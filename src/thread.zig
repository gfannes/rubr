const std = @import("std");
const Env = @import("Env.zig");

// For now, Job contains the data to work on and how to work on it.
// Maybe that should be split into Data and Worker oneday.
// Job should be a POD: no lifetime management and byte-copy.
pub fn Pool(Job: type) type {
    return struct {
        pub const Self = @This();

        env: Env,

        queue_buffer: std.ArrayList(Job) = .empty,
        queue: std.Io.Queue(Job) = undefined,
        threads: std.ArrayList(std.Thread) = .empty,

        do_log: bool = false,

        pub const Options = struct {
            size: ?usize = null,
        };
        pub fn init(self: *Self, options: Options) !void {
            const size = options.size orelse try std.Thread.getCpuCount();

            try self.queue_buffer.resize(self.env.a, size);
            self.queue = .init(self.queue_buffer.items);

            try self.threads.resize(self.env.a, size);
            for (self.threads.items, 0..) |*thrd, ix0| {
                thrd.* = try std.Thread.spawn(.{}, worker, .{ self, ix0 });
            }
        }
        pub fn deinit(self: *Self) void {
            self.queue.close(self.env.io);

            for (self.threads.items) |thrd| {
                thrd.join();
            }
            self.threads.deinit(self.env.a);

            self.queue_buffer.deinit(self.env.a);
        }

        pub fn append(self: *Self, job: Job) !void {
            try self.queue.putOne(self.env.io, job);
        }

        fn worker(self: *Self, ix: usize) !void {
            if (self.do_log)
                std.debug.print("thread.Pool.worker {} starting\n", .{ix});

            var iteration: u64 = 0;
            while (true) {
                if (self.queue.getOne(self.env.io)) |job| {
                    if (self.do_log)
                        std.debug.print("thread.Pool.worker {}-{} found job {f}\n", .{ ix, iteration, job });

                    try job.call();
                } else |err| {
                    if (self.do_log)
                        std.debug.print("thread.Pool.worker {}-{} {}\n", .{ ix, iteration, err });
                    if (err == error.Closed)
                        return;
                    return err;
                }

                iteration += 1;
            }

            if (self.do_log)
                std.debug.print("thread.Pool.worker {} stopping\n", .{ix});
        }
    };
}

test "thread.Pool" {
    const ut = std.testing;
    const env = Env.for_ut();

    var sum: i32 = 0;
    var mutex: std.Io.Mutex = .init;

    const Job = struct {
        const Self = @This();

        env: Env,
        i: i32,
        sum: *i32,
        mutex: *std.Io.Mutex,

        fn call(self: Self) !void {
            try self.mutex.lock(self.env.io);
            defer self.mutex.unlock(self.env.io);
            self.sum.* += self.i;
        }
        pub fn format(self: Self, w: *std.Io.Writer) !void {
            try w.print("[Job](i:{})", .{self.i});
        }
    };

    var exp_sum: i32 = 0;
    {
        var pool: Pool(Job) = .{ .env = env };
        try pool.init(.{});
        defer pool.deinit();

        for (0..100) |i| {
            try pool.append(.{ .env = env, .i = @intCast(i), .sum = &sum, .mutex = &mutex });
            exp_sum += @intCast(i);
        }
    }

    try ut.expectEqual(exp_sum, sum);
}
