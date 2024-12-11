const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const PosSet = std.AutoHashMap(IPos, void);

fn populateReachable(allocator: std.mem.Allocator, reachable: *std.AutoHashMap(IPos, PosSet), grid: Grid, pos: IPos) !void {
    if (reachable.contains(pos)) return;

    const tile = grid.get(pos).?;
    var current_reachable = PosSet.init(allocator);

    // Base case if we're already at a trail end
    if (tile == '9') {
        try current_reachable.put(pos, {});
        try reachable.put(pos, current_reachable);
        return;
    }

    const deltas = [_]IPos{
        IPos{ .row = 1, .col = 0 },
        IPos{ .row = -1, .col = 0 },
        IPos{ .row = 0, .col = 1 },
        IPos{ .row = 0, .col = -1 },
    };

    for (deltas) |delta| {
        const n_pos = IPos{
            .row = pos.row + delta.row,
            .col = pos.col + delta.col,
        };

        if (grid.contains(n_pos) and grid.get(n_pos).? == tile + 1) {
            try populateReachable(allocator, reachable, grid, n_pos);
            var n_reachable_it = reachable.get(n_pos).?.keyIterator();
            while (n_reachable_it.next()) |p| {
                try current_reachable.put(p.*, {});
            }
        }
    }

    try reachable.put(pos, current_reachable);
}

fn populateUniqueTrails(allocator: std.mem.Allocator, unique_trails: *std.AutoHashMap(IPos, u64), grid: Grid, pos: IPos) !void {
    if (unique_trails.contains(pos)) return;

    const tile = grid.get(pos).?;

    // Base case if we're already at a trail end
    if (tile == '9') {
        try unique_trails.put(pos, 1);
        return;
    }

    const deltas = [_]IPos{
        IPos{ .row = 1, .col = 0 },
        IPos{ .row = -1, .col = 0 },
        IPos{ .row = 0, .col = 1 },
        IPos{ .row = 0, .col = -1 },
    };

    var count: u64 = 0;
    for (deltas) |delta| {
        const n_pos = IPos{
            .row = pos.row + delta.row,
            .col = pos.col + delta.col,
        };

        if (grid.contains(n_pos) and grid.get(n_pos).? == tile + 1) {
            try populateUniqueTrails(allocator, unique_trails, grid, n_pos);
            count += unique_trails.get(n_pos).?;
        }
    }

    try unique_trails.put(pos, count);
}

pub fn Aoc10(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const grid = Grid.fromReader(allocator, reader) catch return AocError.ParseFailure;
            defer grid.deinit();

            // Map from coordinates to reachable trail ends
            var reachable = std.AutoHashMap(IPos, PosSet).init(allocator);
            defer {
                var set_it = reachable.valueIterator();
                while (set_it.next()) |set| {
                    set.deinit();
                }
                reachable.deinit();
            }

            // Map from coordinates to number of unique paths to trail ends
            var unique_trails = std.AutoHashMap(IPos, u64).init(allocator);
            defer unique_trails.deinit();

            var part1: u64 = 0;
            var part2: u64 = 0;
            for (0..grid.height) |row| {
                for (0..grid.width) |col| {
                    const pos = IPos{
                        .row = @intCast(row),
                        .col = @intCast(col),
                    };
                    if (grid.get(pos).? == '0') {
                        try populateReachable(allocator, &reachable, grid, pos);
                        part1 += reachable.get(pos).?.count();

                        try populateUniqueTrails(allocator, &unique_trails, grid, pos);
                        part2 += unique_trails.get(pos).?;
                    }
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
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc10.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}
