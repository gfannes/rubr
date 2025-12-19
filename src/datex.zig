const std = @import("std");
const builtin = @import("builtin");

const SYSTEMTIME = extern struct {
    wYear: u16,
    wMonth: u16,
    wDayOfWeek: u16,
    wDay: u16,
    wHour: u16,
    wMinute: u16,
    wSecond: u16,
    wMilliseconds: u16,
};
// You can call any Win32 API directly via `extern` + `callconv(.winapi)`. :contentReference[oaicite:1]{index=1}
extern "kernel32" fn GetLocalTime(lpSystemTime: *SYSTEMTIME) callconv(.winapi) void;
extern "kernel32" fn GetSystemTime(lpSystemTime: *SYSTEMTIME) callconv(.winapi) void;

pub const Date = struct {
    const Self = @This();

    epoch_day: std.time.epoch.EpochDay,

    pub fn today() !Date {
        var esecs = std.time.epoch.EpochSeconds{ .secs = 0 };
        if (builtin.os.tag == .windows) {
            var st: SYSTEMTIME = undefined;
            // Local time (uses current Windows time zone settings). :contentReference[oaicite:2]{index=2}
            GetLocalTime(&st);
            std.debug.print(
                "local: {d:04}-{d:02}-{d:02} {d:02}:{d:02}:{d:02}.{d:03}\n",
                .{ st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds },
            );
        } else {
            const time = try std.posix.clock_gettime(.REALTIME);
            esecs.secs = @intCast(time.sec);
        }
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
