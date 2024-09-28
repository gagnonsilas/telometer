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
  void init();        // run after the main init
  void updateBegin(); // run before update every loop
  void updateEnd();   // run after update every loop
  bool writePacket(Data data);
  bool getNextID(uint8_t *id);
  void read(uint8_t *buffer, unsigned int size);
  void end();
};



typedef struct TelometerInstance {
  Backend *backend;
  size_t count;
  packetID nextPacket;
  Data packetStruct[];
} TelometerInstance;

void init(TelometerInstance instance);
void initPacket(Data packet, void *data);
void sendPacket(Data packet);
void sendValue(Data packet, void *data);
void debug(const char *string);

void update(TelometerInstance instance);
} // namespace Telometer
