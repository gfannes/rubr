const std = @import("std");

pub const Error = error{
    ExpectedIdleState,
    ExpectedRunningState,
    WaitingFailure,
};

// A pool of workers, each with their own job queue.
// Jobs can generate more jobs.
// Workers that run out of jobs from their own job queue steal work from others.
pub const Runner = struct {
    pub const Self = @This();

    a: std.mem.Allocator,
    io: std.Io,

    cox: Cox = undefined,
    workers: std.ArrayList(Worker) = .empty,

    pub fn init(self: *Self, worker_count: usize) !void {
        self.cox = .{ .io = self.io };
        try self.workers.resize(self.a, worker_count);
        for (self.workers.items, 0..) |*worker, ix0| {
            try worker.init(self.a, self.io, ix0, &self.cox);
        }
    }
    pub fn deinit(self: *Self) void {
        self.cox.quit() catch {};
        for (self.workers.items) |*worker| {
            worker.deinit();
        }
        self.workers.deinit(self.a);
    }

    pub fn start(self: *Self, jobs_: []const Job) !void {
        if (!try self.cox.is(.Idle))
            return error.ExpectedIdleState;

        var jobs = jobs_;

        self.cox.job_count = jobs.len;

        while (jobs.len > 0) {
            for (self.workers.items) |*worker| {
                if (jobs.len == 0)
                    break;
                try worker.jobs.pushBack(self.a, jobs[0]);
                jobs = jobs[1..];
            }
        }

        try self.cox.start();
    }

    pub fn stop(self: *Self) !void {
        if (!try self.cox.waitFor(.Done))
            return error.WaitingFailure;
    }
};

// Coxwain: controls the boat
const Cox = struct {
    const Self = @This();

    const State = enum { Idle, Running, Done, Quit };

    io: std.Io,

    state: State = .Idle,
    job_count: u64 = 0,

    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,

    fn is(self: *Self, exp_state: State) !bool {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        return self.state == exp_state;
    }

    fn waitFor(self: *Self, exp_state: State) !bool {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        while (true) {
            if (self.state == .Quit)
                return false;
            if (self.state == exp_state)
                return true;
            try self.cond.wait(self.io, &self.mutex);
        }
    }

    fn decrease(self: *Self, count: usize) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        self.job_count -= count;
        if (self.job_count == 0)
            self.state = .Done;
    }

    fn start(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        switch (self.state) {
            .Quit => return,
            .Running => return,
            else => {
                self.state = .Running;
                self.cond.broadcast(self.io);
            },
        }
    }
    fn stop(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        switch (self.state) {
            .Quit => return,
            .Idle => return,
            else => {
                self.state = .Idle;
                try self.cond.broadcast(self.io);
            },
        }
    }
    fn quit(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        self.state = .Quit;
        self.cond.broadcast(self.io);
    }
};

const Job = struct {
    i: u64,

    pub fn deinit(_: *Job) void {}

    pub fn format(self: Job, w: *std.Io.Writer) !void {
        try w.print("[Job](i:{})\n", .{self.i});
    }
};

const Worker = struct {
    const Self = @This();

    a: std.mem.Allocator,
    io: std.Io,
    ix0: usize,
    cox: *Cox,
    thread: std.Thread,

    queue: Queue,

    fn init(self: *Self, a: std.mem.Allocator, io: std.Io, ix0: usize, cox: *Cox) !void {
        self.a = a;
        self.io = io;
        self.ix0 = ix0;
        self.cox = cox;
        self.thread = try std.Thread.spawn(.{}, Worker.function, .{self});
        self.queue = .{ .a = a, .io = io };
    }
    fn deinit(self: *Self) void {
        self.thread.join();
        self.queue.deinit();
    }

    fn function(self: *Self) !void {
        while (try self.cox.waitFor(.Running)) {
            std.debug.print("Worker {} has {} jobs\n", .{ self.ix0, try self.queue.len() });

            var maybe_job = try self.queue.pop();
            if (maybe_job) |*job| {
                defer job.deinit();
                std.log.info("{f}", .{job});
                try self.cox.decrease(1);
            }
        }
    }
};

pub const Queue = struct {
    pub const Self = @This();

    a: std.mem.Allocator,
    io: std.Io,

    deque: std.Deque(Job) = .empty,
    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,

    pub fn deinit(self: *Self) void {
        self.mutex.lock(self.io) catch return;
        defer self.mutex.unlock(self.io);
        while (self.deque.popBack()) |const_job| {
            var job = const_job;
            job.deinit();
        }
        self.deque.deinit(self.a);
    }

    pub fn pop(self: *Self) !?Job {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        return self.deque.popFront();
    }

    pub fn popWait(self: *Self) !Job {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        while (true) {
            if (self.deque.popFront()) |job|
                return job;
            try self.cond.wait(self.io, *self.mutex);
        }
    }

    pub fn push(self: *Self, job: Job) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        try self.deque.pushBack(self.a, job);
        self.cond.signal(self.io);
    }

    pub fn len(self: *Self) !usize {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        return self.deque.len;
    }
};

test "mt.Runner" {
    const ut = std.testing;

    var runner = Runner{ .a = ut.allocator, .io = ut.io };
    try runner.init(4);
    defer runner.deinit();

    // const jobs = [_]Job{Job{ .i = 12 }};
    // try runner.start(&jobs);
    // try runner.stop();
}

test "mt.Queue" {
    const ut = std.testing;
    var queue = Queue{ .a = ut.allocator, .io = ut.io };
    defer queue.deinit();

    try ut.expect(try queue.pop() == null);
    try queue.push(Job{ .i = 42 });
    const maybe_job = try queue.pop();
    try ut.expect(maybe_job != null);
    const job = maybe_job.?;
    try ut.expect(job.i == 42);
}
