const std = @import("std");
const ut = std.testing;

pub const walker = @import("walker.zig");
pub const ignore = @import("walker/ignore.zig");
pub const strange = @import("strange.zig");
pub const strings = @import("strings.zig");
pub const glob = @import("glob.zig");
pub const slice = @import("slice.zig");
pub const profile = @import("profile.zig");
pub const naft = @import("naft.zig");
pub const cli = @import("cli.zig");
pub const log = @import("log.zig");

test {
    ut.refAllDecls(@This());
    ut.refAllDecls(walker);
    ut.refAllDecls(ignore);
    ut.refAllDecls(strange);
    ut.refAllDecls(strings);
    ut.refAllDecls(glob);
    ut.refAllDecls(slice);
    ut.refAllDecls(profile);
    ut.refAllDecls(naft);
    ut.refAllDecls(cli);
    ut.refAllDecls(log);
}
