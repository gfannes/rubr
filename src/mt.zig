const std = @import("std");

// A pool of workers, each with their own job queue.
// Jobs can generate more jobs.
// Workers that run out of jobs from their own job queue steal work from others.
pub const Runner = struct {
    pub const Self = @This();

    a: std.mem.Allocator,
    io: std.Io,

    state: State = undefined,
    workers: std.ArrayList(Worker) = .empty,

    pub fn init(self: *Self, worker_count: usize) !void {
        self.state = .{ .io = self.io };
        try self.workers.resize(self.a, worker_count);
        for (self.workers.items, 0..) |*worker, ix0| {
            try worker.init(self.a, ix0, &self.state);
        }
    }
    pub fn deinit(self: *Self) void {
        self.state.quit() catch {};
        for (self.workers.items) |*worker| {
            worker.deinit();
        }
        self.workers.deinit(self.a);
    }

    pub fn start(self: *Self) !void {
        try self.state.start();
    }
};

const State = struct {
    const Self = @This();

    const Value = enum { Idle, Running, Quit };

    io: std.Io,

    value: Value = .Idle,

    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,

    fn run(self: *Self) !bool {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        while (true)
            switch (self.value) {
                .Running => return true,
                .Quit => return false,
                else => try self.cond.wait(self.io, &self.mutex),
            };
    }

    fn start(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        switch (self.value) {
            .Quit => return,
            .Running => return,
            else => {
                self.value = .Running;
                self.cond.broadcast(self.io);
            },
        }
    }
    fn stop(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        switch (self.value) {
            .Quit => return,
            .Idle => return,
            else => {
                self.value = .Idle;
                try self.cond.broadcast(self.io);
            },
        }
    }
    fn quit(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        self.value = .Quit;
        self.cond.broadcast(self.io);
    }
};

const Job = struct {};

const Worker = struct {
    const Self = @This();

    a: std.mem.Allocator,
    ix0: usize,
    state: *State,
    thread: std.Thread,
    jobs: std.Deque(Job),

    fn init(self: *Self, a: std.mem.Allocator, ix0: usize, state: *State) !void {
        self.a = a;
        self.ix0 = ix0;
        self.state = state;
        self.thread = try std.Thread.spawn(.{}, Worker.function, .{self});
        self.jobs = .empty;
    }
    fn deinit(self: *Self) void {
        self.thread.join();
        self.jobs.deinit(self.a);
    }

    fn function(self: *Self) !void {
        while (try self.state.run()) {
            std.debug.print("Worker {}\n", .{self.ix0});
        }
    }
};

test "mt" {
    const ut = std.testing;

    var runner = Runner{ .a = ut.allocator, .io = ut.io };
    try runner.init(4);
    defer runner.deinit();
    try runner.start();
}
