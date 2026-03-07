#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>
#include <SDL3_ttf/SDL_ttf.h>
#include "lib/stb/stb_image.h"
#include "lib/qoi/qoi.h"
#include "lib/stb/stb_image_resize2.h"
#include "renderer.h"

#define MAX_GLYPHSET 256
#define CACHE_SIZE 256

struct RenImage {
  RenColor *pixels;
  int width, height;
};

typedef struct {
  RenImage *image;
  int advance;
} CachedGlyph;

typedef struct {
  CachedGlyph glyphs[256];
} GlyphSet;

struct RenFont {
  TTF_Font *font;
  GlyphSet *sets[MAX_GLYPHSET];
  float size;
  int height;
  int tab_width;
};


static SDL_Window *window;
static struct { int left, top, right, bottom; } clip;


static void* check_alloc(void *ptr) {
  if (!ptr) {
    fprintf(stderr, "Fatal error: memory allocation failed\n");
    exit(EXIT_FAILURE);
  }
  return ptr;
}


static const char* utf8_to_codepoint(const char *p, unsigned *dst) {
  unsigned char c = *p;
  unsigned res, n;
  switch (c & 0xf0) {
    case 0xf0 :  res = c & 0x07;  n = 3;  break;
    case 0xe0 :  res = c & 0x0f;  n = 2;  break;
    case 0xd0 :
    case 0xc0 :  res = c & 0x1f;  n = 1;  break;
    default   :  res = c;         n = 0;  break;
  }
  while (n--) {
    if ((*(p + 1) & 0xc0) != 0x80) {
      *dst = c;
      return p + 1;
    }
    res = (res << 6) | (*(++p) & 0x3f);
  }
  *dst = res;
  return p + 1;
}


void ren_init(SDL_Window *win) {
  assert(win);
  window = win;
  TTF_Init();
  SDL_Surface *surf = SDL_GetWindowSurface(window);
  ren_set_clip_rect( (RenRect) { 0, 0, surf->w, surf->h } );
}


void ren_update_rects(RenRect *rects, int count) {
  SDL_UpdateWindowSurfaceRects(window, (SDL_Rect*) rects, count);
  static bool initial_frame = true;
  if (initial_frame) {
    SDL_ShowWindow(window);
    initial_frame = false;
  }
}


void ren_set_clip_rect(RenRect rect) {
  clip.left   = rect.x;
  clip.top    = rect.y;
  clip.right  = rect.x + rect.width;
  clip.bottom = rect.y + rect.height;
}


void ren_get_size(int *x, int *y) {
  SDL_Surface *surf = SDL_GetWindowSurface(window);
  *x = surf->w;
  *y = surf->h;
}


RenImage* ren_new_image(int width, int height) {
  assert(width > 0 && height > 0);
  RenImage *image = malloc(sizeof(RenImage) + (size_t) width * height * sizeof(RenColor));
  check_alloc(image);
  image->pixels = (void*) (image + 1);
  image->width = width;
  image->height = height;
  return image;
}


RenImage* ren_load_image(const char *filename) {
  int w, h, n;
  unsigned char *data = NULL;

  const char *ext = strrchr(filename, '.');
  const bool is_qoi = ext && strcmp(ext, ".qoi") == 0;

  if (is_qoi) {
    qoi_desc desc;
    data = qoi_read(filename, &desc, 4);
    if (!data) { return NULL; }
    w = desc.width;
    h = desc.height;
  } else {
    data = stbi_load(filename, &w, &h, &n, 4);
    if (!data) { return NULL; }
  }

  RenImage *image = ren_new_image(w, h);
  if (!image) { free(data); return NULL; }

  RenColor *dst = image->pixels;
  unsigned char *src = data;
  for (int i = 0; i < w * h; i++) {
    dst[i] = (RenColor){ .r = src[0], .g = src[1], .b = src[2], .a = src[3] };
    src += 4;
  }

  if (is_qoi) {
    free(data);
  } else {
    stbi_image_free(data);
  }
  return image;
}


