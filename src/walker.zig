const std = @import("std");
const ut = std.testing;

const Ignore = @import("walker/ignore.zig");

// &todo Add support for .gitignore files

const Walker = struct {
    filter: Filter = .{},

    // Temporary buffer to hold the path before emitting via callback
    _buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined,

    pub fn walk(self: *Walker, dir: std.fs.Dir, cb: anytype) !void {
        var it = dir.iterate();
        while (try it.next()) |el| {
            if (self.filter.call(dir, el)) {
                switch (el.kind) {
                    std.fs.File.Kind.file => {
                        const path = try dir.realpath(".", &self._buffer);
                        cb(path, el.name);
                    },
                    std.fs.File.Kind.directory => {
                        var subdir = try dir.openDir(el.name, .{ .iterate = true });
                        defer subdir.close();
                        try self.walk(subdir, cb);
                    },
                    else => {},
                }
            }
        }
    }
};

const Filter = struct {
    // Skip hidden files by default
    hidden: bool = true,
    // Skip files with following extensions
    // First const is necessary to support assignment from `&[][]const u8{".o", ".exe"}`.
    extensions: []const []const u8 = &.{},

    fn call(self: Filter, _: std.fs.Dir, entry: std.fs.Dir.Entry) bool {
        if (self.hidden and is_hidden(entry.name))
            return false;

        const my_ext = std.fs.path.extension(entry.name);
        for (self.extensions) |ext| {
            if (std.mem.eql(u8, my_ext, ext))
                return false;
        }

        return true;
    }
};

fn is_hidden(name: []const u8) bool {
    return name.len > 0 and name[0] == '.';
}

test "walk" {
    var walker = Walker{ .filter = .{ .extensions = &[_][]const u8{ ".o", ".exe" } } };
    const cb = struct {
        pub fn call(path: []const u8, name: []const u8) void {
            std.debug.print("path: {s}, name: {s}\n", .{ path, name });
        }
    };
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();
    try walker.walk(dir, cb.call);
}
