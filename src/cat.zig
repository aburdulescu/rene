const std = @import("std");

const usage =
    \\Usage: cat [OPTIONS] [FILE]...
    \\
    \\Print FILEs to stdout.
    \\If no FILEs are specified, stdin will be used.
    \\If one of the FILEs is "-", stdin will be used.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\
;

pub fn run(_: std.mem.Allocator, args: [][]const u8) anyerror!void {
    const stdin = std.io.getStdIn().reader();
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
        try copy(stdin, stdout);
        return;
    }

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    for (pos_args) |path| {
        if (std.mem.eql(u8, args[i], "-")) {
            try copy(stdin, stdout);
            continue;
        }

        const real_path = try std.fs.realpath(path, &path_buffer);
        const file = try std.fs.openFileAbsolute(real_path, .{});
        defer file.close();

        try copy(file.reader(), stdout);
    }
}

fn copy(reader: anytype, writer: anytype) !void {
    var fifo = std.fifo.LinearFifo(u8, .{ .Static = std.mem.page_size }).init();
    try fifo.pump(reader, writer);
}
