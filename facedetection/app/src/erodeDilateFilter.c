#include "filters.h"
#include "image.h"

#define WINDOW_LENGTH 5
#define WINDOW_OFFSET ((WINDOW_LENGTH-1)/2)
#define BACKGROUND_COLOR_R   0
#define BACKGROUND_COLOR_G   0
#define BACKGROUND_COLOR_B   0
#define FOREGROUND_COLOR_R   0xff
#define FOREGROUND_COLOR_G   0xff
#define FOREGROUND_COLOR_B   0xff


void erodeDilateFilter(image_t *inputImage, image_t *outputImage, uint8_t op)
{
  int x, y, dx, dy, wx, wy;
  int pIndex;
  rgb_color_t c, compare;
  uint8_t foundMatch;

  if (op == FILTER_ERODE) {
    // erode: look for neighbor pixels in background color
    compare.r = BACKGROUND_COLOR_R;
    compare.g = BACKGROUND_COLOR_G;
    compare.b = BACKGROUND_COLOR_B;
  }
  else {
    // dilate: look for neighbor pixels in foreground color
    compare.r = FOREGROUND_COLOR_R;
    compare.g = FOREGROUND_COLOR_G;
    compare.b = FOREGROUND_COLOR_B;
  }

  for (y = 0; y < inputImage->height; ++y) {
    for (x = 0; x < inputImage->width; ++x) {  

      foundMatch = 0;
      for (dy = -WINDOW_OFFSET; dy <= WINDOW_OFFSET; ++dy) {
	wy = y+dy;
	if (wy >= 0 && wy < inputImage->height) {
	  for (dx = -WINDOW_OFFSET; dx <= WINDOW_OFFSET; ++dx) {
	    wx = x+dx;
	    if (wx >= 0 && wx < inputImage->width) {
	      pIndex = (wy*inputImage->width + wx)*3;
	      c.b = inputImage->data[pIndex];
	      c.g = inputImage->data[pIndex + 1];
	      c.r = inputImage->data[pIndex + 2];
	      if (c.r == compare.r && c.g == compare.g && c.b == compare.b) {
		foundMatch = 1;
		break;
	      }
	    }
	  }
	}
	if (foundMatch) {
	  break;
	}
      }

      pIndex = (y*inputImage->width+x)*3;      
      
      // default: set background color
      outputImage->data[pIndex] = 0x00;
      outputImage->data[pIndex+1] = 0x00;
      outputImage->data[pIndex+2] = 0x00;

      if ((op == FILTER_ERODE && !foundMatch) ||
	  (op == FILTER_DILATE && foundMatch)) {
	// set output pixel white
	outputImage->data[pIndex] = 0xFF;
	outputImage->data[pIndex+1] = 0xFF;
	outputImage->data[pIndex+2] = 0xFF;
      }

    }
  }
}
