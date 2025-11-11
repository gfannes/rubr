const std = @import("std");

pub const Iso = struct {
    const T = u128;

    v: T,
    nano: bool = false,

    pub fn format(self: @This(), w: *std.Io.Writer) !void {
        if (self.nano)
            try self.format_(w, 1_000_000_000_000_000_000, &[_][]const u8{ "G", "M", "k", "_", "m", "u", "n" })
        else
            try self.format_(w, 1_000_000_000_000, &[_][]const u8{ "T", "G", "M", "k", "" });
    }
    pub fn format_(self: @This(), w: *std.Io.Writer, dd: T, postfixes: []const []const u8) !void {
        var d = dd;

        var v = self.v;
        var first: bool = true;
        for (postfixes, 0..) |postfix, ix0| {
            const last = ix0 + 1 == postfixes.len;

            const n = v / d;
            const r = v % d;

            if (n > 0 or !first or last) {
                if (first)
                    try w.print("{}{s}", .{ n, postfix })
                else
                    try w.print("{:0>3}{s}", .{ n, postfix });
                first = false;
            }

            v = r;
            d /= 1000;
        }
    }
};

pub fn iso(v: anytype, nano: bool) Iso {
    return .{
        .v = @intCast(v),
        .nano = nano,
    };
}

test "fmt.Iso" {
    const ut = std.testing;

    var aa = std.heap.ArenaAllocator.init(ut.allocator);
    defer aa.deinit();
    const a = aa.allocator();

    const Scn = struct {
        v: u128,
        nano: bool,
        exp: []const u8,
    };

    const scns = [_]Scn{
        .{ .v = 0, .nano = false, .exp = "0" },
        .{ .v = 1, .nano = false, .exp = "1" },
        .{ .v = 1_000, .nano = false, .exp = "1k000" },
        .{ .v = 1_234_567_890, .nano = false, .exp = "1G234M567k890" },
        .{ .v = 1_000_000_000_000, .nano = false, .exp = "1T000G000M000k000" },
        .{ .v = 0, .nano = true, .exp = "0n" },
        .{ .v = 1, .nano = true, .exp = "1n" },
        .{ .v = 1_000, .nano = true, .exp = "1u000n" },
    };
    for (&scns) |scn| {
        var sink = std.Io.Writer.Allocating.init(a);
        try sink.writer.print("{f}", .{iso(scn.v, scn.nano)});
        const str = try sink.toOwnedSlice();
        try ut.expectEqualStrings(scn.exp, str);
    }
}
