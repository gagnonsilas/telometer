#pragma once
#include "../../cpp/TelometerImpl.h"
#include <netinet/in.h>
#include <sys/poll.h>

#define MAX_UDP_PACKET_SIZE 576
#define PORT 62895


namespace Telometer {

class PosixUdpBackend : Backend {
public:
  PosixUdpBackend(int port);
  void update() override; // run after at the end of update every loop
  bool writePacket(Data data) override;
  bool getNextID(uint8_t *id) override;
  void read(uint8_t *buffer, unsigned int size) override;
  void end() override;

private:
  int next_packet = 0;
  int udpSocket;
  int port;

  uint8_t readBuffer[MAX_UDP_PACKET_SIZE] = {0};
  int readPointer = 0;
  uint8_t writeBuffer[MAX_UDP_PACKET_SIZE] = {0};
  int readAvailable = 0;
  int writePointer = 0;
  struct pollfd poll_struct;
  struct sockaddr_in servaddr;
  void readNextUDPPacket();
  int openUDPSocket(const char* ip = "127.0.0.1");
  unsigned int available(); 
};

} // namespace Telometer
