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

// const char *ip = "10.218.11.33";

const char *ip = "130.215.137.236";
// const char *ip = "192.168.144.20";


int next_packet = 0; 

int udpSocket;


struct pollfd poll_struct;
struct sockaddr_in servaddr; 


namespace Telemetry {
  uint8_t packetBuffer[MAX_PACKET_SIZE] = {};
  int readPointer = 0;

  void backendUpdate(){}

  unsigned int availableForWrite() { return MAX_PACKET_SIZE; }

  unsigned int available() {
    int available;
    // char *buffer[0];
    // available = recv(udpSocket, &buffer, 0, MSG_PEEK);
    ioctl(udpSocket, FIONREAD, &available);
    ::read(udpSocket, packetBuffer, available);
    readPointer = 0;
    return available;
  }

  int openUDPSocket(const char* name = "romi") {
    // serial = open("/dev/ttyACM0", O_NONBLOCK | O_RDWR);
    udpSocket = socket(AF_INET, SOCK_DGRAM, 0);
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(PORT);
    servaddr.sin_addr.s_addr = inet_addr(ip);
    // servaddr.sin_addr.s_addr = ip;

    int _= bind(udpSocket, (const struct sockaddr*) &servaddr, sizeof(servaddr));
    printf("udp openn\n");
    return udpSocket != -1;
  }

  void end() {
    // close(udpSocket);
  }

  void write(const uint8_t *buffer, unsigned int size) {
    printf("send\n");
    sendto(udpSocket, (const char *) buffer, size, 0, (const struct sockaddr*) &servaddr, sizeof(servaddr));
  }

  void read (uint8_t *buffer, unsigned int size) {
    memcpy(buffer, &packetBuffer[readPointer], size);
    readPointer += size;
  }

  void backendInit() {
    printf("udp: %d\n", openUDPSocket());
  }

  void* allocate(packet_id id ) { return malloc(dataSize(id)); }
  void deallocate(packet_id id ) { return free(data_values[id]); }

  void debug(const char* string) { printf("%s", string); }
  void clear(){}
}
