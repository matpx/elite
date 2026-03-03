#include <stdio.h>
#include <stdlib.h>
#include "lib/RGFW/RGFW.h"
#include "api/api.h"
#include "renderer.h"

#ifdef _WIN32
  #include <windows.h>
#elif __linux__
  #include <unistd.h>
#elif __APPLE__
  #include <mach-o/dyld.h>
#endif


RGFW_window *window;


static double get_scale(void) {
  RGFW_monitor *mon = RGFW_window_getMonitor(window);
  if (mon) {
    float sx;
    RGFW_monitor_getScale(mon, &sx, NULL);
    return sx;
  }
  return 1.0;
}


static const char* get_platform(void) {
#if defined(_WIN32)
  return "Windows";
#elif defined(__APPLE__)
  return "Mac OS X";
#elif defined(__linux__)
  return "Linux";
#else
  return "Unknown";
#endif
}


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
  strcpy(buf, "./lite");
#endif
}


static void init_window_icon(void) {
#ifndef _WIN32
  #include "../icon.inl"
  (void) icon_rgba_len; /* unused */
  RGFW_window_setIcon(window, icon_rgba, 64, 64, RGFW_formatRGBA8);
#endif
}


int main(int argc, char **argv) {
  RGFW_init();

  /* get screen size for initial window dimensions */
  RGFW_monitor **monitors = RGFW_getMonitors(NULL);
  int screen_w = 800, screen_h = 600;
  if (monitors && monitors[0]) {
    RGFW_monitorMode mode;
    if (RGFW_monitor_getMode(monitors[0], &mode)) {
      screen_w = mode.w;
      screen_h = mode.h;
    }
  }

  window = RGFW_createWindow(
    "", 0, 0, screen_w * 0.8, screen_h * 0.8,
    RGFW_windowCenter | RGFW_windowAllowDND | RGFW_windowHide);
  RGFW_window_setExitKey(window, RGFW_keyNULL);

  init_window_icon();
  ren_init(window);


  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  api_load_libs(L);


  lua_newtable(L);
  for (int i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setglobal(L, "ARGS");

  lua_pushstring(L, "1.11");
  lua_setglobal(L, "VERSION");

  lua_pushstring(L, get_platform());
  lua_setglobal(L, "PLATFORM");

  lua_pushnumber(L, get_scale());
  lua_setglobal(L, "SCALE");

  char exename[2048];
  get_exe_filename(exename, sizeof(exename));
  lua_pushstring(L, exename);
  lua_setglobal(L, "EXEFILE");


  (void) luaL_dostring(L,
    "local core\n"
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


  lua_close(L);
  RGFW_window_close(window);

  return EXIT_SUCCESS;
}
