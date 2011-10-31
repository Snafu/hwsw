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

	result.y = 16 + (66*c1.r)/256 + (129*c1.g)/256 + (25*c1.b)/256;
	result.cb = 128 - (38*c1.r)/256 - (74*c1.g)/256 + (112*c1.b)/256;
	result.cr = 128 + (112*c1.r)/256 - (94*c1.g)/256 - (18*c1.b)/256;

	return result;
}
