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

    _strings: Strings,
    ma: std.mem.Allocator,

    pub fn make(ma: std.mem.Allocator) Ignore {
        return Ignore{ .globs = Globs.init(ma), .antiglobs = Globs.init(ma), ._strings = Strings.init(ma), .ma = ma };
    }

    pub fn deinit(self: *Self) void {
        for ([_]*Globs{ &self.globs, &self.antiglobs }) |globs| {
            for (globs.items) |*item|
                item.deinit();
            globs.deinit();
        }
        for (self._strings.items) |str| {
            self.ma.free(str);
        }
        self._strings.deinit();
    }

    pub fn makeFromFile(dir: std.fs.Dir, name: []const u8, ma: std.mem.Allocator) !Self {
        const file = try dir.openFile(name, .{});
        defer file.close();

        const stat = try file.stat();

        const r = file.reader();

        const content = try r.readAllAlloc(ma, stat.size);
        defer ma.free(content);

        return makeFromContent(content, ma);
    }

    pub fn makeFromContent(content: []const u8, ma: std.mem.Allocator) !Self {
        var self = Self.make(ma);
        errdefer self.deinit();

        var strange_content = Strange.make(content);
        while (strange_content.popLine()) |line| {
            var strange_line = Strange.make(line);

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

            try globs.append(try glob.Glob.make(config, ma));
        }

        return self;
    }

    pub fn addExt(self: *Ignore, ext: []const u8) !void {
        const my_ext = try std.mem.concat(self.ma, u8, &[_][]const u8{ ".", ext });
        try self._strings.append(my_ext);
        try self.globs.append(try glob.Glob.make(glob.Config{ .pattern = my_ext, .front = "**" }, self.ma));
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

test "makeFromContent" {
    // '*.txt'    ignores '**/*.txt'
    // 'dir/'     ignores '**/dir/**'
    // '/dir/'    ignores 'dir/**'
    // 'test.txt' ignores '**/test.txt'
    const content = " dir/ \n/dar/\n file\n #comment\n!ok.ext\n\n *.ext  ";

    var ignore = try Ignore.makeFromContent(content, ut.allocator);
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
