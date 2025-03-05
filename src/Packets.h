#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)                   \
    P(N, enabled, bool)                 \
    P(N, state, uint16_t)               \
    P(N, controlmode, uint16_t)         \
    P(N, transforms, jointsMat)         \
    P(N, time, double)                  \
    P(N, trajectoryPosition, vec3f)     \
    P(N, robotPos, vec3f)               \
    P(N, targetVel, vec3f)              \
    P(N, vel, vec3f)                    \
    P(N, jacobianVel, vec6f)            \
    P(N, jointPositions, vec4f)         \
    P(N, trajTime, float)               \
    P(N, targetPos, vec3f)              \
    P(N, det, float)                    \
    P(N, traj, trajectory)              \
    P(N, targetBall, vec3f)             \
    P(N, targetColor, uint16_t)         \
    P(N, targetAngle, float)            \
    P(N, currentAngle, float)           \
    P(N, rotVels, vec3f)                \
    P(N, CameraParams, CameraParameter) \
    P(N, distCoeffss, distCoeffs)      \
    P(N, maxVelocity, float)           \
    P(N, maxAcceleration, float)           \
    P(N, lookahead, float)           \


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
    P(N, float)            \
    P(N, CameraParameter)  \
    P(N, trajectory)       \
    P(N, distCoeffs)

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

typedef struct trajectoryPositions {
    vec3f p1, p2, p3, p4;
} trajectoryPositions;

typedef struct trajectoryAngles {
    float p1, p2, p3, p4;
} trajectoryAngles;

typedef struct trajectory {
    uint8_t len;
    trajectoryPositions positions;
    trajectoryAngles angles;
} trajectory;

typedef struct vec6f {
    float x;
    float y;
    float z;
    float wx;
    float wy;
    float wz;
} vec6f;
typedef struct distCoeffs {
    double k1;
    double k2;
    double k3;
    double p1;
    double p2;

} distCoeffs;
typedef struct rowVec4f {
    float x, y, z, w;
} rowVec4f;

typedef struct newStruct {
    float bob;
    uint32_t color;
} newStruct;

typedef struct CameraParameter {
    float Orange_L_H;
    float Orange_L_S;
    float Orange_L_V;
    float Orange_H_H;
    float Orange_H_S;
    float Orange_H_V;

    float Yellow_L_H;
    float Yellow_L_S;
    float Yellow_L_V;
    float Yellow_H_H;
    float Yellow_H_S;
    float Yellow_H_V;


    float Red_L_H;
    float Red_L_S;
    float Red_L_V;
    float Red_H_H;
    float Red_H_S;
    float Red_H_V;

    float Green_L_H;
    float Green_L_S;
    float Green_L_V;
    float Green_H_H;
    float Green_H_S;
    float Green_H_V;
} CameraParameter;

typedef struct translationMat {
    rowVec4f x, y, z, w;
} translationMat;

typedef struct jointsMat {
    translationMat joint0, joint1, joint3, joint4;
} jointsMat;


TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS)

extern struct TelemetryPackets packets;