RenImage* ren_resize_image(RenImage *image, int new_w, int new_h) {
  RenImage *resized = ren_new_image(new_w, new_h);
  if (!resized) { return NULL; }
  unsigned char *result = stbir_resize_uint8_linear(
    (unsigned char *)image->pixels, image->width, image->height, image->width * 4,
    (unsigned char *)resized->pixels, new_w, new_h, new_w * 4,
    STBIR_BGRA);
  if (!result) { ren_free_image(resized); return NULL; }
  return resized;
}


void ren_free_image(RenImage *image) {
  free(image);
}


int ren_get_image_width(RenImage *image) {
  return image->width;
}


int ren_get_image_height(RenImage *image) {
  return image->height;
}


static RenImage* surface_to_renimage(SDL_Surface *surf) {
  SDL_Surface *converted = SDL_ConvertSurface(surf, SDL_PIXELFORMAT_ARGB8888);
  if (!converted) return NULL;

  RenImage *image = ren_new_image(converted->w, converted->h);
  uint8_t *src = (uint8_t *)converted->pixels;
  uint8_t *dst = (uint8_t *)image->pixels;
  int row_bytes = converted->w * 4;
  for (int row = 0; row < converted->h; row++) {
    memcpy(dst + row * row_bytes, src + row * converted->pitch, row_bytes);
  }
  SDL_DestroySurface(converted);
  return image;
}


static GlyphSet* load_glyphset(RenFont *font, int idx) {
  GlyphSet *set = check_alloc(calloc(1, sizeof(GlyphSet)));
  SDL_Color white = {255, 255, 255, 255};

  for (int i = 0; i < 256; i++) {
    Uint32 cp = idx * 256 + i;
    int advance;
    if (!TTF_GetGlyphMetrics(font->font, cp, NULL, NULL, NULL, NULL, &advance)) {
      continue;
    }
    set->glyphs[i].advance = advance;

    SDL_Surface *surf = TTF_RenderGlyph_Blended(font->font, cp, white);
    if (!surf) continue;

    set->glyphs[i].image = surface_to_renimage(surf);
    SDL_DestroySurface(surf);
  }

  return set;
}


static GlyphSet* get_glyphset(RenFont *font, int codepoint) {
  int idx = (codepoint >> 8) % MAX_GLYPHSET;
  if (!font->sets[idx]) {
    font->sets[idx] = load_glyphset(font, idx);
  }
  return font->sets[idx];
}


RenFont* ren_load_font(const char *filename, float size) {
  RenFont *font = check_alloc(calloc(1, sizeof(RenFont)));
  font->size = size;

  font->font = TTF_OpenFont(filename, size);
  if (!font->font) {
    free(font);
    return NULL;
  }

  font->height = TTF_GetFontHeight(font->font);

  /* initialize tab/newline: zero advance, no image */
  GlyphSet *set = get_glyphset(font, '\n');
  set->glyphs['\t'].advance = 0;
  set->glyphs['\n'].advance = 0;

  return font;
}


void ren_free_font(RenFont *font) {
  for (int i = 0; i < MAX_GLYPHSET; i++) {
    GlyphSet *set = font->sets[i];
    if (set) {
      for (int j = 0; j < 256; j++) {
        if (set->glyphs[j].image) {
          ren_free_image(set->glyphs[j].image);
        }
      }
      free(set);
    }
  }
  TTF_CloseFont(font->font);
  free(font);
}


void ren_set_font_tab_width(RenFont *font, int n) {
  GlyphSet *set = get_glyphset(font, '\t');
  set->glyphs['\t'].advance = n;
}


int ren_get_font_tab_width(RenFont *font) {
  GlyphSet *set = get_glyphset(font, '\t');
  return set->glyphs['\t'].advance;
}


int ren_get_font_width(RenFont *font, const char *text) {
  int x = 0;
  const char *p = text;
  unsigned codepoint;
  while (*p) {
    p = utf8_to_codepoint(p, &codepoint);
    GlyphSet *set = get_glyphset(font, codepoint);
    CachedGlyph *g = &set->glyphs[codepoint & 0xff];
    x += g->advance;
  }
  return x;
}


