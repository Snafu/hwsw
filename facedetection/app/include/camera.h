#ifndef CAMERA_H
#define CAMERA_H

#define CLOCK_CONTROL_REG						0x10
#define PLL_CONFIG1_REG							0x11
#define PLL_CONFIG2_REG							0x12
#define PIXEL_CLOCK_CONTROL_REG			0x0a
#define OUTPUT_CONTROL_REG					0x07


#define GAIN_RED_REG								0x2d
#define GAIN_GREEN1_REG							0x2b
#define GAIN_GREEN2_REG							0x2e
#define GAIN_BLUE_REG								0x2c

#define SHUTTERW_UPPER_REG					0x08
#define SHUTTERW_LOWER_REG					0x09
#define SHUTTER_DELAY_REG						0x0c

#define ROW_SIZE_REG								0x03
#define COL_SIZE_REG								0x04
#define ROW_ADDRESS_MODE_REG				0x22
#define COL_ADDRESS_MODE_REG				0x23

#define READ_MODE1_REG							0x1e
#define READ_MODE2_REG							0x20

#define RESTART_REG									0x0b

#define BLACK_LVL_CAL_REG						0x62

#define TEST_PATTERN_CTRL_REG				0xa0
#define TEST_PATTERN_GREEN_REG			0xa1
#define TEST_PATTERN_REG_REG				0xa2
#define TEST_PATTERN_BLUE_REG				0xa3
#define TEST_PATTERN_BARW_REG				0xa4

#define TEST_CLASSIC								(4 << 3)
#define TEST_MARCHING_ONES					(5 << 3)
#define TEST_MONOCR_HORIZONTAL			(6 << 3)
#define TEST_MONOCR_VERTICAL				(7 << 3)
#define TEST_ENABLE									1


#endif /* CAMERA_H */
