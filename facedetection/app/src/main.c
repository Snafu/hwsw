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
#include "camera.h"
#include "buttons.h"

/*
 * 	hari: additional extension for signalling completion of camera-i2c-config
*/
#define signal_init()     { \
        INIT_DONE_STATUS = (0xFF); \
        uint32_t j; \
        for(j = 0; j < 2300; j++) asm volatile("nop\n\t"); \
        }

#define INIT_DONE_STATUS (*(volatile int *const) (INIT_DONE_BADDR))
#define INIT_DONE_BADDR ((uint32_t)-416)


// 	address -384 --> i2c.h
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

image_t erodeFilterImage;
image_t dilateFilterImage;

void computeSingleImage(void);
void transmitResult(rect_t *resultRect);
void initializeImage(image_t *template, image_t *image);
void freeImage(image_t *image);


void initializeImage(image_t *template, image_t *image)
{
	image->width = template->width;
	image->height = template->height;
	image->dataLength = template->dataLength;

	// allocate memory in external SDRAM
	image->data = (unsigned char *)(SDRAM_BASE+sdramBytesAllocated);
	memset((void *) image->data, 0, image->width * image->height);
	sdramBytesAllocated += template->dataLength;

}

void freeImage(image_t *image) 
{
	free(image->data);
}


void initSVGA(void)
{
	// SVGA initialization (touchscreen)
	SVGA_STATUS = (1<<1);
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
	
	
	erodeFilterImage.width = 800;
	erodeFilterImage.height = 480;
	erodeFilterImage.dataLength = 800*480;
	
	// Initialize Image buffers
	initializeImage(&erodeFilterImage, &erodeFilterImage);
	initializeImage(&erodeFilterImage, &dilateFilterImage);
	
	initSVGA();

	// CAM initialization
	initCamera();
	/*
	setYFactors(66, 129, 25);
	setCbFactors(-38, -74, 112);
	setCrFactors(112, -94, -18);

	setYBounds(38, 235);
	setCbBounds(94, 139);
	setCrBounds(139, 173);
	*/
	setYFactors(66, 129, 25);
	setCbFactors(-38, -74, 112);
	setCrFactors(112, -94, -18);

	setYBounds(38, 235);
	setCbBounds(74, 139);
	setCrBounds(139, 173);

	setCamMode(MODE_COLOR);

	uint32_t i;
	uint32_t j;

	for(i = 0; i < 10; i++) {
		for(j = 0; j < WAIT_TIME; j++) asm volatile("nop\n\t");
	}
	
	signal_init();		// cam - config completed. signal it to who it belongs(dispctrl so far)

	dis7seg_displayHexUInt32(&dispHandle, 0, 0x2b00b1e5);
	draw_rect(5,5, 795,475);

	uint32_t keys, keys_old, value;
	keys_old = 0;
	int mode, mode_old;
	mode = 0;
	mode_old = 1;
	int cam_mode, cam_mode_old;
	cam_mode = 0;
	cam_mode_old = 0;
	
	while(1) {
		
		keys = getKeys();
		value = switchVal();
		dis7seg_displayHexUInt32(&dispHandle, 0, (mode << 24) | (keys << 16) | (value & 0xFFFF));

		cam_mode = (value & (1<<16)) ? 1 : 0;
		if(cam_mode != cam_mode_old)
			setCamMode(cam_mode);
		cam_mode_old = cam_mode;
		
		if(mode == 0 && mode_old == 1) {
			i2c_write(RESTART_REG, TRIGGER);
		}	else if(mode == 1 && mode_old == 0) {
			i2c_write(RESTART_REG, 0);
		}
		
		mode_old = mode;

		if(keys != keys_old) {
			if(value & (1<<17)) {
				// COLOR CORRECTION

				if(keys & (1<<KEY3)) {
					i2c_write(GAIN_RED_REG, value);
				}
				if(keys & (1<<KEY2)) {
					i2c_write(GAIN_GREEN1_REG, value);
					i2c_write(GAIN_GREEN2_REG, value);
				}
				if(keys & (1<<KEY1)) {
					i2c_write(GAIN_BLUE_REG, value);
				}
			} else {
				// TRIGGER FRAME
				if(mode == 1 && (keys & (1<<KEY3))) {
					i2c_write(RESTART_REG, TRIGGER);
					i2c_write(RESTART_REG, 0);
				}

				// SWITCH OUTPUT MODE
				if(keys & (1<<KEY2))
					mode = 1 - mode;
			}
		}
		keys_old = keys;
	}


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


void computeSingleImage(void)
{
	uint32_t imageLen;
	int result;
	rect_t resultRect;


	uint32_t cycles;


	counter_reset(&counterHandle);
	counter_start(&counterHandle);

	erodeFilter((volatile char *) SDRAM_BASE, &erodeFilterImage);
	dilateFilter(&erodeFilterImage, &dilateFilterImage);
	//result = detectFace(&dilateFilterImage, &inputImage, &resultRect);

	// send signal to PC client that output data will be sent
	printf("\x04\n");

	// send elapsed time for computation
	cycles = counter_getValue(&counterHandle);
	UART_write(1, (char *)&cycles, sizeof(cycles));
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
