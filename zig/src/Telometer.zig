const std = @import("std");
const telometer = @cImport({@cInclude("../../src/Telometer.h");});

const PacketState = telometer.TelometerPacketState;
const Data = telometer.Data;

pub fn TelometerInstance(comptime Backend: type, comptime PacketStruct: type) type {
  return struct {
    const Self = @This();
    backend: Backend,
    next_packet: u8 = 0,
    packet_struct: [@sizeOf(PacketStruct) / @sizeof(Data)] Data,
    
    
    pub fn init(allocator: std.mem.Allocator, backend: Backend, packet_struct: PacketStruct) Self {
      
      inline for (packet_struct, 0..) |packet, i| {
        packet.pointer = @pointerCast(allocater.alloc(u8, packet.size));
        packet.
      }

      return Self{
        .backend = backend,
        .packet_struct = packet_struct,
      };
    }

    pub fn update(instance: Self) void {
      instance.backend.backendUpdateBegin();
      for (0..count) |i| {
        var currentId : usize = ((i + instance.next_packet) % instance.packet_struct.len);

        var packet: Data = instance.packet_struct[currentId];

        if (packet.state == TelometerSent or packet.state == TelometerReceived) {
          continue;
        }

        if (packet.size + sizeof(packetID) >
            instance.backend.availableForWrite()) {
          instance.next_packet = currentId;
          break;
        }

        instance.backend.writePacket(packet);

        packet.state = TelometerSent;
      }

      
      while (instance.backend.getNextID()) |id| {
    
        if (id >= instance.count) {
          debug("invalid header\n");
          continue;
        }

        var packet: Data = instance.packet_struct[id];

        if(packet.state == TelometerLockedQueued) {
          uint8_t* trashBin = (uint8_t*)alloca(packet.size);
          instance.backend.read(trashBin, packet.size);
          continue;
        }

        instance.backend.read(packet.pointer, packet.size);

        packet.state = TelometerReceived;
      }

      instance.backend.updateEnd();
    }

  };
}


// Log a value for a specific log ID
pub fn sendValue(packet: Data, data:*void) void {
  @memcpy(@as([packet.size]u8, packet.pointer), data);
  packet.state = TelometerQueued;
}

// Log a data pointer for a specific log ID
pub fn initPacket(packet: Data, data: *anyopaque) void {
  free(packet.pointer);
  packet.pointer = data;
  packet.state = TelometerQueued;
}

// Mark a packet for update
pub fn sendPacket(packet: Data) void { packet.state = TelometerQueued; }


