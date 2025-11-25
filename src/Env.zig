const std = @import("std");
const Log = @import("Log.zig");

const Env_ = @This();

// General purpose allocator
a: std.mem.Allocator = undefined,
// Arena allocator
aa: std.mem.Allocator = undefined,

io: std.Io = undefined,

log: *const Log = undefined,

stdout: *std.Io.Writer = undefined,
stderr: *std.Io.Writer = undefined,

pub const Instance = struct {
    const Self = @This();
    const GPA = std.heap.GeneralPurposeAllocator(.{});
    const AA = std.heap.ArenaAllocator;
    const StdIO = struct {
        stdout_writer: std.fs.File.Writer = undefined,
        stderr_writer: std.fs.File.Writer = undefined,
        stdout_buffer: [4096]u8 = undefined,
        stderr_buffer: [4096]u8 = undefined,
        fn init(self: *@This()) void {
            self.stdout_writer = std.fs.File.stdout().writer(&self.stdout_buffer);
            self.stderr_writer = std.fs.File.stderr().writer(&self.stderr_buffer);
        }
        fn deinit(self: *@This()) void {
            self.stdout_writer.interface.flush() catch {};
            self.stderr_writer.interface.flush() catch {};
        }
    };

    log: Log = undefined,
    gpa: GPA = undefined,
    aa: AA = undefined,
    io: std.Io.Threaded = undefined,
    maybe_start: ?std.time.Instant = null,
    stdio: StdIO = undefined,

    pub fn init(self: *Self) void {
        self.log = Log{};
        self.log.init();
        self.gpa = GPA{};
        self.aa = AA.init(self.gpa.allocator());
        self.io = std.Io.Threaded.init(self.gpa.allocator());
        self.maybe_start = std.time.Instant.now() catch null;
        self.stdio.init();
    }
    pub fn deinit(self: *Self) void {
        self.stdio.deinit();
        self.io.deinit();
        self.aa.deinit();
        if (self.gpa.deinit() == .leak) {
            self.log.err("Found memory leaks in Env\n", .{}) catch {};
        }
        self.log.deinit();
    }

    pub fn env(self: *Self) Env_ {
        return .{
            .a = self.gpa.allocator(),
            .aa = self.aa.allocator(),
            .io = self.io.io(),
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
