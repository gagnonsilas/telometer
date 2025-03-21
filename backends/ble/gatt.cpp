#include "gatt.h"
#include "common.h"
#include "esp_log.h"
#include <semaphore.h>
#include <assert.h>

// static int telometer_chr_access(uint16_t conn_handle, uint16_t attr_handle,
//                                  struct ble_gatt_access_ctxt *ctxt, void *arg);


static uint16_t telometer_chr_conn_handle = 0;
static bool telometer_chr_conn_handle_inited = false;
static bool telometer_ind_status = false;

static const ble_uuid16_t telometer_svc_uuid = BLE_UUID16_INIT(0x1815);
static uint16_t telometer_chr_val_handle;
static const ble_uuid128_t telometer_chr_uuid =
    BLE_UUID128_INIT(0x23, 0xd1, 0xbc, 0xea, 0x5f, 0x78, 0x23, 0x15, 0xde, 0xef,
                     0x12, 0x12, 0x25, 0x15, 0x00, 0x00);

/* GATT services table */
static const struct ble_gatt_svc_def gatt_svr_svcs[] = {
  /* Telometer service */
  {
    .type = BLE_GATT_SVC_TYPE_PRIMARY,
    .uuid = &telometer_svc_uuid.u,
    .characteristics =
    (struct ble_gatt_chr_def[]){
      {/* Telometer characteristic */
        .uuid = &telometer_chr_uuid.u,
        .access_cb = gatt::telometer_chr_access,
        .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_INDICATE,
        .val_handle = &telometer_chr_val_handle},
      {
        0,
      }
    }
  },

  {
    0,
  },
};

int gatt::telometer_chr_access(uint16_t conn_handle, uint16_t attr_handle,
                                 struct ble_gatt_access_ctxt *ctxt, void *arg) {
  int rc = 0;
  if (attr_handle != telometer_chr_val_handle) {
    return BLE_ATT_ERR_UNLIKELY;
  }
  switch (ctxt->op) {
    case BLE_GATT_ACCESS_OP_WRITE_CHR:
      ESP_LOGI(TAG, "Characteristic write access event, len=%d", ctxt->om->om_len);
      // sem_wait(&buf_rx_mutex);
      buf_rx_mutex.acquire();
      gatt::rx_buffer_len = ctxt->om->om_len;
      memcpy(gatt::telometer_rx_buffer, ctxt->om->om_data, gatt::rx_buffer_len);
      // sem_post(&buf_rx_mutex);
      buf_rx_mutex.release();
      return rc;
      break;
    case BLE_GATT_ACCESS_OP_READ_CHR:
      ESP_LOGI(TAG, "Characteristic read access event, len=%d", gatt::tx_buffer_len);
      // sem_wait(&buf_tx_mutex);
      buf_tx_mutex.acquire();
      rc = os_mbuf_append(ctxt->om, &gatt::telometer_tx_buffer, gatt::tx_buffer_len);
      // sem_post(&buf_tx_mutex);
      buf_tx_mutex.release();
      return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
      break;
    default:
      break;
  }
  return BLE_ATT_ERR_UNLIKELY;
  
}

/* Public functions */
void gatt::send_indication(void) {
  if (telometer_ind_status && telometer_chr_conn_handle_inited) {
    if (ble_gatts_indicate(telometer_chr_conn_handle, telometer_chr_val_handle) == 0)
      ESP_LOGI(TAG, "Indication sent!");
  }
}

/*
 *  Handle GATT attribute register events
 *      - Service register event
 *      - Characteristic register event
 *      - Descriptor register event
 */
void gatt::gatt_svr_register_cb(struct ble_gatt_register_ctxt *ctxt, void *arg) {
    /* Local variables */
    char buf[BLE_UUID_STR_LEN];

    /* Handle GATT attributes register events */
    switch (ctxt->op) {

    /* Service register event */
    case BLE_GATT_REGISTER_OP_SVC:
        ESP_LOGD(TAG, "registered service %s with handle=%d",
                 ble_uuid_to_str(ctxt->svc.svc_def->uuid, buf),
                 ctxt->svc.handle);
        break;

    /* Characteristic register event */
    case BLE_GATT_REGISTER_OP_CHR:
        ESP_LOGD(TAG,
                 "registering characteristic %s with "
                 "def_handle=%d val_handle=%d",
                 ble_uuid_to_str(ctxt->chr.chr_def->uuid, buf),
                 ctxt->chr.def_handle, ctxt->chr.val_handle);
        break;

    /* Descriptor register event */
    case BLE_GATT_REGISTER_OP_DSC:
        ESP_LOGD(TAG, "registering descriptor %s with handle=%d",
                 ble_uuid_to_str(ctxt->dsc.dsc_def->uuid, buf),
                 ctxt->dsc.handle);
        break;

    /* Unknown event */
    default:
        assert(0);
        break;
    }
}

void gatt::gatt_svr_subscribe_cb(struct ble_gap_event *event) {
    /* Check connection handle */
    if (event->subscribe.conn_handle != BLE_HS_CONN_HANDLE_NONE) {
        ESP_LOGI(TAG, "subscribe event; conn_handle=%d attr_handle=%d", event->subscribe.conn_handle, event->subscribe.attr_handle);
    } else {
        ESP_LOGI(TAG, "subscribe by nimble stack; attr_handle=%d", event->subscribe.attr_handle);
    }

    /* Check attribute handle */
    if (event->subscribe.attr_handle == telometer_chr_val_handle) {
        telometer_chr_conn_handle = event->subscribe.conn_handle;
        telometer_chr_conn_handle_inited = true;
        telometer_ind_status = event->subscribe.cur_indicate;
    }
}

int gatt::gatt_svc_init(void) {
  int rc;


  /* 1. GATT service initialization */
  ble_svc_gatt_init();

  /* 2. Update GATT services counter */
  rc = ble_gatts_count_cfg(gatt_svr_svcs);
  if (rc != 0) {
    return rc;
  }

  /* 3. Add GATT services */
  rc = ble_gatts_add_svcs(gatt_svr_svcs);
  if (rc != 0) {
    return rc;
  }

  return 0;
 
}
