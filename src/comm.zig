const std = @import("std");

const util = @import("util.zig");

// &todo: Replace id arg for read/write funcs with comptime and check for its even/oddness

// sw: SimpleWriter
// - sw.writeAll()
// sr: SimpleReader
// - sr.readAll()
// tw: TreeWriter
// - tw.writeLeaf()
// - tw.writeComposite()
// tr: TreeReader
// - tw.readLeaf()
// - tw.readComposite()

pub const Error = error{
    TooLarge,
    ExpectedId,
};

// An Id identifies the type/field that is being sedes within some parent context
// 0/1 are reserved for internal use
// Composites must be even, Leafs must be odd
pub const Id = usize;
pub const stop = 0;
pub const close = 1;
pub fn isLeaf(id: Id) bool {
    return util.isOdd(id) and id >= 3;
}
pub fn isComposite(id: Id) bool {
    return util.isEven(id) and id >= 2;
}

pub const TreeWriter = struct {
    const Self = @This();

    out: *std.Io.Writer,

    pub fn writeLeaf(self: Self, obj: anytype, id: Id) !void {
        const T = @TypeOf(obj);
        if (comptime util.isStringType(T)) {
            try self.writeLeaf(String{ .str = obj }, id);
        } else if (comptime util.isUIntType(T)) |_| {
            try self.writeLeaf(UInt{ .u = obj }, id);
        } else {
            var counter = Counter{};
            try obj.writeLeaf(&counter.interface);

            if (!isLeaf(id))
                std.debug.panic("Leaf '{s}' should have odd Id, not {},", .{ @typeName(T), id });
            try writeVLC(id, self.out);
            try writeVLC(counter.size, self.out);
            try obj.writeLeaf(self.out);
        }
    }
    pub fn writeComposite(self: Self, obj: anytype, id: Id) !void {
        if (!isComposite(id))
            std.debug.panic("Composite '{s}' should have even Id, not {},", .{ @typeName(@TypeOf(obj)), id });
        try writeVLC(id, self.out);
        try obj.writeComposite(self);
        try writeVLC(close, self.out);
        try self.out.flush();
    }
};

pub const TreeReader = struct {
    const Self = @This();
    const Header = struct {
        id: Id,
        size: usize = 0,
    };

    in: *std.Io.Reader,
    header: ?Header = null,

    // Returns false if there is a Id mismatch
    pub fn readLeaf(self: *Self, obj: anytype, id: Id, ctx: anytype) !bool {
        const T = @TypeOf(obj.*);
        if (comptime util.isStringType(T)) {
            var string = String{};
            const ret = try self.readLeaf(&string, id, ctx);
            obj.* = string.str;
            return ret;
        } else if (comptime util.isUIntType(T)) |_| {
            var uint = UInt{};
            const ret = try self.readLeaf(&uint, id, ctx);
            obj.* = std.math.cast(T, uint.u) orelse return Error.TooLarge;
            return ret;
        } else {
            const header = try self.readHeader();

            if (!isLeaf(header.id))
                return false;
            if (id != header.id)
                return false;

            const size = header.size;
            self.header = null;

            try obj.readLeaf(size, self.in, ctx);

            return true;
        }
    }

    // Returns false if there is a Id mismatch
    pub fn readComposite(self: *Self, obj: anytype, id: Id) !bool {
        {
            const header = try self.readHeader();

            if (!isComposite(header.id)) {
                std.debug.print("Expected composite, received {}\n", .{header.id});
                return false;
            }
            if (id != header.id) {
                std.debug.print("Expected {}, found {}\n", .{ id, header.id });
                return false;
            }
            self.header = null;
        }

        try obj.readComposite(self);

        {
            const header = try self.readHeader();
            if (header.id != close) {
                std.debug.print("Expected close ({}), found {}\n", .{ close, header.id });
                return false;
            }
            self.header = null;
        }

        return true;
    }

    pub fn readHeader(self: *Self) !Header {
        if (self.header) |header|
            return header;

        const id = try readVLC(Id, self.in);
        const size = if (isLeaf(id)) try readVLC(usize, self.in) else 0;
        const header = Header{ .id = id, .size = size };
        self.header = header;
        return header;
    }

    pub fn isClose(self: *Self) !bool {
        const header = try self.readHeader();
        return header.id == close;
    }
};

// Util for working with a SimpleWriter
pub fn writeUInt(u: anytype, io: *std.Io.Writer) !void {
    const T = @TypeOf(u);
    const len = (@bitSizeOf(T) - @clz(u) + 7) / 8;
    var buffer: [8]u8 = undefined;
    var uu: u128 = u;
    for (0..len) |ix| {
        buffer[len - ix - 1] = @truncate(uu);
        uu >>= 8;
    }
    try io.writeAll(buffer[0..len]);
}
pub fn readUInt(T: type, size: usize, io: *std.Io.Reader) !T {
    if (size > @sizeOf(T))
        return Error.TooLarge;
    var buffer: [@sizeOf(T)]u8 = undefined;
    const slice = buffer[0..size];
    try io.readSliceAll(slice);
    var u: T = 0;
    for (slice) |byte| {
        u <<= 8;
        u |= @as(T, byte);
    }
    return u;
}

