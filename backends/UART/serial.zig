const std = @import("std");
const posix = std.posix;
const zig_serial = @import("serial");

pub const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});

const tm = @import("telometer");

const ALIGNMENT: u8 = 0xAA;

pub const Backend = SerialBackend;

const SerialBackend: type = struct {
    const Self = @This();

    serial: std.fs.File,
    connected: bool,

    pub fn init() Self {
        var self: Self = .{};

        openSerial(&self, "/dev/ttyUSB0");

        return self;
    }

    pub fn openSerial(self: *Self, addr: []const u8) !void {
        // const cmd = [_][]const u8{ "stty", "-F", "/dev/serial/by-id/*", "raw", "speed", "115200", "-echo", "-echoe", "-echok", "-echoctl", "-echoke" };

        var iterator = try zig_serial.list();
        defer iterator.deinit();

        while (try iterator.next()) |port| {
            std.debug.print("path={s},\tname={s},\tdriver={s}\n", .{ port.file_name, port.display_name, port.driver orelse "<no driver recognized>" });
        }

        self.serial = std.fs.cwd().openFile(addr, .{ .mode = .read_write, .lock = .shared }) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{addr});
                return;
            },
            else => return err,
        };

        var flags = std.posix.fcntl(self.serial.handle, std.posix.F.GETFL, 0) catch unreachable;
        flags |= std.posix.SOCK.NONBLOCK;
        _ = std.posix.fcntl(self.serial.handle, std.posix.F.SETFL, flags) catch unreachable;

        try zig_serial.configureSerialPort(self.serial, zig_serial.SerialConfig{
            .baud_rate = 115200,
            .word_size = .eight,
            .parity = .none,
            .stop_bits = .one,
            .handshake = .none,
        });

        std.debug.print("serial openn\n", .{});
        self.connected = true;
    }

    pub fn update(self: *Self) void {
        if (c.igBegin("Serial Interface", null, 0)) {
            // const cstring: [18]u8 =;
            _ = c.igColorButton(
                "Connected",

                c.ImVec4{
                    .x = 0.1,
                    .y = 0.9 * @as(f32, @floatFromInt(@intFromBool(self.connected))),
                    .z = 0.05,
                    .w = 1,
                    // .w = @as(f32, @floatCast(self.connected)),
                },
                0,
                .{},
            );
            c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
            if (c.igButton("Connect", .{})) {
                self.openSerial("/dev/ttyACM0") catch |e| {
                    std.debug.print("error trying to open can socket {}\n", .{e});
                };
            }
            // c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
            // c.igPushItemWidth(c.igGetStyle().*.ite.x)

            // if (c.igCombo_Str("Interface", &interface, "/dev/ttyUSB0\x00/dev/ttyACM0\x00/dev/ttyACM1", 3)) {}

            if (c.igButton("Disconnect", .{})) {
                self.end();
            }

            // if (c.igBegin)
        }
        c.igEnd();
    }

    pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
        self.serial.writer().writeStruct(header) catch unreachable;
        self.serial.writer().writeByte(ALIGNMENT) catch unreachable;
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
        var available: usize = undefined;
        available = 0;

        var rx: [@sizeOf(tm.Header) + @sizeOf(@TypeOf(ALIGNMENT))]u8 = undefined;

        _ = std.posix.system.ioctl(self.serial.handle, std.posix.system.T.FIONREAD, @intFromPtr(&available));
        if (available < @sizeOf(@TypeOf(rx))) {
            return null;
        }

        self.read(@as([*]u8, @ptrCast(&rx)), rx.len) catch {
            return undefined;
        };

        while (rx[@sizeOf(tm.Header)] != ALIGNMENT) {
            _ = std.posix.system.ioctl(self.serial.handle, std.posix.system.T.FIONREAD, @intFromPtr(&available));
            if (available < @sizeOf(@TypeOf(ALIGNMENT)))
                return null;

            std.debug.print("{d} {c}\n", .{ rx[0], rx[0] });
            for (rx, 0..) |value, i| {
                if (i > 0)
                    rx[i - 1] = value;
            }
            self.read(@as([*]u8, @ptrCast(&rx[rx.len - 1])), 1) catch {
                return null;
            };
        }

        const header: tm.Header = @bitCast(rx[0..@sizeOf(tm.Header)].*);
        return header;
    }

    pub fn end(self: Self) void {
        self.serial.close();
        self.connected = false;
    }
};
