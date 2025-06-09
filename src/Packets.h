#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, enabled, bool)                                                          \
  P(N, state, uint32_t)                                                        \
  P(N, controlmode, uint16_t)                                                  \
  P(N, time, double)


typedef struct newStruct {
  float bob;
  uint32_t color;
} newStruct;


TELOMETER_INSTANCE(Telemetry, PACKETS)

extern struct TelemetryPackets packets;
