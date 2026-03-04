#!/bin/sh
set -e

OUTDIR=tinyccbin
TCCDIR=tinycc
JOBS=8

# Linux x86_64 build
make -C $TCCDIR clean
cd $TCCDIR && ./configure --cc="zig cc" --ar="zig ar" && cd ..
make -C $TCCDIR tcc libtcc.a -j$JOBS
mkdir -p $OUTDIR/linux-x86_64
cp $TCCDIR/tcc $TCCDIR/libtcc.a $OUTDIR/linux-x86_64/

# Linux arm64 build
make -C $TCCDIR clean
cd $TCCDIR && ./configure --cc="zig cc -target aarch64-linux-gnu" --ar="zig ar" --targetos=Linux --cpu=arm64 --config-predefs=no --enable-static && cd ..
make -C $TCCDIR tcc libtcc.a -j$JOBS
mkdir -p $OUTDIR/linux-arm64
cp $TCCDIR/tcc $TCCDIR/libtcc.a $OUTDIR/linux-arm64/

# Windows x86_64 build
make -C $TCCDIR clean
cd $TCCDIR && ./configure --cc="zig cc -target x86_64-windows-gnu" --ar="zig ar" --targetos=WIN32 --config-predefs=no --enable-static && cd ..
make -C $TCCDIR tcc.exe libtcc.a -j$JOBS
mkdir -p $OUTDIR/windows-x86_64
cp $TCCDIR/tcc.exe $TCCDIR/libtcc.a $OUTDIR/windows-x86_64/