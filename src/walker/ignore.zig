const std = @import("std");
const ut = std.testing;

const Strange = @import("../strange.zig").Strange;
const glob = @import("../glob.zig");

pub const Ignore = struct {
    const Self = @This();
    const Globs = std.ArrayList(glob.Glob);
    const Strings = std.ArrayList([]const u8);

    globs: Globs,
    antiglobs: Globs,

    pub fn init(ma: std.mem.Allocator) Ignore {
        return Ignore{ .globs = Globs.init(ma), .antiglobs = Globs.init(ma) };
    }

    pub fn deinit(self: *Self) void {
        for ([_]*Globs{ &self.globs, &self.antiglobs }) |globs| {
            for (globs.items) |*item|
                item.deinit();
            globs.deinit();
        }
    }

    pub fn initFromFile(dir: std.fs.Dir, name: []const u8, ma: std.mem.Allocator) !Self {
        const file = try dir.openFile(name, .{});
        defer file.close();

        const stat = try file.stat();

        const r = file.reader();

        const content = try r.readAllAlloc(ma, stat.size);
        defer ma.free(content);

        return initFromContent(content, ma);
    }

    pub fn initFromContent(content: []const u8, ma: std.mem.Allocator) !Self {
        var self = Self.init(ma);
        errdefer self.deinit();

        var strange_content = Strange{ .content = content };
        while (strange_content.popLine()) |line| {
            var strange_line = Strange{ .content = line };

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
            var config = glob.Config{};
            if (strange_line.popMany('/') == 0)
                config.front = "**";
            config.pattern = strange_line.str();
            if (strange_line.back() == '/')
                config.back = "**";

            try globs.append(try glob.Glob.init(config, ma));
        }

        return self;
    }

    pub fn addExt(self: *Ignore, ext: []const u8) !void {
        const buffer: [128]u8 = undefined;
        const fba = std.heap.FixedBufferAllocator.init(buffer);
        const my_ext = try std.mem.concat(fba, u8, &[_][]const u8{ ".", ext });

        const glob_config = glob.Config{ .pattern = my_ext, .front = "**" };
        try self.globs.append(try glob.Glob.init(glob_config, self.globs.allocator));
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
