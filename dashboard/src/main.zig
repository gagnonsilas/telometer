const std = @import("std");
const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});

const tm = @import("telometer");
const UDPBackend = @import("udp.zig").UDPBackend();
const serialbackend = @import("serial.zig").SerialBackend();

const telemetry = @cImport({
    @cInclude("Example.h");
});

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

const PORT = 62895;

var backend = serialbackend.init();
var packets: telemetry.TelemetryPackets = undefined;
var instance: tm.TelometerInstance(serialbackend, telemetry.TelemetryPackets) = undefined;

pub fn dispValues() void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    _ = allocator; // autofix

    packets = telemetry.initTelemetryPackets();
    instance = try tm.TelometerInstance(serialbackend, telemetry.TelemetryPackets).init(
        std.heap.c_allocator,
        backend,
        &packets,
    );

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

    const window = c.SDL_CreateWindow("Telometer Dashboard", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 800, 600, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_ALLOW_HIGHDPI) orelse return error.GLFWCreateWindowFailed;
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

    // NOTE: you have to use the c allocator bc ImGui will try to free it...
    const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/DejavuSansMono-5m7L.ttf"));

    _ = c.ImFontAtlas_AddFontFromMemoryTTF(io.*.Fonts, @ptrCast(dejavu), @intCast(dejavu.len), 16, c.ImFontConfig_ImFontConfig(), null);

    c.igStyleColorsDark(null);

    _ = c.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    defer c.ImGui_ImplSDL2_Shutdown();

    _ = c.ImGui_ImplOpenGL3_Init("#version 410");
    defer c.ImGui_ImplOpenGL3_Shutdown();

    const clear_color = c.ImVec4{ .x = 0.45, .y = 0.55, .z = 0.60, .w = 1.00 };

    try backend.openSerial("/dev/ttyUSB0");

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

var updatesDecay: [telemetry.TelemetryPacketCount]f32 = std.mem.zeroes([telemetry.TelemetryPacketCount]f32);

fn list() void {
    if (c.igBegin("data", null, 0)) {}
    for (instance.packet_struct, 0..) |*packet, i| {
        updatesDecay[i] *= 0.99;

        if (packet.state == tm.PacketState.Received) {
            updatesDecay[i] = 1;
            packet.state = tm.PacketState.Sent;
        }
        c.igPushID_Int(@intCast(i));
        defer c.igPopID();

        if (c.igColorButton(
            "Updated?",
            c.ImVec4{
                .x = 0.1,
                .y = 0.9 * updatesDecay[i],
                .z = 0.05,
                .w = updatesDecay[i],
            },
            0,
            c.ImVec2{ .x = 20, .y = 20 },
        )) {
            packet.state = tm.PacketState.Received;
        }
        c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);

        switch (packet.type) {
            telemetry.uint32_tTelemetryPacket => {
                const typ: type = u32;
                _ = typ;
                _ = c.igInputInt("test", @ptrCast(@alignCast(packet.pointer)), 0, 0, 0);
            },
            telemetry.vec3fTelemetryPacket => {
                const typ: type = @Vector(3, f32);
                _ = typ;
                _ = c.igInputFloat("test", @ptrCast(@alignCast(packet.pointer)), 0, 0, "%.3f", 0);
            },
            else => {},
        }
    }

    c.igEnd();
}

fn update() void {
    if (c.igBegin("test", null, 0)) {}

    // instance.update();

    list();

    c.igEnd();
}
