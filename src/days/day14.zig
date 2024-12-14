const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const Robot = struct {
    x: i64,
    y: i64,
    dx: i64,
    dy: i64,
};

fn parseLine(comptime R: type, reader: R) !?Robot {
    var buffer: [100]u8 = undefined;
    const line = try input.nextLine(reader, &buffer) orelse return null;
    var it = std.mem.splitAny(u8, line, "=, ");

    _ = it.next().?;
    const x = try std.fmt.parseInt(i64, it.next().?, 10);
    const y = try std.fmt.parseInt(i64, it.next().?, 10);
    _ = it.next().?;
    const dx = try std.fmt.parseInt(i64, it.next().?, 10);
    const dy = try std.fmt.parseInt(i64, it.next().?, 10);

    return .{ .x = x, .y = y, .dx = dx, .dy = dy };
}

fn hasTree(comptime width: usize, comptime height: usize, robots: []Robot, steps: i64) bool {
    var locs: [width * height]u64 = undefined;
    for (&locs) |*l| {
        l.* = 0;
    }

    for (robots) |robot| {
        const x: usize = @intCast(@mod(robot.x + steps * robot.dx, @as(i64, @intCast(width))));
        const y: usize = @intCast(@mod(robot.y + steps * robot.dy, @as(i64, @intCast(height))));
        const idx = x + y * width;
        locs[idx] += 1;
    }

    var needle: [8]u64 = undefined;
    for (&needle) |*n| {
        n.* = 1;
    }

    return std.mem.indexOf(u64, &locs, &needle) != null;
}

fn printRobots(comptime width: usize, comptime height: usize, robots: []Robot, steps: i64) void {
    var locs: [width * height]u64 = undefined;
    for (&locs) |*l| {
        l.* = 0;
    }

    for (robots) |robot| {
        const x: usize = @intCast(@mod(robot.x + steps * robot.dx, @as(i64, @intCast(width))));
        const y: usize = @intCast(@mod(robot.y + steps * robot.dy, @as(i64, @intCast(height))));
        const idx = x + y * width;
        locs[idx] += 1;
    }

    std.debug.print("i: {}\n", .{steps});
    for (0..height) |row| {
        for (0..width) |col| {
            const idx = col + row * width;
            var c: u8 = undefined;
            if (locs[idx] == 0) {
                c = ' ';
            } else if (locs[idx] < 10) {
                c = @as(u8, @intCast(locs[idx])) + '0';
            } else {
                c = '#';
            }
            std.debug.print("{c}", .{c});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

pub fn Aoc14(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            // This changes between example and real input
            const width = 101;
            const height = 103;
            // const width = 11;
            // const height = 7;

            // quadrants for part 1
            var quads = [_]u64{ 0, 0, 0, 0 };

            var robots = std.ArrayList(Robot).init(allocator);
            defer robots.deinit();

            while (parseLine(R, reader) catch return error.ParseFailure) |robot| {
                try robots.append(robot);

                const x = @mod(robot.x + 100 * robot.dx, width);
                const y = @mod(robot.y + 100 * robot.dy, height);

                if (x < width / 2 and y < height / 2) {
                    quads[0] += 1;
                } else if (x < width / 2 and y > height / 2) {
                    quads[1] += 1;
                } else if (x > width / 2 and y < height / 2) {
                    quads[2] += 1;
                } else if (x > width / 2 and y > height / 2) {
                    quads[3] += 1;
                }
            }

            const part1 = quads[0] * quads[1] * quads[2] * quads[3];
            var part2: u64 = 0;

            // period is 10403
            for (0..10403) |i| {
                if (hasTree(width, height, robots.items, @intCast(i))) {
                    part2 = i;
                    break;
                }
            }

            return .{
                .part1 = part1,
                .part2 = part2,
            };
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.print("leaked memory\n", .{});
    };
    const allocator = gpa.allocator();

    const width = 101;
    const height = 103;
    // const width = 11;
    // const height = 7;

    var robots = std.ArrayList(Robot).init(allocator);
    defer robots.deinit();

    const reader = std.io.getStdIn().reader();

    while (parseLine(std.fs.File.Reader, reader) catch return error.ParseFailure) |robot| {
        try robots.append(robot);
    }

    var part2: u64 = 0;

    // period is 10403
    for (0..10403) |i| {
        if (hasTree(width, height, robots.items, @intCast(i))) {
            part2 = i;
            break;
        }
    }

    printRobots(width, height, robots.items, @intCast(part2));
}
