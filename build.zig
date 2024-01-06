const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const link_libc = b.option(bool, "link-libc", "Link libc into all executables") orelse false;
    const strip = b.option(bool, "strip", "Omit debug information") orelse switch (optimize) {
        .Debug, .ReleaseSafe => false,
        .ReleaseFast, .ReleaseSmall => true,
    };

    const exe_options = std.Build.ExecutableOptions{
        .name = "rene",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .link_libc = link_libc,
    };

    const exe = b.addExecutable(exe_options);
    exe.strip = strip;
    b.installArtifact(exe);

    const release = b.step("release", "Make a binary release");

    const release_targets = &[_][]const u8{
        "aarch64-linux",
        "x86_64-linux",
        "aarch64-macos",
        "x86_64-macos",
        //"x86_64-windows-gnu",
    };

    for (release_targets) |target_string| {
        var iter = std.mem.splitSequence(u8, target_string, "-");
        const arch = iter.next().?;
        const os = iter.next().?;

        const rel_exe = b.addExecutable(exe_options);
        rel_exe.target = std.zig.CrossTarget.parse(.{
            .arch_os_abi = target_string,
        }) catch unreachable;
        rel_exe.strip = true;
        rel_exe.optimize = if (optimize != .Debug) optimize else .ReleaseSafe;

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}/{s}-{s}-{s}", .{
            @tagName(rel_exe.optimize),
            rel_exe.name,
            os,
            arch,
        });

        release.dependOn(&install.step);
    }
}
