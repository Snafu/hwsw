#include <string.h>
#include <stdio.h>
#include "filters.h"
#include "image.h"
#include "dispctrl.h"
#include "multiplier.h"


#define ERODE_COMPARE				0x01000000
#define DILATE_COMPARE			0xff


int histX[HISTX_LEN], histY[HISTY_LEN];
int maxHistX, maxHistY;
int maxX, maxY;

static int *pHistX;
static int *pHistY;


void erodeFilter(volatile uint32_t *framebuffer, image_t *outputImage)
{
  int x, y, dx, dy;
  uint8_t foundMatch;
	
	volatile uint32_t *pLineIn = framebuffer + (FRAME_SKIP - WINDOW_LENGTH)/2;
	volatile uint32_t *pWinStart;
	volatile uint32_t *pWindow;

	unsigned char *pOut = outputImage->data;

	pHistX = histX;
	pHistY = histY;
	
	for (y = 0; y < IMAGE_HEIGHT; ++y)
	{
		pWinStart = pLineIn;
		for (x = 0; x < IMAGE_WIDTH; ++x)
		{
			pWindow = pWinStart;
			foundMatch = 0;
			
			for (dy = -WINDOW_OFFSET; dy <= WINDOW_OFFSET; ++dy)
			{
				for (dx = -WINDOW_OFFSET; dx <= WINDOW_OFFSET; ++dx)
				{
						if(*pWindow < ERODE_COMPARE)
						{
							foundMatch = 1;
							break;
						}
						
						pWindow++;
				} // for dx
				
				if (foundMatch) {
					break;
				}

				pWindow += FRAME_WIDTH - WINDOW_LENGTH;

			} // for dy
			
			
			if (!foundMatch) {
				*pOut = 0xFF;
			}
			else {
				*pOut = 0;
			}
			
			pOut++;
			pWinStart += FRAME_SKIP;
		} // for x
		
		// go to next line
		pLineIn += FRAME_WIDTH*FRAME_SKIP;

		// clear histogram
		*pHistY++ = 0;
		*pHistX++ = 0;
	} // for y
}


void dilateFilter(image_t *inputImage, image_t *outputImage)
{
	int x, y, dx, dy;
	uint8_t foundMatch;
	
	unsigned char *pIn = inputImage->data;
	unsigned char *pWindow = inputImage->data;
	
	unsigned char *pOut = outputImage->data;




	// clear remaining histogram
	for(pHistX = &histX[HISTY_LEN]; pHistX < &histX[HISTX_LEN]; pHistX++)
		*pHistX = 0;
	maxHistX = 0;
	maxHistY = 0;
	maxX = 0;
	maxY = 0;

	pHistY = histY;
	for (y = 0; y < IMAGE_HEIGHT; ++y)
	{
		pHistX = histX;
		for (x = 0; x < IMAGE_WIDTH; ++x)
		{
			foundMatch = 0;

			for (dy = -DILATE_WINDOW_OFFSET; dy <= DILATE_WINDOW_OFFSET && (y+dy) < IMAGE_HEIGHT; ++dy)
			{
				for (dx = -DILATE_WINDOW_OFFSET; dx <= DILATE_WINDOW_OFFSET && (x+dx) < IMAGE_WIDTH; ++dx)
				{
					if(((dx + x) >= 0) && ((dy + y) >= 0))
					{
						pWindow = pIn + multiply(dy, IMAGE_WIDTH) + dx;
						if(*pWindow == DILATE_COMPARE)
						{
							foundMatch = 1;
							break;
						}
					}
				} // for dx
				
				if(foundMatch)
				{
					break;
				}
			} // for dy
			
			if(foundMatch)
			{
				*pOut = 0xFF;

				(*pHistY)++;
				(*pHistX)++;
			}
			else
			{
				*pOut = 0;
			}
			
			// save histY maximum
			if((y == IMAGE_HEIGHT - 1) && (histX[x] >= maxHistX)){
				maxHistX = histX[x];
				maxX = x;
			}
				
			pOut++;
			pIn++;
			pHistX++;
		} // for x

		// save histX maximum
		if(*pHistY >= maxHistY) {
			maxHistY = *pHistY;
			maxY = y;
		}

		pHistY++;
	} // for y

#ifdef DEBUG
	printf("Max @ %d, %d\n", maxX*FRAME_SKIP, maxY*FRAME_SKIP);
#endif
}
