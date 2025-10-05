const std = @import("std");
pub const fsae = @import("fsae.zig");
pub const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});
//:)
const mat = @import("mat.zig");
const math = std.math;

const tm = @import("telometer");
const Backend = @import("backend.zig").Backend;

const telemetry = @cImport({
    @cInclude("Packets.h");
});

const log = tm.log;

const dash = @import("dashboard.zig");

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

const ids = [_]u32{
    0x0,
    0x300,
    0x707,
    0x301,
    (0x1918FF71 | 1 << 31),
    0x708,
    0x709,
    (0x19107171 | 1 << 31),
    (0x1928FF71 | 1 << 31),
    0x704,
    0x401,
    0x002,
    ((0b111 << 8) | 0xC),
    ((0b111 << 8) | 0xD),
    (0x191AFF71 | 1 << 31),
};
var backend: Backend = undefined;
const TelometerInstance = tm.TelometerInstance(Backend, fsae.TelometerTypes, fsae.TelometerTypes.IDs);
// const TelometerInstance = tm.TelometerInstance(Backend, fsae.TelometerTypes, fsae.TelometerTypes.IDs); :)
var instance: TelometerInstance = undefined;

var plot: dash.Plot = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    // packets = telemetry.initTelemetryPackets();
    backend = Backend.init();

    // const logger = try log.Log(telemetry.TelemetryTypes).init(
    //     TelometerInstance.log_header,
    // );
    // _ = logger;
    //
    instance = try TelometerInstance.init(
        std.heap.c_allocator,
        backend,
    );
    defer instance.close();

    // var log_interface = dash.LogInterface(TelometerInstance.Logger).init(&instance.log);

    var dashboard = dash.Dashboard.init() catch |e| return e;
    defer dashboard.end();

    dash.theme_moonlight();
    // dash.source_engine_theme();
    // dash.theme_fluent();

    plot = dash.Plot.init(allocator);
    defer plot.cleanup();

    const clear_color = c.ImVec4{ .x = 0.45, .y = 0.55, .z = 0.60, .w = 1.00 };

    var running: bool = true;

    // out_path = null;

    while (running) {
        var event: c.SDL_Event = undefined;

        while (0 != c.SDL_PollEvent(&event)) {
            if (c.ImGui_ImplSDL2_ProcessEvent(&event)) continue;
            switch (event.type) {
                (c.SDL_QUIT) => {
                    running = false;
                },
                else => {},
            }
        }

        dashboard.init_frame();
        // if (c.igBeginPopupContextItem("test", c.ImGuiPopupFlags_MouseButtonRight)) {
        //     std.debug.print("WOOOO!3 ", .{});
        //     if (c.igMenuItem_Bool("test", null, true, true)) {
        //         std.debug.print("WOOOO!4 ", .{});
        //     }
        //     c.igEndPopup();
        // }

        if (c.igBegin("Yippee!", null, 0)) {
            if (c.igButton("Hi Silas!", .{})) {
                running = false;
            }
            // if (c.igBeginPopupContextItem("test", c.ImGuiPopupFlags_MouseButtonRight)) {
            //     std.debug.print("WOOOO!3 ", .{});
            // }
            // // _ = c.igInputText("File:", out_path, 0, 0, 0, 0);A
            // if (c.igButton("Hi Silas! 2", .{})) {
            //     // running = false;
            //     c.igOpenPopup_Str("hi??", c.ImGuiPopupFlags_None);
            // }
            // if (c.igBeginPopup("hi??", c.ImGuiPopupFlags_None)) {
            //     // std.debug.print("WOOOO!2 ", .{});
            //     if (c.igMenuItem_Bool("test", null, true, true)) {
            //         std.debug.print("WOOOO!4 \n", .{});
            //     }
            //     c.igEndPopup();
            // }
        }
        c.igEnd();

        instance.update();
        // log_interface.update();
        dash.list(TelometerInstance, &instance);
        plot.update();

        { // can sender
            if (c.igBegin("CAN Write", null, 0)) {}

            const state = struct {
                pub var selected: ?usize = null;
                pub var data: fsae.TelometerTypes = std.mem.zeroes(fsae.TelometerTypes);
            };

            const Fields = std.meta.fields(fsae.TelometerTypes);
            const currently_selected: []const u8 = blk: {
                inline for (Fields, 0..) |field, idx| {
                    if (state.selected == idx) {
                        break :blk field.name;
                    }
                }

                break :blk "None";
            };

            // fsae.TelometerTypes
            if (c.igBeginCombo("Type", currently_selected.ptr, 0)) {
                inline for (Fields, 0..) |field, idx| {
                    if (c.igSelectable_Bool(
                        field.name,
                        false,
                        0,
                        .{ .x = 0, .y = 0 },
                    )) {
                        state.selected = idx;
                    }
                }

                c.igEndCombo();
            }

            if (state.selected) |selected| {
                inline for (Fields, 0..) |field, idx| {
                    if (idx == selected) {
                        const full_pack = &@field(state.data, field.name);
                        inline for (std.meta.fields(field.type)) |field2| {
                            const data = &@field(full_pack.*, field2.name);
                            var fake_data: tm.Data = undefined;
                            dash.displayValue(
                                field2.type,
                                field2.name,
                                "",
                                data,
                                &fake_data,
                            );
                        }
                        if (c.igButton("Send! :3", .{ .x = 0, .y = 0 })) {
                            var data = std.mem.zeroes([8]u8);
                            std.mem.copyForwards(u8, &data, std.mem.asBytes(full_pack));
                            // std.debug.print("{}\n", .{backend.canSocket});
                            // var tes: [32]u8 = undefined;
                            // _ = std.posix.system.recvfrom(backend.canSocket, &tes, 0, null, null);
                            const be = @import("backend.zig");
                            // const bytes = std.mem.toBytes(be.CanFrame{
                            //     .id = field.type.id,
                            //     .len = @sizeOf(field.type),
                            //     .bytes = std.mem.zeroes([3]u8),
                            //     .data = data,
                            // });

                            const msg = std.fmt.allocPrint(gpa, "{}@{s}", .{ field.type.id, data });
                            std.process.execv(gpa, &.{ "cansend", be.getInterfaceName(), msg }) catch |e| std.debug.print("{}\n", .{e});

                            // _ = std.posix.system.write(backend.canSocket, (&bytes).ptr, bytes.len);

                        }
                    }
                }
            }

            c.igEnd();
        }

        dashboard.render(clear_color);
    }
}
