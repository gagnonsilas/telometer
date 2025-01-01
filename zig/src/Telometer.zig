const std = @import("std");
const telometer = @cImport({
    @cInclude("Telometer.h");
});

pub const PacketState = enum(u8) {
    Sent = telometer.TelometerSent,
    Queued = telometer.TelometerQueued,
    LockedQueued = telometer.TelometerLockedQueued,
    Received = telometer.TelometerReceived,
};
// telometer.TelometerData;
pub const Data = extern struct {
    pointer: *anyopaque,
    size: usize,
    type: u8,
    state: PacketState,
};

pub const Header = telometer.TelometerHeader;

pub fn TelometerInstance(comptime Backend: type, comptime PacketStruct: type) type {
    return struct {
        const Self = @This();
        backend: Backend,
        next_packet: u8 = 0,
        count: usize = @typeInfo(PacketStruct).Struct.fields.len,
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
            for (0..self.count) |i| {
                const current_id: u8 = @truncate(self.next_packet + i % self.count);

                var packet = self.packet_struct[current_id];

                if (packet.state == PacketState.Sent or packet.state == PacketState.Received) {
                    continue;
                }

                if (!self.backend.writePacket(.{ .id = current_id }, packet)) {
                    self.next_packet = current_id;
                    break;
                }

                packet.state = PacketState.Sent;
            }

            while (self.backend.getNextHeader()) |header| {
                if (header.id >= self.count) {
                    std.log.err("Invalid header\n", .{});
                    continue;
                }

                var packet = self.packet_struct[header.id];

                if (packet.state == PacketState.LockedQueued) {
                    self.backend.read(null, packet.size) catch {};
                    continue;
                }

                self.backend.read(@as([*]u8, @ptrCast(packet.pointer)), packet.size) catch {};

                packet.state = PacketState.Received;
            }

            self.backend.update();
        }
    };
}
