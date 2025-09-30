const std = @import("std");
pub const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});

// pub const nfd = @cImport({
// @cInclude("nfd.h");
// });

const mat = @import("mat.zig");
const math = std.math;

const tm = @import("telometer");
const log = tm.log;
const Backend = @import("backend.zig").Backend;

const telemetry = @cImport({
    @cInclude("Packets.h");
});

const stdout = std.io.getStdOut().writer();

pub fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

// pub fn openFile(out_path: []u8) void {
//     _ = nfd.NFD_Init();

//     const filters = [1]nfd.nfdu8filteritem_t{.{ .name = "Telometer Log", .spec = "tl" }};
//     const args: nfd.nfdopendialogu8args_t = .{
//         .filterList = @ptrCast(&filters[0]),
//         .filterCount = 1,
//     };

//     var path: [*c]u8 = null;

//     const result: nfd.nfdresult_t = nfd.NFD_OpenDialogU8_With(&path, &args);

//     if (result != nfd.NFD_OKAY) {
//         if (nfd.NFD_GetError()) |ptr| {
//             std.debug.print("{s}\n", .{
//                 std.mem.sliceTo(ptr, 0),
//             });
//         }
//         return;
//         // return error.NfdError;
//     }

//     const len = std.mem.len(path);
//     if (len > out_path.len) {
//         std.debug.print("file path too long: {s}\n", .{path});
//         return;
//     } else {
//         @memcpy(out_path[0 .. len + 1], path[0 .. len + 1]);
//     }

//     nfd.NFD_FreePathU8(path);
// }

var log_path: [256]u8 = undefined;

pub fn LogInterface(comptime Logger: type) type {
    return struct {
        const Self = @This();
        instance_logger: *Logger,
        log_file: ?Logger,

        pub fn init(instance_logger: *Logger) Self {
            return .{
                .instance_logger = instance_logger,
                .log_file = null,
            };
        }

        pub fn update(self: *Self) void {
            defer c.igEnd();
            if (c.igBegin("Log File", null, 0)) {
                _ = c.igInputText("Log File", &log_path, 256, c.ImGuiInputTextFlags_None, null, null);
                if (c.igButton("OPEN", .{})) {
                    // _ = (std.Thread.spawn(.{}, openFile, .{&log_path}) catch unreachable).detach();
                }
                c.igSameLine(0, 8);
                if (c.igButton("LOAD", .{})) {
                    std.debug.print(" what2?? \n", .{});
                    if (self.log_file) |*log_file| {
                        log_file.close();
                    }
                    self.log_file = Logger.initFromFile(log_path[0..std.mem.len(@as([*c]u8, @ptrCast(&log_path)))]) catch unreachable;
                }

                // const current_logger: *Logger = &(self.log_file orelse self.instance_logger.*);
                // const current_logger = self.instance_logger;

                if (c.ImPlot_BeginPlot(
                    "log",
                    .{ .x = -1, .y = 100 },
                    c.ImPlotFlags_NoFrame | c.ImPlotFlags_NoLegend | c.ImPlotFlags_CanvasOnly,
                    // c.ImPlotFlags_NoFrame,
                )) {
                    c.ImPlot_SetupAxis(c.ImAxis_Y1, "", c.ImPlotAxisFlags_NoDecorations);
                    c.ImPlot_SetupAxis(c.ImAxis_X1, "", c.ImPlotFlags_None);
                    // c.ImPlot_SetupAxisLimits(
                    //     c.ImAxis_X1,
                    //     @floatFromInt(current_logger.header.start_time),
                    //     @floatFromInt(current_logger.header.end_time),
                    //     c.ImPlotCond_Always,
                    // );
                    // std.debug.print("start: {}, end: {}\n", .{
                    //     (current_logger.header.start_time),
                    //     (current_logger.header.end_time),
                    // });

                    c.ImPlot_EndPlot();
                }
            }
        }
    };
}

