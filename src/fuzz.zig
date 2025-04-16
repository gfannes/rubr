const std = @import("std");

// &todo: Support null distance when a character from needle is not found

pub fn distance(needle: []const u8, haystack: []const u8) f64 {
    if (needle.len == 0 or haystack.len == 0)
        return 0.0;

    var sum: f64 = 0.0;
    var offset: usize = 0;
    for (needle) |ch| {
        if (offset >= haystack.len)
            offset = 0;
        const d = blk: {
            if (std.mem.indexOfScalar(u8, haystack[offset..], ch)) |ix| {
                defer offset += ix + 1;
                break :blk ix;
            } else if (std.mem.indexOfScalar(u8, haystack[0..offset], ch)) |ix| {
                defer offset = ix + 1;
                break :blk haystack.len - offset + ix;
            } else {
                break :blk haystack.len;
            }
        };
        sum += std.math.log2(@as(f64, @floatFromInt(d + 1)));
    }

    return sum / @as(f64, @floatFromInt(needle.len));
}

pub fn max_distance(needle: []const u8, max_haystack_len: usize) f64 {
    if (needle.len == 0)
        return 0.0;
    return std.math.log2(@as(f64, @floatFromInt(max_haystack_len + 1)));
}

test "fuzz" {
    const needle = "abc";
    for (&[_][]const u8{ "abc", "bca", "ab", "axbxc", "", "xxx" }) |str| {
        std.debug.print("{s}: {} {} {}\n", .{ str, distance(needle, str), max_distance(needle, str.len), std.math.exp(-distance(needle, str)) });
    }
}
