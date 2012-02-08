#include <stdint.h>
#include "i2c.h"

void initCamera(void)
{
	/*
 	 *i2c config for camera, see hints.pdf
 	 */

	// power pll - but not use it for now...
	i2c_write(0x10,0x51);					// OK!

	// pll factor + divider - additional dividier in Reg12
	//i2c_write(0x11,(16<<8)|6);	// 14.285... MHz	// OK!
	i2c_write(0x11,(16<<8)|4);	// 20 MHz		// OK!
	//i2c_write(0x11,(20<<8)|4);	// 25 MHz		// CHECK
	//i2c_write(0x11,0x1404);	// 25MHz		// OK!
	
	// pll p1 divider
	i2c_write(0x12,0x01);					// OK!
	//i2c_write(0x12,0x03);					// OK!
	
	// now use & power pll
	i2c_write(0x10,0x53);					// OK!

	// invert pixel clock
	i2c_write(0x0a,0x8000);					// OK!

	// OUTPUT_Slew_Rate | PIXCLK_Slew_Rate | Chip Enable
	i2c_write(0x07,((1<<10)|(7<<7)|(1<<1)));		// OK!

	// gain settings
	i2c_write(0x2b, (10<<8) | (0<<6) | 29);			// TAKEN FROM HINTS...
	i2c_write(0x2c, (10<<8) | (0<<6) | 39);
	i2c_write(0x2d, (10<<8) | (0<<6) | 42);
	i2c_write(0x2e, (10<<8) | (0<<6) | 29);
		
	// pause restart
//	i2c_write(0x0b,3);

	// row size
	i2c_write(0x03,1439);					// should be OK

	// col size
	i2c_write(0x04,2399);					// should be OK

	// row skipping
	i2c_write(0x22,2);					// OK!

	// col skipping
	i2c_write(0x23,2);					// OK!

	// mirror rows
	i2c_write(0x20,(1<<15));				// OK!

	// snapshot mode
//i2c_write(0x1e,(0x4006 | (1<<8)));	// FUNKTIONIERT ___NICHT___

i2c_write(0x1e,(0x4006 | (1<<8) | (1<<9)));	// FUNKT --> INVERT TRIGGER SETZEN da HW-trigger-pin auf LOW?????


	// unpause restart
	//i2c_write(0x0b,1);

/*
	// black level calibration OFF
	i2c_write(0x62,2);
	
	// Green
	i2c_write(0xA1,0xF00);
	// Blue
	i2c_write(0xA3,0xAA0);
//	TESTPATTERN
	i2c_write(0xA4,3);
	i2c_write(0xA0,(7<<3)|1);
*/	
}
