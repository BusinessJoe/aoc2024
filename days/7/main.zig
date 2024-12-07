const std = @import("std");
const ArrayList = std.ArrayList;

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

const InputLine = struct {
    target: u64,
    nums: []u64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: InputLine) void {
        self.allocator.free(self.nums);
    }

    pub fn parse(allocator: std.mem.Allocator, line: []const u8) !InputLine {
        var splitIt = std.mem.splitSequence(u8, line, ": ");
        const target = try std.fmt.parseInt(u64, splitIt.next().?, 10);

        var it = std.mem.tokenizeScalar(u8, splitIt.next().?, ' ');
        var nums = std.ArrayList(u64).init(allocator);
        while (it.next()) |token| {
            try nums.append(try std.fmt.parseInt(u64, token, 10));
        }

        return InputLine{
            .target = target,
            .nums = try nums.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};

const Input = struct {
    lines: []InputLine,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Input) void {
        for (self.lines) |line| {
            line.deinit();
        }
        self.allocator.free(self.lines);
    }

    pub fn parse(allocator: std.mem.Allocator, reader: anytype) !Input {
        var inputs = std.ArrayList(InputLine).init(allocator);
        var buffer: [100]u8 = undefined;
        while (try nextLine(reader, &buffer)) |line| {
            try inputs.append(try InputLine.parse(allocator, line));
        }

        return Input{
            .lines = try inputs.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};

fn concat(a: u64, b: u64) u64 {
    var aCopy = a;
    var bCopy = b;
    while (bCopy > 0) {
        aCopy *= 10;
        bCopy /= 10;
    }
    return aCopy + b;
}

fn checkLine(target: u64, num: u64, rest: []u64) bool {
    if (rest.len == 0) {
        return target == num;
    }

    return checkLine(target, num * rest[0], rest[1..]) or
        checkLine(target, num + rest[0], rest[1..]);
}

fn checkLineConcat(target: u64, num: u64, rest: []u64) bool {
    if (rest.len == 0) {
        return target == num;
    }

    return checkLineConcat(target, num * rest[0], rest[1..]) or
        checkLineConcat(target, num + rest[0], rest[1..]) or
        checkLineConcat(target, concat(num, rest[0]), rest[1..]);
}

pub fn aoc7(allocator: std.mem.Allocator, reader: anytype) !struct { part1: u64, part2: u64 } {
    const input = try Input.parse(allocator, reader);
    defer input.deinit();

    var part1: u64 = 0;
    var part2: u64 = 0;
    for (input.lines) |line| {
        if (checkLine(line.target, line.nums[0], line.nums[1..])) {
            part1 += line.target;
        }
        if (checkLineConcat(line.target, line.nums[0], line.nums[1..])) {
            part2 += line.target;
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try aoc7(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "test example" {
    const exampleData = @embedFile("data/example");
    var stream = std.io.fixedBufferStream(exampleData);

    const answers = try aoc7(test_allocator, stream.reader());

    try expect(answers.part1 == 3749);
    try expectEqual(11387, answers.part2);
}

test "test concat" {
    try expect(concat(12, 345) == 12345);
    try expect(concat(1, 3) == 13);
    try expect(concat(15, 6) == 156);
}

test "test checkline" {
    const line = try InputLine.parse(test_allocator, "7290: 6 8 6 15");
    defer line.deinit();

    try expect(checkLineConcat(line.target, line.nums[0], line.nums[1..]));
}
