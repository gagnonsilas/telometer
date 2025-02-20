#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                 \
    P(N, test, uint32_t)              \
    P(N, transforms, jointsMat)       \
    P(N, millis, uint32_t)            \
    P(N, cubicTrajectory, vec3f)      \
    P(N, quinticTrajectory, vec3f)    \
    P(N, robotPos, vec3f)             \
    P(N, vel, vec3f)                  \
    P(N, jacobianVel, vec3f)          \
    P(N, wft, vec3f)                  \
    P(N, structThatIsCool, newStruct) \
    P(N, trajectory, float)


#define PACKET_TYPES(P, N) \
    P(N, uint32_t)         \
    P(N, int16_t)          \
    P(N, uint16_t)         \
    P(N, int32_t)          \
    P(N, uint64_t)         \
    P(N, bool)             \
    P(N, int8_t)           \
    P(N, vec3f)            \
    P(N, newStruct)        \
    P(N, jointsMat)        \
    P(N, float)

typedef struct vec3f {
    float x;
    float y;
    float z;
} vec3f;

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
