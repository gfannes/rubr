const std = @import("std");

pub const Error = error{
    BufferTooSmall,
};

pub fn homeDir(a: std.mem.Allocator) ![]u8 {
    // &todo: Support Windows
    return try std.process.getEnvVarOwned(a, "HOME");
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
        const home = try homeDir(ut.allocator);
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
