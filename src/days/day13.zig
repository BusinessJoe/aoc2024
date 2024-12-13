const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const ClawMachine = struct {
    ax: i64,
    ay: i64,
    bx: i64,
    by: i64,
    x: i64,
    y: i64,

    fn tokens(self: ClawMachine) ?u64 {
        const denom = self.ax * self.by - self.bx * self.ay;

        const n = @divTrunc(self.x * self.by - self.y * self.bx, denom);
        const m = @divTrunc(-self.x * self.ay + self.y * self.ax, denom);

        const x_matches = n * self.ax + m * self.bx == self.x;
        const y_matches = n * self.ay + m * self.by == self.y;

        if (x_matches and y_matches) {
            const t: u64 = @intCast(n * 3 + m);
            return t;
        }
        return null;
    }
};

fn parseXY(line: []const u8) !struct { x: i64, y: i64 } {
    var x_idx: usize = undefined;
    var c_idx: usize = undefined;
    var y_idx: usize = undefined;
    for (line, 0..) |c, i| {
        if (c == 'X') {
            x_idx = i;
        } else if (c == ',') {
            c_idx = i;
        } else if (c == 'Y') {
            y_idx = i;
        }
    }

    const x = try std.fmt.parseInt(i64, line[x_idx + 2 .. c_idx], 10);
    const y = try std.fmt.parseInt(i64, line[y_idx + 2 ..], 10);

    return .{ .x = x, .y = y };
}

fn readClawMachine(comptime R: type, reader: R) !?ClawMachine {
    var buffer: [100]u8 = undefined;
    const a_line = try input.nextLine(reader, &buffer) orelse return null;
    const a_vals = try parseXY(a_line);
    const b_line = (try input.nextLine(reader, &buffer)).?;
    const b_vals = try parseXY(b_line);
    const p_line = (try input.nextLine(reader, &buffer)).?;
    const p_vals = try parseXY(p_line);
    _ = try input.nextLine(reader, &buffer);

    return ClawMachine{
        .ax = a_vals.x,
        .ay = a_vals.y,
        .bx = b_vals.x,
        .by = b_vals.y,
        .x = p_vals.x,
        .y = p_vals.y,
    };
}

pub fn Aoc13(comptime R: type) type {
    return struct {
        pub fn solve(_: std.mem.Allocator, reader: R) AocError!Answer {
            var part1: u64 = 0;
            var part2: u64 = 0;

            while (readClawMachine(R, reader) catch return error.ParseFailure) |*machine| {
                if (machine.tokens()) |t| {
                    part1 += t;
                }
                const big_machine = ClawMachine{
                    .ax = machine.ax,
                    .ay = machine.ay,
                    .bx = machine.bx,
                    .by = machine.by,
                    .x = machine.x + 10000000000000,
                    .y = machine.y + 10000000000000,
                };
                if (big_machine.tokens()) |t| {
                    part2 += t;
                }
            }

            return .{
                .part1 = part1,
                .part2 = part2,
            };
        }
    };
}
