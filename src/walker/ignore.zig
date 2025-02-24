const std = @import("std");
const ut = std.testing;

const Strange = @import("../strange.zig").Strange;
const glob = @import("../glob.zig");

const Ignore = struct {
    const Self = @This();
    const Globs = std.ArrayList(glob.Glob);

    ma: std.mem.Allocator,
    globs: Globs,

    pub fn new(ma: std.mem.Allocator) Ignore {
        return Ignore{ .ma = ma, .globs = Globs.init(ma) };
    }

    pub fn deinit(self: *Self) void {
        for (self.globs.items) |*item|
            item.deinit();
        self.globs.deinit();
    }

    const Error = error{NotImplemented};

    pub fn loadFromFile(dir: std.fs.Dir, name: []const u8, ma: std.mem.Allocator) !Self {
        const file = try dir.openFile(name, .{});
        defer file.close();

        const stat = try file.stat();

        const r = file.reader();

        const content = try r.readAllAlloc(ma, stat.size);
        defer ma.free(content);

        return loadFromContent(content, ma);
    }

    pub fn loadFromContent(content: []const u8, ma: std.mem.Allocator) !Self {
        var ret = Self.new(ma);
        errdefer ret.deinit();

        var strange_content = Strange.new(content);
        while (strange_content.popLine()) |line| {
            var strange_line = Strange.new(line);

            // Trim
            _ = strange_line.popMany(' ');
            _ = strange_line.popManyBack(' ');

            if (strange_line.popMany('#') > 0)
                // Skip comments
                continue;

            if (strange_line.empty())
                continue;

            var config = glob.Config{ .pattern = strange_line.str() };
            if (strange_line.back() == '/') {
                config.back = "**";
            }

            try ret.globs.append(try glob.Glob.new(config, ma));
        }

        return ret;
    }

    pub fn match(self: Self, fp: []const u8) bool {
        for (self.globs.items) |item| {
            if (item.match(fp))
                return true;
        }
        return false;
    }
};

test "loadFromContent" {
    const content = " dir/ \n file\n #comment\n\n *.ext  ";

    var ignore = try Ignore.loadFromContent(content, ut.allocator);
    defer ignore.deinit();

    try ut.expect(ignore.match("dir/"));
    try ut.expect(ignore.match("dir/abc"));
    try ut.expect(ignore.match("file"));
    try ut.expect(ignore.match("test.ext"));

    try ut.expect(!ignore.match("#comment"));
}
