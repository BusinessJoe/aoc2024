const std = @import("std");

pub const AocError = error{
    OutOfMemory,
    ParseFailure,
};

pub const Answer = struct {
    part1: u64,
    part2: u64,
};

pub fn Solution(comptime R: type) type {
    return *const fn (std.mem.Allocator, R) AocError!Answer;
}
// pub const Solution = *const fn (comptime R: type, std.mem.Allocator, reader: R) AocError!Answer;
