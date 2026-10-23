#!/usr/bin/env bash
# Optional: cross-compile a standalone Windows x86 HDSDR DLL on Linux.
# Requires apt package g++-mingw-w64-i686-posix (or equivalent toolchain).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$here/Release"
i686-w64-mingw32-g++ -std=c++17 -Wall -Wextra -O2 -shared \
    "$here/ExtIO_SWRadio.cpp" -lws2_32 \
    -Wl,--add-stdcall-alias -static -static-libgcc -static-libstdc++ \
    -o "$here/Release/ExtIO_SWRadio.dll"
echo "Windows x86 DLL: $here/Release/ExtIO_SWRadio.dll"
