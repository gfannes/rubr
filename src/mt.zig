const std = @import("std");

// A pool of workers, each with their own job queue.
// Jobs can generate more jobs.
// Workers that run out of jobs from their own job queue steal work from others.
pub const Runner = struct {
    pub const Self = @This();

    a: std.mem.Allocator,
    io: std.Io,

    workers: std.ArrayList(Worker) = .empty,

    pub fn init(self: *Self, worker_count: usize) !void {
        try self.workers.resize(self.a, worker_count);
        for (self.workers.items, 0..) |*worker, ix0| {
            try worker.init(self.a, ix0);
        }
    }
    pub fn deinit(self: *Self) void {
        for (self.workers.items) |*worker| {
            worker.deinit();
        }
        self.workers.deinit(self.a);
    }
};

const Job = struct {};

const Worker = struct {
    const Self = @This();

    a: std.mem.Allocator,
    ix0: usize,
    thread: std.Thread,
    jobs: std.Deque(Job),

    fn init(self: *Self, a: std.mem.Allocator, ix0: usize) !void {
        self.a = a;
        self.ix0 = ix0;
        self.thread = try std.Thread.spawn(.{}, Worker.function, .{self});
        self.jobs = .empty;
    }
    fn deinit(self: *Self) void {
        self.thread.join();
        self.jobs.deinit(self.a);
    }

    fn function(self: *Self) !void {
        std.debug.print("Worker {}\n", .{self.ix0});
    }
};

test "mt" {
    const ut = std.testing;

    var runner = Runner{ .a = ut.allocator, .io = ut.io };
    try runner.init(4);
    defer runner.deinit();
}
