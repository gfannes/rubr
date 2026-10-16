const std = @import("std");

pub fn isEmpty(slice: anytype) bool {
    return slice.len == 0;
}

pub fn first(slice: anytype) ?@TypeOf(slice[0]) {
    return if (slice.len > 0) slice[0] else null;
}
pub fn firstPtr(slice: anytype) ?@TypeOf(&slice[0]) {
    return if (slice.len > 0) &slice[0] else null;
}
pub fn firstPtrUnsafe(slice: anytype) @TypeOf(&slice[0]) {
    return &slice[0];
}

pub fn last(slice: anytype) ?@TypeOf(slice[0]) {
    return if (slice.len > 0) slice[slice.len - 1] else null;
}
pub fn lastPtr(slice: anytype) ?@TypeOf(&slice[0]) {
    return if (slice.len > 0) &slice[slice.len - 1] else null;
}
pub fn lastPtrUnsafe(slice: anytype) @TypeOf(&slice[0]) {
    return &slice[slice.len - 1];
}

pub fn get(slice: anytype, ix: usize) ?@TypeOf(slice[0]) {
    return if (slice.len > ix) slice[ix] else null;
}

test {
    const ut = std.testing;

    var slice: []const u8 = undefined;

    {
        slice = &.{};
        try ut.expectEqual(true, isEmpty(slice));
        try ut.expectEqual(null, first(slice));
        try ut.expectEqual(null, firstPtr(slice));
        try ut.expectEqual(null, last(slice));
        try ut.expectEqual(null, lastPtr(slice));
        try ut.expectEqual(null, get(slice, 0));
    }
    {
        slice = "abc";
        try ut.expectEqual(false, isEmpty(slice));
        try ut.expectEqual(@as(?u8, 'a'), first(slice));
        try ut.expectEqual(@as(?u8, 'a'), (firstPtr(slice) orelse unreachable).*);
        try ut.expectEqual(@as(?u8, 'c'), last(slice));
        try ut.expectEqual(@as(?u8, 'c'), (lastPtr(slice) orelse unreachable).*);
        try ut.expectEqual(@as(?u8, 'a'), get(slice, 0));
        try ut.expectEqual(@as(?u8, 'b'), get(slice, 1));
        try ut.expectEqual(@as(?u8, 'c'), get(slice, 2));
        try ut.expectEqual(null, get(slice, 3));
    }
}
