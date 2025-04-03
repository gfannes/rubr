// &todo Support avoiding escaping with balanced brackets
// &todo Implement escaping
// &todo Support creating file/folder tree for UTs (mod+cli)
// &todo Create spec
// - Support for post-body attributes?

const std = @import("std");
const ut = std.testing;

pub const Strange = struct {
    content: []const u8,

    pub fn init(content: []const u8) Strange {
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

    pub fn front(self: Strange) ?u8 {
        if (self.content.len == 0)
            return null;
        return self.content[0];
    }
    pub fn back(self: Strange) ?u8 {
        if (self.content.len == 0)
            return null;
        return self.content[self.content.len - 1];
    }

    pub fn popAll(self: *Strange) ?[]const u8 {
        if (self.empty())
            return null;
        defer self.content = &.{};
        return self.content;
    }

    pub fn popMany(self: *Strange, ch: u8) usize {
        for (self.content, 0..) |act, ix| {
            if (act != ch) {
                self._popFront(ix);
                return ix;
            }
        }
        defer self.content = &.{};
        return self.content.len;
    }
    pub fn popManyBack(self: *Strange, ch: u8) usize {
        var count: usize = 0;
        while (self.content.len > 0 and self.content[self.content.len - 1] == ch) {
            self.content.len -= 1;
            count += 1;
        }
        return count;
    }

    pub fn popTo(self: *Strange, ch: u8) ?[]const u8 {
        if (std.mem.indexOfScalar(u8, self.content, ch)) |ix| {
            defer self._popFront(ix + 1);
            return self.content[0..ix];
        } else {
            return null;
        }
    }

    pub fn popStr(self: *Strange, s: []const u8) bool {
        if (std.mem.startsWith(u8, self.content, s)) {
            self._popFront(s.len);
            return true;
        }
        return false;
    }

    pub fn popLine(self: *Strange) ?[]const u8 {
        if (self.empty())
            return null;

        var line = self.content;
        if (std.mem.indexOfScalar(u8, self.content, '\n')) |ix| {
            line.len = if (ix > 0 and self.content[ix - 1] == '\r') ix - 1 else ix;
            self._popFront(ix + 1);
        } else {
            self.content = &.{};
        }

        return line;
    }

    pub fn popInt(self: *Strange, T: type) ?T {
        // Find number of chars comprising number
        var slice = self.content;
        for (self.content, 0..) |ch, ix| {
            switch (ch) {
                '0'...'9', '-', '+' => {},
                else => {
                    slice.len = ix;
                    break;
                },
            }
        }
        if (std.fmt.parseInt(T, slice, 10) catch null) |v| {
            self._popFront(slice.len);
            return v;
        }
        return null;
    }

    fn _popFront(self: *Strange, count: usize) void {
        self.content.ptr += count;
        self.content.len -= count;
    }
};

test "Strange.empty Strange.size" {
    const strange = Strange.init("abc");
    try ut.expectEqual(false, strange.empty());
    try ut.expectEqual(3, strange.size());
}

test "Strange.popLine" {
    var strange = Strange.init("abc\ndef\r\nghi");
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

test "Strange.popStr" {
    var strange = Strange.init("abc");
    try ut.expectEqual(true, strange.popStr("ab"));
    try ut.expectEqual(false, strange.popStr("ab"));
    try ut.expectEqual(true, strange.popStr("c"));
    try ut.expectEqual(false, strange.popStr("c"));
}

test "Strange.popInt" {
    const scns = [_]struct { []const u8, ?i32 }{ .{ "42", 42 }, .{ "-42", -42 }, .{ "+42", 42 }, .{ "not a number", null }, .{ "42 ", 42 } };
    for (scns) |scn| {
        const str, const exp = scn;
        var strange = Strange.init(str);
        try ut.expectEqual(exp, strange.popInt(i32));
    }
}

test "Strange.popTo Strange.popAll" {
    var strange = Strange.init("abc");
    if (strange.popTo('b')) |part| {
        try ut.expectEqualSlices(u8, "a", part);
        try ut.expectEqualSlices(u8, "c", strange.str());
    } else unreachable;
}

test "Strange.popMany" {
    var strange = Strange.init("abbc");
    try ut.expectEqual(0, strange.popMany('z'));
    try ut.expectEqual(1, strange.popMany('a'));
    try ut.expectEqual(0, strange.popMany('a'));
    try ut.expectEqual(2, strange.popMany('b'));
    try ut.expectEqual(0, strange.popMany('b'));
    try ut.expectEqual(1, strange.popMany('c'));
    try ut.expectEqual(0, strange.popMany('c'));
}

test "Strange.popManyBack" {
    var strange = Strange.init("abbc");
    try ut.expectEqual(0, strange.popManyBack('z'));
    try ut.expectEqual(1, strange.popManyBack('c'));
    try ut.expectEqual(0, strange.popManyBack('c'));
    try ut.expectEqual(2, strange.popManyBack('b'));
    try ut.expectEqual(0, strange.popManyBack('b'));
    try ut.expectEqual(1, strange.popManyBack('a'));
    try ut.expectEqual(0, strange.popManyBack('a'));
}

test "Strange.front Strange.back" {
    var strange = Strange.init("abc");
    try ut.expectEqual(@as(?u8, 'a'), strange.front());
    try ut.expectEqual(@as(?u8, 'c'), strange.back());
    _ = strange.popAll();
    try ut.expectEqual(@as(?u8, null), strange.front());
    try ut.expectEqual(@as(?u8, null), strange.back());
}
