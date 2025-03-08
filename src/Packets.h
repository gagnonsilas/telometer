#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, enabled, bool)                                                          \
  P(N, state, uint16_t)                                                        \
  P(N, controlmode, uint16_t)                                                  \
  P(N, time, double)

#define PACKET_TYPES(P, N)                                                     \
  P(N, uint32_t)                                                               \
  P(N, int16_t)                                                                \
  P(N, uint16_t)                                                               \
  P(N, int32_t)                                                                \
  P(N, uint64_t)                                                               \
  P(N, int8_t)                                                                 \
  P(N, bool)                                                                   \
  P(N, newStruct)                                                              \
  P(N, double)                                                                 \
  P(N, float)


typedef struct newStruct {
  float bob;
  uint32_t color;
} newStruct;


TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
