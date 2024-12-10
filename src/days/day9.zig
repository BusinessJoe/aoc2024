const std = @import("std");
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

fn solvePart1(allocator: std.mem.Allocator, line: []const u8) !u64 {
    var filesystem = std.ArrayList(?u64).init(allocator);
    defer filesystem.deinit();

    // Build filesystem array
    for (line, 0..) |char, i| {
        const val = char - '0';
        const id: u64 = @as(u64, i) / 2;
        if (i % 2 == 0) {
            try filesystem.appendNTimes(id, val);
        } else {
            try filesystem.appendNTimes(null, val);
        }
    }

    // Rearrange filesystem
    var i: usize = 0;
    var right: usize = filesystem.items.len - 1;
    while (i < filesystem.items.len and i < right) : (i += 1) {
        if (filesystem.items[i] == null) {
            // find rightmost non-null
            while (filesystem.items[right] == null) {
                right -= 1;
            }
            const tmp = filesystem.items[right];
            filesystem.items[right] = filesystem.items[i];
            filesystem.items[i] = tmp;
            right -= 1;
        }
    }

    var part1: u64 = 0;
    for (filesystem.items, 0..) |val, idx| {
        if (val) |v| {
            part1 += v * idx;
        }
    }

    return part1;
}

const File = struct {
    id: ?usize,
    width: usize,
};

// Replace id block with empty block, merging
// adjacent empty blocks if necessary
fn removeBlock(fs: *std.ArrayList(File), i: usize) File {
    const block = fs.items[i];
    if (block.id == null) {
        // Block should always have an id initially
        unreachable;
    }
    fs.items[i].id = null;
    if (i + 1 < fs.items.len and fs.items[i + 1].id == null) {
        fs.items[i].width += fs.items[i + 1].width;
        _ = fs.orderedRemove(i + 1);
    }
    if (i > 0 and fs.items[i - 1].id == null) {
        fs.items[i - 1].width += fs.items[i].width;
        _ = fs.orderedRemove(i);
    }

    return block;
}

// Insert block at given index, either replacing an empty block
// or reducing its size.
fn insertBlock(fs: *std.ArrayList(File), i: usize, file: File) !void {
    if (fs.items[i].id != null) {
        // Destination should always be empty and have enough space
        unreachable;
    }
    if (fs.items[i].width < file.width) {
        unreachable;
    }

    if (fs.items[i].width == file.width) {
        // We can just replace
        fs.items[i].id = file.id;
    } else {
        fs.items[i].width -= file.width;
        try fs.insert(i, file);
    }
}

fn solvePart2(allocator: std.mem.Allocator, line: []const u8) !u64 {
    var fs = std.ArrayList(File).init(allocator);
    defer fs.deinit();

    // Build filesystem array
    for (line, 0..) |char, i| {
        const val = char - '0';
        const id: u64 = @as(u64, i) / 2;
        if (i % 2 == 0) {
            try fs.append(File{ .id = id, .width = val });
        } else {
            try fs.append(File{ .id = null, .width = val });
        }
    }

    // Rearrange filesystem
    var right: usize = fs.items.len - 1;
    var next_id = fs.items[right].id.?;

    while (right > 0) : (right -= 1) {
        const right_file = fs.items[right];
        if (right_file.id != next_id) {
            continue;
        }

        next_id -= 1;

        // We have the right-most file we'd like to move
        // so find the left-most gap that fits it
        var left: ?usize = null;
        for (fs.items, 0..) |file, i| {
            if (file.id == null and file.width >= right_file.width) {
                left = i;
                break;
            }
        }

        if (left) |l| {
            if (l < right) {
                try insertBlock(&fs, l, removeBlock(&fs, right));
            }
        }
    }

    var checksum: u64 = 0;
    // Checksum
    var fs_i: usize = 0;
    for (fs.items) |file| {
        if (file.id) |id| {
            for (0..file.width) |_| {
                checksum += id * fs_i;
                fs_i += 1;
            }
        } else {
            fs_i += file.width;
        }
    }

    return checksum;
}

pub fn Aoc9(comptime R: type) type {
    return struct {
        pub fn solve(allocator: std.mem.Allocator, reader: R) AocError!Answer {
            const line_with_nl = reader.readAllAlloc(allocator, 30000) catch return AocError.ParseFailure;
            defer allocator.free(line_with_nl);

            // Remove trailing newline
            const line = line_with_nl[0 .. line_with_nl.len - 1];

            const part1 = try solvePart1(allocator, line);
            const part2 = try solvePart2(allocator, line);

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

    const answers = try Aoc9.solve(allocator, stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers.part1, answers.part2 });
}

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
