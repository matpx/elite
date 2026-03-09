CC ?= gcc

CFLAGS = -Wall -Wextra -Werror -O3 -g -std=c11 -fno-strict-aliasing -Isrc \
         -fno-diagnostics-show-caret

ifneq ($(NO_AVX),1)
  CFLAGS += -march=x86-64-v3
endif

SRCS = $(shell find src -name '*.c')
OBJS = $(SRCS:%.c=build/%.o)

# --- Linux (default) ---

CFLAGS  += -DLUA_USE_POSIX -D_XOPEN_SOURCE=500
LDFLAGS  = -lSDL3 -lm
TARGET   = lite

# --- Windows (cross-compile) ---

ifeq ($(OS),windows)
  CC       = x86_64-w64-mingw32-gcc
  WIN_SDL  = winlib/SDL3-3.4.2/x86_64-w64-mingw32
  CFLAGS  := $(filter-out -DLUA_USE_POSIX -D_XOPEN_SOURCE=500,$(CFLAGS))
  CFLAGS  += -I$(WIN_SDL)/include
  LDFLAGS  = -Wl,-subsystem=windows -luser32 $(WIN_SDL)/bin/SDL3.dll res.res
  TARGET   = lite.exe
endif

# --- Sanitizers ---

ifeq ($(SANITIZE),1)
  CFLAGS  += -fsanitize=address,undefined -fno-omit-frame-pointer
  LDFLAGS += -fsanitize=address,undefined
endif

# --- LTO ---

ifneq ($(NO_LTO),1)
  CFLAGS  += -flto=auto
  LDFLAGS += -flto=auto -Wno-stringop-overflow
endif

# --- Targets ---

all: $(TARGET)

$(TARGET): $(OBJS)
ifeq ($(OS),windows)
	x86_64-w64-mingw32-windres res.rc -O coff -o res.res
endif
	$(CC) $(OBJS) $(LDFLAGS) -o $@

build/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

lint:
	luacheck .
	clang-format --dry-run --Werror src/*.c src/*.h src/api/*.c src/api/*.h
	stylua -c .

release: clean
	$(MAKE) OS=windows
	$(MAKE)
	$(MAKE) lint
	strip SDL3.dll lite.exe lite
	rm -f lite.zip
	zip -qrT lite.zip lite lite.exe SDL3.dll data

clean:
	rm -rf build lite lite.exe res.res lite.zip

.PHONY: all clean lint release
