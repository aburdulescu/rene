const std = @import("std");

const usage =
    \\Usage: basename [OPTIONS] [FILE]...
    \\
    \\Strip directory and suffix from FILEs.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\  -s        remove trailing suffix
    \\
    \\
;

const Flags = struct {
    suffix: ?[]const u8,
};

pub fn run(_: std.mem.Allocator, args: [][:0]u8) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var flags = Flags{
        .suffix = null,
    };

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return;
        } else if (std.mem.eql(u8, args[i], "-s")) {
            if (i + 1 == args.len) {
                try stderr.print("error: -s needs a value\n", .{});
                std.process.exit(1);
            }
            flags.suffix = args[i + 1];
            i += 1;
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
        var base = std.fs.path.basename(arg);
        if (flags.suffix != null) {
            base = std.mem.trimRight(u8, base, flags.suffix.?);
        }
        try stdout.print("{s}\n", .{base});
    }
}
