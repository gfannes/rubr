const std = @import("std");

pub const Error = error{
    ExpectedIdleState,
    ExpectedRunningState,
    WaitingFailure,
    WorkerIsClosed,
};

// A pool of workers, each with their own job queue.
// Jobs can generate more jobs.
// Workers that run out of jobs from their own job queue steal work from others.
pub const Runner = struct {
    pub const Self = @This();

    a: std.mem.Allocator,
    io: std.Io,

    busy_mask: BusyMask = undefined,
    workers: std.ArrayList(Worker) = .empty,

    pub fn init(self: *Self, worker_count: usize) !void {
        self.busy_mask = try .init(self.io);
        try self.workers.resize(self.a, worker_count);
        for (self.workers.items, 0..) |*worker, ix0| {
            try worker.init(self.a, self.io, @intCast(ix0), &self.busy_mask);
        }
    }
    pub fn deinit(self: *Self) void {
        for (self.workers.items) |*worker| {
            worker.deinit();
        }
        self.workers.deinit(self.a);
    }

    pub fn start(self: *Self, jobs_: []const Job) !void {
        var jobs = jobs_;

        std.debug.print("Pushing {} jobs ...", .{jobs_.len});
        while (jobs.len > 0) {
            for (self.workers.items) |*worker| {
                if (jobs.len == 0)
                    break;
                try worker.push(jobs[0]);
                jobs = jobs[1..];
            }
        }
        std.debug.print(" done.\n", .{});

        for (self.workers.items) |*worker| {
            try worker.changeState(.Running);
        }
    }

    pub fn stop(self: *Self) !void {
        // Wait for all workers to run out of work before we transition them to idle.
        // Otherwise, new work can arrive and we have to process this with some workers already idle.
        try self.busy_mask.waitForIdle();

        for (self.workers.items) |*worker| {
            try worker.changeState(.Idle);
        }
    }
};

const Job = struct {
    io: std.Io,
    i: u64,
    sum: *std.atomic.Value(u64),
    // sum: *u64,

    pub fn deinit(_: *Job) void {}

    pub fn run(self: *Job, worker: *Worker) !void {
        if (false) {
            std.debug.print("{f} sleeping\n", .{self.*});
            try std.Io.sleep(self.io, .fromSeconds(@intCast(self.i)), .real);
            std.debug.print("{f} awake\n", .{self.*});
        } else {
            if (self.i < 2 or self.i == 3000000) {
                _ = self.sum.fetchAdd(self.i, .monotonic);
                // self.sum.* += self.i;
            } else {
                const orig_i = self.i;

                var job = self.*;

                job.i = job.i / 2;
                try worker.push(job);

                job.i = orig_i - job.i;
                try worker.push(job);
            }
        }
    }

    pub fn format(self: Job, w: *std.Io.Writer) !void {
        try w.print("[Job](i:{})", .{self.i});
    }
};

const Worker = struct {
    const Self = @This();

    const State = enum { Init, Idle, Running, Deinit };

    a: std.mem.Allocator,
    io: std.Io,

    ix0: u6,
    busy_mask: *BusyMask,
    thread: std.Thread,

    busy: bool = false,

    wnt_state: State = .Init,
    act_state: State = .Init,
    queue: std.Deque(Job) = .empty,
    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,

    fn init(self: *Self, a: std.mem.Allocator, io: std.Io, ix0: u6, busy_mask: *BusyMask) !void {
        self.* = .{
            .a = a,
            .io = io,
            .ix0 = ix0,
            .busy_mask = busy_mask,
            .thread = try std.Thread.spawn(.{}, Worker.function, .{self}),
        };
        try self.changeState(.Idle);
    }
    fn deinit(self: *Self) void {
        self.changeState(.Deinit) catch {};

        self.thread.join();

        self.mutex.lock(self.io) catch {};
        defer self.mutex.unlock(self.io);
        while (self.queue.popBack()) |const_job| {
            var job = const_job;
            job.deinit();
        }
        self.queue.deinit(self.a);
    }

    fn changeState(self: *Self, state: State) !void {
        // Update wnt_state
        {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            if (state != self.wnt_state) {
                self.wnt_state = state;
                self.cond.signal(self.io);
            }
        }

        // Wait until act_state follows
        {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);

            while (self.act_state != state) {
                try self.cond.wait(self.io, &self.mutex);
            }
        }
    }

    fn push(self: *Self, job: Job) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        if (self.act_state == .Deinit)
            return error.WorkerIsClosed;
        try self.queue.pushBack(self.a, job);
    }

    fn function(self: *Self) !void {
        var quit = false;
        while (!quit) {
            var maybe_job: ?Job = null;
            {
                try self.mutex.lock(self.io);
                defer self.mutex.unlock(self.io);

                {
                    const new_busy = self.queue.len > 0;
                    if (new_busy != self.busy) {
                        self.busy = new_busy;
                        try self.busy_mask.set(self.ix0, self.busy);
                    }
                }
                if (self.act_state != self.wnt_state) {
                    std.debug.print("[Worker](ix0:{})(act_state:{})(wnt_state:{})(len:{})\n", .{ self.ix0, self.act_state, self.wnt_state, self.queue.len });

                    const change_state = switch (self.wnt_state) {
                        .Idle => !self.busy,
                        else => true,
                    };

                    if (change_state) {
                        self.act_state = self.wnt_state;
                        self.cond.signal(self.io);
                    }
                }

                switch (self.act_state) {
                    .Running => {
                        maybe_job = self.queue.popFront();
                        if (maybe_job == null)
                            try self.cond.wait(self.io, &self.mutex);
                    },
                    .Deinit => quit = true,
                    else => try self.cond.wait(self.io, &self.mutex),
                }
            }

            if (maybe_job) |*job| {
                defer job.deinit();
                try job.run(self);
            }
        }
    }
};

const BusyMask = struct {
    const Self = @This();

    io: std.Io,

    mask: u64 = 0,
    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,

    fn init(io: std.Io) !Self {
        var rv = Self{
            .io = io,
        };

        {
            // Block is necessary to avoid moving a locked mutex
            try rv.mutex.lock(rv.io);
            defer rv.mutex.unlock(rv.io);
            rv.mask = 0;
        }

        return rv;
    }

    fn set(self: *Self, ix0: u6, b: bool) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        const old_mask = self.mask;

        const m: u64 = @as(u64, 1) << ix0;

        if (b)
            self.mask |= m
        else
            self.mask &= ~m;

        if (self.mask != old_mask) {
            std.debug.print("[Busy](mask:0x{x})\n", .{self.mask});
            self.cond.broadcast(self.io);
        }
    }

    fn waitForIdle(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        while (self.mask != 0) {
            try self.cond.wait(self.io, &self.mutex);
        }
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        try w.print("[BusyMask](mask:0x{x})", .{self.mask});
    }
};

test "mt.Runner" {
    const ut = std.testing;

    std.debug.print("mt.Runner\n", .{});

    var runner = Runner{ .a = ut.allocator, .io = ut.io };
    try runner.init(50);
    defer runner.deinit();

    var sum = std.atomic.Value(u64).init(0);
    // var sum: u64 = 0;

    const jobs = [_]Job{
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
        .{ .io = ut.io, .i = 1000000, .sum = &sum },
        .{ .io = ut.io, .i = 2000000, .sum = &sum },
        .{ .io = ut.io, .i = 3000000, .sum = &sum },
        .{ .io = ut.io, .i = 4000000, .sum = &sum },
    };
    try runner.start(&jobs);
    try runner.stop();

    std.debug.print("Sum {}\n", .{sum});
}

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
