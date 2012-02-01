#ifndef I2C_H
#define I2C_H

#define I2CCONFIG_BADDR ((uint32_t)-384)
#define I2CCONFIG_STATUS (*(volatile int *const) (I2CCONFIG_BADDR))
#define I2CCONFIG_DATA   (*(volatile int *const) (I2CCONFIG_BADDR+4))

#define i2c_write(reg,word)	{ \
	I2CCONFIG_STATUS = (((uint8_t) reg)<<16) | ((uint16_t) word); \
	uint32_t j; \
	for(j = 0; j < 1300; j++) asm volatile("nop\n\t"); \
	}

extern void initCamera(void);

#endif /* I2C_H */
