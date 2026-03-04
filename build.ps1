$compiler = if ($env:CC) { $env:CC } else { ".\winlib\tcc\tcc.exe" }

Write-Host "compiling (windows) with $compiler..."
$srcs = (Get-ChildItem -Recurse src -Filter *.c).FullName | Resolve-Path -Relative

& $compiler -Bwinlib\tcc $srcs `
    -O3 -s -std=c11 -fno-strict-aliasing -Isrc -DLUA_USE_POPEN `
    -I./winlib/SDL3-3.4.2/x86_64-w64-mingw32/include `
    -Iwinlib/tcc/include/ -I./winlib/tcc/include/sys `
    -Iwinlib/tcc/include/winapi -luser32 `
    winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll `
    -o lite.exe

Copy-Item winlib/SDL3-3.4.2/x86_64-w64-mingw32/bin/SDL3.dll -Destination . -Force

Write-Host "done"
