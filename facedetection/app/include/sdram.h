/*
 * Project: SDRAM for SPEAR2
 * Author : Martin Luipersbeck
 * 
 * Description: defines and macros for usage of memory controller SDCTRL.
 *
 */

#ifndef __SDRAM_H__
#define __SDRAM_H__

#include <inttypes.h>

/* base addresses */
#define SDRAM_BASE      (0xE0000000)
#define SDRAM_BASE_IO   (0xFFF00000)

/* configuration registers */
#define SDRAM_CFG               (*(volatile uint32_t *const) (SDRAM_BASE_IO))
#define SDRAM_POWER_CFG	        (*(volatile uint32_t *const) (SDRAM_BASE_IO+4))

/* macros for data access */
#define SDRAM_DATA_BYTE(addr)	     (*(volatile uint8_t *const) (SDRAM_BASE+addr))
#define SDRAM_DATA_HALFWORD(addr)    (*(volatile uint16_t *const)(SDRAM_BASE+addr))
#define SDRAM_DATA_WORD(addr)	     (*(volatile uint32_t *const)(SDRAM_BASE+addr))

/* timing parameters */
#define SDRAM_REFRESH_EN        (1<<31)
#define SDRAM_TRP	        (1<<30)
#define SDRAM_TCD	        (1<<26)
#define SDRAM_TRFC(value)       (value<<27)

/* bank size */
#define SDRAM_BANKSIZE_8MB	(1<<23)
#define SDRAM_BANKSIZE_16MB     (2<<23)
#define SDRAM_BANKSIZE_32MB     (3<<23)
#define SDRAM_BANKSIZE_64MB     (4<<23)
#define SDRAM_BANKSIZE_128MB    (5<<23)
#define SDRAM_BANKSIZE_256MB    (6<<23)

/* column size */
#define SDRAM_COLSIZE_256	(0<<21)
#define SDRAM_COLSIZE_512       (1<<21)
#define SDRAM_COLSIZE_1024      (2<<21)
#define SDRAM_COLSIZE_2048_4096 (3<<21) /* bank size decides colsize, (banksize = 256) => 4096 else 2048 */

/* config bits */
#define SDRAM_PAGEBURST_EN      (1<<17)
#define SDRAM_MOBILE_SDR_EN     (1<<16) /* read only */
#define SDRAM_D64_EN	        (1<<15) /* read only */

/* commands */
#define SDRAM_CMD			(7<<18)
#define SDRAM_CMD_PRE_CHARGE	        (2<<18)
#define SDRAM_CMD_AUTO_REFRESH	        (4<<18)
#define SDRAM_CMD_LOAD_CMD_REG	        (6<<18)
#define SDRAM_CMD_LOAD_EXT_CMD_REG      (7<<18)

#endif // __SDRAM_H__
