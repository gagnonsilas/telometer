#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, CarHeartBeat, MsgCarHeartbeat)                                          \
  P(N, Throttle, ThrottlePacket)                                               \
  P(N, Pedal, PedalInfo)                                                       \
  P(N, Brake, BrakePacket)                                                     \
  P(N, inverterHS1, MsgInverterHS1TorqueFeedback)                              \
  P(N, PedalCounts, CountsInfo)                                                \
  P(N, BrakeCounts, BrakeCountsInfo)                                           \
  P(N, inverterHC1, MsgInverterHC1Demands)                                     \
  P(N, inverterHD1, MsgInverterHD1DebugCurrents)                               \
  P(N, Voltage, MsgVoltageResponse)                                            \
  P(N, MinMax, MsgCarVoltageDistribution)                                      \
  P(N, AMS, TelemPacket)                                                       \
  P(N, SusTravel, SusTravelCountsInfo)                                         \
  P(N, Wheelspeed, WheelSpeedMeasurement)                                      \
  P(N, inverterHS3, MsgInverterHS3TemperatureFeedback)

typedef struct __attribute__((__packed__)) MsgWheelSpeedMeasurement {
  uint8_t wheel_id;
  int32_t electrical_milliradians_second;
} WheelSpeedMeasurement;

typedef struct __attribute__((__packed__)) ThrottlePacket {
  uint32_t throttle;
  uint8_t flags;
} ThrottlePacket;

typedef struct Brake {
  uint32_t brake1;
  uint32_t brake2;
} BrakePacket;

typedef struct testPacket {
  uint8_t data[8];
} testPacket;

typedef struct TelemPacket {
  uint16_t data[4];
} TelemPacket;

typedef struct __attribute__((__packed__)) MsgInverterHS1TorqueFeedback {
  int16_t torqueMeasured;
  int16_t speedMeasured;
  int16_t dcLinkCurrent;
  uint8_t checksum;
  uint8_t seqCounter;
} MsgInverterHS1TorqueFeedback;

// typedef uint8_t bool;

typedef struct __attribute__((__packed__)) PedalInfo {
  int16_t pct_one;
  int16_t pct_two;
  bool limit_sw;
  uint8_t faults;
  uint16_t output;
} PedalInfo;

typedef struct __attribute__((__packed__)) PedalFaultInfo {
  uint16_t value;
  uint16_t a;
  uint16_t b;
  uint8_t flags;
  uint8_t pedal;
} PedalFaultInfo;

typedef struct __attribute__((__packed__)) CountsInfo {
  uint16_t counts1;
  uint16_t counts2;
  uint16_t zero1;
  uint16_t zero2;
} CountsInfo;

typedef struct newStruct {
  float bob;
  uint32_t color;
} newStruct;

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
  uint8_t status;
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

TELOMETER_INSTANCE(Telemetry, PACKETS)

extern struct TelemetryPackets packets;
