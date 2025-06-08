const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    comptime {
        const needed = "0.14.0";
        const current = builtin.zig_version;
        const needed_vers = std.SemanticVersion.parse(needed) catch unreachable;
        if (current.order(needed_vers) != .eq) {
            @compileError(std.fmt.comptimePrint("Your zig version is not supported, need version {s}", .{needed}));
        }
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const link_libc = b.option(bool, "link-libc", "Link libc into all executables") orelse false;
    const strip = b.option(bool, "strip", "Omit debug information") orelse switch (optimize) {
        .Debug, .ReleaseSafe => false,
        .ReleaseFast, .ReleaseSmall => true,
    };

    const exe_opts = std.Build.ExecutableOptions{
        .name = "rene",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .strip = strip,
        .link_libc = link_libc,
    };

    const exe = b.addExecutable(exe_opts);
    b.installArtifact(exe);

    const release = b.step("release", "Make a binary release");
    const release_targets = [_]std.Target.Query{
        .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
        },
        .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
        },
        .{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
        },
        .{
            .cpu_arch = .x86_64,
            .os_tag = .macos,
        },
    };

    for (release_targets) |target_query| {
        const resolved_target = b.resolveTargetQuery(target_query);
        const t = resolved_target.result;

        var rel_exe_opts = exe_opts;
        rel_exe_opts.strip = true;
        rel_exe_opts.target = resolved_target;
        rel_exe_opts.optimize = if (optimize != .Debug) optimize else .ReleaseSafe;
        const rel_exe = b.addExecutable(rel_exe_opts);

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}/{s}-{s}-{s}", .{
            @tagName(rel_exe_opts.optimize),
            rel_exe.name,
            @tagName(t.os.tag),
            @tagName(t.cpu.arch),
        });

        release.dependOn(&install.step);
    }
}
