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
    const GPA = std.heap.GeneralPurposeAllocator(.{});
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
    gpa: GPA = undefined,
    aa: AA = undefined,
    io: std.Io.Threaded = undefined,
    maybe_start: ?std.time.Instant = null,
    stdio: StdIO = undefined,

    pub fn init(self: *Self) void {
        self.gpa = GPA{};
        const a = self.gpa.allocator();
        self.envmap = self.environ.createMap(a) catch std.process.Environ.Map.init(a);
        self.aa = AA.init(a);
        self.io = std.Io.Threaded.init(a, .{ .environ = self.environ });
        const io = self.io.io();
        self.log = Log{ .io = io };
        self.log.init();
        self.maybe_start = std.time.Instant.now() catch null;
        self.stdio.init(io);
    }
    pub fn deinit(self: *Self) void {
        self.stdio.deinit();
        self.log.deinit();
        self.io.deinit();
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
            .io = self.io.io(),
            .envmap = &self.envmap,
            .log = &self.log,
            .stdout = &self.stdio.stdout_writer.interface,
            .stderr = &self.stdio.stderr_writer.interface,
        };
    }

    pub fn duration_ns(self: Self) u64 {
        const start = self.maybe_start orelse return 0;
        const now = std.time.Instant.now() catch return 0;
        return now.since(start);
    }
};

pub fn duration_ns(env: Env_) u64 {
    const inst: *const Instance = @fieldParentPtr("log", env.log);
    return inst.duration_ns();
}

test "Env" {
    var instance: Instance = .{};
    instance.init();
    defer instance.deinit();

    const env = instance.env();
    _ = env;
}
