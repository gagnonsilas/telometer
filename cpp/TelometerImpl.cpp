#include "TelometerImpl.h"
#include <cstdlib>
#include <cstring>

namespace Telometer {

void init(TelometerInstance instance) {}

void update(TelometerInstance instance) {

  for (int i = 0; i < (int)instance.count; i++) {
    instance.packetStruct[i].received = false;
  }

  for (int i = 0; i < (int)instance.count; i++) {
    uint16_t currentId = (instance.nextPacket + i) % instance.count;

    Data *packet = &instance.packetStruct[currentId];

    if (packet->queued) {
      continue;
    }

    if (!instance.backend->writePacket({.id = currentId}, *packet)) {
      instance.nextPacket = currentId;
      break;
    }

    packet->locked = false;
    packet->queued = false;
  }

  TelometerHeader header;
  while (instance.backend->getNextHeader(&header)) {

    if (header.id >= instance.count) {
      debug("invalid header\n");
      continue;
    }

    Data *packet = &instance.packetStruct[header.id];

    if (packet->locked) {
      uint8_t *trashBin = (uint8_t *)alloca(packet->size);
      instance.backend->read(trashBin, packet->size);
      continue;
    }

    instance.backend->read((uint8_t *)packet->pointer, packet->size);

    packet->received = true;
  }

  instance.backend->update();
}

// Log a value for a specific log ID
void sendValue(Data packet, void *data) {
  memcpy(packet.pointer, data, packet.size);
  packet.queued = true;
}

// Log a data pointer for a specific log ID
void initPacket(Data packet, void *data) {
  packet.pointer = data;
  packet.queued = true;
}

// Mark a packet for update
void sendPacket(Data packet) { packet.queued = true; }

void debug(const char *string) {}

} // namespace Telometer