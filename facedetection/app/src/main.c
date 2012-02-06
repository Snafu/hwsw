#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "image.h"
#include "filters.h"
#include "detectFace.h"

#ifdef __SCARTS_32__
#include "sdram.h"
#include <machine/modules.h>
#include <machine/interrupts.h>
#include <machine/UART.h>
#include <drivers/counter.h>
#include <drivers/dis7seg.h>
#include <drivers/mini_uart.h>
#include "svga.h"
#include "dispctrl.h"
#include "i2c.h"

#define AUX_UART_BADDR ((uint32_t)-352)
#define COUNTER_BADDR ((uint32_t)-320)
#define DISP_BADDR    ((uint32_t)-288)
#define LEDS (*(volatile int *const) (0xFFFFFEE0+7))
#define WAIT_TIME	0x1ff00

#define SCREEN_WIDTH  800
#define SCREEN_HEIGHT 480

static uint32_t sdramBytesAllocated;
static module_handle_t counterHandle;
static dis7seg_handle_t dispHandle;
static mini_uart_handle_t aux_uart_handle;
static volatile uint32_t *screenData;
#endif

void computeSingleImage(const char *sourcePath, const char *targetPath);
void transmitResult(rect_t *resultRect);
void initializeImage(image_t *template, image_t *image);
void freeImage(image_t *image);


void initializeImage(image_t *template, image_t *image)
{
	image->width = template->width;
	image->height = template->height;
	image->dataLength = template->dataLength;
#ifdef __SCARTS_32__
	// allocate memory in external SDRAM
	image->data = (unsigned char *)(SDRAM_BASE+sdramBytesAllocated);
	sdramBytesAllocated += template->dataLength;
#else
	// allocate memory on heap
	image->data = (unsigned char *)malloc(template->dataLength);    
#endif
}

void freeImage(image_t *image) 
{
	free(image->data);
}


