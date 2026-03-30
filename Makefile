CC ?= gcc

CFLAGS = -Wall -Wextra -Werror -O3 -g -std=c11 -fno-strict-aliasing -Isrc \
         -DMAKE_LIB $(EXTRA_CFLAGS)

ifneq ($(NO_AVX),1)
  CFLAGS += -march=x86-64-v3
endif

BUILDDIR = .build/$(or $(OS),linux)

# --- App sources (everything in src/ except src/lib/) ---

APP_SRCS = $(shell find src -maxdepth 1 -name '*.c') \
           $(shell find src/api -name '*.c')
APP_OBJS = $(APP_SRCS:%.c=$(BUILDDIR)/%.o)

# --- Libraries ---

LUA_SRCS      = src/lib/lua55/onelua.c
STB_SRCS      = $(wildcard src/lib/stb/*.c)
QOI_SRCS      = $(wildcard src/lib/qoi/*.c)
RPMALLOC_SRCS = src/lib/rpmalloc/rpmalloc.c

LUA_OBJS      = $(LUA_SRCS:%.c=$(BUILDDIR)/%.o)
STB_OBJS      = $(STB_SRCS:%.c=$(BUILDDIR)/%.o)
QOI_OBJS      = $(QOI_SRCS:%.c=$(BUILDDIR)/%.o)
RPMALLOC_OBJS = $(RPMALLOC_SRCS:%.c=$(BUILDDIR)/%.o)

LIB_LUA      = $(BUILDDIR)/liblua.a
LIB_STB      = $(BUILDDIR)/libstb.a
LIB_QOI      = $(BUILDDIR)/libqoi.a
LIB_RPMALLOC = $(BUILDDIR)/librpmalloc.a

LIBS = $(LIB_LUA) $(LIB_STB) $(LIB_QOI)

ifneq ($(NO_RPMALLOC),1)
  LIBS += $(LIB_RPMALLOC)
endif

# --- Linux (default) ---

CFLAGS  += -DLUA_USE_POSIX -D_XOPEN_SOURCE=600 -D_DEFAULT_SOURCE
LDFLAGS  = -lSDL3 -lm
TARGET   = elite

# --- Windows (cross-compile) ---

ifeq ($(OS),windows)
  CC       = x86_64-w64-mingw32-gcc
  WIN_SDL  = winlib/SDL3-3.4.2/x86_64-w64-mingw32
  CFLAGS  := $(filter-out -DLUA_USE_POSIX -D_XOPEN_SOURCE=600,$(CFLAGS))
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

$(TARGET): $(APP_OBJS) $(LIBS)
ifeq ($(OS),windows)
	x86_64-w64-mingw32-windres res.rc -O coff -o res.res
endif
	$(CC) $(APP_OBJS) $(LIBS) $(LDFLAGS) -o $@
ifeq ($(OS),windows)
	cp $(WIN_SDL)/bin/SDL3.dll .
endif

$(LIB_LUA): $(LUA_OBJS)
	$(AR) rcs $@ $^

$(LIB_STB): $(STB_OBJS)
	$(AR) rcs $@ $^

$(LIB_QOI): $(QOI_OBJS)
	$(AR) rcs $@ $^

$(LIB_RPMALLOC): $(RPMALLOC_OBJS)
	$(AR) rcs $@ $^

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
