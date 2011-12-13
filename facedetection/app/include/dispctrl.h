#ifndef __DISPCTRL_H__
#define __DISPCTRL_H__

#define DISPCTRL_BASE (0xF0000200)
#define DISPCTRL_STATUS (*(volatile int *const) (DISPCTRL_BASE))
#define DISPCTRL_COLOR (*(volatile int *const) (DISPCTRL_BASE+4))

#define DISPCTRL_UPDATE 0x01

#endif // __DISPCTRL_H__
