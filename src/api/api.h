#ifndef API_H
#define API_H

#include "lib/lua55/lua.h"
#include "lib/lua55/lauxlib.h"
#include "lib/lua55/lualib.h"

#define API_TYPE_FONT "Font"
#define API_TYPE_IMAGE "Image"

void api_load_libs(lua_State *L);

#endif
