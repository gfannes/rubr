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
        var print = struct {
            w: *std.Io.Writer,
            prefix: u8 = '[',
            fn value(my: *@This(), n: u8) !void {
                try my.w.print("{c}{}", .{ my.prefix, n });
                my.prefix = ';';
            }
        }{ .w = w };

        try w.writeByte(0x1b);
        if (self.reset) {
            try print.value(0);
        } else {
            if (!self.bold and !self.underline) {
                try print.value(0);
            } else {
                if (self.bold)
                    try print.value(1);
                if (self.underline)
                    try print.value(4);
            }
            if (self.fg) |g|
                try print.value(30 + @intFromEnum(g.color) + @as(u8, @intFromBool(g.intense)) * 60);
            if (self.bg) |g|
                try print.value(40 + @intFromEnum(g.color) + @as(u8, @intFromBool(g.intense)) * 60);
        }
        try w.print("m", .{});
    }
};

test "ansi" {
    std.debug.print("{f}Hello {f}World{f}\n", .{ Style{ .fg = .{ .color = .Green } }, Style{ .fg = .{ .color = .Green, .intense = true }, .bg = .{ .color = .Magenta } }, Style{ .reset = true } });
    std.debug.print("Normal text\n", .{});
}
