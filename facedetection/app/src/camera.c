#include <stdint.h>
#include "i2c.h"
#include "camera.h"

void initCamera(void)
{
	/*
 	 *i2c config for camera, see hints.pdf
 	 */

	// power pll - but not use it for now...
	i2c_write(CLOCK_CONTROL_REG, 0x51);					// OK!

	// pll factor + divider - additional dividier in Reg12
	//i2c_write(0x11,(16<<8)|6);	// 14.285... MHz	// OK!
	i2c_write(PLL_CONFIG1_REG, (16<<8)|4);	// 20 MHz		// OK!
	//i2c_write(0x11,(20<<8)|4);	// 25 MHz		// CHECK
	//i2c_write(0x11,0x1404);	// 25MHz		// OK!
	
	// pll p1 divider
	i2c_write(PLL_CONFIG2_REG, 0x01);					// OK!
	//i2c_write(0x12,0x03);					// OK!
	
	// now use & power pll
	i2c_write(CLOCK_CONTROL_REG, 0x53);					// OK!

	// invert pixel clock
	//i2c_write(PIXEL_CLOCK_CONTROL_REG, (1<<15));					// OK!

	// OUTPUT_Slew_Rate | PIXCLK_Slew_Rate | Chip Enable
	i2c_write(OUTPUT_CONTROL_REG, ((1<<10)|(3<<7)|(1<<1)));		// OK!

	// gain settings
	// digital [0,120], analog mult [0,1], analog [8,63]
	/*
	i2c_write(0x2b, (10<<8) | (0<<6) | 29);			// TAKEN FROM HINTS...
	i2c_write(0x2c, (10<<8) | (0<<6) | 39);
	i2c_write(0x2d, (10<<8) | (0<<6) | 42);
	i2c_write(0x2e, (10<<8) | (0<<6) | 29);
	*/
	// red
	i2c_write(GAIN_RED_REG, (1<<8) | (1<<6) | 32);
	// green 1
	i2c_write(GAIN_GREEN1_REG, (1<<8) | (1<<6) | 32);
	// green 2
	i2c_write(GAIN_GREEN2_REG, (1<<8) | (1<<6) | 32);
	// blue
	i2c_write(GAIN_BLUE_REG, (3<<8) | (1<<6) | 32);

		
	// pause restart
	// //	i2c_write(0x0b,3);

	/*
	 * Resolution 400x240
	 */
	i2c_write(COL_SIZE_REG, 2401);
	i2c_write(ROW_SIZE_REG, 1441);
	// row skipping
	i2c_write(ROW_ADDRESS_MODE_REG, 2);
	// col skipping
	i2c_write(COL_ADDRESS_MODE_REG, 2);
	// shutter width - lower byte
	// default 0x797
	i2c_write(SHUTTERW_LOWER_REG, 300);					// schaut halbwegs OK aus! hoher wert --> kleinere framerate
	i2c_write(SHUTTER_DELAY_REG, 0);					// schaut halbwegs OK aus! hoher wert --> kleinere framerate


	// mirror rows
	i2c_write(READ_MODE2_REG, (1<<15));				// OK!

	// snapshot mode
	//i2c_write(READ_MODE1_REG,(0x4006 | (1<<8)));	// FUNKTIONIERT ___NICHT___

	i2c_write(READ_MODE1_REG, (0x4006 | (1<<8) | (1<<9)));	// FUNKT --> INVERT TRIGGER SETZEN da HW-trigger-pin auf LOW?

#ifdef TEST
	// unpause restart
	//i2c_write(RESTART_REG, 1);

	// black level calibration OFF
	i2c_write(BLACK_LVL_CAL_REG, 2);
	
	// Green
	i2c_write(TEST_PATTERN_GREEN_REG, 0xFFF);
	// Blue
	i2c_write(TEST_PATTERN_BLUE_REG, 0x000);
	//	TESTPATTERN
	i2c_write(TEST_PATTERN_BARW_REG, 49);
	i2c_write(TEST_PATTERN_CTRL_REG, TEST_MONOCR_VERTICAL | TEST_ENABLE);
#else

	// disable test mode
	i2c_write(TEST_PATTERN_CTRL_REG, 0);
#endif
}

void setYFactors(int16_t rfac, int16_t gfac, int16_t bfac)
{
	uint32_t reg;
	uint16_t ur,ug,ub;
	ur = (uint16_t) rfac;
	ug = (uint16_t) gfac;
	ub = (uint16_t) bfac;

	CAMERA_YR_YG = (ug<<16) | ur;
	reg = CAMERA_YB_CBR & 0xffff0000;
	CAMERA_YB_CBR = reg | ub;
}

void setCbFactors(int16_t rfac, int16_t gfac, int16_t bfac)
{
	uint32_t reg;
	uint16_t ur,ug,ub;
	ur = (uint16_t) rfac;
	ug = (uint16_t) gfac;
	ub = (uint16_t) bfac;
	
	reg = CAMERA_YB_CBR & 0x0000ffff;
	CAMERA_YB_CBR = (ur<<16) | reg;
	CAMERA_CBG_CBB = (ub<<16) | ug;
}

void setCrFactors(int16_t rfac, int16_t gfac, int16_t bfac)
{
	uint32_t reg;
	uint16_t ur,ug,ub;
	ur = (uint16_t) rfac;
	ug = (uint16_t) gfac;
	ub = (uint16_t) bfac;

	CAMERA_CRR_CRG = (ug<<16) | ur;
	reg = CAMERA_CRB_YBOUNDS & 0xffff0000;
	CAMERA_CRB_YBOUNDS = reg | ub;
}

void setYBounds(uint8_t min, uint8_t max)
{
	uint32_t reg;

	reg = CAMERA_CRB_YBOUNDS & 0x0000ffff;
	CAMERA_CRB_YBOUNDS = (max<<24) | (min<<16) | reg;
}

void setCbBounds(uint8_t min, uint8_t max)
{
	uint32_t reg;

	reg = CAMERA_CBBOUNDS_CRBOUNDS & 0xffff0000;
	CAMERA_CBBOUNDS_CRBOUNDS = reg | (max<<8) | min;
}

void setCrBounds(uint8_t min, uint8_t max)
{
	uint32_t reg;

	reg = CAMERA_CBBOUNDS_CRBOUNDS & 0x0000ffff;
	CAMERA_CBBOUNDS_CRBOUNDS = (max<<24) | (min<<16) | reg;
}

void setCamMode(uint8_t mode)
{
	if(mode == MODE_DSP)
		CAMERA_MODE = MODE_DSP;
	else
		CAMERA_MODE = MODE_COLOR;
}
