const std = @import("std");
const dbus = @cImport({
    @cInclude("dbus/dbus.h");
});

const MAX_BLE_PACKET_SIZE = 509;
const bluez: [*c]const u8 = "org.bluez";
const path: [*c]const u8 = "/org/bluez/hci0";
const adapter: [*c]const u8 = "org.bluez.Adapter1";
const device: [*c]const u8 = "org.bluez.Device1";
const tm = @import("telometer");

pub const Backend = BLEBackend;

const DBusError = extern struct {
    name: [*c]const u8,
    message: [*c]const u8,
    dummy: isize,
    padding: *opaque {},
};

const BLEBackend: type = struct {
    const Self = @This();

    tx_buf: [MAX_BLE_PACKET_SIZE]u8,
    tx_pointer: usize = 0,
    rx_buf: [MAX_BLE_PACKET_SIZE]u8,
    rx_pointer: usize = 0,
    rx_available: usize = 0,

    var connected: bool = false;
    var dev_path: [*c]const u8 = "";
    var buf_error: DBusError = undefined;
    var dbus_error: *dbus.DBusError = @ptrCast(&buf_error);
    var connection: ?*dbus.DBusConnection = null;
    var msgQuery: ?*dbus.DBusMessage = null;
    var msgReply: ?*dbus.DBusMessage = null;

    fn check(check_error: ?*dbus.DBusError) void {
        if (check_error != null and check_error != undefined and dbus.dbus_error_is_set(check_error) != 0) {
            std.debug.print("DBus Error {s}\n", .{buf_error.message});
        }
    }

    fn getBluetoothStatus() u8 {
        // var args: dbus.DBusMessageIter = undefined;
        msgQuery = dbus.dbus_message_new_method_call(bluez, path, "org.freedesktop.DBus.Properties", "Get");
        // std.debug.print("1\n", .{});
        // dbus.dbus_message_iter_init_append(msgQuery, &args);
        // std.debug.print("2\n", .{});
        // if (dbus.dbus_message_iter_append_basic(&args, dbus.DBUS_TYPE_STRING, &adapter.?) == 0) {
        //     std.debug.print("Out Of Memory!\n", .{});
        // }
        // std.debug.print("3\n", .{});
        // if (dbus.dbus_message_iter_append_basic(&args, dbus.DBUS_TYPE_STRING, "Powered") == 0) {
        //     std.debug.print("Out Of Memory!\n", .{});
        // }
        const powered: [*c]const u8 = "Powered";
        _ = dbus.dbus_message_append_args(msgQuery, dbus.DBUS_TYPE_STRING, &adapter, dbus.DBUS_TYPE_STRING, &powered, dbus.DBUS_TYPE_INVALID);
        // const va: dbus.va_list = .{ adapter, dbus.DBUS_TYPE_STRING, "Powered" };
        // _ = dbus.dbus_message_append_args(msgQuery, dbus.DBUS_TYPE_STRING, .{ adapter, dbus.DBUS_TYPE_STRING, "Powered", dbus.DBUS_TYPE_INVALID });
        msgReply = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        check(dbus_error);
        var iter: dbus.DBusMessageIter = undefined;
        var sub: dbus.DBusMessageIter = undefined;
        var result: u8 = 0;
        _ = dbus.dbus_message_iter_init(msgReply, &iter);
        dbus.dbus_message_iter_recurse(&iter, &sub);
        dbus.dbus_message_iter_get_basic(&sub, &result);
        return result;
        // return 0;
    }

    fn scanOn() void {
        msgQuery = dbus.dbus_message_new_method_call(bluez, path, adapter, "StartDiscovery");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        dbus.dbus_message_unref(msgQuery);
    }

    fn scanOff() void {
        msgQuery = dbus.dbus_message_new_method_call(bluez, path, adapter, "StopDiscovery");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        dbus.dbus_message_unref(msgQuery);
    }

    fn findDeviceByMac(name: ?[*c]const u8) [*c]const u8 {
        var args: dbus.DBusMessageIter = undefined;
        var sigvalue: ?[*c]const u8 = "";
        dbus.dbus_bus_add_match(connection, "type='signal',interface='org.freedesktop.DBus.ObjectManager'", dbus_error); // see signals from the given interface
        dbus.dbus_connection_flush(connection);
        check(dbus_error);
        while (true) {
            _ = dbus.dbus_connection_read_write(connection, 0);
            msgReply = dbus.dbus_connection_pop_message(connection);
            if (msgReply == null) {
                std.time.sleep(10000);
                continue;
            }
            if (dbus.dbus_message_is_signal(msgReply, "org.freedesktop.DBus.ObjectManager", "InterfacesAdded") != 0) {
                if (dbus.dbus_message_iter_init(msgReply, &args) == 0) {
                    std.debug.print("Message has no arguments!\n", .{});
                } else if (dbus.DBUS_TYPE_OBJECT_PATH != dbus.dbus_message_iter_get_arg_type(&args)) {
                    std.debug.print("Argument is not object! type = {x}\n", .{dbus.dbus_message_iter_get_arg_type(&args)});
                } else {
                    dbus.dbus_message_iter_get_basic(&args, &sigvalue);
                    std.debug.print("Found Device {s}\n", .{sigvalue.?});
                    if (std.mem.eql(u8, std.mem.span(sigvalue.?), std.mem.span(name.?))) {
                        std.debug.print("!!!  !!!  Found Danger Doughnut  !!! !!! {s}\n", .{sigvalue.?});
                        return sigvalue.?;
                    }
                    // msgReply = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
                }
            }
        }
        return "";
    }

    fn connect(device_path: [*c]const u8) bool {
        msgQuery = dbus.dbus_message_new_method_call(bluez, device_path, device, "Connect");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 10000, dbus_error);
        dbus.dbus_message_unref(msgQuery);
        if (dbus.dbus_error_is_set(dbus_error) != 0) {
            std.debug.print("Connection error", .{});
            return false;
        }
        std.time.sleep(std.time.ns_per_s * 6); // TODO: check that we are actually connected
        connected = true;
        return true;
    }

    fn disconnect(device_path: [*c]const u8) void {
        if (dbus.dbus_connection_get_is_connected(connection) == 0) {
            return;
        }
        msgQuery = dbus.dbus_message_new_method_call(bluez, device_path, device, "Disconnect");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        dbus.dbus_message_unref(msgQuery);
        if (dbus.dbus_error_is_set(dbus_error) != 0) {
            std.debug.print("Error disconnecting", .{});
        }
    }

    fn readNextBLEPacket(self: *Self) void {
        var args: dbus.DBusMessageIter = undefined;
        var sub1: dbus.DBusMessageIter = undefined;
        var sub2: dbus.DBusMessageIter = undefined;
        var sub3: dbus.DBusMessageIter = undefined;
        const offset: ?[*c]const u8 = "offset";
        const zero: u16 = 0;
        const sig: [*c]const u8 = "{sv}";
        // const one: u16 = 1;
        // const tes: [*c]const u8 = "a{sv}";
        msgQuery = dbus.dbus_message_new_method_call(
            bluez,
            "/org/bluez/hci0/dev_F4_12_FA_F0_91_2A/service000e/char000f",
            "org.bluez.GattCharacteristic1",
            "ReadValue",
        ); // TODO: add string concatenation to remove hardcoded path

        // std.debug.print("1\n", .{});
        dbus.dbus_message_iter_init_append(msgQuery, &args);
        // dbus.dbus_message_iter_init_closed(&sub1);
        // dbus.dbus_message_iter_init_closed(&sub2);
        // dbus.dbus_message_iter_init_closed(&sub3);
        // std.debug.print("1\n", .{});

        if (dbus.dbus_message_iter_open_container(
            &args,
            dbus.DBUS_TYPE_ARRAY,
            sig,
            &sub1,
        ) == 0) {
            std.debug.print("Out of Memory\n", .{});
        }

        if (dbus.dbus_message_iter_open_container(
            &sub1,
            dbus.DBUS_TYPE_DICT_ENTRY,
            null,
            &sub2,
        ) == 0) {
            std.debug.print("Out of Memory\n", .{});
        }
        // std.debug.print("3 args={s}, {s}\n", .{ dbus.dbus_message_iter_get_signature(&args), dbus.dbus_message_iter_get_signature(&sub1) }) == 0) {
        // std.debug.print("Out of Memory\n");}

        if (dbus.dbus_message_iter_append_basic(
            &sub2,
            dbus.DBUS_TYPE_STRING,
            &offset,
        ) == 0) {
            std.debug.print("Out of Memory\n", .{});
        }
        // // std.debug.print("4 args={s}, {s}, {s}, {s}\n", .{ dbus.dbus_message_iter_get_signature(&args), dbus.dbus_message_iter_get_signature(&sub1), dbus.dbus_message_iter_get_signature(&sub2), dbus.dbus_message_iter_get_signature(&sub3) }) == 0) {
        // std.debug.print("Out of Memory\n");}

        if (dbus.dbus_message_iter_open_container(
            &sub2,
            dbus.DBUS_TYPE_VARIANT,
            dbus.DBUS_TYPE_UINT16_AS_STRING,
            &sub3,
        ) == 0) {
            std.debug.print("Out of Memory\n", .{});
        }
        // // std.debug.print("5 args={s}, {s}, {s}, {s}\n", .{ dbus.dbus_message_iter_get_signature(&args), dbus.dbus_message_iter_get_signature(&sub1), dbus.dbus_message_iter_get_signature(&sub2), dbus.dbus_message_iter_get_signature(&sub3) }) == 0) {
        // std.debug.print("Out of Memory\n");}

        if (dbus.dbus_message_iter_append_basic(
            &sub3,
            dbus.DBUS_TYPE_UINT16,
            &zero,
        ) == 0) {
            std.debug.print("Out of Memory\n", .{});
        }
        // std.debug.print("signature args={s}\n", .{dbus.dbus_message_iter_get_signature(&args)});

        _ = dbus.dbus_message_iter_close_container(&sub2, &sub3);
        _ = dbus.dbus_message_iter_close_container(&sub1, &sub2);
        _ = dbus.dbus_message_iter_close_container(&args, &sub1);

        // _ = dbus.dbus_message_append_args(msgQuery, dbus.DBUS_TYPE_ARRAY, dbus.DBUS_DICT_ENTRY_BEGIN_CHAR, dbus.DBUS_TYPE_STRING, dbus.DBUS_TYPE_VARIANT, dbus.DBUS_DICT_ENTRY_END_CHAR, &one, &offset, dbus.DBUS_TYPE_UINT16, &zero);
        msgReply = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        std.debug.print("sent\n", .{});
        dbus.dbus_message_unref(msgQuery);
        check(dbus_error);
        dbus_error = @ptrCast(&buf_error);
        // _ = dbus.dbus_message_get_args(msgReply, dbus_error, dbus.DBUS_TYPE_ARRAY, &self.rx_buf, dbus.DBUS_TYPE_INVALID);
        _ = self;

        // self.readPointer = 0;
        // self.readAvailable = n_recv;
        // std.debug.print(
        //     "received {d} byte(s) : {s}",
        //     .{ n_recv, self.readBuffer[0..n_recv] },
        // );
    }

    pub fn init() Self {
        const self: Self = .{
            .tx_buf = undefined,
            .tx_pointer = 0,
            .rx_buf = undefined,
            .rx_pointer = 0,
            .rx_available = 0,
        };
        dbus.dbus_error_init(dbus_error);
        connection = dbus.dbus_bus_get(dbus.DBUS_BUS_SYSTEM, dbus_error);
        check(dbus_error);
        if (getBluetoothStatus() != 0) {
            std.debug.print("bluetooth is on\n", .{});
        } else {
            std.debug.print("bluetooth is off\n", .{});
        }
        // disconnect("/org/bluez/hci0/dev_F4_12_FA_F0_91_2A");
        scanOn();
        dev_path = findDeviceByMac("/org/bluez/hci0/dev_F4_12_FA_F0_91_2A");
        scanOff();
        _ = connect(dev_path);
        return self;
    }

    pub fn update(self: *Self) void {
        if (self.tx_pointer > 0) {
            // _ = // send;
            self.tx_pointer = 0;
        }

        std.debug.print("ble\n", .{});

        self.readNextBLEPacket();

        // msgQuery = dbus.dbus_message_new_method_call(bluez, "/org/freedesktop/UPower", "org.freedesktop.UPower", "GetCriticalAction");

        // msgReply = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        // // dbus.check_and_abort(dbus_error);

        // dbus.dbus_message_unref(msgQuery);

        // _ = dbus.dbus_message_get_args(msgReply, dbus_error, dbus.DBUS_TYPE_STRING, &versionValue, dbus.DBUS_TYPE_INVALID);

        // std.debug.print("The critical action is: {s}\n", .{versionValue});

        // dbus.dbus_message_unref(msgReply);
    }

    pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
        @memcpy(self.tx_buf[self.tx_pointer .. self.tx_pointer + @sizeOf(tm.Header)], @as([*]u8, @constCast(@ptrCast(&header))));
        self.tx_pointer += @sizeOf(tm.Header);
        @memcpy(self.tx_buf[self.tx_pointer .. self.tx_pointer + data.size], @as([*]u8, @ptrCast(data.pointer)));
        self.tx_pointer += data.size;
        return true;
    }

    pub fn read(self: *Self, buffer: ?[*]u8, size: usize) !void {
        if (buffer) |buf| {
            @memcpy(
                buf[0..size],
                self.rx_buf[self.rx_pointer .. self.rx_pointer + size],
            );
        }
        self.rx_pointer += size;
    }

    pub fn getNextHeader(self: *Self) ?tm.Header {
        if (self.rx_available - self.rx_pointer < @sizeOf(tm.Header))
            return null;
        var header: tm.Header = undefined;
        self.read(@as([*]u8, @ptrCast(&header)), @sizeOf(@TypeOf(header))) catch unreachable;
        return header;
    }

    pub fn end(self: Self) void {
        _ = self;
        disconnect(dev_path);
        dbus.dbus_message_unref(msgQuery);
        dbus.dbus_message_unref(msgReply);
    }
};
