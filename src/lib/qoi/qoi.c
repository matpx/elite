#include "lib/rpmalloc/rpmalloc.h"
#define QOI_MALLOC(sz) rpmalloc(sz)
#define QOI_FREE(p)    rpfree(p)
#define QOI_IMPLEMENTATION
#include "qoi.h"
