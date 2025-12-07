const std = @import("std");

pub const Style = struct {
    const Self = @This();

    pub const Color = enum(u8) { Black = 0, Red, Green, Yellow, Blue, Magenta, Cyan, White };
    pub const Intensity = enum(u8) { Low = 0, High = 60 };

    fgc: ?Color = null,
    fgi: Intensity = .Low,

    bgc: ?Color = null,
    bgi: Intensity = .Low,

    reset: bool = false,

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.writeByte(0x1b);
        if (self.reset) {
            try w.print("[0", .{});
        } else {
            var prefix: u8 = '[';
            if (self.fgc) |fgc| {
                const code: u8 = 30 + @intFromEnum(fgc) + @intFromEnum(self.fgi);
                try w.print("{c}{}", .{ prefix, code });
                prefix = ';';
            }
            if (self.bgc) |bgc| {
                const code: u8 = 40 + @intFromEnum(bgc) + @intFromEnum(self.bgi);
                try w.print("{c}{}", .{ prefix, code });
                prefix = ';';
            }
        }
        try w.print("m", .{});
    }
};

test "ansi" {
    std.debug.print("{f}Hello {f}World{f}\n", .{ Style{ .fgc = .Green }, Style{ .fgc = .Green, .fgi = .High, .bgc = .Magenta }, Style{ .reset = true } });
    std.debug.print("Normal text\n", .{});
}
