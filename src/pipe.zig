const std = @import("std");

pub const Pipe = struct {
    const Self = @This();
    const reader_vtable: std.Io.Reader.VTable = .{
        .stream = stream,
    };
    const writer_vtable: std.Io.Writer.VTable = .{
        .drain = drain,
    };
    const Intern = struct {
        buffer: []u8,
        head: usize = 0,
        len: usize = 0,
        mutex: std.Thread.Mutex = std.Thread.Mutex{},

        fn used(i: *Intern) []const []u8 {
            if (i.len == 0) {
                // Buffer is empty
                // Set head to 0 to optimize placement
                i.head = 0;
                return &.{};
            } else if (i.len == i.buffer.len) {
                // Buffer is full
                return &[_][]u8{i.buffer};
            } else if (i.head + i.len <= i.buffer.len) {
                // Buffer is contiguous
                return &[_][]u8{i.buffer[i.head .. i.head + i.len]};
            } else {
                // Buffer wraps over end
                return &[_][]u8{ i.buffer[i.head..], i.buffer[0 .. i.len - (i.buffer.len - i.head)] };
            }
        }
        fn unused(i: *Intern) []const []u8 {
            if (i.len == 0) {
                // Buffer is empty: unused is the full buffer
                // Set head to 0 to optimize placement
                i.head = 0;
                return &[_][]u8{i.buffer};
            } else if (i.len == i.buffer.len) {
                // Buffer is full: unused is empty
                return &.{};
            } else if (i.head + i.len < i.buffer.len) {
                // Buffer has unused space after
                if (i.head == 0) {
                    // and no unused space in front
                    return &[_][]u8{i.buffer[i.head + i.len ..]};
                } else {
                    // and unused space in front
                    return &[_][]u8{ i.buffer[i.head + i.len ..], i.buffer[0..i.head] };
                }
            } else {
                // Unused buffer is contiguous and runs till i.head
                const len = i.buffer.len - i.len;
                return &[_][]u8{i.buffer[i.head - len .. i.head]};
            }
        }
    };

    writer: std.Io.Writer,
    intern: Intern,
    reader: std.Io.Reader,

    pub fn init(wb: []u8, ib: []u8, rb: []u8) Self {
        return Self{
            .writer = .{
                .vtable = &writer_vtable,
                .buffer = wb,
            },
            .intern = Intern{
                .buffer = ib,
            },
            .reader = .{
                .vtable = &reader_vtable,
                .buffer = rb,
                .seek = 0,
                .end = 0,
            },
        };
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print(
            \\[Pipe]{{
            \\    [Writer](end:{})({s})
            \\    [Intern](head:{})(len:{})
            \\    [Reader](seek:{})(end:{})({s})
            \\}}
            \\
        ,
            .{
                self.writer.end,
                self.writer.buffer[0..self.writer.end],

                self.intern.head,
                self.intern.len,

                self.reader.seek,
                self.reader.end,
                self.reader.buffer[self.reader.seek..self.reader.end],
            },
        );
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
        _ = data;
        _ = splat;

        const pipe: *Pipe = @fieldParentPtr("writer", w);
        var intern = &pipe.intern;

        intern.mutex.lock();
        defer intern.mutex.unlock();

        std.debug.print("drain()> {f}\n", .{pipe.*});
        defer std.debug.print("drain(). {f}\n", .{pipe.*});

        var src = w.buffer[0..w.end];

        // Copy `src` into intern
        for (intern.unused()) |dst| {
            const count = @min(dst.len, src.len);
            @memcpy(dst[0..count], src[0..count]);
            intern.len += count;
            src = src[count..];
        }

        // Move the remainder to the front, if any
        if (src.len > 0) {
            @memmove(w.buffer[0..src.len], src);
        }
        w.end = src.len;

        return 0;
    }

    fn stream(r: *std.Io.Reader, _: *std.Io.Writer, limit: std.Io.Limit) !usize {
        _ = limit;

        const pipe: *Pipe = @fieldParentPtr("reader", r);
        var intern = &pipe.intern;

        intern.mutex.lock();
        defer intern.mutex.unlock();

        std.debug.print("stream()> {f}\n", .{pipe.*});
        defer std.debug.print("stream(). {f}\n", .{pipe.*});

        var dst = r.buffer[r.end..];

        // Copy internal data to r.buffer
        for (intern.used()) |src| {
            const count = @min(dst.len, src.len);
            @memcpy(dst[0..count], src[0..count]);
            dst = dst[count..];
            r.end += count;
            intern.head += count;
            intern.len -= count;
        }
        if (intern.head >= intern.buffer.len) {
            intern.head -= intern.buffer.len;
        }

        return 0;
    }
};

test "pipe.Pipe" {
    const ut = std.testing;

    var wb: [4]u8 = undefined;
    var ib: [4]u8 = undefined;
    var rb: [4]u8 = undefined;

    var pipe: Pipe = .init(&wb, &ib, &rb);
    defer pipe.deinit();

    try pipe.writer.print("ab", .{});
    std.debug.print("{f}", .{pipe});
    try pipe.writer.flush();
    std.debug.print("{f}", .{pipe});
    try ut.expectEqual('a', try pipe.reader.takeByte());
    // try ut.expectEqual('b', try pipe.reader.takeByte());

    // try pipe.writer.print("cd", .{});
    // try ut.expectEqual('c', try pipe.reader.takeByte());
    // try ut.expectEqual('d', try pipe.reader.takeByte());

    // try pipe.writer.print("e", .{});
    // try ut.expectEqual('e', try pipe.reader.takeByte());
}
