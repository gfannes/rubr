const std = @import("std");
const ut = std.testing;

pub const Strange = struct {
    content: []const u8,

    pub fn new(content: []const u8) Strange {
        return Strange{ .content = content };
    }

    pub fn empty(self: Strange) bool {
        return self.content.len == 0;
    }
    pub fn size(self: Strange) usize {
        return self.content.len;
    }

    pub fn str(self: Strange) []const u8 {
        return self.content;
    }

    pub fn popAll(self: *Strange) ?[]const u8 {
        if (self.empty()) return null;
        const ret = self.content;
        self.content = &.{};
        return ret;
    }

    pub fn popTo(self: *Strange, ch: u8) ?[]const u8 {
        if (std.mem.indexOfScalar(u8, self.content, ch)) |ix| {
            const ret = self.content[0..ix];
            self._popFront(ix + 1);
            return ret;
        } else {
            return null;
        }
    }

    pub fn popLine(self: *Strange) ?[]const u8 {
        if (self.empty()) return null;

        var line = self.content;
        if (std.mem.indexOfScalar(u8, self.content, '\n')) |ix| {
            line.len = if (ix > 0 and self.content[ix - 1] == '\r') ix - 1 else ix;
            self._popFront(ix + 1);
        } else {
            self.content = &.{};
        }

        return line;
    }

    fn _popFront(self: *Strange, count: usize) void {
        self.content.ptr += count;
        self.content.len -= count;
    }
};

test "Strange.empty Strange.size" {
    const strange = Strange.new("abc");
    try ut.expectEqual(false, strange.empty());
    try ut.expectEqual(3, strange.size());
}

test "Strange.popLine" {
    var strange = Strange.new("abc\ndef\r\nghi");
    if (strange.popLine()) |line| {
        try ut.expectEqualSlices(u8, "abc", line);
    } else unreachable;
    if (strange.popLine()) |line| {
        try ut.expectEqualSlices(u8, "def", line);
    } else unreachable;
    if (strange.popLine()) |line| {
        try ut.expectEqualSlices(u8, "ghi", line);
    } else unreachable;
    if (strange.popLine()) |_| unreachable;
    try ut.expectEqual(true, strange.empty());
}

test "Strange.popTo Strange.popAll" {
    var strange = Strange.new("abc");
    if (strange.popTo('b')) |part| {
        try ut.expectEqualSlices(u8, "a", part);
        try ut.expectEqualSlices(u8, "c", strange.str());
    } else unreachable;
}
