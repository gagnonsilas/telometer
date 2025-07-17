#pragma once

#include "Telometer.h"

#include <stdbool.h>
#define PACKETS(P, N)         \
    P(N, speed, int16_t)      \
    P(N, feed, int16_t)       \
    P(N, motorEnable, bool)   \
    P(N, pumpEnable, bool)    \
    P(N, stepperEnable, bool) \
    P(N, spindleMeasured, int16_t) \

TELOMETER_INSTANCE(Telemetry, PACKETS)

extern struct TelemetryPackets packets;
