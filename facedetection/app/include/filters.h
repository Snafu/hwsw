#ifndef _filters_h_
#define _filters_h_

#include "image.h"

#define FRAME_WIDTH					800
#define FRAME_HEIGHT				480
#define FRAME_SKIP					10

#define FRAME_WIDTH						800
#define FRAME_HEIGHT					480
#define FRAME_SKIP						10

#define IMAGE_WIDTH						(FRAME_WIDTH/FRAME_SKIP)
#define IMAGE_HEIGHT					(FRAME_HEIGHT/FRAME_SKIP)

#define WINDOW_LENGTH					7
#define WINDOW_OFFSET					((WINDOW_LENGTH-1)/2)

#define DILATE_WINDOW_LENGTH	3
#define DILATE_WINDOW_OFFSET	((DILATE_WINDOW_LENGTH-1)/2)

#define HISTX_LEN							(IMAGE_WIDTH)
#define HISTY_LEN							(IMAGE_HEIGHT)

extern int histX[HISTX_LEN];
extern int histY[HISTY_LEN];
extern int maxHistX, maxHistY;

#ifndef __SCARTS_32__
void skinFilter(image_t *inputImage, image_t *outputImage);
#endif
void erodeFilter(volatile uint32_t *inputImage, image_t *outputImage);
void dilateFilter(image_t *inputImage, image_t *outputImage);


#endif // _filters_h_
