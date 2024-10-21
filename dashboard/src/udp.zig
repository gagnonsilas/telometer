const std = @import("std");
const posix = std.posix;

const MAX_UDP_PACKET_SIZE = 1024;

pub fn UDPBackend(comptime Port: u16, comptime Data: type) type {
    return struct {
        const Self = @This();
        next_packet: i16 = 0,
        udpSocket: posix.socket_t,
        addr: posix.sockaddr,
        port: i16,

        readBuffer: [MAX_UDP_PACKET_SIZE]u8,
        readPointer: u16 = 0,
        writeBuffer: [MAX_UDP_PACKET_SIZE]u8,
        readAvailable: i16 = 0,
        writePointer: i16 = 0,

        pub fn openUDPSocket(self: Self) void {
            const local = try std.net.Address.parseIp("127.0.0.1", Port);
            self.udpSocket = try posix.socket(
                posix.AF.INET,
                posix.SOCK.DGRAM | posix.SOCK.NONBLOCK,
                posix.IPPROTO.UDP,
            );

            try posix.bind(self.udpSocket, local.any, local.getOsSockLen());
            // servaddr.sin_family = AF_INET;
            // servaddr.sin_port = htons(PORT);
            // servaddr.sin_addr.s_addr = inet_addr(ip);

            // int bind_rc =
            //     bind(udpSocket, (const struct sockaddr *)&servaddr, sizeof(servaddr));
            std.debug.print("udp openn\n");
        }

        pub fn readNextUDPPacket(self: Self) void {
            const n_recv = posix.recvfrom(
                self.udpSocket,
                self.readBuffer[0..],
                0,
                null,
                null,
            ) catch return;

            self.readPointer = 0;
            self.readAvailable = n_recv;
            std.debug.print(
                "received {d} byte(s) : {s}\n",
                .{ n_recv, self.readBuffer[0..n_recv] },
            );
        }

        // pub fn update() void {
        //   sendto(udpSocket, (const char *)writeBuffer, writePointer, 0,
        //          (const struct sockaddr *)&servaddr, sizeof(servaddr));
        //   readNextUDPPacket();
        // }

        pub fn writePacket(self: Self, data: Data) bool {
            self.writeBuffer[self.writePointer] = data.type;
            @memcpy(&self.writeBuffer[self.writePointer + @sizeOf(data.type)], @as([data.size]u8, data.pointer));

            return true;
        }

        // pub fn read(uint8_t *buffer, size: usize) {
        //   memcpy(buffer, &readBuffer[readPointer], size);
        //   readPointer += size;
        // }

        // pub fn getNextID(uint8_t *id) {
        //   if (available() < sizeof(id))
        //     readNextUDPPacket();
        //   if (available() < sizeof(id))
        //     return false;

        //   read((uint8_t *)id, sizeof(id));
        //   return true;
        // }

        pub fn end(self: Self) void {
            posix.close(self.updSocket);
        }
    };
}
