#include "Telemetry.h"

#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/poll.h>
#include <unistd.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>

#define PORT 62895


// const char *ip = "130.215.137.236"; // NOILES
// const char *ip = "130.215.137.232"; // NOILES IR ROBOT
// const char *ip = "130.215.23.103"; // AK
// const char *ip = "130.215.23.14"; // AK IR ROBOT
// const char *ip = "130.215.23.15"; // AK Goatworks-ESP-53
// const char *ip = "130.215.137.152"; // NOILES Goatworks-ESP-53
// const char *ip = "192.168.144.193"; // Silas Hotspot BAGEL
// const char *ip = "130.215.137.155"; // NOILES BAGEL 
const char *ip = "192.168.144.173"; // Silas Hotspot Goatworks-esp53
// const char *ip = "130.215.137.196"; // Kate Romi Noiles
// const char *ip = "192.168.253.20"; // Silas Hotspot 192.168.***.20
// const char *ip = "192.168.7.89"; // Silas Hotspot IR ROBOT


int next_packet = 0; 

int udpSocket;


struct pollfd poll_struct;
struct sockaddr_in servaddr; 

#define MAX_UDP_PACKET_SIZE 576

namespace Telemetry {
  uint8_t readBuffer[MAX_UDP_PACKET_SIZE] = {0};
  int readPointer = 0;
  int readAvailable = 0;
  int writePointer = 0;


  void backendUpdateBegin(){
    ioctl(udpSocket, FIONREAD, &readAvailable);
    ::read(udpSocket, readBuffer, (size_t) readAvailable);
    readPointer = 0;
  }

  void backendUpdateEnd() {  
  }

  unsigned int availableForWrite() { return MAX_PACKET_SIZE; }

  unsigned int available() {
    return readAvailable - readPointer;
  }

  int openUDPSocket(const char* name = "romi") {
    // serial = open("/dev/ttyACM0", O_NONBLOCK | O_RDWR);
    udpSocket = socket(AF_INET, SOCK_DGRAM, 0);
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(PORT);
    servaddr.sin_addr.s_addr = inet_addr(ip);
    // servaddr.sin_addr.s_addr = ip;

    int bind_rc = bind(udpSocket, (const struct sockaddr*) &servaddr, sizeof(servaddr));
    printf("udp openn\n");
    return udpSocket != -1 && bind_rc != -1;
  }


  void writePacket(packetHeader header, const uint8_t *buffer, unsigned int size) {
    static uint8_t writeBuffer[MAX_PACKET_SIZE] = {0};

    memcpy(&writeBuffer[0], &header, sizeof(packetHeader));
    memcpy(&writeBuffer[sizeof(packetHeader)], buffer, size);

    sendto(udpSocket, (const char *) writeBuffer, sizeof(packetHeader) + size, 0, (const struct sockaddr*) &servaddr, sizeof(servaddr));
  }


  void read (uint8_t *buffer, unsigned int size) {
    memcpy(buffer, &readBuffer[readPointer], size);
    readPointer += size;
    // for(int i = 0; i < size; i ++) {
    //   printf("%hhu ", buffer[i]);
    // }
    // printf(" | %i\n", size);
  }

  bool getNextHeader(packetHeader *header) {
    if(available() < sizeof(packetHeader))
      return false;

    read((uint8_t*)header, sizeof(packetHeader));
    // printf("header: %i | ", header->id);
    return true;
  }

  void backendInit() {
    printf("udp: %d\n", openUDPSocket());
  }

  void* allocate(packet_id id ) { return malloc(dataSize(id)); }
  void deallocate(packet_id id ) { return free(data_values[id]); }

  void debug(const char* string) { printf("%s", string); }


  void end() { // close(udpSocket); 
  }
}
