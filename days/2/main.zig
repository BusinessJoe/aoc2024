const std = @import("std");
const Allocator = std.mem.Allocator;
const parseInt = std.fmt.parseInt;
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

fn reportWithRemovalIsSafe(allocator: *Allocator, level: []u32) !bool {
    var small_level = try allocator.alloc(u32, level.len - 1);

    for (0..level.len) |removed| {
        for (0..removed) |i| {
            small_level[i] = level[i];
        }
        for (removed + 1..level.len) |i| {
            small_level[i - 1] = level[i];
        }
        if (reportIsSafe(small_level)) {
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
        } else if (try reportWithRemovalIsSafe(allocator, levels.items)) {
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
    var test_allocator = std.testing.allocator;

    var list = std.ArrayList(u8).init(test_allocator);
    defer list.deinit();

    try list.appendSlice("7 6 4 2 1\n1 2 7 8 9\n9 7 6 2 1\n1 3 2 4 5\n8 6 4 4 1\n1 3 6 7 9");

    var stream = std.io.fixedBufferStream(list.items);

    const answers = try aoc2(&test_allocator, stream.reader());

    try expect(answers[0] == 2);
    try expect(answers[1] == 4);
}
