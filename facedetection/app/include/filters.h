#ifndef _filters_h_
#define _filters_h_

#include "image.h"

#define FILTER_ERODE   0
#define FILTER_DILATE  1

void skinFilter(image_t *inputImage, image_t *outputImage);
void erodeFilter(volatile char *inputImage, image_t *outputImage);
void dilateFilter(image_t *inputImage, image_t *outputImage);


#endif // _filters_h_
