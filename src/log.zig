const std = @import("std");

pub const Error = error{FilePathTooLong};

// &improv: Support both buffered and non-buffered logging
pub const Log = struct {
    const Self = @This();
    const BufferedWriter = std.io.BufferedWriter(4096, std.fs.File.Writer);
    // const Writer = BufferedWriter.Writer;
    pub const Writer = std.fs.File.Writer;

    _file: std.fs.File = std.io.getStdOut(),
    _do_close: bool = false,
    _buffered_writer: BufferedWriter = undefined,
    _writer: Writer = undefined,
    _lvl: usize = 0,

    pub fn init(self: *Self) void {
        self.initWriter();
    }
    pub fn deinit(self: *Self) void {
        self.closeWriter() catch {};
    }

    // Any '%' in 'filepath' will be replaced with the process id
    pub fn toFile(self: *Self, filepath: []const u8) !void {
        try self.closeWriter();

        var pct_count: usize = 0;
        for (filepath) |ch| {
            if (ch == '%')
                pct_count += 1;
        }

        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const filepath_clean = if (pct_count > 0) blk: {
            var pid_buf: [32]u8 = undefined;
            const pid_str = try std.fmt.bufPrint(&pid_buf, "{}", .{std.c.getpid()});
            if (filepath.len + pct_count * pid_str.len >= buf.len)
                return Error.FilePathTooLong;
            var ix: usize = 0;
            for (filepath) |ch| {
                if (ch == '%') {
                    for (pid_str) |c| {
                        buf[ix] = c;
                        ix += 1;
                    }
                } else {
                    buf[ix] = ch;
                    ix += 1;
                }
            }
            break :blk buf[0..ix];
        } else blk: {
            break :blk filepath;
        };

        if (std.fs.path.isAbsolute(filepath_clean))
            self._file = try std.fs.createFileAbsolute(filepath_clean, .{})
        else
            self._file = try std.fs.cwd().createFile(filepath_clean, .{});
        self._do_close = true;

        self.initWriter();
    }

    pub fn setLevel(self: *Self, lvl: usize) void {
        self._lvl = lvl;
    }

    pub fn writer(self: Self) Writer {
        return self._writer;
    }

    pub fn print(self: Self, comptime fmt: []const u8, args: anytype) !void {
        try self._writer.print(fmt, args);
    }
    pub fn info(self: Self, comptime fmt: []const u8, args: anytype) !void {
        try self._writer.print("Info: " ++ fmt, args);
    }
    pub fn warning(self: Self, comptime fmt: []const u8, args: anytype) !void {
        try self._writer.print("Warning: " ++ fmt, args);
    }
    pub fn err(self: Self, comptime fmt: []const u8, args: anytype) !void {
        try self._writer.print("Error: " ++ fmt, args);
    }

    pub fn level(self: Self, lvl: usize) ?Writer {
        if (self._lvl >= lvl)
            return self._writer;
        return null;
    }

    fn initWriter(self: *Self) void {
        self._writer = self._file.writer();
        // self.buffered_writer = std.io.bufferedWriter(self.file.writer());
        // self.writer = self.buffered_writer.writer();
    }
    fn closeWriter(self: *Self) !void {
        // try self.buffered_writer.flush();
        if (self._do_close) {
            self._file.close();
            self._do_close = false;
        }
    }
};

test "log" {
    const ut = std.testing;
    try ut.expect(true);

    var log = Log{};
    log.init();
    defer log.deinit();

    try log.toFile("test.log");
    try log.print("Started log\n", .{});

    log.setLevel(2);

    for (0..4) |lvl| {
        if (log.level(lvl)) |out|
            try out.print("Level {}\n", .{lvl});
    }
}
