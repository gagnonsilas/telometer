#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, packet1, uint32_t)                                                      \
  P(N, packet3, float)                                                         \
  P(N, robotPos, uint16_t)                                                     \
  P(N, test5, vec2f)                                                           \
  P(N, test6, bool)                                                            \
  P(N, test3, int32_t)                                                         \
  P(N, test4, int8_t)

#define PACKET_TYPES(P, N)                                                     \
  P(N, uint32_t)                                                               \
  P(N, int16_t)                                                                \
  P(N, uint16_t)                                                               \
  P(N, int32_t)                                                                \
  P(N, bool)                                                                   \
  P(N, int8_t)                                                                 \
  P(N, vec2f)                                                                  \
  P(N, float)

typedef struct vec2f {
  float x;
  float y;
} vec2f;

TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
