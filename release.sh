#!/bin/bash

set -e

CC="x86_64-w64-mingw32-gcc -flto=auto" ./build.sh windows
CC="gcc -flto=auto" ./build.sh

cp winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll SDL3.dll

strip SDL3.dll
strip lite.exe
strip lite

rm -f lite.zip 2>/dev/null
zip -qrT lite.zip lite lite.exe SDL3.dll data
