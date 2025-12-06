const std = @import("std");

const DEBUG = false;

const FNAME = if (DEBUG) "input_test.txt" else "input.txt";

const ID = struct {
    start: u64,
    end: u64,
    sum: u128 = 0,
};

fn ustring(buf: []u8, int: u64) []u8 {
    return std.fmt.bufPrint(buf, "{d}", .{int}) catch unreachable;
}

fn uparse(str: []u8) !u64 {
    return try std.fmt.parseUnsigned(u64, str, 10);
}

fn repeat(buf: []u8, str: []u8, count: u64) []u8 {
    const slice = buf[0 .. str.len * count];

    for (slice, 0..) |*char, idx| {
        char.* = str[idx % str.len];
    }

    return slice;
}

fn numlen(len: u64) u64 {
    return std.math.powi(u64, 10, len - 1) catch unreachable;
}

fn nextRepeatedID(id: u64, max: u64) !?u64 {
    var buf: [20]u8 = undefined;

    var id_str = ustring(buf[0..], id);
    var id_len = id_str.len;

    while (true) {
        if (numlen(id_len) > max) return null;

        var best: u64 = 0;

        for (2..id_len + 1) |reps| {
            if (id_len % reps != 0) continue;

            const pattern_len = id_len / reps;
            const pattern_str = id_str[0..pattern_len];
            const pattern_int = try uparse(pattern_str);

            const candidate = repeat(buf[0..], pattern_str, reps);
            const candidate_int = try uparse(candidate);

            if (candidate_int > max) continue;

            if (candidate_int >= id) {
                const is_better = best == 0 or candidate_int < best;
                best = if (is_better) candidate_int else best;
            } else {
                const next_pattern_int = pattern_int + 1;
                const next_pattern_str = ustring(buf[0..], next_pattern_int);

                if (next_pattern_str.len != pattern_len) continue;

                const next_candidate = repeat(buf[0..], next_pattern_str, reps);
                const next_candidate_int = try uparse(next_candidate);

                if (next_candidate_int < id or next_candidate_int > max) continue;

                const is_better = best == 0 or next_candidate_int < best;
                best = if (is_better) next_candidate_int else best;
            }
        }

        if (best != 0) return best;

        id_len += 1;
        id_str = ustring(buf[0..], numlen(id_len));
    }
}

fn parseIdRange(str: []const u8) !ID {
    const dash = std.mem.indexOf(u8, str, "-") orelse return error.NoDashFound;
    const start = try std.fmt.parseUnsigned(u64, str[0..dash], 10);
    const end = try std.fmt.parseUnsigned(u64, str[dash + 1 ..], 10);
    return ID{ .start = start, .end = end };
}

fn findInvalids(id: *ID) !void {
    var next_repeated = try nextRepeatedID(id.start, id.end) orelse id.end + 1;
    if (DEBUG) std.debug.print("\n<{d}-{d}>\n", .{ id.start, id.end });

    while (next_repeated <= id.end) {
        id.sum += next_repeated;
        if (DEBUG) std.debug.print("{d}\n", .{next_repeated});
        next_repeated = try nextRepeatedID(next_repeated + 1, id.end) orelse id.end + 1;
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
