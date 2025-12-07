const std = @import("std");

const DEBUG = false;
const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

const Number = struct { allocator: std.mem.Allocator, value: u64, repr: *[]u8 };

const Symbol = struct { callback: fn (u64, u64) u64, repr: u8 };

const Entry = union(enum) {
    Number: Number,
    Symbol: Symbol,

    fn init(allocator: std.mem.Allocator, value: []const u8) !Entry {
        const int_value: ?u64 = try uparse(u64, value) catch null;
        if (int_value) |k| return Entry{ .Number = .{ .allocator = allocator, .value = k, .repr = try save(u8, allocator, value) } };
        return Entry{ .Symbol = .{ .callback = symbol_cb(value[0]), .repr = value[0] } };
    }

    fn free(self: *Entry) void {
        switch (self.*) {
            .Number => |n| n.allocator.free(n.repr),
            else => return,
        }
    }
};

const Grid = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(Entry),

    fn init(allocator: std.mem.Allocator) Grid {
        return Grid{ .allocator = allocator, .list = .empty };
    }

    fn parseLine(self: *Grid, line: []const u8) !void {
        var iter = std.mem.splitScalar(u8, line, ' ');

        while (iter.next()) |value| {
            const trimmed = std.mem.trim(u8, value, " \r\n\t");
            if (trimmed.len == 0) continue;

            try self.list.append(try Entry.init(self.allocator, trimmed));
        }
    }

    fn deinit(self: *Grid) void {
        for (self.list.items) |*entry| entry.free();
        self.list.deinit(self.allocator);
    }
};

fn uparse(comptime T: type, str: []const u8) !T {
    return try std.fmt.parseUnsigned(T, str, 10);
}

fn save(comptime T: type, allocator: std.mem.Allocator, value: []const T) *[]T {
    const buf = allocator.alloc(T, value.len);
    @memcpy(buf, value);
    return buf;
}

fn add(a: u64, b: u64) u64 {
    return a + b;
}

fn multiply(a: u64, b: u64) u64 {
    return a * b;
}

fn symbol_cb(symbol: u8) !fn (u64, u64) u64 {
    return switch (symbol) {
        '+' => add,
        '*' => multiply,
        else => error.InvalidSymbol,
    };
}

// TODO: partition grid into columns and apply final symbol

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(FNAME, .{});
    defer file.close();

    var buffer: [512]u8 = undefined;
    var reader_wrapper = file.reader(&buffer);
    const reader = &reader_wrapper.interface;
    const delimiter = '\n';

    var grid = Grid.init(gpa);
    defer grid.deinit();

    var sum: u64 = 0;

    while (reader.takeDelimiterExclusive(delimiter)) |item| {
        const trimmed = std.mem.trim(u8, item, " \r\n\t");

        if (trimmed.len == 0) {
            _ = reader.peekByte() catch continue;
            reader.toss(1);
            continue;
        }

        sum += 1;
        try grid.parseLine(trimmed);

        _ = reader.peekByte() catch continue;
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    std.debug.print("\nCompleted Successfully.\nResult:\t{d}\n", .{sum});
}
