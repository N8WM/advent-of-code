const std = @import("std");

const DEBUG = false;
const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

// Batteries Per Array
const BPA_NEEDED = 12;

const BatteryArray = struct {
    joltages: []u8,
    joltage_str: []u8,
    allocator: std.mem.Allocator,

    fn new(allocator: std.mem.Allocator, joltages: []const u8) !BatteryArray {
        const result = BatteryArray{ .joltages = try allocator.alloc(u8, joltages.len), .joltage_str = try allocator.alloc(u8, joltages.len), .allocator = allocator };

        for (result.joltages, 0..) |*jt, idx| jt.* = try uparse(u8, joltages[idx .. idx + 1]);
        @memcpy(result.joltage_str, joltages);

        return result;
    }

    fn free(self: *const BatteryArray) void {
        self.allocator.free(self.joltages);
        self.allocator.free(self.joltage_str);
    }

    fn optimize(self: *const BatteryArray, buf: []u8) ![]u8 {
        if (buf.len > self.joltages.len) return error.NotEnoughBatteries;

        const last_sig_idx = self.joltages.len - buf.len + 1;
        const sig_candidates = self.joltages[0..last_sig_idx];
        const best_sig_idx = umax_idx(sig_candidates);

        buf[0] = best_sig_idx;

        if (buf.len > 1) {
            const next_fig_idx = best_sig_idx + 1;
            const next_fig_joltage_str = self.joltage_str[next_fig_idx..];
            const next_battery_array = try BatteryArray.new(self.allocator, next_fig_joltage_str);
            const next_buf = buf[1..];
            _ = try next_battery_array.optimize(next_buf);
            for (next_buf) |*batt_id| batt_id.* += next_fig_idx;
            next_battery_array.free();
        }

        return buf;
    }
};

fn uparse(comptime T: type, str: []const u8) !T {
    return try std.fmt.parseUnsigned(T, str, 10);
}

fn umax_idx(ints: []u8) u8 {
    var best_idx: u8 = 0;
    for (0..ints.len) |idx| best_idx = if (ints[idx] > ints[best_idx]) @intCast(idx) else best_idx;
    return best_idx;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(FNAME, .{});
    defer file.close();

    var buffer: [512]u8 = undefined;
    var reader_wrapper = file.reader(&buffer);
    const reader = &reader_wrapper.interface;
    const delimiter = '\n';

    var sum: u64 = 0;

    while (reader.takeDelimiterExclusive(delimiter)) |item| {
        const trimmed = std.mem.trim(u8, item, " \r\n\t");

        if (DEBUG) std.debug.print("<{s}>\t", .{trimmed});

        var battery_array = try BatteryArray.new(gpa, trimmed);
        defer battery_array.free();

        var opt_buf = try gpa.alloc(u8, BPA_NEEDED);
        var opt_buf_str = try gpa.alloc(u8, BPA_NEEDED);
        defer gpa.free(opt_buf);
        defer gpa.free(opt_buf_str);

        const optimal = try battery_array.optimize(opt_buf[0..]);

        for (opt_buf_str[0..], 0..) |*batt, idx| {
            batt.* = battery_array.joltage_str[optimal[idx]];
        }

        if (DEBUG) std.debug.print("{s}\n", .{opt_buf_str});

        const joltage = try uparse(u64, opt_buf_str);
        sum += joltage;

        _ = reader.peekByte() catch continue;
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    std.debug.print("Completed Successfully.\nResult:\t{d}\n", .{sum});
}
