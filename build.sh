#!/bin/bash

set -e

cflags="-Wall -Wextra -O3 -g -std=c11 -fno-strict-aliasing -Isrc -fno-diagnostics-show-caret"

if echo "$*" | grep -q "windows"; then
  compiler="${CC:-winlib/tcc/tcc.exe}"

  cflags="$cflags -I./winlib/SDL3-3.4.2/x86_64-w64-mingw32/include"

  lflags="$lflags -Wl,-subsystem=windows"
  lflags="$lflags -luser32 winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll"
  lflags="$lflags -o lite.exe"

  if echo "$compiler" | grep -q "tcc"; then
    cflags="$cflags -Bwinlib/tcc"
    cflags="$cflags -Iwinlib/tcc/include/ -I./winlib/tcc/include/sys"
    cflags="$cflags -Iwinlib/tcc/include/winapi"
  else
    x86_64-w64-mingw32-windres res.rc -O coff -o res.res
    lflags="$lflags res.res"
  fi

else
  compiler="${CC:-tcc}"
  cflags="$cflags -DLUA_USE_POSIX -D_XOPEN_SOURCE=500"
  lflags="-lSDL3 -lm -o lite"
fi

echo "compiling..."
find src -name "*.c" | xargs -P$(nproc) -I{} sh -c '$0 -c $1 "$2" -o "$(echo $2 | tr / _).o"' "$compiler" "$cflags" {}

echo "linking..."
$compiler *.o $lflags

echo "cleaning up..."
rm -f *.o

if echo "$*" | grep -q "windows"; then
  if echo "$compiler" | grep -q "tcc"; then
    ./winlib/rcedit/rcedit-x64.exe lite.exe --set-icon icon.ico
  fi

  cp winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll .
fi

echo "done"
