const std = @import("std");

// Only if needle constains upper-case letters, case-sensitive search will happen.
// 'maybe_skip_count' can be used to return the number of characters that could not be matched.
pub fn distance(needle_in: []const u8, haystack_in: []const u8, maybe_skip_count: ?*usize) f64 {
    // We wrap the computation of the total distance in a closure to support closure.indexOf() to take 'case_sensitive' into account
    var closure = struct {
        const Cl = @This();

        case_sensitive: bool = false,
        skip_count: usize = 0,

        fn total_distance(cl: *Cl, haystack: []const u8, needle: []const u8) f64 {
            for (needle) |ch|
                if (std.ascii.isUpper(ch)) {
                    cl.case_sensitive = true;
                    break;
                };

            var sum: f64 = 0.0;
            var offset: usize = 0;
            for (needle) |ch| {
                if (offset >= haystack.len)
                    offset = 0;
                const d = blk: {
                    if (cl.indexOf(haystack[offset..], ch)) |ix| {
                        defer offset += ix + 1;
                        break :blk ix;
                    } else if (cl.indexOf(haystack[0..offset], ch)) |ix| {
                        defer offset = ix + 1;
                        break :blk haystack.len - offset + ix;
                    } else {
                        cl.skip_count += 1;
                        break :blk haystack.len;
                    }
                };
                sum += std.math.log2(@as(f64, @floatFromInt(d + 1)));
            }

            return sum;
        }

        fn indexOf(cl: Cl, slice: []const u8, ch: u8) ?usize {
            return if (cl.case_sensitive)
                std.mem.indexOfScalar(u8, slice, ch)
            else
                std.ascii.indexOfIgnoreCase(slice, (&ch)[0..1]);
        }
    }{};

    const total_distance = closure.total_distance(haystack_in, needle_in);
    if (maybe_skip_count) |v|
        v.* = closure.skip_count;

    return if (needle_in.len > 0) total_distance / @as(f64, @floatFromInt(needle_in.len)) else 0.0;
}

pub fn max_distance(needle: []const u8, max_haystack_len: usize) f64 {
    if (needle.len == 0)
        return 0.0;
    return std.math.log2(@as(f64, @floatFromInt(max_haystack_len + 1)));
}

test "fuzz" {
    const ut = std.testing;

    const needle = "abc";
    for (&[_][]const u8{ "abc", "bca", "ab", "axbxc", "", "xxx" }) |str| {
        std.debug.print("{s}: {} {} {}\n", .{ str, distance(needle, str, null), max_distance(needle, str.len), std.math.exp(-distance(needle, str, null)) });
    }

    var skip_count: usize = undefined;
    _ = distance("abc", "abc", &skip_count);
    try ut.expectEqual(0, skip_count);
    _ = distance("ccc", "abc", &skip_count);
    try ut.expectEqual(0, skip_count);
    _ = distance("axbxc", "abc", &skip_count);
    try ut.expectEqual(2, skip_count);
}
