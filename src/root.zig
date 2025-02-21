const std = @import("std");
const ut = std.testing;

const walker = @import("walker.zig");
const ignore = @import("walker/ignore.zig");
const strange = @import("strange.zig");
const glob = @import("glob.zig");

test {
    ut.refAllDecls(@This());
    ut.refAllDecls(walker);
    ut.refAllDecls(ignore);
    ut.refAllDecls(strange);
    ut.refAllDecls(glob);
}
