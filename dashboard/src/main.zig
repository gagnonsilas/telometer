const std = @import("std");
pub const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});

const mat = @import("mat.zig");
const math = std.math;

const tm = @import("telometer");
const Backend = @import("backend.zig").Backend;

const telemetry = @cImport({
    @cInclude("Packets.h");
});

const dash = @import("dashboard.zig");

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

var backend: Backend = undefined;
var packets: telemetry.TelemetryPackets = undefined;
var instance: tm.TelometerInstance(Backend, telemetry.TelemetryPackets, telemetry.TelemetryTypes) = undefined;

var plot: dash.Plot = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    packets = telemetry.initTelemetryPackets();
    backend = Backend.init();
    instance = try tm.TelometerInstance(Backend, telemetry.TelemetryPackets, telemetry.TelemetryTypes).init(
        std.heap.c_allocator,
        backend,
        &packets,
    );

    var dashboard = dash.Dashboard.init() catch |e| return e;
    defer dashboard.end();

    dash.theme_fluent();

    plot = dash.Plot.init(allocator);
    defer plot.cleanup();

    const clear_color = c.ImVec4{ .x = 0.45, .y = 0.55, .z = 0.60, .w = 1.00 };

    var running: bool = true;
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

        if (c.igBegin("Yippee!", null, 0)) {
            if (c.igButton("Hi Silas!", .{})) {
                running = false;
            }
        }

        c.igEnd();

        instance.update();
        dash.list(instance);
        plot.update();

        dashboard.render(clear_color);
    }
}