int ren_get_font_height(RenFont *font) {
  return font->height;
}


static inline RenColor blend_pixel(RenColor dst, RenColor src) {
  int ia = 0xff - src.a;
  dst.r = ((src.r * src.a) + (dst.r * ia)) >> 8;
  dst.g = ((src.g * src.a) + (dst.g * ia)) >> 8;
  dst.b = ((src.b * src.a) + (dst.b * ia)) >> 8;
  return dst;
}


static inline RenColor blend_pixel2(RenColor dst, RenColor src, RenColor color) {
  src.a = (src.a * color.a) >> 8;
  int ia = 0xff - src.a;
  dst.r = ((src.r * color.r * src.a) >> 16) + ((dst.r * ia) >> 8);
  dst.g = ((src.g * color.g * src.a) >> 16) + ((dst.g * ia) >> 8);
  dst.b = ((src.b * color.b * src.a) >> 16) + ((dst.b * ia) >> 8);
  return dst;
}


#define rect_draw_loop(expr)        \
  for (int j = y1; j < y2; j++) {   \
    for (int i = x1; i < x2; i++) { \
      *d = expr;                    \
      d++;                          \
    }                               \
    d += dr;                        \
  }

void ren_draw_rect(RenRect rect, RenColor color) {
  if (color.a == 0) { return; }

  int x1 = rect.x < clip.left ? clip.left : rect.x;
  int y1 = rect.y < clip.top  ? clip.top  : rect.y;
  int x2 = rect.x + rect.width;
  int y2 = rect.y + rect.height;
  x2 = x2 > clip.right  ? clip.right  : x2;
  y2 = y2 > clip.bottom ? clip.bottom : y2;

  SDL_Surface *surf = SDL_GetWindowSurface(window);
  RenColor *d = (RenColor*) surf->pixels;
  d += x1 + y1 * surf->w;
  int dr = surf->w - (x2 - x1);

  if (color.a == 0xff) {
    rect_draw_loop(color);
  } else {
    rect_draw_loop(blend_pixel(*d, color));
  }
}


void ren_draw_image(RenImage *image, RenRect *sub, int x, int y, RenColor color) {
  if (color.a == 0) { return; }

  /* clip */
  int n;
  if ((n = clip.left - x) > 0) { sub->width  -= n; sub->x += n; x += n; }
  if ((n = clip.top  - y) > 0) { sub->height -= n; sub->y += n; y += n; }
  if ((n = x + sub->width  - clip.right ) > 0) { sub->width  -= n; }
  if ((n = y + sub->height - clip.bottom) > 0) { sub->height -= n; }

  if (sub->width <= 0 || sub->height <= 0) {
    return;
  }

  /* draw */
  SDL_Surface *surf = SDL_GetWindowSurface(window);
  RenColor *s = image->pixels;
  RenColor *d = (RenColor*) surf->pixels;
  s += sub->x + sub->y * image->width;
  d += x + y * surf->w;
  int sr = image->width - sub->width;
  int dr = surf->w - sub->width;

  for (int j = 0; j < sub->height; j++) {
    for (int i = 0; i < sub->width; i++) {
      *d = blend_pixel2(*d, *s, color);
      d++;
      s++;
    }
    d += dr;
    s += sr;
  }
}


int ren_draw_text(RenFont *font, const char *text, int x, int y, RenColor color) {
  const char *p = text;
  unsigned codepoint;
  while (*p) {
    p = utf8_to_codepoint(p, &codepoint);
    GlyphSet *set = get_glyphset(font, codepoint);
    CachedGlyph *g = &set->glyphs[codepoint & 0xff];
    if (g->image) {
      RenRect rect = { 0, 0, g->image->width, g->image->height };
      ren_draw_image(g->image, &rect, x, y, color);
    }
    x += g->advance;
  }
  return x;
}
