#include "i2c.h"

void initCamera(void)
{
	/*
 	 *i2c config for camera, see hints.pdf
 	 */

	// power pll
	i2c_write(0x10,0x51);
	// pll factor + divider
	i2c_write(0x11,0x1404);			// 25MHz
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
	
	// pause restart
	i2c_write(0x0b,3);

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
	i2c_write(0x1e,(0x4006 | (1<<8)));
	
	// unpause restart
	i2c_write(0x0b,1);
}