pub fn writeVLC(u: anytype, io: *std.Io.Writer) !void {
    var uu: u128 = u;
    const max_byte_count = (@bitSizeOf(@TypeOf(uu)) + 6) / 7;

    var buffer: [max_byte_count]u8 = undefined;
    const len = @max((@bitSizeOf(@TypeOf(uu)) - @clz(uu) + 6) / 7, 1);
    for (0..len) |ix| {
        const data: u7 = @truncate(uu);
        uu >>= 7;

        const msbit: u8 = if (ix == 0) 0x00 else 0x80;

        buffer[len - ix - 1] = msbit | @as(u8, data);
    }

    try io.writeAll(buffer[0..len]);
}
// Note: If reading a VLC of type T fails (eg., due to size constraint), there is no roll-back on 'sr'
pub fn readVLC(T: type, io: *std.Io.Reader) !T {
    var uu: u128 = 0;
    const max_byte_count = (@bitSizeOf(@TypeOf(uu)) + 6) / 7;
    for (0..max_byte_count) |ix| {
        var ary: [1]u8 = undefined;
        try io.readSliceAll(&ary);
        const byte = ary[0];
        const data: u7 = @truncate(byte);
        uu <<= 7;
        uu |= @as(u128, data);

        // Check msbit to see if we need to continue
        const msbit = byte >> 7;
        if (msbit == 0)
            break;

        if (ix + 1 == max_byte_count)
            return Error.TooLarge;
    }
    return std.math.cast(T, uu) orelse return Error.TooLarge;
}

// SimpleWriter that counts the byte size of a leaf
const Counter = struct {
    const Self = @This();
    const vtable: std.Io.Writer.VTable = .{ .drain = drain };

    size: usize = 0,
    interface: std.Io.Writer = .{ .vtable = &vtable, .buffer = &.{} },

    pub fn writeAll(self: *Self, ary: []const u8) !void {
        self.size += ary.len;
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, _: usize) std.Io.Writer.Error!usize {
        std.debug.print("drain {} {} {s} {*}\n", .{ data.len, data[0].len, data[0], data[0].ptr });
        const self: *Counter = @fieldParentPtr("interface", w);
        self.size += data[0].len;
        return data[0].len;
    }
};

// Wrapper classes for primitives to support obj.writeLeaf()
const String = struct {
    const Self = @This();
    str: []const u8 = &.{},
    fn writeLeaf(self: Self, io: *std.Io.Writer) !void {
        try io.writeAll(self.str);
    }
    fn readLeaf(self: *Self, size: usize, io: *std.Io.Reader, a: std.mem.Allocator) !void {
        const slice = try a.alloc(u8, size);
        try io.readSliceAll(slice);
        self.str = slice;
    }
};
const UInt = struct {
    const Self = @This();
    u: u128 = 0,
    fn writeLeaf(self: Self, io: *std.Io.Writer) !void {
        try writeUInt(self.u, io);
    }
    fn readLeaf(self: *Self, size: usize, io: *std.Io.Reader, _: void) !void {
        self.u = try readUInt(@TypeOf(self.u), size, io);
    }
};

test "leaf" {
    const ut = std.testing;

    const filename = "leaf.dat";

    // Create a file with some leaf data
    {
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var writer = file.writer(&buffer);
        defer writer.interface.flush() catch {};

        const tw = TreeWriter{ .out = &writer.interface };
        try tw.writeLeaf(@as(u32, 1234), 3);
        try tw.writeLeaf("string", 3);
    }

    // Read the content using wrapper classes
    {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var reader = file.reader(&buffer);

        var tr = TreeReader{ .in = &reader.interface };

        var uint = UInt{};
        try ut.expect(try tr.readLeaf(&uint, 3, {}));
        try ut.expectEqual(uint.u, 1234);

        var string = String{};
        try ut.expect(try tr.readLeaf(&string, 3, ut.allocator));
        defer ut.allocator.free(string.str);
        try ut.expectEqualStrings("string", string.str);
    }

    // Read the content using primitive data types
    {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var reader = file.reader(&buffer);

        var tr = TreeReader{ .in = &reader.interface };

        var u: u32 = undefined;
        try ut.expect(try tr.readLeaf(&u, 3, {}));
        try ut.expectEqual(u, 1234);

        var string = String{};
        try ut.expect(try tr.readLeaf(&string, 3, ut.allocator));
        defer ut.allocator.free(string.str);
        try ut.expectEqualStrings("string", string.str);
    }
}

test "composite" {
    const Composite = struct {
        const Self = @This();
        str: []const u8 = "composite",
        fn writeComposite(self: Self, tw: TreeWriter) !void {
            try tw.writeLeaf(self.str, 3);
        }
        fn readComposite(self: *Self, tr: TreeReader, a: std.mem.Allocator) !void {
            try tr.readLeaf(&self.str, a, 3);
        }
    };

    const file = try std.fs.cwd().createFile("composite.dat", .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var writer = file.writer(&buffer);
    defer writer.interface.flush() catch {};

    const tw = TreeWriter{ .out = &writer.interface };

    const comp = Composite{};
    try tw.writeComposite(comp, 2);
}
