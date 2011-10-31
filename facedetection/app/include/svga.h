#ifndef __SVGA_H__
#define __SVGA_H__

#define SVGA_BASE (0xF0000100)
#define SVGA_STATUS (*(volatile int *const) (SVGA_BASE))
#define SVGA_VIDEO_LENGTH (*(volatile int *const) (SVGA_BASE+4))
#define SVGA_FRONT_PORCH (*(volatile int *const) (SVGA_BASE+8))
#define SVGA_SYNC_LENGTH (*(volatile int *const) (SVGA_BASE+12))
#define SVGA_LINE_LENGTH (*(volatile int *const) (SVGA_BASE+16))
#define SVGA_FRAME_BUFFER (*(volatile int *const) (SVGA_BASE+20))
#define SVGA_DYN_CLOCK0 (*(volatile int *const) (SVGA_BASE+24))
#define SVGA_DYN_CLOCK1 (*(volatile int *const) (SVGA_BASE+28))
#define SVGA_DYN_CLOCK2 (*(volatile int *const) (SVGA_BASE+32))
#define SVGA_DYN_CLOCK3 (*(volatile int *const) (SVGA_BASE+36))
#define SVGA_CLUT (*(volatile int *const) (SVGA_BASE+40))


#define SVGA_VVIDEOLEN(x) (x<<16)
#define SVGA_HVIDEOLEN(x) (x)

#define SVGA_VPORCH(x)	(x<<16)
#define SVGA_HPORCH(x)	(x)

#define SVGA_VLINELEN(x)	(x<<16)
#define SVGA_HLINELEN(x)	(x)


#endif // __SVGA_H__
