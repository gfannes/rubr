const std = @import("std");

pub const Id = enum {
    A,
    B,
    C,
};

const Timestamp = i128;

const Measurement = struct {
    max: Timestamp = 0,
};

const count = @typeInfo(Id).@"enum".fields.len;
var measurements = [_]Measurement{Measurement{}} ** count;

pub const Scope = struct {
    const Self = @This();

    io: std.Io,

    id: Id,
    start_ts: std.Io.Timestamp,
    w: *std.Io.Writer,

    pub fn init(io: std.Io, id: Id, w: *std.Io.Writer) Scope {
        return Scope{ .io = io, .id = id, .start_ts = std.Io.Clock.now(.real, io), .w = w };
    }
    pub fn deinit(self: Self) void {
        const elapse_ns = self.start_ts.durationTo(self.now()).nanoseconds;
        measurements[@intFromEnum(self.id)].max = elapse_ns;
        const a = @divFloor(elapse_ns, 1_000_000_000);
        const b = elapse_ns - a * 1_000_000_000;
        self.w.print("elapse: {}.{:0>9.9}s\n", .{ a, @as(u64, @intCast(b)) }) catch {};
        self.w.flush() catch {};
    }

    fn now(self: Self) std.Io.Timestamp {
        return std.Io.Clock.now(.real, self.io);
    }
};

test "Scope" {
    const ut = std.testing;

    var aw = std.Io.Writer.Allocating.init(ut.allocator);
    defer aw.deinit();

    {
        const s = Scope.init(ut.io, Id.A, &aw.writer);
        defer s.deinit();

        std.debug.print("Blabla\n", .{});
    }
    std.debug.print("measurement {}\n", .{measurements[@intFromEnum(Id.A)]});

    const str = try aw.toOwnedSlice();
    defer ut.allocator.free(str);
    std.debug.print("output: {s}\n", .{str});
}
