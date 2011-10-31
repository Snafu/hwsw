#ifndef _image_h_
#define _image_h_

#include <stdint.h>

typedef struct {
  uint8_t r;
  uint8_t g;
  uint8_t b;
} rgb_color_t;

typedef struct {
  float y;
  float cb;
  float cr;
} ycbcr_color_t;

typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t dataLength;
  unsigned char *data;
} image_t;

rgb_color_t getRGBColorValue(image_t *i, int x, int y);
ycbcr_color_t getYCbCrColorValue(image_t *i, int x, int y);

#endif // _image_h_
