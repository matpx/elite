#!/bin/bash

set -e

if echo "$*" | grep -q "windows"; then
  compiler="${CC:-winlib/tcc/tcc.exe}"
  cflags="-Wall -O3 -std=c11 -fno-strict-aliasing -Isrc"
  cflags="$cflags -I./winlib/SDL3-3.4.2/x86_64-w64-mingw32/include"

  if echo "$compiler" | grep -q "tcc"; then
    cflags="$cflags -Bwinlib/tcc"
    cflags="$cflags -Iwinlib/tcc/include/ -I./winlib/tcc/include/sys"
    cflags="$cflags -Iwinlib/tcc/include/winapi"
  fi

  lflags="-Wl,-subsystem=windows -luser32 winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll -o lite.exe"
else
  compiler="${CC:-tcc}"
  cflags="-Wall -O3 -std=c11 -fno-strict-aliasing -Isrc -DLUA_USE_POSIX -D_XOPEN_SOURCE=500"
  lflags="-lSDL3 -lm -o lite"
fi

if echo "$*" | grep -q "debug"; then
  cflags="$cflags -g -DLUA_USE_APICHECK"
  # cflags="$cflags -b"
  # lflags="$lflags -b"
else
  lflags="-s $lflags"
fi

echo "compiling..."
find src -name "*.c" | xargs -P$(nproc) -I{} sh -c '$0 -c $1 "$2" -o "$(echo $2 | tr / _).o"' "$compiler" "$cflags" {}

echo "linking..."
$compiler *.o $lflags

echo "cleaning up..."
rm -f *.o

if echo "$*" | grep -q "windows"; then
  ./winlib/rcedit/rcedit-x64.exe lite.exe --set-icon icon.ico
  cp winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll .
fi

echo "done"
