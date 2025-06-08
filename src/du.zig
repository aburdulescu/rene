const std = @import("std");

const usage =
    \\Usage: du [OPTIONS] [FILE]...
    \\
    \\Summarize disk usage for the given FILE or directory.
    \\If the FILE is not specified, '.' will be used.
    \\If no size related option is provided, the size will be printed in kilobytes.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\  -h        print human readable sizes(e.g. 11K 22M 63G)
    \\  -b        print sizes in bytes
    \\
    \\
;

const Flags = struct {
    print_human: bool,
    print_bytes: bool,
    print_total: bool,
};

var flags = Flags{
    .print_bytes = false,
    .print_human = false,
    .print_total = false,
};

pub fn run(allocator: std.mem.Allocator, args: [][:0]u8) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return;
        } else if (std.mem.eql(u8, args[i], "-h")) {
            flags.print_human = true;
        } else if (std.mem.eql(u8, args[i], "-b")) {
            flags.print_bytes = true;
        } else if (std.mem.eql(u8, args[i], "-s")) {
            flags.print_total = true;
        } else if (std.mem.startsWith(u8, args[i], "-") or std.mem.startsWith(u8, args[i], "--")) {
            try stdout.writeAll(usage);
            try stderr.print("error: unknown option '{s}'\n", .{args[i]});
            std.process.exit(1);
        } else {
            break;
        }
        i += 1;
    }

    if (flags.print_bytes and flags.print_human) {
        try stderr.print("error: -b and -h cannot be used at the same time, choose one\n", .{});
        std.process.exit(1);
    }

    const pos_args = args[i..];
    if (pos_args.len == 0) {
        try walk_dir(allocator, ".");
    }

    for (pos_args) |path| {
        const st = try std.fs.cwd().statFile(path);
        if (st.kind != std.fs.File.Kind.directory) {
            try print(path, st.size);
        } else {
            try walk_dir(allocator, path);
        }
    }
}

fn walk_dir(allocator: std.mem.Allocator, dir_path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var total: u128 = 0;

    // add root dir size
    {
        const st = try dir.stat();
        total += st.size;
    }

    while (try walker.next()) |entry| {
        if (entry.kind == std.fs.File.Kind.sym_link) continue;
        const st = try entry.dir.statFile(entry.basename);
        total += st.size;
    }

    try print(dir_path, total);
}

const KB = 1 << 10;
const MB = KB << 10;
const GB = MB << 10;

const sep = "  ";

fn print(dir: []const u8, total: u128) !void {
    const stdout = std.io.getStdOut().writer();

    if (flags.print_bytes) {
        try stdout.print("{d}{s}{s}\n", .{ total, sep, dir });
        return;
    }

    if (!flags.print_human) {
        try stdout.print("{d}{s}{s}\n", .{ total / KB, sep, dir });
        return;
    }

    if (total > GB) {
        try stdout.print("{d}G{s}{s}\n", .{ total / GB, sep, dir });
    } else if (total > MB) {
        try stdout.print("{d}M{s}{s}\n", .{ total / MB, sep, dir });
    } else if (total > KB) {
        try stdout.print("{d}K{s}{s}\n", .{ total / KB, sep, dir });
    } else {
        try stdout.print("{d}{s}{s}\n", .{ total, sep, dir });
    }
}
