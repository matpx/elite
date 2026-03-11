#include "lib/rpmalloc/rpmalloc.h"
#define STBTT_malloc(x,u)  ((void)(u),rpmalloc(x))
#define STBTT_free(x,u)    ((void)(u),rpfree(x))
#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
