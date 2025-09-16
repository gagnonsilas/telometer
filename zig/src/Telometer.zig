const std = @import("std");
const telometer = @cImport({
    @cInclude("Telometer.h");
});

pub const log = @import("Log.zig");

pub const Data = extern struct {
    pointer: *anyopaque,
    size: usize,
    queued: bool,
    locked: bool,
    received: bool,
};

fn packedSize(comptime T: type) usize {
    return @divExact(@bitSizeOf(T), 8);
}

pub const Header = telometer.TelometerHeader;

pub fn TelometerInstance(comptime Backend: type, comptime InstanceStruct: type) type {
    return struct {
        const Self = @This();
        const count: usize = @typeInfo(InstanceStruct).@"struct".fields.len;
        const log_header: log.Header = log.Header.init(12, InstanceStruct, 1, 0);
        pub const Logger = log.Log(InstanceStruct);
        backend: Backend,
        next_packet: u16 = 0,
        data: *InstanceStruct,
        packet_struct: [count]Data,
        log: Logger,

        pub fn init(allocator: std.mem.Allocator, backend: Backend) !Self {
            var self: Self = .{
                .backend = backend,
                // .packet_struct = &packet_struct,
                .data = @ptrCast(try allocator.alloc(InstanceStruct, 1)),
                .packet_struct = undefined,
                .log = undefined,
            };

            inline for (@typeInfo(InstanceStruct).@"struct".fields, &self.packet_struct) |field, *data| {
                data.pointer = @ptrCast(&(@field(self.data.*, field.name)));
                data.size = @sizeOf(field.type);
                data.queued = false;
                data.locked = false;
                data.received = false;
            }

            self.log = try log.Log(InstanceStruct).init(log_header, self.data);
            // for (self.packet_struct) |*data| {
            //     data.pointer = @ptrCast(&(@field(self.data.*, packet.name)));
            // }

            // self.packet_struct);

            return self;
        }

        pub fn close(self: *Self) void {
            self.log.endLog() catch unreachable;
        }

        pub fn update(self: *Self) void {
            for (&self.packet_struct) |*packet| {
                packet.received = false;
            }

            for (0..count) |i| {
                const current_id: u16 = @truncate(self.next_packet + i % count);

                var packet = &self.packet_struct[current_id];

                if (!packet.queued) {
                    continue;
                }

                if (!self.backend.writePacket(.{ .id = current_id }, packet.*)) {
                    self.next_packet = current_id;
                    break;
                }
                self.log.logPacket(.{ .id = current_id }, packet.*) catch unreachable;

                packet.queued = false;
                packet.locked = false;
            }

            while (self.backend.getNextHeader()) |header| {
                if (header.id >= count) {
                    std.log.err("Invalid header", .{});
                    continue;
                }

                var packet = &self.packet_struct[header.id];

                if (packet.locked) {
                    self.backend.read(null, packet.size) catch |e| {
                        std.debug.print("mega error?? {}\n", .{e});
                    };
                    continue;
                }

                self.backend.read(@as([*]u8, @ptrCast(packet.pointer)), packet.size) catch |e| {
                    std.debug.print("Error?? {}\n", .{e});
                };

                self.log.logPacket(header, packet.*) catch unreachable;

                packet.received = true;
            }

            self.backend.update();
        }
    };
}
