const std = @import("std");
const tm = @import("Telometer.zig");

fn packedSize(comptime T: type) usize {
    return @divExact(@bitSizeOf(T), 8);
}

const HEADER_VERSION = 1;

pub const Header = packed struct {
    const Self = @This();
    git_hash: u256,
    packet_header_hash: u256,
    block_size: usize,
    data_size: usize,
    packet_count: u32,
    block_header_size: u32,
    uid: u64,
    start_time: i64,
    end_time: i64,
    version: u32 = HEADER_VERSION,

    pub fn init(packet_header_hash: u256, comptime PacketTypes: type, uid: u64, start_time: i64) Self {
        return .{
            .git_hash = 1,
            .packet_header_hash = packet_header_hash,
            .block_size = 4096,
            .data_size = @sizeOf(PacketTypes),
            .packet_count = @typeInfo(PacketTypes).@"struct".fields.len,
            .block_header_size = 2 + @sizeOf(PacketTypes),
            .uid = uid,
            .start_time = start_time,
            .end_time = start_time,
            .version = HEADER_VERSION,
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
        const numFields = @typeInfo(PacketsStruct).@"struct".fields.len;
        const BlockHeader = packed struct {
            timestamp: i64,
            next_header: u16,
        };
        const Self = @This();
        file: std.fs.File,
        header: Header,
        new_data: *PacketsStruct,
        data: PacketsStruct = undefined,
        fieldCorrections: [numFields]?FieldCorrection = [1]?FieldCorrection{null} ** numFields,
        reader: std.io.BufferedReader(4096, std.fs.File.Reader) = undefined,
        writer: std.io.BufferedWriter(4096, std.fs.File.Writer) = undefined,
        current_time: i64,

        pub fn init(header: Header, data: *PacketsStruct) !Self {
            std.fs.cwd().access("log", .{}) catch {
                try std.fs.cwd().makeDir("log");
            };

            var self = Self{
                .file = try std.fs.cwd().createFile("log/test.tl", .{ .read = true }),
                .header = header,
                .new_data = data,
                .current_time = std.time.microTimestamp(),
            };

            self.reader = std.io.bufferedReader(self.file.reader());
            self.writer = std.io.bufferedWriter(self.file.writer());

            // try self.writer.writer().writeStruct(header);

            _ = try self.writer.writer().write(&@as([packedSize(Header)]u8, @bitCast(header)));

            inline for (@typeInfo(PacketsStruct).@"struct".fields, 0..) |packet, i| {
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

        // pub fn logPlayer(self: *Self) void {}

        pub fn initFromFile(filename: []const u8) !Self {
            var self = Self{
                .file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only }),
                .header = undefined,
                .new_data = undefined,
                .current_time = undefined,
            };

            self.reader = std.io.bufferedReader(self.file.reader());
            // self.writer = std.io.bufferedWriter(self.file.writer());

            var buf: [packedSize(Header)]u8 = undefined;
            try self.file.reader().readNoEof(&buf);
            self.header = @bitCast(buf);

            inline for (@typeInfo(PacketsStruct).@"struct".fields, 0..) |packet, i| {
                const f = try self.file.reader().readStruct(Field);
                if (f.id != i) return error.BadHeader;
                if (f.size != @sizeOf(packet.type)) {
                    self.fieldCorrections[i] = .{ .actualSize = f.size };
                    std.debug.print("HEADER MISMATCH: \"{s}\" expected size:{}, found size:{}\n", .{
                        packet.name,
                        @sizeOf(packet.type),
                        f.size,
                    });
                }
            }

            std.debug.print("Field Corrections: {any}\n", .{self.fieldCorrections});

            std.debug.print("loaded file: {s}\n", .{filename});

            return self;
        }

        pub fn logPacket(self: *Self, header: tm.Header, data: tm.Data, timestamp: i64) !void {
            const pos = try self.file.getPos();

            if (self.writer.end != 0) {
                try self.writer.flush();
            }

            std.debug.print("what the fuck? {} \n", .{self.header.end_time});
            self.header.end_time = timestamp;
            try self.writer.writer().writeInt(i64, timestamp, std.builtin.Endian.little);
            try self.writer.writer().writeStruct(header);
            try self.writer.writer().writeAll(@as([*]u8, @ptrCast(data.pointer))[0..data.size]);

            const overflow: i32 = @as(i32, @intCast(((pos % self.header.block_size) + self.writer.end))) - @as(i32, @intCast(self.header.block_size));

            if (overflow >= 0) {
                try self.writeBlockHeader((pos / self.header.block_size) + 1, @intCast(overflow));
            }

            try self.writer.flush();
        }

        pub fn findBlock(self: *Self, micros: i64) i32 {
            const file_len = self.file.getEndPos() catch unreachable;
            const blocks = file_len / self.header.block_size;
            var blocks_left = blocks + 1;
            var seek_block = blocks_left / 2;
            // var current_block = seek_block;
            while (true) {
                const seek_pos = seek_block * self.header.block_size;
                self.file.seekTo(seek_pos) catch unreachable;
                const header = self.file.reader().readStruct(BlockHeader) catch unreachable;

                std.debug.print("fileSize: {}, seek_pos: {}, blocks: {}, file_pos: {},   \t header: {}, micros: {}\n", .{
                    file_len,
                    seek_pos,
                    blocks_left,
                    self.file.getPos() catch unreachable,
                    header,
                    micros,
                });

                std.debug.print("blocks_left: {}, seek_block: {},\n ", .{
                    blocks_left,
                    seek_block,
                });

                if (header.timestamp < micros) {
                    if (seek_block == blocks) {
                        return @intCast(seek_block);
                    }

                    self.file.seekTo(seek_pos + self.header.block_size) catch unreachable;
                    const next_header = self.file.reader().readStruct(BlockHeader) catch unreachable;

                    if (next_header.timestamp >= micros) {
                        return @intCast(seek_block);
                    }
                    blocks_left = blocks_left - (blocks_left / 2);
                    seek_block += blocks_left / 2;
                } else {
                    if (seek_block == 0) {
                        return @intCast(seek_block);
                    }
                    blocks_left = blocks_left / 2;
                    seek_block -= (blocks_left - blocks_left / 2);
                }
            }
            return 0;
        }

        pub fn seekToTime(self: *Self, micros: i64) void {
            _ = self.findBlock(micros);
            return;
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
                .timestamp = std.time.microTimestamp(),
                .next_header = @intCast(self.header.block_header_size + block_overflow),
            };

            try self.writer.writer().writeStruct(block_header);
            try self.writer.writer().writeStruct(self.new_data.*);

            self.writer.end = block_header_end + block_overflow;
            std.debug.print("WOOOOOOOO!!!! block_index:{}, block_overflow:{}\n", .{ block_index, block_overflow });
        }

        pub fn endLog(self: *Self) !void {
            self.header.end_time = self.current_time;
            try self.file.seekTo(0);
            _ = try self.writer.writer().write(&@as([packedSize(Header)]u8, @bitCast(self.header)));
            self.close();
        }

        pub fn close(self: *Self) void {
            self.file.close();
        }
    };
}
