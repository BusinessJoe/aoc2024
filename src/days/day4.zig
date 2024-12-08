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

    pub fn get(self: Grid, row: isize, col: isize) ?u8 {
        if (row < 0 or col < 0) {
            return null;
        }
        if (row >= self.height or col >= self.width) {
            return null;
        }

        const urow: usize = @intCast(row);
        const ucol: usize = @intCast(col);

        return self.rows[urow][ucol];
    }
};

fn buildString(comptime n: comptime_int, grid: *const Grid, r: isize, c: isize, dr: isize, dc: isize) ?[n]u8 {
    var text: [n]u8 = undefined;

    for (0..n) |i| {
        const si: isize = @intCast(i);
        const row: isize = r + dr * si;
        const col: isize = c + dc * si;
        text[i] = grid.get(row, col) orelse return null;
    }

    return text;
}

fn hasXmas(grid: *const Grid, r: isize, c: isize, dr: isize, dc: isize) bool {
    var text = buildString(4, grid, @intCast(r), @intCast(c), dr, dc) orelse return false;
    return std.mem.eql(u8, &text, "XMAS");
}

fn hasMas(grid: *const Grid, r: isize, c: isize, dr: isize, dc: isize) bool {
    var text = buildString(3, grid, r - dr, c - dc, dr, dc) orelse return false;
    return std.mem.eql(u8, &text, "MAS");
}

fn part1(grid: *const Grid) u64 {
    var count: u64 = 0;

    const drs = [_]isize{ -1, -1, -1, 0, 0, 1, 1, 1 };
    const dcs = [_]isize{ -1, 0, 1, -1, 1, -1, 0, 1 };

    for (0..grid.height) |r| {
        for (0..grid.width) |c| {
            for (0..8) |i| {
                const dr = drs[i];
                const dc = dcs[i];

                if (hasXmas(grid, @intCast(r), @intCast(c), dr, dc)) {
                    count += 1;
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

pub fn Aoc4(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            var buffer: [100000]u8 = undefined;
            const bytes = reader.readAll(&buffer) catch return AocError.ParseFailure;

            const grid = try Grid.new(allocator, buffer[0..bytes]);
            defer grid.deinit();

            const total1 = part1(&grid);
            const total2 = part2(&grid);

            return .{ .part1 = total1, .part2 = total2 };
        }
    };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const answers = try Aoc4.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers[0], answers[1] });
}
