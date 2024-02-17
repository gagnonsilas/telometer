#pragma once
#include "lib/logger/log.h"

packet read_next();

void update_packet(packet_id id);

void serial_update();

void serial_setup();

void close_serial();
