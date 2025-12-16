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

pub fn run(_: std.mem.Allocator, stdout: *std.Io.Writer, stderr: *std.Io.Writer, args: [][:0]u8) anyerror!void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

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
        try copy(stdout, stdin);
        return;
    }

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var file_reader_buf: [8192]u8 = undefined;

    for (pos_args) |path| {
        if (std.mem.eql(u8, args[i], "-")) {
            try copy(stdout, stdin);
            continue;
        }

        const real_path = try std.fs.realpath(path, &path_buffer);
        const file = try std.fs.openFileAbsolute(real_path, .{});
        defer file.close();

        var file_reader = file.reader(&file_reader_buf);
        try copy(stdout, &file_reader.interface);
    }
}

fn copy(writer: *std.Io.Writer, reader: *std.Io.Reader) !void {
    _ = writer;
    _ = reader;
    // TODO: implement this by hand or find std fn
    return error.NotImplemented;
}
