#include "api.h"
#include "renderer.h"
#include "rencache.h"


static int f_load(lua_State *L) {
  const char *filename = luaL_checkstring(L, 1);
  RenImage **self = lua_newuserdata(L, sizeof(*self));
  luaL_setmetatable(L, API_TYPE_IMAGE);
  *self = ren_load_image(filename);
  if (!*self) { luaL_error(L, "failed to load image: %s", filename); }
  return 1;
}


static int f_get_width(lua_State *L) {
  RenImage **self = luaL_checkudata(L, 1, API_TYPE_IMAGE);
  lua_pushnumber(L, ren_get_image_width(*self));
  return 1;
}


static int f_get_height(lua_State *L) {
  RenImage **self = luaL_checkudata(L, 1, API_TYPE_IMAGE);
  lua_pushnumber(L, ren_get_image_height(*self));
  return 1;
}


static int f_resize(lua_State *L) {
  RenImage **self = luaL_checkudata(L, 1, API_TYPE_IMAGE);
  int w = luaL_checknumber(L, 2);
  int h = luaL_checknumber(L, 3);
  RenImage **out = lua_newuserdata(L, sizeof(*out));
  luaL_setmetatable(L, API_TYPE_IMAGE);
  *out = ren_resize_image(*self, w, h);
  return 1;
}


static int f_gc(lua_State *L) {
  RenImage **self = luaL_checkudata(L, 1, API_TYPE_IMAGE);
  if (*self) { ren_free_image(*self); *self = NULL; }
  return 0;
}


static const luaL_Reg lib[] = {
  { "__gc",       f_gc         },
  { "load",       f_load       },
  { "get_width",  f_get_width  },
  { "get_height", f_get_height },
  { "resize",     f_resize     },
  { NULL, NULL }
};

int luaopen_renderer_image(lua_State *L) {
  luaL_newmetatable(L, API_TYPE_IMAGE);
  luaL_setfuncs(L, lib, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  return 1;
}
