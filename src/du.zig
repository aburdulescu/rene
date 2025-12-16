const std = @import("std");

const usage =
    \\
    \\Usage: du [OPTIONS] FILE|DIRECTORY...
    \\
    \\Summarize disk usage for the given FILE or directory.
    \\If the FILE is not specified, '.' will be used.
    \\
    \\OPTIONS:
    \\  --help    print this message and exit
    \\  -b        print sizes in bytes
    \\  -l        list sorted by size
    \\
;

const Flags = struct {
    print_bytes: bool,
    print_list: bool,
};

var flags = Flags{
    .print_bytes = false,
    .print_list = false,
};

pub fn run(allocator: std.mem.Allocator, stdout: *std.Io.Writer, stderr: *std.Io.Writer, args: [][:0]u8) anyerror!u8 {
    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return 0;
        } else if (std.mem.eql(u8, args[i], "-b")) {
            flags.print_bytes = true;
        } else if (std.mem.eql(u8, args[i], "-l")) {
            flags.print_list = true;
        } else if (std.mem.startsWith(u8, args[i], "-") or std.mem.startsWith(u8, args[i], "--")) {
            try stdout.writeAll(usage);
            try stderr.print("error: unknown option '{s}'\n", .{args[i]});
            return 1;
        } else {
            break;
        }
        i += 1;
    }

    const pos_args = args[i..];
    if (pos_args.len == 0) {
        try stderr.print("error: file or directory not specified\n", .{});
        return 1;
    }

    for (pos_args) |path| {
        if (flags.print_list) {
            const Item = struct {
                path: []const u8,
                size: u128,
            };

            var files = try std.ArrayList(Item).initCapacity(allocator, 100);

            var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
            defer dir.close();

            var total: u128 = 0;

            var it = dir.iterate();
            while (try it.next()) |entry| {
                if (entry.kind == std.fs.File.Kind.sym_link) continue;
                const size = try get_size(allocator, entry.name);
                try files.append(allocator, Item{ .path = entry.name, .size = size });
                total += size;
            }

            const cmp = struct {
                pub fn lessThan(_: void, a: Item, b: Item) bool {
                    return a.size < b.size;
                }
            }.lessThan;
            std.sort.block(Item, files.items, {}, cmp);

            for (files.items) |item| {
                try print(stdout, item.path, item.size);
            }
            try print(stdout, path, total);
        } else {
            const size = try get_size(allocator, path);
            try print(stdout, path, size);
        }
    }

    return 0;
}

fn get_size(allocator: std.mem.Allocator, path: []const u8) !u128 {
    const st = try std.fs.cwd().statFile(path);
    if (st.kind != std.fs.File.Kind.directory) {
        return st.size;
    } else {
        return walk_dir(allocator, path);
    }
}

fn walk_dir(allocator: std.mem.Allocator, dir_path: []const u8) !u128 {
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

    return total;
}

const KB = 1 << 10;
const MB = KB << 10;
const GB = MB << 10;

const sep = "  ";

fn print(stdout: *std.Io.Writer, dir: []const u8, size: u128) !void {
    if (flags.print_bytes) {
        try stdout.print("{d}{s}{s}\n", .{ size, sep, dir });
        return;
    }

    if (size > GB) {
        try stdout.print("{d}G{s}{s}\n", .{ size / GB, sep, dir });
    } else if (size > MB) {
        try stdout.print("{d}M{s}{s}\n", .{ size / MB, sep, dir });
    } else if (size > KB) {
        try stdout.print("{d}K{s}{s}\n", .{ size / KB, sep, dir });
    } else {
        try stdout.print("{d}{s}{s}\n", .{ size, sep, dir });
    }
}
