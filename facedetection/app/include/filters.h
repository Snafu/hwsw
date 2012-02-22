#ifndef _filters_h_
#define _filters_h_

#include "image.h"

#define HISTX_LEN			(800-4)
#define HISTY_LEN			(480-4)

extern int histX[HISTX_LEN];
extern int histY[HISTY_LEN];
extern int maxHistX, maxHistY;

void skinFilter(image_t *inputImage, image_t *outputImage);
void erodeFilter(volatile char *inputImage, image_t *outputImage);
void dilateFilter(image_t *inputImage, image_t *outputImage);


#endif // _filters_h_
