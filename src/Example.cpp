#include "Example.h"
#include "../cpp/TelometerImpl.h"
#include "Telometer.h"


struct TelemetryPackets packets;

Telometer::Backend *myBackend = new Telometer::Backend();

Telometer::TelometerInstance telemetry = {
  .backend  = myBackend,
  .count = TelemetryPacketCount,
  .packetStruct = (Telometer::Data*)&packets
};

int main() {
  Telometer::init(telemetry);

  static uint32_t pos = 50;
  packets.robotPos.pointer = &pos;

  while(true) {
    pos++;
    packets.robotPos.state = TelometerQueued;
    Telometer::update(telemetry);
  }
  
  return 0;
}

void test() {
}