int main(int argc, char **argv)
{

#ifdef __SCARTS_32__
	UART_Cfg cfg;
	mini_uart_cfg_t aux_uart_cfg;

	// initialize HW modules
	// Cycle counter
	counter_initHandle(&counterHandle, COUNTER_BADDR);
	counter_setPrescaler(&counterHandle, 3);
	// UART
	cfg.fclk = 50000000;
	cfg.baud = UART_CFG_BAUD_115200;
	cfg.frame.msg_len = UART_CFG_MSG_LEN_8;
	cfg.frame.parity = UART_CFG_PARITY_EVEN;
	cfg.frame.stop_bits = UART_CFG_STOP_BITS_1;
	UART_init (cfg);
	// AUX UART
	aux_uart_cfg.fclk = 50000000;
	aux_uart_cfg.baud = UART_CFG_BAUD_230400;
	aux_uart_cfg.frame.msg_len = UART_CFG_MSG_LEN_8;
	aux_uart_cfg.frame.parity = UART_CFG_PARITY_EVEN;
	aux_uart_cfg.frame.stop_bits = UART_CFG_STOP_BITS_1;
	mini_uart_initHandle(&aux_uart_handle, AUX_UART_BADDR, &aux_uart_cfg);

	// 7-Seg Display
	dis7seg_initHandle(&dispHandle, DISP_BADDR, 8);
	dis7seg_displayHexUInt32(&dispHandle, 0, 0x42);  

	// SDRAM initialization
	SDRAM_CFG = SDRAM_REFRESH_EN | 
		SDRAM_TRFC(2) | 
		SDRAM_BANKSIZE_128MB | 
		SDRAM_COLSIZE_1024 | 
		SDRAM_CMD_LOAD_CMD_REG | 
		389;

	// SVGA initialization (touchscreen)
	SVGA_VIDEO_LENGTH = ((SCREEN_HEIGHT-1)<<16) | (SCREEN_WIDTH-1);
	SVGA_FRONT_PORCH = (10<<16) | 40;
	SVGA_SYNC_LENGTH = (1<<16) | 1;
	SVGA_LINE_LENGTH = (526<<16) | 1056;
	SVGA_FRAME_BUFFER = SDRAM_BASE;
	SVGA_DYN_CLOCK0 = 30000;
	SVGA_STATUS = (1<<0) | (3<<4);
	sdramBytesAllocated += SCREEN_WIDTH*SCREEN_HEIGHT*4;
	screenData = (volatile uint32_t *)SDRAM_BASE;
	memset((void *)screenData, 0, (SCREEN_WIDTH*SCREEN_HEIGHT*4));


	mini_uart_write(&aux_uart_handle, (char *)"DISPCTRL INIT", sizeof("DISPCTRL INIT"));

	// DISPCTRL initialization
	dis7seg_displayHexUInt32(&dispHandle, 0, DISPCTRL_STATUS);  

	mini_uart_write(&aux_uart_handle, (char *)"I2C WRITE", sizeof("I2C WRITE"));
	
	// CAM initialization
	initCamera();

	uint32_t i;
	uint32_t j;

	
	// slew rate settings
	// 1024 | 868 | 2
/*
	// red -> yellow
	for(i = 0; i < 0xff; i++)
	{
		DISPCTRL_COLOR = 0x00ff0000 + (i<<8);
		DISPCTRL_STATUS = 0;
		DISPCTRL_STATUS = DISPCTRL_UPDATE;
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	// yello -> green
	for(i = 0; i < 0xff; i++)
	{
		DISPCTRL_COLOR = 0x00ffff00 - (i<<16);
		DISPCTRL_STATUS = 0;
		DISPCTRL_STATUS = DISPCTRL_UPDATE;
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	// green -> cyan
	for(i = 0; i < 0xff; i++)
	{
		DISPCTRL_COLOR = 0x0000ff00 + i;
		DISPCTRL_STATUS = 0;
		DISPCTRL_STATUS = DISPCTRL_UPDATE;
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	// cyan -> blue
	for(i = 0; i < 0xff; i++)
	{
		DISPCTRL_COLOR = 0x0000ffff - (i<<8);
		DISPCTRL_STATUS = 0;
		DISPCTRL_STATUS = DISPCTRL_UPDATE;
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	// blue -> violet
	for(i = 0; i < 0xff; i++)
	{
		DISPCTRL_COLOR = 0x000000ff + (i<<16);
		DISPCTRL_STATUS = 0;
		DISPCTRL_STATUS = DISPCTRL_UPDATE;
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	// violet -> red
	for(i = 0; i < 0xff; i++)
	{
		DISPCTRL_COLOR = 0x00ff00ff - i;
		DISPCTRL_STATUS = 0;
		DISPCTRL_STATUS = DISPCTRL_UPDATE;
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	*/
	for(i = 0; i < 300; i++)
	{
		UPDATE_GLCD();
		for(j = 0; j < 30; j++) asm volatile("nop\n\t");
	}

	i2c_write(0x0b, 0x04);
/*
	while(1)
	{
		i2c_write(0x0b, 0x04);
		for(i = 0; i < 100; i++)
		{
			for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
		}
	}
	
	DRAW_RECT(0,0,0,0);
	DISPCTRL_COLOR = 0x000000ff;
	UPDATE_GLCD();
	for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
*/





#endif

#ifdef TEST
	computeSingleImage(argv[1], argv[2]);
#else
	while (1) {
		rect_t resultRect;

		// TODO:
		// get picture from camera
		// perform face detection
		// outout result image on screen

		// transmit result to benchmark board
		transmitResult(&resultRect);
	}  
#endif


#ifdef __SCARTS_32__
	counter_releaseHandle(&counterHandle);
	dis7seg_releaseHandle(&dispHandle);
	mini_uart_releaseHandle(&aux_uart_handle);
#endif

	return 0;
}


