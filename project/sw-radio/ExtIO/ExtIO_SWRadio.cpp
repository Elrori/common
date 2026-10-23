// Minimal HDSDR-compatible ExtIO network backend; x86 (Win32), no USB driver.
// ExtIO format type 3: signed 16-bit interleaved I/Q, little-endian.
// SPDX-License-Identifier: MIT
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <atomic>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <thread>
#include <vector>
#include <array>
#include <cstdlib>

#pragma comment(lib, "Ws2_32.lib")
using ExtCallback = void (*)(int, int, float, void *);
namespace {
constexpr int kPortRx = 50003, kPortControl = 50001;
constexpr int kSamplesPacket = 256, kCallbackSamples = 512;
constexpr long kSampleRate = 1250000;
constexpr double kAdcHz = 40000000.0;
std::atomic<ExtCallback> callback{nullptr};
std::atomic<bool> running{false};
std::atomic<long> center_hz{7100000};
SOCKET rx = INVALID_SOCKET, control = INVALID_SOCKET;
sockaddr_in control_addr{};
bool wsa_active = false;
std::thread worker;

uint32_t get32(const unsigned char* b) {
    return static_cast<uint32_t>(b[0]) |
        (static_cast<uint32_t>(b[1]) << 8) |
        (static_cast<uint32_t>(b[2]) << 16) |
        (static_cast<uint32_t>(b[3]) << 24);
}
void put32(unsigned char* b, uint32_t x) {
    for (int i=0;i<4;++i) b[i] = static_cast<unsigned char>(x >> (i*8));
}
void send_tune(long hz) {
    if (control == INVALID_SOCKET || hz<0) return;
    unsigned char data[12]={'K','9','T','U'};
    put32(data+4,static_cast<uint32_t>(hz));
    // Compute in double: integer 0x100000000 * freq overflows 32-bit.
    const auto fcw = static_cast<uint32_t>(
        static_cast<uint64_t>(std::llround(double(hz)*4294967296.0/kAdcHz)));
    put32(data+8,fcw);
    sendto(control,reinterpret_cast<const char*>(data),sizeof(data),0,
           reinterpret_cast<const sockaddr*>(&control_addr),sizeof(control_addr));
}
void capture() {
    std::array<int16_t, kCallbackSamples*2> out{};
    int fill=0;
    uint64_t expected=0;
    bool have_expected=false;
    std::array<unsigned char, 2048> datagram{};
    while (running.load()) {
        sockaddr_in peer{};
        int peer_len=sizeof(peer);
        const int received=recvfrom(rx,reinterpret_cast<char*>(datagram.data()),
            static_cast<int>(datagram.size()),0,
            reinterpret_cast<sockaddr*>(&peer),&peer_len);
        if (received<0) {
            if (!running.load()) break;
            const int err=WSAGetLastError();
            if (err==WSAETIMEDOUT || err==WSAEWOULDBLOCK || err==WSAEINTR) continue;
            continue;
        }
        // Application header starts at start of UDP payload, not Ethernet frame.
        if (received!=32+4*kSamplesPacket ||
            std::memcmp(datagram.data(),"K9IQ",4)!=0 ||
            datagram[4]!=3 || (datagram[5]&4)==0 ||
            datagram[6]!=32 || datagram[7]!=0 ||
            get32(datagram.data()+16)!=kSampleRate) continue;

        const auto* p=datagram.data();
        uint64_t first=0;
        for(int i=0;i<8;i++) first|=uint64_t(p[20+i])<<(i*8);
        if (!have_expected || first<expected || first>expected+4*kSamplesPacket) {
            // Stream startup, large gap or retune: reset the accumulation.
            fill=0; expected=first; have_expected=true;
        }
        // Small gaps are explicit IQ=0, avoiding sample phase slip in HDSDR.
        while (expected<first) {
            out[2*fill]=0; out[2*fill+1]=0; ++fill; ++expected;
            if (fill==kCallbackSamples) {
                auto cb=callback.load();
                if (cb) cb(kCallbackSamples,0,0.0f,out.data());
                fill=0;
            }
        }
        for(int sample=0;sample<kSamplesPacket;sample++) {
            const int idx=32+4*sample;
            out[2*fill]=static_cast<int16_t>(uint16_t(p[idx]) | uint16_t(p[idx+1])<<8);
            out[2*fill+1]=static_cast<int16_t>(uint16_t(p[idx+2]) | uint16_t(p[idx+3])<<8);
            ++fill; ++expected;
            if(fill==kCallbackSamples) {
                auto cb=callback.load();
                if(cb) cb(kCallbackSamples,0,0.0f,out.data());
                fill=0;
            }
        }
    }
}
} // namespace

