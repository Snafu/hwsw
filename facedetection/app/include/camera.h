#ifndef CAMERA_H
#define CAMERA_H

// SCARTS EXTENSION
#define CAMERA_BADDR								((uint32_t) -480)
#define CAMERA_STATUS								(*(volatile int *const) (CAMERA_BADDR))
#define CAMERA_YR_YG								(*(volatile int *const) (CAMERA_BADDR+4))
#define CAMERA_YB_CBR								(*(volatile int *const) (CAMERA_BADDR+8))
#define CAMERA_CBG_CBB							(*(volatile int *const) (CAMERA_BADDR+12))
#define CAMERA_CRR_CRG							(*(volatile int *const) (CAMERA_BADDR+16))
#define CAMERA_CRB_YBOUNDS					(*(volatile int *const) (CAMERA_BADDR+20))
#define CAMERA_CBBOUNDS_CRBOUNDS		(*(volatile int *const) (CAMERA_BADDR+24))
#define CAMERA_MODE									(*(volatile int *const) (CAMERA_BADDR+28))

#define MODE_COLOR									0
#define MODE_DSP										1

// TRDB-D5M I2C
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
#define TRIGGER											(1 << 2)

#define BLACK_LVL_CAL_REG						0x62

#define TEST_PATTERN_CTRL_REG				0xa0
#define TEST_PATTERN_GREEN_REG			0xa1
#define TEST_PATTERN_REG_REG				0xa2
#define TEST_PATTERN_BLUE_REG				0xa3
#define TEST_PATTERN_BARW_REG				0xa4

#define TEST_GRADIENT_HORIZONTAL		(1 << 3)
#define TEST_GRADIENT_VERTICAL			(2 << 3)
#define TEST_CLASSIC								(4 << 3)
#define TEST_MARCHING_ONES					(5 << 3)
#define TEST_MONOCR_HORIZONTAL			(6 << 3)
#define TEST_MONOCR_VERTICAL				(7 << 3)
#define TEST_ENABLE									1


extern void initCamera(void);
extern void setYFactors(int16_t rfac, int16_t gfac, int16_t bfac);
extern void setCbFactors(int16_t rfac, int16_t gfac, int16_t bfac);
extern void setCrFactors(int16_t rfac, int16_t gfac, int16_t bfac);
extern void setYBounds(uint8_t min, uint8_t max);
extern void setCbBounds(uint8_t min, uint8_t max);
extern void setCrBounds(uint8_t min, uint8_t max);
extern void setCamMode(uint8_t mode);


#endif /* CAMERA_H */
