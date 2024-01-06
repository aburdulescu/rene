const std = @import("std");

const usage =
    \\Usage: find [OPTIONS] [DIRECTORY]
    \\
    \\Search for files in a DIRECTORY.
    \\If the DIRECTORY is not specified, '.' will be used.
    \\
    \\OPTIONS:
    \\  --help              print this message and exit
    \\  -t, --type [d,f]    type of file to search for: d=directory, f=file
    \\  -h, --hidden        ignore hidden files
    \\
    \\
;

const Flags = struct {
    type: ?[]const u8,
    ignore_hidden: bool,
};

pub fn run(allocator: std.mem.Allocator, args: [][]const u8) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var flags = Flags{
        .type = null,
        .ignore_hidden = false,
    };

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return;
        } else if (std.mem.eql(u8, args[i], "-t") or std.mem.eql(u8, args[i], "--type")) {
            if (i + 1 == args.len) {
                try stderr.print("error: -t needs a value\n", .{});
                std.process.exit(1);
            }
            flags.type = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "-h") or std.mem.eql(u8, args[i], "--hidden")) {
            flags.ignore_hidden = true;
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

    var dir_path: []const u8 = undefined;

    switch (pos_args.len) {
        0 => dir_path = ".",
        1 => dir_path = pos_args[0],
        else => {
            try stdout.writeAll(usage);
            try stderr.print("error: cannot handle more than one directory\n", .{});
            std.process.exit(1);
        },
    }

    var file_type: std.fs.File.Kind = std.fs.File.Kind.unknown;
    if (flags.type) |v| {
        if (std.mem.eql(u8, v, "d")) {
            file_type = std.fs.File.Kind.directory;
        } else if (std.mem.eql(u8, v, "f")) {
            file_type = std.fs.File.Kind.file;
        } else {
            try stderr.print(
                "error: '{any}' is not a valid value for -t flag\n",
                .{v},
            );
            std.process.exit(1);
        }
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    // print root dir if directories can be printed(i.e. -t is "" or "d")
    const should_print_root =
        (file_type == std.fs.File.Kind.unknown or file_type == std.fs.File.Kind.directory);
    if (should_print_root) {
        try stdout.print("{s}\n", .{dir_path});
    }

    // use a FixedBufferAllocator for joining paths
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buf[0..]);

    while (try walker.next()) |entry| {
        // TODO: don't stop if error happens for a path, print error and go on
        if (std.mem.startsWith(u8, entry.basename, ".") and flags.ignore_hidden) {
            continue;
        }
        if (file_type != std.fs.File.Kind.unknown and entry.kind != file_type) {
            continue;
        }
        const full_path = try std.fs.path.join(fba.allocator(), &[_][]const u8{
            dir_path, entry.path,
        });
        try stdout.print("{s}\n", .{full_path});
        fba.reset();
    }
}
