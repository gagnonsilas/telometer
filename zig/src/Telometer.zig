const std = @import("std");
const telometer = @cImport({
    @cInclude("Telometer.h");
});

pub const PacketState = telometer.TelometerPacketState;
pub const Data = telometer.TelometerData;

pub fn TelometerInstance(comptime Backend: type, comptime PacketStruct: type) type {
    return struct {
        const Self = @This();
        backend: Backend,
        next_packet: u8 = 0,
        count: usize,
        packet_struct: PacketStruct,

        pub fn init(allocator: std.mem.Allocator, backend: Backend, packet_struct: PacketStruct) Self {
            inline for (@typeInfo(PacketStruct).Struct.fields) |packet| {
                @field(packet_struct, packet.name).pointer = @ptrCast(allocator.alloc(u8, @field(packet_struct, packet.name).size));
            }

            return Self{
                .backend = backend,
                .packet_struct = packet_struct,
                .count = @typeInfo(PacketStruct).Struct.fields.len,
            };
        }

        pub fn update(self: Self) void {
            for (0..self.count) |i| {
                const current_id = (self.next_packet + i) % self.count;

                var packet = @field(self.packet_struct, @typeInfo(PacketStruct).Struct.fields[current_id].name);

                if (packet.state == .TelometerSent or packet.state == .TelometerRecieved) {
                    continue;
                }

                if (!self.backend.writePacket(packet)) {
                    self.next_packet = current_id;
                    break;
                }

                packet.state = .TelometerSent;

                var id: usize = undefined;
                while (self.backend.getNextId(&id)) {
                    if (id >= self.count) {
                        std.log.err("Invalid header\n", .{});
                        continue;
                    }

                    packet = @field(self.packet_struct, @typeInfo(PacketStruct).Struct.fields[id].name);

                    if (packet.state == .TelometerLockedQueued) {
                        self.backend.read(null, packet.size);
                        continue;
                    }

                    self.backend.read(@ptrCast(packet.pointer), packet.size);

                    packet.state = .TelometerReceived;
                }
            }

            self.backend.update();
        }
    };
}
