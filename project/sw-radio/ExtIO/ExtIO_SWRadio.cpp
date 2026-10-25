// Minimal HDSDR-compatible ExtIO network backend; x86 (Win32), no USB driver.
// ExtIO format type 3: signed 16-bit interleaved I/Q, little-endian.
// SPDX-License-Identifier: MIT
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <commctrl.h>
#include <atomic>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <thread>
#include <vector>
#include <array>
#include <cstdlib>

#pragma comment(lib, "Ws2_32.lib")
#pragma comment(lib, "Comctl32.lib")
using ExtCallback = void (*)(int, int, float, void *);
namespace {
constexpr int kPortRx = 50003, kPortControl = 50001;
constexpr int kSamplesPacket = 256, kCallbackSamples = 512;
constexpr long kSampleRate = 1250000;
constexpr double kAdcHz = 62500000.0;
constexpr wchar_t kGainWindowClass[] = L"SWRadioAD8370GainWindow";
constexpr UINT kMsgOtrChanged = WM_APP + 1;
constexpr int kSliderId = 1001, kLowId = 1002, kDefaultId = 1003, kHighId = 1004;
std::atomic<ExtCallback> callback{nullptr};
std::atomic<bool> running{false};
std::atomic<long> center_hz{7100000};
std::atomic<int> gain_code{0x40};
std::atomic<bool> adc_overrange{false};
SOCKET rx = INVALID_SOCKET, control = INVALID_SOCKET;
sockaddr_in control_addr{};
bool wsa_active = false;
std::thread worker;
HINSTANCE dll_instance = nullptr;
HWND gain_window = nullptr, gain_slider = nullptr;
HWND gain_value_text = nullptr, gain_status_text = nullptr, otr_status_text = nullptr;

void close_network();

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
bool send_gain(int code) {
    if (control == INVALID_SOCKET || code < 0 || code > 255) return false;
    const unsigned char data[5] = {'K','9','A','G',static_cast<unsigned char>(code)};
    return sendto(control,reinterpret_cast<const char*>(data),sizeof(data),0,
        reinterpret_cast<const sockaddr*>(&control_addr),sizeof(control_addr)) == sizeof(data);
}
void set_control_font(HWND control_window) {
    SendMessageW(control_window,WM_SETFONT,
        reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)),TRUE);
}
void update_gain_text() {
    if (!gain_value_text) return;
    wchar_t text[80]{};
    swprintf_s(text,L"AD8370 gain code: 0x%02X  (%d / 255)",
        gain_code.load(),gain_code.load());
    SetWindowTextW(gain_value_text,text);
}
void update_otr_text() {
    if (!otr_status_text) return;
    SetWindowTextW(otr_status_text,adc_overrange.load()
        ? L"ADC OTR: OVERLOAD - reduce gain and reprogram/reset FPGA to clear"
        : L"ADC OTR: OK");
}
void apply_gain(int code) {
    if (code < 0) code = 0;
    if (code > 255) code = 255;
    gain_code.store(code);
    if (gain_slider) SendMessageW(gain_slider,TBM_SETPOS,TRUE,code);
    update_gain_text();
    if (gain_status_text) SetWindowTextW(gain_status_text,
        send_gain(code) ? L"Applied to FPGA" : L"Stored; receiver is not open");
}
LRESULT CALLBACK gain_window_proc(HWND window,UINT message,WPARAM wparam,LPARAM lparam) {
    switch (message) {
    case WM_HSCROLL:
        if (reinterpret_cast<HWND>(lparam) == gain_slider) {
            const int code = static_cast<int>(SendMessageW(gain_slider,TBM_GETPOS,0,0));
            gain_code.store(code);
            update_gain_text();
            const int action = LOWORD(wparam);
            // Track continuously for responsive tuning, and always transmit
            // the final position so SPI-command coalescing cannot lose it.
            if (action == TB_THUMBTRACK || action == TB_ENDTRACK ||
                action == TB_THUMBPOSITION || action == TB_LINEUP ||
                action == TB_LINEDOWN || action == TB_PAGEUP || action == TB_PAGEDOWN) {
                if (gain_status_text) SetWindowTextW(gain_status_text,
                    send_gain(code) ? L"Applied to FPGA" : L"Stored; receiver is not open");
            }
        }
        return 0;
    case WM_COMMAND:
        switch (LOWORD(wparam)) {
        case kLowId: apply_gain(0x20); return 0;
        case kDefaultId: apply_gain(0x40); return 0;
        case kHighId: apply_gain(0x60); return 0;
        }
        break;
    case kMsgOtrChanged:
        update_otr_text();
        return 0;
    case WM_CLOSE:
        ShowWindow(window,SW_HIDE);
        return 0;
    case WM_NCDESTROY:
        gain_window = nullptr; gain_slider = nullptr;
        gain_value_text = nullptr; gain_status_text = nullptr; otr_status_text = nullptr;
        return DefWindowProcW(window,message,wparam,lparam);
    }
    return DefWindowProcW(window,message,wparam,lparam);
}
bool create_gain_window() {
    if (gain_window) return true;
    INITCOMMONCONTROLSEX controls{sizeof(controls),ICC_BAR_CLASSES};
    InitCommonControlsEx(&controls);
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = gain_window_proc;
    wc.hInstance = dll_instance;
    wc.hCursor = LoadCursorW(nullptr,IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_BTNFACE+1);
    wc.lpszClassName = kGainWindowClass;
    RegisterClassExW(&wc);
    gain_window = CreateWindowExW(WS_EX_TOOLWINDOW,kGainWindowClass,
        L"SW-Radio / AD8370 Gain",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU,
        CW_USEDEFAULT,CW_USEDEFAULT,470,240,GetForegroundWindow(),nullptr,dll_instance,nullptr);
    if (!gain_window) return false;
    auto make_control = [](LPCWSTR kind,LPCWSTR text,DWORD style,
                           int x,int y,int width,int height,int id) {
        HWND child=CreateWindowExW(0,kind,text,WS_CHILD|WS_VISIBLE|style,
            x,y,width,height,gain_window,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
            dll_instance,nullptr);
        if (child) set_control_font(child);
        return child;
    };
    gain_value_text=make_control(L"STATIC",L"",0,18,16,420,22,0);
    gain_slider=make_control(TRACKBAR_CLASSW,L"",TBS_AUTOTICKS|TBS_HORZ,
        16,42,425,45,kSliderId);
    SendMessageW(gain_slider,TBM_SETRANGE,TRUE,MAKELPARAM(0,255));
    SendMessageW(gain_slider,TBM_SETTICFREQ,16,0);
    SendMessageW(gain_slider,TBM_SETPAGESIZE,0,16);
    SendMessageW(gain_slider,TBM_SETPOS,TRUE,gain_code.load());
    make_control(L"BUTTON",L"Low 0x20",BS_PUSHBUTTON,18,94,125,30,kLowId);
    make_control(L"BUTTON",L"Default 0x40",BS_PUSHBUTTON,166,94,125,30,kDefaultId);
    make_control(L"BUTTON",L"High 0x60",BS_PUSHBUTTON,314,94,125,30,kHighId);
    gain_status_text=make_control(L"STATIC",L"",0,18,137,420,22,0);
    otr_status_text=make_control(L"STATIC",L"",0,18,164,430,42,0);
    update_gain_text();
    update_otr_text();
    SetWindowTextW(gain_status_text,control == INVALID_SOCKET
        ? L"Stored; receiver is not open" : L"Receiver open; move slider to apply");
    return true;
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

        const bool new_overrange=(datagram[5]&2)!=0;
        if (new_overrange != adc_overrange.exchange(new_overrange) && gain_window)
            PostMessageW(gain_window,kMsgOtrChanged,0,0);

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
void close_network() {
    if(rx!=INVALID_SOCKET) { closesocket(rx); rx=INVALID_SOCKET; }
    if(control!=INVALID_SOCKET) { closesocket(control); control=INVALID_SOCKET; }
    if(wsa_active) { WSACleanup(); wsa_active=false; }
}
} // namespace

