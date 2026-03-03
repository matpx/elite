#include <stdbool.h>
#include <ctype.h>
#include <dirent.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include "../lib/RGFW/RGFW.h"
#include "../lib/libtinyfiledialogs/tinyfiledialogs.h"
#include "api.h"
#include "../rencache.h"
#ifdef _WIN32
  #include <windows.h>
#endif

extern RGFW_window *window;


static const char* button_name(int button) {
  switch (button) {
    case RGFW_mouseLeft   : return "left";
    case RGFW_mouseMiddle : return "middle";
    case RGFW_mouseRight  : return "right";
    default               : return "?";
  }
}


static char* key_name(char *dst, RGFW_key key) {
  switch (key) {
    case RGFW_escape:       strcpy(dst, "escape"); break;
    case RGFW_return:       strcpy(dst, "return"); break;
    case RGFW_tab:          strcpy(dst, "tab"); break;
    case RGFW_backSpace:    strcpy(dst, "backspace"); break;
    case RGFW_delete:       strcpy(dst, "delete"); break;
    case RGFW_space:        strcpy(dst, "space"); break;
    case RGFW_F1:           strcpy(dst, "f1"); break;
    case RGFW_F2:           strcpy(dst, "f2"); break;
    case RGFW_F3:           strcpy(dst, "f3"); break;
    case RGFW_F4:           strcpy(dst, "f4"); break;
    case RGFW_F5:           strcpy(dst, "f5"); break;
    case RGFW_F6:           strcpy(dst, "f6"); break;
    case RGFW_F7:           strcpy(dst, "f7"); break;
    case RGFW_F8:           strcpy(dst, "f8"); break;
    case RGFW_F9:           strcpy(dst, "f9"); break;
    case RGFW_F10:          strcpy(dst, "f10"); break;
    case RGFW_F11:          strcpy(dst, "f11"); break;
    case RGFW_F12:          strcpy(dst, "f12"); break;
    case RGFW_capsLock:     strcpy(dst, "capslock"); break;
    case RGFW_shiftL:       strcpy(dst, "left shift"); break;
    case RGFW_shiftR:       strcpy(dst, "right shift"); break;
    case RGFW_controlL:     strcpy(dst, "left ctrl"); break;
    case RGFW_controlR:     strcpy(dst, "right ctrl"); break;
    case RGFW_altL:         strcpy(dst, "left alt"); break;
    case RGFW_altR:         strcpy(dst, "right alt"); break;
    case RGFW_superL:       strcpy(dst, "left gui"); break;
    case RGFW_superR:       strcpy(dst, "right gui"); break;
    case RGFW_up:           strcpy(dst, "up"); break;
    case RGFW_down:         strcpy(dst, "down"); break;
    case RGFW_left:         strcpy(dst, "left"); break;
    case RGFW_right:        strcpy(dst, "right"); break;
    case RGFW_insert:       strcpy(dst, "insert"); break;
    case RGFW_home:         strcpy(dst, "home"); break;
    case RGFW_end:          strcpy(dst, "end"); break;
    case RGFW_pageUp:       strcpy(dst, "pageup"); break;
    case RGFW_pageDown:     strcpy(dst, "pagedown"); break;
    case RGFW_numLock:      strcpy(dst, "numlock"); break;
    case RGFW_scrollLock:   strcpy(dst, "scrolllock"); break;
    case RGFW_printScreen:  strcpy(dst, "printscreen"); break;
    case RGFW_pause:        strcpy(dst, "pause"); break;
    case RGFW_menu:         strcpy(dst, "menu"); break;
    case RGFW_kpSlash:      strcpy(dst, "keypad /"); break;
    case RGFW_kpMultiply:   strcpy(dst, "keypad *"); break;
    case RGFW_kpPlus:       strcpy(dst, "keypad +"); break;
    case RGFW_kpMinus:      strcpy(dst, "keypad -"); break;
    case RGFW_kpPeriod:     strcpy(dst, "keypad ."); break;
    case RGFW_kpReturn:     strcpy(dst, "keypad enter"); break;
    case RGFW_kp0:          strcpy(dst, "keypad 0"); break;
    case RGFW_kp1:          strcpy(dst, "keypad 1"); break;
    case RGFW_kp2:          strcpy(dst, "keypad 2"); break;
    case RGFW_kp3:          strcpy(dst, "keypad 3"); break;
    case RGFW_kp4:          strcpy(dst, "keypad 4"); break;
    case RGFW_kp5:          strcpy(dst, "keypad 5"); break;
    case RGFW_kp6:          strcpy(dst, "keypad 6"); break;
    case RGFW_kp7:          strcpy(dst, "keypad 7"); break;
    case RGFW_kp8:          strcpy(dst, "keypad 8"); break;
    case RGFW_kp9:          strcpy(dst, "keypad 9"); break;
    default:
      /* printable ASCII keys */
      if (key >= 32 && key < 127) {
        dst[0] = tolower(key);
        dst[1] = '\0';
      } else {
        dst[0] = '?';
        dst[1] = '\0';
      }
      break;
  }
  return dst;
}


