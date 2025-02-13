#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)             \
    P(N, test, uint32_t)          \
    P(N, transforms, jointsMat) \
    P(N, robotPos, uint16_t)      \
    P(N, test5, vec3f)            \
    P(N, test6, bool)             \
    P(N, test3, int32_t)          \
    P(N, float_numero_two, float) \
    P(N, test4, int8_t)

#define PACKET_TYPES(P, N) \
    P(N, uint32_t)         \
    P(N, int16_t)          \
    P(N, uint16_t)         \
    P(N, int32_t)          \
    P(N, bool)             \
    P(N, int8_t)           \
    P(N, vec3f)            \
    P(N, jointsMat)        \
    P(N, float)

typedef struct vec2f {
    float x;
    float y;
} vec2f;
typedef struct vec3f {
    float x;
    float y;
    int z;
    vec2f vec;
} vec3f;

typedef struct rowVec4f {
    float x, y, z, w;
} rowVec4f;

typedef struct translationMat {
    rowVec4f x, y, z, w;
} translationMat;

typedef struct jointsMat {
    translationMat joint0, joint1, joint3, joint4;
} jointsMat;


TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
