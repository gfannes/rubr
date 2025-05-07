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
pub const lsp = @import("lsp.zig");
pub const index = @import("index.zig");
pub const fuzz = @import("fuzz.zig");
pub const tree = @import("tree.zig");

pub fn optional(x: anytype) ?@TypeOf(x) {
    return x;
}
pub fn none(T: type) ?T {
    return null;
}

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
    ut.refAllDecls(lsp);
    ut.refAllDecls(index);
    ut.refAllDecls(fuzz);
    ut.refAllDecls(tree);
}
