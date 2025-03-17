// &todo Take `.gitignore` and `.ignore` into account

const std = @import("std");
const ut = std.testing;

const ignore = @import("walker/ignore.zig");
const slice = @import("slice.zig");

const Error = error{
    CouldNotReadIgnore,
};

pub const Offsets = struct {
    base: usize = 0,
    name: usize = 0,
};

pub const Walker = struct {
    const Ignore = struct { buffer: Buffer = undefined, ignore: ignore.Ignore = undefined, path_len: usize = 0 };
    const IgnoreStack = std.ArrayList(Ignore);
    const Buffer = std.ArrayList(u8);

    filter: Filter = .{},

    _ma: std.mem.Allocator,

    // We keep track of the current path as a []const u8. If the caller has to do this,
    // he has to use Dir.realpath() which is less efficient.
    _buffer: [std.fs.max_path_bytes]u8 = undefined,
    _path: []const u8 = &.{},

    _offsets: Offsets = undefined,
    _ignore_offset: usize = 0,

    _ignore_stack: IgnoreStack = undefined,

    pub fn make(ma: std.mem.Allocator) !Walker {
        return Walker{ ._ma = ma, ._ignore_stack = IgnoreStack.init(ma) };
    }

    pub fn deinit(self: *Walker) void {
        for (self._ignore_stack.items) |*item| {
            item.ignore.deinit();
            item.buffer.deinit();
        }
        self._ignore_stack.deinit();
    }

    pub fn walk(self: *Walker, basedir: std.fs.Dir, cb: anytype) !void {
        self._path = try basedir.realpath(".", &self._buffer);
        self._offsets = Offsets{ .base = self._path.len + 1 };

        var dir = try basedir.openDir(".", .{ .iterate = true });
        defer dir.close();

        try self._walk(dir, cb);
    }

    fn _walk(self: *Walker, dir: std.fs.Dir, cb: anytype) !void {
        var added_ignore = false;

        if (dir.openFile(".gitignore", .{})) |file| {
            defer file.close();

            const stat = try file.stat();

            var ig = Ignore{ .buffer = try Buffer.initCapacity(self._ma, stat.size) };
            try ig.buffer.resize(stat.size);
            if (stat.size != try file.readAll(ig.buffer.items))
                return Error.CouldNotReadIgnore;

            ig.ignore = try ignore.Ignore.makeFromContent(ig.buffer.items, self._ma);
            ig.path_len = self._path.len;
            try self._ignore_stack.append(ig);

            self._ignore_offset = ig.path_len + 1;

            added_ignore = true;
        } else |_| {}

        var it = dir.iterate();
        while (try it.next()) |el| {
            if (!self.filter.call(dir, el))
                continue;

            switch (el.kind) {
                std.fs.File.Kind.file => {
                    const orig_path_len = self._path.len;
                    defer self._path.len = orig_path_len;

                    self._offsets.name = self._path.len + 1;
                    self._append_to_path(el.name);

                    if (slice.last(self._ignore_stack.items)) |e| {
                        const ignore_path = self._path[self._ignore_offset..];
                        if (e.ignore.match(ignore_path))
                            continue;
                    }

                    try cb.call(dir, self._path, self._offsets);
                },
                std.fs.File.Kind.directory => {
                    var subdir = try dir.openDir(el.name, .{ .iterate = true });
                    defer subdir.close();

                    const orig_path_len = self._path.len;
                    defer self._path.len = orig_path_len;

                    self._append_to_path(el.name);

                    if (slice.last(self._ignore_stack.items)) |e| {
                        const ignore_path = self._path[self._ignore_offset..];
                        if (e.ignore.match(ignore_path))
                            continue;
                    }

                    try self._walk(subdir, cb);
                },
                else => {},
            }
        }

        if (added_ignore) {
            if (self._ignore_stack.pop()) |v| {
                v.buffer.deinit();
                var v_mut = v;
                v_mut.ignore.deinit();
            }

            self._ignore_offset = if (slice.last(self._ignore_stack.items)) |x| x.path_len + 1 else 0;
        }
    }

    fn _append_to_path(self: *Walker, name: []const u8) void {
        self._buffer[self._path.len] = '/';
        self._path.len += 1;

        std.mem.copyForwards(u8, self._buffer[self._path.len..], name);
        self._path.len += name.len;
    }
};

pub const Filter = struct {
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
    var walker = try Walker.make(ut.allocator);
    defer walker.deinit();
    walker.filter = .{ .extensions = &[_][]const u8{ ".o", ".exe" } };

    var cb = struct {
        pub fn call(_: *@This(), dir: std.fs.Dir, path: []const u8, offsets: Offsets) !void {
            std.debug.print("dir: {}, path: {s}, offsets: {}\n", .{ dir, path, offsets });
        }
    }{};

    try walker.walk(std.fs.cwd(), &cb);
}