extern "C" {
__declspec(dllexport) bool __stdcall InitHW(char* name,char* model,int& type) {
    // ExtIO host provides 16-byte arrays (incl terminator).
    std::strncpy(name,"SW-Radio",15); name[15]=0;
    std::strncpy(model,"K9+ AD9235",15); model[15]=0;
    type=3; // exthwUSBdata16
    return true;
}
__declspec(dllexport) bool __stdcall OpenHW() {
    if (wsa_active) return true;
    WSADATA info{};
    if (WSAStartup(MAKEWORD(2,2),&info)!=0) return false;
    wsa_active=true;
    rx=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);
    control=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);
    if (rx==INVALID_SOCKET || control==INVALID_SOCKET) return false;
    BOOL reuse=TRUE, broadcast=TRUE;
    setsockopt(rx,SOL_SOCKET,SO_REUSEADDR,reinterpret_cast<const char*>(&reuse),sizeof(reuse));
    setsockopt(control,SOL_SOCKET,SO_BROADCAST,reinterpret_cast<const char*>(&broadcast),sizeof(broadcast));
    DWORD timeout=200;
    setsockopt(rx,SOL_SOCKET,SO_RCVTIMEO,reinterpret_cast<const char*>(&timeout),sizeof(timeout));
    sockaddr_in listen{};
    listen.sin_family=AF_INET;
    listen.sin_addr.s_addr=htonl(INADDR_ANY);
    listen.sin_port=htons(kPortRx);
    if (bind(rx,reinterpret_cast<const sockaddr*>(&listen),sizeof(listen))!=0) return false;
    control_addr.sin_family=AF_INET;
    control_addr.sin_port=htons(kPortControl);
    const char* target=std::getenv("SW_RADIO_CONTROL_HOST");
    if(!target || !*target) target="192.168.10.255";
    if(inet_pton(AF_INET,target,&control_addr.sin_addr)!=1) return false;
    return true;
}
__declspec(dllexport) int __stdcall StartHW(long hz) {
    if(!wsa_active || rx==INVALID_SOCKET) return 0;
    if(hz>0) center_hz.store(hz);
    send_tune(center_hz.load());
    if (!running.exchange(true)) worker=std::thread(capture);
    return kCallbackSamples;
}
__declspec(dllexport) void __stdcall StopHW() {
    if(running.exchange(false)) {
        if(worker.joinable()) worker.join();
    }
}
__declspec(dllexport) void __stdcall CloseHW() {
    StopHW();
    if(rx!=INVALID_SOCKET) { closesocket(rx); rx=INVALID_SOCKET; }
    if(control!=INVALID_SOCKET) { closesocket(control); control=INVALID_SOCKET; }
    if(wsa_active) { WSACleanup(); wsa_active=false; }
}
__declspec(dllexport) int __stdcall SetHWLO(long hz) {
    if(hz<0 || hz>30000000) return 1;
    center_hz.store(hz);
    send_tune(hz);
    return 0;
}
__declspec(dllexport) long __stdcall GetHWLO() { return center_hz.load(); }
__declspec(dllexport) long __stdcall GetHWSR() { return kSampleRate; }
__declspec(dllexport) long __stdcall GetTune() { return center_hz.load(); }
__declspec(dllexport) int __stdcall GetStatus() { return 0; }
__declspec(dllexport) void __stdcall TuneChanged(long) {}
__declspec(dllexport) void __stdcall GetFilters(int& lo,int& hi,int& pitch) {
    lo=-500000; hi=500000; pitch=0;
}
__declspec(dllexport) void __stdcall SetCallback(ExtCallback cb) {
    callback.store(cb);
    if(cb) cb(-1,101,0.0f,nullptr);
}
__declspec(dllexport) int __stdcall ExtIoGetSrates(int idx,double* out) {
    if(idx!=0 || !out) return 1;
    *out=double(kSampleRate); return 0;
}
__declspec(dllexport) int __stdcall ExtIoGetActualSrateIdx() {return 0;}
__declspec(dllexport) int __stdcall ExtIoSetSrate(int idx) {return idx==0?0:1;}
__declspec(dllexport) long __stdcall ExtIoGetBandwidth(int idx) {return idx==0?1000000:0;}
} // extern C

BOOL WINAPI DllMain(HINSTANCE,DWORD,LPVOID) {return TRUE;}
