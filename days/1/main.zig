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

fn parseLists(allocator: Allocator, reader: anytype) !struct { std.ArrayList(u32), std.ArrayList(u32) } {
    var l1 = std.ArrayList(u32).init(allocator);
    var l2 = std.ArrayList(u32).init(allocator);

    var buffer: [100]u8 = undefined;
    while (try nextLine(reader, &buffer)) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ' ');

        const n1 = try parseInt(u32, it.next().?, 10);
        try l1.append(n1);

        const n2 = try parseInt(u32, it.next().?, 10);
        try l2.append(n2);
    }

    return .{ l1, l2 };
}

fn aoc1p1(l1: []u32, l2: []u32) u32 {
    var total: u32 = 0;
    for (l1, l2) |n1, n2| {
        if (n1 > n2) {
            total += n1 - n2;
        } else {
            total += n2 - n1;
        }
    }
    return total;
}

fn aoc1p2(allocator: Allocator, l1: []u32, l2: []u32) !u32 {
    const max = @max(l1[l1.len - 1], l2[l2.len - 1]);

    const counts = try allocator.alloc(u32, max + 1);
    defer allocator.free(counts);

    @memset(counts, 0);

    for (l2) |n| {
        counts[n] += 1;
    }

    var total: u32 = 0;
    for (l1) |n| {
        total += n * counts[n];
    }
    return total;
}

fn aoc1(allocator: Allocator, reader: anytype) !struct { u32, u32 } {
    const lists = try parseLists(allocator, reader);
    defer lists[0].deinit();
    defer lists[1].deinit();

    std.mem.sort(u32, lists[0].items, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, lists[1].items, {}, comptime std.sort.asc(u32));

    const out1 = aoc1p1(lists[0].items, lists[1].items);
    const out2 = try aoc1p2(allocator, lists[0].items, lists[1].items);

    return .{ out1, out2 };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    const allocator = std.heap.page_allocator;

    const answers = aoc1(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers[0], answers[1] });
}

test "both parts with given example" {
    var list = std.ArrayList(u8).init(test_allocator);
    defer list.deinit();

    try list.appendSlice("3   4\n4   3\n2   5\n1   3\n3   9\n3   3");

    var stream = std.io.fixedBufferStream(list.items);

    const answers = try aoc1(test_allocator, stream.reader());

    try expect(answers[0] == 11);
    try expect(answers[1] == 31);
}
