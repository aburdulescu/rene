const std = @import("std");
const find = @import("./find.zig");
const du = @import("./du.zig");
const cat = @import("./cat.zig");
const echo = @import("./echo.zig");
const basename = @import("./basename.zig");
const dirname = @import("./dirname.zig");
const time = @import("./time.zig");
const rm = @import("./rm.zig");
const touch = @import("./touch.zig");
const ls = @import("./ls.zig");

const usage =
    \\Usage: rene <COMMAND> [OPTIONS]
    \\
    \\COMMANDS:
    \\  find, du, cat, echo, basename, dirname, time, rm, touch, ls
    \\
    \\Run 'rene <command> --help' for details about a specific command.
    \\
    \\
;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var args = try std.process.argsAlloc(arena);

    var cmd = std.fs.path.basename(args[0]);
    args = args[1..];

    // if exe name is a supported cmd name => run it
    if (parseCmd(cmd)) |runner| {
        try runner(arena, args);
        return;
    }

    // otherwise => use next arg
    if (args.len == 0 or
        (args.len > 0 and
        std.mem.eql(u8, args[0], "--help")))
    {
        try stdout.writeAll(usage);
        return;
    }

    cmd = args[0];
    args = args[1..];

    // supported cmd => run it
    if (parseCmd(cmd)) |runner| {
        try runner(arena, args);
        return;
    }

    // unknown cmd
    try stdout.writeAll(usage);
    try stdout.print("error: unknown command '{s}'\n", .{cmd});
    std.process.exit(1);
}

const CmdRunner = *const fn (std.mem.Allocator, [][]const u8) anyerror!void;

fn parseCmd(name: []const u8) ?CmdRunner {
    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, name)) {
            return cmd.runner;
        }
    }
    return null;
}

const Command = struct {
    name: []const u8,
    runner: CmdRunner,
};

const commands = &[_]Command{
    .{ .name = "du", .runner = du.run },
    .{ .name = "find", .runner = find.run },
    .{ .name = "cat", .runner = cat.run },
    .{ .name = "echo", .runner = echo.run },
    .{ .name = "basename", .runner = basename.run },
    .{ .name = "dirname", .runner = dirname.run },
    .{ .name = "time", .runner = time.run },
    .{ .name = "rm", .runner = rm.run },
    .{ .name = "touch", .runner = touch.run },
    .{ .name = "ls", .runner = ls.run },
};
