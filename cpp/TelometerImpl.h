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
  virtual void update() = 0; // run after at the end of update every loop
  virtual bool writePacket(TelometerHeader id, Data data) = 0;
  virtual bool getNextID(TelometerHeader *id) = 0;
  virtual void read(uint8_t *buffer, unsigned int size) = 0;
  virtual void end() = 0;
};

typedef struct TelometerInstance {
  Backend *backend;
  size_t count;
  packetID nextPacket = 0;
  Data *packetStruct;
} TelometerInstance;

void init(TelometerInstance instance);
void sendPacket(Data packet);
void sendValue(Data packet, void *data);
void debug(const char *string);

void update(TelometerInstance instance);
} // namespace Telometer
