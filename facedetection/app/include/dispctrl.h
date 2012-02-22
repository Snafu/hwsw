#ifndef __DISPCTRL_H__
#define __DISPCTRL_H__

// SCARTS EXTENSION
#define DISPCTRL_BADDR							((uint32_t) -512)
#define DISPCTRL_STATUS							(*(volatile int *const) (DISPCTRL_BADDR))
#define DISPCTRL_TOPLEFT						(*(volatile int *const) (DISPCTRL_BADDR+4))
#define DISPCTRL_BOTTOMRIGHT				(*(volatile int *const) (DISPCTRL_BADDR+8))

#define NOFACE											((uint16_t) 480)

#define draw_rect(xt,yt,xb,yb)			{ \
	DISPCTRL_TOPLEFT = (((uint16_t) yt)<<16) | ((uint16_t) xt); \
	DISPCTRL_BOTTOMRIGHT = (((uint16_t) yb)<<16) | ((uint16_t) xb); \
	}

#define clear_rect()								{ \
	DISPCTRL_TOPLEFT = (NOFACE<<16) | NOFACE; \
	DISPCTRL_BOTTOMRIGHT = (NOFACE<<16) | NOFACE; \
	}

#endif // __DISPCTRL_H__
