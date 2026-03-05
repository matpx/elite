@echo off
setlocal enabledelayedexpansion

if defined CC (
    set compiler=%CC%
) else (
    set compiler=winlib\tcc\tcc.exe
)

echo compiling (windows) with %compiler%...

set srcs=
for /r src %%f in (*.c) do set srcs=!srcs! %%f

%compiler% -Bwinlib\tcc %srcs% ^
    -Wall -O3 -s -std=c11 -fno-strict-aliasing -Isrc -DLUA_USE_POPEN ^
    -I.\winlib\SDL3-3.4.2\x86_64-w64-mingw32\include ^
    -Iwinlib\tcc\include\ -I.\winlib\tcc\include\sys ^
    -Iwinlib\tcc\include\winapi -Wl,-subsystem=windows -luser32 ^
    winlib\SDL3-3.4.2\x86_64-w64-mingw32\bin\SDL3.dll ^
    -o lite.exe || exit /b 1

winlib\rcedit\rcedit-x64.exe lite.exe --set-icon icon.ico
copy winlib\SDL3-3.4.2\x86_64-w64-mingw32\bin\SDL3.dll . >nul

echo done
