#pragma once

#include <cstddef>
#include <cstdint>

#define PACKET_TYPE_FORMAT(namespace, t, ...) t##namespace##Packet,

#define PACKET_STRUCT(namespace, id, packetType)                               \
  TelometerData id = {.type = (uint8_t)packetType##namespace##Packet,          \
                      .size = sizeof(packetType),                              \
                      .state = TelometerSent};

#define TYPEDEF(N, type, ...) __VA_OPT__(typedef __VA_ARGS__ type;)

#define TELOMETER_INSTANCE(name, packet_types, packets)                        \
  packet_types(TYPEDEF, name);                                                 \
  enum name##PacketTypes : uint8_t{packet_types(PACKET_TYPE_FORMAT, name)};    \
  struct name##Packets {                                                       \
    packets(PACKET_STRUCT, name)                                               \
  };                                                                           \
  constexpr size_t name##PacketCount =                                         \
      sizeof(TelemetryPackets) / sizeof(TelometerData);

enum TelometerPacketState {
  TelometerSent,
  TelometerQueued,
  TelometerLockedQueued,
  TelometerReceived,
};

struct TelometerData {
  void *pointer;
  uint8_t type;
  size_t size;
  TelometerPacketState state;
};
