const std = @import("std");
const ut = std.testing;

pub const glb = @import("glb.zig");
pub const log = @import("log.zig");
pub const slc = @import("slc.zig");
pub const opt = @import("opt.zig");
pub const idx = @import("idx.zig");
pub const strng = @import("strng.zig");
pub const walker = @import("walker.zig");
pub const ignore = @import("walker/ignore.zig");
pub const strings = @import("strings.zig");
pub const profile = @import("profile.zig");
pub const naft = @import("naft.zig");
pub const cli = @import("cli.zig");
pub const lsp = @import("lsp.zig");
pub const fuzz = @import("fuzz.zig");
pub const tree = @import("tree.zig");
pub const algo = @import("algo.zig");
pub const util = @import("util.zig");
pub const comm = @import("comm.zig");

test {
    ut.refAllDecls(@This());
    ut.refAllDecls(glb);
    ut.refAllDecls(log);
    ut.refAllDecls(slc);
    ut.refAllDecls(opt);
    ut.refAllDecls(idx);
    ut.refAllDecls(strng);
    ut.refAllDecls(walker);
    ut.refAllDecls(ignore);
    ut.refAllDecls(strings);
    ut.refAllDecls(profile);
    ut.refAllDecls(naft);
    ut.refAllDecls(cli);
    ut.refAllDecls(lsp);
    ut.refAllDecls(fuzz);
    ut.refAllDecls(tree);
    ut.refAllDecls(algo);
    ut.refAllDecls(util);
    ut.refAllDecls(comm);
}
