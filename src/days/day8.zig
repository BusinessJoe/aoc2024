const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

fn populateAnodesP1(anodeSet: *std.AutoHashMap(IPos, void), locs: []IPos, grid: Grid) !void {
    for (locs, 0..) |p1, i| {
        for (locs, 0..) |p2, j| {
            if (i == j) continue;
            const dr = p1.row - p2.row;
            const dc = p1.col - p2.col;

            const anodePos = IPos{ .row = p1.row + dr, .col = p1.col + dc };
            // Only count antinodes within the bounds of the map
            if (grid.contains(anodePos)) {
                try anodeSet.put(anodePos, {});
            }
        }
    }
}

fn populateAnodesP2(anodeSet: *std.AutoHashMap(IPos, void), locs: []IPos, grid: Grid) !void {
    for (locs, 0..) |p1, i| {
        for (locs, 0..) |p2, j| {
            if (i == j) continue;
            const dr = p1.row - p2.row;
            const dc = p1.col - p2.col;

            var anodePos = IPos{ .row = p1.row, .col = p1.col };
            while (grid.contains(anodePos)) {
                try anodeSet.put(anodePos, {});
                anodePos.row += dr;
                anodePos.col += dc;
            }
        }
    }
}

pub fn Aoc8(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const grid = input.Grid.fromReader(allocator, reader) catch return AocError.ParseFailure;
            defer grid.deinit();

            var antLocMap = std.AutoHashMap(u8, std.ArrayList(IPos)).init(allocator);
            defer {
                var it = antLocMap.valueIterator();
                while (it.next()) |list| {
                    list.deinit();
                }
                antLocMap.deinit();
            }

            // Populate map with lists of the coordinates of each type of antenna
            for (0..grid.height) |row| {
                for (0..grid.width) |col| {
                    const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
                    const ant = grid.get(pos).?;

                    // Skip 'empty' tiles
                    if (ant == '.') continue;

                    var list: std.ArrayList(IPos) = undefined;
                    if (antLocMap.getPtr(ant)) |list_ptr| {
                        list = list_ptr.*;
                    } else {
                        list = std.ArrayList(IPos).init(allocator);
                    }
                    try list.append(pos);
                    try antLocMap.put(ant, list);
                }
            }

            var anodeSetP1 = std.AutoHashMap(IPos, void).init(allocator);
            var anodeSetP2 = std.AutoHashMap(IPos, void).init(allocator);
            defer anodeSetP1.deinit();
            defer anodeSetP2.deinit();

            var it = antLocMap.iterator();
            while (it.next()) |entry| {
                const locs = entry.value_ptr.*;
                try populateAnodesP1(&anodeSetP1, locs.items, grid);
                try populateAnodesP2(&anodeSetP2, locs.items, grid);
            }

            return .{
                .part1 = anodeSetP1.count(),
                .part2 = anodeSetP2.count(),
            };
        }
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc8.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

test "test parse" {
    const exampleData = @embedFile("data/example");
    var stream = std.io.fixedBufferStream(exampleData);

    const grid = try input.Grid.fromReader(test_allocator, stream.reader());
    defer grid.deinit();
}

test "test example" {
    const exampleData = @embedFile("data/example");
    var stream = std.io.fixedBufferStream(exampleData);

    const answers = try Aoc8.solve(test_allocator, stream.reader());
    try expectEqual(14, answers.part1);
    try expectEqual(34, answers.part2);
}
