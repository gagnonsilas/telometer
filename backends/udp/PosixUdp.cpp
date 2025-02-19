#include "PosixUdp.h"

#include <arpa/inet.h>
#include <cstring>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <sys/socket.h>
#include <unistd.h>
#include <linux/can.h>

namespace Telometer {

PosixUdpBackend::PosixUdpBackend(int port) : port{port} {
  printf("udp: %d\n", openUDPSocket());
}

void PosixUdpBackend::readNextUDPPacket() {
  ioctl(udpSocket, FIONREAD, &readAvailable);
  ::read(udpSocket, readBuffer, (size_t)readAvailable);
  readPointer = 0;
}

void PosixUdpBackend::update() {
  if(writePointer > 0) {
    sendto(udpSocket, (const char *)writeBuffer, writePointer, 0,
           (const struct sockaddr *)&servaddr, sizeof(servaddr));
    writePointer = 0;
  }
  readNextUDPPacket();
}

int PosixUdpBackend::openUDPSocket(const char *ip) {
  udpSocket = socket(PF_CAN, SOCK_DGRAM, CAN_RAW);
  memset(&servaddr, 0, sizeof(servaddr));
  servaddr.sin_family = AF_INET;
  servaddr.sin_port = htons(PORT);
  servaddr.sin_addr.s_addr = inet_addr(ip);

  int bind_rc =
      bind(udpSocket, (const struct sockaddr *)&servaddr, sizeof(servaddr));
  printf("udp openn\n");
  return udpSocket != -1 && bind_rc != -1;
}

bool PosixUdpBackend::writePacket(TelometerHeader id, Data data) {
  memcpy(&writeBuffer[writePointer], &data.type, sizeof(data.type));
  memcpy(&writeBuffer[writePointer + sizeof(data.type)], data.pointer,
         data.size);

  return true;
}

void PosixUdpBackend::read(uint8_t *buffer, unsigned int size) {
  memcpy(buffer, &readBuffer[readPointer], size);
  readPointer += size;
}

unsigned int PosixUdpBackend::available() {
  return readAvailable - readPointer;
}

bool PosixUdpBackend::getNextID(TelometerHeader *id) {
  if (available() < sizeof(*id))
    readNextUDPPacket();
  if (available() < sizeof(*id))
    return false;

  read((uint8_t *)id, sizeof(*id));
  return true;
}

void PosixUdpBackend::end() { close(udpSocket); }

} // namespace Telometer