/* convert a Unicode codepoint to a UTF-8 string, return length */
static int codepoint_to_utf8(unsigned int cp, char *buf) {
  if (cp < 0x80) {
    buf[0] = cp;
    buf[1] = '\0';
    return 1;
  } else if (cp < 0x800) {
    buf[0] = 0xC0 | (cp >> 6);
    buf[1] = 0x80 | (cp & 0x3F);
    buf[2] = '\0';
    return 2;
  } else if (cp < 0x10000) {
    buf[0] = 0xE0 | (cp >> 12);
    buf[1] = 0x80 | ((cp >> 6) & 0x3F);
    buf[2] = 0x80 | (cp & 0x3F);
    buf[3] = '\0';
    return 3;
  } else if (cp < 0x110000) {
    buf[0] = 0xF0 | (cp >> 18);
    buf[1] = 0x80 | ((cp >> 12) & 0x3F);
    buf[2] = 0x80 | ((cp >> 6) & 0x3F);
    buf[3] = 0x80 | (cp & 0x3F);
    buf[4] = '\0';
    return 4;
  }
  buf[0] = '\0';
  return 0;
}


/* state for multi-file drops */
static char **pending_drop_files;
static size_t pending_drop_count;
static size_t pending_drop_idx;

/* last known mouse position (for file drop coordinates) */
static int last_mouse_x, last_mouse_y;


static int f_poll_event(lua_State *L) {
  char buf[64];
  RGFW_event e;

  /* emit pending file drops one at a time */
  if (pending_drop_files && pending_drop_idx < pending_drop_count) {
    lua_pushstring(L, "filedropped");
    lua_pushstring(L, pending_drop_files[pending_drop_idx++]);
    lua_pushnumber(L, last_mouse_x);
    lua_pushnumber(L, last_mouse_y);
    if (pending_drop_idx >= pending_drop_count) {
      pending_drop_files = NULL;
      pending_drop_count = 0;
      pending_drop_idx = 0;
    }
    return 4;
  }

top:
  if (!RGFW_window_checkEvent(window, &e)) {
    return 0;
  }

  switch (e.type) {
    case RGFW_quit:
      lua_pushstring(L, "quit");
      return 1;

    case RGFW_windowResized: {
      int ww, wh;
      RGFW_window_getSize(window, &ww, &wh);
      lua_pushstring(L, "resized");
      lua_pushnumber(L, ww);
      lua_pushnumber(L, wh);
      return 3;
    }

    case RGFW_windowRefresh:
      rencache_invalidate();
      lua_pushstring(L, "exposed");
      return 1;

    case RGFW_focusIn:
      goto top;

    case RGFW_focusOut:
      goto top;

    case RGFW_dataDrop:
      pending_drop_files = e.drop.files;
      pending_drop_count = e.drop.count;
      pending_drop_idx = 0;
      goto top;

    case RGFW_keyPressed:
      lua_pushstring(L, "keypressed");
      lua_pushstring(L, key_name(buf, e.key.value));
      return 2;

    case RGFW_keyReleased:
      lua_pushstring(L, "keyreleased");
      lua_pushstring(L, key_name(buf, e.key.value));
      return 2;

    case RGFW_keyChar: {
      char utf8[8];
      int len = codepoint_to_utf8(e.keyChar.value, utf8);
      if (len > 0 && e.keyChar.value >= 32) {
        lua_pushstring(L, "textinput");
        lua_pushstring(L, utf8);
        return 2;
      }
      goto top;
    }

    case RGFW_mouseButtonPressed:
      if (e.button.value == RGFW_mouseLeft) {
        RGFW_window_captureMouse(window, RGFW_TRUE);
      }
      lua_pushstring(L, "mousepressed");
      lua_pushstring(L, button_name(e.button.value));
      lua_pushnumber(L, last_mouse_x);
      lua_pushnumber(L, last_mouse_y);
      lua_pushnumber(L, 1); /* RGFW doesn't track click count */
      return 5;

    case RGFW_mouseButtonReleased:
      if (e.button.value == RGFW_mouseLeft) {
        RGFW_window_captureMouse(window, RGFW_FALSE);
      }
      lua_pushstring(L, "mousereleased");
      lua_pushstring(L, button_name(e.button.value));
      lua_pushnumber(L, last_mouse_x);
      lua_pushnumber(L, last_mouse_y);
      return 4;

    case RGFW_mousePosChanged:
      last_mouse_x = e.mouse.x;
      last_mouse_y = e.mouse.y;
      lua_pushstring(L, "mousemoved");
      lua_pushnumber(L, e.mouse.x);
      lua_pushnumber(L, e.mouse.y);
      lua_pushnumber(L, e.mouse.vecX);
      lua_pushnumber(L, e.mouse.vecY);
      return 5;

    case RGFW_mouseScroll:
      lua_pushstring(L, "mousewheel");
      lua_pushnumber(L, e.scroll.y);
      return 2;

    default:
      goto top;
  }

  return 0;
}


