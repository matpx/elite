#!/bin/bash

set -e

./build.sh release windows
./build.sh release
rm -f lite.zip
cp winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll SDL3.dll
strip lite
strip lite.exe
strip SDL3.dll
zip lite.zip lite lite.exe SDL3.dll data -r

rm -f lite lite.exe SDL3.dll
