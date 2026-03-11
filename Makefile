CC ?= gcc

CFLAGS = -Wall -Wextra -Werror -O3 -g -std=c11 -fno-strict-aliasing -Isrc \
         -fno-diagnostics-show-caret -DMAKE_LIB

ifneq ($(NO_AVX),1)
  CFLAGS += -march=x86-64-v3
endif

SRCS = $(shell find src -name '*.c' -not -path 'src/lib/lua55/*') src/lib/lua55/onelua.c
BUILDDIR = .build/$(or $(OS),linux)
OBJS    = $(SRCS:%.c=$(BUILDDIR)/%.o)

# --- Linux (default) ---

CFLAGS  += -DLUA_USE_POSIX -D_XOPEN_SOURCE=500
LDFLAGS  = -lSDL3 -lm
TARGET   = elite

# --- Windows (cross-compile) ---

ifeq ($(OS),windows)
  CC       = x86_64-w64-mingw32-gcc
  WIN_SDL  = winlib/SDL3-3.4.2/x86_64-w64-mingw32
  CFLAGS  := $(filter-out -DLUA_USE_POSIX -D_XOPEN_SOURCE=500,$(CFLAGS))
  CFLAGS  += -I$(WIN_SDL)/include
  LDFLAGS  = -Wl,-subsystem=windows -luser32 $(WIN_SDL)/bin/SDL3.dll res.res
  TARGET   = elite.exe
endif

# --- Sanitizers ---

ifeq ($(SANITIZE),1)
  CFLAGS  += -fsanitize=address,undefined -fno-omit-frame-pointer -Wno-unused-but-set-variable
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
ifeq ($(OS),windows)
	cp $(WIN_SDL)/bin/SDL3.dll .
endif

$(BUILDDIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

format:
	clang-format -i src/*.c src/*.h src/api/*.c src/api/*.h
	stylua .

lint:
	luacheck .
	clang-format --dry-run --Werror src/*.c src/*.h src/api/*.c src/api/*.h
	stylua -c .

release: clean
	$(MAKE) OS=windows
	$(MAKE)
	$(MAKE) lint
	strip SDL3.dll elite.exe elite
	rm -f elite.zip
	zip -qrT elite.zip elite elite.exe SDL3.dll data

clean:
	rm -rf .build elite elite.exe res.res elite.zip SDL3.dll

.PHONY: all clean format lint release
