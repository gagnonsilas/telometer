#pragma once

#include "../src/Telometer.h"
#include <cstddef>
#include <cstdint>

namespace Telometer {
typedef TelometerData Data;
typedef TelometerPacketState PacketState;

typedef uint8_t packetID;

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
  packetID nextPacket;
  Data packetStruct[];
};

void init(TelometerInstance instance);
void initPacket(Data packet, void *data);
void sendPacket(Data packet);
void sendValue(Data packet, void *data);
void debug(const char *string);

void update(TelometerInstance instance);
} // namespace Telometer
