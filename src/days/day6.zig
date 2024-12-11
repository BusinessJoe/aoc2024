const std = @import("std");
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const Grid = struct {
    rows: []const []const u8,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, text: []const u8) !Grid {
        var lines = std.ArrayList([]const u8).init(allocator);
        var it = std.mem.splitScalar(u8, text, '\n');
        while (it.next()) |line| {
            if (line.len > 0) {
                try lines.append(line);
            }
        }

        const rows = try lines.toOwnedSlice();
        return Grid{
            .rows = rows,
            .width = rows.len,
            .height = rows[0].len,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Grid) void {
        self.allocator.free(self.rows);
    }

    pub fn contains(self: Grid, p: Pos) bool {
        if (p.row < 0 or p.col < 0) {
            return false;
        }
        if (p.row >= self.height or p.col >= self.width) {
            return false;
        }
        return true;
    }

    pub fn get(self: Grid, p: Pos) ?u8 {
        if (!self.contains(p)) {
            return null;
        }

        const urow: usize = @intCast(p.row);
        const ucol: usize = @intCast(p.col);

        return self.rows[urow][ucol];
    }
};

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

const Pos = struct {
    row: isize,
    col: isize,
};

fn findGuard(grid: *const Grid) ?Pos {
    for (0..grid.height) |r| {
        for (0..grid.width) |c| {
            const pos: Pos = .{ .row = @intCast(r), .col = @intCast(c) };
            if (grid.get(pos).? == '^') {
                return pos;
            }
        }
    }

    return null;
}

fn getIndex(pos: Pos, width: usize) usize {
    if (pos.row < 0 or pos.col < 0 or pos.row >= width or pos.col >= width) {
        std.debug.panic("Fuck", .{});
    }
    const row: usize = @intCast(pos.row);
    const col: usize = @intCast(pos.col);
    return row * width + col;
}

fn move(pos: Pos, dir: Dirs) Pos {
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
    pos: Pos,
    dir: Dirs,
};

fn tracePath(allocator: std.mem.Allocator, grid: *const Grid, extra: ?Pos) ![]TraceItem {
    var trace = std.ArrayList(TraceItem).init(allocator);
    defer trace.deinit();

    var gPos = findGuard(grid).?;

    var visited: []DirVisited = try allocator.alloc(DirVisited, grid.width * grid.height);
    defer allocator.free(visited);
    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = Pos{ .row = @intCast(row), .col = @intCast(col) };
            visited[getIndex(pos, grid.width)] = DirVisited{};
        }
    }

    var dir = Dirs.up;
    try trace.append(TraceItem{ .pos = gPos, .dir = dir });

    var inMap = true;
    while (inMap) {
        // std.debug.print("{d} {d}\n", .{ gPos.row, gPos.col });
        // Update visited
        switch (dir) {
            Dirs.up => {
                visited[getIndex(gPos, grid.width)].up = true;
            },
            Dirs.right => {
                visited[getIndex(gPos, grid.width)].right = true;
            },
            Dirs.down => {
                visited[getIndex(gPos, grid.width)].down = true;
            },
            Dirs.left => {
                visited[getIndex(gPos, grid.width)].left = true;
            },
        }

        // Make a move
        var moved = false;
        while (!moved) {
            const nextPos = move(gPos, dir);
            if (grid.get(nextPos)) |tile| {
                // Treat extra as an extra obstacle
                var hitsExtra = false;
                if (extra) |e| {
                    if (e.row == nextPos.row and e.col == nextPos.col) {
                        hitsExtra = true;
                    }
                }

                if (tile == '#' or hitsExtra) {
                    // Turn right
                    dir = dir.turn();
                } else {
                    gPos = nextPos;
                    try trace.append(TraceItem{
                        .pos = gPos,
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
            const v = visited[getIndex(gPos, grid.width)];
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
            var buffer: [100000]u8 = undefined;
            const bytes = reader.readAll(&buffer) catch return AocError.ParseFailure;
            const grid = try Grid.new(allocator, buffer[0..bytes]);
            defer grid.deinit();

            const trace = try tracePath(allocator, &grid, null);
            defer allocator.free(trace);

            // Part 1
            var visited = std.AutoHashMap(Pos, void).init(allocator);
            defer visited.deinit();

            for (trace) |t| {
                try visited.put(t.pos, {});
            }

            // Part 2
            var extras = std.AutoHashMap(Pos, void).init(allocator);
            defer extras.deinit();

            for (trace[1..]) |t| {
                const extraPos = t.pos;
                if (grid.get(extraPos)) |tile| {
                    if (tile == '.') {
                        const extraTrace = try tracePath(allocator, &grid, extraPos);
                        if (extraTrace.len == 0) {
                            try extras.put(extraPos, {});
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
