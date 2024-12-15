const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

fn findRobotP1(grid: Grid) ?IPos {
    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
            if (grid.get(pos)) |tile| {
                if (tile == '@') {
                    return pos;
                }
            }
        }
    }
    return null;
}

fn findRobotP2(grid: Grid) ?IPos {
    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
            if (grid.get(pos)) |tile| {
                if (tile == '@') {
                    return IPos{ .row = pos.row, .col = 2 * pos.col };
                }
            }
        }
    }
    return null;
}

const Positions = std.AutoHashMap(IPos, void);

fn populateBoxesP1(allocator: std.mem.Allocator, grid: Grid) !Positions {
    var boxes = std.AutoHashMap(IPos, void).init(allocator);

    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
            if (grid.get(pos)) |tile| {
                if (tile == 'O') {
                    try boxes.put(pos, {});
                }
            }
        }
    }

    return boxes;
}

fn populateBoxesP2(allocator: std.mem.Allocator, grid: Grid) !Positions {
    var boxes = std.AutoHashMap(IPos, void).init(allocator);

    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
            if (grid.get(pos)) |tile| {
                if (tile == 'O') {
                    try boxes.put(IPos{ .row = pos.row, .col = 2 * pos.col }, {});
                }
            }
        }
    }

    return boxes;
}

fn populateWallsP2(allocator: std.mem.Allocator, grid: Grid) !Positions {
    var walls = std.AutoHashMap(IPos, void).init(allocator);

    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
            if (grid.get(pos)) |tile| {
                if (tile == '#') {
                    try walls.put(IPos{ .row = pos.row, .col = 2 * pos.col }, {});
                    try walls.put(IPos{ .row = pos.row, .col = 2 * pos.col + 1 }, {});
                }
            }
        }
    }

    return walls;
}

const Dir = enum { left, right, up, down };

fn move(pos: IPos, dir: Dir) IPos {
    var row = pos.row;
    var col = pos.col;
    switch (dir) {
        .left => col -= 1,
        .right => col += 1,
        .up => row -= 1,
        .down => row += 1,
    }
    return .{ .row = row, .col = col };
}

fn moveRobotP1(pos: IPos, dir: Dir, boxes: *Positions, grid: Grid) !bool {
    const dest = move(pos, dir);

    if (grid.get(dest).? == '#') {
        // Move is not possible
        return false;
    }
    const possible = !boxes.contains(dest) or try moveRobotP1(dest, dir, boxes, grid);
    if (possible) {
        if (boxes.contains(pos)) {
            _ = boxes.remove(pos);
            try boxes.put(dest, {});
        }
        return true;
    } else {
        return false;
    }
}

fn containsWideBox(pos: IPos, boxes: Positions) bool {
    return boxes.contains(pos) or boxes.contains(IPos{ .row = pos.row, .col = pos.col - 1 });
}

fn otherBoxHalf(pos: IPos, boxes: Positions) IPos {
    if (boxes.contains(pos)) {
        return IPos{ .row = pos.row, .col = pos.col + 1 };
    } else {
        return IPos{ .row = pos.row, .col = pos.col - 1 };
    }
}

fn leftBoxHalf(pos: IPos, boxes: Positions) IPos {
    if (boxes.contains(pos)) {
        return pos;
    } else {
        return otherBoxHalf(pos, boxes);
    }
}

fn canMoveIntoP2(pos: IPos, dir: Dir, boxes: Positions, walls: Positions, touched_boxes: *Positions) !bool {
    if (walls.contains(pos)) {
        return false;
    }

    const is_box_move = containsWideBox(pos, boxes);
    if (is_box_move) {
        if (dir == Dir.up or dir == Dir.down) {
            try touched_boxes.put(leftBoxHalf(pos, boxes), {});
            const pos1 = move(pos, dir);
            const pos2 = move(otherBoxHalf(pos, boxes), dir);
            return try canMoveIntoP2(pos1, dir, boxes, walls, touched_boxes) and try canMoveIntoP2(pos2, dir, boxes, walls, touched_boxes);
        } else if (dir == Dir.left) {
            try touched_boxes.put(leftBoxHalf(pos, boxes), {});
            const dest = move(leftBoxHalf(pos, boxes), dir);
            return try canMoveIntoP2(dest, dir, boxes, walls, touched_boxes);
        } else {
            try touched_boxes.put(leftBoxHalf(pos, boxes), {});
            const dest = move(otherBoxHalf(leftBoxHalf(pos, boxes), boxes), dir);
            return try canMoveIntoP2(dest, dir, boxes, walls, touched_boxes);
        }
    }

    // Not a wall or box means the tile is empty
    return true;
}

fn scoreBoxes(boxes: Positions) u64 {
    var score: i64 = 0;
    var it = boxes.keyIterator();
    while (it.next()) |pos| {
        score += pos.row * 100 + pos.col;
    }

    return @intCast(score);
}

fn part1(allocator: std.mem.Allocator, grid: Grid, dirs: []Dir) !u64 {
    var robot_pos = findRobotP1(grid).?;

    var boxes = try populateBoxesP1(allocator, grid);
    defer boxes.deinit();

    for (dirs) |dir| {
        const possible = try moveRobotP1(robot_pos, dir, &boxes, grid);
        if (possible) {
            robot_pos = move(robot_pos, dir);
        }
    }

    return scoreBoxes(boxes);
}

fn part2(allocator: std.mem.Allocator, grid: Grid, dirs: []Dir) !u64 {
    var robot_pos = findRobotP2(grid).?;

    var boxes = try populateBoxesP2(allocator, grid);
    defer boxes.deinit();

    var walls = try populateWallsP2(allocator, grid);
    defer walls.deinit();

    for (dirs) |dir| {
        var touched_boxes = Positions.init(allocator);
        defer touched_boxes.deinit();

        const dest = move(robot_pos, dir);
        if (try canMoveIntoP2(dest, dir, boxes, walls, &touched_boxes)) {
            var it = touched_boxes.keyIterator();
            while (it.next()) |pos| {
                _ = boxes.remove(pos.*);
            }
            it = touched_boxes.keyIterator();
            while (it.next()) |pos| {
                try boxes.put(move(pos.*, dir), {});
            }
            robot_pos = dest;
        }
    }

    return scoreBoxes(boxes);
}

pub fn Solution(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const grid = Grid.fromReader(allocator, reader) catch return error.ParseFailure;
            defer grid.deinit();

            var dirs = std.ArrayList(Dir).init(allocator);
            defer dirs.deinit();

            var buffer: [1024]u8 = undefined;
            while (input.nextLine(reader, &buffer) catch return error.ParseFailure) |dir_line| {
                for (dir_line) |d_char| {
                    const dir: Dir = switch (d_char) {
                        '<' => Dir.left,
                        '>' => Dir.right,
                        '^' => Dir.up,
                        'v' => Dir.down,
                        else => unreachable,
                    };
                    try dirs.append(dir);
                }
            }

            return .{
                .part1 = try part1(allocator, grid, dirs.items),
                .part2 = try part2(allocator, grid, dirs.items),
            };
        }
    };
}
