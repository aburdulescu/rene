const std = @import("std");

const usage =
    \\Usage: rm [OPTIONS] FILE...
    \\
    \\Remove FILEs.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\  -f        ignore nonexistent files
    \\  -r        recurse
    \\
    \\
;

const Flags = struct {
    force: bool,
    recurse: bool,
};

pub fn run(_: std.mem.Allocator, args: [][]const u8) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var flags = Flags{
        .force = false,
        .recurse = false,
    };

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return;
        } else if (std.mem.eql(u8, args[i], "-f")) {
            flags.force = true;
        } else if (std.mem.eql(u8, args[i], "-r")) {
            flags.recurse = true;
        } else if (std.mem.startsWith(u8, args[i], "-") or std.mem.startsWith(u8, args[i], "--")) {
            try stdout.writeAll(usage);
            try stderr.print("error: unknown option '{s}'\n", .{args[i]});
            std.process.exit(1);
        } else {
            break;
        }
        i += 1;
    }

    const pos_args = args[i..];

    if (pos_args.len == 0) {
        try stdout.writeAll(usage);
        return;
    }

    var got_error = false;

    for (pos_args) |arg| {
        if (flags.recurse) {
            if (!flags.force) {
                std.fs.cwd().access(arg, .{}) catch |err| switch (err) {
                    error.FileNotFound => {
                        try stderr.print("rm: '{s}' does not exist\n", .{arg});
                        got_error = true;
                        continue;
                    },
                    else => |e| return e,
                };
            }
            try std.fs.cwd().deleteTree(arg);
        } else {
            std.fs.cwd().deleteFile(arg) catch |err| switch (err) {
                error.FileNotFound => {
                    if (!flags.force) {
                        try stderr.print("rm: '{s}' does not exist\n", .{arg});
                        got_error = true;
                    }
                },
                error.IsDir => {
                    try stderr.print("rm: '{s}' is a directory\n", .{arg});
                    got_error = true;
                },
                else => |e| return e,
            };
        }
    }

    if (got_error) {
        std.process.exit(1);
    }
}
