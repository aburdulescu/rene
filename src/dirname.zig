const std = @import("std");

const usage =
    \\Usage: dirname [OPTIONS] [FILE]...
    \\
    \\Strip non-directory suffix from FILEs.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\
    \\
;

pub fn run(_: std.mem.Allocator, args: [][]const u8) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return;
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
        try stderr.print("error: missing operand\n", .{});
        std.process.exit(1);
    }

    for (pos_args) |arg| {
        if (std.mem.eql(u8, arg, "/")) {
            try stdout.print("/\n", .{});
            continue;
        }
        const dir = std.fs.path.dirname(arg) orelse ".";
        try stdout.print("{s}\n", .{dir});
    }
}