pub const Dashboard = struct {
    const Self = @This();
    window: *c.SDL_Window,
    gl_context: c.SDL_GLContext,
    ctx: ?*c.ImGuiContext,
    io: [*c]c.ImGuiIO,
    context: [*c]c.ImPlotContext,

    pub fn init() !Self {
        var self: Self = .{
            .window = undefined,
            .gl_context = undefined,
            .ctx = undefined,
            .io = undefined,
            .context = undefined,
        };

        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            return error.GLFWInitFailed;
        }

        if (0 != c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3)) {
            return error.FailedToSetGLVersion;
        }
        if (0 != c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 3)) {
            return error.FailedToSetGLVersion;
        }
        if (0 != c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE)) {
            return error.FailedToSetGLVersion;
        }

        self.window = c.SDL_CreateWindow(
            "Telometer Dashboard",
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            900,
            900,
            c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_ALLOW_HIGHDPI,
        ) orelse return error.GLFWCreateWindowFailed;

        self.gl_context = c.SDL_GL_CreateContext(self.window);
        if (0 != c.SDL_GL_MakeCurrent(self.window, self.gl_context))
            return error.GLMakeCurrentFailed;

        if (0 != c.SDL_GL_SetSwapInterval(1))
            return error.GLMakeCurrentFailed;

        if (c.gladLoadGLLoader(c.SDL_GL_GetProcAddress) == 0) {
            return error.FailedToLoadOpenGL;
        }

        self.ctx = c.igCreateContext(null);

        self.io = c.igGetIO();
        self.io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;
        self.io.*.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;

        // c.igStyleColorsDark(null);

        _ = c.ImGui_ImplSDL2_InitForOpenGL(self.window, self.gl_context);

        _ = c.ImGui_ImplOpenGL3_Init("#version 410");

        self.context = c.ImPlot_CreateContext() orelse @panic("Kill yourself");
        return self;
    }

    pub fn init_frame(_: *Self) void {
        c.ImGui_ImplOpenGL3_NewFrame();
        c.ImGui_ImplSDL2_NewFrame();
        c.igNewFrame();

        _ = c.igDockSpaceOverViewport(0, null, 0, c.ImGuiWindowClass_ImGuiWindowClass());
    }

    pub fn render(self: *Self, clear_color: c.ImVec4) void {
        c.igRender();
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.SDL_GetWindowSize(self.window, &width, &height);
        c.glViewport(0, 0, width, height);
        c.glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());

        c.SDL_GL_SwapWindow(self.window);
    }

    pub fn end(self: *Self) void {
        c.ImPlot_DestroyContext(self.context);
        c.ImGui_ImplOpenGL3_Shutdown();
        c.ImGui_ImplSDL2_Shutdown();
        c.igDestroyContext(self.ctx);
        c.SDL_GL_DeleteContext(self.gl_context);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};

