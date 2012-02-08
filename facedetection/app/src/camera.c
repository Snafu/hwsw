#include <stdint.h>
#include "i2c.h"

void initCamera(void)
{
	/*
 	 *i2c config for camera, see hints.pdf
 	 */

	// power pll
	i2c_write(0x10,0x51);
	// pll factor + divider
	i2c_write(0x11,(16<<8)|4);			// 20 MHz
	//i2c_write(0x11,0x1404);			// 25MHz
	/*
	i2c_write(0x11,0x3004);
	i2c_write(0x11,0x1e04);
	*/
	// pll p1 divider
	i2c_write(0x12,0x01);
	// use and power pll
	i2c_write(0x10,0x53);
	// invert pixel clock
	i2c_write(0x0a,0x8000);

	// slew rate
	i2c_write(0x07,((1<<10)|(7<<7)|(1<<1)));

	// gain settings
	i2c_write(0x2b, (10<<8) | (0<<6) | 29);
	i2c_write(0x2c, (10<<8) | (0<<6) | 39);
	i2c_write(0x2d, (10<<8) | (0<<6) | 42);
	i2c_write(0x2e, (10<<8) | (0<<6) | 29);
		
	// pause restart
//	i2c_write(0x0b,3);

	// row size
	i2c_write(0x03,1439);
	// col size
	i2c_write(0x04,2399);
	// row skipping
	i2c_write(0x22,2);
	// col skipping
	i2c_write(0x23,2);
	// mirror rows
	i2c_write(0x20,(1<<15));
	// snapshot mode
	i2c_write(0x1e,0x4006 | (1<<8) | (1<<9));


	/*
	 * Hadsch du Ratte, die Bloede while-Schleife wars :)
	 */
	/*
	while(1)
	{
		i2c_write(0x0b, 0x04);
	}
	*/
	
	// unpause restart
//	i2c_write(0x0b,1);

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
