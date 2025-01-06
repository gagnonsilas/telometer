#pragma once

#include "../../cpp/TelometerImpl.h"

namespace Telometer {

class ArduinoUARTBackend : public Backend {
public:
  void update(); // run after at the end of update every loop
  bool writePacket(TelometerHeader header, Data data);
  bool getNextHeader(TelometerHeader *header);
  void read(uint8_t *buffer, size_t size);
  void end();
private:
  const uint8_t ALIGNMENT = 0xAA;
};

} // namespace Telometer