pub fn theme_moonlight() void {
    var style: *c.ImGuiStyle = @ptrCast(c.igGetStyle());
    // var colors = &style.*.Colors;
    // NOTE: you have to use the c allocator bc ImGui will try to free it...
    const dejavu = std.heap.c_allocator.dupe(u8, @embedFile("fonts/DejavuSansMono-5m7L.ttf")) catch unreachable;
    // const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/Slugs Racer.ttf"));

    _ = c.ImFontAtlas_AddFontFromMemoryTTF(c.igGetIO().*.Fonts, @ptrCast(dejavu), @intCast(dejavu.len), 16, c.ImFontConfig_ImFontConfig(), null);

    style.Alpha = 1.0;
    style.DisabledAlpha = 1.0;
    style.WindowPadding = c.ImVec2{ .x = 12.0, .y = 12.0 };
    style.WindowRounding = 11.5;
    style.WindowBorderSize = 0.0;
    style.WindowMinSize = c.ImVec2{ .x = 20.0, .y = 20.0 };
    style.WindowTitleAlign = c.ImVec2{ .x = 0.5, .y = 0.5 };
    style.WindowMenuButtonPosition = c.ImGuiDir_Right;
    style.ChildRounding = 0.0;
    style.ChildBorderSize = 1.0;
    style.PopupRounding = 0.0;
    style.PopupBorderSize = 1.0;
    style.FramePadding = c.ImVec2{ .x = 20.0, .y = 3.400000095367432 };
    style.FrameRounding = 11.89999961853027;
    style.FrameBorderSize = 0.0;
    style.ItemSpacing = c.ImVec2{ .x = 4.300000190734863, .y = 5.5 };
    style.ItemInnerSpacing = c.ImVec2{ .x = 7.099999904632568, .y = 1.799999952316284 };
    style.CellPadding = c.ImVec2{ .x = 12.10000038146973, .y = 9.199999809265137 };
    style.IndentSpacing = 0.0;
    style.ColumnsMinSpacing = 4.900000095367432;
    style.ScrollbarSize = 11.60000038146973;
    style.ScrollbarRounding = 15.89999961853027;
    style.GrabMinSize = 3.700000047683716;
    style.GrabRounding = 20.0;
    style.TabRounding = 0.0;
    style.TabBorderSize = 0.0;
    style.TabMinWidthForCloseButton = 0.0;
    style.ColorButtonPosition = c.ImGuiDir_Right;
    style.ButtonTextAlign = c.ImVec2{ .x = 0.5, .y = 0.5 };
    style.SelectableTextAlign = c.ImVec2{ .x = 0.0, .y = 0.0 };

    // style.WindowRounding = 5.0;
    // style.FrameRounding = 5.0;
    // style.ScrollbarRounding = 5.0;
    // style.GrabRounding = 5.0;
    // style.TabRounding = 5.0;
    // style.WindowBorderSize = 1.0;
    // style.FrameBorderSize = 1.0;
    // style.PopupBorderSize = 1.0;
    // style.PopupRounding = 5.0;

    style.Colors[c.ImGuiCol_Text] = c.ImVec4{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 };
    style.Colors[c.ImGuiCol_TextDisabled] = c.ImVec4{ .x = 0.2745098173618317, .y = 0.3176470696926117, .z = 0.4509803950786591, .w = 1.0 };
    style.Colors[c.ImGuiCol_WindowBg] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    style.Colors[c.ImGuiCol_ChildBg] = c.ImVec4{ .x = 0.09250493347644806, .y = 0.100297249853611, .z = 0.1158798336982727, .w = 1.0 };
    style.Colors[c.ImGuiCol_PopupBg] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    style.Colors[c.ImGuiCol_Border] = c.ImVec4{ .x = 0.1568627506494522, .y = 0.168627455830574, .z = 0.1921568661928177, .w = 1.0 };
    style.Colors[c.ImGuiCol_BorderShadow] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    style.Colors[c.ImGuiCol_FrameBg] = c.ImVec4{ .x = 0.1120669096708298, .y = 0.1262156516313553, .z = 0.1545064449310303, .w = 1.0 };
    style.Colors[c.ImGuiCol_FrameBgHovered] = c.ImVec4{ .x = 0.1568627506494522, .y = 0.168627455830574, .z = 0.1921568661928177, .w = 1.0 };
    style.Colors[c.ImGuiCol_FrameBgActive] = c.ImVec4{ .x = 0.1568627506494522, .y = 0.168627455830574, .z = 0.1921568661928177, .w = 1.0 };
    style.Colors[c.ImGuiCol_TitleBg] = c.ImVec4{ .x = 0.0470588244497776, .y = 0.05490196123719215, .z = 0.07058823853731155, .w = 1.0 };
    style.Colors[c.ImGuiCol_TitleBgActive] = c.ImVec4{ .x = 0.0470588244497776, .y = 0.05490196123719215, .z = 0.07058823853731155, .w = 1.0 };
    style.Colors[c.ImGuiCol_TitleBgCollapsed] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    style.Colors[c.ImGuiCol_MenuBarBg] = c.ImVec4{ .x = 0.09803921729326248, .y = 0.105882354080677, .z = 0.1215686276555061, .w = 1.0 };
    style.Colors[c.ImGuiCol_ScrollbarBg] = c.ImVec4{ .x = 0.0470588244497776, .y = 0.05490196123719215, .z = 0.07058823853731155, .w = 1.0 };
    style.Colors[c.ImGuiCol_ScrollbarGrab] = c.ImVec4{ .x = 0.1176470592617989, .y = 0.1333333402872086, .z = 0.1490196138620377, .w = 1.0 };
    style.Colors[c.ImGuiCol_ScrollbarGrabHovered] = c.ImVec4{ .x = 0.1568627506494522, .y = 0.168627455830574, .z = 0.1921568661928177, .w = 1.0 };
    style.Colors[c.ImGuiCol_ScrollbarGrabActive] = c.ImVec4{ .x = 0.1176470592617989, .y = 0.1333333402872086, .z = 0.1490196138620377, .w = 1.0 };
    style.Colors[c.ImGuiCol_CheckMark] = c.ImVec4{ .x = 0.9725490212440491, .y = 1.0, .z = 0.4980392158031464, .w = 1.0 };
    style.Colors[c.ImGuiCol_SliderGrab] = c.ImVec4{ .x = 0.971993625164032, .y = 1.0, .z = 0.4980392456054688, .w = 1.0 };
    style.Colors[c.ImGuiCol_SliderGrabActive] = c.ImVec4{ .x = 1.0, .y = 0.7953379154205322, .z = 0.4980392456054688, .w = 1.0 };
    style.Colors[c.ImGuiCol_Button] = c.ImVec4{ .x = 0.1176470592617989, .y = 0.1333333402872086, .z = 0.1490196138620377, .w = 1.0 };
    style.Colors[c.ImGuiCol_ButtonHovered] = c.ImVec4{ .x = 0.1821731775999069, .y = 0.1897992044687271, .z = 0.1974248886108398, .w = 1.0 };
    style.Colors[c.ImGuiCol_ButtonActive] = c.ImVec4{ .x = 0.1545050293207169, .y = 0.1545048952102661, .z = 0.1545064449310303, .w = 1.0 };
    style.Colors[c.ImGuiCol_Header] = c.ImVec4{ .x = 0.1414651423692703, .y = 0.1629818230867386, .z = 0.2060086131095886, .w = 1.0 };
    style.Colors[c.ImGuiCol_HeaderHovered] = c.ImVec4{ .x = 0.1072951927781105, .y = 0.107295036315918, .z = 0.1072961091995239, .w = 1.0 };
    style.Colors[c.ImGuiCol_HeaderActive] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    style.Colors[c.ImGuiCol_Separator] = c.ImVec4{ .x = 0.1293079704046249, .y = 0.1479243338108063, .z = 0.1931330561637878, .w = 1.0 };
    style.Colors[c.ImGuiCol_SeparatorHovered] = c.ImVec4{ .x = 0.1568627506494522, .y = 0.1843137294054031, .z = 0.250980406999588, .w = 1.0 };
    style.Colors[c.ImGuiCol_SeparatorActive] = c.ImVec4{ .x = 0.1568627506494522, .y = 0.1843137294054031, .z = 0.250980406999588, .w = 1.0 };
    style.Colors[c.ImGuiCol_ResizeGrip] = c.ImVec4{ .x = 0.1459212601184845, .y = 0.1459220051765442, .z = 0.1459227204322815, .w = 1.0 };
    style.Colors[c.ImGuiCol_ResizeGripHovered] = c.ImVec4{ .x = 0.9725490212440491, .y = 1.0, .z = 0.4980392158031464, .w = 1.0 };
    style.Colors[c.ImGuiCol_ResizeGripActive] = c.ImVec4{ .x = 0.999999463558197, .y = 1.0, .z = 0.9999899864196777, .w = 1.0 };
    style.Colors[c.ImGuiCol_Tab] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    style.Colors[c.ImGuiCol_TabHovered] = c.ImVec4{ .x = 0.1176470592617989, .y = 0.1333333402872086, .z = 0.1490196138620377, .w = 1.0 };
    style.Colors[c.ImGuiCol_TabSelected] = c.ImVec4{ .x = 0.1176470592617989, .y = 0.1333333402872086, .z = 0.1490196138620377, .w = 1.0 };
    // style.Colors[c.ImGuiCol_TabUnfocused] = c.ImVec4{ .x = 0.0784313753247261, .y = 0.08627451211214066, .z = 0.1019607856869698, .w = 1.0 };
    // style.Colors[c.ImGuiCol_TabUnfocusedActive] = c.ImVec4{ .x = 0.1249424293637276, .y = 0.2735691666603088, .z = 0.5708154439926147, .w = 1.0 };
    style.Colors[c.ImGuiCol_PlotLines] = c.ImVec4{ .x = 0.5215686559677124, .y = 0.6000000238418579, .z = 0.7019608020782471, .w = 1.0 };
    style.Colors[c.ImGuiCol_PlotLinesHovered] = c.ImVec4{ .x = 0.03921568766236305, .y = 0.9803921580314636, .z = 0.9803921580314636, .w = 1.0 };
    style.Colors[c.ImGuiCol_PlotHistogram] = c.ImVec4{ .x = 0.8841201663017273, .y = 0.7941429018974304, .z = 0.5615870356559753, .w = 1.0 };
    style.Colors[c.ImGuiCol_PlotHistogramHovered] = c.ImVec4{ .x = 0.9570815563201904, .y = 0.9570719599723816, .z = 0.9570761322975159, .w = 1.0 };
    style.Colors[c.ImGuiCol_TableHeaderBg] = c.ImVec4{ .x = 0.0470588244497776, .y = 0.05490196123719215, .z = 0.07058823853731155, .w = 1.0 };
    style.Colors[c.ImGuiCol_TableBorderStrong] = c.ImVec4{ .x = 0.0470588244497776, .y = 0.05490196123719215, .z = 0.07058823853731155, .w = 1.0 };
    style.Colors[c.ImGuiCol_TableBorderLight] = c.ImVec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 };
    style.Colors[c.ImGuiCol_TableRowBg] = c.ImVec4{ .x = 0.1176470592617989, .y = 0.1333333402872086, .z = 0.1490196138620377, .w = 1.0 };
    style.Colors[c.ImGuiCol_TableRowBgAlt] = c.ImVec4{ .x = 0.09803921729326248, .y = 0.105882354080677, .z = 0.1215686276555061, .w = 1.0 };
    style.Colors[c.ImGuiCol_TextSelectedBg] = c.ImVec4{ .x = 0.9356134533882141, .y = 0.9356129765510559, .z = 0.9356223344802856, .w = 1.0 };
    style.Colors[c.ImGuiCol_DragDropTarget] = c.ImVec4{ .x = 0.4980392158031464, .y = 0.5137255191802979, .z = 1.0, .w = 1.0 };
    style.Colors[c.ImGuiCol_NavHighlight] = c.ImVec4{ .x = 0.266094446182251, .y = 0.2890366911888123, .z = 1.0, .w = 1.0 };
    style.Colors[c.ImGuiCol_NavWindowingHighlight] = c.ImVec4{ .x = 0.4980392158031464, .y = 0.5137255191802979, .z = 1.0, .w = 1.0 };
    style.Colors[c.ImGuiCol_NavWindowingDimBg] = c.ImVec4{ .x = 0.196078434586525, .y = 0.1764705926179886, .z = 0.5450980663299561, .w = 0.501960813999176 };
    style.Colors[c.ImGuiCol_ModalWindowDimBg] = c.ImVec4{ .x = 0.196078434586525, .y = 0.1764705926179886, .z = 0.5450980663299561, .w = 0.501960813999176 };
}

