#pragma once
#include "MathUtils.h"


#include <stdint.h>

#define PACKETS(X) \
X(robotEnabled, uint16_t)\
X(loopTime, uint16_t)\
X(voltage, uint16_t)\
X(position, vec2f)\
X(heading, angle)\
X(targetPathPoint, vec2f)\
X(targetAngle, angle)\
X(lineP, float)\
X(wheelVels, vec2f)\
X(motorsVolt, vec2f)\
X(drivetrainState, uint16_t)\
X(urfDistance, uint16_t)\
X(lineSpeed, float)\
X(imuAngleVel, vec3f)\
X(imuCalibration, uint16_t)\
X(imuAcceleration, vec3i16)\
X(gravity, vec3f)\
X(pitchAngle, angle)\
X(aprilTagID, int16_t)\
X(tagRotation, float)    \
X(lineMult, float) \
X(lineThresh, float)  \
X(lineDist, float) \
X(turnP, float)    \
X(currentMazeState, uint16_t) \
X(nearestLine, vec2f)\
X(lineSensorEstimatedHeading, angle)\
X(lineSensorRaw, vec6f)\
X(linePercievedWidth, float)\
X(passCode, uint32_t)\
X(doorLoc, uint32_t)\
X(path, pathPoints)\

#define PACKET_TYPES(X) \
X(uint16_t)\
X(int16_t)\
X(float)\
X(vec2f)\
X(vec2i)\
X(vec2i16)\
X(vec3i)\
X(vec3f)\
X(vec3i16)\
X(angle)\
X(vec6f)\
X(uint32_t)\
X(pathPoints)\

#define PACKET_TYPE_FORMAT(t) t##_packet,
#define UNION(type) type type##_packet;

#define PACKET_ID_FORMAT(id, type) id,
#define PACKET_ID_TYPE_FORMAT(id, type) type##_packet,
#define PACKET_ID_NAME(id, type) #id,
#define PACKET_SIZES(id, type) (packet_id) sizeof(type),

#define PACKET_HANDLER(t) \
void handle_##t(t packet);

// because vec2<float>_packet wouldn't work
typedef vec2<float> vec2f;
typedef vec3<float> vec3f;

typedef vec2<int16_t> vec2i16;
typedef vec3<int16_t> vec3i16;

typedef vec2<int> vec2i;
typedef vec3<int> vec3i;

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
