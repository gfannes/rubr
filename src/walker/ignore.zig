const std = @import("std");
const ut = std.testing;

const strange = @import("../strange.zig");

const Ignore = struct {
    const Self = @This();
    const Strings = std.ArrayList([]const u8);

    ma: std.mem.Allocator,
    folders: Strings,
    names: Strings,

    pub fn new(ma: std.mem.Allocator) Ignore {
        return Ignore{ .ma = ma, .folders = Strings.init(ma), .names = Strings.init(ma) };
    }

    pub fn deinit(self: *Self) void {
        for (self.folders.items) |folder|
            self.ma.free(folder);
        self.folders.deinit();
        for (self.names.items) |name|
            self.ma.free(name);
        self.names.deinit();
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

        var strng = strange.Strange.new(content);
        while (strng.popLine()) |line| {
            std.debug.print("line: {s}\n", .{line});
            if (std.mem.endsWith(u8, line, "/")) {
                try ret.folders.append(try ma.dupe(u8, line[0 .. line.len - 1]));
            } else {
                try ret.names.append(try ma.dupe(u8, line));
            }
        }

        return ret;
    }
};

test "loadFromContent" {
    const content = "dir/\nfile\n#comment\n\n*.ext";

    var ignore = try Ignore.loadFromContent(content, ut.allocator);
    defer ignore.deinit();

    std.debug.print("ignore: {}\n", .{ignore});
    std.debug.print("folders: {s}\n", .{ignore.folders.items});
    std.debug.print("names: {s}\n", .{ignore.names.items});
}
