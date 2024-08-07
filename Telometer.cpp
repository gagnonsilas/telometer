#include "Telometer.h"
#include "Telemetry.h"
#include <cstring>

namespace Telometer {

void init(TelometerInstance instance) {
  for (unsigned int i = 0; i < instance.count; i++) {
    instance.packetStruct[i].pointer = malloc(instance.packetStruct[i].size);
  }
  instance.backend->backendInit();
}

void update(TelometerInstance instance) {
  instance.backend->backendUpdateBegin();
  for (int i = instance.nextPacket;
       i < instance.nextPacket + (int)instance.count; i++) {
    packet_id currentId = (packet_id)(i % instance.count);

    Data packet = instance.packetStruct[currentId];

    if (packet.state == sent || packet.state == received) {
      continue;
    }

    if (packet.size + sizeof(packet_id) >
        instance.backend->availableForWrite()) {
      instance.nextPacket = currentId;
      break;
    }

    instance.backend->writePacket(packet);

    packet.state = sent;
  }

  packet_id id;
  while (instance.backend->getNextID(&id)) {
    
    if (id >= instance.count) {
      debug("invalid header\n");
      continue;
    }

    Data packet = instance.packetStruct[id];

    if(packet.state == lockedQueued) {
      uint8_t* trashBin = (uint8_t*)alloca(packet.size);
      instance.backend->read(trashBin, packet.size);
      continue;
    }

    instance.backend->read((uint8_t *)packet.pointer, packet.size);

    packet.state = received;
  }

  instance.backend->backendUpdateEnd();
}

// Log a value for a specific log ID
void sendValue(Data packet, void *data) {
  memcpy(packet.pointer, data, packet.size);
  packet.state = queued;
}

// Log a data pointer for a specific log ID
void initPacket(Data packet, void *data) {
  free(packet.pointer);
  packet.pointer = data;
  packet.state = queued;
}

// Mark a packet for update
void sendPacket(Data packet) { packet.state = queued; }

} // namespace Telometer