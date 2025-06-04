const std = @import("std");
const tm = @import("Telometer.zig");

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
    block_header_size: u32,

    pub fn init(packet_header_hash: u256, comptime PacketTypes: type) Self {
        return .{
            .git_hash = 1,
            .packet_header_hash = packet_header_hash,
            .block_size = 256,
            .data_size = @sizeOf(PacketTypes),
            .packet_count = @typeInfo(PacketTypes).Struct.fields.len,
            .block_header_size = 2 + @sizeOf(PacketTypes),
        };
    }
};

const LogError = error{
    BufferedWriterOverflow,
};

pub fn logPicker() void {}

pub fn Log(comptime PacketsStruct: type) type {
    return struct {
        const Field = packed struct { id: u16, size: u16 };
        const FieldCorrection = struct { actualSize: usize };
        const numFields = @typeInfo(PacketsStruct).Struct.fields.len;
        const BlockHeader = packed struct {
            next_header: u16,
        };
        const Self = @This();
        file: std.fs.File,
        header: Header,
        data: *PacketsStruct,
        reader: std.io.BufferedReader(4096, std.fs.File.Reader),
        writer: std.io.BufferedWriter(4096, std.fs.File.Writer),

        pub fn init(header: Header, data: *PacketsStruct) !Self {
            std.fs.cwd().access("log", .{}) catch {
                try std.fs.cwd().makeDir("log");
            };

            var self = Self{
                .file = try std.fs.cwd().createFile("log/test.tl", .{}),
                .header = header,
                .data = data,
                .reader = undefined,
                .writer = undefined,
            };

            self.reader = std.io.bufferedReader(self.file.reader());
            self.writer = std.io.bufferedWriter(self.file.writer());

            // try self.writer.writer().writeStruct(header);

            _ = try self.file.writer().write(&@as([packedSize(Header)]u8, @bitCast(header)));

            inline for (@typeInfo(PacketsStruct).Struct.fields, 0..) |packet, i| {
                try self.writer.writer().writeStruct(@as(
                    packed struct {
                        id: u16,
                        size: u16,
                    },
                    .{
                        .id = i,
                        .size = @sizeOf(packet.type),
                    },
                ));
            }

            try self.writer.flush();

            return self;
        }

        pub fn initFromFile(filename: []const u8, data: *PacketsStruct) !Self {
            var self = Self{
                .file = try std.fs.cwd().openFile(filename, .{ .read = true }),
                .header = undefined,
                .data = data,
                .reader = undefined,
                .writer = undefined,
            };

            self.reader = std.io.bufferedReader(self.file.reader());
            self.writer = std.io.bufferedWriter(self.file.writer());

            var buf: [packedSize(Header)]u8 = undefined;
            try self.file.reader().readNoEof(&buf);
            self.header = @bitCast(buf);

            inline for (@typeInfo(PacketsStruct).Struct.fields, 0..) |packet, i| {
                const f = try self.file.reader().readStruct(Field);
                if (f.id != i) return error.BadHeader;
                if (f.size != @sizeOf(packet.type)) self.fieldCorrections[i] = .{ .actualSize = f.size };
            }

            return self;
        }

        pub fn logPacket(self: *Self, header: tm.Header, data: tm.Data) !void {
            // std.debug.print("huh?\n", .{});

            const pos = try self.file.getPos();

            if (self.writer.end != 0) {
                try self.writer.flush();
            }

            try self.writer.writer().writeInt(i64, std.time.microTimestamp(), std.builtin.Endian.little);
            try self.writer.writer().writeStruct(header);
            try self.writer.writer().writeAll(@as([*]u8, @ptrCast(data.pointer))[0..data.size]);

            const overflow: i32 = @as(i32, @intCast(((pos % self.header.block_size) + self.writer.end))) - @as(i32, @intCast(self.header.block_size));

            if (overflow >= 0) {
                try self.writeBlockHeader((pos / self.header.block_size) + 1, @intCast(overflow));
            }

            try self.writer.flush();
        }

        pub fn writeBlockHeader(self: *Self, block_index: u64, block_overflow: u64) !void {
            if (self.writer.end + self.header.block_header_size > self.writer.buf.len) {
                return LogError.BufferedWriterOverflow;
            }

            const block_end: usize = self.writer.end - block_overflow;
            const block_header_end: usize = block_end + self.header.block_header_size;

            @memcpy(
                self.writer.buf[block_header_end .. block_header_end + block_overflow],
                self.writer.buf[block_end .. block_end + block_overflow],
            );

            self.writer.end = block_end;

            const block_header: BlockHeader = .{
                .next_header = @intCast((block_index * self.header.block_size) + self.header.block_header_size + block_overflow),
            };

            try self.writer.writer().writeStruct(block_header);
            try self.writer.writer().writeStruct(self.data.*);

            self.writer.end = block_header_end + block_overflow;
            std.debug.print("WOOOOOOOO!!!! block_index:{}, block_overflow:{}\n", .{ block_index, block_overflow });
        }

        pub fn close(self: *Self) void {
            self.file.close();
        }
    };
}
