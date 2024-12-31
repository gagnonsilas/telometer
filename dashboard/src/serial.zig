const std = @import("std");
const posix = std.posix;
const zig_serial = @import("serial");

const tm = @import("telometer");

pub fn SerialBackend() type {
    return struct {
        const Self = @This();

        serial: std.fs.File,

        pub fn init() Self {
            return .{
                .serial = undefined,
            };
        }

        pub fn openSerial(self: *Self, addr: []const u8) !void {
            // const cmd = [_][]const u8{ "stty", "-F", "/dev/serial/by-id/*", "raw", "speed", "115200", "-echo", "-echoe", "-echok", "-echoctl", "-echoke" };

            var iterator = try zig_serial.list();
            defer iterator.deinit();

            while (try iterator.next()) |port| {
                std.debug.print("path={s},\tname={s},\tdriver={s}\n", .{ port.file_name, port.display_name, port.driver orelse "<no driver recognized>" });
            }

            self.serial = std.fs.openFileAbsolute(addr, .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => {
                    std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{addr});
                    return;
                },
                else => return err,
            };

            try zig_serial.configureSerialPort(self.serial, zig_serial.SerialConfig{
                .baud_rate = 115200,
                .word_size = .eight,
                .parity = .none,
                .stop_bits = .one,
                .handshake = .none,
            });

            std.debug.print("serial openn\n", .{});
        }

        pub fn update(self: *Self) void {
            _ = self;
        }

        pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
            self.serial.writer().writeStruct(header) catch unreachable;
            self.serial.writer().writeAll(@as([*]u8, @ptrCast(data.pointer))[0..data.size]) catch unreachable;
            return true;
        }

        pub fn read(self: *Self, buffer: ?[*]u8, size: usize) !void {
            if (buffer) |buf| {
                _ = try self.serial.reader().readAll(buf[0..size]);
            } else {
                try self.serial.seekBy(@intCast(size));
            }
        }

        pub fn getNextHeader(self: *Self) ?tm.Header {
            if (((self.serial.getEndPos() catch unreachable) - (self.serial.getPos() catch unreachable)) < @sizeOf(tm.Header))
                return null;

            var header: tm.Header = undefined;
            self.read(@as([*]u8, @ptrCast(&header)), @sizeOf(@TypeOf(header))) catch {
                return undefined;
            };

            return header;
        }

        pub fn end(self: Self) void {
            self.serial.close();
        }
    };
}
