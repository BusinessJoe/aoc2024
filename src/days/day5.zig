const std = @import("std");
const ArrayList = std.ArrayList;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

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

fn contains(comptime T: type, haystack: []const T, needle: T) bool {
    for (haystack) |item| {
        if (item == needle) {
            return true;
        }
    }
    return false;
}

fn topoSort(allocator: std.mem.Allocator, rules: [][2]u8, seq: []const u8) ![]u8 {
    var inDegrees = std.AutoHashMap(u8, usize).init(allocator);
    defer inDegrees.deinit();
    for (seq) |n| {
        try inDegrees.put(n, 0);
    }
    for (rules) |rule| {
        if (!contains(u8, seq, rule[0]) or !contains(u8, seq, rule[1])) {
            continue;
        }
        inDegrees.getPtr(rule[1]).?.* += 1;
    }

    // S is a collection of all nodes with no incoming edge
    var s = ArrayList(u8).init(allocator);
    defer s.deinit();
    for (seq) |n| {
        if (inDegrees.get(n).? == 0) {
            try s.append(n);
        }
    }

    // Make a map of edges (Key = pre, Value = all post).
    var edges = std.AutoHashMap(u8, ArrayList(u8)).init(allocator);
    for (seq) |n| {
        try edges.put(n, ArrayList(u8).init(allocator));
    }
    defer {
        for (seq) |n| edges.get(n).?.deinit();
        edges.deinit();
    }
    for (rules) |rule| {
        if (!contains(u8, seq, rule[0]) or !contains(u8, seq, rule[1])) {
            continue;
        }
        var lst = edges.get(rule[0]).?;
        try lst.append(rule[1]);
        try edges.put(rule[0], lst);
    }

    // Kahn's algorithm
    var sorted = ArrayList(u8).init(allocator);
    while (s.popOrNull()) |n| {
        try sorted.append(n);

        // Iterate over each node m with an edge from n to m, removing the edge
        // as well.
        while (edges.getPtr(n).?.popOrNull()) |m| {
            const count: usize = inDegrees.get(m).?;
            try inDegrees.put(m, count - 1);

            if (count - 1 == 0) {
                try s.append(m);
            }
        }
    }

    return sorted.toOwnedSlice();
}

pub fn Aoc5(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const input = parseInput(allocator, reader) catch return AocError.ParseFailure;
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
            var part2: u32 = 0;
            for (input.seqs) |seq| {
                if (try validSeq(allocator, map, seq)) {
                    part1 += seq[seq.len / 2];
                } else {
                    const sorted = try topoSort(allocator, input.rules, seq);
                    defer allocator.free(sorted);
                    part2 += sorted[sorted.len / 2];
                }
            }

            return .{ .part1 = part1, .part2 = part2 };
        }
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc5.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

test "test example" {
    const test_allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const exampleData = @embedFile("data/example");
    var stream = std.io.fixedBufferStream(exampleData);

    const answers = try Aoc5.solve(test_allocator, stream.reader());

    try expect(answers.part1 == 143);
    try expect(answers.part2 == 123);
}
