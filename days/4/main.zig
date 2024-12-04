const std = @import("std");
const T = std.testing;

const Grid = struct {
    rows: []const []const u8,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, text: []const u8) !Grid {
        var lines = std.ArrayList([]const u8).init(allocator);
        var it = std.mem.split(u8, text, "\n");
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

    pub fn get(self: Grid, row: isize, col: isize) ?u8 {
        if (row < 0 or col < 0) {
            return null;
        }
        if (row >= self.height or col >= self.width) {
            return null;
        }

        const urow: usize = @intCast(row);
        const ucol: usize = @intCast(col);

        // std.debug.print("{d} {d}\n", .{ urow, ucol });

        return self.rows[urow][ucol];
    }
};

fn getDiag4(grid: *const Grid, r: isize, c: isize, dr: isize, dc: isize) ?[4]u8 {
    var text = [_]u8{ 0, 0, 0, 0 };

    for (0..4) |i| {
        const si: isize = @intCast(i);
        const row: isize = r + dr * si;
        const col: isize = c + dc * si;
        text[i] = grid.get(row, col) orelse return null;
    }

    return text;
}

fn hasMas(grid: *const Grid, r: isize, c: isize, dr: isize, dc: isize) bool {
    var text = [_]u8{ 0, 0, 0 };

    for (0..3) |i| {
        const si: isize = @intCast(i);
        const row: isize = r + dr * (si - 1);
        const col: isize = c + dc * (si - 1);
        text[i] = grid.get(row, col) orelse return false;
    }

    return std.mem.eql(u8, &text, "MAS");
}

fn part1(grid: *const Grid) u64 {
    var count: u64 = 0;

    const drs = [_]isize{ 1, 1, 1, 0, 0, -1, -1, -1 };
    const dcs = [_]isize{ -1, 0, 1, -1, 1, -1, 0, 1 };

    for (0..grid.height) |r| {
        for (0..grid.width) |c| {
            for (0..8) |i| {
                const dr = drs[i];
                const dc = dcs[i];

                if (getDiag4(grid, @intCast(r), @intCast(c), dr, dc)) |diag| {
                    if (std.mem.eql(u8, &diag, "XMAS")) {
                        count += 1;
                    }
                }
            }
        }
    }
    return count;
}

fn part2(grid: *const Grid) u64 {
    var count: u64 = 0;
    for (0..grid.height) |r| {
        for (0..grid.width) |c| {
            const ir: isize = @intCast(r);
            const ic: isize = @intCast(c);
            if ((hasMas(grid, ir, ic, 1, 1) or hasMas(grid, ir, ic, -1, -1)) and
                (hasMas(grid, ir, ic, -1, 1) or hasMas(grid, ir, ic, 1, -1)))
            {
                count += 1;
            }
        }
    }
    return count;
}

fn aoc4(allocator: std.mem.Allocator, reader: anytype) !struct { u64, u64 } {
    var buffer: [100000]u8 = undefined;
    const bytes = try reader.readAll(&buffer);

    const grid = try Grid.new(allocator, buffer[0..bytes]);
    defer grid.deinit();

    const total1 = part1(&grid);
    const total2 = part2(&grid);

    return .{ total1, total2 };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try aoc4(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers[0], answers[1] });
}
