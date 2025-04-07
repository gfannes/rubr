const std = @import("std");

pub const Range = struct {
    const Self = @This();

    begin: usize = 0,
    end: usize = 0,

    pub fn empty(self: Self) bool {
        return self.begin == self.end;
    }
    pub fn size(self: Self) usize {
        return self.end - self.begin;
    }
};

test "index" {
    const ut = std.testing;

    var r = Range{};
    try ut.expectEqual(true, r.empty());
    try ut.expectEqual(0, r.size());

    r = Range{ .begin = 1, .end = 4 };
    try ut.expectEqual(false, r.empty());
    try ut.expectEqual(3, r.size());

    var ixs = std.ArrayList(usize).init(ut.allocator);
    defer ixs.deinit();
    for (r.begin..r.end) |ix| {
        try ixs.append(ix);
    }
    try ut.expectEqualSlices(usize, &[_]usize{ 1, 2, 3 }, ixs.items);
}
