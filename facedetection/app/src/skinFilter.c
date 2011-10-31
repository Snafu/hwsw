#include "filters.h"
#include "image.h"

#define Y_LOW	38 	/* 0.10f */
#define CB_LOW	94	/* -0.15f */
#define CR_LOW	139	/* 0.05f */

#define Y_HIGH	235	/* 1.00f */
#define CB_HIGH	139	/* 0.05f */
#define CR_HIGH	173	/* 0.20f */


void skinFilter(image_t *inputImage, image_t *outputImage)
{
  int x, y;
  for (y = 0; y < inputImage->height; ++y) {
    for (x = 0; x < inputImage->width; ++x) {  
      ycbcr_color_t ycbcr = getYCbCrColorValue(inputImage, x, y);
      int pIndex = (y*inputImage->width+x)*3;

      if (ycbcr.y >= Y_LOW && ycbcr.y <= Y_HIGH
	  && ycbcr.cb >= CB_LOW && ycbcr.cb <= CB_HIGH
	  && ycbcr.cr >= CR_LOW && ycbcr.cr <= CR_HIGH) {
	// set output pixel white
	outputImage->data[pIndex] = 0xFF;
	outputImage->data[pIndex+1] = 0xFF;
	outputImage->data[pIndex+2] = 0xFF;
      }
      else {
	// set output pixel black
	outputImage->data[pIndex] = 0x00;
	outputImage->data[pIndex+1] = 0x00;
	outputImage->data[pIndex+2] = 0x00;
      }
    }
  }
}


