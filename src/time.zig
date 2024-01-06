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

pub fn run(allocator: std.mem.Allocator, args: [][]const u8) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

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

    // start time
    const start = timer.read();

    const term = try child.spawnAndWait();

    // stop time
    const end = timer.read();

    const exit_status: u8 = switch (term) {
        .Exited => |code| code,
        else => {
            try stderr.print("error: command terminated unexpectedly\n", .{});
            std.process.exit(1);
        },
    };

    const elapsed_time = prettyTime(end - start);

    switch (builtin.os.tag) {
        .linux => {
            const r = child.resource_usage_statistics.rusage.?;

            const usr_time = prettyTime(tvToNs(r.utime));
            const sys_time = prettyTime(tvToNs(r.stime));

            const max_rss: u64 = @intCast(r.maxrss);
            const pretty_max_rss = prettySize(max_rss * 1024);

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
                try stderr.print("\twtime      {d}{s}\n", .{ elapsed_time.value, elapsed_time.unit });
                try stderr.print("\tutime      {d}{s}\n", .{ usr_time.value, usr_time.unit });
                try stderr.print("\tstime      {d}{s}\n", .{ sys_time.value, sys_time.unit });
                try stderr.print("\tmaxrss     {d}{s}\n", .{ pretty_max_rss.value, pretty_max_rss.unit });
                try stderr.print("\tminflt     {d}\n", .{r.minflt});
                try stderr.print("\tmajflt     {d}\n", .{r.majflt});
                try stderr.print("\tinblock    {d}\n", .{r.inblock});
                try stderr.print("\toublock    {d}\n", .{r.oublock});
                try stderr.print("\tnvcsw      {d}\n", .{r.nvcsw});
                try stderr.print("\tnivcsw     {d}\n", .{r.nivcsw});
            } else {
                try stderr.print("real    {d}{s}\n", .{ elapsed_time.value, elapsed_time.unit });
                try stderr.print("user    {d}{s}\n", .{ usr_time.value, usr_time.unit });
                try stderr.print("sys     {d}{s}\n", .{ sys_time.value, sys_time.unit });
            }
        },

        else => @panic("os not supported"),
    }
}

fn tvToNs(tv: std.os.timeval) u64 {
    const s: u64 = @intCast(tv.tv_sec);
    const u: u64 = @intCast(tv.tv_usec);
    return s * std.time.ns_per_s + u * std.time.ns_per_us;
}

const PrettyTime = struct {
    value: f64,
    unit: []const u8,
};

fn prettyTime(v: u64) PrettyTime {
    if (v >= std.time.ns_per_s) {
        const vf: f64 = @floatFromInt(v);
        const df: f64 = @floatFromInt(std.time.ns_per_s);
        return .{ .value = vf / df, .unit = "s" };
    }
    if (v >= std.time.ns_per_ms) {
        const vf: f64 = @floatFromInt(v);
        const df: f64 = @floatFromInt(std.time.ns_per_ms);
        return .{ .value = vf / df, .unit = "ms" };
    }
    if (v >= std.time.ns_per_us) {
        const vf: f64 = @floatFromInt(v);
        const df: f64 = @floatFromInt(std.time.ns_per_us);
        return .{ .value = vf / df, .unit = "us" };
    }
    const vf: f64 = @floatFromInt(v);
    return .{ .value = vf, .unit = "ns" };
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
