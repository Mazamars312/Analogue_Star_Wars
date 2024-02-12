#ifndef VIDEOS_H
#define VIDEOS_H
#ifdef __cplusplus
extern "C" {
#endif
#include "hardware.h"
void video_start();
void set_color (int8_t color);
void vg_set_halt (int dummy);
void drawline(int x2, int y2, int x1, int y1);
void clearpixel();
#ifdef __cplusplus
}
#endif
#endif