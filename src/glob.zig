// &todo Support '?' pattern

const std = @import("std");
const ut = std.testing;

const Strange = @import("strange.zig").Strange;

const Error = error{
    EmptyPattern,
    IllegalWildcard,
};

const Wildcard = enum {
    None,
    Some, // '*': All characters except path separator '/'
    All, // '**': All characters

    pub fn fromStr(str: []const u8) !Wildcard {
        if (str.len == 0)
            return Wildcard.None;
        if (std.mem.eql(u8, str, "*"))
            return Wildcard.Some;
        if (std.mem.eql(u8, str, "**"))
            return Wildcard.All;
        return Error.IllegalWildcard;
    }

    pub fn max(a: Wildcard, b: Wildcard) Wildcard {
        return switch (a) {
            Wildcard.None => b,
            Wildcard.Some => if (b == Wildcard.None) a else b,
            Wildcard.All => a,
        };
    }

    test "fromStr" {
        try ut.expectEqual(Wildcard.None, Wildcard.fromStr(""));
        try ut.expectEqual(Wildcard.Some, Wildcard.fromStr("*"));
        try ut.expectEqual(Wildcard.All, Wildcard.fromStr("**"));
        try ut.expectEqual(Error.IllegalWildcard, Wildcard.fromStr("x"));
    }

    test "max" {
        const nothing = Wildcard.None;
        const nopathsep = Wildcard.Some;
        const anything = Wildcard.All;

        try ut.expectEqual(Wildcard.None, Wildcard.max(nothing, nothing));

        try ut.expectEqual(Wildcard.Some, Wildcard.max(nothing, nopathsep));
        try ut.expectEqual(Wildcard.Some, Wildcard.max(nopathsep, nothing));
        try ut.expectEqual(Wildcard.Some, Wildcard.max(nopathsep, nopathsep));

        try ut.expectEqual(Wildcard.All, Wildcard.max(nothing, anything));
        try ut.expectEqual(Wildcard.All, Wildcard.max(anything, nothing));
        try ut.expectEqual(Wildcard.All, Wildcard.max(nopathsep, anything));
        try ut.expectEqual(Wildcard.All, Wildcard.max(anything, nopathsep));
        try ut.expectEqual(Wildcard.All, Wildcard.max(anything, anything));
    }
};

// A Part is easy to match: search for str and check if whatever in-between matches with wildcard
const Part = struct {
    wildcard: Wildcard,
    str: []const u8,
};

pub const Config = struct {
    pattern: []const u8 = &.{},
    front: []const u8 = &.{},
    back: []const u8 = &.{},
};

