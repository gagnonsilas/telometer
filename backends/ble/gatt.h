#ifndef GATT_H
#define GATT_H
#include "host/ble_gatt.h"
#include "services/gatt/ble_svc_gatt.h"
#include "host/ble_gap.h"
#include "common.h"
#include <semaphore>

static std::binary_semaphore buf_rx_mutex(1); 
static std::binary_semaphore buf_tx_mutex(1);

class gatt {
public:
 
static void send_indication(void);
static int gatt_svc_init(void);

static int telometer_chr_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
static void gatt_svr_register_cb(struct ble_gatt_register_ctxt *ctxt, void *arg);
static void gatt_svr_subscribe_cb(struct ble_gap_event *event);

inline static uint8_t telometer_rx_buffer[MAX_BLE_PACKET_SIZE] = {0};
inline static uint8_t telometer_tx_buffer[MAX_BLE_PACKET_SIZE] = {0};
inline static uint16_t rx_buffer_len = 0;
inline static uint16_t tx_buffer_len = 0;
// static sem_t buf_rx_mutex;
// static sem_t buf_tx_mutex;
};


#endif