const std = @import("std");
const builtin = @import("builtin");
const Env = @import("Env.zig");

pub const Error = error{
    BufferTooSmall,
    CouldNotFindHome,
};

pub const Path = struct {
    const Self = @This();
    pub const max_len = std.fs.max_path_bytes;

    buffer: [Self.max_len]u8 = undefined,
    len: usize = 0,

    pub fn set(self: *Self, str: []const u8) !void {
        if (str.len > max_len)
            return Error.BufferTooSmall;
        self.len = str.len;
        @memcpy(self.buffer[0..self.len], str);
    }

    pub fn home() !Self {
        var res = Self{};
        var fba = std.heap.FixedBufferAllocator.init(&res.buffer);
        const env_var = try std.process.getEnvVarOwned(fba.allocator(), "HOME");
        res.len = env_var.len;
        @memmove(res.buffer[0..res.len], env_var);
        return res;
    }

    pub fn add(self: *Self, part: []const u8) !void {
        if (self.len + 1 + part.len > max_len)
            return Error.BufferTooSmall;
        if (self.len > 0) {
            self.buffer[self.len] = '/';
            self.len += 1;
        }
        @memcpy(self.buffer[self.len .. self.len + part.len], part);
        self.len += part.len;
    }

    pub fn path(self: Self) []const u8 {
        return self.buffer[0..self.len];
    }
};

test "fs.Path" {
    const ut = std.testing;

    var p = Path{};
    try ut.expectEqualStrings("", p.path());

    try p.add("abc");
    try ut.expectEqualStrings("abc", p.path());

    try p.add("def");
    try ut.expectEqualStrings("abc/def", p.path());
}

pub fn homePathAlloc(env: Env, maybe_part: ?[]const u8) ![]u8 {
    const name = if (builtin.os.tag == .windows) "USERPROFILE" else "HOME";
    const home = env.envmap.get(name) orelse return error.CouldNotFindHome;
    return if (maybe_part) |part|
        try std.mem.concat(env.a, u8, &[_][]const u8{ home, "/", part })
    else
        try env.a.dupe(u8, home);
}

pub fn cwdPathAlloc(io: std.Io, a: std.mem.Allocator, maybe_part: ?[]const u8) ![:0]u8 {
    return try std.Io.Dir.cwd().realPathFileAlloc(io, maybe_part orelse ".", a);
}

pub fn isDirectory(io: std.Io, path: []const u8) bool {
    const err_dir =
        if (std.fs.path.isAbsolute(path))
            std.Io.Dir.openDirAbsolute(io, path, .{})
        else
            std.Io.Dir.cwd().openDir(io, path, .{});
    return if (err_dir) |_| true else |_| false;
}

pub fn deleteTree(io: std.Io, path: []const u8) !void {
    if (std.fs.path.isAbsolute(path)) {
        var dir = try std.Io.Dir.openDirAbsolute(io, path, .{});
        defer dir.close(io);
        try dir.deleteTree(io, ".");
    } else try std.Io.Dir.cwd().deleteTree(io, path);
}

test "fs" {
    const ut = std.testing;

    var envmap = try std.process.Environ.empty.createMap(ut.allocator);
    defer envmap.deinit();
    const name = if (builtin.os.tag == .windows) "USERPROFILE" else "HOME";
    try envmap.put(name, "/home/geertf");

    const env = Env{ .a = ut.allocator, .io = ut.io, .envmap = &envmap };

    {
        const home = try homePathAlloc(env, null);
        defer ut.allocator.free(home);

        std.debug.print("home: {s}\n", .{home});
    }

    try ut.expect(isDirectory(ut.io, "src"));
    try ut.expect(!isDirectory(ut.io, "not_a_dir"));
}