extern "C" {
__declspec(dllexport) bool __stdcall InitHW(char* name,char* model,int& type) {
    // ExtIO host provides 16-byte arrays (incl terminator).
    strncpy_s(name,16,"SW-Radio 62M5",_TRUNCATE);
    strncpy_s(model,16,"K9+ AD9226-62",_TRUNCATE);
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
    if (rx==INVALID_SOCKET || control==INVALID_SOCKET) {
        close_network();
        return false;
    }
    BOOL reuse=TRUE, broadcast=TRUE;
    setsockopt(rx,SOL_SOCKET,SO_REUSEADDR,reinterpret_cast<const char*>(&reuse),sizeof(reuse));
    setsockopt(control,SOL_SOCKET,SO_BROADCAST,reinterpret_cast<const char*>(&broadcast),sizeof(broadcast));
    DWORD timeout=200;
    setsockopt(rx,SOL_SOCKET,SO_RCVTIMEO,reinterpret_cast<const char*>(&timeout),sizeof(timeout));
    sockaddr_in listen{};
    listen.sin_family=AF_INET;
    listen.sin_addr.s_addr=htonl(INADDR_ANY);
    listen.sin_port=htons(kPortRx);
    if (bind(rx,reinterpret_cast<const sockaddr*>(&listen),sizeof(listen))!=0) {
        close_network();
        return false;
    }
    control_addr.sin_family=AF_INET;
    control_addr.sin_port=htons(kPortControl);
    char* target_env=nullptr;
    size_t target_len=0;
    _dupenv_s(&target_env,&target_len,"SW_RADIO_CONTROL_HOST");
    const char* target=(target_env && *target_env) ? target_env : "192.168.10.255";
    const int target_ok=inet_pton(AF_INET,target,&control_addr.sin_addr);
    std::free(target_env);
    if(target_ok!=1) {
        close_network();
        return false;
    }
    send_gain(gain_code.load());
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
    close_network();
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
__declspec(dllexport) void __stdcall ShowGUI() {
    if (!create_gain_window()) return;
    ShowWindow(gain_window,SW_SHOWNORMAL);
    SetForegroundWindow(gain_window);
}
__declspec(dllexport) void __stdcall HideGUI() {
    if (gain_window) ShowWindow(gain_window,SW_HIDE);
}
__declspec(dllexport) void __stdcall SwitchGUI() {
    if (!gain_window || !IsWindowVisible(gain_window)) ShowGUI();
    else HideGUI();
}
} // extern C

BOOL WINAPI DllMain(HINSTANCE instance,DWORD reason,LPVOID) {
    if (reason==DLL_PROCESS_ATTACH) {
        dll_instance=instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}
