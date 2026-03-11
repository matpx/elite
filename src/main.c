#include <stdio.h>
#include <stdlib.h>
#define SDL_MAIN_HANDLED
#include "api/api.h"
#include "lib/rpmalloc/rpmalloc.h"
#include "rencache.h"
#include "renderer.h"
#include <SDL3/SDL.h>

#ifdef _WIN32
#include <windows.h>
#elif __linux__
#include <unistd.h>
#elif __APPLE__
#include <mach-o/dyld.h>
#endif

SDL_Window *window;
static lua_State *L;

static void shutdown_rpmalloc(void) {
    rpmalloc_global_statistics_t stats = {0};
    rpmalloc_global_statistics(&stats);
    fprintf(stderr,
            "[rpmalloc] mapped: %zu KB (peak %zu KB), active: %zu KB (peak "
            "%zu KB), heaps: %zu\n",
            stats.mapped / 1024, stats.mapped_peak / 1024,
            stats.active / 1024, stats.active_peak / 1024,
            stats.heap_count);
    rpmalloc_finalize();
}

static void shutdown_sdl(void) {
    SDL_DestroyWindow(window);
    SDL_Quit();
}

static void shutdown_lua(void) {
    if (!L)
        return;
    rencache_end_frame();
    lua_close(L);
    L = NULL;
}

static void *rp_lua_alloc(void *ud, void *ptr, size_t osize, size_t nsize) {
    (void)ud;
    (void)osize;
    if (nsize == 0) {
        rpfree(ptr);
        return NULL;
    }
    return rprealloc(ptr, nsize);
}

static double get_scale(void) { return SDL_GetWindowDisplayScale(window); }

static void get_exe_filename(char *buf, int sz) {
#if _WIN32
    int len = GetModuleFileName(NULL, buf, sz - 1);
    buf[len] = '\0';
#elif __linux__
    char path[512];
    sprintf(path, "/proc/%d/exe", getpid());
    int len = readlink(path, buf, sz - 1);
    buf[len] = '\0';
#elif __APPLE__
    unsigned size = sz;
    _NSGetExecutablePath(buf, &size);
#else
    strcpy(buf, "./elite");
#endif
}

static void init_window_icon(void) {
#ifndef _WIN32
#include "../icon.inl"
    (void)icon_rgba_len; /* unused */
    SDL_Surface *surf = SDL_CreateSurfaceFrom(64, 64, SDL_PIXELFORMAT_RGBA32,
                                              icon_rgba, 64 * 4);
    SDL_SetWindowIcon(window, surf);
    SDL_DestroySurface(surf);
#endif
}

int main(int argc, char **argv) {
    rpmalloc_initialize(NULL);
    atexit(shutdown_rpmalloc);
    SDL_SetMemoryFunctions(rpmalloc, rpcalloc, rprealloc, rpfree);
    SDL_Init(SDL_INIT_VIDEO);
    atexit(shutdown_sdl);
    SDL_EnableScreenSaver();
    SDL_SetEventEnabled(SDL_EVENT_DROP_FILE, true);

    SDL_SetHint(SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR, "0");
    SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, "1");

    const SDL_DisplayMode *dm =
        SDL_GetCurrentDisplayMode(SDL_GetPrimaryDisplay());

    window = SDL_CreateWindow("", dm->w * 0.8, dm->h * 0.8,
                              SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN |
                                  SDL_WINDOW_HIGH_PIXEL_DENSITY);
    init_window_icon();
    ren_init(window);

    SDL_StartTextInput(window);

    L = lua_newstate(rp_lua_alloc, NULL, luaL_makeseed(NULL));
    atexit(shutdown_lua);
    luaL_openlibs(L);
    api_load_libs(L);

    lua_newtable(L);
    for (int i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "ARGS");

    lua_pushstring(L, "1.0");
    lua_setglobal(L, "VERSION");

    lua_pushstring(L, SDL_GetPlatform());
    lua_setglobal(L, "PLATFORM");

    lua_pushnumber(L, get_scale());
    lua_setglobal(L, "SCALE");

    char exename[2048];
    get_exe_filename(exename, sizeof(exename));
    lua_pushstring(L, exename);
    lua_setglobal(L, "EXEFILE");

    (void)luaL_dostring(
        L, "local core\n"
           "xpcall(function()\n"
           "  SCALE = tonumber(os.getenv(\"LITE_SCALE\")) or SCALE\n"
           "  PATHSEP = package.config:sub(1, 1)\n"
           "  EXEDIR = EXEFILE:match(\"^(.+)[/\\\\].*$\")\n"
           "  package.path = EXEDIR .. '/data/?.lua;' .. package.path\n"
           "  package.path = EXEDIR .. '/data/?/init.lua;' .. package.path\n"
           "  core = require('core')\n"
           "  core.init()\n"
           "  core.run()\n"
           "end, function(err)\n"
           "  print('Error: ' .. tostring(err))\n"
           "  print(debug.traceback(nil, 2))\n"
           "  if core and core.on_error then\n"
           "    pcall(core.on_error, err)\n"
           "  end\n"
           "  os.exit(1)\n"
           "end)");

    return EXIT_SUCCESS;
}
