const std = @import("std");

// Twig markers are used to annotate a stream of logging data with structure.
// These markers can indicate:
// - A new twig is Entered `&#`
// - The current twig is Closed `&.`
// - A Leaf is encountered `&*`
// - A Switch to an alternative source is made `&~`
//
// A twig has the format `\n&<type><name> `
// - `\n` is a newline
// - `<type>` indicates the twig type and can be `#*~.`
// - `<indent>` is an optional indentation that can be used for human readability
// - `<name>` is the name of the twig, this cannot contain a space
//   - For a switch, the name is `parent.name`, linking the switch to a specific parent that must be active
// - ` ` is used to end the twig marker
//
// &#ci Starting CI
// &#  build Starting build
// &*    date 2025-10-27
// &.  build
// &#  ut Running unit tests
// &~    ut.a Testing a.1
// &~    ut.b Testing b.1
// &~    ut.a Testing a.2
// &~    ut.b Testing b.2
// &.  ut
// &.ci

const Output = struct {
    const Self = @This();

    valid: bool = false,
    stdout: std.fs.File = undefined,
    writer: std.fs.File.Writer = undefined,
    output: *std.Io.Writer = undefined,

    pub fn set(self: *Self, itf: *std.Io.Writer) void {
        self.output = itf;
    }
};
var output: Output = .{};

const Indent = struct {
    const Self = @This();

    level: usize = 0,

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        var data: [1][]const u8 = .{"  "};
        for (0..self.level) |_| {
            try w.writeVecAll(&data);
        }
    }
};

// &todo: Keep indent level for each `change` path that was taken
var indent: Indent = .{};

var current_name: []const u8 = &.{};

const Scope = struct {
    const Self = @This();

    name: []const u8,
    parent: []const u8 = &.{},

    pub fn init(name: []const u8) Self {
        if (!output.valid) {
            // Logging to stdout somehow hangs for UT
            // output.stdout = std.fs.File.stdout();
            output.stdout = std.fs.File.stderr();
            output.writer = output.stdout.writer(&.{});
            output.output = &output.writer.interface;
            output.valid = true;
        }
        output.output.print("\n&#{f}{s} ", .{ indent, name }) catch {};
        indent.level += 1;
        defer current_name = name;
        return Self{ .name = name, .parent = current_name };
    }
    pub fn deinit(self: *Self) void {
        indent.level -= 1;
        output.output.print("\n&.{f}{s} ", .{ indent, self.name }) catch {};
        current_name = self.parent;
    }

    pub fn scope(_: Self, name: []const u8) Self {
        return Scope.init(name);
    }

    pub fn leaf(_: Self, name: []const u8) void {
        output.output.print("\n&*{f}{s} ", .{ indent, name }) catch {};
    }

    pub fn change(self: Self, name: []const u8) void {
        output.output.print("\n&~{f}{s}.{s} ", .{ indent, self.name, name }) catch {};
    }
};

test "twig" {
    var ci = Scope.init("root");
    defer ci.deinit();

    {
        var build = Scope.init("build");
        defer build.deinit();

        build.leaf("data");
    }

    {
        var ut = ci.scope("ut");
        defer ut.deinit();

        ut.change("a");
        ut.change("b");
        ut.change("a");
    }
}
