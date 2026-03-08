#!/bin/sh

set -e

clang-format --dry-run --Werror src/*.c src/*.h src/api/*.c src/api/*.h
luacheck .
stylua -c .
