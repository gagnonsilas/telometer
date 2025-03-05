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

const dashboard = @import("dashboard.zig");

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

var backend: Backend = undefined;
var packets: telemetry.TelemetryPackets = undefined;
var instance: tm.TelometerInstance(Backend, telemetry.TelemetryPackets) = undefined;

var test_plot: dashboard.Plot = undefined;
var plot_arm: dashboard.Plot3d = undefined;
var vel_plot: dashboard.Plot3d = undefined;

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
    instance = try tm.TelometerInstance(Backend, telemetry.TelemetryPackets).init(
        std.heap.c_allocator,
        backend,
        &packets,
    );
    // @as(*bool, @ptrCast(@alignCast(packets.test6.pointer))).* = false;

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        return error.GLFWInitFailed;
    }
    defer c.SDL_Quit();

    if (0 != c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3)) {
        return error.FailedToSetGLVersion;
    }
    if (0 != c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 3)) {
        return error.FailedToSetGLVersion;
    }
    if (0 != c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE)) {
        return error.FailedToSetGLVersion;
    }

    const window = c.SDL_CreateWindow(
        "Telometer Dashboard",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        900,
        900,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_ALLOW_HIGHDPI,
    ) orelse return error.GLFWCreateWindowFailed;

    defer c.SDL_DestroyWindow(window);

    const gl_context = c.SDL_GL_CreateContext(window);
    if (0 != c.SDL_GL_MakeCurrent(window, gl_context))
        return error.GLMakeCurrentFailed;
    defer c.SDL_GL_DeleteContext(gl_context);

    if (0 != c.SDL_GL_SetSwapInterval(1))
        return error.GLMakeCurrentFailed;

    if (c.gladLoadGLLoader(c.SDL_GL_GetProcAddress) == 0) {
        return error.FailedToLoadOpenGL;
    }

    const ctx = c.igCreateContext(null);
    defer c.igDestroyContext(ctx);

    const io = c.igGetIO();
    io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;
    io.*.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;

    // c.igStyleColorsDark(null);
    dashboard.theme_fluent();

    _ = c.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    defer c.ImGui_ImplSDL2_Shutdown();

    _ = c.ImGui_ImplOpenGL3_Init("#version 410");
    defer c.ImGui_ImplOpenGL3_Shutdown();

    const context = c.ImPlot_CreateContext() orelse @panic("Kill yourself");
    defer c.ImPlot_DestroyContext(context);

    // std.debug.print("drag drop? {}\n", .{c.igIsDragDropActive()});
    // c.igDragDrop

    test_plot = dashboard.Plot.init(allocator);
    plot_arm = dashboard.Plot3d.init(300, 10, 30);
    vel_plot = dashboard.Plot3d.init(20, 1, 10);

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

        c.ImGui_ImplOpenGL3_NewFrame();
        c.ImGui_ImplSDL2_NewFrame();
        c.igNewFrame();

        _ = c.igDockSpaceOverViewport(0, null, 0, c.ImGuiWindowClass_ImGuiWindowClass());

        if (c.igBegin("Yippee!", null, 0)) {
            if (c.igButton("Hi Silas!", .{})) {
                running = false;
            }
        }
        c.igEnd();

        update();

        c.igRender();
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.SDL_GetWindowSize(window, &width, &height);
        c.glViewport(0, 0, width, height);
        c.glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());

        c.SDL_GL_SwapWindow(window);
    }
}

var reflow_times = [_]f64{ 0, 3, 7, 11, 16, 20, 25, 30, 35, 39, 45, 54, 60, 66, 72, 79, 85, 93, 100, 107, 114, 123, 132, 141, 150, 158, 168, 175, 181, 187, 192, 202, 212, 207, 218, 225, 230, 237, 244, 250, 255, 259, 263, 266, 269, 272, 277, 283, 289, 295, 298, 301, 303 };
const reflow_temps = [_]f64{ 25, 35, 48, 57, 67, 76, 85, 92, 97, 101, 107, 111, 115, 118, 120, 123, 126, 129, 132, 135, 138, 142, 147, 153, 160, 168, 180, 188, 196, 204, 211, 223, 233, 228, 240, 245, 248, 248, 247, 242, 235, 225, 216, 207, 198, 188, 172, 149, 123, 101, 92, 83, 78 };

// const reflow_times: []f64 = []f64{ 0, 30, 120, 050, 210, 240 };
// const reflow_temps: []f64 = []f64{ 77, 200, 300, 361, 455, 183 };

var plot_reflow: bool = false;
var reflow_start_time: f64 = 0;

