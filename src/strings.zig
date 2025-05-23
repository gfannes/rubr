const std = @import("std");
const ut = std.testing;

pub const Strings = std.ArrayList([]const u8);

pub fn index(comptime T: type, haystack: []const []const T, needle: []const T) ?usize {
    for (haystack, 0..) |el, ix| {
        if (std.mem.eql(T, needle, el))
            return ix;
    }
    return null;
}

pub fn contains(comptime T: type, haystack: []const []const T, needle: []const T) bool {
    return index(T, haystack, needle) != null;
}

test "index" {
    const haystack = &[_][]const u8{ "abc", "def", "abc" };
    try ut.expectEqual(0, index(u8, haystack, "abc"));
    try ut.expectEqual(1, index(u8, haystack, "def"));
    try ut.expectEqual(null, index(u8, haystack, "ghi"));
}

test "contains" {
    const haystack = &[_][]const u8{ "abc", "def", "abc" };
    try ut.expectEqual(true, contains(u8, haystack, "abc"));
    try ut.expectEqual(true, contains(u8, haystack, "def"));
    try ut.expectEqual(false, contains(u8, haystack, "ghi"));
}
