const std = @import("std");
const ut = std.testing;

// &todo Deal with '**' patterns that can match '/' and '*' that cannot

const Strange = @import("strange.zig").Strange;

const Part = struct {
    const Kind = enum { Here, Anywhere, Accept, End };

    kind: Kind,
    str: []const u8,
};

const Glob = struct {
    const Self = @This();
    const Parts = std.ArrayList(Part);

    ma: std.mem.Allocator,
    parts: Parts,

    pub fn new(pattern: []const u8, ma: std.mem.Allocator) !Glob {
        var glob = Glob{ .ma = ma, .parts = Parts.init(ma) };

        var kind = Part.Kind.Here;
        var strange = Strange.new(pattern);
        while (strange.popTo('*')) |part| {
            std.debug.print("part: {s}\n", .{part});
            if (part.len > 0) {
                try glob.parts.append(Part{ .kind = kind, .str = part });
            }
            // We found a '*': match for next part can start anywhere
            kind = Part.Kind.Anywhere;
        }

        if (strange.popAll()) |part| {
            try glob.parts.append(Part{ .kind = kind, .str = part });
            try glob.parts.append(Part{ .kind = Part.Kind.End, .str = "" });
        } else {
            // pattern either end with a '*' or is empty: we accept whatever we matched already
            try glob.parts.append(Part{ .kind = Part.Kind.Accept, .str = "" });
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
        if (parts.len == 0) return true;
        const part = &parts[0];

        switch (part.kind) {
            Part.Kind.Here => {
                if (!std.mem.startsWith(u8, haystack, part.str))
                    return false;
                return _match(parts[1..], haystack[part.str.len..]);
            },
            Part.Kind.Anywhere => {
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
                return false;
            },
            Part.Kind.Accept => return true,
            Part.Kind.End => return haystack.len == 0,
        }
    }
};

test {
    const ma = ut.allocator;

    var glob = try Glob.new("*ab*c*", ma);
    defer glob.deinit();
    std.debug.print("{any}\n", .{glob.parts.items});

    try ut.expect(glob.match("abc"));
    try ut.expect(glob.match("XXabYYcZZ"));
    try ut.expect(glob.match("XXaXbcXabYYcZZ"));

    try ut.expect(!glob.match("ab"));
}
