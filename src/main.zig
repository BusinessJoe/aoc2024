const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types");
const Aoc1 = @import("days/day1.zig").Aoc1;
const Aoc2 = @import("days/day2.zig").Aoc2;
const Aoc3 = @import("days/day3.zig").Aoc3;
const Aoc4 = @import("days/day4.zig").Aoc4;
const Aoc5 = @import("days/day5.zig").Aoc5;
const Aoc6 = @import("days/day6.zig").Aoc6;
const Aoc7 = @import("days/day7.zig").Aoc7;
const Aoc8 = @import("days/day8.zig").Aoc8;

const Reader = std.fs.File.Reader;
const sols = [_]types.Solution(Reader){
    Aoc1(Reader).solve,
    Aoc2(Reader).solve,
    Aoc3(Reader).solve,
    Aoc4(Reader).solve,
    Aoc5(Reader).solve,
    Aoc6(Reader).solve,
    Aoc7(Reader).solve,
    Aoc8(Reader).solve,
};

fn openInputFile(allocator: Allocator, day: usize) !std.fs.File {
    var day_buf: [2]u8 = undefined;
    const day_str = try std.fmt.bufPrint(&day_buf, "{d}", .{day});

    const paths = [_][]const u8{ "inputs", "real", day_str };

    const filepath = try std.fs.path.join(allocator, &paths);
    defer allocator.free(filepath);

    return std.fs.cwd().openFile(filepath, .{});
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    for (sols, 1..) |sol, day| {
        try stdout.writer().print("Day {}:\n", .{day});

        const file = try openInputFile(allocator, day);
        defer file.close();

        const answers = try sol(allocator, file.reader());
        try stdout.writer().print("\tPart one: {}\n\tPart two: {}\n", .{ answers.part1, answers.part2 });
    }
}
