const std = @import("std");
const Env = @import("Env.zig");

// Allocates everything on env.aa: no need for deinit() or lifetime management
pub const Args = struct {
    const Self = @This();

    env: Env,
    argv: [][]const u8 = &.{},

    pub fn setupFromOS(self: *Self) !void {
        const a = self.env.aa;

        const os_argv = try std.process.argsAlloc(a);
        defer std.process.argsFree(a, os_argv);

        self.argv = try a.alloc([]const u8, os_argv.len);

        for (os_argv, 0..) |str, ix| {
            self.argv[ix] = try a.dupe(u8, str);
        }
    }
    pub fn setupFromData(self: *Self, argv: []const []const u8) !void {
        const a = self.env.aa;

        self.argv = try a.alloc([]const u8, argv.len);
        for (argv, 0..) |slice, ix| {
            self.argv[ix] = try a.dupe(u8, slice);
        }
    }

    pub fn pop(self: *Self) ?Arg {
        if (self.argv.len == 0) return null;

        const a = self.env.aa;
        const arg = a.dupe(u8, std.mem.sliceTo(self.argv[0], 0)) catch return null;
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
    var env_inst = Env.Instance{};
    env_inst.init();
    defer env_inst.deinit();

    var args = Args{ .env = env_inst.env() };
    try args.setupFromData(&[_][]const u8{ "exe", "-h" });

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
