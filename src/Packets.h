#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                                                          \
  P(N, Throttle, ThrottlePacket)                                               \
  P(N, Pedal, PedalInfo)                                                       \
  P(N, PedalFault, PedalFaultInfo)                                             \
  P(N, Brake, BrakePacket)                                                     \
  P(N, inverterHS1, MsgInverterHS1TorqueFeedback)                              \
  P(N, PedalCounts, CountsInfo)                                                \
  P(N, BrakeCounts, BrakeCountsInfo )                                          \
  P(N, IMU_PITCH, TelemPacket) 						       \
  P(N, inverterHD1, MsgInverterHD1DebugCurrents)

// P(N, IMU_ROLL, TelemPacket)                                                  \
  // P(N, IMU_X, TelemPacket)                                                     \
  // P(N, IMU_y, TelemPacket)                                                     \
  // P(N, IMU_Z, TelemPacket)                                                     \
  // P(N, MAG_X, TelemPacket)                                                     \
  // P(N, MAG_Y, TelemPacket)                                                     \
  // P(N, MAG_Z, TelemPacket)                                                     \
  // P(N, VBUS, TelemPacket)                                                      \
  // P(N, IBUS, TelemPacket)                                                      \
  // P(N, MOTOR_RPM, TelemPacket)                                                 \
  // P(N, GPS_LAT, TelemPacket)                                                   \
  // P(N, GPS_LON, TelemPacket)                                                   \
  // P(N, STEERING_WHEEL_ANGLE, TelemPacket)                                      \
  // P(N, SUSPENSION_FR, TelemPacket)                                             \
  // P(N, SUSPENSION_FL, TelemPacket)                                             \
  // P(N, SUSPENSION_BR, TelemPacket)                                             \
  // P(N, SUSPENSION_BL, TelemPacket)                                             \
  // P(N, WHEELSPEED_FR, TelemPacket)                                             \
  // P(N, WHEELSPEED_FL, TelemPacket)                                             \
  // P(N, WHEELSPEED_BR, TelemPacket)                                             \
  // P(N, WHEELSPEED_BL, TelemPacket)                                             \
  // P(N, DRIVER_HEARTRATE, TelemPacket)                                          \
  // P(N, PUMP_SPEED, TelemPacket)

#define PACKET_TYPES(P, N)                                                     \
  P(N, TelemPacket)                                                            \
  P(N, BrakePacket)                                                            \
  P(N, CountsInfo)                                                            \
  P(N, BrakeCountsInfo)                                                            \
  P(N, MsgInverterHS1TorqueFeedback)                                           \
  P(N, MsgInverterHD1DebugCurrents)                                           \
  P(N, PedalInfo)                                                              \
  P(N, PedalFaultInfo)                                                         \
  P(N, ThrottlePacket)                                                         \
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

// #define ID(namespace, id) (namespace << 8 | id)
// #define ThrottleID 768

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

typedef struct __attribute__((__packed__)) MsgInverterHD1DebugCurrents {
	int16_t Iq_ref;
	int16_t Id_ref;
	int16_t Iq_act;
	int16_t Id_act;
} MsgInverterHD1DebugCurrents;

TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
