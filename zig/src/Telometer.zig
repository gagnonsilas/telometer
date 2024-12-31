const std = @import("std");
const telometer = @cImport({
    @cInclude("Telometer.h");
});

pub const PacketState = telometer.TelometerPacketState;
pub const Data = telometer.TelometerData;
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
                .packet_struct = std.mem.bytesAsSlice(Data, std.mem.asBytes(packet_struct)),
            };
        }

        pub fn update(self: *Self) void {
            for (0..self.count) |i| {
                const current_id: u8 = @truncate(self.next_packet + i % self.count);

                var packet = self.packet_struct[current_id];

                if (packet.state == telometer.TelometerSent or packet.state == telometer.TelometerReceived) {
                    continue;
                }

                if (!self.backend.writePacket(.{ .id = current_id }, packet)) {
                    self.next_packet = current_id;
                    break;
                }

                packet.state = telometer.TelometerSent;

                while (self.backend.getNextHeader()) |header| {
                    if (header.id >= self.count) {
                        std.log.err("Invalid header\n", .{});
                        continue;
                    }

                    packet = self.packet_struct[header.id];

                    if (packet.state == telometer.TelometerLockedQueued) {
                        self.backend.read(null, packet.size) catch {};
                        continue;
                    }

                    self.backend.read(@as([*]u8, @ptrCast(packet.pointer)), packet.size) catch {};

                    packet.state = telometer.TelometerReceived;
                }
            }

            self.backend.update();
        }
    };
}
