const std = @import("std");
const c = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
    @cInclude("cimgui_impl.h");
    @cInclude("cimplot.h");
    @cInclude("GLFW/glfw3.h");
});

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

// const testarr: [3] u8 = {1, 2, 3};

pub fn main() !void {
    _ = c.glfwSetErrorCallback(glfwErrorCallback);
    if (c.glfwInit() == 0) {
        return error.GLFWInitFailed;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 0);

    const window = c.glfwCreateWindow(800, 600, "Telometer Dashboard", null, null) orelse return error.GLFWCreateWindowFailed;
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);

    const ctx = c.igCreateContext(null);
    defer c.igDestroyContext(ctx);

    const io = c.igGetIO();
    io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;
    io.*.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;

    // const dejavu = @embedFile("fonts/DejavuSansMono-5m7L.ttf");

    const dejavu = @embedFile("fonts/Slugs Racer.ttf");
    _ = c.ImFontAtlas_AddFontFromMemoryTTF(io.*.Fonts, @constCast(@ptrCast(dejavu)), dejavu.len, 16, c.ImFontConfig_ImFontConfig(), null);

    c.igStyleColorsDark(null);

    _ = c.ImGui_ImplGlfw_InitForOpenGL(window, true);
    defer c.ImGui_ImplGlfw_Shutdown();

    _ = c.ImGui_ImplOpenGL3_Init("#version 130");
    defer c.ImGui_ImplOpenGL3_Shutdown();

    const clear_color = c.ImVec4{ .x = 0.45, .y = 0.55, .z = 0.60, .w = 1.00 };

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();

        if (c.glfwGetWindowAttrib(window, c.GLFW_ICONIFIED) != 0) {
            std.time.sleep(10 * std.time.ns_per_ms);
            continue;
        }

        c.ImGui_ImplOpenGL3_NewFrame();
        c.ImGui_ImplGlfw_NewFrame();
        c.igNewFrame();

        _ = c.igDockSpaceOverViewport(0, null, 0, c.ImGuiWindowClass_ImGuiWindowClass());

        var thing: bool = true;
        if (c.igBegin("test", @ptrCast(&thing), 0)) {}
        c.igEnd();

        c.igShowDemoWindow(@ptrCast(&thing));

        c.igRender();
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(window, &width, &height);
        c.glViewport(0, 0, width, height);
        c.glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());

        c.glfwSwapBuffers(window);
    }
}
