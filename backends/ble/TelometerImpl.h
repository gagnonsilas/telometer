#pragma once

#include "Telometer.h"

namespace Telometer {
typedef TelometerData Data;

typedef uint16_t packetID;

class Backend {
public:
  virtual void update() = 0; // run after at the end of update every loop
  virtual bool writePacket(TelometerHeader header, Data data) = 0;
  virtual bool getNextHeader(TelometerHeader *header) = 0;
  virtual void read(uint8_t *buffer, size_t size) = 0;
  virtual void end() = 0;
};

typedef struct TelometerInstance {
  Backend *backend;
  uint16_t count;
  packetID nextPacket;
  Data *packetStruct;
} TelometerInstance;

void init(TelometerInstance *instance);
void sendPacket(Data packet);
void sendValue(Data packet, void *data);
void debug(const char *string);

void update(TelometerInstance *instance);
} // namespace Telometer
