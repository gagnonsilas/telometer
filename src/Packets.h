#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, enabled, bool)                                                     \
  P(N, PWM, bool)                                                        \
  P(N, PWM_Hz, float)                                                         \
  P(N, accel, vec3f)                                                         \
  P(N, gyro, vec3f)

typedef struct __attribute__((__packed__)) BrakeCountsInfo {
  uint16_t counts_one;
  uint16_t counts_two;
  uint16_t zero_one;
  uint16_t zero_two;
} BrakeCountsInfo;

typedef struct __attribute__((__packed__)) SusTravelCountsInfo {
  uint8_t id;
  uint16_t counts_one;
  uint16_t counts_two;
  // uint16_t zero_one;
  // uint16_t zero_two;
} SusTravelCountsInfo;

typedef struct __attribute__((__packed__)) MsgInverterHS3TemperatureFeedback {
  int16_t tempRemaining;
  int16_t motorTemp;
  int16_t dcLinkVoltage;
  uint8_t checksum;
  uint8_t seqCounter;
}MsgInverterHS3TemperatureFeedback;

typedef struct __attribute__((__packed__)) MsgInverterHC1Demands {
  int16_t torqueRequest;
  uint16_t controlWord;
  int16_t torqueLimit;
  uint8_t checksum;
  uint8_t seqCounter;
} MsgInverterHC1Demands;
typedef struct __attribute__((__packed__)) MsgInverterHD1DebugCurrents {
  int16_t Iq_ref;
  int16_t Id_ref;
  int16_t Iq_act;
  int16_t Id_act;
} MsgInverterHD1DebugCurrents;

enum CarStatus : uint8_t { OK = 0, NOT_OK, DRIVER_DECEASED, ON_FIRE };

typedef struct __attribute__((__packed__)) MsgCarHeartbeat {
  uint32_t tick;
  enum CarStatus status;
  bool rtd_status;
  uint8_t errno_;
  uint8_t caught;
} MsgCarHeartbeat;

typedef struct __attribute__((__packed__)) MsgVoltageResponse {
  uint8_t segmentID;
  uint8_t index;
  uint16_t voltages[3];
} MsgVoltageResponse;

typedef struct __attribute__((__packed__)) MsgCarVoltageDistribution {
  uint16_t min_voltage;
  uint16_t max_voltage;
  uint16_t avg_voltage;
  uint16_t current;
} MsgCarVoltageDistribution;

typedef struct vec2f {
  float x;
  float y;
} vec2f;
typedef struct vec3f {
  float x, y, z;
} vec3f;
TELOMETER_INSTANCE(Telemetry, PACKETS)

extern struct TelemetryPackets packets;
