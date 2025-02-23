const std = @import("std");
const ut = std.testing;

const GlobError = error{
    EmptyPattern,
};

const Strange = @import("strange.zig").Strange;

const Part = struct {
    const Wildcard = enum { Nothing, Anything, NoPathSep, End };

    wildcard: Wildcard,
    str: []const u8,
};

const Glob = struct {
    const Self = @This();
    const Parts = std.ArrayList(Part);

    ma: std.mem.Allocator,
    parts: Parts,

    pub fn new(pattern: []const u8, ma: std.mem.Allocator) !Glob {
        if (pattern.len == 0)
            return GlobError.EmptyPattern;

        var glob = Glob{ .ma = ma, .parts = Parts.init(ma) };

        var wildcard = Part.Wildcard.Nothing;
        var strange = Strange.new(pattern);
        while (strange.popTo('*')) |str| {
            std.debug.print("part: {s}\n", .{str});
            if (str.len > 0) {
                try glob.parts.append(Part{ .wildcard = wildcard, .str = str });
            }
            // We found a single '*', check for more '*' to decide if we can match path separators as well
            wildcard = if (strange.popMany('*') > 0) Part.Wildcard.Anything else Part.Wildcard.NoPathSep;
        }

        if (strange.popAll()) |str| {
            // pattern does not end with a '*'
            try glob.parts.append(Part{ .wildcard = wildcard, .str = str });
            try glob.parts.append(Part{ .wildcard = Part.Wildcard.End, .str = "" });
        } else {
            // pattern ends with a '*'
            try glob.parts.append(Part{ .wildcard = wildcard, .str = "" });
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
            Part.Wildcard.Nothing => {
                if (!std.mem.startsWith(u8, haystack, part.str))
                    return false;
                return _match(parts[1..], haystack[part.str.len..]);
            },
            Part.Wildcard.Anything => {
                if (part.str.len == 0) {
                    // This is a special case with an empty part.str: this should only for the last part
                    // Accept a full match until the end if this is the last part.
                    // If this is not the last part, something unexpected happened: Glob.new() should not produce something like that
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
            Part.Wildcard.NoPathSep => {
                if (part.str.len == 0) {
                    // This is a special case with an empty part.str: this should only for the last part
                    // Accept a full match if there is no path separator
                    if (std.mem.indexOfScalar(u8, haystack, '/')) |_| {
                        // We found a path separator: this is not a match until the end
                        return false;
                    } else {
                        // If this is not the last part, something unexpected happened: Glob.new() should not produce something like that
                        return parts.len == 1;
                    }
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
            Part.Wildcard.End => {
                // Accept if we fully matched haystack
                return haystack.len == 0;
            },
        }
    }
};

test "glob" {
    var glob = try Glob.new("*ab*c*", ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("XXabYYcZZ"));
    try ut.expect(glob.match("XXaXbcXabYYcZZ"));

    try ut.expect(!glob.match("ab"));
}

test "without path separator" {
    var glob = try Glob.new("*.wav", ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc.wav"));

    try ut.expect(!glob.match("a/bc.wav"));
    try ut.expect(!glob.match("a/b/c.wav"));
}

test "with path separator" {
    var glob = try Glob.new("**.wav", ut.allocator);
    defer glob.deinit();

    try ut.expect(glob.match("abc.wav"));
    try ut.expect(glob.match("a/bc.wav"));
    try ut.expect(glob.match("a/b/c.wav"));

    try ut.expect(!glob.match("a/b/c.wa"));
}
