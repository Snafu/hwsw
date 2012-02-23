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

void erodeFilter(volatile uint32_t *framebuffer, image_t *outputImage)
{
  int x, y, dx, dy;
  uint8_t foundMatch;
	
	volatile uint32_t *inptr = framebuffer;
	volatile uint32_t *winptr;

	unsigned char *outptr = outputImage->data;
	
	for (y = 0; y < IMAGE_HEIGHT; ++y)
	{
		for (x = 0; x < IMAGE_WIDTH; ++x)
		{
			foundMatch = 0;
			
			for (dy = -WINDOW_OFFSET; dy < WINDOW_OFFSET; ++dy)
			{
				for (dx = -WINDOW_OFFSET; dx < WINDOW_OFFSET; ++dx)
				{
					if( ((dy + y) >= 0) && ((dx + x) >= 0) && ((dy + y) < IMAGE_HEIGHT) && ((dx + x) < IMAGE_WIDTH))
					{
						winptr = inptr + multiply(dy, FRAME_WIDTH) + dx;
						if(*winptr < ERODE_COMPARE)
						{
							foundMatch = 1;
							break;
						}
					}
				} // for dx
				
				if (foundMatch) {
					break;
				}
			} // for dy
			
			
			if (!foundMatch)
				*outptr = 0xFF;
			else
				*outptr = 0;
			
			outptr++;
			inptr += FRAME_SKIP;
		} // for x
		
		// go to next line
		inptr += FRAME_WIDTH*(FRAME_SKIP-1);
	} // for y
}


void dilateFilter(image_t *inputImage, image_t *outputImage)
{
	int x, y, dx, dy;
	uint8_t foundMatch;
	
	unsigned char *inptr = inputImage->data;
	unsigned char *winptr = inptr;
	
	unsigned char *outptr = outputImage->data;

	/*
	for(y=0;y<HISTY_LEN;y++)
	{
		histY[y] = 0;
		histX[y] = 0;
	}

	for(x=HISTY_LEN;x<HISTX_LEN;x++)
	{
		histX[x] = 0;
	}
	*/
	for(y=0;y<HISTY_LEN;y++)
	{
		histY[y] = 0;
	}

	for(x=0;x<HISTX_LEN;x++)
	{
		histX[x] = 0;
	}

	maxHistX = 0;
	maxHistY = 0;
	maxX = 0;
	maxY = 0;

	for (y = 0; y < IMAGE_HEIGHT; ++y)
	{

		for (x = 0; x < IMAGE_WIDTH; ++x)
		{
			foundMatch = 0;

			//winptr = inptr;
			for (dy = -WINDOW_OFFSET; dy < WINDOW_OFFSET; ++dy)
			{
				for (dx = -WINDOW_OFFSET; dx < WINDOW_OFFSET; ++dx)
				{
					if( ((dx + x) >= 0) && ((dy + y) >= 0) && ((dx+x) < IMAGE_WIDTH) && ((dy+y) < IMAGE_HEIGHT) )
					{
						winptr = inptr + multiply(dy, IMAGE_WIDTH) + dx;
						if(*winptr == DILATE_COMPARE)
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
				*outptr = 0xFF;
				histY[y]++;
				histX[x]++;
			}
			else
			{
				*outptr = 0;
			}
			
			// save histY maximum
			if((y == IMAGE_HEIGHT - 1) && (histX[x] >= maxHistX)){
				maxHistX = histX[x];
				maxX = x;
			}
				
			outptr++;
			inptr++;
		} // for x

		// save histX maximum
		if(histY[y] >= maxHistY) {
			maxHistY = histY[y];
			maxY = y;
		}

		// go to next line
		//inptr += IMAGE_WIDTH;
	} // for y

	//printf("Max @ %d, %d\n", maxX*FRAME_SKIP, maxY*FRAME_SKIP);
}