pub fn source_engine_theme() void {
    c.igStyleColorsDark(null);
    const dejavu = std.heap.c_allocator.dupe(u8, @embedFile("fonts/DejavuSansMono-5m7L.ttf")) catch unreachable;
    // const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/Slugs Racer.ttf"));

    _ = c.ImFontAtlas_AddFontFromMemoryTTF(c.igGetIO().*.Fonts, @ptrCast(dejavu), @intCast(dejavu.len), 16, c.ImFontConfig_ImFontConfig(), null);

    var style: *c.ImGuiStyle = @ptrCast(c.igGetStyle());
    var colors = &style.*.Colors;
    colors[c.ImGuiCol_Text] = c.ImVec4{ .x = 1.00, .y = 1.00, .z = 1.00, .w = 1.00 };
    colors[c.ImGuiCol_TextDisabled] = c.ImVec4{ .x = 0.50, .y = 0.50, .z = 0.50, .w = 1.00 };
    colors[c.ImGuiCol_WindowBg] = c.ImVec4{ .x = 0.29, .y = 0.34, .z = 0.26, .w = 1.00 };
    colors[c.ImGuiCol_ChildBg] = c.ImVec4{ .x = 0.29, .y = 0.34, .z = 0.26, .w = 1.00 };
    colors[c.ImGuiCol_PopupBg] = c.ImVec4{ .x = 0.24, .y = 0.27, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_Border] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 0.50 };
    colors[c.ImGuiCol_BorderShadow] = c.ImVec4{ .x = 0.14, .y = 0.16, .z = 0.11, .w = 0.52 };
    colors[c.ImGuiCol_FrameBg] = c.ImVec4{ .x = 0.24, .y = 0.27, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_FrameBgHovered] = c.ImVec4{ .x = 0.27, .y = 0.30, .z = 0.23, .w = 1.00 };
    colors[c.ImGuiCol_FrameBgActive] = c.ImVec4{ .x = 0.30, .y = 0.34, .z = 0.26, .w = 1.00 };
    colors[c.ImGuiCol_TitleBg] = c.ImVec4{ .x = 0.24, .y = 0.27, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_TitleBgActive] = c.ImVec4{ .x = 0.29, .y = 0.34, .z = 0.26, .w = 1.00 };
    colors[c.ImGuiCol_TitleBgCollapsed] = c.ImVec4{ .x = 0.00, .y = 0.00, .z = 0.00, .w = 0.51 };
    colors[c.ImGuiCol_MenuBarBg] = c.ImVec4{ .x = 0.24, .y = 0.27, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarBg] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarGrab] = c.ImVec4{ .x = 0.28, .y = 0.32, .z = 0.24, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarGrabHovered] = c.ImVec4{ .x = 0.25, .y = 0.30, .z = 0.22, .w = 1.00 };
    colors[c.ImGuiCol_ScrollbarGrabActive] = c.ImVec4{ .x = 0.23, .y = 0.27, .z = 0.21, .w = 1.00 };
    colors[c.ImGuiCol_CheckMark] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_SliderGrab] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_SliderGrabActive] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 0.50 };
    colors[c.ImGuiCol_Button] = c.ImVec4{ .x = 0.29, .y = 0.34, .z = 0.26, .w = 0.40 };
    colors[c.ImGuiCol_ButtonHovered] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_ButtonActive] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 0.50 };
    colors[c.ImGuiCol_Header] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_HeaderHovered] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 0.6 };
    colors[c.ImGuiCol_HeaderActive] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 0.50 };
    colors[c.ImGuiCol_Separator] = c.ImVec4{ .x = 0.14, .y = 0.16, .z = 0.11, .w = 1.00 };
    colors[c.ImGuiCol_SeparatorHovered] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 1.00 };
    colors[c.ImGuiCol_SeparatorActive] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_ResizeGrip] = c.ImVec4{ .x = 0.19, .y = 0.23, .z = 0.18, .w = 0.00 }; // grip invis
    colors[c.ImGuiCol_ResizeGripHovered] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 1.00 };
    colors[c.ImGuiCol_ResizeGripActive] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_Tab] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_TabHovered] = c.ImVec4{ .x = 0.54, .y = 0.57, .z = 0.51, .w = 0.78 };
    colors[c.ImGuiCol_TabSelected] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    // colors[c.ImGuiCol_TabUnfocused] = c.ImVec4{ .x = 0.24, .y = 0.27, .z = 0.20, .w = 1.00 };
    // colors[c.ImGuiCol_TabUnfocusedActive] = c.ImVec4{ .x = 0.35, .y = 0.42, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_DockingPreview] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_DockingEmptyBg] = c.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.20, .w = 1.00 };
    colors[c.ImGuiCol_PlotLines] = c.ImVec4{ .x = 0.61, .y = 0.61, .z = 0.61, .w = 1.00 };
    colors[c.ImGuiCol_PlotLinesHovered] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_PlotHistogram] = c.ImVec4{ .x = 1.00, .y = 0.78, .z = 0.28, .w = 1.00 };
    colors[c.ImGuiCol_PlotHistogramHovered] = c.ImVec4{ .x = 1.00, .y = 0.60, .z = 0.00, .w = 1.00 };
    colors[c.ImGuiCol_TextSelectedBg] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_DragDropTarget] = c.ImVec4{ .x = 0.73, .y = 0.67, .z = 0.24, .w = 1.00 };
    colors[c.ImGuiCol_NavHighlight] = c.ImVec4{ .x = 0.59, .y = 0.54, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_NavWindowingHighlight] = c.ImVec4{ .x = 1.00, .y = 1.00, .z = 1.00, .w = 0.70 };
    colors[c.ImGuiCol_NavWindowingDimBg] = c.ImVec4{ .x = 0.80, .y = 0.80, .z = 0.80, .w = 0.20 };
    colors[c.ImGuiCol_ModalWindowDimBg] = c.ImVec4{ .x = 0.80, .y = 0.80, .z = 0.80, .w = 0.35 };

    // ImGuiStyle& style = ImGui::GetStyle();
    style.FrameBorderSize = 1.0;
    style.WindowRounding = 0.0;
    style.ChildRounding = 0.0;
    style.FrameRounding = 0.0;
    style.PopupRounding = 0.0;
    style.ScrollbarRounding = 0.0;
    style.GrabRounding = 0.0;
    style.TabRounding = 0.0;
}

