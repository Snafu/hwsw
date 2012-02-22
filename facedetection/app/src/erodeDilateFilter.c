#include <string.h>
#include "filters.h"
#include "image.h"
#include "dispctrl.h"

#define WINDOW_LENGTH				5
#define WINDOW_OFFSET				((WINDOW_LENGTH-1)/2)

#define ERODE_COMPARE				0
#define DILATE_COMPARE			0xff

#define IMAGE_WIDTH					800
#define IMAGE_HEIGHT				480

#define SKINBYTE_OFFSET			3

int histX[HISTX_LEN], histY[HISTY_LEN];
int maxHistX, maxHistY;

void erodeFilter(volatile char *framebuffer, image_t *outputImage)
{
  int x, y, dx, dy;
  uint8_t foundMatch;
	
	volatile char *lineptr = framebuffer + SKINBYTE_OFFSET;
	volatile char *woffsetptr;
	volatile char *winptr;
	
	unsigned char *outlineptr = outputImage->data + (IMAGE_WIDTH+1)*WINDOW_OFFSET;
	unsigned char *outptr;
	
	for (y = 0; y < IMAGE_HEIGHT - WINDOW_LENGTH + 1; ++y)
	{
		woffsetptr = lineptr;
		outptr = outlineptr;
		for (x = 0; x < IMAGE_WIDTH - WINDOW_LENGTH + 1; ++x)
		{
			foundMatch = 0;
			
			winptr = woffsetptr;
			for (dy = 0; dy < WINDOW_LENGTH; ++dy)
			{
				
				for (dx = 0; dx < WINDOW_LENGTH; ++dx)
				{
					if(*winptr == ERODE_COMPARE)
					{
						foundMatch = 1;
						break;
					}
					winptr += 4;
				} // for dx
				
				winptr += (IMAGE_WIDTH - WINDOW_LENGTH)*4;
				if (foundMatch) {
					break;
				}
			} // for dy
			
			
			if (!foundMatch)
				*outptr = 0xFF;
			else
				*outptr = 0;
			
			outptr++;
			woffsetptr += 4;
		} // for x
		
		// go to next line
		outlineptr += IMAGE_WIDTH;
		lineptr += IMAGE_WIDTH*4;
	} // for y
}


void dilateFilter(image_t *inputImage, image_t *outputImage)
{
	int x, y, dx, dy;
	uint8_t foundMatch;
	
	int hX, hY;

	unsigned char *lineptr = inputImage->data;
	unsigned char *woffsetptr;
	unsigned char *winptr;
	
	unsigned char *outlineptr = outputImage->data + (IMAGE_WIDTH+1)*WINDOW_OFFSET;
	unsigned char *outptr;
	
	memset(histX, 0, HISTX_LEN);
	memset(histY, 0, HISTY_LEN);
	maxHistX = 0;
	maxHistY = 0;

	hX = 0;
	hY = 0;

	for (y = 0; y < IMAGE_HEIGHT - WINDOW_LENGTH + 1; ++y)
	{
		woffsetptr = lineptr;
		outptr = outlineptr;

		for (x = 0; x < IMAGE_WIDTH - WINDOW_LENGTH + 1; ++x)
		{
			foundMatch = 0;
			
			winptr = woffsetptr;
			for (dy = 0; dy < WINDOW_LENGTH; ++dy)
			{
				for (dx = 0; dx < WINDOW_LENGTH; ++dx)
				{
					if(*winptr == DILATE_COMPARE)
					{
						foundMatch = 1;
						break;
					}
					winptr++;
				} // for dx
				
				winptr += IMAGE_WIDTH - WINDOW_LENGTH;
				if (foundMatch)
				{
					break;
				}
			} // for dy
			
			if(foundMatch)
			{
				*outptr = 0xFF;
				histY[hY]++;
				histY[hX]++;
			}
			else
			{
				*outptr = 0;
			}
			
			// save histY maximum
			if((y == IMAGE_HEIGHT - WINDOW_LENGTH) && (histY[hX] > maxHistY))
				maxHistY = histY[hX];
				
			hX++;
			outptr++;
			woffsetptr++;
		} // for x

		// save histX maximum
		if(histX[hY] > maxHistX)
			maxHistX = histX[hY];
	
		hX = 0;
		hY++;

		// go to next line
		outlineptr += IMAGE_WIDTH;
		lineptr += IMAGE_WIDTH;
	} // for y
}
