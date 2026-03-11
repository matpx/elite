#include "lib/rpmalloc/rpmalloc.h"
#define STBI_MALLOC(sz)              rpmalloc(sz)
#define STBI_REALLOC(p,newsz)        rprealloc(p,newsz)
#define STBI_REALLOC_SIZED(p,o,newsz) rprealloc(p,newsz)
#define STBI_FREE(p)                 rpfree(p)
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
