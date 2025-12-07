const std = @import("std");

const DEBUG = false;
const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

const Range = struct {
    min: u64,
    max: u64,

    fn check(self: *const Range, value: u64) bool {
        return self.min <= value and value <= self.max;
    }

    fn init(str: []const u8) !Range {
        var iter = std.mem.splitScalar(u8, str, '-');

        const min = try parseInt(u64, iter.next() orelse return error.InvalidRange);
        const max = try parseInt(u64, iter.next() orelse return error.InvalidRange);

        return Range{ .min = min, .max = max };
    }

    fn attemptMergeInto(self: *const Range, other: *Range) bool {
        const self_min_intersects = other.check(self.min);
        const self_max_intersects = other.check(self.max);
        const other_min_intersects = self.check(other.min);
        const other_max_intersects = self.check(other.max);

        const intersects = self_min_intersects or self_max_intersects or other_min_intersects or other_max_intersects;

        if (!intersects) return false;

        other.min = @min(self.min, other.min);
        other.max = @max(self.max, other.max);

        return true;
    }

    fn getRange(self: *const Range) u64 {
        if (DEBUG) std.debug.print("{d}-{d}\n", .{ self.min, self.max });
        return self.max - self.min + 1;
    }
};

const Ranges = struct {
    allocator: std.mem.Allocator,
    ranges: std.ArrayList(Range),

    fn init(allocator: std.mem.Allocator) Ranges {
        return Ranges{ .allocator = allocator, .ranges = .empty };
    }

    fn deinit(self: *Ranges) void {
        self.ranges.deinit(self.allocator);
    }

    fn append(self: *Ranges, str: []const u8) !void {
        var new_range = try Range.init(str);
        var merging_range_idx: ?usize = null;

        var to_delete: std.ArrayList(usize) = .empty;
        defer to_delete.deinit(self.allocator);

        for (self.ranges.items, 0..) |*r, idx| {
            const merging_range = if (merging_range_idx) |i| &self.ranges.items[i] else &new_range;

            if (merging_range.attemptMergeInto(r)) {
                if (merging_range_idx) |i| try to_delete.append(self.allocator, i);

                _ = merging_range.getRange();
                _ = r.getRange();
                if (DEBUG) std.debug.print("\n", .{});

                merging_range_idx = idx;
            }
        }

        if (merging_range_idx == null) {
            try self.ranges.append(self.allocator, new_range);
            return;
        }

        self.ranges.orderedRemoveMany(to_delete.items);
    }

    fn getRange(self: *const Ranges) u64 {
        var sum: u64 = 0;
        for (self.ranges.items) |range| sum += range.getRange();
        return sum;
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
    defer ranges.deinit();

    var checking = false;

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

        if (!checking) try ranges.append(trimmed);

        _ = reader.peekByte() catch continue;
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    std.debug.print("\nCompleted Successfully.\nResult:\t{d}\n", .{ranges.getRange()});
}
