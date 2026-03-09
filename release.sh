#!/bin/bash

set -e

CC="x86_64-w64-mingw32-gcc -flto=auto -Wno-stringop-overflow" ./build.sh windows
CC="gcc -flto=auto -Wno-stringop-overflow" ./build.sh

sh ./lint.sh

strip SDL3.dll
strip lite.exe
strip lite

rm -f lite.zip 2>/dev/null
zip -qrT lite.zip lite lite.exe SDL3.dll data
