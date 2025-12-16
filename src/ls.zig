const std = @import("std");

const usage =
    \\Usage: ls [OPTIONS] [FILE]...
    \\
    \\List directory contents.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\  -1        print on one line
    \\  -a        include hidden files
    \\
;

const Flags = struct {
    print_hidden: bool,
    print_one_line: bool,
};

var flags = Flags{
    .print_hidden = false,
    .print_one_line = false,
};

pub fn run(_: std.mem.Allocator, stdout: *std.Io.Writer, stderr: *std.Io.Writer, args: [][:0]u8) anyerror!void {
    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.print(usage, .{});
            return;
        }
        if (std.mem.eql(u8, args[i], "-a")) {
            flags.print_hidden = true;
        } else if (std.mem.eql(u8, args[i], "-1")) {
            flags.print_one_line = true;
        } else if (std.mem.startsWith(u8, args[i], "-") or std.mem.startsWith(u8, args[i], "--")) {
            try stdout.print(usage, .{});
            try stderr.print("error: unknown option '{s}'\n", .{args[i]});
            std.process.exit(1);
        } else {
            break;
        }
        i += 1;
    }

    const pos_args = args[i..];

    if (pos_args.len == 0) {
        try listDir(stdout, ".");
    }

    for (pos_args) |arg| {
        if (pos_args.len > 1) {
            try stdout.print("{s}:\n", .{arg});
        }
        try listDir(stdout, arg);
        if (pos_args.len > 1) {
            try stdout.print("\n", .{});
        }
    }
}

fn listDir(stdout: *std.Io.Writer, path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, ".")) {
            if (flags.print_hidden) {
                try printFile(stdout, entry);
            }
        } else {
            try printFile(stdout, entry);
        }
    }

    if (flags.print_one_line) {
        try stdout.print("\n", .{});
    }
}

fn printFile(stdout: *std.Io.Writer, entry: std.fs.Dir.Entry) !void {
    try stdout.print("{s}", .{entry.name});
    if (flags.print_one_line) {
        try stdout.print("  ", .{});
    } else {
        try stdout.print("\n", .{});
    }
}
