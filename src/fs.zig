const std = @import("std");

pub const Error = error{
    BufferTooSmall,
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

pub fn homeDirAlloc(a: std.mem.Allocator, maybe_part: ?[]const u8) ![]u8 {
    // &todo: Support Windows
    var home_buf: [std.fs.max_path_bytes]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&home_buf);
    const home = try std.process.getEnvVarOwned(fba.allocator(), "HOME");
    return if (maybe_part) |part|
        try std.mem.concat(a, u8, &[_][]const u8{ home, "/", part })
    else
        try a.dupe(u8, home);
}

pub fn homePath(part: []const u8, buf: []u8) ![]const u8 {
    var path: []u8 = buf;

    {
        var fba = std.heap.FixedBufferAllocator.init(buf);
        const home = try std.process.getEnvVarOwned(fba.allocator(), "HOME");
        path.len = home.len;
        @memmove(path, home);
    }

    if (path.len + 1 > buf.len) return Error.BufferTooSmall;
    path.len += 1;
    path[path.len - 1] = '/';

    if (path.len + part.len > buf.len) return Error.BufferTooSmall;
    const start = path.len;
    path.len += part.len;
    std.mem.copyForwards(u8, path[start..], part);

    return path;
}

pub fn cwdPathAlloc(a: std.mem.Allocator, maybe_part: ?[]const u8) ![]u8 {
    return try std.fs.cwd().realpathAlloc(a, maybe_part orelse ".");
}

pub fn isDirectory(path: []const u8) bool {
    const err_dir =
        if (std.fs.path.isAbsolute(path))
            std.fs.openDirAbsolute(path, .{})
        else
            std.fs.cwd().openDir(path, .{});
    return if (err_dir) |_| true else |_| false;
}

pub fn deleteTree(path: []const u8) !void {
    if (std.fs.path.isAbsolute(path))
        try std.fs.deleteTreeAbsolute(path)
    else
        try std.fs.cwd().deleteTree(path);
}

test "fs" {
    const ut = std.testing;

    {
        const home = try homeDirAlloc(ut.allocator, null);
        defer ut.allocator.free(home);

        std.debug.print("home: {s}\n", .{home});
    }

    {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try homePath("abc", &buf);
        std.debug.print("path: {s}\n", .{path});
    }

    try ut.expect(isDirectory("src"));
    try ut.expect(!isDirectory("not_a_dir"));
}
