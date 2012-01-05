#ifndef __DISPCTRL_H__
#define __DISPCTRL_H__

#define DISPCTRL_BASE (0xF0000200)
#define DISPCTRL_STATUS (*(volatile int *const) (DISPCTRL_BASE))
#define DISPCTRL_COLOR (*(volatile int *const) (DISPCTRL_BASE+4))
#define DISPCTRL_TL (*(volatile int *const) (DISPCTRL_BASE+8))
#define DISPCTRL_BR (*(volatile int *const) (DISPCTRL_BASE+12))

#define DRAW_RECT(xt,yt,xb,yb)	DISPCTRL_TL = (((uint16_t) yt)<<16) | ((uint16_t) xt); \
	DISPCTRL_BR = (((uint16_t) yb)<<16) | ((uint16_t) xb);

#define UPDATE_GLCD()	DISPCTRL_STATUS = 0; DISPCTRL_STATUS = DISPCTRL_UPDATE;
#define DISPCTRL_UPDATE 0x01

#endif // __DISPCTRL_H__
