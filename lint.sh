#!/bin/sh

set -e

luacheck .

clang-format --dry-run --Werror src/*.c src/*.h src/api/*.c src/api/*.h
stylua -c .