void computeSingleImage(const char *sourcePath, const char *targetPath)
{
	uint32_t imageLen;
	image_t inputImage;
	image_t skinFilterImage;
	image_t erodeFilterImage;
	image_t dilateFilterImage;
	char tgaHeader[18];
	int result;
	rect_t resultRect;

#ifndef __SCARTS_32__
	FILE *f;
#else
	uint32_t cycles;
	int x, y;
#endif

#ifndef __SCARTS_32__
	f = fopen(sourcePath, "r");
	if (!f) {
		printf("Image file <%s> not found\n", sourcePath);
		exit(1);
	}
	fseek(f, 0, SEEK_END);
	imageLen = ftell(f);
	fseek(f, 0, SEEK_SET);

	fread(tgaHeader, 1, sizeof(tgaHeader), f);
#else
	UART_read(0, (char *)&imageLen, sizeof(imageLen));

	// read header
	UART_read(0, (char *)tgaHeader, sizeof(tgaHeader));

#endif

	inputImage.width = (tgaHeader[13] << 8) | (tgaHeader[12] & 0xFF);
	inputImage.height = (tgaHeader[15] << 8) | (tgaHeader[14] & 0xFF);
	inputImage.dataLength = imageLen - sizeof(tgaHeader);


#ifndef __SCARTS_32__
	// allocate memory on heap
	inputImage.data = (unsigned char *)malloc(inputImage.dataLength);    
	fread(inputImage.data, 1, inputImage.dataLength, f);
	fclose(f);
#else

	// allocate memory in external SDRAM
	inputImage.data = (unsigned char *)(SDRAM_BASE+sdramBytesAllocated);
	sdramBytesAllocated += inputImage.dataLength;

	// read image data
	UART_read(0, (char *)inputImage.data, inputImage.dataLength);

	printf("Images received, starting computation.\n");
#endif

	initializeImage(&inputImage, &skinFilterImage);
	initializeImage(&inputImage, &erodeFilterImage);
	initializeImage(&inputImage, &dilateFilterImage);


#ifdef __SCARTS_32__

	counter_reset(&counterHandle);
	counter_start(&counterHandle);

#endif 

	// perform face detection
	skinFilter(&inputImage, &skinFilterImage);
	erodeDilateFilter(&skinFilterImage, &erodeFilterImage, FILTER_ERODE);
	erodeDilateFilter(&erodeFilterImage, &dilateFilterImage, FILTER_DILATE);
	result = detectFace(&dilateFilterImage, &inputImage, &resultRect);

#ifdef __SCARTS_32__
	// output image on touchscreen
	for (y=0; y<SCREEN_HEIGHT; y++) {
		for (x=0; x<SCREEN_WIDTH; x++) {
			if (x < inputImage.width && y < inputImage.height) {
				int pIndex;
				rgb_color_t color;
				pIndex = (y*inputImage.width+x)*3;
				color.b = inputImage.data[pIndex];
				color.g = inputImage.data[pIndex+1];
				color.r = inputImage.data[pIndex+2];
				screenData[y*SCREEN_WIDTH+x] = (color.r << 16) | (color.g << 8) | color.b;
			}
			else {
				screenData[y*SCREEN_WIDTH+x] = 0;
			}
		}
	}

	// send result coordinates
	if (result) {
		transmitResult(&resultRect);
	}
	counter_stop(&counterHandle);
#endif 

	// send output
	memset(tgaHeader,0,sizeof(tgaHeader));
	tgaHeader[12] = (unsigned char) (inputImage.width & 0xFF);
	tgaHeader[13] = (unsigned char) (inputImage.width >> 8);
	tgaHeader[14] = (unsigned char) (inputImage.height & 0xFF);
	tgaHeader[15] = (unsigned char) (inputImage.height >> 8);
	tgaHeader[17] = 0x20;    // Top-down, non-interlaced
	tgaHeader[2]  = 2;       // image type = uncompressed RGB
	tgaHeader[16] = 24;

	imageLen = sizeof(tgaHeader) + inputImage.dataLength;

#ifndef __SCARTS_32__
	f = fopen(targetPath, "w");
	if (!f) {
		printf("Image file <%s> couldn't be opened", targetPath);
		exit(1);
	}

	fwrite(tgaHeader, 1, sizeof(tgaHeader), f);
	fwrite(inputImage.data, 1, inputImage.dataLength, f);
	fclose(f);
#else
	// send signal to PC client that output data will be sent
	printf("\x04\n");

	// send elapsed time for computation
	cycles = counter_getValue(&counterHandle);
	UART_write(1, (char *)&cycles, sizeof(cycles));
	// send length of whole image file
	UART_write(1, (char *)&imageLen, sizeof(imageLen));
	// send image header
	UART_write(1, tgaHeader, sizeof(tgaHeader));
	// send image data
	UART_write(1, (char *)inputImage.data, inputImage.dataLength);
#endif

	freeImage(&inputImage);
	freeImage(&skinFilterImage);
	freeImage(&erodeFilterImage);
	freeImage(&dilateFilterImage);

}

void transmitResult(rect_t *resultRect)
{
#ifdef __SCARTS_32__
	uint16_t preamble = 0xffff;
	mini_uart_write(&aux_uart_handle, (char *)&preamble, sizeof(preamble));
	mini_uart_write(&aux_uart_handle, (char *)&resultRect->topLeftX, sizeof(resultRect->topLeftX));
	mini_uart_write(&aux_uart_handle, (char *)&resultRect->topLeftY, sizeof(resultRect->topLeftY));
	mini_uart_write(&aux_uart_handle, (char *)&resultRect->bottomRightX, sizeof(resultRect->bottomRightX));
	mini_uart_write(&aux_uart_handle, (char *)&resultRect->bottomRightY, sizeof(resultRect->bottomRightY));
#endif
}
