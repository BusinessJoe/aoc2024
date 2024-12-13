const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const Region = struct {
    coords: std.AutoHashMap(IPos, void),
    area: u32,
    perimeter: u32,
    edges: u32,

    fn deinit(self: *Region) void {
        self.coords.deinit();
    }
};

fn getLUTIndex(visited: std.AutoHashMap(IPos, void), pos: IPos) u8 {
    const deltas3x3 = [_]IPos{
        IPos{ .row = -1, .col = -1 },
        IPos{ .row = -1, .col = 0 },
        IPos{ .row = -1, .col = 1 },
        IPos{ .row = 0, .col = -1 },
        IPos{ .row = 0, .col = 1 },
        IPos{ .row = 1, .col = -1 },
        IPos{ .row = 1, .col = 0 },
        IPos{ .row = 1, .col = 1 },
    };

    var lut_idx: u8 = 0;
    for (deltas3x3, 0..8) |delta, i| {
        const n_pos = IPos{
            .row = pos.row + delta.row,
            .col = pos.col + delta.col,
        };
        const i_u3: u3 = @intCast(i);
        if (visited.contains(n_pos)) {
            const one: u8 = 1;
            lut_idx |= (one << i_u3);
        }
    }

    return lut_idx;
}

fn findRegion(allocator: std.mem.Allocator, grid: Grid, seed: IPos) !Region {
    const region_type: u8 = grid.get(seed).?;
    var visited = std.AutoHashMap(IPos, void).init(allocator);
    var area: u32 = 0;
    var peri: i32 = 0;
    var edges: i32 = 0;

    var to_visit = std.ArrayList(IPos).init(allocator);
    defer to_visit.deinit();

    try to_visit.append(seed);

    while (to_visit.popOrNull()) |pos| {
        // Position must be in the grid
        const tile = grid.get(pos) orelse continue;
        // Tile should be the same type as the rest of region
        if (tile != region_type) continue;
        // Skip visited positions
        if (visited.contains(pos)) continue;

        area += 1;
        // Perimeter increase depends on how many visited positions are next to
        // this position
        // We also mark the neighbours as positions to visit next
        var neighbours: u8 = 0;
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
            try to_visit.append(n_pos);
            if (visited.contains(n_pos)) neighbours += 1;
        }
        peri += 4 - 2 * @as(i32, neighbours);

        // Edge calculation
        const edge_delta_lut = comptime edgeDeltaLUT();
        const lut_idx = getLUTIndex(visited, pos);
        edges += edge_delta_lut[lut_idx];

        try visited.put(pos, {});
    }

    return Region{
        .coords = visited,
        .area = area,
        .perimeter = @intCast(peri),
        .edges = @intCast(edges),
    };
}

