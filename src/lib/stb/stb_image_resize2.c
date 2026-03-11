#include "lib/rpmalloc/rpmalloc.h"
#define STBIR_MALLOC(sz,ud) ((void)(ud),rpmalloc(sz))
#define STBIR_FREE(p,ud)    ((void)(ud),rpfree(p))
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize2.h"
