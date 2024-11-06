#pragma once
// #include "MathUtils.h"


#include <stdint.h>

#define PACKETS(X) \
X(robotEnabled, uint16_t)\
X(loopTime, float)\
X(cos, float)\
X(sin, float)\
X(fxcool, float)\

#define PACKET_TYPES(X) \
X(uint16_t)\
X(int16_t)\
X(float)\
X(uint32_t)\

#define PACKET_TYPE_FORMAT(t) t##_packet,
#define UNION(type) type type##_packet;

#define PACKET_ID_FORMAT(id, type) id,
#define PACKET_ID_TYPE_FORMAT(id, type) type##_packet,
#define PACKET_ID_NAME(id, type) #id,
#define PACKET_SIZES(id, type) (packet_id) sizeof(type),

#define PACKET_HANDLER(t) \
void handle_##t(t packet);

// because vec2<float>_packet wouldn't work
typedef struct{ float x, y; } vec2f;

typedef struct vec6f { float vec[6];} vec6f;
typedef struct pathPoints { vec2f points[3];} pathPoints;


namespace Telemetry { 
  constexpr const uint8_t MAX_PACKET_SIZE = 64;
  constexpr const uint8_t PACKET_ALIGNMENT = 0xAA;

  enum packet_type {
    PACKET_TYPES(PACKET_TYPE_FORMAT)
  };

  enum packet_id : uint16_t { 
    PACKETS(PACKET_ID_FORMAT)
    // packet_alignment,
    packetIdsCount,
  };

  static const int packet_id_types[] = {
    PACKETS(PACKET_ID_TYPE_FORMAT)
  };

  static const packet_id packet_sizes[] = {
    PACKETS(PACKET_SIZES)
  };

  extern const char* packet_id_names[];

  typedef union data {
    PACKET_TYPES(UNION);
    // char alignment_packet[8] = {packet_alignment}; 
  } data;

  #pragma pack(push, 1)
  typedef struct packetHeader {
    packet_id id;
    uint8_t FFFF;
  } packetHeader;
  #pragma pack(pop)

  extern void* data_values[(int) packetIdsCount];
  extern uint8_t receivedUpdates[(int) packetIdsCount];

  void init();
  void update();
  int dataSize(packet_id id);
  void* initPacket(packet_id id, void *data); 
  void* getValue(packet_id id);
  void sendPacket(packet_id id);
  void* sendValue(packet_id id, void* data);

  void backendInit(); // run after the main init
  void backendUpdateBegin(); // run before update every loop
  void backendUpdateEnd(); // run before update every loop
  unsigned int available(); 
  unsigned int availableForWrite();
  void writePacket(packetHeader header, const uint8_t *buffer, unsigned int size);
  bool getNextHeader(packetHeader *header);
  void read(uint8_t *buffer, unsigned int size);
  void end();
  void* allocate(packet_id id);
  void deallocate(packet_id id);
  void debug(const char* string);
}
