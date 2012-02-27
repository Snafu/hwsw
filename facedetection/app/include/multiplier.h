#ifndef __MULTIPLIER_H__
#define __MULTIPLIER_H__

// SCARTS EXTENSION
#define MULTIPLIER_BADDR							((uint32_t) -544)
#define MULTIPLIER_STATUS							(*(volatile int *const) (MULTIPLIER_BADDR))
#define MULTIPLIER_OPA								(*(volatile int *const) (MULTIPLIER_BADDR+4))
#define MULTIPLIER_OPB								(*(volatile int *const) (MULTIPLIER_BADDR+8))
#define MULTIPLIER_RESULT							(*(volatile int *const) (MULTIPLIER_BADDR+12))


extern inline int multiply(int a, int b);

#endif // __MULTIPLIER_H__
