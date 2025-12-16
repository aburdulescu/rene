const std = @import("std");

const usage =
    \\
    \\Usage: echo [OPTIONS] [ARG]...
    \\
    \\Print the specified ARGs to stdout.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\  -n        don't print trailing newline
    \\  -e        interpret backslash escapes
    \\
;

const Flags = struct {
    print_newline: bool,
    interpret_escapes: bool,
};

pub fn run(_: std.mem.Allocator, stdout: *std.Io.Writer, stderr: *std.Io.Writer, args: [][:0]u8) anyerror!u8 {
    var flags = Flags{
        .print_newline = true,
        .interpret_escapes = false,
    };

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return 0;
        } else if (std.mem.eql(u8, args[i], "-n")) {
            flags.print_newline = false;
        } else if (std.mem.eql(u8, args[i], "-e")) {
            flags.interpret_escapes = true;
        } else if (std.mem.startsWith(u8, args[i], "-") or std.mem.startsWith(u8, args[i], "--")) {
            try stdout.writeAll(usage);
            try stderr.print("error: unknown option '{s}'\n", .{args[i]});
            return 1;
        } else {
            break;
        }
        i += 1;
    }

    if (flags.interpret_escapes) {
        try stderr.print("error: -e is not implemented\n", .{});
        return 1;
    }

    const pos_args = args[i..];
    for (pos_args, 0..) |arg, index| {
        try stdout.print("{s}", .{arg});
        if (index != pos_args.len - 1) {
            _ = try stdout.write(" ");
        }
    }

    if (flags.print_newline) {
        try stdout.print("\n", .{});
    }

    return 0;
}
