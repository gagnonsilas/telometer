const std = @import("std");
const posix = std.posix;

const MAX_UDP_PACKET_SIZE = 1024;
const tm = @import("telometer");

pub const Backend = UDPBackend;

const UDPBackend: type = struct {
    const Self = @This();
    udpSocket: posix.socket_t,
    addr: posix.sockaddr,
    socklen: posix.socklen_t,

    readBuffer: [MAX_UDP_PACKET_SIZE]u8,
    readPointer: usize = 0,
    writeBuffer: [MAX_UDP_PACKET_SIZE]u8,
    readAvailable: usize = 0,
    writePointer: usize = 0,

    pub fn init() Self {
        var self: Self = .{
            .readBuffer = undefined,
            .udpSocket = undefined,
            .addr = undefined,
            .socklen = undefined,
            .readPointer = 0,
            .writeBuffer = undefined,
            .readAvailable = 0,
            .writePointer = 0,
        };
        self.openUDPSocket(62895) catch unreachable;
        return self;
    }

    pub fn openUDPSocket(self: *Self, port: u16) !void {
        const local = try std.net.Address.parseIp("0.0.0.0", port);
        self.udpSocket = try posix.socket(
            posix.AF.INET,
            posix.SOCK.DGRAM | posix.SOCK.NONBLOCK,
            posix.IPPROTO.UDP,
        );

        try posix.bind(self.udpSocket, &local.any, local.getOsSockLen());

        std.debug.print("udp openn maybe?\n", .{});
    }

    pub fn readNextUDPPacket(self: *Self) void {
        // std.debug.print("read1? {}\n", .{0});
        const n_recv = posix.recvfrom(
            self.udpSocket,
            self.readBuffer[0..],
            0,
            &self.addr,
            &self.socklen,
        ) catch return;

        self.readPointer = 0;
        self.readAvailable = n_recv;

        // std.debug.print(
        //     "received {d} byte(s) : {s}\n",
        //     .{ n_recv, self.readBuffer[0..n_recv] },
        // );
    }

    pub fn connect(self: *Self, addr: posix.sockaddr) void {
        self.addr = addr;
    }

    pub fn update(self: *Self) void {
        if (self.writePointer > 0) {
            _ = posix.sendto(
                self.udpSocket,
                self.writeBuffer[0..self.writePointer],
                0,
                &self.addr,
                self.socklen,
            ) catch {};

            self.writePointer = 0;
        }

        self.readNextUDPPacket();
    }

    pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
        @memcpy(self.writeBuffer[self.writePointer .. self.writePointer + @sizeOf(tm.Header)], @as([*]u8, @constCast(@ptrCast(&header))));
        self.writePointer += @sizeOf(tm.Header);
        @memcpy(self.writeBuffer[self.writePointer .. self.writePointer + data.size], @as([*]u8, @ptrCast(data.pointer)));
        self.writePointer += data.size;
        return true;
    }

    pub fn read(self: *Self, buffer: ?[*]u8, size: usize) !void {
        if (self.readAvailable < size) {
            // std.debug.print("who tf readin? available: {}, size {}\n ", .{ self.readAvailable, size });
            // std.debug.panic("what thf fuck?\n", .{});
            return error.Oops;
            // return;
        }
        if (buffer) |buf| {
            @memcpy(
                buf[0..size],
                self.readBuffer[self.readPointer .. self.readPointer + size],
            );
        }
        self.readPointer += size;
        // self.readAvailable -= size;
    }

    pub fn getNextHeader(self: *Self) ?tm.Header {
        // std.debug.print("read available: {}, read pointer: {}\n", .{ self.readAvailable, self.readPointer });

        // std.debug.print("buffer? .{any}\n", .{self.readBuffer[0 .. self.readAvailable + 1]});
        if (self.readAvailable - self.readPointer < @sizeOf(tm.Header))
            return null;
        var header: tm.Header = undefined;
        self.read(@as([*]u8, @ptrCast(&header)), @sizeOf(@TypeOf(header))) catch unreachable;
        return header;
    }

    pub fn end(self: Self) void {
        posix.close(self.updSocket);
    }
};
