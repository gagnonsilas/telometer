#include "lib/Telemetry/telemetry.h"

#include <bits/types/FILE.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/poll.h>
#include <unistd.h>
#include <poll.h>
#include <sys/ioctl.h>

int updated[(int)telemetry::packet_ids_count];


int next_packet = 0; 

int serial;

bool log;

struct pollfd poll_struct;

namespace telemetry {


  void update_packet(int id) {
    updated[id] = 1;
  }


  int available() {
    int available;
    ioctl(serial, FIONREAD, &available);
    return available;
  }

  void send_packet(packet_id id) {
    updated[id] = 1;
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

  void update() {
  
    for(int i = next_packet; i < next_packet + telemetry::packet_ids_count; i++) {
      int current_id = i % telemetry::packet_ids_count;

      if(!updated[current_id]) {
        continue;
      }

      packet p = (packet){
        .id = static_cast<uint16_t>((packet_id) current_id),
        .value = *data_values[current_id]
      };

      write(serial, &p, sizeof(struct packet));

      updated[current_id] = 0;

      // printf("updated id: %d", current_id);
    }

    packet p = {};
    while(available() > sizeof(struct packet) && serial != -1) {

      read(serial, &p, sizeof(struct packet)); 
    
      if(p.id < 0 || p.id >= packet_ids_count) {
        fprintf(stderr, "PACKETS MISALIGNED\n");
        fprintf(stderr, "data: id-%d, x-%f, y-%f\n", p.id, p.value.vec2_packet.x, p.value.vec2_packet.y);
        end();
        serial_try_open();
        break;
      }

      *data_values[p.id] = p.value;
    }
  }

  void init() {
    printf("serial: %d\n", serial_try_open());

    for(unsigned int i = 0; i < sizeof(data_values)/sizeof(union data*); i++) {
      data_values[i] = (data*) malloc(sizeof(union data));
    }

    // printf("test %f\n", data_values[position]->vec2_packet.x);
  }
}
