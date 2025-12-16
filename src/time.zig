const std = @import("std");
const builtin = @import("builtin");

const usage =
    \\Usage: time [OPTIONS] PROG [ARG]...
    \\
    \\Run PROG and display resource usage when it exits
    \\
    \\OPTIONS:
    \\  -v    Print all available resources
    \\
;

const Flags = struct {
    verbose: bool,
};

pub fn run(allocator: std.mem.Allocator, stdout: *std.Io.Writer, stderr: *std.Io.Writer, args: [][:0]u8) anyerror!void {
    switch (builtin.os.tag) {
        .linux, .macos => {},
        else => {
            @panic("OS not supported");
        },
    }

    var flags = Flags{
        .verbose = false,
    };

    var i: usize = 0;
    while (i < args.len) {
        if (std.mem.eql(u8, args[i], "--help")) {
            try stdout.writeAll(usage);
            return;
        } else if (std.mem.eql(u8, args[i], "-v")) {
            flags.verbose = true;
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

    var child = std.process.Child.init(pos_args, allocator);
    child.request_resource_usage_statistics = true;

    var timer = std.time.Timer.start() catch @panic("need timer to work");

    const start = timer.read();
    const term = try child.spawnAndWait();
    const end = timer.read();

    const exit_status: u8 = switch (term) {
        .Exited => |code| code,
        else => {
            try stderr.print("error: command terminated unexpectedly\n", .{});
            std.process.exit(1);
        },
    };

    const wall_time = end - start;

    const max_rss = child.resource_usage_statistics.getMaxRss().?;
    const pretty_max_rss = prettySize(max_rss);

    const r = child.resource_usage_statistics.rusage.?;

    const usr_time = tvToNs(r.utime);
    const sys_time = tvToNs(r.stime);

    if (flags.verbose) {
        try stderr.print("\tcmd        \"", .{});
        for (0.., pos_args) |index, arg| {
            if (index == pos_args.len - 1) {
                try stderr.print("{s}\"\n", .{arg});
            } else {
                try stderr.print("{s} ", .{arg});
            }
        }
        try stderr.print("\trc         {d}\n", .{exit_status});
        try stderr.print("\twtime      {D}\n", .{wall_time});
        try stderr.print("\tutime      {D}\n", .{usr_time});
        try stderr.print("\tstime      {D}\n", .{sys_time});
        try stderr.print("\tmaxrss     {d}{s}\n", .{ pretty_max_rss.value, pretty_max_rss.unit });
        try stderr.print("\tminflt     {d}\n", .{r.minflt});
        try stderr.print("\tmajflt     {d}\n", .{r.majflt});
        try stderr.print("\tinblock    {d}\n", .{r.inblock});
        try stderr.print("\toublock    {d}\n", .{r.oublock});
        try stderr.print("\tnvcsw      {d}\n", .{r.nvcsw});
        try stderr.print("\tnivcsw     {d}\n", .{r.nivcsw});
    } else {
        try stderr.print("{D} wall {D} user {D} system\n", .{ wall_time, usr_time, sys_time });
    }
}

fn tvToNs(tv: std.c.timeval) u64 {
    const s: u64 = @intCast(tv.sec);
    const u: u64 = @intCast(tv.usec);
    return s * std.time.ns_per_s + u * std.time.ns_per_us;
}

const PrettySize = struct {
    value: f64,
    unit: []const u8,
};

const kb = 1024.0;
const mb = 1024.0 * kb;
const gb = 1024.0 * mb;

fn prettySize(v: u64) PrettySize {
    if (v >= gb) {
        const vf: f64 = @floatFromInt(v);
        return .{ .value = vf / gb, .unit = "gb" };
    }
    if (v >= mb) {
        const vf: f64 = @floatFromInt(v);
        return .{ .value = vf / mb, .unit = "mb" };
    }
    if (v >= kb) {
        const vf: f64 = @floatFromInt(v);
        return .{ .value = vf / kb, .unit = "kb" };
    }
    const vf: f64 = @floatFromInt(v);
    return .{ .value = vf, .unit = "bytes" };
}
