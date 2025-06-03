const std = @import("std");

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

pub const Log = struct {
    const Self = @This();
    file: std.fs.File,
    header: Header,

    pub fn init(header: Header, comptime PacketTypes: type) !Self {
        std.fs.cwd().access("log", .{}) catch {
            try std.fs.cwd().makeDir("log");
        };

        var self = Self{
            .file = try std.fs.cwd().createFile("log/test.tl", .{}),
            .header = header,
        };

        try self.file.writer().writeStruct(header);

        try self.file.writer().writeStruct(@as(packed struct { a: u32 }, .{ .a = @sizeOf(Header) }));

        inline for (@typeInfo(PacketTypes).Struct.fields, 0..) |packet, i| {
            try self.file.writer().writeStruct(@as(
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

        return self;
    }

    pub fn log() void {
        std.time.microTimestamp();
    }

    pub fn close(self: *Self) void {
        self.file.close();
    }
};
