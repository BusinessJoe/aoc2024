const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types");
const Answer = types.Answer;
const Aoc1 = @import("days/day1.zig").Aoc1;
const Aoc2 = @import("days/day2.zig").Aoc2;
const Aoc3 = @import("days/day3.zig").Aoc3;
const Aoc4 = @import("days/day4.zig").Aoc4;
const Aoc5 = @import("days/day5.zig").Aoc5;
const Aoc6 = @import("days/day6.zig").Aoc6;
const Aoc7 = @import("days/day7.zig").Aoc7;
const Aoc8 = @import("days/day8.zig").Aoc8;
const Aoc9 = @import("days/day9.zig").Aoc9;

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
    Aoc9(Reader).solve,
};

fn openInputFile(allocator: Allocator, day: usize, dirpath: []const u8) !std.fs.File {
    var day_buf: [2]u8 = undefined;
    const day_str = try std.fmt.bufPrint(&day_buf, "{d}", .{day});

    const paths = [_][]const u8{ dirpath, day_str };

    const filepath = try std.fs.path.join(allocator, &paths);
    defer allocator.free(filepath);

    return std.fs.cwd().openFile(filepath, .{});
}

const Args = struct {
    all: bool = false,
    day: ?u8 = null,
    dirpath: []const u8 = "inputs" ++ std.fs.path.sep_str ++ "real",
};

const ArgParseError = error{
    InvalidDate,
    ArgumentRequired,
    InvalidArgument,
};

fn parseArgs() ArgParseError!Args {
    var it = std.process.args();
    _ = it.skip();

    var args = Args{};

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--all") or std.mem.eql(u8, arg, "-a")) {
            args.all = true;
        } else if (std.mem.eql(u8, arg, "--day") or std.mem.eql(u8, arg, "-d")) {
            const day_str = it.next() orelse return ArgParseError.ArgumentRequired;
            const day = std.fmt.parseInt(u8, day_str, 10) catch return ArgParseError.InvalidDate;
            if (0 == day or day > 25) {
                return ArgParseError.InvalidDate;
            }

            args.day = day;
        } else if (std.mem.eql(u8, arg, "--dir")) {
            const dirpath = it.next() orelse return ArgParseError.ArgumentRequired;
            args.dirpath = dirpath;
        } else {
            return ArgParseError.InvalidArgument;
        }
    }

    return args;
}

fn header() !void {
    const stdout = std.io.getStdOut();
    try stdout.writer().print("       \t{s:=^20}  {s:=^20}\n", .{ " Part 1 ", " Part 2 " });
}

fn solutionNotFound(day: u8) !void {
    const stdout = std.io.getStdOut();
    try stdout.writer().print("Day {: >2}:\t{s:-^42}\n", .{ day, " Not implemented " });
}

fn printAnswers(day: u8, answers: Answer) !void {
    const stdout = std.io.getStdOut();
    try stdout.writer().print(
        "Day {: >2}:\t{: >20}  {: >20}\n",
        .{ day, answers.part1, answers.part2 },
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try parseArgs();
    var days = try std.BoundedArray(u8, 25).init(0);
    if (args.all) {
        for (1..26) |day| {
            try days.append(@intCast(day));
        }
    } else if (args.day) |day| {
        try days.append(day);
    } else {
        // Default to most recent day
        // Days are 1-indexed so we want sols.len instead of sols.len - 1.
        try days.append(sols.len);
    }

    try header();

    for (days.constSlice()) |day| {
        if (day - 1 >= sols.len) {
            try solutionNotFound(day);
            continue;
        }

        const sol = sols[day - 1];

        const file = try openInputFile(allocator, day, args.dirpath);
        defer file.close();

        const answers = try sol(allocator, file.reader());
        try printAnswers(day, answers);
    }
}
