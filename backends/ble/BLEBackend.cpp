#include "BLEBackend.h"
#include "gap.h"
#include "gatt.h"
// #include <semaphore>
#include "host/util/util.h"
#include <cstdint>
#include <cstring>

extern "C" {
  void ble_store_config_init(void);
}

// extern uint16_t tx_buffer_len;
// extern uint16_t rx_buffer_len;
  
namespace Telometer {
  
void BLEBackend::nimble_host_task(void *param) {
  ESP_LOGI(TAG, "nimble host task has been started!");
  nimble_port_run();
  vTaskDelete(NULL);
}

void BLEBackend::on_stack_reset(int reason) {
    /* On reset, print reset reason to console */
    ESP_LOGI(TAG, "nimble stack reset, reset reason: %d", reason);
}

void BLEBackend::on_stack_sync(void) {
    /* On stack sync, do advertising initialization */
    adv_init();
}

void BLEBackend::nimble_host_config_init(void) {
  /* Set host callbacks */
  ble_hs_cfg.reset_cb = on_stack_reset;
  ble_hs_cfg.sync_cb = on_stack_sync;
  ble_hs_cfg.gatts_register_cb = gatt::gatt_svr_register_cb;
  ble_hs_cfg.store_status_cb = ble_store_util_status_rr;

  /* Store host configuration */
  ble_store_config_init();
}

BLEBackend::BLEBackend() {
  int rc = 1;
  esp_err_t ret;

  ESP_LOGI(TAG, "Initialising BLE backend");

  ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
    ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    ret = nvs_flash_init();
  }
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "failed to initialize nvs flash, error code: %d ", ret);
    return;
  }

  /* NimBLE stack initialization */
  ret = nimble_port_init();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "failed to initialize nimble stack, error code: %d ",ret);
    return;
  }

  /* GAP service initialization */
  rc = gap_init();
  if (rc != 0) {
    ESP_LOGE(TAG, "failed to initialize GAP service, error code: %d", rc);
    return;
  }

  /* GATT server initialization */
  rc = gatt::gatt_svc_init();
  if (rc != 0) {
    ESP_LOGE(TAG, "failed to initialize GATT server, error code: %d", rc);
    return;
  }

  /* NimBLE host configuration initialization */
  nimble_host_config_init();

  /* Start NimBLE host task thread and return */
  xTaskCreate(nimble_host_task, "NimBLE Host", 4*1024, NULL, 5, NULL);

}

void BLEBackend::readBLEPacket() {
  // sem_wait(&buf_rx_mutex);
  buf_rx_mutex.acquire();
  if (gatt::rx_buffer_len > 0) {
    memcpy(read_buffer, gatt::telometer_rx_buffer, gatt::rx_buffer_len);
    read_available = gatt::rx_buffer_len;
    gatt::rx_buffer_len = 0;
    read_pointer = 0;
  }
  // sem_post(&buf_rx_mutex);
  buf_rx_mutex.release();
}

void BLEBackend::update() {
  if (write_pointer > 0) {
    // sem_wait(&buf_tx_mutex);
    buf_tx_mutex.acquire();
    gatt::tx_buffer_len = write_pointer;
    memcpy(gatt::telometer_tx_buffer, write_buffer, gatt::tx_buffer_len);
    // sem_post(&buf_tx_mutex);
    buf_tx_mutex.release();
    ESP_LOGI(TAG, "Update, len=%d", gatt::tx_buffer_len);
    write_pointer = 0;
    gatt::send_indication();
  }

  readBLEPacket();
}

bool BLEBackend::writePacket(TelometerHeader id, Data data) {
  if (write_pointer + sizeof(id.id) + data.size >= MAX_BLE_PACKET_SIZE) {
    return false;
  }
  // memcpy(&write_buffer[write_pointer], &data.type, sizeof(data.type));
  memcpy(&write_buffer[write_pointer], &id.id, sizeof(id.id));
  memcpy(&write_buffer[write_pointer + sizeof(id.id)], data.pointer,
         data.size);
  // write_pointer += sizeof(data.type) + data.size;
  write_pointer += sizeof(id.id) + data.size;
  // ESP_LOGI(TAG, "write_ptr=%d, tx_len=%d", write_pointer, gatt::tx_buffer_len);
  return true;
}

void BLEBackend::read(uint8_t *buffer, size_t size) {
  if (read_pointer + size > MAX_BLE_PACKET_SIZE) size = MAX_BLE_PACKET_SIZE - read_pointer;
  memcpy(buffer, &read_buffer[read_pointer], size);
  read_pointer += size;
}

uint16_t BLEBackend::available() {return read_available - read_pointer;}

bool BLEBackend::getNextHeader(TelometerHeader *id) {
  if (available() < sizeof(*id))
    readBLEPacket();
  if (available() < sizeof(*id))
    return false;

  read((uint8_t *)id, sizeof(*id));
  return true;
}

void BLEBackend::end() {
  nimble_port_stop();
}

} // namespace Telometer