fn reflow() void {
    if (c.igBegin("Reflow", null, 0)) {
        _ = c.igCheckbox("Show Reflow Curve", &plot_reflow);
        if (c.igButton("Start Reflow", c.ImVec2{ .x = 0, .y = 0 })) {
            const new_start_time = @as(f64, @floatFromInt(std.time.microTimestamp())) / 1e6;
            for (reflow_times, 0..) |time, i| {
                reflow_times[i] = time - reflow_start_time + new_start_time;
            }
            reflow_start_time = new_start_time;
        }
    }
    c.igEnd();
}

fn plotArm() void {
    if (c.igBegin("Arm", null, 0)) {}
    plot_arm.updateBegin();
    var transforms: []mat.Mat(4, 4, f32) = undefined;
    transforms.ptr = @ptrCast(@alignCast(packets.transforms.pointer));
    transforms.len = 4;

    // for (0..4) |i| {}
    for (transforms) |transform| {
        // std.debug.print("transform : {}\n ", .{transform.transpose()});
        plot_arm.drawTransformMatrix(transform.transpose(), 20);
    }

    var traj: []mat.Vec3f = undefined;
    traj.ptr = @ptrCast(&@as(*telemetry.trajectory, @ptrCast(@alignCast(packets.traj.pointer))).*.positions);
    traj.len = @as(*telemetry.trajectory, @ptrCast(@alignCast(packets.traj.pointer))).*.len;

    for (traj, 0..) |point, i| {
        if (i < traj.len - 1) {
            plot_arm.drawLine(point, traj[i + 1], 0xFFFFFF00, 2);
        }
    }

    const jacobian: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.jacobianVel.pointer))).*);
    const vel: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.vel.pointer))).*);

    const transform: mat.Vec3f = .{ .d = transforms[3].transpose().col(3).d[0..3].* };

    // std.debug.print("transform? {}, {}\n", .{ transform, transforms[3] });

    plot_arm.drawLine(transform, transform.add(jacobian), 0xFFFF6900, 2);
    plot_arm.drawLine(transform, transform.add(vel), 0xFF00B1DF, 2);
    plot_arm.end();
    plot_arm.drawPoint(@as(*mat.Vec3f, @ptrCast(@alignCast(packets.targetPos.pointer))).*, 0xFF21FFFF, 2);
    c.igEnd();
}

fn vel3d() void {
    if (c.igBegin("Velocity", null, 0)) {
        vel_plot.updateBegin();

        const jacobian: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.jacobianVel.pointer))).*);
        const vel: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.vel.pointer))).*);
        vel_plot.drawLine(mat.Vec3f.new(.{ 0, 0, 0 }), jacobian, 0xFFFF6900, 3);
        vel_plot.drawLine(mat.Vec3f.new(.{ 0, 0, 0 }), vel, 0xFF00B1DF, 3);

        vel_plot.end();
    }
    c.igEnd();
}

fn rbe3001() void {
    const enabled: *bool = @ptrCast(@alignCast(packets.enabled.pointer));
    if (c.igIsKeyPressed_Bool(c.ImGuiKey_Space, false)) {
        enabled.* = false;
        packets.enabled.queued = 1;
    }

    if ((c.igIsKeyPressed_Bool(c.ImGuiKey_Backslash, false) or
        c.igIsKeyPressed_Bool(c.ImGuiKey_RightBracket, false) or
        c.igIsKeyPressed_Bool(c.ImGuiKey_LeftBracket, false)) and
        (c.igIsKeyPressed_Bool(c.ImGuiKey_Backslash, true) and
        c.igIsKeyPressed_Bool(c.ImGuiKey_LeftBracket, true) and
        c.igIsKeyPressed_Bool(c.ImGuiKey_RightBracket, true)))
    {
        enabled.* = !enabled.*;
        packets.enabled.queued = 1;
    }

    if (c.igBegin("Control everything", null, 0)) {
        const state: *u16 = @ptrCast(@alignCast(packets.state.pointer));
        if (c.igButton("GRAB", .{ .x = -1, .y = 100 })) {
            state.* = 3;
            packets.state.queued = 1;
        }
        if (c.igButton("DEPOSIT", .{ .x = -1, .y = 100 })) {
            state.* = 4;
            packets.state.queued = 1;
        }
        // c.igSameLine(0, 10);
        if (c.igButton("THROW", .{ .x = -1, .y = 100 })) {
            state.* = 5;
            packets.state.queued = 1;
        }
    }
    c.igEnd();
}

fn update() void {
    dashboard.list(instance);

    instance.update();

    rbe3001();
    reflow();

    test_plot.update();
    plotArm();
    vel3d();
}
