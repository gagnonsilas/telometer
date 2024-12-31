#pragma once

#include "Telometer.h"

#define PACKETS(P, N)                                                          \
  P(N, packet1, uint32_t)                                                      \
  P(N, packet3, vec3f)                                                         \
  P(N, robotPos, uint32_t)

#define PACKET_TYPES(P, N)                                                     \
  P(N, uint32_t)                                                               \
  P(N, vec3f, float)

TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;

