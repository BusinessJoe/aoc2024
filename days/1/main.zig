const std = @import("std");
const parseInt = std.fmt.parseInt;

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

fn parseLists(reader: anytype) !struct { std.ArrayList(u32), std.ArrayList(u32) } {
    const ally = std.heap.page_allocator;

    var l1 = std.ArrayList(u32).init(ally);
    var l2 = std.ArrayList(u32).init(ally);

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

fn aoc1p2(l1: []u32, l2: []u32) !u32 {
    const ally = std.heap.page_allocator;
    const max = @max(l1[l1.len - 1], l2[l2.len - 1]);

    const counts = try ally.alloc(u32, max + 1);
    defer ally.free(counts);

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

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    const lists = try parseLists(stdin.reader());
    std.mem.sort(u32, lists[0].items, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, lists[1].items, {}, comptime std.sort.asc(u32));

    const out1 = aoc1p1(lists[0].items, lists[1].items);
    const out2 = try aoc1p2(lists[0].items, lists[1].items);
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ out1, out2 });
}
