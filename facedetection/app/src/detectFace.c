#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "image.h"
#include "detectFace.h"
#include "filters.h"

#define FOREGROUND_COLOR_R   0xff
#define FOREGROUND_COLOR_G   0xff
#define FOREGROUND_COLOR_B   0xff
#define STEP_SIZE            1


int aboveThresholdX[HISTX_LEN];
int aboveThresholdY[HISTY_LEN];

int getIndexBelowThreshold(int *hist, int histLen, int start, int step, int threshold);

int detectFace(rect_t *resultRect)
{
  int i, j;
  int width, height;
	int scaledWidth;

  int aboveThresholdXLen;
  int aboveThresholdYLen;

  resultRect->topLeftX = 0;
  resultRect->topLeftY = 0;
  resultRect->bottomRightX = 0;
  resultRect->bottomRightY = 0;
  
  int maxArea;

  // select coordinates where histogram value is above half 
  // of max hist value
  j = 0;
  for (i=0; i < HISTX_LEN; i+=STEP_SIZE) {
    if (histX[i] > maxHistX>>1) {
      aboveThresholdX[j] = i;
      j++;
    }
  }
  aboveThresholdXLen = j;

  j = 0;
  for (i=0; i < HISTY_LEN; i+=STEP_SIZE) {
    if (histY[i] > maxHistY>>1) {
      aboveThresholdY[j] = i;
      j++;
    }
  }
  aboveThresholdYLen = j;

  // compute candidate face regions and pick the
  // one with the largest area
  maxArea=0;
  for (i=0; i<aboveThresholdYLen; i++) {
    for (j=0; j<aboveThresholdXLen; j++) {
      rect_t r;
      int area;      

      r.topLeftX = getIndexBelowThreshold(histX, HISTX_LEN, aboveThresholdX[j], -1, maxHistX>>2);
      r.bottomRightX = getIndexBelowThreshold(histX, HISTX_LEN, aboveThresholdX[j], 1, maxHistX>>2);
      r.topLeftY = getIndexBelowThreshold(histY, HISTY_LEN, aboveThresholdY[i], -1, maxHistY>>3);
      r.bottomRightY = getIndexBelowThreshold(histY, HISTY_LEN, aboveThresholdY[i], 1, maxHistY>>3);

      width = r.bottomRightX - r.topLeftX;
      height = r.bottomRightY - r.topLeftY;
      area = width*height;

      if (area > maxArea) {
				*resultRect = r;	
				maxArea = area;
      }
    }
  }

  printf("selected rect: topLeft=(%d, %d), bottomRight=(%d, %d)\n", resultRect->topLeftX, resultRect->topLeftY, resultRect->bottomRightX, resultRect->bottomRightY);
  
	if (maxArea > 0) {
    // adjust face proportions, assume upright faces
    // typical face proportions: width:height = 2:3
    width = resultRect->bottomRightX-resultRect->topLeftX;
    height = resultRect->bottomRightY-resultRect->topLeftY;
		
		scaledWidth = width + (width>>1);

    if (width < height) {
      if (height > scaledWidth) {
				resultRect->bottomRightY = resultRect->topLeftY + scaledWidth;
      }
    }

    return 1;
  }
  else {
    return 0;
  }
}

int getIndexBelowThreshold(int *hist, int histLen, int start, int step, int threshold) {
  int i;
  int result = start;
  for (i=start; i>0 && i<histLen; i+=step) {
    if (hist[i] < threshold) {
      result = i<<2;
      break;
    }
  }

  return result;
}
