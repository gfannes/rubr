const std = @import("std");

// Twig markers are used to annotate a stream of logging data with structure.
// These markers can indicate:
// - A new twig is Entered `&#`
// - The current twig is Closed `&.`
// - A Marker is encountered `&*`
// - A Switch to an alternative source is made `&+`
//
// A twig has the format `\n&<type><path> `
// - `\n` is a newline
// - `<type>` indicates the twig type and can be `#*~.`
// - `<indent>` is an optional indentation that can be used for human readability
// - `<path>` is the path of the twig, this cannot contain a spaces
//   - path parts are separated with a '/'
//   - a part constists of a name and an optional id, separated with a '.'
// - ` ` is used to end the twig marker
//
// &#/ci                                              => We start with an absolute path
// &#  build                                          => Relative path, we are at /ci/build
// &*    object a.cpp                                 => Marker 'ojbect'
// &*    object b.cpp
// &.  build                                          => Closing /ci/build
// &#  ut
// &#/ci/ut/work.0                                    => Entering /ci/ut/work.0, full path due to a new thread
// &*      duration ix: 0 36507446                    => Marker relative to /ci/ut/work.0
// &#/ci/ut/work.1                                    => Note that a path part can optionally contain an id
// &*      duration ix: 1 136340278
// &#/ci/ut/work.2
// &*      duration ix: 2 210553650
// &*/ci/ut/work.0/duration ix: 0 41303962            => These prints are not interrupted by other threads: no need for a full path
// &*      duration ix: 0 49802063ix: 0 last
// &*      duration ix: 0 1501378
// &.    work.0
// &*/ci/ut/work.1/duration ix: 1 114091738
// &*/ci/ut/work.2/duration ix: 2 182767239
// &*/ci/ut/work.1/duration ix: 1 15226260ix: 1 last
// &*      duration ix: 1 150430204
// &*/ci/ut/work.2/duration ix: 2 253533771
// &./ci/ut/work.1
// &~/ci/ut/work.2 ix: 2 last                         => This is a print on a Scope without a marker that requires a switch with '~'
// &*      duration ix: 2 83898627
// &.    work.2
// &.  ut
// &./ci

pub const Root = struct {
    valid: bool = false,
    a: std.mem.Allocator = undefined,
    writer: std.fs.File.Writer = undefined,
    mutex: std.Thread.Mutex = .{},
    current: ?*Scope = null,

    pub fn init(self: *Root, a: std.mem.Allocator, file: std.fs.File, buffer: []u8) void {
        std.debug.assert(!self.valid);
        self.* = .{ .valid = true, .a = a, .writer = file.writer(buffer), .current = null };
    }
    pub fn deinit(self: *Root) void {
        std.debug.assert(self.valid);
        self.writer.interface.flush() catch {};
        self.valid = false;
    }
};

pub var root: Root = .{};
threadlocal var tl_current: ?*Scope = null;

pub const Scope = struct {
    const Self = @This();

    name: []const u8,
    id: ?usize = null,
    root: ?*Root = null,
    parent: ?*Scope = null,

    // `self` must have a stable address
    pub fn enter(self: *Self) void {
        if (self.root == null)
            self.root = &root;
        var r = self.root.?;

        if (self.parent == null)
            self.parent = tl_current;

        r.mutex.lock();
        Marker.create('#', self.parent, self.name, self.id, r.current == tl_current).format(&r.writer.interface) catch @panic("Failed to write 'enter'");
        tl_current = self;
        r.current = self;
        r.mutex.unlock();
    }
    pub fn leave(self: *Self) void {
        std.debug.assert(self.root != null);
        var r = self.root.?;

        r.mutex.lock();
        Marker.create('.', self.parent, self.name, self.id, r.current == tl_current).format(&r.writer.interface) catch @panic("Failed to write 'leave'");
        tl_current = self.parent;
        r.current = self.parent;
        r.mutex.unlock();
    }

    pub fn mark(self: *Self, name: []const u8) *Self {
        std.debug.assert(self.root != null);
        var r = self.root.?;

        r.mutex.lock();
        Marker.create('*', self, name, null, r.current == tl_current).format(&r.writer.interface) catch @panic("Failed to write 'mark'");
        tl_current = self;
        r.current = self;
        r.mutex.unlock();

        return self;
    }

    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
        std.debug.assert(self.root != null);
        const r = self.root.?;

        r.mutex.lock();
        if (r.current != self) {
            Marker.create('~', self.parent, self.name, self.id, false).format(&r.writer.interface) catch @panic("Failed to write 'print'");
            r.current = self;
        }
        r.writer.interface.print(fmt, args) catch @panic("Failed to write 'print'");
        r.mutex.unlock();
    }
};

const Marker = struct {
    char: u8,
    scope: ?*Scope,
    name: []const u8,
    id: ?usize,
    consistent: bool,

    fn create(char: u8, scope: ?*Scope, name: []const u8, id: ?usize, consistent: bool) Marker {
        return Marker{ .char = char, .scope = scope, .name = name, .id = id, .consistent = consistent };
    }

    pub fn format(self: @This(), w: *std.Io.Writer) !void {
        try w.writeAll("\n&");
        try w.writeByte(self.char);
        const is_root = self.scope == null;
        try format_path(self.scope, w, self.consistent and !is_root);
        try w.writeAll(self.name);
        if (self.id) |id|
            try w.print(".{}", .{id});
        try w.writeByte(' ');
    }

    fn format_path(scope: ?*Scope, w: *std.Io.Writer, relative: bool) !void {
        if (scope) |s| {
            try format_path(s.parent, w, relative);
            if (relative) {
                try w.splatByteAll(' ', 2);
            } else {
                try w.writeAll(s.name);
                if (s.id) |id|
                    try w.print(".{}", .{id});
            }
        }
        if (!relative)
            try w.writeByte('/');
    }
};

test "twig" {
    const ut = std.testing;

    var buf: [10]u8 = undefined;
    root.init(ut.allocator, std.fs.File.stderr(), &buf);
    defer root.deinit();

    var ci = Scope{ .name = "ci" };
    ci.enter();
    defer ci.leave();

    {
        var build = Scope{ .name = "build" };
        build.enter();
        defer build.leave();
        build.mark("object").print("a.cpp", .{});
        build.mark("object").print("b.cpp", .{});
    }

    {
        var utt = Scope{ .name = "ut" };
        utt.enter();
        defer utt.leave();

        const Worker = struct {
            fn call(ix: usize, parent: *Scope) void {
                var s = Scope{ .name = "work", .id = ix, .parent = parent };
                s.enter();
                defer s.leave();

                var prng = std.Random.DefaultPrng.init(ix);
                var rng = prng.random();
                for (0..4) |i| {
                    if (i == 3)
                        s.print("ix: {} last", .{ix});
                    const duration_ns: u64 = @as(u64, @intFromFloat(rng.float(f64) * 100_000_000.0)) * (ix + 1);
                    s.mark("duration").print("ix: {} {}", .{ ix, duration_ns });
                    std.Thread.sleep(duration_ns);
                }
            }
        };

        var threads: [3]std.Thread = undefined;
        for (&threads, 0..) |*thread, ix0| {
            thread.* = try std.Thread.spawn(.{}, Worker.call, .{ ix0, &utt });
        }

        for (&threads) |*thread| {
            thread.join();
        }
    }
}
