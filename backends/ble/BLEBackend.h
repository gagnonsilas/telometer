#pragma once
#include "TelometerImpl.h"
#include "common.h"

#include "esp_log.h"
#include "gatt.h"
#include "nvs_flash.h"

#include <cstdint>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "nimble/ble.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"

#include <cstring>
#include <stdio.h>
#include <stdlib.h>
#include <semaphore.h>

namespace Telometer {

class BLEBackend : Backend {
public:
  BLEBackend();
  void update() override; // run after at the end of update every loop
  bool writePacket(TelometerHeader id, Data data) override;
  bool getNextHeader(TelometerHeader *id) override;
  void read(uint8_t *buffer, size_t size) override;
  void end() override;

private:

  uint8_t read_buffer[MAX_BLE_PACKET_SIZE] = {0};
  uint8_t write_buffer[MAX_BLE_PACKET_SIZE] = {0};
  int read_pointer = 0;
  int read_available = 0;
  int write_pointer = 0;
  uint16_t available(); 
  void readBLEPacket();
  static void nimble_host_task(void *param);
  static void on_stack_reset(int reason);
  static void on_stack_sync(void);
  static void nimble_host_config_init(void);
};

} // namespace Telometer
