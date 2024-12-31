#include "TelometerImpl.h"
#include <cstdlib>
#include <cstring>

namespace Telometer {

void init(TelometerInstance instance) {}

void update(TelometerInstance instance) {
  for (int i = instance.nextPacket;
       i < instance.nextPacket + (int)instance.count; i++) {
    packetID currentId = (packetID)(i % instance.count);

    Data packet = instance.packetStruct[currentId];

    if (packet.state == TelometerSent || packet.state == TelometerReceived) {
      continue;
    }

    if (instance.backend->writePacket(packet)) {
      instance.nextPacket = currentId;
      break;
    }

    packet.state = TelometerSent;
  }

  packetID id;
  while (instance.backend->getNextID(&id)) {

    if (id >= instance.count) {
      debug("invalid header\n");
      continue;
    }

    Data packet = instance.packetStruct[id];

    if (packet.state == TelometerLockedQueued) {
      uint8_t *trashBin = (uint8_t *)alloca(packet.size);
      instance.backend->read(trashBin, packet.size);
      continue;
    }

    instance.backend->read((uint8_t *)packet.pointer, packet.size);

    packet.state = TelometerReceived;
  }

  instance.backend->update();
}

// Log a value for a specific log ID
void sendValue(Data packet, void *data) {
  memcpy(packet.pointer, data, packet.size);
  packet.state = TelometerQueued;
}

// Log a data pointer for a specific log ID
void initPacket(Data packet, void *data) {
  packet.pointer = data;
  packet.state = TelometerQueued;
}

// Mark a packet for update
void sendPacket(Data packet) { packet.state = TelometerQueued; }

} // namespace Telometer