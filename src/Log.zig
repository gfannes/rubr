const std = @import("std");

pub const Error = error{FilePathTooLong};

// &improv: Support both buffered and non-buffered logging
const Self = @This();

const Autoclean = struct {
    buffer: [std.fs.max_path_bytes]u8 = undefined,
    filepath: []const u8 = &.{},
};

_do_close: bool = false,
_file: std.fs.File = undefined,

_buffer: [1024]u8 = undefined,
_writer: std.fs.File.Writer = undefined,

_io: *std.Io.Writer = undefined,

_lvl: usize = 0,

_autoclean: ?Autoclean = null,

pub fn init(self: *Self) void {
    self._file = std.fs.File.stdout();
    self.initWriter();
}
pub fn deinit(self: *Self) void {
    self.closeWriter() catch {};
    if (self._autoclean) |autoclean| {
        std.fs.deleteFileAbsolute(autoclean.filepath) catch {};
    }
}

// Any '%' in 'filepath' will be replaced with the process id
const Options = struct {
    autoclean: bool = false,
};
pub fn toFile(self: *Self, filepath: []const u8, options: Options) !void {
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

    if (std.fs.path.isAbsolute(filepath_clean)) {
        self._file = try std.fs.createFileAbsolute(filepath_clean, .{});
        if (options.autoclean) {
            self._autoclean = undefined;
            const fp = self._autoclean.?.buffer[0..filepath_clean.len];
            std.mem.copyForwards(u8, fp, filepath_clean);
            if (self._autoclean) |*autoclean| {
                autoclean.filepath = fp;
            }
        }
    } else {
        self._file = try std.fs.cwd().createFile(filepath_clean, .{});
    }
    self._do_close = true;

    self.initWriter();
}

pub fn setLevel(self: *Self, lvl: usize) void {
    self._lvl = lvl;
}

pub fn writer(self: Self) *std.Io.Writer {
    return self._io;
}

pub fn print(self: Self, comptime fmtstr: []const u8, args: anytype) !void {
    try self._io.print(fmtstr, args);
    try self._io.flush();
}
pub fn info(self: Self, comptime fmtstr: []const u8, args: anytype) !void {
    try self.print("Info: " ++ fmtstr, args);
}
pub fn warning(self: Self, comptime fmtstr: []const u8, args: anytype) !void {
    try self.print("Warning: " ++ fmtstr, args);
}
pub fn err(self: Self, comptime fmtstr: []const u8, args: anytype) !void {
    try self.print("Error: " ++ fmtstr, args);
}

pub fn level(self: Self, lvl: usize) ?*std.Io.Writer {
    if (self._lvl >= lvl)
        return self._io;
    return null;
}

fn initWriter(self: *Self) void {
    self._writer = self._file.writer(&self._buffer);
    self._io = &self._writer.interface;
}
fn closeWriter(self: *Self) !void {
    try self._io.flush();
    if (self._do_close) {
        self._file.close();
        self._do_close = false;
    }
}

test "log" {
    const ut = std.testing;
    try ut.expect(true);

    var log = Self{};
    log.init();
    defer log.deinit();

    try log.toFile("test.log", .{});
    try log.print("Started log\n", .{});

    log.setLevel(2);

    for (0..4) |lvl| {
        if (log.level(lvl)) |out|
            try out.print("Level {}\n", .{lvl});
    }
}
