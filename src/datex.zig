const std = @import("std");

pub const Date = struct {
    const Self = @This();

    epoch_day: std.time.epoch.EpochDay,

    pub fn today() !Date {
        const time = try std.posix.clock_gettime(.REALTIME);
        const esecs = std.time.epoch.EpochSeconds{ .secs = @intCast(time.sec) };
        return .{ .epoch_day = esecs.getEpochDay() };
    }

    pub fn fromEpochDays(days: u47) Date {
        return Date{ .epoch_day = std.time.epoch.EpochDay{ .day = days } };
    }

    pub fn yearDay(self: Self) std.time.epoch.YearAndDay {
        return self.epoch_day.calculateYearDay();
    }

    pub fn format(self: Self, w: *std.Io.Writer) !void {
        const yd = self.epoch_day.calculateYearDay();
        const md = yd.calculateMonthDay();
        try w.print("{:04}{:02}{:02}", .{ yd.year, md.month.numeric(), md.day_index + 1 });
    }
};

test "datex" {
    const today = try Date.today();
    std.debug.print("{f}\n", .{today});
}
