const std = @import("std");

const usage =
    \\Usage: touch [OPTIONS] FILE...
    \\
    \\Update the access and modification times of FILEs.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
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
        return;
    }

    for (pos_args) |arg| {
        // TODO:
        // if exists
        //    change atime a mtime
        // else
        //    create

        var file = try std.fs.cwd().createFile(arg, .{});
        file.close();
    }
}
