const std = @import("std");
const T = std.testing;
const ArrayList = std.ArrayList;

const Input = struct {
    rules: [][2]u8,
    seqs: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Input) void {
        self.allocator.free(self.rules);
        for (self.seqs) |seq| {
            self.allocator.free(seq);
        }
        self.allocator.free(self.seqs);
    }
};

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

pub fn parseInput(allocator: std.mem.Allocator, reader: anytype) !Input {
    var rules = std.ArrayList([2]u8).init(allocator);
    var seqs = std.ArrayList([]u8).init(allocator);

    var parseRules = true;
    var buffer: [100]u8 = undefined;
    while (try nextLine(reader, &buffer)) |line| {
        if (parseRules) {
            if (line.len == 0) {
                parseRules = false;
                continue;
            }
            var it = std.mem.tokenizeScalar(u8, line, '|');

            const first = try std.fmt.parseInt(u8, it.next().?, 10);
            const second = try std.fmt.parseInt(u8, it.next().?, 10);
            try rules.append([_]u8{ first, second });
        } else {
            var seq = std.ArrayList(u8).init(allocator);
            var it = std.mem.tokenizeScalar(u8, line, ',');
            while (it.next()) |token| {
                const n = try std.fmt.parseInt(u8, token, 10);
                try seq.append(n);
            }
            try seqs.append(try seq.toOwnedSlice());
        }
    }

    return .{
        .rules = try rules.toOwnedSlice(),
        .seqs = try seqs.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn validSeq(allocator: std.mem.Allocator, map: [100]ArrayList(u8), seq: []const u8) !bool {
    var excluded = std.AutoHashMap(u8, void).init(allocator);
    defer excluded.deinit();

    for (seq) |n| {
        if (excluded.contains(n)) {
            return false;
        }

        for (map[n].items) |ex| {
            try excluded.put(ex, {});
        }
    }

    return true;
}

pub fn aoc5(allocator: std.mem.Allocator, reader: anytype) !struct { part1: u32, part2: u32 } {
    const input = try parseInput(allocator, reader);
    defer input.deinit();

    var map: [100]std.ArrayList(u8) = undefined;
    for (0..100) |i| {
        map[i] = std.ArrayList(u8).init(allocator);
    }
    defer {
        for (0..100) |i| {
            map[i].deinit();
        }
    }

    for (input.rules) |rule| {
        var list = map[rule[1]];
        try list.append(rule[0]);
        map[rule[1]] = list;
    }

    var part1: u32 = 0;
    for (input.seqs) |seq| {
        if (try validSeq(allocator, map, seq)) {
            part1 += seq[seq.len / 2];
        }
    }

    return .{ .part1 = part1, .part2 = 0 };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try aoc5(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

test "part 1 example" {
    const test_allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const exampleData = @embedFile("data/example");
    var stream = std.io.fixedBufferStream(exampleData);

    const answers = try aoc5(test_allocator, stream.reader());

    std.debug.print("{d}\n", .{answers.part1});
    try expect(answers.part1 == 143);
}
