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

// Type-safe index to work with 'pointers into a slice'
pub fn Ix(T: type) type {
    return struct {
        const Self = @This();

        ix: usize = 0,

        pub fn init(ix: usize) Self {
            return Self{ .ix = ix };
        }

        pub fn get(self: Self, slice: []T) ?*T {
            if (self.ix >= slice.len)
                return null;
            return &slice[self.ix];
        }
        pub fn cget(self: Self, slice: []const T) ?*const T {
            if (self.ix >= slice.len)
                return null;
            return &slice[self.ix];
        }

        // Unchecked version of get()
        pub fn ptr(self: Self, slice: []T) *T {
            return &slice[self.ix];
        }
        pub fn cptr(self: Self, slice: []const T) *const T {
            return &slice[self.ix];
        }
    };
}

test "index.Ref" {
    const ut = std.testing;

    var data = [_]i64{ 0, 1, 2 };

    const I = Ix(i64);

    try ut.expectEqual(&data[0], (I{ .ix = 0 }).get(&data));
    try ut.expectEqual(&data[0], (I{ .ix = 0 }).ptr(&data));
    try ut.expectEqual(&data[1], (I{ .ix = 1 }).get(&data));
    try ut.expectEqual(&data[1], (I{ .ix = 1 }).ptr(&data));
    try ut.expectEqual(&data[2], (I{ .ix = 2 }).get(&data));
    try ut.expectEqual(&data[2], (I{ .ix = 2 }).ptr(&data));
    try ut.expectEqual(null, (I{ .ix = 3 }).get(&data));
}

test "index.Range" {
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
