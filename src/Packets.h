#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)               \
    P(N, enabled, bool)             \
    P(N, state, uint16_t)           \
    P(N, transforms, jointsMat)     \
    P(N, time, double)              \
    P(N, trajectoryPosition, vec3f) \
    P(N, robotPos, vec3f)           \
    P(N, targetVel, vec3f)          \
    P(N, vel, vec3f)                \
    P(N, jacobianVel, vec6f)        \
    P(N, jointPositions, vec4f)     \
    P(N, trajTime, float)           \
    P(N, det, float)                \
    P(N, traj, trajectory)          \
    P(N, trajLength, int8_t)        \
    P(N, maxVelocity, float)        \
    P(N, maxAcceleration, float)    \
    P(N, targetPos, vec3f)


#define PACKET_TYPES(P, N) \
    P(N, uint32_t)         \
    P(N, int16_t)          \
    P(N, uint16_t)         \
    P(N, int32_t)          \
    P(N, uint64_t)         \
    P(N, bool)             \
    P(N, int8_t)           \
    P(N, vec3f)            \
    P(N, vec4f)            \
    P(N, vec6f)            \
    P(N, newStruct)        \
    P(N, jointsMat)        \
    P(N, double)           \
    P(N, trajectory)       \
    P(N, float)

typedef struct vec3f {
    float x;
    float y;
    float z;
} vec3f;

typedef struct vec4f {
    float x;
    float y;
    float z;
    float w;
} vec4f;

typedef struct trajectory {
    vec4f p1, p2, p3, p4;
} trajectory;

typedef struct vec6f {
    float x;
    float y;
    float z;
    float wx;
    float wy;
    float wz;

} vec6f;

typedef struct rowVec4f {
    float x, y, z, w;
} rowVec4f;

typedef struct newStruct {
    float bob;
    uint32_t color;
} newStruct;

typedef struct translationMat {
    rowVec4f x, y, z, w;
} translationMat;

typedef struct jointsMat {
    translationMat joint0, joint1, joint3, joint4;
} jointsMat;


TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
