#include "image.h"

rgb_color_t getRGBColorValue(image_t *i, int x, int y)
{
  rgb_color_t result;
  int pIndex = (y*i->width+x)*3;
  result.b = i->data[pIndex];
  result.g = i->data[pIndex+1];
  result.r = i->data[pIndex+2];
  return result;
}

ycbcr_color_t getYCbCrColorValue(image_t *i, int x, int y)
{  
  rgb_color_t c1 = getRGBColorValue(i, x, y);
  ycbcr_color_t result;

  const float f = 1.0f / 255.0f;
  float rf = c1.r * f;
  float gf = c1.g * f;
  float bf = c1.b * f; 

  result.y = 0.299f * rf + 0.587f * gf + 0.114f * bf;
  result.cb = -0.168736f * rf + -0.331264f * gf + 0.5f * bf;
  result.cr = 0.5f * rf + -0.418688f * gf + -0.081312f * bf;

  return result;
}
