const std = @import("std");

pub fn print(w: *std.Io.Writer, comptime fmt_str: []const u8, args: anytype) !void {
    try w.print(fmt_str, args);
    try w.flush();
}
