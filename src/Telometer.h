#pragma once

#include <stddef.h>
#include <stdint.h>

#define PACKET_TYPE_FORMAT(namespace, t, ...) t##namespace##Packet,

#define PACKET_STRUCT(namespace, id, packetType) TelometerData id;

#define PACKET_INIT(namespace, id, packetType)                                 \
  .id = {.type = (uint8_t)packetType##namespace##Packet,                       \
         .size = sizeof(packetType),                                           \
         .state = TelometerSent},

#define TYPEDEF(N, type, ...) __VA_OPT__(typedef __VA_ARGS__ type;)

#define TELOMETER_INSTANCE(name, packet_types, packets)                        \
  packet_types(TYPEDEF, name);                                                 \
  enum name##PacketTypes : uint8_t{packet_types(PACKET_TYPE_FORMAT, name)};    \
  typedef struct name##Packets {                                               \
    packets(PACKET_STRUCT, name)                                               \
  } name##Packets;                                                             \
  const size_t name##PacketCount =                                             \
      sizeof(name##Packets) / sizeof(TelometerData);                           \
  inline struct name##Packets init##name##Packets() {                          \
    return (name##Packets){packets(PACKET_INIT, name)};                        \
  }

typedef enum TelometerPacketState : uint8_t {
  TelometerSent,
  TelometerQueued,
  TelometerLockedQueued,
  TelometerReceived,
} TelometerPacketState;

typedef struct TelometerData {
  void *pointer;
  uint8_t type;
  size_t size;
  TelometerPacketState state;
} TelometerData;

typedef struct TelometerHeader {
  uint8_t id;
} TelometerHeader;
