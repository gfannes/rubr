const std = @import("std");

pub fn is_empty(slice: anytype) bool {
    return slice.len == 0;
}

pub fn first(slice: anytype) ?@TypeOf(slice[0]) {
    return if (slice.len > 0) slice[0] else null;
}
pub fn firstPtr(slice: anytype) ?@TypeOf(&slice[0]) {
    return if (slice.len > 0) &slice[0] else null;
}

pub fn last(slice: anytype) ?@TypeOf(slice[0]) {
    return if (slice.len > 0) slice[slice.len - 1] else null;
}
pub fn lastPtr(slice: anytype) ?@TypeOf(&slice[0]) {
    return if (slice.len > 0) &slice[slice.len - 1] else null;
}

test {
    const ut = std.testing;

    var slice: []const u8 = undefined;

    {
        slice = &.{};
        try ut.expectEqual(true, is_empty(slice));
        try ut.expectEqual(null, first(slice));
        try ut.expectEqual(null, firstPtr(slice));
        try ut.expectEqual(null, last(slice));
        try ut.expectEqual(null, lastPtr(slice));
    }
    {
        slice = "abc";
        try ut.expectEqual(false, is_empty(slice));
        try ut.expectEqual(@as(?u8, 'a'), first(slice));
        try ut.expectEqual(@as(?u8, 'a'), (firstPtr(slice) orelse unreachable).*);
        try ut.expectEqual(@as(?u8, 'c'), last(slice));
        try ut.expectEqual(@as(?u8, 'c'), (lastPtr(slice) orelse unreachable).*);
    }
}
