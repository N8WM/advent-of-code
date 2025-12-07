const std = @import("std");

const DEBUG = false;
const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

const Range = struct {
    min: u64,
    max: u64,

    fn check(self: *const Range, value: u64) bool {
        const condition = self.min <= value and value <= self.max;

        if (DEBUG and condition) std.debug.print("\t{d}<={d}<={d}\n", .{ self.min, value, self.max });

        return condition;
    }

    fn init(str: []const u8) !Range {
        var iter = std.mem.splitScalar(u8, str, '-');

        const min = try parseInt(u64, iter.next() orelse return error.InvalidRange);
        const max = try parseInt(u64, iter.next() orelse return error.InvalidRange);

        return Range{ .min = min, .max = max };
    }
};

const Ranges = struct {
    allocator: std.mem.Allocator,
    ranges: std.ArrayList(Range),

    fn init(allocator: std.mem.Allocator) Ranges {
        return Ranges{ .allocator = allocator, .ranges = .empty };
    }

    fn append(self: *Ranges, str: []const u8) !void {
        try self.ranges.append(self.allocator, try Range.init(str));
    }

    fn checkStr(self: *const Ranges, str: []const u8) !bool {
        const value = try parseInt(u64, str);

        for (self.ranges.items) |range| if (range.check(value)) return true;

        return false;
    }
};

fn parseInt(comptime T: type, string: []const u8) !T {
    return try std.fmt.parseInt(T, string, 10);
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(FNAME, .{});
    defer file.close();

    var buffer: [512]u8 = undefined;
    var reader_wrapper = file.reader(&buffer);
    const reader = &reader_wrapper.interface;
    const delimiter = '\n';

    var ranges = Ranges.init(gpa);
    var checking = false;
    var sum: u64 = 0;

    while (reader.takeDelimiterExclusive(delimiter)) |item| {
        const trimmed = std.mem.trim(u8, item, " \r\n\t");

        if (trimmed.len == 0) {
            checking = true;
            if (DEBUG) std.debug.print("-----\n", .{});

            _ = reader.peekByte() catch continue;
            reader.toss(1);

            continue;
        }

        if (DEBUG) std.debug.print("<{s}>\n", .{trimmed});

        if (checking)
            sum += @intFromBool(try ranges.checkStr(trimmed))
        else
            try ranges.append(trimmed);

        _ = reader.peekByte() catch continue;
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    std.debug.print("\nCompleted Successfully.\nResult:\t{d}\n", .{sum});
}
