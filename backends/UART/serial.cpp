#include "Telemetry.h"

// #include <bits/types/FILE.h>
#include <cstdint>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/poll.h>
#include <unistd.h>
#include <poll.h>
#include <sys/ioctl.h>


int next_packet = 0; 

int serial;

struct pollfd poll_struct;

namespace Telemetry {

  void backendUpdateBegin(){
    
  }
  void backendUpdateEnd() {  
  }

  unsigned int availableForWrite() {
    return MAX_PACKET_SIZE;
  }

  unsigned int available() {
    int available;
    ioctl(serial, FIONREAD, &available);
    return available;
  }

  int openSerial(const char* name = "romi") {
    int rc = system("stty -F /dev/serial/by-id/* raw speed 115200 -echo -echoe -echok -echoctl -echoke");

    if(rc < 0) {
      return(-1);
    }
  
    serial = open("/dev/ttyACM0", O_NONBLOCK | O_RDWR);

    poll_struct.fd = serial;
    poll_struct.events = POLLRDNORM;
  
    printf("serial_open\n");
    return serial != -1;
  }

  void end() {
    close(serial);
  }

  void writePacket(packetHeader header, const uint8_t *buffer, unsigned int size) {
    ::write(serial, &header, sizeof(packetHeader));
    ::write(serial, buffer, size);
  }

  void read (uint8_t *buffer, unsigned int size) {
    ::read(serial, buffer, size);
    // for(int i = 0; i < size / 2; i++) {
    //   printf(" %hu", *((int16_t*)&buffer[i*2]));
    // }
    // printf("\n");
  }

  bool getNextHeader(packetHeader *header) {
    if(available() < sizeof(packetHeader))
      return false;

    read((uint8_t*)header, sizeof(packetHeader));
    // printf("header: %i | ", header->id);
    return true;
  }

  void backendInit() {
    printf("serial: %d\n", openSerial());
  }

  void debug(const char* string) {
    printf("%s", string);
  }
  
  void* allocate(packet_id id ) {
    return malloc(dataSize(id));
  }

  void deallocate(packet_id id ) {
    return free(data_values[id]);
  }

}
