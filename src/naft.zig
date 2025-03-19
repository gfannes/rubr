const std = @import("std");

const Error = error{
    CouldNotCreateStdOut,
};

pub const Node = struct {
    const Self = @This();

    out: ?std.fs.File.Writer,
    level: usize,
    has_block: bool = false,

    pub fn init(out: ?std.fs.File.Writer) Node {
        return Node{ .out = out, .level = 0, .has_block = true };
    }
    pub fn deinit(self: Self) void {
        if (self.level == 0)
            // The top-level block does not need any handling
            return;

        if (self.has_block) {
            self.indent();
            self.print("}}\n", .{});
        } else {
            self.print("\n", .{});
        }
    }

    pub fn node(self: *Self, name: []const u8) Node {
        self.ensure_block();
        const n = Node{ .out = self.out, .level = self.level + 1 };
        n.indent();
        n.print("[{s}]", .{name});
        return n;
    }

    pub fn attr(self: *Self, key: []const u8, value: anytype) void {
        if (self.has_block) {
            std.debug.print("Attributes are not allowed anymore: block was already started\n", .{});
            return;
        }

        // std.debug.print("\ntype {s} {any}\n", .{ @typeName(@TypeOf(value)), @typeInfo(@TypeOf(value)) });

        const str = switch (@typeInfo(@TypeOf(value))) {
            // A bit crude, but "str" and '[]const u8' are .pointer
            .pointer => "s",
            else => "any",
        };

        self.print("({s}:{" ++ str ++ "})", .{ key, value });
    }

    fn ensure_block(self: *Self) void {
        if (!self.has_block)
            self.print("{{\n", .{});
        self.has_block = true;
    }

    fn indent(self: Self) void {
        if (self.level > 1)
            for (0..self.level - 1) |_|
                self.print("  ", .{});
    }

    fn print(self: Self, comptime fmt: []const u8, args: anytype) void {
        if (self.out) |out| {
            out.print(fmt, args) catch {};
        } else {
            std.debug.print(fmt, args);
        }
    }
};

test "naft" {
    var root = Node.init(null);
    defer root.deinit();
    {
        var a = root.node("a");
        defer a.deinit();
        a.attr("b", "cccc");

        {
            var b = a.node("b");
            defer b.deinit();
            b.attr("int", 123);
        }

        {
            var c = a.node("c");
            defer c.deinit();
            const slice: []const u8 = "slice";
            c.attr("slice", slice);
        }
    }
}
