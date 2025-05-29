const std = @import("std");
const telometer = @cImport({
    @cInclude("Telometer.h");
});

pub const Data = extern struct {
    pointer: *anyopaque,
    size: usize,
    queued: bool,
    locked: bool,
    received: bool,
};

pub const Header = telometer.TelometerHeader;

pub fn TelometerInstance(comptime Backend: type, comptime PacketStruct: type) type {
    return struct {
        const Self = @This();
        const count: usize = @typeInfo(PacketStruct).Struct.fields.len;
        backend: Backend,
        next_packet: u16 = 0,
        packet_struct: []Data,

        pub fn init(allocator: std.mem.Allocator, backend: Backend, packet_struct: *PacketStruct) !Self {
            inline for (@typeInfo(PacketStruct).Struct.fields) |packet| {
                @field(packet_struct, packet.name).pointer = @ptrCast(try allocator.alloc(u8, @field(packet_struct, packet.name).size));
            }

            return Self{
                .backend = backend,
                // .packet_struct = &packet_struct,
                .packet_struct = std.mem.bytesAsSlice(Data, std.mem.asBytes(packet_struct)),
            };
        }

        pub fn update(self: *Self) void {
            for (self.packet_struct) |*packet| {
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

                packet.queued = false;
                packet.locked = false;
            }

            var i: u32 = 0;
            while (self.backend.getNextHeader()) |header| {
                if (header.id >= count) {
                    std.log.err("Invalid header", .{});
                    continue;
                }

                var packet = &self.packet_struct[header.id];

                if (packet.locked) {
                    self.backend.read(null, packet.size) catch {};
                    continue;
                }

                self.backend.read(@as([*]u8, @ptrCast(packet.pointer)), packet.size) catch {};

                packet.received = true;
                i += 1;
            }

            self.backend.update();
        }
    };
}
