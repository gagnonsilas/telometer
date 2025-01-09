const std = @import("std");
pub const c = @cImport({
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

fn theme_fluent() void {
    // var io = c.igGetIO();

    // io.Fonts->Clear();
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Light.ttf", 18);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Regular.ttf", 18);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Light.ttf", 32);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Regular.ttf", 14);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Bold.ttf", 14);
    // io.Fonts->Build();

    var style: *c.ImGuiStyle = @ptrCast(c.igGetStyle());
    var colors = &style.*.Colors;

    // General window settings
    style.WindowRounding = 5.0;
    style.FrameRounding = 5.0;
    style.ScrollbarRounding = 5.0;
    style.GrabRounding = 5.0;
    style.TabRounding = 5.0;
    style.WindowBorderSize = 1.0;
    style.FrameBorderSize = 1.0;
    style.PopupBorderSize = 1.0;
    style.PopupRounding = 5.0;

    // Setting the colors
    colors[c.ImGuiCol_Text] = c.ImVec4{ .x = 0.95, .y = 0.95, .z = 0.95, .w = 1.00 };
    colors[c.ImGuiCol_TextDisabled] = c.ImVec4{ .x = 0.60, .y = 0.60, .z = 0.60, .w = 1.00 };
    colors[c.ImGuiCol_WindowBg] = c.ImVec4{ .x = 0.13, .y = 0.13, .z = 0.13, .w = 1.00 };
    colors[c.ImGuiCol_ChildBg] = c.ImVec4{ .x = 0.10, .y = 0.10, .z = 0.10, .w = 1.00 };
    colors[c.ImGuiCol_PopupBg] = c.ImVec4{ .x = 0.18, .y = 0.18, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_Border] = c.ImVec4{ .x = 0.30, .y = 0.30, .z = 0.30, .w = 1.00 };
    colors[c.ImGuiCol_BorderShadow] = c.ImVec4{ .x = 0.00, .y = 0.00, .z = 0.00, .w = 0.00 };
    colors[c.ImGuiCol_FrameBg] = c.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_FrameBgHovered] = c.ImVec4{ .x = 0.25, .y = 0.25, .z = 0.25, .w = 1.00 };
    colors[c.ImGuiCol_FrameBgActive] = c.ImVec4{ .x = 0.30, .y = 0.30, .z = 0.30, .w = 1.00 };
    colors[c.ImGuiCol_TitleBg] = c.ImVec4{ .x = 0.10, .y = 0.10, .z = 0.10, .w = 1.00 };
    colors[c.ImGuiCol_TitleBgActive] = c.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_TitleBgCollapsed] = c.ImVec4{ .x = 0.10, .y = 0.10, .z = 0.10, .w = 1.00 };
    colors[c.ImGuiCol_MenuBarBg] = c.ImVec4{ .x = 0.15, .y = 0.15, .z = 0.15, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarBg] = c.ImVec4{ .x = 0.10, .y = 0.10, .z = 0.10, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarGrab] = c.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarGrabHovered] = c.ImVec4{ .x = 0.25, .y = 0.25, .z = 0.25, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarGrabActive] = c.ImVec4{ .x = 0.30, .y = 0.30, .z = 0.30, .w = 1.00 };

    // Accent colors changed to darker olive-green/grey shades
    colors[c.ImGuiCol_CheckMark] = c.ImVec4{ .x = 0.45, .y = 0.45, .z = 0.45, .w = 1.00 }; // Dark gray for check marks
    colors[c.ImGuiCol_SliderGrab] = c.ImVec4{ .x = 0.45, .y = 0.45, .z = 0.45, .w = 1.00 }; // Dark gray for sliders
    colors[c.ImGuiCol_SliderGrabActive] = c.ImVec4{ .x = 0.50, .y = 0.50, .z = 0.50, .w = 1.00 }; // Slightly lighter gray when active
    colors[c.ImGuiCol_Button] = c.ImVec4{ .x = 0.25, .y = 0.25, .z = 0.25, .w = 1.00 }; // Button background (dark gray)
    colors[c.ImGuiCol_ButtonHovered] = c.ImVec4{ .x = 0.30, .y = 0.30, .z = 0.30, .w = 0.2 }; // Button hover state
    colors[c.ImGuiCol_ButtonActive] = c.ImVec4{ .x = 0.35, .y = 0.35, .z = 0.35, .w = 0.2 }; // Button active state
    colors[c.ImGuiCol_Header] = c.ImVec4{ .x = 0.40, .y = 0.40, .z = 0.40, .w = 1.00 }; // Dark gray for menu headers
    colors[c.ImGuiCol_HeaderHovered] = c.ImVec4{ .x = 0.45, .y = 0.45, .z = 0.45, .w = 1.00 }; // Slightly lighter on hover
    colors[c.ImGuiCol_HeaderActive] = c.ImVec4{ .x = 0.50, .y = 0.50, .z = 0.50, .w = 1.00 }; // Lighter gray when active
    colors[c.ImGuiCol_Separator] = c.ImVec4{ .x = 0.30, .y = 0.30, .z = 0.30, .w = 1.00 }; // Separators in dark gray
    colors[c.ImGuiCol_SeparatorHovered] = c.ImVec4{ .x = 0.35, .y = 0.35, .z = 0.35, .w = 1.00 };
    colors[c.ImGuiCol_SeparatorActive] = c.ImVec4{ .x = 0.40, .y = 0.40, .z = 0.40, .w = 1.00 };
    colors[c.ImGuiCol_ResizeGrip] = c.ImVec4{ .x = 0.45, .y = 0.45, .z = 0.45, .w = 1.00 }; // Resize grips in dark gray
    colors[c.ImGuiCol_ResizeGripHovered] = c.ImVec4{ .x = 0.50, .y = 0.50, .z = 0.50, .w = 1.00 };
    colors[c.ImGuiCol_ResizeGripActive] = c.ImVec4{ .x = 0.55, .y = 0.55, .z = 0.55, .w = 1.00 };
    colors[c.ImGuiCol_Tab] = c.ImVec4{ .x = 0.18, .y = 0.18, .z = 0.18, .w = 1.00 }; // Tabs background
    colors[c.ImGuiCol_TabHovered] = c.ImVec4{ .x = 0.40, .y = 0.40, .z = 0.40, .w = 1.00 }; // Darker gray on hover
    colors[c.ImGuiCol_TabSelected] = c.ImVec4{ .x = 0.40, .y = 0.40, .z = 0.40, .w = 1.00 };
    colors[c.ImGuiCol_TabDimmed] = c.ImVec4{ .x = 0.18, .y = 0.18, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_TabDimmedSelected] = c.ImVec4{ .x = 0.40, .y = 0.40, .z = 0.40, .w = 1.00 };
    colors[c.ImGuiCol_TabSelectedOverline] = .{ .w = 0.0 };
    colors[c.ImGuiCol_TabDimmedSelectedOverline] = .{ .w = 0.0 };
    colors[c.ImGuiCol_DockingPreview] = c.ImVec4{ .x = 0.45, .y = 0.45, .z = 0.45, .w = 1.00 }; // Docking preview in gray
    colors[c.ImGuiCol_DockingEmptyBg] = c.ImVec4{ .x = 0.18, .y = 0.18, .z = 0.18, .w = 1.00 }; // Empty dock background
    // Additional styles
    style.FramePadding = c.ImVec2{ .x = 8.0, .y = 4.0 };
    style.ItemSpacing = c.ImVec2{ .x = 8.0, .y = 4.0 };
    style.IndentSpacing = 20.0;
    style.ScrollbarSize = 16.0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    _ = allocator; // autofix

    try backend.openSerial("/dev/ttyUSB0");

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

    const window = c.SDL_CreateWindow(
        "Telometer Dashboard",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        800,
        600,
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

    // NOTE: you have to use the c allocator bc ImGui will try to free it...
    const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/DejavuSansMono-5m7L.ttf"));

    _ = c.ImFontAtlas_AddFontFromMemoryTTF(io.*.Fonts, @ptrCast(dejavu), @intCast(dejavu.len), 16, c.ImFontConfig_ImFontConfig(), null);

    // c.igStyleColorsDark(null);
    theme_fluent();

    _ = c.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    defer c.ImGui_ImplSDL2_Shutdown();

    _ = c.ImGui_ImplOpenGL3_Init("#version 410");
    defer c.ImGui_ImplOpenGL3_Shutdown();

    const context = c.ImPlot_CreateContext() orelse @panic("Kill yourself");
    defer c.ImPlot_DestroyContext(context);

    // std.debug.print("drag drop? {}\n", .{c.igIsDragDropActive()});
    // c.igDragDrop

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

var updatesDecay: [telemetry.TelemetryPacketCount]f32 = std.mem.zeroes([telemetry.TelemetryPacketCount]f32);

// const IntDragDrop = struct { "" };

fn displayFloat(name: [*c]const u8, data: *anyopaque, dataType: type) bool {
    const cast_data: *dataType = @ptrCast(@alignCast(data));
    var value: f32 = std.math.lossyCast(f32, cast_data.*);

    if (c.igInputFloat(name, &value, 0, 0, "%1f", c.ImGuiInputTextFlags_None)) {
        cast_data.* = std.math.lossyCast(dataType, value);
        return true;
    }

    return false;
}

fn displayInt(name: [*c]const u8, data: *anyopaque, dataType: type) bool {
    const castData: *dataType = @ptrCast(@alignCast(data));
    var value: c_int = @truncate(@as(i64, @intCast(castData.*)));

    if (c.igInputInt(name, &value, 0, 0, c.ImGuiInputTextFlags_EnterReturnsTrue)) {
        castData.* = std.math.lossyCast(dataType, value);
        return true;
    }

    return false;
}

fn list() void {
    if (c.igBegin("data", null, 0)) {}

    inline for (@typeInfo(telemetry.TelemetryTypes).Struct.fields, 0..) |packetType, i| {
        const packet: *tm.Data = &instance.packet_struct[i];

        updatesDecay[i] *= 0.99;

        if (packet.received) {
            updatesDecay[i] = 1;
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
            c.ImVec2{ .x = c.igGetFrameHeight(), .y = c.igGetFrameHeight() },
        )) {
            packet.queued = true;
        }
        c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);

        // const info = @typeInfo(packetType.type);

        switch (@typeInfo(packetType.type)) {
            .Struct => |struct_type| {
                // std.debug.print("struct {s}\n", .{thing.fields});

                const max_fields = 3;
                const fields: f32 = @min(struct_type.fields.len, max_fields);
                c.igPushItemWidth((c.igCalcItemWidth() - c.igGetStyle().*.ItemInnerSpacing.x) / fields);

                inline for (struct_type.fields, 0..) |field, j| {
                    if (j >= max_fields) {
                        break;
                    }

                    switch (@typeInfo(field.type)) {
                        .Int => {
                            if (displayInt("##" ++ field.name, &@field(@as(*packetType.type, @ptrCast(@alignCast(packet.pointer))).*, field.name), field.type)) packet.queued = true;
                        },
                        .Float => {
                            if (displayFloat("##" ++ field.name, &@field(@as(*packetType.type, @ptrCast(@alignCast(packet.pointer))).*, field.name), field.type)) packet.queued = true;
                        },
                        else => {},
                    }
                    c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
                }
                c.igTextUnformatted(packetType.name, packetType.name.ptr + packetType.name.len);
                c.igPopItemWidth();
            },
            .Int => {
                if (displayInt(packetType.name, packet.pointer, packetType.type)) packet.queued = true;
            },
            .Float => {
                if (displayFloat(packetType.name, packet.pointer, packetType.type)) packet.queued = true;
            },
            else => {
                c.igTextUnformatted(packetType.name, packetType.name.ptr + packetType.name.len);
            },
        }
    }

    c.igEnd();
}

