const std = @import("std");

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
        Marker.create('#', self.parent, self.name, r.current == tl_current).format(&r.writer.interface) catch @panic("Failed to write 'enter'");
        tl_current = self;
        r.current = self;
        r.mutex.unlock();
    }
    pub fn leave(self: *Self) void {
        std.debug.assert(self.root != null);
        var r = self.root.?;

        r.mutex.lock();
        Marker.create('.', self.parent, self.name, r.current == tl_current).format(&r.writer.interface) catch @panic("Failed to write 'leave'");
        tl_current = self.parent;
        r.current = self.parent;
        r.mutex.unlock();
    }

    pub fn mark(self: *Self, name: []const u8) *Self {
        std.debug.assert(self.root != null);
        var r = self.root.?;

        r.mutex.lock();
        Marker.create('*', self, name, r.current == tl_current).format(&r.writer.interface) catch @panic("Failed to write 'mark'");
        r.mutex.unlock();

        return self;
    }

    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) void {
        std.debug.assert(self.root != null);
        const r = self.root.?;

        r.mutex.lock();
        r.writer.interface.print(fmt, args) catch @panic("Failed to write print");
        r.mutex.unlock();
    }
};

pub const Variant = struct {
    name: []const u8,
    id: ?usize = null,

    scope: Scope = .{ .name = "<noname>" },

    pub fn enter(self: *Variant, parent: *Scope) void {
        self.scope.name = self.name;
        self.scope.parent = parent;
        self.scope.enter();
    }
    pub fn leave(self: *Variant) void {
        self.scope.leave();
    }
};

const Marker = struct {
    char: u8,
    scope: ?*Scope,
    name: []const u8,
    consistent: bool,

    fn create(char: u8, scope: ?*Scope, name: []const u8, consistent: bool) Marker {
        return Marker{ .char = char, .scope = scope, .name = name, .consistent = consistent };
    }

    pub fn format(self: @This(), w: *std.Io.Writer) !void {
        try w.writeAll("\n&");
        try w.writeByte(self.char);
        var maybe_scope = self.scope;
        while (maybe_scope) |scope| {
            try w.splatByteAll(' ', 2);
            maybe_scope = scope.parent;
        }
        try w.writeAll(self.name);
        try w.writeByte(' ');
    }
};

test "twip" {
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
                var v = Variant{ .name = "work", .id = ix };
                v.enter(parent);
                defer v.leave();

                var prng = std.Random.DefaultPrng.init(ix);
                var rng = prng.random();
                for (0..4) |_| {
                    const duration_ns: u64 = @intFromFloat(rng.float(f64) * 100_000_000.0);
                    std.debug.print("{} {}\n", .{ ix, duration_ns });
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
