const std = @import("std");
const ut = std.testing;

const walker = @import("walker.zig");

test {
    std.testing.refAllDecls(@This());
}
