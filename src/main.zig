const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types");
const Aoc1 = @import("days/1/main.zig").Aoc1;

const sols = [_]types.Solution(std.fs.File.Reader){Aoc1(std.fs.File.Reader).solve};

fn openInputFile(allocator: Allocator, day: usize) !std.fs.File {
    var day_buf: [2]u8 = undefined;
    const day_str = try std.fmt.bufPrint(&day_buf, "{d}", .{day});

    const paths = [_][]const u8{ "inputs", day_str, "input" };

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
