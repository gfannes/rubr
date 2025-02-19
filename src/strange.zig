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

    pub fn popLine(self: *Strange) ?[]const u8 {
        if (self.empty()) return null;

        var line = self.content;
        if (std.mem.indexOfScalar(u8, self.content, '\n')) |ix| {
            line.len = if (ix > 0 and self.content[ix - 1] == '\r') ix - 1 else ix;
            self.content.ptr += ix + 1;
            self.content.len -= ix + 1;
        } else {
            self.content = &.{};
        }

        return line;
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
