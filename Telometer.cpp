#include "Telometer.h"

namespace Telometer {

void init(TelometerInstance instance) {
  for (unsigned int i = 0; i < sizeof(data_values) / sizeof(void *); i++) {
    data_values[i] = malloc((packet_id)i);
  }
  instance.backend->backendInit();
}

void update(TelometerInstance instance) {
  instance.backend->backendUpdateBegin();
  for (int i = instance.nextPacket;
       i < instance.nextPacket + (int)instance.count; i++) {
    packet_id currentId = (packet_id)(i % instance.count);

    Data packet = instance.packetStruct[currentId];

    if (packet.state == sent || packet.state == updatedRemote) {
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
  while (instance.backend->getNextID(
      &id)) { // Read incoming serial data and update corresponding packets
    // debug("test2\n");
    if (id >= instance.count) {
      debug("invalid header\n");
      continue;
    }

    Data packet = instance.packetStruct[id];

    instance.backend->read((uint8_t *)packet.pointer, packet.size);

    packet.state = updatedRemote;
  }
  instance.backend->backendUpdateEnd();
}
int dataSize(packet_id id) { return packet_sizes[id]; }

// Log a value for a specific log ID
void *sendValue(Data packet, void *data) {
  memcpy(packet.pointer, data, packet.size);
  packet.state = send;

  return data_values[id];
}

// Log a data pointer for a specific log ID
void initPacket(Data packet, void *data) {
  free(packet.pointer);
  packet.pointer = data;
  packet.state = updatedLocal;
  return data_values[id];
}

// Mark a packet for update
void sendPacket(Data packet) { packet.state = updatedLocal; }

} // namespace Telometer