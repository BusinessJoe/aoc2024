const std = @import("std");
const Allocator = std.mem.Allocator;
const parseInt = std.fmt.parseInt;
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim carriage return if on windows
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}

fn reportIsSafe(level: []u32) bool {
    const isIncreasing: bool = level[0] < level[1];

    for (0..level.len - 1) |i| {
        if ((level[i] < level[i + 1]) != isIncreasing) {
            return false;
        }
        var diff: u32 = undefined;
        if (isIncreasing) {
            diff = level[i + 1] - level[i];
        } else {
            diff = level[i] - level[i + 1];
        }
        if (diff == 0 or diff > 3) {
            return false;
        }
    }

    return true;
}

fn reportWithSingleRemovalIsSafe(level: []u32, removed: u64) bool {
    const f = if (0 >= removed) level[1] else level[0];
    const s = if (1 >= removed) level[2] else level[1];
    const isIncreasing = f < s;
    for (0..level.len - 2) |i| {
        const first = if (i >= removed) level[i + 1] else level[i];
        const second = if (i + 1 >= removed) level[i + 2] else level[i + 1];

        if ((first < second) != isIncreasing) {
            return false;
        }
        var diff: u32 = undefined;
        if (isIncreasing) {
            diff = second - first;
        } else {
            diff = first - second;
        }
        if (diff == 0 or diff > 3) {
            return false;
        }
    }
    return true;
}

fn reportWithRemovalIsSafe(level: []u32) bool {
    for (0..level.len) |removed| {
        if (reportWithSingleRemovalIsSafe(level, removed)) {
            return true;
        }
    }

    return false;
}

fn aoc2(allocator: *Allocator, reader: anytype) !struct { u32, u32 } {
    var total: u32 = 0;
    var total2: u32 = 0;
    var buffer: [100]u8 = undefined;
    while (try nextLine(reader, &buffer)) |line| {
        var levels = std.ArrayList(u32).init(allocator.*);
        defer levels.deinit();

        var it = std.mem.tokenizeScalar(u8, line, ' ');

        while (it.next()) |token| {
            const n = try parseInt(u32, token, 10);
            try levels.append(n);
        }

        if (reportIsSafe(levels.items)) {
            total += 1;
            total2 += 1;
        } else if (reportWithRemovalIsSafe(levels.items)) {
            total2 += 1;
        }
    }

    return .{ total, total2 };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    const answers = try aoc2(&allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers[0], answers[1] });
}

test "both parts with given example" {
    var list = std.ArrayList(u8).init(test_allocator);
    defer list.deinit();

    try list.appendSlice("3   4\n4   3\n2   5\n1   3\n3   9\n3   3");

    var stream = std.io.fixedBufferStream(list.items);

    _ = try aoc2(test_allocator, stream.reader());
}
