const std = @import("std");
const posix = std.posix;

const MAX_UDP_PACKET_SIZE = 1024;

pub fn UDPBackend(comptime Data: type) type {
    return struct {
        const Self = @This();
        udpSocket: posix.socket_t,
        addr: posix.sockaddr,

        readBuffer: [MAX_UDP_PACKET_SIZE]u8,
        readPointer: usize = 0,
        writeBuffer: [MAX_UDP_PACKET_SIZE]u8,
        readAvailable: usize = 0,
        writePointer: usize = 0,

        pub fn init() Self {
            return .{
                .readBuffer = undefined,
                .udpSocket = undefined,
                .addr = undefined,
                .readPointer = 0,
                .writeBuffer = undefined,
                .readAvailable = 0,
                .writePointer = 0,
            };
        }

        pub fn openUDPSocket(self: *Self, port: u16) !void {
            const local = try std.net.Address.parseIp("0.0.0.0", port);
            self.udpSocket = try posix.socket(
                posix.AF.INET,
                posix.SOCK.DGRAM | posix.SOCK.NONBLOCK,
                posix.IPPROTO.UDP,
            );

            try posix.bind(self.udpSocket, &local.any, local.getOsSockLen());
            // servaddr.sin_family = AF_INET;
            // servaddr.sin_port = htons(PORT);
            // servaddr.sin_addr.s_addr = inet_addr(ip);

            // int bind_rc =
            //     bind(udpSocket, (const struct sockaddr *)&servaddr, sizeof(servaddr));
            std.debug.print("udp openn\n", .{});
        }

        pub fn readNextUDPPacket(self: *Self) void {
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
                "received {d} byte(s) : {s}",
                .{ n_recv, self.readBuffer[0..n_recv] },
            );
        }

        pub fn connect(self: *Self, addr: posix.sockaddr) void {
            self.addr = addr;
        }

        pub fn update(self: *Self) void {
            if (self.writePointer > 0) {
                _ = try posix.sendto(
                    self.udpSocket,
                    self.writeBuffer[0..self.writePointer],
                    0,
                    self.addr,
                    *self.addr.len,
                ) catch {};
                self.writePointer = 0;
            }
            readNextUDPPacket();
        }

        pub fn writePacket(self: Self, data: Data) bool {
            self.writeBuffer[self.writePointer] = data.type;
            @memcpy(&self.writeBuffer[self.writePointer + @sizeOf(data.type)], @as([data.size]u8, data.pointer));
            return true;
        }

        pub fn read(self: *Self, buffer: ?[]u8, size: usize) void {
            if (buffer) |buf| {
                @memcpy(
                    buf[0..size],
                    self.readBuffer[self.readPointer .. self.readPointer + size],
                );
            }
            self.readPointer += size;
        }

        pub fn getNextID(self: *Self) ?Data.id {
            if (self.readAvailable - self.readPointer < @sizeOf(Data.id))
                return null;
            var id: Data.id = undefined;
            self.read(&id, @sizeOf(id));
            return id;
        }

        pub fn end(self: Self) void {
            posix.close(self.updSocket);
        }
    };
}
