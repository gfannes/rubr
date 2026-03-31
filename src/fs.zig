const std = @import("std");
const builtin = @import("builtin");

pub const Error = error{
    BufferTooSmall,
    CouldNotFindHome,
    CouldNotReadAll,
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
        @memmove(self.buffer[0..self.len], str);
    }

    // Use env.envmap
    pub fn home(envmap: *const std.process.Environ.Map) !Self {
        const name = if (builtin.os.tag == .windows) "USERPROFILE" else "HOME";
        const value = envmap.get(name) orelse return error.CouldNotFindHome;

        var res = Self{};

        if (value.len > max_len)
            return error.BufferTooSmall;
        res.len = value.len;

        @memmove(res.buffer[0..res.len], value);
        return res;
    }

    pub fn add(self: *Self, part: []const u8) !void {
        if (self.len + 1 + part.len > max_len)
            return Error.BufferTooSmall;
        if (self.len > 0) {
            self.buffer[self.len] = '/';
            self.len += 1;
        }
        @memmove(self.buffer[self.len .. self.len + part.len], part);
        self.len += part.len;
    }

    pub fn path(self: *const Self) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn exists(self: *const Self, io: std.Io) bool {
        const file = std.Io.Dir.openFileAbsolute(io, self.path(), .{}) catch return false;
        defer file.close(io);
        return true;
    }

    pub fn read(self: *const Self, io: std.Io, a: std.mem.Allocator) ![]u8 {
        const file = try std.Io.Dir.openFileAbsolute(io, self.path(), .{});
        defer file.close(io);
        const stat = try file.stat(io);
        const content = try a.alloc(u8, stat.size);
        const size = try file.readPositionalAll(io, content, 0);
        if (size != stat.size)
            return error.CouldNotReadAll;
        return content;
    }
    pub fn readSentinel(self: *const Self, io: std.Io, a: std.mem.Allocator) ![:0]u8 {
        const file = try std.Io.Dir.openFileAbsolute(io, self.path(), .{});
        defer file.close(io);
        const stat = try file.stat(io);
        const content = try a.alloc(u8, stat.size + 1);
        const size = try file.readPositionalAll(io, content[0..stat.size], 0);
        if (size != stat.size)
            return error.CouldNotReadAll;
        content[stat.size] = 0;
        return content[0..stat.size :0];
    }
};

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

test "fs.Path" {
    const ut = std.testing;

    var p = Path{};
    try ut.expectEqualStrings("", p.path());

    try p.add("abc");
    try ut.expectEqualStrings("abc", p.path());

    try p.add("def");
    try ut.expectEqualStrings("abc/def", p.path());
}
