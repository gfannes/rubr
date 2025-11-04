const std = @import("std");

pub fn homeDir(a: std.mem.Allocator) ![]u8 {
    // &todo: Support Windows
    return try std.process.getEnvVarOwned(a, "HOME");
}

test "fs" {
    const ut = std.testing;

    const home = try homeDir(ut.allocator);
    defer ut.allocator.free(home);

    std.debug.print("home: {s}\n", .{home});
}
