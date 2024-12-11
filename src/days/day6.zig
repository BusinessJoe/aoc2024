const std = @import("std");
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;

const DirVisited = packed struct {
    up: bool = false,
    right: bool = false,
    down: bool = false,
    left: bool = false,

    fn any(self: DirVisited) bool {
        return self.up or self.right or self.down or self.left;
    }
};

const Dirs = enum {
    up,
    right,
    down,
    left,

    fn turn(self: Dirs) Dirs {
        return switch (self) {
            .up => Dirs.right,
            .right => Dirs.down,
            .down => Dirs.left,
            .left => Dirs.up,
        };
    }
};

fn findGuard(grid: *const Grid) ?IPos {
    for (0..grid.height) |r| {
        for (0..grid.width) |c| {
            const pos: IPos = .{ .row = @intCast(r), .col = @intCast(c) };
            if (grid.get(pos).? == '^') {
                return pos;
            }
        }
    }

    return null;
}

fn getIndex(pos: IPos, width: usize) usize {
    const row: usize = @intCast(pos.row);
    const col: usize = @intCast(pos.col);
    return row * width + col;
}

fn move(pos: IPos, dir: Dirs) IPos {
    var row = pos.row;
    var col = pos.col;
    switch (dir) {
        Dirs.up => {
            row -= 1;
        },
        Dirs.right => {
            col += 1;
        },
        Dirs.down => {
            row += 1;
        },
        Dirs.left => {
            col -= 1;
        },
    }
    return .{ .row = row, .col = col };
}

const TraceItem = struct {
    pos: IPos,
    dir: Dirs,
};

fn tracePath(allocator: std.mem.Allocator, grid: *const Grid, extra: ?IPos) ![]TraceItem {
    var trace = std.ArrayList(TraceItem).init(allocator);
    defer trace.deinit();

    var gIPos = findGuard(grid).?;

    var visited: []DirVisited = try allocator.alloc(DirVisited, grid.width * grid.height);
    defer allocator.free(visited);
    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
            visited[getIndex(pos, grid.width)] = DirVisited{};
        }
    }

    var dir = Dirs.up;
    try trace.append(TraceItem{ .pos = gIPos, .dir = dir });

    var inMap = true;
    while (inMap) {
        // std.debug.print("{d} {d}\n", .{ gIPos.row, gIPos.col });
        // Update visited
        switch (dir) {
            Dirs.up => {
                visited[getIndex(gIPos, grid.width)].up = true;
            },
            Dirs.right => {
                visited[getIndex(gIPos, grid.width)].right = true;
            },
            Dirs.down => {
                visited[getIndex(gIPos, grid.width)].down = true;
            },
            Dirs.left => {
                visited[getIndex(gIPos, grid.width)].left = true;
            },
        }

        // Make a move
        var moved = false;
        while (!moved) {
            const nextIPos = move(gIPos, dir);
            if (grid.get(nextIPos)) |tile| {
                // Treat extra as an extra obstacle
                var hitsExtra = false;
                if (extra) |e| {
                    if (e.row == nextIPos.row and e.col == nextIPos.col) {
                        hitsExtra = true;
                    }
                }

                if (tile == '#' or hitsExtra) {
                    // Turn right
                    dir = dir.turn();
                } else {
                    gIPos = nextIPos;
                    try trace.append(TraceItem{
                        .pos = gIPos,
                        .dir = dir,
                    });
                    moved = true;
                }
            } else {
                inMap = false;
                break;
            }
        }

        if (inMap) {
            // Check if repeat position
            const v = visited[getIndex(gIPos, grid.width)];
            if ((dir == Dirs.up and v.up) or
                (dir == Dirs.right and v.right) or
                (dir == Dirs.down and v.down) or
                (dir == Dirs.left and v.left))
            {
                return &[_]TraceItem{};
            }
        }
    }

    return trace.toOwnedSlice();
}

pub fn Aoc6(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const grid = Grid.fromReader(allocator, reader) catch return AocError.ParseFailure;
            defer grid.deinit();

            const trace = try tracePath(allocator, &grid, null);
            defer allocator.free(trace);

            // Part 1
            var visited = std.AutoHashMap(IPos, void).init(allocator);
            defer visited.deinit();

            for (trace) |t| {
                if (visited.contains(t.pos)) {
                    std.debug.print("{any}\n", .{t.pos});
                }
                try visited.put(t.pos, {});
            }

            std.debug.print("done part 1\n", .{});

            // Part 2
            var extras = std.AutoHashMap(IPos, void).init(allocator);
            defer extras.deinit();

            for (trace[1..]) |t| {
                const extraIPos = t.pos;
                if (grid.get(extraIPos)) |tile| {
                    if (tile == '.') {
                        const extraTrace = try tracePath(allocator, &grid, extraIPos);
                        if (extraTrace.len == 0) {
                            try extras.put(extraIPos, {});
                        } else {
                            allocator.free(extraTrace);
                        }
                    }
                }
            }

            return .{ .part1 = visited.count(), .part2 = extras.count() };
        }
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc6.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}
