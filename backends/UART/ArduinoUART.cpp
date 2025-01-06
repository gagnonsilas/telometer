#include "ArduinoUART.h"
#include "../../cpp/TelometerImpl.h"
#include "../../src/Telometer.h"

#include <Arduino.h>

namespace Telometer {

void ArduinoUARTBackend::update() {} // run after at the end of update every loop

bool ArduinoUARTBackend::writePacket(TelometerHeader header, Data data) {
  Serial.write((uint8_t *)&header, sizeof(TelometerHeader));
  Serial.write(ALIGNMENT);
  Serial.write((uint8_t *)data.pointer, data.size);
  return true;
}
bool ArduinoUARTBackend::getNextHeader(TelometerHeader *header) {
  static bool splitLastPacket;

  uint8_t alignment = 0;
  if(Serial.available() < sizeof(TelometerHeader) + 1) {
    return false;
  }
  Serial.readBytes((uint8_t*)header, sizeof(TelometerHeader));
  Serial.readBytes(&alignment, 1);

  if(alignment != ALIGNMENT) {
    return false; 
  }

  return true;
}
void ArduinoUARTBackend::read(uint8_t *buffer, size_t size) { Serial.readBytes(buffer, size); }
void ArduinoUARTBackend::end() {}

} // namespace Telometer
