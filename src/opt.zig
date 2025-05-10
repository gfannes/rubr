const std = @import("std");

pub fn value(x: anytype) ?@TypeOf(x) {
    return x;
}
pub fn none(T: type) ?T {
    return null;
}

test "opt" {
    const ut = std.testing;

    const ch: u8 = 'a';
    try ut.expectEqual(@as(?u8, 'a'), value(ch));
    try ut.expectEqual(null, none(u8));
}
