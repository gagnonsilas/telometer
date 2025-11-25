#pragma once

#include <stddef.h>
#include <stdint.h>

#define PACKET_TYPE_FORMAT(namespace, t, ...) t##namespace##Packet,

#define PACKET_STRUCT(namespace, id, packetType) TelometerData id;

#define TYPE_FORMAT(namespace, t, packetType)                                  \
  packetType t;

#define PACKET_INIT(namespace, id, packetType)                                 \
  .id = {                                                                      \
      .size = sizeof(packetType),                                              \
      .queued = 0,                                                             \
      .locked = 0,                                                             \
      .received = 0,                                                           \
  },

#define TYPEDEF(N, type, ...) __VA_OPT__(typedef __VA_ARGS__ type;)

#define TELOMETER_INSTANCE(name, packets)                        \
  typedef struct name##Packets {                                               \
    packets(PACKET_STRUCT, name)                                               \
  } name##Packets;                                                             \
  const size_t name##PacketCount =                                             \
      sizeof(name##Packets) / sizeof(TelometerData);                           \
  inline struct name##Packets init##name##Packets() {                          \
    return (name##Packets){packets(PACKET_INIT, name)};                        \
  }                                                                            \
  struct name##Types {                                                         \
    packets(TYPE_FORMAT, name);                                                \
  };

typedef struct TelometerData {
  void *pointer;
  size_t size;
  uint8_t queued;
  uint8_t locked;
  uint8_t received;
} TelometerData;

typedef struct TelometerHeader {
  uint32_t id;
} TelometerHeader;
