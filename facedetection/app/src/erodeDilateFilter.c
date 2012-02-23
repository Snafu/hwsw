#include <string.h>
#include <stdio.h>
#include "filters.h"
#include "image.h"
#include "dispctrl.h"


#define ERODE_COMPARE				0
#define DILATE_COMPARE			0xff


int histX[HISTX_LEN], histY[HISTY_LEN];
int maxHistX, maxHistY;
int maxX, maxY;

void erodeFilter(volatile char *framebuffer, image_t *outputImage)
{
  int x, y, dx, dy;
  uint8_t foundMatch;
	
	volatile char *inlineptr = framebuffer + SKINBYTE_OFFSET;
	volatile char *woffsetptr;
	volatile char *winptr;
	
	unsigned char *outlineptr = outputImage->data + (IMAGE_WIDTH+1)*WINDOW_OFFSET;
	unsigned char *outptr;
	
	//for (y = 0; y < IMAGE_HEIGHT - WINDOW_LENGTH + 1; ++y)
	for (y = 0; y < IMAGE_HEIGHT; ++y)
	{
		woffsetptr = inlineptr;
		outptr = outlineptr;
		//for (x = 0; x < IMAGE_WIDTH - WINDOW_LENGTH + 1; ++x)
		for (x = 0; x < IMAGE_WIDTH; ++x)
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
					//winptr += 4*FRAME_SKIP;
					winptr += 4;
				} // for dx
				
				//winptr += (FRAME_WIDTH - WINDOW_LENGTH)*4*FRAME_SKIP;
				winptr += (FRAME_WIDTH - WINDOW_LENGTH)*4;
				if (foundMatch) {
					break;
				}
			} // for dy
			
			
			if (!foundMatch)
				*outptr = 0xFF;
			else
				*outptr = 0;
			
			outptr++;
			woffsetptr += 4*FRAME_SKIP;
		} // for x
		
		// go to next line
		outlineptr += IMAGE_WIDTH;
		inlineptr += FRAME_WIDTH*4*FRAME_SKIP;
	} // for y
}


void dilateFilter(image_t *inputImage, image_t *outputImage)
{
	int x, y, dx, dy;
	uint8_t foundMatch;
	
	int hX, hY;

	unsigned char *inlineptr = inputImage->data;
	unsigned char *woffsetptr;
	unsigned char *winptr;
	
	unsigned char *outlineptr = outputImage->data + (IMAGE_WIDTH+1)*WINDOW_OFFSET;
	unsigned char *outptr;

	for(y=0;y<HISTY_LEN;y++)
	{
		histY[y] = 0;
		histX[y] = 0;
	}

	for(x=HISTY_LEN;x<HISTX_LEN;x++)
	{
		histX[x] = 0;
	}

	maxHistX = 0;
	maxHistY = 0;
	maxX = 0;
	maxY = 0;

	hX = 0;
	hY = 0;

	for (y = WINDOW_OFFSET; y < IMAGE_HEIGHT - WINDOW_OFFSET; ++y)
	{
		woffsetptr = inlineptr;
		outptr = outlineptr;

		for (x = WINDOW_OFFSET; x < IMAGE_WIDTH - WINDOW_OFFSET; ++x)
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
				histY[y]++;
				histX[x]++;
			}
			else
			{
				*outptr = 0;
			}
			
			// save histY maximum
			if((y == IMAGE_HEIGHT - WINDOW_LENGTH) && (histX[x] > maxHistX)){
			//if(histX[x] > maxHistX) {
				maxHistX = histX[x];
				maxX = x;
			}
				
			hX++;
			outptr++;
			woffsetptr++;
		} // for x

		// save histX maximum
		if(histY[y] > maxHistY) {
			maxHistY = histY[y];
			maxY = y;
		}
	
		hX = 0;
		hY++;

		// go to next line
		outlineptr += IMAGE_WIDTH;
		inlineptr += IMAGE_WIDTH;
	} // for y

	//printf("Max @ %d, %d\n", maxX<<2, maxY<<2);
}
