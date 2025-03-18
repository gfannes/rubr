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
    start: Timestamp,

    pub fn init(id: Id) Scope {
        return Scope{ .id = id, .start = Self.now() };
    }
    pub fn deinit(self: Self) void {
        const elapse = now() - self.start;
        measurements[@intFromEnum(self.id)].max = elapse;
        std.debug.print("elapse: {}\n", .{elapse});
    }

    fn now() i128 {
        return std.time.nanoTimestamp();
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
