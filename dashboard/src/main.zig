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

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

const PORT = 62895;

var backend: Backend = undefined;
var packets: telemetry.TelemetryPackets = undefined;
var instance: tm.TelometerInstance(Backend, telemetry.TelemetryPackets) = undefined;

var test_plot: Plot = undefined;
var plot_arm: Plot3d = undefined;
var vel_plot: Plot3d = undefined;

const stdout = std.io.getStdOut().writer();

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

    // NOTE: you have to use the c allocator bc ImGui will try to free it...
    const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/DejavuSansMono-5m7L.ttf"));
    // const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/Slugs Racer.ttf"));

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

    test_plot = Plot.init(allocator);
    plot_arm = Plot3d.init(300, 10, 30);
    vel_plot = Plot3d.init(20, 1, 10);

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

    if (c.igInputFloat(name, &value, 0, 0, "%1f", c.ImGuiInputTextFlags_EnterReturnsTrue)) {
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

fn displayValue(ValueType: type, comptime name: [:0]const u8, comptime parent_name: [:0]const u8, data: *ValueType, packet: *tm.Data) void {
    const info = @typeInfo(ValueType);
    const long_name = parent_name ++ name;
    switch (info) {
        .Struct => |struct_type| {
            // std.debug.print("struct {s}\n", .{thing.fields});

            // c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x * 2);

            if (c.igTreeNode_Str(name)) {
                c.igPushItemWidth(c.igCalcItemWidth() * 0.8);

                inline for (struct_type.fields) |field| {
                    displayValue(field.type, field.name, long_name ++ ".", &@field(data.*, field.name), packet);
                }
                c.igPopItemWidth();
                c.igTreePop();
            }
        },
        .Int => {
            if (displayInt("##" ++ name, data, ValueType)) packet.queued = true;
        },
        .Float => {
            if (displayFloat("##" ++ name, data, ValueType)) packet.queued = true;
        },
        .Bool => {
            // if (c.igCheckbox("##" ++ name, @ptrCast(@alignCast(data)))) packet.queued = true;
        },
        else => {
            c.igTextUnformatted(name, name.ptr + name.len);
        },
    }

    switch (info) {
        .Int, .Float, .Bool => {
            c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
            _ = c.igSelectable_Bool(name, false, 0, c.ImVec2{ .x = 0, .y = 0 });

            if (c.igBeginDragDropSource(c.ImGuiDragDropFlags_None)) {
                drag_drop_payload = PlotData{
                    .pointer = @unionInit(PlotValue, @typeName(ValueType), @ptrCast(@alignCast(data))),
                    .updated = &packet.received,
                    .name = long_name,
                };
                _ = c.igSetDragDropPayload("f32", &drag_drop_payload, @sizeOf(PlotData), c.ImGuiCond_Once);
                c.igTextUnformatted(long_name, long_name.ptr + long_name.len);
                c.igEndDragDropSource();
            }
        },
        else => {},
    }
}

var drag_drop_payload: PlotData = undefined;
var my_bool: bool = false;

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

        displayValue(packetType.type, packetType.name, "", @ptrCast(@alignCast(packet.pointer)), packet);
    }

    c.igEnd();
}

const PlotValue = union(enum) {
    f64: *f64,
    f32: *f32,
    u8: *u8,
    i8: *i8,
    u16: *u16,
    i16: *i16,
    u32: *u32,
    i32: *i32,
    u64: *u64,
    i64: *i64,
    c_int: *c_int,
    bool: *bool,

    pub fn get_float(self: PlotValue) f64 {
        return switch (self) {
            inline else => |s| {
                const info = @typeInfo(@typeInfo(@TypeOf(s)).Pointer.child);
                switch (info) {
                    .Float => {
                        return @floatCast(s.*);
                    },
                    .Int => {
                        return @floatFromInt(s.*);
                    },
                    .Bool => {
                        return @floatFromInt(@intFromBool(s.*));
                    },
                    else => unreachable,
                }
            },
        };
    }
};

