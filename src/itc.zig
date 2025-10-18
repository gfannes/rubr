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
            _ = w;
            _ = data;
            _ = splat;

            return 0;
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
    try writer.interface.print("writing data", .{});
    std.debug.print("Vlotjes\n", .{});
    try std.testing.expect(false);
}
