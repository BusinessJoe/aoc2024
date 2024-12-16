const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim carriage return if on windows
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}

const GridParseError = error{
    OutOfMemory,
    ReaderFail,
    EmptyInput,
    NonRectangular,
};

pub const IPos = struct {
    row: isize,
    col: isize,

    pub fn offset(self: IPos, dr: isize, dc: isize) IPos {
        return IPos{
            .row = self.row + dr,
            .col = self.col + dc,
        };
    }

    pub fn format(
        value: IPos,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("({d}, {d})", .{ value.row, value.col });
    }
};

pub const Grid = struct {
    allocator: Allocator,

    width: usize,
    height: usize,
    elements: []u8,

    pub fn fromReader(allocator: Allocator, reader: anytype) GridParseError!Grid {
        var elements = ArrayList(u8).init(allocator);
        errdefer elements.deinit();

        var width: ?usize = null;
        var height: usize = 0;

        var buffer: [1024]u8 = undefined;
        while (nextLine(reader, &buffer) catch return error.ReaderFail) |line| {
            if (line.len == 0) {
                break;
            }

            if (width) |w| {
                if (w != line.len) {
                    return error.NonRectangular;
                }
            } else {
                width = line.len;
            }

            try elements.appendSlice(line);
            height += 1;
        }

        return Grid{
            .allocator = allocator,
            .width = width orelse return error.EmptyInput,
            .height = height,
            .elements = try elements.toOwnedSlice(),
        };
    }

    pub fn deinit(self: Grid) void {
        self.allocator.free(self.elements);
    }

    pub fn contains(self: Grid, pos: IPos) bool {
        const rowContained = 0 <= pos.row and pos.row < self.height;
        const colContained = 0 <= pos.col and pos.col < self.width;
        return rowContained and colContained;
    }

    pub fn get(self: Grid, pos: IPos) ?u8 {
        if (!self.contains(pos)) {
            return null;
        }

        const row: usize = @intCast(pos.row);
        const col: usize = @intCast(pos.col);
        const index = row * self.width + col;
        return self.elements[index];
    }

    pub fn find(self: Grid, target: u8) ?IPos {
        for (0..self.height) |row| {
            for (0..self.width) |col| {
                const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
                if (self.get(pos).? == target) return pos;
            }
        }
        return null;
    }

    pub fn set(self: *Grid, pos: IPos, value: u8) void {
        const row: usize = @intCast(pos.row);
        const col: usize = @intCast(pos.col);
        const index = row * self.width + col;
        self.elements[index] = value;
    }

    pub fn print(self: Grid) void {
        for (0..self.height) |row| {
            for (0..self.width) |col| {
                const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };
                std.debug.print("{c}", .{self.get(pos).?});
            }
            std.debug.print("\n", .{});
        }
    }
};

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "test fromReader no trailing newline" {
    const exampleData = "abcd\nefgh\nijkl";
    var stream = std.io.fixedBufferStream(exampleData);

    const grid = try Grid.fromReader(test_allocator, stream.reader());
    defer grid.deinit();

    const expectedElements = "abcdefghijkl";
    try std.testing.expectEqualSlices(u8, expectedElements, grid.elements);

    try expectEqual(4, grid.width);
    try expectEqual(3, grid.height);
}

test "test fromReader trailing newline" {
    const exampleData = "abcd\nefgh\nijkl\n";
    var stream = std.io.fixedBufferStream(exampleData);

    const grid = try Grid.fromReader(test_allocator, stream.reader());
    defer grid.deinit();

    const expectedElements = "abcdefghijkl";
    try std.testing.expectEqualSlices(u8, expectedElements, grid.elements);

    try expectEqual(4, grid.width);
    try expectEqual(3, grid.height);
}
