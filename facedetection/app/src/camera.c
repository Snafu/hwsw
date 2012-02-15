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
	i2c_write(PIXEL_CLOCK_CONTROL_REG, 0x8000);					// OK!

	// OUTPUT_Slew_Rate | PIXCLK_Slew_Rate | Chip Enable
	i2c_write(OUTPUT_CONTROL_REG, ((1<<10)|(7<<7)|(1<<1)));		// OK!

	// gain settings
	// digital [0,120], analog mult [0,1], analog [8,63]
	/*
	i2c_write(0x2b, (10<<8) | (0<<6) | 29);			// TAKEN FROM HINTS...
	i2c_write(0x2c, (10<<8) | (0<<6) | 39);
	i2c_write(0x2d, (10<<8) | (0<<6) | 42);
	i2c_write(0x2e, (10<<8) | (0<<6) | 29);
	*/
	// red
	i2c_write(GAIN_RED_REG, (16<<8) | (1<<6) | 32);
	// green 1
	i2c_write(GAIN_GREEN1_REG, (16<<8) | (1<<6) | 32);
	// green 2
	i2c_write(GAIN_GREEN2_REG, (16<<8) | (1<<6) | 32);
	// blue
	i2c_write(GAIN_BLUE_REG, (16<<8) | (1<<6) | 32);

	// shutter width - lower byte
	// default 0x797
	i2c_write(SHUTTERW_LOWER_REG, 100);					// schaut halbwegs OK aus! hoher wert --> kleinere framerate
	i2c_write(SHUTTER_DELAY_REG, 7000);					// schaut halbwegs OK aus! hoher wert --> kleinere framerate
		
	// pause restart
	// //	i2c_write(0x0b,3);

	// row size
	//i2c_write(ROW_SIZE_REG, 1439);					// should be OK
	i2c_write(ROW_SIZE_REG, 1440);					// should be OK

	// col size
	//i2c_write(COL_SIZE_REG, 2399);					// should be OK
	i2c_write(COL_SIZE_REG, 2400);					// should be OK

	// row skipping
	i2c_write(ROW_ADDRESS_MODE_REG, 2);					// OK!

	// col skipping
	i2c_write(COL_ADDRESS_MODE_REG, 2);					// OK!

	// mirror rows
	i2c_write(READ_MODE2_REG, (1<<15));				// OK!

	// snapshot mode
	//i2c_write(READ_MODE1_REG,(0x4006 | (1<<8)));	// FUNKTIONIERT ___NICHT___

	i2c_write(READ_MODE1_REG, (0x4006 | (1<<8) | (1<<9)));	// FUNKT --> INVERT TRIGGER SETZEN da HW-trigger-pin auf LOW?


	// unpause restart
	//i2c_write(RESTART_REG, 1);

	//*
	// black level calibration OFF
	i2c_write(BLACK_LVL_CAL_REG, 2);
	
	// Green
	i2c_write(TEST_PATTERN_GREEN_REG, 0xFFF);
	// Blue
	i2c_write(TEST_PATTERN_BLUE_REG, 0x000);
	//	TESTPATTERN
	i2c_write(TEST_PATTERN_BARW_REG, 2);
	i2c_write(TEST_PATTERN_CTRL_REG, TEST_MONOCR_VERTICAL | TEST_ENABLE);
	//*/	
}
