const std = @import("std");

pub const Error = error{
    NotRunning,
    StillRunning,
    IxOutOfRange,
    NameMismatch,
};

pub fn now(io: std.Io) std.Io.Timestamp {
    return std.Io.Clock.now(.real, io);
}

const Timestamp = i128;

const Measurement = struct {
    pub const Self = @This();

    name: ?[]const u8 = null,
    sum: Timestamp = 0,
    max: Timestamp = 0,
};

const Descriptor = struct {
    ix: usize,
    name: ?[]const u8 = null,
};

pub const Scope = struct {
    const Self = @This();

    const max_measurement_count: usize = 16;

    io: std.Io,

    ix: usize,
    start_ts: std.Io.Timestamp,

    measurements: [max_measurement_count]?Measurement = @splat(null),
    running: bool = true,

    pub fn start(io: std.Io, desc: Descriptor) !Self {
        var rv: Self = .{ .io = io, .ix = desc.ix, .start_ts = now(io) };
        try rv.setup(desc);
        return rv;
    }

    pub fn stop(self: *Self) !void {
        try self.mark(.{ .ix = self.ix });
        self.running = false;
    }

    pub fn mark(self: *Self, desc: Descriptor) !void {
        if (!self.running)
            return error.NotRunning;

        const now_ts = now(self.io);

        var m = self.measurements[self.ix].?;
        {
            const elapse_ns = self.start_ts.durationTo(now_ts).nanoseconds;
            m.sum += elapse_ns;
            m.max = @max(m.max, elapse_ns);
        }
        self.measurements[self.ix] = m;

        try self.setup(desc);
        self.ix = desc.ix;
        self.start_ts = now_ts;
    }

    pub fn measurement(self: Self, ix: usize) !?Measurement {
        if (self.running)
            return error.StillRunning;
        return self.measurements[ix];
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        for (0..max_measurement_count) |ix| {
            if (self.measurements[ix]) |m| {
                try w.print("[Measurement]", .{});
                const Local = struct {
                    fn print(ts: Timestamp, desc: []const u8, ww: *std.Io.Writer) !void {
                        const a = @divFloor(ts, 1_000_000_000);
                        const b = ts - a * 1_000_000_000;
                        try ww.print("({s}:{}.{:0>9.9}s)", .{ desc, a, @as(u64, @intCast(b)) });
                    }
                };
                try Local.print(m.sum, "sum", w);
                try Local.print(m.max, "max", w);
                if (m.name) |name|
                    try w.print("(name:{s})", .{name});
                try w.print("(ix:{})\n", .{ix});
                try w.flush();
            }
        }
    }

    fn setup(self: *Self, desc: Descriptor) !void {
        if (desc.ix >= max_measurement_count)
            return error.IxOutOfRange;

        if (self.measurements[desc.ix]) |*m| {
            if (desc.name) |name| {
                if (m.name) |m_name| {
                    if (!std.mem.eql(u8, name, m_name))
                        return error.NameMismatch;
                } else {
                    m.name = name;
                }
            }
        } else {
            self.measurements[desc.ix] = Measurement{ .name = desc.name };
        }
    }
};

test "Scope" {
    const ut = std.testing;

    {
        var s = try Scope.start(ut.io, .{ .ix = 0 });
        std.debug.print("0\n", .{});
        try s.mark(.{ .ix = 1 });
        std.debug.print("1\n", .{});
        try s.mark(.{ .ix = 0, .name = "all" });
        std.debug.print("0\n", .{});
        try s.stop();

        std.debug.print("{f}\n", .{s});
    }
}
