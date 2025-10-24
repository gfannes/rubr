const std = @import("std");

pub const Pipe = struct {
    const Self = @This();
    const reader_vtable: std.Io.Reader.VTable = .{
        .stream = stream,
    };
    const writer_vtable: std.Io.Writer.VTable = .{
        .drain = drain,
    };

    reader: std.Io.Reader,
    writer: std.Io.Writer,

    pub fn init(rb: []u8, wb: []u8) Self {
        return Self{ .reader = .{
            .vtable = &reader_vtable,
            .buffer = rb,
            .seek = 0,
            .end = 0,
        }, .writer = .{
            .vtable = &writer_vtable,
            .buffer = wb,
        } };
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print(
            \\[Pipe]{{
            \\    [Writer](end:{})({s})
            \\    [Reader](seek:{})(end:{})({s})
            \\}}
            \\
        , .{ self.writer.end, self.writer.buffer[0..self.writer.end], self.reader.seek, self.reader.end, self.reader.buffer[self.reader.seek..self.reader.end] });
    }

    fn stream(r: *std.Io.Reader, _: *std.Io.Writer, limit: std.Io.Limit) !usize {
        _ = limit;

        const pipe: *Pipe = @fieldParentPtr("reader", r);

        std.debug.print("stream()> {f}\n", .{pipe.*});
        defer std.debug.print("stream(). {f}\n", .{pipe.*});

        _ = pipe.move_data_();

        return 0;
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
        _ = data;
        _ = splat;

        const pipe: *Pipe = @fieldParentPtr("writer", w);

        std.debug.print("drain()> {f}\n", .{pipe.*});
        defer std.debug.print("drain(). {f}\n", .{pipe.*});

        _ = pipe.move_data_();

        return 0;
    }

    fn move_data_(pipe: *Self) usize {
        if (pipe.writer.end == 0)
            return 0;
        // We have data in the write buffer that we can move into the read buffer

        var r = &pipe.reader;
        var w = &pipe.writer;
        const re = r.end;
        const we = w.end;
        const count = @min(r.buffer.len - re, we);

        if (count == 0)
            return 0;
        // We can move 'count' bytes from writer to reader=

        std.debug.print("move_data_()> count {}\n", .{count});
        defer std.debug.print("move_data_().\n", .{});

        const src = w.buffer[0..count];
        const dst = r.buffer[re .. re + count];
        std.debug.print("src {s}\n", .{src});
        @memcpy(dst, src);
        std.debug.print("dst {s}\n", .{dst});

        r.end += count;

        if (count == we) {
            w.end = 0;
        } else {
            const stay = we - count;
            @memmove(w.buffer[0..stay], w.buffer[count..we]);
            w.end = stay;
        }

        return count;
    }
};

test "pipe.Pipe" {
    const ut = std.testing;

    var rb: [4]u8 = undefined;
    var wb: [4]u8 = undefined;

    var pipe: Pipe = .init(&rb, &wb);
    defer pipe.deinit();

    try pipe.writer.print("ab", .{});
    try ut.expectEqual('a', try pipe.reader.takeByte());
    try ut.expectEqual('b', try pipe.reader.takeByte());

    try pipe.writer.print("cd", .{});
    try ut.expectEqual('c', try pipe.reader.takeByte());
    try ut.expectEqual('d', try pipe.reader.takeByte());

    try pipe.writer.print("e", .{});
    try ut.expectEqual('e', try pipe.reader.takeByte());
}
