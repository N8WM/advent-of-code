const std = @import("std");

const DEBUG = false;

const FNAME = if (DEBUG) "input_test.txt" else "input.txt";
const TICKS = 100;

const TurnState = struct {
    position: i32 = 50,
    zero_alignments: u32 = 0,
    zero_passes: u32 = 0,

    fn debugPrint(self: *TurnState, offset: i32) void {
        if (!DEBUG) return;
        std.debug.print("{d}\tState({d}, {d}, {d})\n", .{ offset, self.position, self.zero_alignments, self.zero_passes });
    }
};

fn parseOffset(str: []u8) i32 {
    const dir_char = @as(u8, str[0]);
    const offset_str = str[1..];

    var offset = std.fmt.parseUnsigned(i32, offset_str, 10) catch 0;

    offset *= switch (dir_char) {
        'L' => -1,
        'R' => 1,
        else => 0,
    };

    return offset;
}

fn turn(state: *TurnState, offset: i32) void {
    const offset_abs = @abs(offset);
    const offset_remainder = @rem(offset, TICKS);
    const position_wrapped = @mod(state.position, TICKS);
    const new_position = state.position + offset;
    const new_position_wrapped = @mod(new_position, TICKS);
    const calculated_remainder = position_wrapped + offset_remainder;

    const already_zero = position_wrapped == 0;
    const remainder_does_wrap = !already_zero and (calculated_remainder >= 100 or calculated_remainder <= 0);

    var wraps = offset_abs / TICKS;
    if (remainder_does_wrap) wraps += 1;

    state.position = new_position;
    state.zero_alignments += if (new_position_wrapped == 0) 1 else 0;
    state.zero_passes += wraps;
}

pub fn main() void {
    const file = std.fs.cwd().openFile(FNAME, .{}) catch |err| {
        std.debug.print("File Error: {}\n", .{err});
        return;
    };

    defer file.close();

    var buffer: [512]u8 = undefined;
    var reader_wrapper = file.reader(&buffer);
    const reader = &reader_wrapper.interface;

    var state: TurnState = TurnState{};
    state.debugPrint(0);

    while (reader.takeDelimiterExclusive('\n')) |line| {
        const next_offset = parseOffset(line);
        turn(&state, next_offset);
        state.debugPrint(next_offset);

        reader.toss(1);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => {
            std.debug.print("Read Error: {}\n", .{err});
            return;
        },
    }

    std.debug.print("Completed Successfully.\nZero Alignments:\t{d}\nZero Passes:\t\t{d}\n", .{ state.zero_alignments, state.zero_passes });
}
