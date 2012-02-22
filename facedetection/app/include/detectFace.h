#ifndef _detectFace_h_
#define _detectFace_h_

#include "image.h"

typedef struct {
  uint16_t topLeftX;
  uint16_t topLeftY;
  uint16_t bottomRightX;
  uint16_t bottomRightY;
} rect_t;

int detectFace(rect_t *resultRect);

#endif // _detectFace_h_
