const std = @import("std");

pub const Style = struct {
    const Self = @This();
    pub const Ground = struct {
        pub const Color = enum(u8) { Black = 0, Red, Green, Yellow, Blue, Magenta, Cyan, White };
        color: Color,
        intense: bool = false,
    };

    fg: ?Ground = null,
    bg: ?Ground = null,
    bold: bool = false,
    underline: bool = false,
    reset: bool = false,

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.writeByte(0x1b);
        if (self.reset) {
            try w.print("[0", .{});
        } else {
            var prefix: u8 = '[';
            if (!self.bold and !self.underline) {
                try w.print("{c}0", .{prefix});
                prefix = ';';
            } else {
                if (self.bold) {
                    try w.print("{c}1", .{prefix});
                    prefix = ';';
                }
                if (self.underline) {
                    try w.print("{c}4", .{prefix});
                    prefix = ';';
                }
            }
            if (self.fg) |g| {
                const code: u8 = 30 + @intFromEnum(g.color) + @as(u8, @intFromBool(g.intense)) * 60;
                try w.print("{c}{}", .{ prefix, code });
                prefix = ';';
            }
            if (self.bg) |g| {
                const code: u8 = 40 + @intFromEnum(g.color) + @as(u8, @intFromBool(g.intense)) * 60;
                try w.print("{c}{}", .{ prefix, code });
                prefix = ';';
            }
        }
        try w.print("m", .{});
    }
};

test "ansi" {
    std.debug.print("{f}Hello {f}World{f}\n", .{ Style{ .fg = .{ .color = .Green } }, Style{ .fg = .{ .color = .Green, .intense = true }, .bg = .{ .color = .Magenta } }, Style{ .reset = true } });
    std.debug.print("Normal text\n", .{});
}
