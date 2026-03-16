const std = @import("std");
const Log = @import("Log.zig");

const Env_ = @This();

// General purpose allocator
a: std.mem.Allocator = undefined,
// Arena allocator
aa: std.mem.Allocator = undefined,

io: std.Io = undefined,
envmap: *const std.process.Environ.Map = undefined,

log: *const Log = undefined,

stdout: *std.Io.Writer = undefined,
stderr: *std.Io.Writer = undefined,

pub const Instance = struct {
    const Self = @This();
    const DA = std.heap.DebugAllocator(.{});
    const AA = std.heap.ArenaAllocator;
    const StdIO = struct {
        stdout_writer: std.Io.File.Writer = undefined,
        stderr_writer: std.Io.File.Writer = undefined,
        stdout_buffer: [4096]u8 = undefined,
        stderr_buffer: [4096]u8 = undefined,
        fn init(self: *@This(), io: std.Io) void {
            self.stdout_writer = std.Io.File.stdout().writer(io, &self.stdout_buffer);
            self.stderr_writer = std.Io.File.stderr().writer(io, &self.stderr_buffer);
        }
        fn deinit(self: *@This()) void {
            self.stdout_writer.interface.flush() catch {};
            self.stderr_writer.interface.flush() catch {};
        }
    };

    environ: std.process.Environ = std.process.Environ.empty,
    envmap: std.process.Environ.Map = undefined,
    log: Log = undefined,
    gpa: DA = undefined,
    aa: AA = undefined,
    io_threaded: std.Io.Threaded = undefined,
    io: std.Io = undefined,
    start_ts: std.Io.Timestamp = undefined,
    stdio: StdIO = undefined,

    pub fn init(self: *Self) void {
        self.gpa = DA{};
        const a = self.gpa.allocator();
        self.envmap = self.environ.createMap(a) catch std.process.Environ.Map.init(a);
        self.aa = AA.init(a);
        self.io_threaded = std.Io.Threaded.init(a, .{ .environ = self.environ });
        self.io = self.io_threaded.io();
        self.log = Log{ .io = self.io };
        self.log.init();
        self.start_ts = std.Io.Clock.now(.real, self.io);
        self.stdio.init(self.io);
    }
    pub fn deinit(self: *Self) void {
        self.stdio.deinit();
        self.log.deinit();
        self.io_threaded.deinit();
        self.aa.deinit();
        self.envmap.deinit();
        if (self.gpa.deinit() == .leak) {
            self.log.err("Found memory leaks in Env\n", .{}) catch {};
        }
    }

    pub fn env(self: *Self) Env_ {
        return .{
            .a = self.gpa.allocator(),
            .aa = self.aa.allocator(),
            .io = self.io,
            .envmap = &self.envmap,
            .log = &self.log,
            .stdout = &self.stdio.stdout_writer.interface,
            .stderr = &self.stdio.stderr_writer.interface,
        };
    }

    pub fn duration_ns(self: Self) i96 {
        const duration = self.start_ts.durationTo(std.Io.Clock.now(.real, self.io));
        return duration.nanoseconds;
    }
};

pub fn for_ut() Env_ {
    const ut = std.testing;
    return .{
        .a = ut.allocator,
        .aa = ut.allocator,
        .io = ut.io,
    };
}

pub fn duration_ns(env: Env_) i96 {
    const inst: *const Instance = @alignCast(@fieldParentPtr("log", env.log));
    return inst.duration_ns();
}

test "Env.Instance" {
    var instance: Instance = .{};
    instance.init();
    defer instance.deinit();

    const env = instance.env();
    _ = env;
}

test "Env from ut" {
    const env = Env_.for_ut();

    const buf = try env.a.alloc(u8, 11);
    defer env.a.free(buf);
}
