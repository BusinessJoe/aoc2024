const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const PosSet = std.AutoHashMap(IPos, void);

const Split = struct {
    left: u64,
    right: u64,
};

fn evenSplit(num: u64) ?Split {
    const digits = std.math.log10_int(num) + 1;
    if (digits % 2 == 0) {
        const divisor = pow10(digits / 2);
        return .{
            .left = num / divisor,
            .right = num % divisor,
        };
    } else {
        return null;
    }
}

fn pow10(n: u64) u64 {
    var ret: u64 = 1;
    for (0..n) |_| {
        ret *= 10;
    }
    return ret;
}

const AnswerCache = std.AutoHashMap(struct { u64, u64 }, u64);

fn amountAfterBlinks(cache: *AnswerCache, num: u64, blinks: u64) !u64 {
    if (blinks == 0) return 1;

    if (cache.get(.{ num, blinks })) |answer| {
        return answer;
    }

    var answer: u64 = undefined;
    if (num == 0) {
        answer = try amountAfterBlinks(cache, 1, blinks - 1);
    } else if (evenSplit(num)) |split| {
        const left = try amountAfterBlinks(cache, split.left, blinks - 1);
        const right = try amountAfterBlinks(cache, split.right, blinks - 1);
        answer = left + right;
    } else {
        answer = try amountAfterBlinks(cache, num * 2024, blinks - 1);
    }

    try cache.put(.{ num, blinks }, answer);
    return answer;
}

pub fn Aoc11(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            var buffer: [1024]u8 = undefined;
            const line = (input.nextLine(reader, &buffer) catch return AocError.ParseFailure) orelse return AocError.ParseFailure;

            var answerCache = AnswerCache.init(allocator);
            defer answerCache.deinit();

            var part1: u64 = 0;
            var part2: u64 = 0;
            var num_it = std.mem.splitScalar(u8, line, ' ');
            while (num_it.next()) |num_str| {
                const num = std.fmt.parseInt(u64, num_str, 10) catch return AocError.ParseFailure;
                part1 += try amountAfterBlinks(&answerCache, num, 25);
                part2 += try amountAfterBlinks(&answerCache, num, 75);
            }

            return .{
                .part1 = part1,
                .part2 = part2,
            };
        }
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc11.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

const testing = std.testing;
test "test evenSplit" {
    try testing.expectEqual(Split{ .left = 10, .right = 0 }, evenSplit(1000));
    try testing.expectEqual(Split{ .left = 9, .right = 9 }, evenSplit(99));
    try testing.expectEqual(Split{ .left = 20, .right = 24 }, evenSplit(2024));
    try testing.expectEqual(null, evenSplit(9));
    try testing.expectEqual(null, evenSplit(100));
}
