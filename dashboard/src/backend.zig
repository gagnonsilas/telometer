const std = @import("std");
const posix = std.posix;
const MAX_UDP_PACKET_SIZE = 1024;
const tm = @import("telometer");
pub const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});

const telemetry = @cImport({
    @cInclude("Packets.h");
});
// https://github.com/Hedwyn/canzig/blob/master/src/socketcan.zig :)

const CanError = error{
    SendFailed,
    InterfaceNotFound,
    SocketCanFailure,
    UnknownCanID,
};

const SockaddrCan = extern struct {
    can_family: u16 = posix.AF.CAN,
    can_ifindex: i32,
    data: [10]u8,
};

pub const CanFrame = extern struct {
    id: u32,
    len: u8,
    bytes: [3]u8,

    data: [8]u8 = undefined,
};

pub const Backend = CANBackend;

const StrError = error{
    BufferTooSmall,
};

// const interfaces: [3][]const u8 = .{ "can0", "can1", "vcan0" };

const interfaces = [_][]const u8{ "can0", "can1", "vcan0" };

/// Copies the characters from `input` to `output`
/// Returns StrError if output is too small
pub fn strcpy(input: []const u8, output: []u8) StrError!void {
    if (input.len > output.len) {
        std.debug.print("Input cannot fit into output", .{});
        return StrError.BufferTooSmall;
    }
    for (0..input.len) |i| {
        output[i] = input[i];
    }
}

var interface: i32 = 0;

const CANBackend: type = struct {
    const Self = @This();
    canSocket: posix.socket_t,
    addr: SockaddrCan,
    frame: CanFrame,
    data_start: usize,
    connected: bool,

    pub fn init() Self {
        var backend: Self = .{
            .canSocket = undefined,
            .addr = undefined,
            .frame = undefined,
            .data_start = 0,
            .connected = false,
        };
        backend.openCANSocket() catch |e| {
            std.debug.print("error trying to open can socket {}\n", .{e});
        };
        std.debug.print("huh? \n", .{});
        return backend;
    }

    pub fn openCANSocket(self: *Self) !void {
        self.connected = false;
        self.canSocket = try posix.socket(
            posix.AF.CAN,
            posix.SOCK.RAW | posix.SOCK.NONBLOCK,
            1, // CAN_RAW <linux/can.h>
        );

        var ifname = [_]u8{0} ** 16;
        try strcpy(interfaces[std.math.lossyCast(usize, interface)], &ifname); // :)

        var ifreq = posix.ifreq{
            .ifrn = .{ .name = ifname },
            .ifru = undefined,
        };

        posix.ioctl_SIOCGIFINDEX(self.canSocket, &ifreq) catch |e| {
            std.debug.print("ioctl reported: {}\nwhen trying to get the can interface index: {s}\n", .{ e, ifname });
            return CanError.InterfaceNotFound;
        };

        std.debug.print("CAN interface index is {}\n", .{ifreq.ifru.ivalue});

        self.addr = .{
            .can_ifindex = ifreq.ifru.ivalue,
            .data = undefined,
        };

        // @memset(&self.addr.data, &ifreq.ifru.ivalue);

        posix.bind(self.canSocket, @ptrCast(&self.addr), @sizeOf(SockaddrCan)) catch {
            return CanError.SocketCanFailure;
        };

        // catch {
        //     return CanError.SocketCanFailure;
        // };

        self.connected = true;
        std.debug.print("Bound to socketcan successfully\n", .{});
    }

    pub fn connect(self: *Self, addr: posix.sockaddr) void {
        self.addr = addr;
    }

    pub fn update(self: *Self) void {
        if (c.igBegin("Can Interface", null, 0)) {
            // const cstring: [18]u8 =;
            _ = c.igColorButton(
                "Connected",

                c.ImVec4{
                    .x = 0.1,
                    .y = 0.9 * @as(f32, @floatFromInt(@intFromBool(self.connected))),
                    .z = 0.05,
                    .w = 1,
                    // .w = @as(f32, @floatCast(self.connected)),
                },
                0,
                .{},
            );
            c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
            if (c.igButton("Connect", .{})) {
                self.openCANSocket() catch |e| {
                    std.debug.print("error trying to open can socket {}\n", .{e});
                };
            }
            c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
            // c.igPushItemWidth(c.igGetStyle().*.ite.x)

            if (c.igCombo_Str("Interface", &interface, "can0\x00can1\x00vcan0", 3)) {
                self.openCANSocket() catch |e| {
                    std.debug.print("error trying to open can socket {}\n", .{e});
                };
            }

            // if (c.igBegin)
        }
        c.igEnd();

        // self.readNextUDPPacket();
    }

    pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
        _ = data; // autofix
        _ = header; // autofix
        _ = self; // autofix

        // @memcpy(self.writeBuffer[self.writePointer .. self.writePointer + @sizeOf(tm.Header)], @as([*]u8, @constCast(@ptrCast(&header))));
        // self.writePointer += @sizeOf(tm.Header);
        // @memcpy(self.writeBuffer[self.writePointer .. self.writePointer + data.size], @as([*]u8, @ptrCast(data.pointer)));
        // self.writePointer += data.size;
        return false;
    }

    pub fn read(self: *Self, buffer: ?[*]u8, size: usize) !void {
        if (buffer) |buf| {
            if (self.frame.data.len < size) {
                std.debug.print("ok we fucked this one up folks - id:0x{x},  data len:{}, requested:{}\n", .{ self.frame.id, self.frame.data.len, size });
                return;
            }
            @memcpy(
                buf[0..size],
                self.frame.data[0..size],
            );
        }
    }

    pub fn translateHeader(self: Self, id: u32) !tm.Header {
        return switch (id) {
            0 => tm.Header{ .id = 0 },
            0x300 => tm.Header{ .id = 1 },
            0x707 => tm.Header{ .id = 2 },
            0x301 => tm.Header{ .id = 4 },
            (0x1918FF71 | 1 << 31) => tm.Header{ .id = 5 },
            0x708 => tm.Header{ .id = 6 },
            0x709 => tm.Header{ .id = 7 },
            (0x19107171 | 1 << 31) => tm.Header{ .id = 8 },
            (0x1928FF71 | 1 << 31) => tm.Header{ .id = 9 },
            (0x704) => {
                if (self.frame.data[0] == 3 and self.frame.data[1] == 1) {
                    return tm.Header{ .id = 10 };
                }
                return CanError.UnknownCanID;
            },
            0x401 => tm.Header{ .id = 11 },
            0x002 => tm.Header{ .id = 12 },
            ((0b111 << 8) | 0xC) => tm.Header{ .id = 14 },
            ((0b111 << 8) | 0xD) => tm.Header{ .id = 15 },
            (0x191AFF71 | 1 << 31) => tm.Header{ .id = 16 },
            // 1799 => tm.Header{ .id = 2 },
            else => CanError.UnknownCanID,
        };
    }

    pub fn getNextHeader(self: *Self) ?tm.Header {
        while (true) {
            const ret = std.posix.system.recvfrom(
                self.canSocket,
                @ptrCast(&self.frame),
                @sizeOf(CanFrame),
                0,
                null,
                null,
            );
            if (ret == -1) {
                return null;
            }
            // self.data_start = self.frame.data.len - self.frame.len;
            // return self.translateHeader(self.frame.id) catch continue;
            // if (self.frame.id == 0x02) {
            //     std.debug.print("frame: {any}\n ", .{self.frame});
            // }
            return tm.Header{ .id = self.frame.id };
        }
    }

    pub fn end(self: Self) void {
        posix.close(self.updSocket);
    }
};
