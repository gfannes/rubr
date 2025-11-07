const std = @import("std");

pub fn homeDir(a: std.mem.Allocator) ![]u8 {
    // &todo: Support Windows
    return try std.process.getEnvVarOwned(a, "HOME");
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

    const home = try homeDir(ut.allocator);
    defer ut.allocator.free(home);

    std.debug.print("home: {s}\n", .{home});

    try ut.expect(isDirectory("src"));
    try ut.expect(!isDirectory("not_a_dir"));
}
