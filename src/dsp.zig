const std = @import("std");

pub const Error = error{
    WrongSignalSize,
};

pub const IQ = struct {
    const Self = @This();

    a: std.mem.Allocator,
    signal_count: usize,
    freq_count: usize,
    oscillators: []Oscillator,
    estimators: []Estimator,
    normalize: u32 = 0,

    pub fn init(a: std.mem.Allocator, signal_count: usize, freqs: []const f64, fs: f64, response_time: f64) !Self {
        const oscillators = try a.alloc(Oscillator, freqs.len);
        for (freqs, oscillators) |freq, *oscillator| {
            oscillator.init(freq, fs, response_time);
        }
        const estimators = try a.alloc(Estimator, signal_count * freqs.len);
        return .{
            .a = a,
            .signal_count = signal_count,
            .freq_count = freqs.len,
            .oscillators = oscillators,
            .estimators = estimators,
        };
    }
    pub fn deinit(self: *Self) void {
        self.a.free(self.oscillators);
        self.a.free(self.estimators);
    }

    pub fn process(self: *Self, signal: []const f64) !void {
        if (signal.len != self.signal_count)
            return error.WrongSignalSize;

        for (signal, 0..) |v, six0| {
            for (self.oscillators, 0..) |oscillator, oix0| {
                const estimator = &self.estimators[six0 * self.freq_count + oix0];
                estimator.process(v, oscillator);
            }
        }

        for (self.oscillators) |*oscillator|
            oscillator.update();

        self.normalize += 1;
        if (self.normalize >= 128) {
            self.normalize = 0;
            for (self.oscillators) |*oscillator|
                oscillator.normalize();
        }
    }
};

const Estimator = struct {
    const Self = @This();

    i: f64 = 0.0,
    q: f64 = 0.0,

    fn process(self: *Self, v: f64, oscillator: Oscillator) void {
        const i = 2.0 * v * oscillator.value.re;
        const q = -2.0 * v * oscillator.value.im;
        self.i += oscillator.alpha * (i - self.i);
        self.q += oscillator.alpha * (q - self.q);
    }

    fn amplitude(self: Self) f64 {
        return @sqrt(self.i * self.i + self.q * self.q);
    }
    fn phase(self: Self) f64 {
        return std.math.atan2(self.q, self.i);
    }
};

const Oscillator = struct {
    const Self = @This();
    const Complex = std.math.Complex(f64);

    value: Complex,
    rot: Complex,
    alpha: f64,

    fn init(self: *Self, freq: f64, fs: f64, response_time: f64) void {
        self.value = Complex.init(1.0, 0.0);
        self.rot = std.math.complex.exp(Complex.init(0.0, std.math.tau * freq / fs));
        self.alpha = 1.0 - @exp(-1.0 / (fs * response_time));
    }

    fn update(self: *Self) void {
        self.value = self.value.mul(self.rot);
    }

    fn normalize(self: *Self) void {
        // Newton approximation of 1/sqrt(s) ~= (3-s)/2 when s ~= 1
        const s = self.value.re * self.value.re + self.value.im * self.value.im;
        const scale = 0.5 * (3.0 - s);
        self.value.re *= scale;
        self.value.im *= scale;
    }
};

test "dsp" {
    const ut = std.testing;

    const freqs: [3]f64 = .{ 30.0, 50.0, 70.0 };
    const fs = 48000.0;

    var iq = try IQ.init(ut.allocator, 1, &freqs, fs, 0.5);
    defer iq.deinit();
    const dt = 1.0 / fs;

    for (0..96000) |ix0| {
        const time = @as(f64, @floatFromInt(ix0)) * dt;
        const signal = 0.1 * @cos(std.math.tau * freqs[0] * time + 0.4) + 0.2 * @cos(std.math.tau * freqs[1] * time + 0.5) + 0.3 * @cos(std.math.tau * freqs[2] * time + 0.6);

        try iq.process((&signal)[0..1]);

        for (iq.estimators) |estimator| {
            std.debug.print("| {:.4} {:.4} ", .{ estimator.amplitude(), estimator.phase() });
        }
        std.debug.print("|\n", .{});
    }

    try ut.expect(true);
}
