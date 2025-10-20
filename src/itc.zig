const std = @import("std");

pub const Pipe = struct {
    const Self = @This();

    pub const Writer = struct {
        const vtable: std.Io.Writer.VTable = .{
            .drain = drain,
        };

        interface: std.Io.Writer,
        fn init(buffer: []u8) Writer {
            return Writer{ .interface = .{ .buffer = buffer, .vtable = &vtable } };
        }

        fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
            if (w.end > 0) {
                std.debug.print("buffer: {s}\n", .{w.buffer[0..w.end]});
                w.end = 0;
            }

            var eaten: usize = 0;

            for (data, 0..) |part, ix0| {
                const ix1 = ix0 + 1;
                const my_splat = if (ix1 == data.len) splat else 1;
                for (0..my_splat) |splat_ix0| {
                    eaten += part.len;
                    std.debug.print("part {d}-{d}: {s}\n", .{ ix0, splat_ix0, part });
                }
            }

            return eaten;
        }
    };
    pub const Reader = struct {
        interface: std.Io.Reader,
    };

    buffer: []u8 = undefined,

    pub fn init(buffer: []u8) Self {
        return Self{ .buffer = buffer };
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn writer(self: *Self, buffer: []u8) Writer {
        _ = self;
        return Writer.init(buffer);
    }
};

test "itc.Pipe" {
    var io_buf: [16]u8 = undefined;

    var pipe: Pipe = .init(&io_buf);
    defer pipe.deinit();

    var w_buf: [4]u8 = undefined;
    var writer = pipe.writer(&w_buf);
    try writer.interface.print("ab", .{});
    try writer.interface.print("cd", .{});
    try writer.interface.print("0123456789", .{});
    try writer.interface.print("cd", .{});
    _ = try writer.interface.splatByte('z', 42);
    try writer.interface.flush();
    std.debug.print("Vlotjes\n", .{});
}
