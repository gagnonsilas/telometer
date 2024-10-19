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

fn glfwErrorCallback(err: c_int, desc: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error {}: {s}\n", .{ err, desc });
}

// const testarr: [3] u8 = {1, 2, 3};

pub fn main() !void {
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

    const window = c.SDL_CreateWindow("Telometer Dashboard", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 800, 600, c.SDL_WINDOW_OPENGL) orelse return error.GLFWCreateWindowFailed;
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

    const dejavu = @embedFile("fonts/DejavuSansMono-5m7L.ttf");
    _ = c.ImFontAtlas_AddFontFromMemoryTTF(io.*.Fonts, @constCast(@ptrCast(dejavu)), dejavu.len, 16, c.ImFontConfig_ImFontConfig(), null);

    c.igStyleColorsDark(null);

    _ = c.ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    defer c.ImGui_ImplSDL2_Shutdown();

    _ = c.ImGui_ImplOpenGL3_Init("#version 410");
    defer c.ImGui_ImplOpenGL3_Shutdown();

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

        if (c.igBegin("test", null, 0)) {}
        c.igEnd();

        c.igShowDemoWindow(null);

        if (c.igBegin("Yippee!", null, 0)) {
            if (c.igButton("Hi Silas!", .{})) {
                running = false;
            }
        }
        c.igEnd();

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
