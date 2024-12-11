#include "Telemetry.h"
#include <cstdio>

namespace Telemetry {  

  void* data_values[(int) packetIdsCount] = {};

  // Define global variables and arrays for logging
  uint8_t updated[(uint8_t) packetIdsCount] = {0};
  uint8_t receivedUpdates[(uint8_t) packetIdsCount] = {0};

  int nextPacket = 0;

  void copy(void* dest, const void* src, int size) {
    for(int i = 0; i < size; i++) {
      ((char*)dest)[i] = ((char*)src)[i];
    }
  }

  void init() {
    for(unsigned int i = 0; i < sizeof(data_values)/sizeof(void*); i++) {
      data_values[i] = allocate((packet_id)i);
    }
    backendInit();   
  }

  int dataSize(packet_id id) {
    return packet_sizes[id];
  }
  
  // Get the data pointer for a specific log ID
  void* getValue(packet_id id) {
    return data_values[id];
  }

  // Log a value for a specific log ID
  void* sendValue(packet_id id, void* data) {
    copy(data_values[id], data, dataSize(id));
    updated[id] = 1; 
    return data_values[id];
  }

  // Log a data pointer for a specific log ID
  void* initPacket(packet_id id, void* data) {
    deallocate(id);
    data_values[id] = data;
    updated[id] = 1;
    return data_values[id];
  }

  // Mark a packet for update
  void sendPacket(packet_id id) {
    updated[id] = 1;
  }

  void update() {
    backendUpdateBegin();
    for(int i = nextPacket; i < nextPacket + (int)packetIdsCount; i++) {
      packet_id currentId = (packet_id)(i % packetIdsCount);

      if(!updated[currentId]) {
        continue;
      }

      if(dataSize((packet_id)currentId) + sizeof(packetHeader) > availableForWrite()) {
        nextPacket = currentId; 
        goto read;
      }

      packetHeader header = (packetHeader){
        .id = currentId,
        .FFFF = PACKET_ALIGNMENT
      };

      writePacket(
        header,
        (const uint8_t*)data_values[currentId],
        dataSize(currentId)
      );

      updated[currentId] = 0;
    }

read:
    packetHeader header; 
    while(getNextHeader(&header)) { // Read incoming serial data and update corresponding packets
      if(header.id >= packetIdsCount || header.FFFF != PACKET_ALIGNMENT) {
        debug("invalid header: ");
        printf("%i, %i", header.id, header.FFFF);
        continue;
      }
      // debug("header: ");
      // printf("%i, %i\n", header.id, header.FFFF);
      // printf("-");

      uint8_t buffer[dataSize(header.id)];

      read((uint8_t*)&buffer, dataSize(header.id));


      // for(int i = 0; i < dataSize(header.id); i ++) {
      //   printf("%c, ", buffer[i]);
      // }
      // printf("\n");

      copy(data_values[header.id], buffer, dataSize(header.id));
      receivedUpdates[header.id] = 1;
    }
    backendUpdateEnd();
  }
}
