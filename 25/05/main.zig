const std = @import("std");

const DEBUG = false;
const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

const PaperNode = struct {
    context: *const PaperArray,
    x: i64,
    y: i64,

    fn init(context: *const PaperArray, index: usize) PaperNode {
        const x = @as(i64, @intCast(index % context.width));
        const y = @as(i64, @intCast(index / context.width));

        return PaperNode{ .context = context, .x = x, .y = y };
    }

    fn getIndex(self: *const PaperNode) ?usize {
        const oob_x = self.x < 0 or self.x >= self.context.width;
        const oob_y = self.y < 0 or self.y >= self.context.grid.items.len / self.context.width;
        const oob = oob_x or oob_y;

        if (oob) return null;

        return (@as(usize, @intCast(self.y)) * self.context.width) + @as(usize, @intCast(self.x));
    }

    fn getValue(self: *const PaperNode) ?bool {
        return self.context.grid.items[self.getIndex() orelse return null];
    }

    fn offset(self: *const PaperNode, dx: i64, dy: i64) PaperNode {
        return PaperNode{ .context = self.context, .x = self.x + dx, .y = self.y + dy };
    }

    fn next(self: *PaperNode) !PaperNode {
        const idx = (self.getIndex() orelse return error.InvalidNode) + 1;

        if (idx >= self.context.grid.items.len) return error.NoneLeft;

        const new_node = PaperNode.init(self.context, idx);

        self.x = new_node.x;
        self.y = new_node.y;

        return self.*;
    }
};

const PaperArray = struct {
    allocator: std.mem.Allocator,
    grid: std.ArrayList(bool),
    width: usize = 0,

    fn init(allocator: std.mem.Allocator) PaperArray {
        return PaperArray{ .allocator = allocator, .grid = .empty };
    }

    fn parseAppendRow(self: *PaperArray, row: []const u8) !void {
        if (row.len == 0) return error.EmptyRow;

        if (self.width == 0) {
            self.width = row.len;
        } else if (self.width != row.len) {
            return error.WidthMismatch;
        }

        for (row) |item| try self.grid.append(self.allocator, try parseToBool(item));
    }

    fn deinit(self: *const PaperArray) void {
        self.grid.deinit(self.allocator);
    }

    fn evaluate(self: *const PaperArray) u64 {
        var node = PaperNode.init(self, 0);

        var sum: u64 = 0;
        while (node.next()) |*n| {
            const removable = criteria(n);
            sum += @intFromBool(removable);
            if (removable) self.grid.items[n.getIndex().?] = false;
        } else |_| return sum;
    }
};

fn criteria(node: *const PaperNode) bool {
    if (!(node.getValue() orelse false)) return false;

    const check: [8]PaperNode = .{
        node.offset(-1, -1),
        node.offset(0, -1),
        node.offset(1, -1),
        node.offset(-1, 0),
        // node.offset(0, 0), // self
        node.offset(1, 0),
        node.offset(-1, 1),
        node.offset(0, 1),
        node.offset(1, 1),
    };

    if (DEBUG) std.debug.print("\n{d}\t", .{node.getIndex() orelse 999});

    var sum: i8 = 0;
    for (check) |n| {
        sum += bOptToNumber(n.getValue());
        if (DEBUG) std.debug.print("{d} ", .{sum});
    }

    return sum < 4;
}

fn bOptToNumber(value: ?bool) i8 {
    return if (value orelse false) 1 else 0;
}

fn parseToBool(char: u8) !bool {
    return switch (char) {
        '@' => true,
        '.' => false,
        else => error.InvalidCellState,
    };
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(FNAME, .{});
    defer file.close();

    var buffer: [512]u8 = undefined;
    var reader_wrapper = file.reader(&buffer);
    const reader = &reader_wrapper.interface;
    const delimiter = '\n';

    var arr = PaperArray.init(gpa);

    while (reader.takeDelimiterExclusive(delimiter)) |item| {
        const trimmed = std.mem.trim(u8, item, " \r\n\t");

        if (DEBUG) std.debug.print("<{s}>\n", .{trimmed});

        try arr.parseAppendRow(trimmed);

        _ = reader.peekByte() catch continue;
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    var sum: u64 = arr.evaluate();
    var last_sum: u64 = sum;

    while (last_sum > 0) {
        last_sum = arr.evaluate();
        sum += last_sum;
        std.debug.print("Removed {d} rolls.\n", .{last_sum});
    }

    std.debug.print("\nCompleted Successfully.\nResult:\t{d}\n", .{sum});
}
