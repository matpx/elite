@echo off

rem download this:
rem https://nuwen.net/mingw.html

echo compiling (windows)...

windres res.rc -O coff -o res.res
gcc src/*.c src/api/*.c src/lib/lua52/*.c src/lib/stb/*.c^
    -O3 -s -std=gnu11 -fno-strict-aliasing -Isrc -DLUA_USE_POPEN^
    -Iwinlib/SDL3-3.4.2/x86_64-w64-mingw32/include^
    -lmingw32 -lm -lSDL3 -Lwinlib/SDL3-3.4.2/x86_64-w64-mingw32/lib^
    -mwindows res.res^
    -o lite.exe

echo done
