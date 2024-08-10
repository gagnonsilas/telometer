#include "TelometerImpl.h"
#include <cstdlib>
#include <cstring>

namespace Telometer {

void init(TelometerInstance instance) {
  for (unsigned int i = 0; i < instance.count; i++) {
    instance.packetStruct[i].pointer = malloc(instance.packetStruct[i].size);
  }
  instance.backend->init();
}

void update(TelometerInstance instance) {
  instance.backend->updateBegin();
  for (int i = instance.nextPacket;
       i < instance.nextPacket + (int)instance.count; i++) {
    packetID currentId = (packetID)(i % instance.count);

    Data packet = instance.packetStruct[currentId];

    if (packet.state == TelometerSent || packet.state == TelometerReceived) {
      continue;
    }

    if (packet.size + sizeof(packetID) >
        instance.backend->availableForWrite()) {
      instance.nextPacket = currentId;
      break;
    }

    instance.backend->writePacket(packet);

    packet.state = TelometerSent;
  }

  packetID id;
  while (instance.backend->getNextID(&id)) {
    
    if (id >= instance.count) {
      debug("invalid header\n");
      continue;
    }

    Data packet = instance.packetStruct[id];

    if(packet.state == TelometerLockedQueued) {
      uint8_t* trashBin = (uint8_t*)alloca(packet.size);
      instance.backend->read(trashBin, packet.size);
      continue;
    }

    instance.backend->read((uint8_t *)packet.pointer, packet.size);

    packet.state = TelometerReceived;
  }

  instance.backend->pdateEnd();
}

// Log a value for a specific log ID
void sendValue(Data packet, void *data) {
  memcpy(packet.pointer, data, packet.size);
  packet.state = TelometerQueued;
}

// Log a data pointer for a specific log ID
void initPacket(Data packet, void *data) {
  free(packet.pointer);
  packet.pointer = data;
  packet.state = TelometerQueued;
}

// Mark a packet for update
void sendPacket(Data packet) { packet.state = TelometerQueued; }

} // namespace Telometer