const std = @import("std");
const posix = std.posix;

const MAX_UDP_PACKET_SIZE = 1024;
const tm = @import("telometer");

// https://github.com/Hedwyn/canzig/blob/master/src/socketcan.zig

const CanError = error{
    SendFailed,
    InterfaceNotFound,
    SocketCanFailure,
};

const SockaddrCan = extern struct {
    can_family: posix.sa_family_t = posix.AF.CAN,
    can_ifindex: i32,
};

pub const CanFrame = extern struct {
    can_id: u32,
    len: u8,
    pad: u8,
    res0: u8 = 0,
    len8_dlc: u8 = 8,
    data: [8]u8 = undefined,
};

pub fn CANBackend() type {
    return struct {
        const Self = @This();
        canSocket: posix.socket_t,
        addr: *posix.sockaddr,

        pub fn init() Self {
            var backend: Self = .{
                .canSocket = undefined,
                .addr = undefined,
            };
            backend.openCANSocket();
        }

        pub fn openCANSocket(self: *Self) !void {
            self.canSocket = try posix.socket(
                posix.AF.CAN,
                posix.SOCK.RAW,
                1, // CAN_RAW <linux/can.h>
            );

            const ifname = "can0";

            var ifreq = posix.ifreq{
                .ifrn = .{ .name = ifname },
                .ifru = undefined,
            };

            posix.ioctl_SIOCGIFINDEX(self.canSocket, &ifreq) catch |e| {
                std.debug.print("ioctl reported {} when trying to get the can interface index", .{e});
                return CanError.InterfaceNotFound;
            };

            std.debug.print("CAN interface index is {}", .{ifreq.ifru.ivalue});

            var can_addr: posix.sockaddr = .{
                .can_ifindex = ifreq.ifru.ivalue,
            };

            self.addr = @ptrCast(&can_addr);
            posix.bind(self.canSocket, self.addr, @sizeOf(SockaddrCan)) catch {
                return CanError.SocketCanFailure;
            };
            std.debup.print("Bound to socketcan successfully", .{});
        }

        pub fn canRecv(fd: posix.socket_t) CanFrame {
            var _frame: CanFrame = undefined;
            const ret = std.posix.system.recvfrom(fd, @ptrCast(&_frame), @sizeOf(CanFrame), 0, null, null);

            std.debug.print("Recv returned {}\n", .{ret});
            return _frame;
        }

        pub fn readNextUDPPacket(self: *Self) void {
            const n_recv = posix.recvfrom(
                self.canSocket,
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
                _ = posix.sendto(
                    self.canSocket,
                    self.writeBuffer[0..self.writePointer],
                    0,
                    &self.addr,
                    @sizeOf(posix.socklen_t),
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

        pub fn read(self: *Self, buffer: ?[*]u8, size: usize) void {
            if (buffer) |buf| {
                @memcpy(
                    buf[0..size],
                    self.readBuffer[self.readPointer .. self.readPointer + size],
                );
            }
            self.readPointer += size;
        }

        pub fn getNextHeader(self: *Self) ?tm.Header {
            if (self.readAvailable - self.readPointer < @sizeOf(tm.Header))
                return null;
            var header: tm.Header = undefined;
            self.read(@as([*]u8, @ptrCast(&header)), @sizeOf(@TypeOf(header)));
            return header;
        }

        pub fn end(self: Self) void {
            posix.close(self.updSocket);
        }
    };
}
