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

    id: Id,
    start: std.time.Instant,

    pub fn init(id: Id) Scope {
        return Scope{ .id = id, .start = Self.now() };
    }
    pub fn deinit(self: Self) void {
        const elapse = now().since(self.start);
        measurements[@intFromEnum(self.id)].max = elapse;
        const a = @divFloor(elapse, 1_000_000_000);
        const b = elapse - a * 1_000_000_000;
        std.debug.print("elapse: {}.{:0>9.9}s\n", .{ a, @as(u64, @intCast(b)) });
    }

    fn now() std.time.Instant {
        return std.time.Instant.now() catch @panic("Cannot get current time");
    }
};

test "Scope" {
    {
        const s = Scope.init(Id.A);
        defer s.deinit();

        std.debug.print("Blabla\n", .{});
    }
    std.debug.print("measurement {}\n", .{measurements[@intFromEnum(Id.A)]});
}