pub fn theme_fluent() void {
    // var io = c.igGetIO();

    // io.Fonts->Clear(); :)
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Light.ttf", 18);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Regular.ttf", 18);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Light.ttf", 32);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Regular.ttf", 14);
    // io.Fonts->AddFontFromFileTTF("fonts/OpenSans-Bold.ttf", 14);
    // io.Fonts->Build();

    var style: *c.ImGuiStyle = @ptrCast(c.igGetStyle());
    var colors = &style.*.Colors;

    // NOTE: you have to use the c allocator bc ImGui will try to free it...
    const dejavu = std.heap.c_allocator.dupe(u8, @embedFile("fonts/DejavuSansMono-5m7L.ttf")) catch unreachable;
    // const dejavu = try std.heap.c_allocator.dupe(u8, @embedFile("fonts/Slugs Racer.ttf"));

    _ = c.ImFontAtlas_AddFontFromMemoryTTF(c.igGetIO().*.Fonts, @ptrCast(dejavu), @intCast(dejavu.len), 16, c.ImFontConfig_ImFontConfig(), null);

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

// const IntDragDrop = struct { "" };

pub fn displayFloat(name: [*c]const u8, data: *anyopaque, dataType: type) bool {
    const cast_data: *align(1) dataType = @ptrCast(@alignCast(data));
    var value: f32 = std.math.lossyCast(f32, cast_data.*);

    if (c.igInputFloat(name, &value, 0, 0, "%1f", c.ImGuiInputTextFlags_EnterReturnsTrue)) {
        cast_data.* = std.math.lossyCast(dataType, value);
        return true;
    }

    return false;
}

