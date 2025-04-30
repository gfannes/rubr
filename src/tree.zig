const std = @import("std");

pub const Error = error{
    UnknownNode,
};

const Id = usize;

pub fn Tree(Data: type) type {
    return struct {
        const Self = @This();
        const Ids = std.ArrayList(usize);

        const Node = struct {
            data: Data,
            child_ids: Ids,
            parent_id: ?Id = null,
        };
        const Nodes = std.ArrayList(Node);

        nodes: Nodes,
        root_ids: Ids,
        a: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator) Self {
            return Self{ .nodes = Nodes.init(a), .root_ids = Ids.init(a), .a = a };
        }
        pub fn deinit(self: *Self) void {
            for (self.nodes.items) |*node|
                node.child_ids.deinit();
            self.nodes.deinit();
            self.root_ids.deinit();
        }

        pub fn get(self: *Self, id: Id) !*Data {
            if (id >= self.nodes.items.len)
                return Error.UnknownNode;
            return &self.nodes.items[id].data;
        }

        pub fn parent(self: Self, id: Id) !?Id {
            if (id >= self.nodes.items.len)
                return Error.UnknownNode;
            return self.nodes.items[id].parent_id;
        }

        pub fn addChild(self: *Self, maybe_parent_id: ?Id) !struct { Id, *Data } {
            var ids: *Ids = undefined;
            if (maybe_parent_id) |parent_id| {
                if (parent_id >= self.nodes.items.len)
                    return Error.UnknownNode;
                ids = &self.nodes.items[parent_id].child_ids;
            } else {
                ids = &self.root_ids;
            }

            const child_id = self.nodes.items.len;
            try ids.append(child_id);

            const child = try self.nodes.addOne();
            child.child_ids = Ids.init(self.a);
            child.parent_id = maybe_parent_id;

            return .{ child_id, &child.data };
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

        pub fn dfs(self: *Self, before: bool, cb: anytype) !void {
            for (self.root_ids.items) |root_id| {
                try self.dfs_(root_id, before, cb);
            }
        }
        fn dfs_(self: *Self, id: Id, before: bool, cb: anytype) !void {
            const n = &self.nodes.items[id];
            if (before)
                try cb.call(id, &n.data);
            for (n.child_ids.items) |child_id|
                try self.dfs_(child_id, before, cb);
            if (!before)
                try cb.call(id, &n.data);
        }
    };
}

test "tree" {
    const ut = std.testing;

    const Data = struct {
        i: usize = 0,
    };

    var tree = Tree(Data).init(ut.allocator);
    defer tree.deinit();

    try ut.expectEqual(Error.UnknownNode, tree.get(0));

    const root_id, const root_data = try tree.addChild(null);
    try ut.expectEqual(0, root_id);
    root_data.i = 0;

    {
        const ch1_id, const ch1_data = try tree.addChild(root_id);
        try ut.expectEqual(1, ch1_id);
        ch1_data.i = 1;
        {
            const ch2_id, const ch2_data = try tree.addChild(ch1_id);
            _ = ch2_id;
            ch2_data.i = 2;
        }
        {
            const ch3_id, const ch3_data = try tree.addChild(ch1_id);
            _ = ch3_id;
            ch3_data.i = 3;
        }
    }

    const cb = struct {
        const Self = @This();

        tree: *Tree(Data),

        pub fn call(my: Self, id: Id, data: *Data) !void {
            std.debug.print("{} {} {}\n", .{ id, data.i, try my.tree.depth(id) });
        }
    }{ .tree = &tree };

    try tree.dfs(true, cb);
}
