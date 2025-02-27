const std = @import("std");
const ut = std.testing;

pub fn last(slice: anytype) ?@TypeOf(slice[0]) {
    return if (slice.len > 0) slice[slice.len - 1] else null;
}

test "last" {
    var slice: []const u8 = undefined;

    {
        slice = &.{};
        try ut.expectEqual(null, last(slice));
    }
    {
        slice = "abc";
        try ut.expectEqual(@as(?u8, 'c'), last(slice));
    }
}
