#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, enabled, bool)                                                          \
  P(N, calibration, cal_en)                                                    \
  P(N, time, float)                                                            \
  P(N, deltaTime, float)                                                       \
  P(N, accel1, vec3_t)                                                         \
  P(N, accel2, vec3_t)                                                         \
  P(N, accel1Avg, vec3f_t)                                                     \
  P(N, accel2Avg, vec3f_t)                                                     \
  P(N, centerOfRotation, vec2f_t)                                              \
  P(N, mag, vec3l_t)                                                           

#define PACKET_TYPES(P, N)                                                     \
  P(N, uint32_t)                                                               \
  P(N, int16_t)                                                                \
  P(N, uint16_t)                                                               \
  P(N, int32_t)                                                                \
  P(N, uint64_t)                                                               \
  P(N, int8_t)                                                                 \
  P(N, bool)                                                                   \
  P(N, cal_en)                                                                 \
  P(N, vec3_t)                                                                 \
  P(N, vec2f_t)                                                                \
  P(N, vec3f_t)                                                                \
  P(N, vec3l_t)                                                                \
  P(N, newStruct)                                                              \
  P(N, double)                                                                 \
  P(N, float)


typedef struct cal_en {
  bool
    XL_l_z_up,
    XL_r_z_up,
    Mag_x,
    Mag_y,
    Mag_z;
} cal_en;

typedef struct vec3_t {
  int16_t x, y, z;
} vec3_t;

typedef struct vec3l_t {
  int32_t x, y, z;
} vec3l_t;

typedef struct vec2f_t {
  float x, y;
} vec2f_t;

typedef struct vec3f_t {
  float x, y, z;
} vec3f_t;

TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
