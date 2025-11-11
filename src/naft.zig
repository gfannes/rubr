const std = @import("std");

const Error = error{
    CouldNotCreateStdOut,
};

pub const Node = struct {
    const Self = @This();

    io: ?*std.Io.Writer,
    level: usize,
    // Indicates if this Node already contains nested elements (Text, Node). This is used to add a closing '}' upon deinit().
    has_block: bool = false,
    // Indicates if this Node already contains a Node. This is used for deciding newlines etc.
    has_node: bool = false,

    pub fn init(io: ?*std.Io.Writer) Node {
        return Node{ .io = io, .level = 0, .has_block = true, .has_node = true };
    }
    pub fn deinit(self: Self) void {
        if (self.level == 0)
            // The top-level block does not need any handling
            return;

        if (self.has_block) {
            if (self.has_node)
                self.indent();
            self.print("}}\n", .{});
        } else {
            self.print("\n", .{});
        }
    }

    pub fn node(self: *Self, name: []const u8) Node {
        self.ensure_block(true);
        const n = Node{ .io = self.io, .level = self.level + 1 };
        n.indent();
        n.print("[{s}]", .{name});
        return n;
    }

    pub fn attr(self: *Self, key: []const u8, value: anytype) void {
        const T = @TypeOf(value);

        if (self.has_block) {
            std.debug.print("Attributes are not allowed anymore: block was already started\n", .{});
            return;
        }

        const str = switch (@typeInfo(T)) {
            // We assume that any .pointer can be printed as a string
            .pointer => "s",
            .@"struct" => if (@hasDecl(T, "format")) "f" else "any",
            else => "any",
        };

        self.print("({s}:{" ++ str ++ "})", .{ key, value });
    }
    pub fn attr1(self: *Self, value: anytype) void {
        if (self.has_block) {
            std.debug.print("Attributes are not allowed anymore: block was already started\n", .{});
            return;
        }

        const str = switch (@typeInfo(@TypeOf(value))) {
            // We assume that any .pointer can be printed as a string
            .pointer => "s",
            else => "any",
        };

        self.print("({" ++ str ++ "})", .{value});
    }

    pub fn text(self: *Self, str: []const u8) void {
        self.ensure_block(false);
        self.print("{s}", .{str});
    }

    fn ensure_block(self: *Self, is_node: bool) void {
        if (!self.has_block)
            self.print("{{", .{});
        self.has_block = true;
        if (is_node) {
            if (!self.has_node)
                self.print("\n", .{});
            self.has_node = is_node;
        }
    }

    fn indent(self: Self) void {
        if (self.level > 1)
            for (0..self.level - 1) |_|
                self.print("  ", .{});
    }

    fn print(self: Self, comptime fmtstr: []const u8, args: anytype) void {
        if (self.io) |io| {
            io.print(fmtstr, args) catch {};
            io.flush() catch {};
        } else {
            std.debug.print(fmtstr, args);
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