static int f_wait_event(lua_State *L) {
  double n = luaL_checknumber(L, 1);
  RGFW_waitForEvent((int)(n * 1000));
  lua_pushboolean(L, 1);
  return 1;
}


static const char *cursor_opts[] = {
  "arrow",
  "ibeam",
  "sizeh",
  "sizev",
  "hand",
  NULL
};

static const RGFW_mouseIcons cursor_enums[] = {
  RGFW_mouseArrow,
  RGFW_mouseIbeam,
  RGFW_mouseResizeEW,
  RGFW_mouseResizeNS,
  RGFW_mousePointingHand
};

static int f_set_cursor(lua_State *L) {
  int opt = luaL_checkoption(L, 1, "arrow", cursor_opts);
  RGFW_window_setMouseStandard(window, cursor_enums[opt]);
  return 0;
}


static int f_set_window_title(lua_State *L) {
  const char *title = luaL_checkstring(L, 1);
  RGFW_window_setName(window, title);
  return 0;
}


static const char *window_opts[] = { "normal", "maximized", "fullscreen", 0 };
enum { WIN_NORMAL, WIN_MAXIMIZED, WIN_FULLSCREEN };

static int f_set_window_mode(lua_State *L) {
  int n = luaL_checkoption(L, 1, "normal", window_opts);
  if (n == WIN_FULLSCREEN) {
    RGFW_window_setFullscreen(window, RGFW_TRUE);
  } else {
    RGFW_window_setFullscreen(window, RGFW_FALSE);
    if (n == WIN_NORMAL)    { RGFW_window_restore(window); }
    if (n == WIN_MAXIMIZED) { RGFW_window_maximize(window); }
  }
  return 0;
}


static int f_window_has_focus(lua_State *L) {
  lua_pushboolean(L, RGFW_window_isInFocus(window));
  return 1;
}


static int f_show_confirm_dialog(lua_State *L) {
  const char *title = luaL_checkstring(L, 1);
  const char *msg = luaL_checkstring(L, 2);
  int result = tinyfd_messageBox(title, msg, "yesno", "warning", 0);
  lua_pushboolean(L, result);
  return 1;
}


static int f_chdir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  int err = chdir(path);
  if (err) { luaL_error(L, "chdir() failed"); }
  return 0;
}


