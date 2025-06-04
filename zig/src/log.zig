const std = @import("std");

fn packedSize(comptime T: type) usize {
    return @divExact(@bitSizeOf(T), 8);
}

pub const Header = packed struct {
    const Self = @This();
    git_hash: u256,
    packet_header_hash: u256,
    block_size: usize,
    data_size: usize,
    packet_count: u32,

    pub fn init(packet_header_hash: u256, comptime PacketTypes: type) Self {
        var data_size = 0;

        for (@typeInfo(PacketTypes).Struct.fields) |thing| {
            data_size += @sizeOf(thing.type);
        }
        return .{
            .git_hash = 1,
            .packet_header_hash = packet_header_hash,
            .block_size = 8192,
            .data_size = data_size,
            .packet_count = @typeInfo(PacketTypes).Struct.fields.len,
        };
    }
};

pub fn Log(comptime PacketTypes: type) type {
    return struct {
        const Field = packed struct { id: u16, size: u16 };
        const FieldCorrection = struct { actualSize: usize };
        const numFields = @typeInfo(PacketTypes).Struct.fields.len;

        const Self = @This();
        file: std.fs.File,
        header: Header,
        fieldCorrections: [numFields]?FieldCorrection = @splat(null),

        pub fn init(header: Header) !Self {
            std.fs.cwd().access("log", .{}) catch {
                try std.fs.cwd().makeDir("log");
            };

            var self = Self{
                .file = try std.fs.cwd().createFile("log/test.tl", .{}),
                .header = header,
            };

            _ = try self.file.writer().write(&@as([packedSize(Header)]u8, @bitCast(header)));

            inline for (@typeInfo(PacketTypes).Struct.fields, 0..) |packet, i| {
                try self.file.writer().writeStruct(@as(
                    Field,
                    .{
                        .id = i,
                        .size = @sizeOf(packet.type),
                    },
                ));
            }

            return self;
        }

        pub fn initFromFile(filename: []const u8) !Self {
            var self = Self{
                .file = try std.fs.cwd().openFile(filename, .{ .read = true }),
                .header = undefined,
            };

            var buf: [packedSize(Header)]u8 = undefined;
            try self.file.reader().readNoEof(&buf);
            self.header = @bitCast(buf);

            inline for (@typeInfo(PacketTypes).Struct.fields, 0..) |packet, i| {
                const f = try self.file.reader().readStruct(Field);
                if (f.id != i) return error.BadHeader;
                if (f.size != @sizeOf(packet.type)) self.fieldCorrections[i] = .{ .actualSize = f.size };
            }

            return self;
        }

        pub fn log() void {
            std.time.microTimestamp();
        }

        pub fn close(self: *Self) void {
            self.file.close();
        }
    };
}
