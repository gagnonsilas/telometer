const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const imgui_dep = b.dependency("imgui", .{});
    const dear_bindings_dep = b.dependency("dear_bindings", .{});

    const dear_bindings_py = dear_bindings_dep.path("dear_bindings.py");

    const imgui_lib = b.addStaticLibrary(.{ .name = "imgui_zig", .target = target, .optimize = optimize });

    if (std.fs.openFileAbsolute(b.path("generated/cimgui.h").getPath(b), .{}) == error.FileNotFound) {
        const generate_main_bindings = b.addSystemCommand(&.{"python"});
        generate_main_bindings.addFileArg(dear_bindings_py);
        generate_main_bindings.addArgs(&.{ "-o", "generated/cimgui" });
        generate_main_bindings.addFileArg(imgui_dep.path("imgui.h"));

        imgui_lib.step.dependOn(&generate_main_bindings.step);
    }

    if (std.fs.openFileAbsolute(b.path("generated/cimgui_impl_glfw.h").getPath(b), .{}) == error.FileNotFound) {
        const generate_glfw_backend_bindings = b.addSystemCommand(&.{"python"});
        generate_glfw_backend_bindings.addFileArg(dear_bindings_py);
        generate_glfw_backend_bindings.addArg("--backend");
        generate_glfw_backend_bindings.addArg("--imconfig-path");
        generate_glfw_backend_bindings.addFileArg(imgui_dep.path("imconfig.h"));
        generate_glfw_backend_bindings.addArgs(&.{ "-o", "generated/cimgui_impl_glfw" });
        generate_glfw_backend_bindings.addFileArg(imgui_dep.path("backends/imgui_impl_glfw.h"));

        imgui_lib.step.dependOn(&generate_glfw_backend_bindings.step);
    }

    if (std.fs.openFileAbsolute(b.path("generated/cimgui_impl_opengl3.h").getPath(b), .{}) == error.FileNotFound) {
        const generate_opengl_backend_bindings = b.addSystemCommand(&.{"python"});
        generate_opengl_backend_bindings.addFileArg(dear_bindings_py);
        generate_opengl_backend_bindings.addArg("--backend");
        generate_opengl_backend_bindings.addArg("--imconfig-path");
        generate_opengl_backend_bindings.addFileArg(imgui_dep.path("imconfig.h"));
        generate_opengl_backend_bindings.addArgs(&.{ "-o", "generated/cimgui_impl_opengl3" });
        generate_opengl_backend_bindings.addFileArg(imgui_dep.path("backends/imgui_impl_opengl3.h"));

        imgui_lib.step.dependOn(&generate_opengl_backend_bindings.step);
    }

    imgui_lib.addCSourceFiles(.{ .root = b.path("generated"), .files = &.{ "cimgui.cpp", "cimgui_impl_glfw.cpp", "cimgui_impl_opengl3.cpp" } });
    imgui_lib.addCSourceFiles(.{ .root = imgui_dep.path(""), .files = &.{ "imgui.cpp", "imgui_demo.cpp", "imgui_draw.cpp", "imgui_tables.cpp", "imgui_widgets.cpp" } });
    imgui_lib.addCSourceFiles(.{ .root = imgui_dep.path("backends"), .files = &.{ "imgui_impl_glfw.cpp", "imgui_impl_opengl3.cpp" } });

    imgui_lib.addIncludePath(b.path("generated"));
    imgui_lib.addIncludePath(imgui_dep.path(""));
    imgui_lib.addIncludePath(imgui_dep.path("backends"));

    imgui_lib.linkLibCpp();
    imgui_lib.linkLibC();
    imgui_lib.linkSystemLibrary("glfw");

    b.installArtifact(imgui_lib);

    const exe = b.addExecutable(.{
        .name = "dear_imgui_zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkLibrary(imgui_lib);
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("glfw");

    exe.addIncludePath(imgui_dep.path(""));
    exe.addIncludePath(b.path("generated"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
