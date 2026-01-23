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
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
            data: [2][]u8 = undefined,

        fn isEmpty(i: @This()) bool {
            return i.len == 0;
        }
        fn is_full(i: @This()) bool {
            return i.len == i.buffer.len;
        }

        fn first(i: @This()) []const u8 {
            const len = @min(i.len, i.buffer.len - i.head);
            return i.buffer[i.head .. i.head + len];
        }
        fn second(i: @This()) []const u8 {
            const end = i.head + i.len;
            if (end <= i.buffer.len)
                return &.{};
            const len = end - i.buffer.len;
            return i.buffer[0..len];
        }
        fn used(i: *Intern) []const []u8 {
            if (i.len == 0) {
                // Buffer is empty
                // Set head to 0 to optimize placement
                i.head = 0;
                    return i.data[0..0];
            } else if (i.len == i.buffer.len) {
                // Buffer is full
                    i.data[0] = i.buffer;
                    return i.data[0..1];
            } else if (i.head + i.len <= i.buffer.len) {
                // Buffer is contiguous
                    i.data[0] = i.buffer[i.head .. i.head + i.len];
                    return i.data[0..1];
            } else {
                // Buffer wraps over end
                    i.data[0] = i.buffer[i.head..];
                    i.data[1] = i.buffer[0 .. i.len - (i.buffer.len - i.head)];
                    return i.data[0..2];
            }
        }
        fn unused(i: *Intern) []const []u8 {
            if (i.len == 0) {
                // Buffer is empty: unused is the full buffer
                // Set head to 0 to optimize placement
                i.head = 0;
                    i.data[0] = i.buffer;
                    return i.data[0..1];
            } else if (i.len == i.buffer.len) {
                // Buffer is full: unused is empty
                    return i.data[0..0];
            } else if (i.head + i.len < i.buffer.len) {
                // Buffer has unused space after
                if (i.head == 0) {
                    // and no unused space in front
                        i.data[0] = i.buffer[i.head + i.len ..];
                        return i.data[0..1];
                } else {
                    // and unused space in front
                        i.data[0] = i.buffer[i.head + i.len ..];
                        i.data[1] = i.buffer[0..i.head];
                        return i.data[0..2];
                }
            } else {
                // Unused buffer is contiguous and runs till i.head
                const len = i.buffer.len - i.len;
                    i.data[0] = i.buffer[i.head - len .. i.head];
                    return i.data[0..1];
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
            \\    [Writer](end:{}){{{s}}}
            \\    [Intern](head:{})(len:{}){{{s}{s}}}
            \\    [Reader](seek:{})(end:{}){{{s}}}
            \\}}
            \\
        ,
            .{
                self.writer.end,
                self.writer.buffer[0..self.writer.end],

                self.intern.head,
                self.intern.len,
                self.intern.first(),
                self.intern.second(),

                self.reader.seek,
                self.reader.end,
                self.reader.buffer[self.reader.seek..self.reader.end],
            },
        );
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
        _ = splat;

        const p: *Pipe = @fieldParentPtr("writer", w);
        var intern = &p.intern;

        const copy_from_buffer = w.end > 0;
        var src = if (copy_from_buffer) w.buffer[0..w.end] else data[0];
        const orig_src_len = src.len;

        {
            intern.mutex.lock();
            defer intern.mutex.unlock();

            while (intern.is_full()) {
                intern.cond.wait(&intern.mutex);
            }

            // Copy `src` into intern
            for (intern.unused()) |dst| {
                const count = @min(dst.len, src.len);
                @memcpy(dst[0..count], src[0..count]);
                intern.len += count;
                src = src[count..];
            }

            if (copy_from_buffer) {
                // Move the remainder to the front, if any
                if (src.len > 0) {
                    @memmove(w.buffer[0..src.len], src);
                }
                w.end = src.len;
            }
        }

        intern.cond.signal();

        return if (copy_from_buffer) 0 else orig_src_len - src.len;
    }

    fn stream(r: *std.Io.Reader, _: *std.Io.Writer, limit: std.Io.Limit) !usize {
        _ = limit;

        const p: *Pipe = @fieldParentPtr("reader", r);
        var intern = &p.intern;

        {
            intern.mutex.lock();
            defer intern.mutex.unlock();

            while (intern.isEmpty()) {
                intern.cond.wait(&intern.mutex);
            }

            if (r.seek == r.end) {
                // All buffered data was read: reset the internal pointers to maximize read buffer size
                r.seek = 0;
                r.end = 0;
            }

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
        }

        intern.cond.signal();

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
    try pipe.writer.flush();
    try ut.expectEqual('a', try pipe.reader.takeByte());
    try ut.expectEqual('b', try pipe.reader.takeByte());

    try pipe.writer.print("cd", .{});
    try pipe.writer.flush();
    try ut.expectEqual('c', try pipe.reader.takeByte());
    try ut.expectEqual('d', try pipe.reader.takeByte());

    try pipe.writer.print("e", .{});
    try pipe.writer.flush();
    try ut.expectEqual('e', try pipe.reader.takeByte());
    std.debug.print("{f}", .{pipe});
}

test "pipe.Pipe threading" {
    // const ut = std.testing;

    var wb: [4]u8 = undefined;
    var ib: [4]u8 = undefined;
    var rb: [4]u8 = undefined;

    const Ctx = struct {
        const alphabet = "abcdefghijklmnopqrstuvwxyz";
        pipe: Pipe,
        fn producer(ctx: *@This()) !void {
            std.debug.print("producer()>\n", .{});
            defer std.debug.print("producer().\n", .{});
            try ctx.pipe.writer.print("{s}", .{alphabet});
            try ctx.pipe.writer.flush();
        }
        fn consumer(ctx: *@This()) !void {
            std.debug.print("consumer()>\n", .{});
            defer std.debug.print("consumer().\n", .{});
            for (0..26) |_| {
                std.debug.print("{}", .{try ctx.pipe.reader.takeByte()});
            }
        }
    };
    var ctx = Ctx{ .pipe = Pipe.init(&wb, &ib, &rb) };
    defer ctx.pipe.deinit();

    var prod: std.Thread = try .spawn(.{}, Ctx.producer, .{&ctx});
    defer prod.join();

    var cons: std.Thread = try .spawn(.{}, Ctx.consumer, .{&ctx});
    defer cons.join();
}
