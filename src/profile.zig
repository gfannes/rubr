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
    w: *std.Io.Writer,

    pub fn init(id: Id, w: *std.Io.Writer) Scope {
        return Scope{ .id = id, .start = Self.now(), .w = w };
    }
    pub fn deinit(self: Self) void {
        const elapse = now().since(self.start);
        measurements[@intFromEnum(self.id)].max = elapse;
        const a = @divFloor(elapse, 1_000_000_000);
        const b = elapse - a * 1_000_000_000;
        self.w.print("elapse: {}.{:0>9.9}s\n", .{ a, @as(u64, @intCast(b)) }) catch {};
        self.w.flush() catch {};
    }

    fn now() std.time.Instant {
        return std.time.Instant.now() catch @panic("Cannot get current time");
    }
};

test "Scope" {
    const ut = std.testing;

    var aw = std.Io.Writer.Allocating.init(ut.allocator);
    defer aw.deinit();

    {
        const s = Scope.init(Id.A, &aw.writer);
        defer s.deinit();

        std.debug.print("Blabla\n", .{});
    }
    std.debug.print("measurement {}\n", .{measurements[@intFromEnum(Id.A)]});

    const str = try aw.toOwnedSlice();
    defer ut.allocator.free(str);
    std.debug.print("output: {s}\n", .{str});
}
