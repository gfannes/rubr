const std = @import("std");

pub const Pipe = struct {
    const Self = @This();
    const reader_vtable: std.Io.Reader.VTable = .{
        .stream = stream,
        .rebase = rebase,
    };
    const writer_vtable: std.Io.Writer.VTable = .{
        .drain = drain,
    };

    reader: std.Io.Reader,
    writer: std.Io.Writer,

    pub fn init(buffer: []u8) Self {
        return Self{ .reader = .{
            .vtable = &reader_vtable,
            .buffer = buffer,
            .seek = 0,
            .end = 0,
        }, .writer = .{
            .vtable = &writer_vtable,
            .buffer = buffer,
        } };
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    fn stream(r: *std.Io.Reader, _: *std.Io.Writer, limit: std.Io.Limit) !usize {
        std.debug.print("r seek {} end {} limit {?}\n", .{ r.seek, r.end, limit.toInt() });

        const pipe: *Pipe = @fieldParentPtr("reader", r);
        std.debug.print("before {f}", .{pipe.*});

        if (pipe.writer.end > r.end) {
            // There was data written into the pipe that we can return.
            r.end = pipe.writer.end;
            std.debug.print("after {f}", .{pipe.*});
            return 0;
        }

        // &todo: wait for more data

        return error.ReadFailed;
    }

    fn rebase(r: *std.Io.Reader, capacity: usize) !void {
        _ = capacity;

        if (r.seek > 0) {
            const pipe: *Pipe = @fieldParentPtr("reader", r);
            std.debug.print("rebase() before {f}", .{pipe});
            pipe.rebase_();
            std.debug.print("rebase() after {f}", .{pipe});
        }
    }
    fn rebase_(self: *Self) void {
        const src = self.reader.buffer[self.reader.seek..self.writer.end];
        @memmove(self.reader.buffer[0..src.len], src);

        self.reader.end -= self.reader.seek;
        self.writer.end -= self.reader.seek;
        self.reader.seek = 0;
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
        const pipe: *Pipe = @fieldParentPtr("writer", w);

        std.debug.print("drain() before {f}", .{pipe});

        pipe.rebase_();

        var eaten: usize = 0;

        var room = w.buffer.len - w.end;
        for (data[0 .. data.len - 1]) |part| {
            std.debug.print("    part {}\n", .{part.len});
            const n = @min(room, part.len);
            @memcpy(w.buffer[w.end .. w.end + n], part[0..n]);
            w.end += n;
            room -= n;
            eaten += n;
            if (room == 0)
                break;
        }

        for (0..splat) |_| {
            const part = data[data.len - 1];
            std.debug.print("    PART {}\n", .{part.len});
            const n = @min(room, part.len);
            @memcpy(w.buffer[w.end .. w.end + n], part[0..n]);
            w.end += n;
            room -= n;
            eaten += n;
            if (room == 0)
                break;
        }

        std.debug.print("drain() after {f}", .{pipe});

        return eaten;
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print(
            \\[Pipe]{{
            \\    [Writer](end:{})
            \\    [Reader](seek:{})(end:{})
            \\}}
            \\
        , .{ self.writer.end, self.reader.seek, self.reader.end });
    }
};

test "pipe.Pipe" {
    const ut = std.testing;

    var buffer: [4]u8 = undefined;

    var pipe: Pipe = .init(&buffer);
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
