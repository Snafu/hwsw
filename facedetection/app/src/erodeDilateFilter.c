#include "filters.h"
#include <string.h>
#include "image.h"

#define WINDOW_LENGTH 5
#define WINDOW_OFFSET ((WINDOW_LENGTH-1)/2)
#define BACKGROUND_COLOR_R   0
#define BACKGROUND_COLOR_G   0
#define BACKGROUND_COLOR_B   0
#define FOREGROUND_COLOR_R   0xff
#define FOREGROUND_COLOR_G   0xff
#define FOREGROUND_COLOR_B   0xff

#define ERODE_COMPARE				0
#define DILATE_COMPARE			0xff



void erodeFilter(volatile char *framebuffer, image_t *outputImage)
{
  int x, y, dx, dy;
  uint8_t foundMatch;
	
	volatile char *lineptr = framebuffer + 3;
	volatile char *woffsetptr; // 1st row, 1st col
	volatile char *winptr;
	
	unsigned char *outptr = outputImage->data + (800<<1) + 2; // 3rd row, 3rd col
	
	for (y = WINDOW_OFFSET; y < 480 - WINDOW_OFFSET; ++y)
	{ // 2..478
		woffsetptr = lineptr;
		for (x = WINDOW_OFFSET; x < 800 - WINDOW_OFFSET; ++x)
		{  // 2..798
			foundMatch = 0;
			
			winptr = woffsetptr;
			for (dy = -WINDOW_OFFSET; dy <= WINDOW_OFFSET; ++dy)
			{ // -2..2
				
				for (dx = -WINDOW_OFFSET; dx <= WINDOW_OFFSET; ++dx)
				{ // -2..2
					if(*(winptr+3) == ERODE_COMPARE)
					{
						foundMatch = 1;
						break;
					}
					winptr += 1<<2;
				} // for dx
				
				winptr += (800<<2) - 20;
				if (foundMatch) {
					break;
				}
			} // for dy
			
			
			if (!foundMatch)
				*outptr = 0xFF;
			else
				*outptr = 0;
			
			outptr++;
			woffsetptr += 1<<2;
		} // for x
		
		outptr += 4; // from prev line to next line, 3rd pixel
		lineptr += 800<<2; // next line, 1st pixel
	} // for y
}


void dilateFilter(image_t *inputImage, image_t *outputImage)
{
	int x, y, dx, dy;
	uint8_t foundMatch;
	
	int hX, hY, histX[480], histY[800];

	unsigned char *lineptr = inputImage->data;
	unsigned char *woffsetptr; // 1st row, 1st col
	unsigned char *winptr;
	
	unsigned char *outptr = outputImage->data + (800<<1) + 2; // 3rd row, 3rd col
	
	memset(histX, 0, 480);
	memset(histY, 0, 800);

	hX = 2;
	hY = 2;

	for (y = WINDOW_OFFSET; y < 480 - WINDOW_OFFSET; ++y)
	{ // 2..478
		woffsetptr = lineptr;
		for (x = WINDOW_OFFSET; x < 800 - WINDOW_OFFSET; ++x)
		{  // 2..798
			foundMatch = 0;
			
			winptr = woffsetptr;
			for (dy = -WINDOW_OFFSET; dy <= WINDOW_OFFSET; ++dy)
			{ // -2..2
				for (dx = -WINDOW_OFFSET; dx <= WINDOW_OFFSET; ++dx)
				{ // -2..2
					if(*winptr == DILATE_COMPARE)
					{
						foundMatch = 1;
						break;
					}
					winptr += 1;
				} // for dx
				
				winptr += 800 - 20;
				if (foundMatch)
				{
					break;
				}
			} // for dy
			
			if (foundMatch)
			{
				*outptr = 0xFF;
				histY[hY]++;
				histY[hX]++;
				// draw histogramm
				
			}
			else
			{
				*outptr = 0;
			}
				
			hX++;
			outptr++;
			woffsetptr += 1;
		} // for x
	
		hX = 2;
		hY++;
		outptr += 4; // from prev line to next line, 3rd pixel
		lineptr += 800; // next line, 1st pixel
	} // for y
}
