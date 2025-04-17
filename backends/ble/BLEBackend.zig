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

    readBuffer: [MAX_BLE_PACKET_SIZE]u8,
    readPointer: usize = 0,
    writeBuffer: [MAX_BLE_PACKET_SIZE]u8,
    readAvailable: usize = 0,
    writePointer: usize = 0,

    var tx_buf: [MAX_BLE_PACKET_SIZE]u8 = undefined;
    var tx_buf_len: u16 = 0;
    var rx_buf: [MAX_BLE_PACKET_SIZE]u8 = undefined;
    var rx_buf_len: u16 = 0;
    var rx_mutex: std.Thread.Mutex = undefined;

    var thread: std.Thread = undefined;
    var connected: bool = false;
    var dev_path: [*c]const u8 = "/org/bluez/hci0/dev_F4_12_FA_F0_91_2A";
    var buf_error: DBusError = undefined;
    var dbus_error: *dbus.DBusError = @ptrCast(&buf_error);
    var connection: ?*dbus.DBusConnection = null;
    var msgQuery: ?*dbus.DBusMessage = null;
    var msgReply: ?*dbus.DBusMessage = null;
    var msgWrite: ?*dbus.DBusMessage = null;

    fn check(check_error: ?*dbus.DBusError) void {
        if (dbus.dbus_error_is_set(check_error) != 0) {
            std.debug.print("DBus Error {s}", .{buf_error.message});
            dbus.dbus_error_free(check_error);
        }
    }

    fn getBluetoothStatus() u8 {
        msgQuery = dbus.dbus_message_new_method_call(bluez, path, "org.freedesktop.DBus.Properties", "Get");
        const powered: [*c]const u8 = "Powered";
        _ = dbus.dbus_message_append_args(msgQuery, dbus.DBUS_TYPE_STRING, &adapter, dbus.DBUS_TYPE_STRING, &powered, dbus.DBUS_TYPE_INVALID);
        msgReply = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        check(dbus_error);
        var iter: dbus.DBusMessageIter = undefined;
        var sub: dbus.DBusMessageIter = undefined;
        var result: u8 = 0;
        _ = dbus.dbus_message_iter_init(msgReply, &iter);
        dbus.dbus_message_iter_recurse(&iter, &sub);
        dbus.dbus_message_iter_get_basic(&sub, &result);
        return result;
    }

    fn scanOn() void {
        msgQuery = dbus.dbus_message_new_method_call(bluez, path, adapter, "StartDiscovery");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        check(dbus_error);
        dbus.dbus_message_unref(msgQuery);
    }

    fn scanOff() void {
        msgQuery = dbus.dbus_message_new_method_call(bluez, path, adapter, "StopDiscovery");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        check(dbus_error);
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
                }
            }
        }
        return "";
    }

    fn isConnected() bool {
        var message: ?*dbus.DBusMessage = null;
        var reply: ?*dbus.DBusMessage = null;
        message = dbus.dbus_message_new_method_call(bluez, dev_path, "org.freedesktop.DBus.Properties", "Get");
        const variable: [*c]const u8 = "Connected";
        _ = dbus.dbus_message_append_args(message, dbus.DBUS_TYPE_STRING, &device, dbus.DBUS_TYPE_STRING, &variable, dbus.DBUS_TYPE_INVALID);
        reply = dbus.dbus_connection_send_with_reply_and_block(connection, message, 1000, dbus_error);
        dbus.dbus_message_unref(message);
        if (dbus.dbus_error_is_set(dbus_error) != 0) {
            dbus.dbus_error_free(dbus_error);
            return false;
        }
        var iter: dbus.DBusMessageIter = undefined;
        var sub: dbus.DBusMessageIter = undefined;
        var result: u8 = 0;
        _ = dbus.dbus_message_iter_init(reply, &iter);
        dbus.dbus_message_iter_recurse(&iter, &sub);
        dbus.dbus_message_iter_get_basic(&sub, &result);
        dbus.dbus_message_unref(reply);
        return result != 0;
    }

    fn connect(device_path: [*c]const u8) bool {
        msgQuery = dbus.dbus_message_new_method_call(bluez, device_path, device, "Connect");
        msgReply = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, -1, dbus_error);
        dbus.dbus_message_unref(msgQuery);
        if (dbus.dbus_error_is_set(dbus_error) != 0) {
            std.debug.print("Connection error\n", .{});
            dbus.dbus_error_free(dbus_error);
            return false;
        }
        return true;
        // // const result: [*c]const u8 = dbus.dbus_message_get_signature(msgReply);
        // // std.debug.print("sig = {s}", .{result});
    }

    fn disconnect(device_path: [*c]const u8) void {
        if (dbus.dbus_connection_get_is_connected(connection) == 0) {
            return;
        }
        msgQuery = dbus.dbus_message_new_method_call(bluez, device_path, device, "Disconnect");
        _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
        check(dbus_error);
        dbus.dbus_message_unref(msgQuery);
        if (dbus.dbus_error_is_set(dbus_error) != 0) {
            std.debug.print("Error disconnecting", .{});
        }
    }

    fn subscribe() void {
        for (0..50) |_| { // notifications usually take 2 seconds after connection to be available
            msgQuery = dbus.dbus_message_new_method_call(
                bluez,
                "/org/bluez/hci0/dev_F4_12_FA_F0_91_2A/service000e/char000f",
                "org.bluez.GattCharacteristic1",
                "StartNotify",
            ); // TODO: remove hardcoded path
            _ = dbus.dbus_connection_send_with_reply_and_block(connection, msgQuery, 1000, dbus_error);
            dbus.dbus_message_unref(msgQuery);
            if (dbus.dbus_error_is_set(dbus_error) == 0) return;
            dbus.dbus_error_free(dbus_error);
            std.time.sleep(std.time.ns_per_ms * 100);
        }
        std.debug.print("Failed subscribe! Moving on without notifications\n", .{});
    }

    fn notifyWorker() void {
        // dbus.dbus_bus_remove_match(connection, "type='signal',interface='org.freedesktop.DBus.ObjectManager'", dbus_error);
        // dbus.dbus_connection_flush(connection);
        // check(dbus_error);
        dbus.dbus_bus_add_match(connection, "type='signal',path='/org/bluez/hci0/dev_F4_12_FA_F0_91_2A/service000e/char000f',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'", dbus_error); // see signals from the given interface
        dbus.dbus_connection_flush(connection);
        check(dbus_error);
        var noDataCounter: u32 = 0;
        while (true) {
            _ = dbus.dbus_connection_read_write(connection, 0);
            msgReply = dbus.dbus_connection_pop_message(connection);
            if (msgReply == null) {
                std.time.sleep(std.time.ns_per_ms * 5);
                noDataCounter += 1;
                if (noDataCounter > 200) { // 1 second without data
                    if (!isConnected()) {
                        _ = init();
                        return;
                    }
                }
                continue;
            }
            noDataCounter = 0;
            var iter: dbus.DBusMessageIter = undefined;
            var sub1: dbus.DBusMessageIter = undefined;
            var sub2: dbus.DBusMessageIter = undefined;
            var sub3: dbus.DBusMessageIter = undefined;
            var sub4: dbus.DBusMessageIter = undefined;
            _ = dbus.dbus_message_iter_init(msgReply, &iter);
            if (dbus.dbus_message_iter_get_arg_type(&iter) != dbus.DBUS_TYPE_STRING) continue; // check string for disconnect
            _ = dbus.dbus_message_iter_next(&iter); // skip interface string
            if (dbus.dbus_message_iter_get_arg_type(&iter) != dbus.DBUS_TYPE_ARRAY) continue;
            dbus.dbus_message_iter_recurse(&iter, &sub1); // step into array
            if (dbus.dbus_message_iter_get_arg_type(&sub1) != dbus.DBUS_TYPE_DICT_ENTRY) continue;
            dbus.dbus_message_iter_recurse(&sub1, &sub2); // step into dict
            if (dbus.dbus_message_iter_get_arg_type(&sub2) != dbus.DBUS_TYPE_STRING) continue;
            _ = dbus.dbus_message_iter_next(&sub2); // skip name string
            if (dbus.dbus_message_iter_get_arg_type(&sub2) != dbus.DBUS_TYPE_VARIANT) continue;
            dbus.dbus_message_iter_recurse(&sub2, &sub3); // step into variant
            if (dbus.dbus_message_iter_get_arg_type(&sub3) != dbus.DBUS_TYPE_ARRAY) continue;
            var len: c_int = dbus.dbus_message_iter_get_element_count(&sub3);
            var result: ?[*c]u8 = undefined;
            dbus.dbus_message_iter_recurse(&sub3, &sub4); // step into array
            dbus.dbus_message_iter_get_fixed_array(&sub4, &result, &len);
            std.Thread.Mutex.lock(&rx_mutex);
            rx_buf_len = @truncate(@as(u32, @intCast(@as(i32, len)))); // what the fuck
            for (0..rx_buf_len) |i| {
                rx_buf[i] = result.?[i];
            }
            std.Thread.Mutex.unlock(&rx_mutex);
        }
    }

    fn makeTxMessage() ?*dbus.DBusMessage {
        var args: dbus.DBusMessageIter = undefined;
        var data: dbus.DBusMessageIter = undefined;
        var sub1: dbus.DBusMessageIter = undefined;
        var sub2: dbus.DBusMessageIter = undefined;
        var sub3: dbus.DBusMessageIter = undefined;
        var writeMessage: ?*dbus.DBusMessage = null;
        const offset: ?[*c]const u8 = "offset";
        const zero: u16 = 0;
        const sig: [*c]const u8 = "{sv}";
        writeMessage = dbus.dbus_message_new_method_call(
            bluez,
            "/org/bluez/hci0/dev_F4_12_FA_F0_91_2A/service000e/char000f",
            "org.bluez.GattCharacteristic1",
            "WriteValue",
        ); // TODO: add string concatenation to remove hardcoded path

        dbus.dbus_message_iter_init_append(writeMessage, &args);

        var send_data: ?[*c]u8 = @ptrCast(&tx_buf);

        std.debug.print("sent {d} byte(s) : ", .{tx_buf_len});

        for (0..tx_buf_len) |i| {
            std.debug.print("{x:0>2} ", .{tx_buf[i]});
        }
        std.debug.print("\n", .{});

        // why does DBus api have to be this convoluted
        _ = dbus.dbus_message_iter_open_container(&args, dbus.DBUS_TYPE_ARRAY, dbus.DBUS_TYPE_BYTE_AS_STRING, &data);
        _ = dbus.dbus_message_iter_append_fixed_array(&data, dbus.DBUS_TYPE_BYTE, &send_data, tx_buf_len);
        _ = dbus.dbus_message_iter_close_container(&args, &data);
        _ = dbus.dbus_message_iter_open_container(&args, dbus.DBUS_TYPE_ARRAY, sig, &sub1);
        _ = dbus.dbus_message_iter_open_container(&sub1, dbus.DBUS_TYPE_DICT_ENTRY, null, &sub2);
        _ = dbus.dbus_message_iter_append_basic(&sub2, dbus.DBUS_TYPE_STRING, &offset);
        _ = dbus.dbus_message_iter_open_container(&sub2, dbus.DBUS_TYPE_VARIANT, dbus.DBUS_TYPE_UINT16_AS_STRING, &sub3);
        _ = dbus.dbus_message_iter_append_basic(&sub3, dbus.DBUS_TYPE_UINT16, &zero);
        _ = dbus.dbus_message_iter_close_container(&sub2, &sub3);
        _ = dbus.dbus_message_iter_close_container(&sub1, &sub2);
        _ = dbus.dbus_message_iter_close_container(&args, &sub1);

        return writeMessage;
    }

    fn readNextBLEPacket(self: *Self) void {
        if (rx_buf_len == 0) return;
        std.Thread.Mutex.lock(&rx_mutex);
        for (0..rx_buf_len) |i| {
            self.readBuffer[i] = rx_buf[i];
        }
        self.readAvailable = rx_buf_len;
        rx_buf_len = 0;
        std.Thread.Mutex.unlock(&rx_mutex);

        self.readPointer = 0;
        std.debug.print(
            "received {d} byte(s) : ",
            .{self.readAvailable},
        );
        for (0..self.readAvailable) |i| {
            std.debug.print("{x:0>2} ", .{self.readBuffer[i]});
        }
        std.debug.print("\n", .{});
    }

    pub fn init() Self {
        const self: Self = .{
            .writeBuffer = undefined,
            .writePointer = 0,
            .readBuffer = undefined,
            .readPointer = 0,
            .readAvailable = 0,
        };
        dbus.dbus_error_init(dbus_error);
        connection = dbus.dbus_bus_get(dbus.DBUS_BUS_SYSTEM, dbus_error);
        check(dbus_error);
        if (getBluetoothStatus() != 0) {
            std.debug.print("bluetooth is on\n", .{});
        } else {
            std.debug.print("bluetooth is off\n", .{});
        }
        while (!isConnected()) {
            if (!connect(dev_path)) {
                std.debug.print("Unknown device. Scanning...\n", .{});
                scanOn();
                dev_path = findDeviceByMac(dev_path);
                scanOff();
            }
        }
        std.debug.print("Device connected\n", .{});
        subscribe();
        thread = std.Thread.spawn(.{}, notifyWorker, .{}) catch undefined;
        return self;
    }

    pub fn update(self: *Self) void {
        if (self.writePointer > 0) {
            tx_buf_len = @intCast(self.writePointer);
            for (0..tx_buf_len) |i| {
                tx_buf[i] = self.writeBuffer[i];
            }
            msgWrite = makeTxMessage();
            _ = dbus.dbus_connection_send(connection, msgWrite, dbus.dbus_message_get_serial(msgWrite));
            self.writePointer = 0;
        }

        self.readNextBLEPacket();
    }

    pub fn writePacket(self: *Self, header: tm.Header, data: tm.Data) bool {
        @memcpy(self.writeBuffer[self.writePointer .. self.writePointer + @sizeOf(tm.Header)], @as([*]u8, @constCast(@ptrCast(&header))));
        self.writePointer += @sizeOf(tm.Header);
        @memcpy(self.writeBuffer[self.writePointer .. self.writePointer + data.size], @as([*]u8, @ptrCast(data.pointer)));
        self.writePointer += data.size;
        return true;
    }

    pub fn read(self: *Self, buffer: ?[*]u8, size: usize) !void {
        if (buffer) |buf| {
            @memcpy(
                buf[0..size],
                self.readBuffer[self.readPointer .. self.readPointer + size],
            );
        }
        self.readPointer += size;
    }

    pub fn getNextHeader(self: *Self) ?tm.Header {
        if (self.readAvailable - self.readPointer < @sizeOf(tm.Header))
            return null;
        var header: tm.Header = undefined;
        self.read(@as([*]u8, @ptrCast(&header)), @sizeOf(@TypeOf(header))) catch unreachable;
        return header;
    }

    pub fn end(self: Self) void {
        _ = self;
        disconnect(dev_path);
    }
};