pub const Glob = struct {
    const Self = @This();
    const Parts = std.ArrayList(Part);

    ma: std.mem.Allocator,
    parts: Parts,

    pub fn init(config: Config, ma: std.mem.Allocator) !Glob {
        if (config.pattern.len == 0)
            return Error.EmptyPattern;

        var glob = Glob{ .ma = ma, .parts = Parts.init(ma) };

        var strange = Strange.new(config.pattern);

        var wildcard = try Wildcard.fromStr(config.front);

        while (true) {
            if (strange.popTo('*')) |str| {
                if (str.len > 0) {
                    try glob.parts.append(Part{ .wildcard = wildcard, .str = str });
                }

                // We found a single '*', check for more '*' to decide if we can match path separators as well
                {
                    const new_wildcard = if (strange.popMany('*') > 0) Wildcard.All else Wildcard.Some;

                    if (str.len == 0) {
                        // When pattern starts with a '*', keep the config.front wildcard if it is stronger
                        wildcard = Wildcard.max(wildcard, new_wildcard);
                    } else {
                        wildcard = new_wildcard;
                    }
                }

                if (strange.empty()) {
                    // We popped everything from strange and will hence not enter below's branch: setup wildcard according to config.back
                    const new_wildcard = try Wildcard.fromStr(config.back);
                    wildcard = Wildcard.max(wildcard, new_wildcard);
                }
            } else if (strange.popAll()) |str| {
                try glob.parts.append(Part{ .wildcard = wildcard, .str = str });

                wildcard = try Wildcard.fromStr(config.back);
            } else {
                try glob.parts.append(Part{ .wildcard = wildcard, .str = "" });
                break;
            }
        }

        return glob;
    }

    pub fn deinit(self: *Self) void {
        self.parts.deinit();
    }

    pub fn match(self: Self, haystack: []const u8) bool {
        return _match(self.parts.items, haystack);
    }

    fn _match(parts: []const Part, haystack: []const u8) bool {
        if (parts.len == 0)
            return true;

        const part = &parts[0];

        switch (part.wildcard) {
            Wildcard.None => {
                if (part.str.len == 0) {
                    // This is a special case with an empty part.str: this should only for the last part
                    std.debug.assert(parts.len == 1);

                    // None only matches if we are at the end
                    return haystack.len == 0;
                }

                if (!std.mem.startsWith(u8, haystack, part.str))
                    return false;

                return _match(parts[1..], haystack[part.str.len..]);
            },
            Wildcard.Some => {
                if (part.str.len == 0) {
                    // This is a special case with an empty part.str: this should only for the last part
                    std.debug.assert(parts.len == 1);

                    // Accept a full match if there is no path separator
                    return std.mem.indexOfScalar(u8, haystack, '/') == null;
                } else {
                    var start: usize = 0;
                    while (start < haystack.len) {
                        if (std.mem.indexOf(u8, haystack[start..], part.str)) |ix| {
                            if (std.mem.indexOfScalar(u8, haystack[start .. start + ix], '/')) |_|
                                // We found a path separator: this is not a match
                                return false;
                            if (_match(parts[1..], haystack[start + ix + part.str.len ..]))
                                // We found a match for the other parts
                                return true;
                            // No match found downstream: try to match part.str further in haystack
                            start += ix + 1;
                        }
                        break;
                    }
                }
                return false;
            },
            Wildcard.All => {
                if (part.str.len == 0) {
                    // This is a special case with an empty part.str: this should only be used for the last part
                    std.debug.assert(parts.len == 1);

                    // Accept a full match until the end if this is the last part.
                    // If this is not the last part, something unexpected happened: Glob.init() should not produce something like that
                    return parts.len == 1;
                } else {
                    var start: usize = 0;
                    while (start < haystack.len) {
                        if (std.mem.indexOf(u8, haystack[start..], part.str)) |ix| {
                            if (_match(parts[1..], haystack[start + ix + part.str.len ..]))
                                // We found a match for the other parts
                                return true;
                            // No match found downstream: try to match part.str further in haystack
                            start += ix + 1;
                        }
                        break;
                    }
                }
                return false;
            },
        }
    }
};

test "glob" {
    var glob = try Glob.init(.{ .pattern = "*ab*c*" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("XXabYYcZZ"));
    try ut.expect(glob.match("XXaXbcXabYYcZZ"));

    try ut.expect(!glob.match("ab"));
}

test "without path separator" {
    var glob = try Glob.init(.{ .pattern = "*.wav" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc.wav"));

    try ut.expect(!glob.match("a/bc.wav"));
    try ut.expect(!glob.match("a/b/c.wav"));
}

test "with path separator" {
    var glob = try Glob.init(.{ .pattern = "**.wav" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc.wav"));
    try ut.expect(glob.match("a/bc.wav"));
    try ut.expect(glob.match("a/b/c.wav"));

    try ut.expect(!glob.match("a/b/c.wa"));
}

test "with front some" {
    var glob = try Glob.init(.{ .pattern = "*abc", .front = "*" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("xabc"));

    try ut.expect(!glob.match("/abc"));
    try ut.expect(!glob.match("abcx"));
}

test "with front any" {
    var glob = try Glob.init(.{ .pattern = "*abc", .front = "**" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("/abc"));
    try ut.expect(glob.match("//abc"));

    try ut.expect(!glob.match("abcx"));
}

test "with back some" {
    var glob = try Glob.init(.{ .pattern = "abc*", .back = "*" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("abcx"));
    try ut.expect(!glob.match("abc/"));
}

test "with back any" {
    var glob = try Glob.init(.{ .pattern = "abc*", .back = "**" }, ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("abc/"));
    try ut.expect(glob.match("abc//"));
}
