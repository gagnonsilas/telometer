#include "telemetry.h"

// #include <bits/types/FILE.h>
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

namespace telemetry {

  unsigned int availableForWrite() {
    return sizeof(data);
  }

  unsigned int available() {
    int available;
    ioctl(serial, FIONREAD, &available);
    return available;
  }

  int serial_try_open(const char* name = "romi") {
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

  void write(const uint8_t *buffer, unsigned int size) {
    ::write(serial, buffer, size);
  }

  void read (uint8_t *buffer, unsigned int size) {
    ::read(serial, buffer, size);
  }

  void init() {
    printf("serial: %d\n", serial_try_open());

    for(unsigned int i = 0; i < sizeof(data_values)/sizeof(union data*); i++) {
      data_values[i] = (data*) malloc(sizeof(union data));
    }
  }
}
