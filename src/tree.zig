const std = @import("std");

pub const Error = error{
    UnknownNode,
};

pub fn Tree(Data: type) type {
    return struct {
        const Self = @This();
        pub const Id = usize;
        pub const Ids = std.ArrayList(usize);

        pub const Entry = struct {
            id: usize,
            data: *Data,
        };

        const Node = struct {
            data: Data,
            child_ids: Ids,
            parent_id: ?Id = null,
        };
        const Nodes = std.ArrayList(Node);

        a: std.mem.Allocator,
        nodes: Nodes = .{},
        root_ids: Ids = .{},

        pub fn init(a: std.mem.Allocator) Self {
            return Self{ .a = a };
        }
        pub fn deinit(self: *Self) void {
            for (self.nodes.items) |*node|
                node.child_ids.deinit(self.a);
            self.nodes.deinit(self.a);
            self.root_ids.deinit(self.a);
        }

        pub fn get(self: *Self, id: Id) !*Data {
            if (id >= self.nodes.items.len)
                return Error.UnknownNode;
            return &self.nodes.items[id].data;
        }
        pub fn cget(self: Self, id: Id) !*const Data {
            if (id >= self.nodes.items.len)
                return Error.UnknownNode;
            return &self.nodes.items[id].data;
        }

        pub fn ptr(self: *Self, id: Id) *Data {
            return &self.nodes.items[id].data;
        }
        pub fn cptr(self: Self, id: Id) *const Data {
            return &self.nodes.items[id].data;
        }

        pub fn parent(self: Self, id: Id) !?Entry {
            if (id >= self.nodes.items.len)
                return Error.UnknownNode;
            if (self.nodes.items[id].parent_id) |pid|
                return Entry{ .id = pid, .data = &self.nodes.items[pid].data };
            return null;
        }

        pub fn childIds(self: Self, parent_id: Id) []const Id {
            return self.nodes.items[parent_id].child_ids.items;
        }
        pub fn childIdsMut(self: *Self, parent_id: Id) []Id {
            return self.nodes.items[parent_id].child_ids.items;
        }

        pub fn addChild(self: *Self, maybe_parent_id: ?Id) !Entry {
            var ids: *Ids = undefined;
            if (maybe_parent_id) |parent_id| {
                if (parent_id >= self.nodes.items.len)
                    return Error.UnknownNode;
                ids = &self.nodes.items[parent_id].child_ids;
            } else {
                ids = &self.root_ids;
            }

            const child_id = self.nodes.items.len;
            try ids.append(self.a, child_id);

            const child = try self.nodes.addOne(self.a);
            child.child_ids = Ids{};
            child.parent_id = maybe_parent_id;

            return Entry{ .id = child_id, .data = &child.data };
        }

        pub fn depth(self: Self, id: Id) !usize {
            if (id >= self.nodes.items.len)
                return Error.UnknownNode;
            var d: usize = 0;
            var id_ = id;
            while (true) {
                if (self.nodes.items[id_].parent_id) |pid| {
                    d += 1;
                    id_ = pid;
                } else break;
            }
            return d;
        }

        pub fn dfsAll(self: *Self, cb: anytype) CallbackErrorSet(@TypeOf(cb.*))!void {
            for (self.root_ids.items) |root_id| {
                try self.dfs(root_id, cb);
            }
        }
        pub fn dfs(self: *Self, id: Id, cb: anytype) CallbackErrorSet(@TypeOf(cb.*))!void {
            const n = &self.nodes.items[id];
            const entry = Entry{ .id = id, .data = &n.data };
            try cb.call(entry, true);
            for (n.child_ids.items) |child_id|
                try self.dfs(child_id, cb);
            try cb.call(entry, false);
        }

        pub fn each(self: *Self, cb: anytype) CallbackErrorSet(@TypeOf(cb.*))!void {
            for (self.nodes.items, 0..) |*node, id|
                try cb.call(Entry{ .id = id, .data = &node.data });
        }
    };
}

// When a callback calls some Tree func itself, Zig cannot infer the ErrorSet
// With below comptime machinery, we can express that a certain Tree func has
// the same ErrorSet as the Callback
fn CallbackErrorSet(Callback: type) type {
    const fn_info = @typeInfo(@TypeOf(Callback.call)).@"fn";
    const rt = fn_info.return_type orelse
        @compileError("Callback.call() must have a return value");

    const rt_info = @typeInfo(rt);
    if (rt_info != .error_union)
        @compileError("Callback.call() must return an error union");

    return rt_info.error_union.error_set;
}

test "tree" {
    const ut = std.testing;

    const Data = struct {
        i: usize = 0,
    };

    var tree = Tree(Data).init(ut.allocator);
    defer tree.deinit();

    try ut.expectEqual(Error.UnknownNode, tree.get(0));

    const root = try tree.addChild(null);
    try ut.expectEqual(0, root.id);
    root.data.i = 0;

    {
        const ch1 = try tree.addChild(root.id);
        try ut.expectEqual(1, ch1.id);
        ch1.data.i = 1;
        {
            const ch2 = try tree.addChild(ch1.id);
            ch2.data.i = 2;
        }
        {
            const ch3 = try tree.addChild(ch1.id);
            ch3.data.i = 3;
        }
    }

    const cb = struct {
        const Self = @This();

        const MyTree = Tree(Data);
        tree: *MyTree,

        pub fn call(my: Self, entry: MyTree.Entry, before: bool) !void {
            if (!before)
                return;
            std.debug.print("{} {} {}\n", .{ entry.id, entry.data.i, try my.tree.depth(entry.id) });
        }
    }{ .tree = &tree };

    try tree.dfsAll(&cb);
}