pub fn displayInt(name: [*c]const u8, data: *anyopaque, dataType: type) bool {
    const castData: *align(1) dataType = @ptrCast(@alignCast(data));
    var value: c_int = @truncate(@as(i64, @intCast(castData.*)));

    if (c.igInputInt(name, &value, 0, 0, c.ImGuiInputTextFlags_EnterReturnsTrue)) {
        castData.* = std.math.lossyCast(dataType, value);
        return true;
    }

    return false;
}

pub fn displayValue(ValueType: type, comptime name: [:0]const u8, comptime parent_name: [:0]const u8, data: *align(1) ValueType, packet: *tm.Data) void {
    const info = @typeInfo(ValueType);
    const long_name = parent_name ++ name;
    switch (info) {
        .@"struct" => |struct_type| {
            // std.debug.print("struct {s}\n", .{thing.fields});

            // c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x * 2);

            if (c.igTreeNode_Str(name)) {
                c.igPushItemWidth(c.igCalcItemWidth() * 0.8);

                inline for (struct_type.fields) |field| {
                    displayValue(field.type, field.name, long_name ++ ".", @alignCast(&@field(data.*, field.name)), packet);
                }
                c.igPopItemWidth();
                c.igTreePop();
            }
        },
        .array => |array_type| {
            // std.debug.print("array type: {}", .{array_type});
            if (c.igTreeNode_Str(name)) {
                c.igPushItemWidth(c.igCalcItemWidth() * 0.8);
                inline for (0..array_type.len) |i| {
                    displayValue(array_type.child, std.fmt.comptimePrint("{}", .{i}), long_name ++ ".", &data[i], packet);
                }
                c.igPopItemWidth();
                c.igTreePop();
            }
        }, //:)
        .@"enum" => |_| {
            // const thing =  catch blk: {
            //     std.debug.print("INVALIDD VALUE\n", .{});
            //     break :blk @as(ValueType, @enumFromInt(0));
            // };

            // std.debug.print("thing: {}\n", .{thing});
            const tagName = if (std.meta.intToEnum(ValueType, @intFromEnum(data.*))) |_| @tagName(data.*) else |_| "INVALID";

            c.igTextUnformatted(tagName, tagName[tagName.len]);
            c.igSameLine(0.0, c.igGetStyle().*.ItemInnerSpacing.x);
            // // c.igDataTypeFormatString(buf: [*c]u8, buf_size: c_int, data_type: ImGuiDataType, p_data: ?*const anyopaque, format: [*c]const u8)
            if (displayInt("##" ++ name, @ptrCast(data), @TypeOf(@intFromEnum(data.*)))) packet.queued = true;
        },
        .int => {
            if (displayInt("##" ++ name, data, ValueType)) packet.queued = true;
        },
        .float => {
            if (displayFloat("##" ++ name, data, ValueType)) packet.queued = true;
        },
        .bool => {
            const ptr: *bool = @ptrCast(@alignCast(data));
            const val: f32 = @floatFromInt(@as(*u8, @ptrCast(@alignCast(data))).*);
            if (c.igColorButton(
                "##" ++ name,
                c.ImVec4{
                    .x = val,
                    .y = val,
                    .z = val,
                    .w = val,
                },
                0,
                c.ImVec2{ .x = c.igGetFrameHeight() * 2, .y = c.igGetFrameHeight() },
            )) {
                ptr.* = !ptr.*;
                packet.queued = true;
            }
        },
        else => {
            c.igTextUnformatted(name, name.ptr + name.len);
        },
    }

    switch (info) {
        .int, .float, .bool => {
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

pub fn list(comptime TelometerInstance: type, instance: *TelometerInstance) void {
    const state = struct {
        var updatesDecay = std.mem.zeroes([TelometerInstance.count]f32);
    };
    if (c.igBegin("data", null, 0)) {}

    inline for (@typeInfo(TelometerInstance.Struct).@"struct".fields, 0..) |packetType, i| {
        const packet: *tm.Data = &instance.packet_struct[i];

        state.updatesDecay[i] *= 0.99;

        if (packet.received) {
            state.updatesDecay[i] = 1;
        }

        c.igPushID_Int(@intCast(i));
        defer c.igPopID();

        if (c.igColorButton(
            "Updated?",
            c.ImVec4{
                .x = 0.1,
                .y = 0.9 * state.updatesDecay[i],
                .z = 0.05,
                .w = state.updatesDecay[i],
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

pub const PlotData = struct {
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

pub const PlotValue = union(enum) {
    f64: *align(1) f64,
    f32: *align(1) f32,
    u8: *align(1) u8,
    i8: *align(1) i8,
    u16: *align(1) u16,
    i16: *align(1) i16,
    u32: *align(1) u32,
    i32: *align(1) i32,
    u64: *align(1) u64,
    i64: *align(1) i64,
    c_int: *align(1) c_int,
    bool: *align(1) bool,

    pub fn get_float(self: PlotValue) f64 {
        return switch (self) {
            inline else => |s| {
                const info = @typeInfo(@typeInfo(@TypeOf(s)).pointer.child);
                switch (info) {
                    .float => {
                        return @floatCast(s.*);
                    },
                    .int => {
                        return @floatFromInt(s.*);
                    },
                    .bool => {
                        return @floatFromInt(@intFromBool(s.*));
                    },
                    else => unreachable,
                }
            },
        };
    }
};

pub const Plot = struct {
    const Self = @This();
    paused: bool,
    data_pointers: std.ArrayList(PlotData),
    data_pointers2: std.ArrayList(PlotData),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .paused = false,
            .data_pointers = std.ArrayList(PlotData).init(allocator),
            .data_pointers2 = std.ArrayList(PlotData).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn cleanup(self: *Self) void {
        for (self.data_pointers.items) |pointer| {
            pointer.data.deinit();
        }
        self.data_pointers.deinit();
        for (self.data_pointers2.items) |pointer| {
            pointer.data.deinit();
        }
        self.data_pointers2.deinit();
    }

    pub fn update(self: *Self) void {
        const current_time: f64 = @as(f64, @floatFromInt(std.time.microTimestamp())) / 1e6;

        if (c.igBegin("Plot", null, 0)) {
            if (c.ImPlot_BeginPlot("test", c.ImVec2{ .x = -1, .y = -50 }, 0)) {
                c.ImPlot_SetupAxes("Time", "", 0, 0);
                c.ImPlot_SetupAxis(c.ImAxis_Y2, "", c.ImPlotAxisFlags_Opposite);

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

                if (c.ImPlot_BeginDragDropTargetAxis(c.ImAxis_Y2)) {
                    if (c.igAcceptDragDropPayload("f32", c.ImGuiDragDropFlags_None)) |payload| {
                        self.data_pointers2.append(@as(*PlotData, @ptrCast(@alignCast(payload.*.Data))).*) catch unreachable;
                        self.data_pointers2.items[self.data_pointers2.items.len - 1].initData(self.allocator, current_time);
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

                c.ImPlot_SetAxes(c.ImAxis_X1, c.ImAxis_Y2);
                for (self.data_pointers2.items) |*data| {
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

pub const Plot3d = struct {
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

    pub fn drawPoint(self: Self, point: mat.Vec3f, color: c.ImU32, size: f32) void {
        // const transformSpace = mat.Mat(4, 1, f32).new(.{ point.d, 1 });
        const cameraSpacePoint = self.cameraTransform.mul(mat.Mat(4, 1, f32).new(.{ point.d[0], point.d[1], point.d[2], 1 }));

        const screenSpacePoint = self.toScreenSpace(mat.Vec4f.new(cameraSpacePoint.m));
        c.ImDrawList_AddCircleFilled(self.drawList, .{ .x = screenSpacePoint.d[0], .y = screenSpacePoint.d[1] }, size, color, 0);
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