const PlotData = struct {
    const Self = @This();
    const DataStruct = struct { value: f64, time: f64 };
    const max_len = 1 << 15;
    pointer: PlotValue,
    updated: *bool,
    name: [*c]const u8,
    offset: i32 = 0,
    data: std.ArrayList(DataStruct) = undefined,

    pub fn initData(self: *Self, allocator: std.mem.Allocator, timestamp: f64) void {
        self.data = std.ArrayList(DataStruct).initCapacity(allocator, max_len) catch unreachable;
        self.data.append(DataStruct{ .value = self.pointer.get_float(), .time = timestamp }) catch unreachable;
        self.data.append(DataStruct{ .value = self.pointer.get_float(), .time = timestamp }) catch unreachable;
    }

    pub fn update(self: *Self, timestamp: f64) void {
        const length = self.data.items.len;

        self.get_value(-1).time = timestamp;

        if (self.updated.*) {
            self.get_value(-1).value = self.pointer.get_float();

            stdout.print("{}, {}\n", .{ timestamp, self.pointer.get_float() }) catch unreachable;

            if (length < max_len) {
                self.data.append(DataStruct{ .value = self.pointer.get_float(), .time = timestamp }) catch unreachable;
            } else {
                self.offset += 1;
                self.get_value(-1).* = DataStruct{ .value = self.pointer.get_float(), .time = timestamp };
            }
        }
    }

    pub fn get_value(self: *Self, index: i32) *DataStruct {
        const length = self.data.items.len;
        return &self.data.items[@intCast(@mod((self.offset + index), @as(i32, @intCast(length))))];
    }
};

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

