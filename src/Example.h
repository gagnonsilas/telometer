#pragma once

#include "Telometer.h"

#define PACKETS(P, N)                                                          \
  P(N, packet1, uint32_t)                                                      \
  P(N, packet3, vec3f)                                                         \
  P(N, robotPos, uint32_t)

#define PACKET_TYPES(P, N)                                                     \
  P(N, uint32_t)                                                               \
  P(N, vec3f, float)

typedef float vec3f;
;
enum TelemetryPacketTypes : uint8_t {
  uint32_tTelemetryPacket,
  vec3fTelemetryPacket,
};
struct TelemetryPackets {
  TelometerData packet1 = {.type = (uint8_t)uint32_tTelemetryPacket,
                           .size = sizeof(uint32_t),
                           .state = TelometerSent};
  TelometerData packet3 = {.type = (uint8_t)vec3fTelemetryPacket,
                           .size = sizeof(vec3f),
                           .state = TelometerSent};
  TelometerData robotPos = {.type = (uint8_t)uint32_tTelemetryPacket,
                            .size = sizeof(uint32_t),
                            .state = TelometerSent};
};
constexpr size_t TelemetryPacketCount =
    sizeof(TelemetryPackets) / sizeof(TelometerData);

extern TelemetryPackets packets;