const std = @import("std");

pub const Error = error{
    NotRunning,
    StillRunning,
};

pub fn now(io: std.Io) std.Io.Timestamp {
    return std.Io.Clock.now(.real, io);
}

const Timestamp = i128;

const Measurement = struct {
    pub const Self = @This();

    sum: Timestamp = 0,
    max: Timestamp = 0,

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print("[Measurement]", .{});
        try format_(self.sum, "sum", w);
        try format_(self.max, "max", w);
        try w.flush();
    }
    fn format_(ts: Timestamp, desc: []const u8, w: *std.Io.Writer) !void {
        const a = @divFloor(ts, 1_000_000_000);
        const b = ts - a * 1_000_000_000;
        try w.print("({s}:{}.{:0>9.9}s)", .{ desc, a, @as(u64, @intCast(b)) });
    }
};

pub const Scope = struct {
    const Self = @This();

    pub const Id = enum { A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z };

    const count = @typeInfo(Id).@"enum".fields.len;

    io: std.Io,

    id: Id,
    start_ts: std.Io.Timestamp,

    // &todo: Rework into optional measurements to support reporting of only the observed data
    measurements: [count]Measurement = [_]Measurement{Measurement{}} ** count,
    running: bool = true,

    pub fn start(io: std.Io, id: Id) Self {
        return .{ .io = io, .id = id, .start_ts = now(io) };
    }

    pub fn stop(self: *Self) !void {
        try self.mark(self.id);
        self.running = false;
    }

    pub fn mark(self: *Self, id: Id) !void {
        if (!self.running)
            return error.NotRunning;

        const now_ts = now(self.io);
        const elapse_ns = self.start_ts.durationTo(now_ts).nanoseconds;
        const m = &self.measurements[@intFromEnum(self.id)];
        m.sum += elapse_ns;
        m.max = @max(m.max, elapse_ns);

        self.id = id;
        self.start_ts = now_ts;
    }

    pub fn measurement(self: Self, id: Id) !Measurement {
        if (self.running)
            return error.StillRunning;
        return self.measurements[@intFromEnum(id)];
    }
};

test "Scope" {
    const ut = std.testing;

    {
        var s = Scope.start(ut.io, .A);
        std.debug.print("A\n", .{});
        try s.mark(.B);
        std.debug.print("B\n", .{});
        try s.mark(.A);
        std.debug.print("A\n", .{});
        try s.stop();

        std.debug.print("A {f}\n", .{try s.measurement(.A)});
        std.debug.print("B {f}\n", .{try s.measurement(.B)});
    }
}
