#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "image.h"
#include "detectFace.h"

#define FOREGROUND_COLOR_R   0xff
#define FOREGROUND_COLOR_G   0xff
#define FOREGROUND_COLOR_B   0xff
#define STEP_SIZE            10

int getIndexBelowThreshold(int *hist, int histLen, int start, int step, int threshold);
void paintRectangle(image_t *image, rect_t *rectangle);

int detectFace(image_t *faceMask, image_t *rawImage, rect_t *resultRect)
{
  int *histX;
  int *histY;
  int x, y;
  int pIndex;
  rgb_color_t c;
  int i, j;
  int width, height;
  int maxHistX, maxHistY;
  int faceX, faceY;

  int histXLen, histYLen;
  int *aboveThresholdX;
  int *aboveThresholdY;
  int aboveThresholdXLen;
  int aboveThresholdYLen;

  resultRect->topLeftX = 0;
  resultRect->topLeftY = 0;
  resultRect->bottomRightX = 0;
  resultRect->bottomRightY = 0;
  
  int maxArea;

  // compute histogramm
  histXLen = faceMask->width;
  histYLen = faceMask->height;
  histX = (int *)malloc(histXLen*sizeof(int));
  histY = (int *)malloc(histYLen*sizeof(int));

  memset(histX, 0, faceMask->width*sizeof(int));
  memset(histY, 0, faceMask->height*sizeof(int));

  for (y = 0; y < faceMask->height; y++) {
    for (x = 0; x < faceMask->width; x++) {
      pIndex = (y*faceMask->width + x)*3;
      c.b = faceMask->data[pIndex];
      c.g = faceMask->data[pIndex + 1];
      c.r = faceMask->data[pIndex + 2];

      if (c.r == FOREGROUND_COLOR_R && 
	  c.g == FOREGROUND_COLOR_G && 
	  c.b == FOREGROUND_COLOR_B) {
	histX[x]++;
	histY[y]++;
      }
    }
  }

  // find maximum histgram value and related xy-coordinate
  maxHistX = 0;
  for (i = 0; i < faceMask->width; i++) {
    if (histX[i] > maxHistX) {
      maxHistX = histX[i];
      faceX = i;
    }
  }
  maxHistY = 0;
  for (i = 0; i < faceMask->height; i++) {
    if (histY[i] > maxHistY) {
      maxHistY = histY[i];
      faceY = i;
    }
  }

  // select coordinates where histogram value is above half 
  // of max hist value
  aboveThresholdX = (int *)malloc(histXLen*sizeof(int));
  aboveThresholdY = (int *)malloc(histYLen*sizeof(int));
  j = 0;
  for (i=0; i < histXLen; i+=STEP_SIZE) {
    if (histX[i] > maxHistX/2) {
      aboveThresholdX[j] = i;
      j++;
    }
  }
  aboveThresholdXLen = j;

  j = 0;
  for (i=0; i < histYLen; i+=STEP_SIZE) {
    if (histY[i] > maxHistY/2) {
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

      r.topLeftX = getIndexBelowThreshold(histX, histXLen, aboveThresholdX[j], -1, maxHistX/6);
      r.bottomRightX = getIndexBelowThreshold(histX, histXLen, aboveThresholdX[j], 1, maxHistX/6);
      r.topLeftY = getIndexBelowThreshold(histY, histYLen, aboveThresholdY[i], -1, maxHistY/9);
      r.bottomRightY = getIndexBelowThreshold(histY, histYLen, aboveThresholdY[i], 1, maxHistY/9);

      width = r.bottomRightX-r.topLeftX;
      height = r.bottomRightY-r.topLeftY;
      area = width*height;

      if (area > maxArea) {
	*resultRect = r;	
	maxArea = area;
      }
    }
  }

  free(aboveThresholdX);
  free(aboveThresholdY);
  free(histX);
  free(histY);

  if (maxArea > 0) {
    // adjust face proportions, assume upright faces
    // typical face proportions: width:height = 2:3
    width = resultRect->bottomRightX-resultRect->topLeftX;
    height = resultRect->bottomRightY-resultRect->topLeftY;
    if (width < height) {
      if (height > width/2*3) {
	resultRect->bottomRightY = resultRect->topLeftY + width/2*3;
      }
    }

    printf("selected rect: topLeft=(%d, %d), bottomRight=(%d, %d)\n", resultRect->topLeftX, resultRect->topLeftY, resultRect->bottomRightX, resultRect->bottomRightY);
    
    paintRectangle(rawImage, resultRect);
    return 1;
  }
  else {
    return 0;
  }
}


void paintRectangle(image_t *image, rect_t *rectangle)
{
  int pIndex;
  int i;

  // paint rectangle on original image
  // horizontal lines
  for (i=rectangle->topLeftX; i<rectangle->bottomRightX; i++) {
    pIndex = (rectangle->topLeftY*image->width+i)*3;
    image->data[pIndex] = 0x00;
    image->data[pIndex+1] = 0xff;
    image->data[pIndex+2] = 0x00;
    
    pIndex = (rectangle->bottomRightY*image->width+i)*3;
    image->data[pIndex] = 0x00;
    image->data[pIndex+1] = 0xff;
    image->data[pIndex+2] = 0x00;
  }
  // vertical lines
  for (i=rectangle->topLeftY; i<rectangle->bottomRightY; i++) {
    pIndex = (i*image->width+rectangle->topLeftX)*3;
    image->data[pIndex] = 0x00;
    image->data[pIndex+1] = 0xff;
    image->data[pIndex+2] = 0x00;
    
    pIndex = (i*image->width+rectangle->bottomRightX)*3;
    image->data[pIndex] = 0x00;
    image->data[pIndex+1] = 0xff;
    image->data[pIndex+2] = 0x00;
  }
}

int getIndexBelowThreshold(int *hist, int histLen, int start, int step, int threshold) {
  int i;
  int result = start;
  for (i=start; i>0 && i<histLen; i+=step) {
    if (hist[i] < threshold) {
      result = i;
      break;
    }
  }

  return result;
}