static int f_list_dir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);

  DIR *dir = opendir(path);
  if (!dir) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }

  lua_newtable(L);
  int i = 1;
  struct dirent *entry;
  while ( (entry = readdir(dir)) ) {
    if (strcmp(entry->d_name, "." ) == 0) { continue; }
    if (strcmp(entry->d_name, "..") == 0) { continue; }
    lua_pushstring(L, entry->d_name);
    lua_rawseti(L, -2, i);
    i++;
  }

  closedir(dir);
  return 1;
}


#ifdef _WIN32
  #include <windows.h>
  #define realpath(x, y) _fullpath(y, x, MAX_PATH)
#endif

static int f_absolute_path(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  char *res = realpath(path, NULL);
  if (!res) { return 0; }
  lua_pushstring(L, res);
  free(res);
  return 1;
}


static int f_get_file_info(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);

  struct stat s;
  int err = stat(path, &s);
  if (err < 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }

  lua_newtable(L);
  lua_pushnumber(L, s.st_mtime);
  lua_setfield(L, -2, "modified");

  lua_pushnumber(L, s.st_size);
  lua_setfield(L, -2, "size");

  if (S_ISREG(s.st_mode)) {
    lua_pushstring(L, "file");
  } else if (S_ISDIR(s.st_mode)) {
    lua_pushstring(L, "dir");
  } else {
    lua_pushnil(L);
  }
  lua_setfield(L, -2, "type");

  return 1;
}


static int f_get_clipboard(lua_State *L) {
  size_t len;
  const char *text = RGFW_readClipboard(&len);
  if (!text || len == 0) { return 0; }
  lua_pushstring(L, text);
  return 1;
}


static int f_set_clipboard(lua_State *L) {
  size_t len;
  const char *text = luaL_checklstring(L, 1, &len);
  RGFW_writeClipboard(text, len);
  return 0;
}


static int f_get_time(lua_State *L) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  double n = ts.tv_sec + ts.tv_nsec / 1e9;
  lua_pushnumber(L, n);
  return 1;
}


static int f_sleep(lua_State *L) {
  double n = luaL_checknumber(L, 1);
  struct timespec ts;
  ts.tv_sec = (time_t) n;
  ts.tv_nsec = (long)((n - ts.tv_sec) * 1e9);
  nanosleep(&ts, NULL);
  return 0;
}


static int f_exec(lua_State *L) {
  size_t len;
  const char *cmd = luaL_checklstring(L, 1, &len);
  char *buf = malloc(len + 32);
  if (!buf) { luaL_error(L, "buffer allocation failed"); }
#if _WIN32
  sprintf(buf, "cmd /c \"%s\"", cmd);
  WinExec(buf, SW_HIDE);
#else
  sprintf(buf, "%s &", cmd);
  int res = system(buf);
  (void) res;
#endif
  free(buf);
  return 0;
}


static int f_fuzzy_match(lua_State *L) {
  const char *str = luaL_checkstring(L, 1);
  const char *ptn = luaL_checkstring(L, 2);
  int score = 0;
  int run = 0;

  while (*str && *ptn) {
    while (*str == ' ') { str++; }
    while (*ptn == ' ') { ptn++; }
    if (tolower(*str) == tolower(*ptn)) {
      score += run * 10 - (*str != *ptn);
      run++;
      ptn++;
    } else {
      score -= 10;
      run = 0;
    }
    str++;
  }
  if (*ptn) { return 0; }

  lua_pushnumber(L, score - (int) strlen(str));
  return 1;
}


static const luaL_Reg lib[] = {
  { "poll_event",          f_poll_event          },
  { "wait_event",          f_wait_event          },
  { "set_cursor",          f_set_cursor          },
  { "set_window_title",    f_set_window_title    },
  { "set_window_mode",     f_set_window_mode     },
  { "window_has_focus",    f_window_has_focus    },
  { "show_confirm_dialog", f_show_confirm_dialog },
  { "chdir",               f_chdir               },
  { "list_dir",            f_list_dir            },
  { "absolute_path",       f_absolute_path       },
  { "get_file_info",       f_get_file_info       },
  { "get_clipboard",       f_get_clipboard       },
  { "set_clipboard",       f_set_clipboard       },
  { "get_time",            f_get_time            },
  { "sleep",               f_sleep               },
  { "exec",                f_exec                },
  { "fuzzy_match",         f_fuzzy_match         },
  { NULL, NULL }
};


int luaopen_system(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}
