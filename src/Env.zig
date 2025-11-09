const std = @import("std");
const Log = @import("Log.zig");

const Env_ = @This();

// General purpose allocator
a: std.mem.Allocator = undefined,
// Arena allocator
aa: std.mem.Allocator = undefined,

io: std.Io = undefined,

log: *const Log = undefined,

pub const Instance = struct {
    const Self = @This();
    const GPA = std.heap.GeneralPurposeAllocator(.{});
    const AA = std.heap.ArenaAllocator;

    log: Log = undefined,
    gpa: GPA = undefined,
    aa: AA = undefined,
    io: std.Io.Threaded = undefined,
    maybe_start: ?std.time.Instant = null,

    pub fn init(self: *Self) void {
        self.log = Log{};
        self.log.init();
        self.gpa = GPA{};
        self.aa = AA.init(self.gpa.allocator());
        self.io = std.Io.Threaded.init(self.gpa.allocator());
        self.maybe_start = std.time.Instant.now() catch null;
    }
    pub fn deinit(self: *Self) void {
        self.io.deinit();
        self.aa.deinit();
        if (self.gpa.deinit() == .leak) {
            self.log.err("Found memory leaks in Env\n", .{}) catch {};
        }
        self.log.deinit();
    }

    pub fn env(self: *Self) Env_ {
        return .{ .a = self.gpa.allocator(), .aa = self.aa.allocator(), .io = self.io.io(), .log = &self.log };
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
