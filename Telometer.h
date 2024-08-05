#pragma once

#include "MathUtils.h"
#include <cstddef>
#include <stdint.h>

namespace Telometer {

#define PACKET_TYPE_FORMAT(t, ...) t##_packet,

#define PACKET_STRUCT(id, packet_type, typeNamespace)                          \
  ::Telometer::Data id = {.type =                                              \
                              (uint8_t)::typeNamespace::packet_type##_packet,  \
                          .size = sizeof(packet_type),                         \
                          .state = ::Telometer::PacketState::sent};

#define TYPEDEF(type, ...) __VA_OPT__(typedef __VA_ARGS__ type;)

#define PACKET(id, type, P, ...) P(id, type __VA_OPT__(, ) __VA_ARGS__)

#define TELOMETER_INSTANCE(name, packet_types, packets, backend)               \
  packet_types(TYPEDEF);                                                       \
  enum class name##PacketTypes : uint8_t{packet_types(PACKET_TYPE_FORMAT)};    \
  struct name##Packets {                                                       \
    packets(PACKET_STRUCT, name##PacketTypes)                                  \
  };                                                                           \
  constexpr size_t name##PacketCount =                                         \
      sizeof(TelemetryPackets) / sizeof(::Telometer ::Data);

constexpr uint8_t MAX_PACKET_SIZE = 64;

enum PacketState {
  sent,
  send,
  sendHighPriority,
  updated,
};

typedef uint8_t packet_id;

struct Data {
  void *pointer;
  uint8_t type;
  size_t size;
  PacketState state;
};

class Backend {
public:
  void backendInit();        // run after the main init
  void backendUpdateBegin(); // run before update every loop
  void backendUpdateEnd();   // run after update every loop
  unsigned int available();
  unsigned int availableForWrite();
  void writePacket(Data data);
  bool getNextID(uint8_t *id);
  void read(uint8_t *buffer, unsigned int size);
  void end();
  void *allocate(Data id);
  void deallocate(Data id);
};

struct TelometerInstance {
  Backend *backend;
  size_t count;
  packet_id nextPacket;
  Data packetStruct[];
};

void init(TelometerInstance instance);
void initPacket(Data packet, void* data); 
void sendPacket(Data packet);
void *sendValue(Data packet, void *data);
void debug(const char *string);

void update(TelometerInstance instance);
} // namespace Telometer

extern Telometer::Backend *backend;

#define PACKETS(args...)                                                       \
  PACKET(packet1, uint32_t, args)                                              \
  PACKET(packet3, vec3f, args)                                                 \
  PACKET(robotPos, uint32_t, args)

#define PACKET_TYPES(P)                                                        \
  P(uint32_t)                                                                  \
  P(vec3f, vec3<float>)

TELOMETER_INSTANCE(Telemetry, PACKET_TYPES, PACKETS, backend)

// In c file
TelemetryPackets Telemetry = {};

Telometer ::TelometerInstance TelemetryInstance = {
    .backend = backend,
    .count = TelemetryPacketCount,
    .nextPacket = 0,
    .packetStruct = {{(::Telometer ::Data *)&Telemetry}},
};

vec3f thing = {};

void test() {
  free(Telemetry.packet1.pointer);
  Telemetry.packet1.pointer = &thing;

  Telometer::initPacket(Telemetry.packet1, &thing);
}