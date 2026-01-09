// &todo Take `.gitignore` and `.ignore` into account

const std = @import("std");

const ignore = @import("walker/ignore.zig");
const slc = @import("slc.zig");
const Env = @import("Env.zig");

pub const Offsets = struct {
    base: usize = 0,
    name: usize = 0,
};

pub const Kind = enum {
    Enter,
    Leave,
    File,
};

pub const Walker = struct {
    const Ignore = struct { buffer: Buffer = undefined, ignore: ignore.Ignore = undefined, path_len: usize = 0 };
    const IgnoreStack = std.ArrayList(Ignore);
    const Buffer = std.ArrayList(u8);

    env: Env,

    filter: Filter = .{},

    // We keep track of the current path as a []const u8. If the caller has to do this,
    // he has to use Dir.realPath() which is less efficient.
    buffer: [std.fs.max_path_bytes]u8 = undefined,
    path: []const u8 = &.{},
    base: usize = undefined,

    ignore_offset: usize = 0,

    ignore_stack: IgnoreStack = .{},

    pub fn deinit(self: *Walker) void {
        for (self.ignore_stack.items) |*item| {
            item.ignore.deinit();
            item.buffer.deinit(self.env.a);
        }
        self.ignore_stack.deinit(self.env.a);
    }

    // cb() is passed:
    // - dir: std.Io.Dir
    // - path: full path of file/folder
    // - offsets: optional offsets for basename and filename. Only for the toplevel Enter/Leave is this null to avoid out of bound reading
    // - kind: Enter/Leave/File
    pub fn walk(self: *Walker, basedir: std.Io.Dir, cb: anytype) !void {
        const len = try basedir.realPathFile(self.env.io, ".", &self.buffer);
        self.path = self.buffer[0..len];
        self.base = self.path.len + 1;

        var dir = try basedir.openDir(self.env.io, ".", .{ .iterate = true });
        defer dir.close(self.env.io);

        const path = self.path;

        try cb.call(dir, path, null, Kind.Enter);
        try self._walk(dir, cb);
        try cb.call(dir, path, null, Kind.Leave);
    }

    fn _walk(self: *Walker, dir: std.Io.Dir, cb: anytype) !void {
        var added_ignore = false;

        if (dir.openFile(self.env.io, ".gitignore", .{})) |file| {
            defer file.close(self.env.io);

            const stat = try file.stat(self.env.io);

            var ig = Ignore{ .buffer = try Buffer.initCapacity(self.env.a, stat.size) };
            try ig.buffer.resize(self.env.a, stat.size);
            var buf: [1024]u8 = undefined;
            var reader = file.reader(self.env.io, &buf);
            try reader.interface.readSliceAll(ig.buffer.items);

            ig.ignore = try ignore.Ignore.initFromContent(ig.buffer.items, self.env.a);
            ig.path_len = self.path.len;
            try self.ignore_stack.append(self.env.a, ig);

            self.ignore_offset = ig.path_len + 1;

            added_ignore = true;
        } else |_| {}

        var it = dir.iterate();
        while (try it.next(self.env.io)) |el| {
            if (!self.filter.call(dir, el))
                continue;

            const orig_path_len = self.path.len;
            defer self.path.len = orig_path_len;

            const offsets = Offsets{ .base = self.base, .name = self.path.len + 1 };
            self._append_to_path(el.name);

            switch (el.kind) {
                std.Io.File.Kind.file => {
                    if (slc.last(self.ignore_stack.items)) |e| {
                        const ignore_path = self.path[self.ignore_offset..];
                        if (e.ignore.match(ignore_path))
                            continue;
                    }

                    try cb.call(dir, self.path, offsets, Kind.File);
                },
                std.Io.File.Kind.directory => {
                    if (slc.last(self.ignore_stack.items)) |e| {
                        const ignore_path = self.path[self.ignore_offset..];
                        if (e.ignore.match(ignore_path))
                            continue;
                    }

                    var subdir = try dir.openDir(self.env.io, el.name, .{ .iterate = true });
                    defer subdir.close(self.env.io);

                    const path = self.path;

                    try cb.call(subdir, path, offsets, Kind.Enter);

                    try self._walk(subdir, cb);

                    try cb.call(subdir, path, offsets, Kind.Leave);
                },
                else => {},
            }
        }

        if (added_ignore) {
            if (self.ignore_stack.pop()) |v| {
                var v_mut = v;
                v_mut.buffer.deinit(self.env.a);
                v_mut.ignore.deinit();
            }

            self.ignore_offset = if (slc.last(self.ignore_stack.items)) |x| x.path_len + 1 else 0;
        }
    }

    fn _append_to_path(self: *Walker, name: []const u8) void {
        self.buffer[self.path.len] = '/';
        self.path.len += 1;

        std.mem.copyForwards(u8, self.buffer[self.path.len..], name);
        self.path.len += name.len;
    }
};

pub const Filter = struct {
    // Skip hidden files by default
    hidden: bool = true,

    // Skip files with following extensions. Include '.' in extension.
    extensions: []const []const u8 = &.{},

    fn call(self: Filter, _: std.Io.Dir, entry: std.Io.Dir.Entry) bool {
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
    var env_inst = Env.Instance{};
    env_inst.init();
    defer env_inst.deinit();

    var walker = Walker{ .env = env_inst.env() };
    defer walker.deinit();
    walker.filter = .{ .extensions = &[_][]const u8{ ".o", ".exe" } };

    var cb = struct {
        pub fn call(_: *@This(), dir: std.Io.Dir, path: []const u8, maybe_offsets: ?Offsets, kind: Kind) !void {
            std.debug.print("dir: {}, path: {s}, offsets: {?}, kind: {}\n", .{ dir, path, maybe_offsets, kind });
        }
    }{};

    try walker.walk(std.Io.Dir.cwd(), &cb);
}
