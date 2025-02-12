const std = @import("std");
const posix = std.posix;
const zig_serial = @import("serial");

const tm = @import("telometer");

const ALIGNMENT: u8 = 0xAA;

pub const Backend = SerialBackend;

const SerialBackend: type = struct {
    const Self = @This();

    pub fn init() Self {
        const self: Self = .{};

        return self;
    }

    pub fn update(self: *Self) void {
        _ = self;
    }

    pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
        _ = self;
        _ = header;
        _ = data;
        return true;
    }

    pub fn read(self: *Self, buffer: ?[*]u8, size: usize) !void {
        _ = self;
        _ = buffer;
        _ = size;
    }

    pub fn getNextHeader(self: *Self) ?tm.Header {
        _ = self;
        return null;
    }

    pub fn end(self: Self) void {
        _ = self;
    }
};
