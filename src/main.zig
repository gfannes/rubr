const std = @import("std");
const ut = std.testing;

const walker = @import("walker.zig");

pub fn main() !void {}

test {
    // Necessary to ensure all UTs from imported modules are run
    ut.refAllDecls(@This());
}
