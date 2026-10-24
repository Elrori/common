#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <limits>

using Callback = void (*)(int, int, float, void*);
using InitHWFn = bool (__stdcall *)(char*, char*, int&);
using OpenHWFn = bool (__stdcall *)();
using StartHWFn = int (__stdcall *)(long);
using StopHWFn = void (__stdcall *)();
using CloseHWFn = void (__stdcall *)();
using SetCallbackFn = void (__stdcall *)(Callback);
using SetHWLOFn = int (__stdcall *)(long);
using GetHWSRFn = long (__stdcall *)();
using GuiFn = void (__stdcall *)();

std::atomic<unsigned long> callback_count{0};
std::atomic<unsigned long> sample_count{0};
std::atomic<long long> sum_squares{0};
std::atomic<int> peak{0};

void on_samples(int count, int, float, void* data) {
    if (count <= 0 || !data) return;
    const auto* iq = static_cast<const int16_t*>(data);
    long long block_power = 0;
    int block_peak = 0;
    for (int n=0; n<2*count; ++n) {
        const int v = iq[n];
        block_power += static_cast<long long>(v)*v;
        const int a = v < 0 ? -v : v;
        if (a > block_peak) block_peak = a;
    }
    sum_squares.fetch_add(block_power);
    sample_count.fetch_add(static_cast<unsigned long>(count));
    callback_count.fetch_add(1);
    int old_peak = peak.load();
    while (block_peak > old_peak && !peak.compare_exchange_weak(old_peak, block_peak)) {}
}

template<typename T> T symbol(HMODULE dll, const char* name) {
    const auto p = GetProcAddress(dll, name);
    if (!p) {
        std::fprintf(stderr, "missing export: %s\n", name);
        ExitProcess(2);
    }
    return reinterpret_cast<T>(p);
}

int main(int argc, char** argv) {
    const char* path = argc > 1 ? argv[1] : "ExtIO_SWRadio.dll";
    HMODULE dll = LoadLibraryA(path);
    if (!dll) {
        std::fprintf(stderr, "LoadLibrary failed: %lu\n", GetLastError());
        return 2;
    }
    const auto init = symbol<InitHWFn>(dll,"InitHW");
    const auto open = symbol<OpenHWFn>(dll,"OpenHW");
    const auto start = symbol<StartHWFn>(dll,"StartHW");
    const auto stop = symbol<StopHWFn>(dll,"StopHW");
    const auto close = symbol<CloseHWFn>(dll,"CloseHW");
    const auto set_callback = symbol<SetCallbackFn>(dll,"SetCallback");
    const auto set_lo = symbol<SetHWLOFn>(dll,"SetHWLO");
    const auto get_rate = symbol<GetHWSRFn>(dll,"GetHWSR");
    // HDSDR's SDR-Device button requires these optional ExtIO GUI exports.
    symbol<GuiFn>(dll,"ShowGUI");
    symbol<GuiFn>(dll,"HideGUI");
    symbol<GuiFn>(dll,"SwitchGUI");

    char name[16]{}, model[16]{};
    int type=0;
    if (!init(name,model,type) || !open()) {
        std::fprintf(stderr,"InitHW/OpenHW failed\n");
        FreeLibrary(dll);
        return 3;
    }
    set_callback(on_samples);
    if (set_lo(7100000) != 0 || start(7100000) != 512) {
        std::fprintf(stderr,"SetHWLO/StartHW failed\n");
        close();
        FreeLibrary(dll);
        return 4;
    }
    Sleep(2000);
    stop();
    close();

    const auto callbacks=callback_count.load();
    const auto samples=sample_count.load();
    const auto power=sum_squares.load();
    const double rms=samples ? std::sqrt(double(power)/(2.0*double(samples))) : 0.0;
    std::printf("EXTIO_SMOKE name=%s model=%s type=%d rate=%ld callbacks=%lu samples=%lu rms=%.3f peak=%d\n",
        name,model,type,get_rate(),callbacks,samples,rms,peak.load());
    FreeLibrary(dll);
    return callbacks >= 100 && samples >= 50000 && rms > 1.0 ? 0 : 5;
}