pub fn Aoc12(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const grid = Grid.fromReader(allocator, reader) catch return error.ParseFailure;
            defer grid.deinit();

            var visited = std.AutoHashMap(IPos, void).init(allocator);
            defer visited.deinit();

            var part1: u32 = 0;
            var part2: u32 = 0;

            for (0..grid.height) |row| {
                for (0..grid.width) |col| {
                    const seed = IPos{ .row = @intCast(row), .col = @intCast(col) };
                    if (visited.contains(seed)) continue;

                    var region = try findRegion(allocator, grid, seed);
                    defer region.deinit();

                    part1 += region.area * region.perimeter;
                    part2 += region.area * region.edges;

                    var it = region.coords.keyIterator();
                    while (it.next()) |pos| {
                        try visited.put(pos.*, {});
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

fn countEdgesLine(edge: []bool) u32 {
    // Counts low-to-high transitions
    var state = false;
    var count: u32 = 0;

    inline for (edge) |e| {
        if (e) {
            if (!state) count += 1;
            state = true;
        } else {
            state = false;
        }
    }
    return count;
}

fn countEdges3x3(grid: [3][3]bool) u32 {
    var edges: u32 = 0;
    for (0..4) |erow| {
        var edge_r_t: [3]bool = undefined;
        var edge_r_b: [3]bool = undefined;
        var edge_c_l: [3]bool = undefined;
        var edge_c_r: [3]bool = undefined;
        inline for (0..3) |ecol| {
            const above = 1 <= erow and grid[erow - 1][ecol];
            const below = erow < 3 and grid[erow][ecol];
            edge_r_t[ecol] = (above and !below);
            edge_r_b[ecol] = (!above and below);

            const left = 1 <= erow and grid[ecol][erow - 1];
            const right = erow < 3 and grid[ecol][erow];
            edge_c_l[ecol] = (left and !right);
            edge_c_r[ecol] = (!left and right);
        }
        edges += countEdgesLine(&edge_r_t);
        edges += countEdgesLine(&edge_r_b);
        edges += countEdgesLine(&edge_c_l);
        edges += countEdgesLine(&edge_c_r);
    }
    return edges;
}

fn edgeDeltaLUT() [256]i32 {
    @setEvalBranchQuota(45000);
    var deltas: [256]i32 = undefined;

    for (0..256) |i| {
        var grid: [3][3]bool = .{
            .{ false, false, false },
            .{ false, false, false },
            .{ false, false, false },
        };
        grid[0][0] = i & (1 << 0) != 0;
        grid[0][1] = i & (1 << 1) != 0;
        grid[0][2] = i & (1 << 2) != 0;
        grid[1][0] = i & (1 << 3) != 0;
        grid[1][1] = false;
        grid[1][2] = i & (1 << 4) != 0;
        grid[2][0] = i & (1 << 5) != 0;
        grid[2][1] = i & (1 << 6) != 0;
        grid[2][2] = i & (1 << 7) != 0;

        const before: i32 = countEdges3x3(grid);
        grid[1][1] = true;
        const after: i32 = countEdges3x3(grid);

        deltas[i] = after - before;
    }

    return deltas;
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc12.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

const testing = std.testing;
test "test countEdges3x3 empty" {
    const grid: [3][3]bool = .{
        .{ false, false, false },
        .{ false, false, false },
        .{ false, false, false },
    };
    try testing.expectEqual(0, countEdges3x3(grid));
}

test "test countEdges3x3 single" {
    const grid: [3][3]bool = .{
        .{ false, false, false },
        .{ true, false, false },
        .{ false, false, false },
    };
    try testing.expectEqual(4, countEdges3x3(grid));
}

test "test countEdges3x3 double" {
    const grid: [3][3]bool = .{
        .{ false, false, false },
        .{ true, true, false },
        .{ false, false, false },
    };
    try testing.expectEqual(4, countEdges3x3(grid));
}

test "test countEdges3x3 long" {
    const grid: [3][3]bool = .{
        .{ false, true, false },
        .{ false, true, false },
        .{ false, true, false },
    };
    try testing.expectEqual(4, countEdges3x3(grid));
}

test "test countEdges3x3 double long" {
    const grid: [3][3]bool = .{
        .{ true, false, true },
        .{ true, false, true },
        .{ true, false, true },
    };
    try testing.expectEqual(8, countEdges3x3(grid));
}

test "test countEdges3x3 donut" {
    const grid: [3][3]bool = .{
        .{ true, true, true },
        .{ true, false, true },
        .{ true, true, true },
    };
    try testing.expectEqual(8, countEdges3x3(grid));
}

test "test countEdges3x3 X" {
    const grid: [3][3]bool = .{
        .{ true, false, true },
        .{ false, true, false },
        .{ true, false, true },
    };
    try testing.expectEqual(20, countEdges3x3(grid));
}

test "test countEdges3x3 cross" {
    const grid: [3][3]bool = .{
        .{ false, true, false },
        .{ true, true, true },
        .{ false, true, false },
    };
    try testing.expectEqual(12, countEdges3x3(grid));
}

test "test edgeDeltaLUT" {
    const lut = comptime edgeDeltaLUT();
    try testing.expectEqual(4, lut[0]);
    try testing.expectEqual(0, lut[0b00010000]);
}