var testptr: u32 = 10;

const Plot = struct {
    const Self = @This();
    paused: bool,
    payloadptr: *u32,

    pub fn init() Self {
        return .{
            .paused = false,
            .payloadptr = &testptr,
        };
    }

    pub fn update(self: *Self) void {
        const currentTime: f64 = @as(f64, @floatFromInt(std.time.microTimestamp())) / 1e6;

        if (c.igBegin("Plot", null, 0)) {
            if (c.ImPlot_BeginPlot("test", c.ImVec2{ .x = -1, .y = -50 }, 0)) {
                c.ImPlot_SetupAxes("Time", "", 0, 0);

                c.ImPlot_SetupAxisLimits(0, currentTime - 10, currentTime, c.ImPlotCond_Once);
                c.ImPlot_SetupAxisScale_PlotScale(c.ImAxis_X1, c.ImPlotScale_Time);

                if (!self.paused) {
                    var pout: c.ImPlotRect = undefined;
                    c.ImPlot_GetPlotLimits(&pout, c.ImAxis_X1, c.ImAxis_Y1);
                    const range = pout.X.Max - pout.X.Min;
                    c.ImPlotAxis_SetRange_double(&c.ImPlot_GetCurrentPlot().*.Axes[c.ImAxis_X1], currentTime - range, currentTime);
                }

                if (c.ImPlot_BeginDragDropTargetPlot()) {
                    if (c.igAcceptDragDropPayload("u32", c.ImGuiDragDropFlags_None)) |dataPtr| {
                        self.payloadptr = @as(**u32, @ptrCast(@alignCast(dataPtr.*.Data))).*;
                    }

                    c.ImPlot_EndDragDropTarget();
                }
                // std.debug.print("{}\n", .{@as(u32, self.payloadptr.*)});

                c.ImPlot_EndPlot();

                if (self.paused) {
                    c.igPushStyleColor_Vec4(c.ImGuiCol_Button, c.ImVec4{ .x = 0, .y = 0, .z = 0, .w = 0.5 });
                } else {
                    c.igPushStyleColor_Vec4(c.ImGuiCol_Button, c.ImVec4{ .x = 0, .y = 0, .z = 0, .w = 0 });
                }

                if (c.igButton("Pause", c.ImVec2{ .x = -1, .y = -1 })) {
                    self.paused = !self.paused;
                }

                c.igPopStyleColor(1);
            }
        }
        c.igEnd();
    }
};

var testPlot: Plot = Plot.init();

fn update() void {
    if (c.igBegin("test", null, 0)) {}

    c.igEnd();
    instance.update();

    testPlot.update();

    list();
}
