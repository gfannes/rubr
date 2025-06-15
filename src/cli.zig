const std = @import("std");

pub const Args = struct {
    const Self = @This();

    argv: [][]const u8 = &.{},
    aa: std.heap.ArenaAllocator,

    pub fn init(a: std.mem.Allocator) Self {
        return Self{ .aa = std.heap.ArenaAllocator.init(a) };
    }
    pub fn deinit(self: *Self) void {
        self.aa.deinit();
    }

    pub fn setupFromOS(self: *Self) !void {
        const aaa = self.aa.allocator();

        const os_argv = try std.process.argsAlloc(aaa);
        defer std.process.argsFree(aaa, os_argv);

        self.argv = try aaa.alloc([]const u8, os_argv.len);

        for (os_argv, 0..) |str, ix| {
            self.argv[ix] = try aaa.dupe(u8, str);
        }
    }
    pub fn setupFromData(self: *Self, argv: []const []const u8) !void {
        const aaa = self.aa.allocator();

        self.argv = try aaa.alloc([]const u8, argv.len);
        for (argv, 0..) |slice, ix| {
            self.argv[ix] = try aaa.dupe(u8, slice);
        }
    }

    pub fn pop(self: *Self) ?Arg {
        if (self.argv.len == 0) return null;

        const aaa = self.aa.allocator();
        const arg = aaa.dupe(u8, std.mem.sliceTo(self.argv[0], 0)) catch return null;
        self.argv.ptr += 1;
        self.argv.len -= 1;

        return Arg{ .arg = arg };
    }
};

pub const Arg = struct {
    const Self = @This();

    arg: []const u8,

    pub fn is(self: Arg, sh: []const u8, lh: []const u8) bool {
        return std.mem.eql(u8, self.arg, sh) or std.mem.eql(u8, self.arg, lh);
    }

    pub fn as(self: Self, T: type) !T {
        return try std.fmt.parseInt(T, self.arg, 10);
    }
};

test "cli" {
    const ut = std.testing;

    var args = Args.init(ut.allocator);
    try args.setupFromData(&[_][]const u8{ "exe", "-h" });
    defer args.deinit();

    const exe = args.pop() orelse unreachable;
    try ut.expectEqualSlices(u8, "exe", exe.arg);
    try ut.expectEqual(true, exe.is("exe", "exe"));
    try ut.expectEqual(false, exe.is("???", "???"));

    const help = args.pop() orelse unreachable;
    try ut.expectEqualSlices(u8, "-h", help.arg);
    try ut.expectEqual(true, help.is("-h", "--help"));
    try ut.expectEqual(true, help.is("--help", "-h"));
    try ut.expectEqual(false, help.is("-o", "--output"));

    try ut.expectEqual(null, args.pop());
    try ut.expectEqual(null, args.pop());
}