const Plot = struct {
    const Self = @This();
    paused: bool,
    data_pointers: std.ArrayList(PlotData),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .paused = false,
            .data_pointers = std.ArrayList(PlotData).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn update(self: *Self) void {
        const current_time: f64 = @as(f64, @floatFromInt(std.time.microTimestamp())) / 1e6;

        if (c.igBegin("Plot", null, 0)) {
            if (c.ImPlot_BeginPlot("test", c.ImVec2{ .x = -1, .y = -50 }, 0)) {
                c.ImPlot_SetupAxes("Time", "", 0, 0);

                c.ImPlot_SetupAxisLimits(0, current_time - 10, current_time, c.ImPlotCond_Once);
                c.ImPlot_SetupAxisScale_PlotScale(c.ImAxis_X1, c.ImPlotScale_Time);

                if (!self.paused) {
                    var pout: c.ImPlotRect = undefined;
                    c.ImPlot_GetPlotLimits(&pout, c.ImAxis_X1, c.ImAxis_Y1);
                    const range = pout.X.Max - pout.X.Min;
                    c.ImPlotAxis_SetRange_double(&c.ImPlot_GetCurrentPlot().*.Axes[c.ImAxis_X1], current_time - range, current_time);
                }

                if (c.ImPlot_BeginDragDropTargetPlot()) {
                    if (c.igAcceptDragDropPayload("f32", c.ImGuiDragDropFlags_None)) |payload| {
                        self.data_pointers.append(@as(*PlotData, @ptrCast(@alignCast(payload.*.Data))).*) catch unreachable;
                        self.data_pointers.items[self.data_pointers.items.len - 1].initData(self.allocator, current_time);
                    }
                    c.ImPlot_EndDragDropTarget();
                }

                // if (self.data_pointers.items.len > 0) {
                //     std.debug.print("{},", .{current_time});
                // }

                for (self.data_pointers.items) |*data| {
                    if (c.ImPlot_GetCurrentPlot().*.Axes[c.ImAxis_X1].Range.Max >= current_time) {
                        data.update(current_time);
                    }

                    c.ImPlot_PlotLine_doublePtrdoublePtr(
                        data.name,
                        &data.data.items[0].time,
                        &data.data.items[0].value,
                        @intCast(data.data.items.len),
                        c.ImPlotLineFlags_None,
                        data.offset,
                        @intCast(@sizeOf(f64) * 2),
                    );
                }

                // if (self.data_pointers.items.len > 0) {
                //     std.debug.print("\n", .{});
                // }

                if (plot_reflow) {
                    c.ImPlot_PlotLine_doublePtrdoublePtr(
                        "reflow",
                        &reflow_times,
                        &reflow_temps,
                        reflow_times.len,
                        c.ImPlotFlags_None,
                        0,
                        @sizeOf(f64),
                    );
                }

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

const Plot3d = struct {
    const Self = @This();
    cameraTransform: mat.Mat(4, 4, f32),
    drawList: [*c]c.ImDrawList,
    start: c.ImVec2,
    size: c.ImVec2,
    bounds_x: f32,
    bounds_y: f32,
    sf: f32,
    projectionRatio: f32,
    rotation: f32,
    gridLines: i32,
    gridSpacing: f32,

    pub fn init(
        cameraDist: f32,
        gridSpacing: f32,
        gridLines: i32,
    ) Self {
        const cameraPos = mat.Vec3f.new(.{ 1 * cameraDist, 1 * cameraDist, 1 * cameraDist });
        const cameraDir = mat.Vec3f.new(.{ -1, -1, -1 }).unit();
        // const xy_dir = mat.Vec2f.new(.{ cameraDir.d[0], cameraDir.d[1] });
        // const up_xy = xy_dir.unit().scale(-cameraDir.d[2]);

        // std.debug.print("cameraDir: {}\nxy_dir: {}\nup_xy: {}\ntransform: {} \n", .{ cameraDir, xy_dir, up_xy, mat.translation_matrix(f32, cameraPos) });

        // const transform_up: mat.Vec3f = mat.Vec3f.new(.{ up_xy.d[0], up_xy.d[1], xy_dir.norm() });
        const sideways: mat.Vec3f = cameraDir.cross(mat.Vec3f.new(.{ 0, 0, 1 })).unit();
        const transform_up: mat.Vec3f = sideways.cross(cameraDir);

        const self: Self = .{
            .cameraTransform = mat.Mat(4, 4, f32).new(.{
                cameraDir.d[0], sideways.d[0], transform_up.d[0], 0.0,
                cameraDir.d[1], sideways.d[1], transform_up.d[1], 0.0,
                cameraDir.d[2], sideways.d[2], transform_up.d[2], 0.0,
                0.0,            0.0,           0.0,               1.0,
            }).transpose().mul(mat.translation_matrix(f32, cameraPos).inverse() orelse unreachable),

            .drawList = undefined,
            .start = undefined,
            .size = undefined,
            .bounds_x = 10,
            .bounds_y = 10,
            .projectionRatio = 5,
            .sf = 0,
            .rotation = 0,
            .gridLines = gridLines,
            .gridSpacing = gridSpacing,
        };

        // std.debug.print("Camera Transform: {}\n", .{self.cameraTransform});

        // const test2 = mat.Vec4f.new(.{ 0, 0, 0, 1 });

        // std.debug.print("test transform: {}\n", .{self.cameraTransform.mul(test2.col_matrix())});

        return self;
    }

    pub fn toScreenSpace(self: Self, point: mat.Vec4f) mat.Vec2f {
        return mat.Vec2f.new(.{
            point.d[1] * self.projectionRatio / point.d[0] * self.sf + self.start.x + self.size.x / 2,
            (self.start.y + self.size.y / 2) - point.d[2] * self.projectionRatio / point.d[0] * self.sf,
        });
    }

    pub fn drawLine(self: Self, start: mat.Vec3f, stop: mat.Vec3f, color: c.ImU32, thickness: f32) void {
        // const transformSpace = mat.Mat(4, 1, f32).new(.{ start.d, 1 });
        const cameraSpaceStart = self.cameraTransform.mul(mat.Mat(4, 1, f32).new(.{ start.d[0], start.d[1], start.d[2], 1 }));
        const cameraSpaceEnd = self.cameraTransform.mul(mat.Mat(4, 1, f32).new(.{ stop.d[0], stop.d[1], stop.d[2], 1 }));

        const screenSpaceStart = self.toScreenSpace(mat.Vec4f.new(cameraSpaceStart.m));
        const screenSpaceEnd = self.toScreenSpace(mat.Vec4f.new(cameraSpaceEnd.m));
        c.ImDrawList_AddLine(self.drawList, .{ .x = screenSpaceStart.d[0], .y = screenSpaceStart.d[1] }, .{ .x = screenSpaceEnd.d[0], .y = screenSpaceEnd.d[1] }, color, thickness);
    }

    pub fn drawTransformMatrix(self: Self, matrix: mat.Mat(4, 4, f32), scale: f32) void {
        const transform: mat.Vec3f = .{ .d = matrix.col(3).d[0..3].* };
        for (0..3) |i| {
            self.drawLine(transform, transform.add(mat.Vec3f.new(matrix.col(i).d[0..3].*).scale(scale)), (@as(u32, 0xFF) << @intCast(i * 8)) | 0xFF000000, scale / 10);
        }
    }

    pub fn updateBegin(self: *Self) void {
        self.drawList = c.igGetWindowDrawList();
        c.igGetCursorScreenPos(&self.start);
        c.igGetContentRegionAvail(&self.size);

        if ((self.size.x * (self.bounds_y / self.bounds_x)) < self.size.y) {
            // std.debug.print("toast? {}, {}, \n", .{ self.size.x * (self.bounds_y / self.size.y), self.size.y });
            self.sf = self.size.x / (self.bounds_x);
            self.start.y = self.start.y + (self.size.y - self.bounds_y * self.sf) / 2;
        } else {
            // std.debug.print("test?\n", .{});
            self.sf = self.size.y / (self.bounds_y);
            self.start.x = self.start.x + (self.size.x - self.bounds_x * self.sf) / 2;
        }

        self.size = .{ .x = self.bounds_x * self.sf, .y = self.bounds_y * self.sf };

        // c.igSetScrollY_WindowPtr(, )
        if (c.igIsWindowFocused(c.ImGuiFocusedFlags_None)) {
            const scrollFactor = std.math.pow(f32, 2, -0.05 * c.igGetIO().*.MouseWheel);
            self.cameraTransform = self.cameraTransform.mul(mat.scale_matrix(f32, mat.Vec3f.new(.{ scrollFactor, scrollFactor, scrollFactor })));

            if (c.igGetIO().*.MouseDown[0]) {
                const xdrag = c.igGetIO().*.MouseDelta.x;
                self.rotation = xdrag * -0.005;
            }
            const horizontal = c.igGetIO().*.MouseWheelH;
            if (horizontal != 0) {
                self.rotation = horizontal * -0.01;
            }
        }
        // self.rotation = self.rotation * 0.98;

        self.cameraTransform = self.cameraTransform.mul(mat.rotation_axis_angle(f32, mat.Vec3f.new(.{ 0, 0, 1 }), self.rotation));

        c.ImDrawList_AddRectFilled(
            self.drawList,
            self.start,
            c.ImVec2{ .x = self.start.x + self.size.x, .y = self.start.y + self.size.y - 30 },
            0xFF101010,
            10,
            c.ImDrawFlags_None,
        );

        c.ImDrawList_PushClipRect(
            self.drawList,
            self.start,
            c.ImVec2{ .x = self.start.x + self.size.x, .y = self.start.y + self.size.y - 30 },
            false,
        );

        for (0..@intCast(self.gridLines * 2 + 1)) |n| {
            const i: i32 = @as(i32, @intCast(n)) - self.gridLines;
            self.drawLine(
                mat.Vec3f.new(.{ @as(f32, @floatFromInt(i)) * self.gridSpacing, @as(f32, @floatFromInt(self.gridLines)) * self.gridSpacing, 0 }),
                mat.Vec3f.new(.{ @as(f32, @floatFromInt(i)) * self.gridSpacing, -@as(f32, @floatFromInt(self.gridLines)) * self.gridSpacing, 0 }),
                0x55FFFFFF,
                2,
            );
            self.drawLine(
                mat.Vec3f.new(.{ @as(f32, @floatFromInt(self.gridLines)) * self.gridSpacing, @as(f32, @floatFromInt(i)) * self.gridSpacing, 0 }),
                mat.Vec3f.new(.{ -@as(f32, @floatFromInt(self.gridLines)) * self.gridSpacing, @as(f32, @floatFromInt(i)) * self.gridSpacing, 0 }),
                0x55FFFFFF,
                2,
            );
        }

        self.drawTransformMatrix(mat.Mat(4, 4, f32).identity(), self.gridSpacing);

        // self.drawLine(mat.Vec3f.new(.{ 0, 0, 0 }), mat.Vec3f.new(.{ 0, 0, 10 }), 0xFFFF0000, 2);

        // self.drawTransformMatrix(mat.translation_matrix(f32, mat.Vec3f.new(.{ 0, 0, 30 })), 20);

        // std.debug.print("size: {}\n", .{@sizeOf(mat.Mat(4, 4, f32))});

        // std.debug.print("{}\n", .{self.cameraPos});

    }

    pub fn end(self: *Self) void {
        c.ImDrawList_PopClipRect(self.drawList);
    }
};

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

    const jacobian: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.jacobianVel.pointer))).*);
    const vel: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.vel.pointer))).*);

    const transform: mat.Vec3f = .{ .d = transforms[3].transpose().col(3).d[0..3].* };

    // std.debug.print("transform? {}, {}\n", .{ transform, transforms[3] });

    plot_arm.drawLine(transform, transform.add(jacobian), 0xFFFF6900, 2);
    plot_arm.drawLine(transform, transform.add(vel), 0xFF00B1DF, 2);
    plot_arm.end();
    c.igEnd();
}

fn vel3d() void {
    if (c.igBegin("Velocity", null, 0)) {}
    vel_plot.updateBegin();

    const jacobian: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.jacobianVel.pointer))).*);
    const vel: mat.Vec3f = @as(mat.Vec3f, @as(*mat.Vec3f, @ptrCast(@alignCast(packets.vel.pointer))).*);
    vel_plot.drawLine(mat.Vec3f.new(.{ 0, 0, 0 }), jacobian, 0xFFFF6900, 3);
    vel_plot.drawLine(mat.Vec3f.new(.{ 0, 0, 0 }), vel, 0xFF00B1DF, 3);

    vel_plot.end();
    c.igEnd();
}

fn update() void {
    if (c.igBegin("test", null, 0)) {}

    c.igEnd();
    instance.update();

    reflow();

    test_plot.update();
    plotArm();
    vel3d();

    list();
}
