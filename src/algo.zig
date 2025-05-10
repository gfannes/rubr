const std = @import("std");

pub fn anyOf(T: type, slice: []const T, predicate: anytype) bool {
    for (slice) |el|
        if (predicate.call(el))
            return true;
    return false;
}

pub fn allOf(T: type, slice: []const T, predicate: anytype) bool {
    for (slice) |el|
        if (!predicate.call(el))
            return false;
    return true;
}

pub fn countIf(T: type, slice: []const T, predicate: anytype) usize {
    var count: usize = 0;
    for (slice) |el| {
        if (predicate.call(el))
            count += 1;
    }
    return count;
}

test "algo" {
    const ut = std.testing;

    const values = [_]u32{ 1, 3, 4, 6 };

    const even = struct {
        fn call(_: @This(), v: u32) bool {
            return v % 2 == 0;
        }
    }{};

    try ut.expectEqual(true, anyOf(u32, &values, even));
    try ut.expectEqual(false, allOf(u32, &values, even));
    try ut.expectEqual(2, countIf(u32, &values, even));
}
