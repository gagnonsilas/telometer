const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const imgui_dep = b.dependency("imgui", .{});
    const implot_dep = b.dependency("implot", .{});
    const cimgui_dep = b.dependency("cimgui", .{});
    const cimplot_dep = b.dependency("cimplot", .{});
    const serial_dep = b.dependency("serial", .{ .target = target, .optimize = optimize });
    const telometer_dep = b.dependency("telometer", .{ .target = target, .optimize = optimize });

    const zig_imgui = b.addStaticLibrary(.{
        .name = "zig-imgui",
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(zig_imgui);

    zig_imgui.linkLibC();
    zig_imgui.linkLibCpp();
    zig_imgui.linkSystemLibrary("SDL2");

    zig_imgui.root_module.addCMacro("IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "1");
    zig_imgui.root_module.addCMacro("IMGUI_IMPL_API", "extern \"C\" ");

    // imgui
    zig_imgui.addIncludePath(imgui_dep.path(""));
    zig_imgui.addCSourceFiles(.{
        .root = imgui_dep.path(""),
        .files = &.{
            "imgui.cpp",
            "imgui_demo.cpp",
            "imgui_draw.cpp",
            "imgui_tables.cpp",
            "imgui_widgets.cpp",
        },
    });
    zig_imgui.addCSourceFiles(
        .{
            .root = imgui_dep.path("backends"),
            .files = &.{
                "imgui_impl_opengl3.cpp",
                "imgui_impl_sdl2.cpp",
            },
        },
    );

    // implot
    zig_imgui.addIncludePath(implot_dep.path(""));
    zig_imgui.addCSourceFiles(
        .{
            .root = implot_dep.path(""),
            .files = &.{
                "implot.cpp",
                "implot_demo.cpp",
                "implot_items.cpp",
            },
        },
    );

    // cimgui
    const modify_cimgui_cpp = b.addSystemCommand(&.{"sed"});
    modify_cimgui_cpp.addArgs(&.{
        "-E",
        "s/#include \".\\/imgui\\/([^\"]+)\"/#include <\\1>/",
    });
    modify_cimgui_cpp.addFileArg(cimgui_dep.path("cimgui.cpp"));

    const cimgui_cpp_tmp = modify_cimgui_cpp.captureStdOut();

    const gen_cimgui_cpp = b.addWriteFiles();
    const cimgui_cpp = gen_cimgui_cpp.addCopyFile(cimgui_cpp_tmp, "cimgui.cpp");

    gen_cimgui_cpp.step.dependOn(&modify_cimgui_cpp.step);
    zig_imgui.step.dependOn(&gen_cimgui_cpp.step);

    zig_imgui.addIncludePath(cimgui_dep.path(""));
    zig_imgui.addCSourceFile(.{ .file = cimgui_cpp });
    zig_imgui.installHeader(cimgui_dep.path("cimgui.h"), "cimgui.h");
    zig_imgui.installHeader(cimgui_dep.path("generator/output/cimgui_impl.h"), "cimgui_impl.h");

    // cimplot
    const modify_cimplot_cpp = b.addSystemCommand(&.{"sed"});
    modify_cimplot_cpp.addArgs(&.{
        "-E",
        "s/#include \".\\/implot\\/([^\"]+)\"/#include <\\1>/",
    });
    modify_cimplot_cpp.addFileArg(cimplot_dep.path("cimplot.cpp"));

    const cimplot_cpp_tmp = modify_cimplot_cpp.captureStdOut();

    const gen_cimplot_cpp = b.addWriteFiles();
    const cimplot_cpp = gen_cimplot_cpp.addCopyFile(cimplot_cpp_tmp, "cimplot.cpp");

    gen_cimgui_cpp.step.dependOn(&modify_cimplot_cpp.step);
    zig_imgui.step.dependOn(&gen_cimplot_cpp.step);

    zig_imgui.addIncludePath(cimplot_dep.path(""));
    zig_imgui.addCSourceFile(.{ .file = cimplot_cpp });
    zig_imgui.installHeader(cimplot_dep.path("cimplot.h"), "cimplot.h");

    const exe = b.addExecutable(.{
        .name = "telometer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("telometer", telometer_dep.module("Telometer"));
    exe.root_module.addImport("serial", serial_dep.module("serial"));
    exe.linkSystemLibrary("dbus-1");
    exe.linkLibC();
    // exe.linkLibrary(telometer_dep.artifact("Telometer"));
    b.installArtifact(exe);

    // Native File Dialogue
    const nfd_dependency = b.dependency("nativefiledialog-extended", .{
        .target = target,
        .optimize = optimize,
        .portal = true,
    });
    exe.linkLibrary(nfd_dependency.artifact("nfd"));

    // glad
    const glad = b.addStaticLibrary(.{
        .name = "glad",
        .target = target,
        .optimize = optimize,
    });

    glad.addIncludePath(b.path("glad/include"));
    glad.addCSourceFiles(.{
        .files = &.{"glad/src/glad.c"},
    });

    glad.linkLibC();

    exe.addIncludePath(b.path("glad/include"));
    exe.linkLibrary(glad);
    exe.addIncludePath(b.path("../src"));

    exe.root_module.addCMacro("CIMGUI_USE_SDL2", "");
    exe.root_module.addCMacro("CIMGUI_USE_OPENGL3", "");
    exe.linkLibrary(zig_imgui);
    exe.linkSystemLibrary("SDL2");

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
