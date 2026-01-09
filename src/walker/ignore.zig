const std = @import("std");

const strng = @import("../strng.zig");
const glb = @import("../glb.zig");

pub const Ignore = struct {
    const Self = @This();
    const Globs = std.ArrayList(glb.Glob);
    const Strings = std.ArrayList([]const u8);

    a: std.mem.Allocator,
    globs: Globs = .{},
    antiglobs: Globs = .{},

    pub fn init(a: std.mem.Allocator) Ignore {
        return Ignore{ .a = a };
    }

    pub fn deinit(self: *Self) void {
        for ([_]*Globs{ &self.globs, &self.antiglobs }) |globs| {
            for (globs.items) |*item|
                item.deinit();
            globs.deinit(self.a);
        }
    }

    pub fn initFromFile(dir: std.Io.Dir, name: []const u8, a: std.mem.Allocator) !Self {
        const file = try dir.openFile(name, .{});
        defer file.close();

        const stat = try file.stat();

        const r = file.reader();

        const content = try r.readAllAlloc(a, stat.size);
        defer a.free(content);

        return initFromContent(content, a);
    }

    pub fn initFromContent(content: []const u8, a: std.mem.Allocator) !Self {
        var self = Self.init(a);
        errdefer self.deinit();

        var strange_content = strng.Strange{ .content = content };
        while (strange_content.popLine()) |line| {
            var strange_line = strng.Strange{ .content = line };

            // Trim
            _ = strange_line.popMany(' ');
            _ = strange_line.popManyBack(' ');

            if (strange_line.popMany('#') > 0)
                // Skip comments
                continue;

            if (strange_line.empty())
                continue;

            const is_anti = strange_line.popMany('!') > 0;
            const globs = if (is_anti) &self.antiglobs else &self.globs;

            // '*.txt'    ignores '**/*.txt'
            // 'dir/'     ignores '**/dir/**'
            // '/dir/'    ignores 'dir/**'
            // 'test.txt' ignores '**/test.txt'
            var config = glb.Config{};
            if (strange_line.popMany('/') == 0)
                config.front = "**";
            config.pattern = strange_line.str();
            if (strange_line.back() == '/')
                config.back = "**";

            try globs.append(a, try glb.Glob.init(config, a));
        }

        return self;
    }

    pub fn addExt(self: *Ignore, ext: []const u8) !void {
        const buffer: [128]u8 = undefined;
        const fba = std.heap.FixedBufferAllocator.init(buffer);
        const my_ext = try std.mem.concat(fba, u8, &[_][]const u8{ ".", ext });

        const glob_config = glb.Config{ .pattern = my_ext, .front = "**" };
        try self.globs.append(self.a, try glb.Glob.init(glob_config, self.globs.allocator));
    }

    pub fn match(self: Self, fp: []const u8) bool {
        var ret = false;
        for (self.globs.items) |item| {
            if (item.match(fp))
                ret = true;
        }
        for (self.antiglobs.items) |item| {
            if (item.match(fp))
                ret = false;
        }
        return ret;
    }
};

test "initFromContent" {
    const ut = std.testing;

    // '*.txt'    ignores '**/*.txt'
    // 'dir/'     ignores '**/dir/**'
    // '/dir/'    ignores 'dir/**'
    // 'test.txt' ignores '**/test.txt'
    const content = " dir/ \n/dar/\n file\n #comment\n!ok.ext\n\n *.ext  ";

    var ignore = try Ignore.initFromContent(content, ut.allocator);
    defer ignore.deinit();

    try ut.expect(ignore.match("dir/"));
    try ut.expect(ignore.match("dir/abc"));
    try ut.expect(ignore.match("base/dir/abc"));

    try ut.expect(ignore.match("dar/"));
    try ut.expect(!ignore.match("base/dar/"));

    try ut.expect(ignore.match("file"));
    try ut.expect(ignore.match("base/file"));

    try ut.expect(!ignore.match("#comment"));

    try ut.expect(ignore.match("test.ext"));
    try ut.expect(ignore.match("base/test.ext"));
    try ut.expect(!ignore.match("ok.ext"));
    try ut.expect(!ignore.match("base/ok.ext"));
}
