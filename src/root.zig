const std = @import("std");
const ut = std.testing;

pub const walker = @import("walker.zig");
pub const ignore = @import("walker/ignore.zig");
pub const strange = @import("strange.zig");
pub const glob = @import("glob.zig");
pub const slice = @import("slice.zig");

test {
    ut.refAllDecls(@This());
    ut.refAllDecls(walker);
    ut.refAllDecls(ignore);
    ut.refAllDecls(strange);
    ut.refAllDecls(glob);
    ut.refAllDecls(slice);
}
