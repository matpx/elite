#!/bin/bash

set -e

compiler="${CC:-tcc}"
cflags="-Wall -O3 -g -std=c11 -fno-strict-aliasing -Isrc -DLUA_USE_POSIX -D_XOPEN_SOURCE=500"
lflags="-lSDL3 -lm -o lite"

echo "compiling..."
for f in `find src -name "*.c"`; do
  $compiler -c $cflags $f -o "${f//\//_}.o"
done

echo "linking..."
$compiler *.o $lflags

echo "cleaning up..."
rm -f *.o
echo "done"
