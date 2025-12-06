const std = @import("std");

const DEBUG = false;

const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

const ID = struct {
    start: u64,
    end: u64,
    sum: u128 = 0,
};

fn nextRepeatedID(id_num: u64) !u64 {
    var buf: [20]u8 = undefined;
    var id_buf: [20]u8 = undefined;

    const id = try std.fmt.bufPrint(id_buf[0..], "{d}", .{id_num});

    if (id.len % 2 == 1) {
        const next_magnitude = try std.math.powi(u64, 10, id.len);
        return try nextRepeatedID(next_magnitude);
    }

    const rep_size = id.len / 2;

    const first_half = try std.fmt.parseUnsigned(u64, id[0..rep_size], 10);
    const second_half = try std.fmt.parseUnsigned(u64, id[rep_size..], 10);
    const next_pattern = if (first_half >= second_half) first_half else first_half + 1;
    const result = try std.fmt.bufPrint(buf[0..], "{d}{d}", .{ next_pattern, next_pattern });

    return try std.fmt.parseUnsigned(u64, result, 10);
}

fn parseIdRange(str: []const u8) !ID {
    const dash = std.mem.indexOf(u8, str, "-") orelse return error.NoDashFound;
    const start = try std.fmt.parseUnsigned(u64, str[0..dash], 10);
    const end = try std.fmt.parseUnsigned(u64, str[dash + 1 ..], 10);
    return ID{ .start = start, .end = end };
}

fn findInvalids(id: *ID) !void {
    var next_repeated = try nextRepeatedID(id.start);
    if (DEBUG) std.debug.print("\n<{d}-{d}>\n", .{ id.start, id.end });

    while (next_repeated <= id.end) {
        id.sum += next_repeated;
        if (DEBUG) std.debug.print("{d}\n", .{next_repeated});
        next_repeated = try nextRepeatedID(next_repeated + 1);
    }
}

pub fn main() !void {
    const file = try std.fs.cwd().openFile(FNAME, .{});

    defer file.close();

    var buffer: [512]u8 = undefined;
    var reader_wrapper = file.reader(&buffer);
    const reader = &reader_wrapper.interface;
    const delimiter = ',';

    var sum: u128 = 0;

    while (reader.takeDelimiterExclusive(delimiter)) |item| {
        const trimmed = std.mem.trim(u8, item, " \r\n\t");
        var id = try parseIdRange(trimmed);

        try findInvalids(&id);

        sum += id.sum;

        _ = reader.peekByte() catch continue;
        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    std.debug.print("Completed Successfully.\nResult:\t{d}\n", .{sum});
}
