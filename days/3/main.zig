const std = @import("std");
const Allocator = std.mem.Allocator;
const parseInt = std.fmt.parseInt;
const T = std.testing;
const expect = std.testing.expect;

const TokenType = enum { num, comma, mul_start, mul_end, junk, enable };
const Token = union(TokenType) { num: u64, comma, mul_start, mul_end, junk, enable: bool };

fn isDigit(chr: u8) bool {
    return '0' <= chr and chr <= '9';
}

const Tokenizer = struct {
    text: []const u8,
    idx: usize = 0,
    fn next(self: *Tokenizer) ?Token {
        if (self.idx >= self.text.len) {
            return null;
        }

        if (self.text[self.idx] == ',') {
            self.idx += 1;
            return Token.comma;
        }

        if (self.text[self.idx] == ')') {
            self.idx += 1;
            return Token.mul_end;
        }

        if (std.mem.startsWith(u8, self.text[self.idx..], "mul(")) {
            self.idx += 4;
            return Token.mul_start;
        }

        if (std.mem.startsWith(u8, self.text[self.idx..], "do()")) {
            self.idx += 4;
            return Token{ .enable = true };
        }

        if (std.mem.startsWith(u8, self.text[self.idx..], "don't()")) {
            self.idx += 7;
            return Token{ .enable = false };
        }

        if (isDigit(self.text[self.idx])) {
            return self.nextNum();
        }

        self.idx += 1;
        var old = self.idx;
        while (self.next()) |token| {
            if (token == Token.junk) {
                old = self.idx;
            } else {
                self.idx = old;
                break;
            }
        }
        return Token.junk;
    }

    fn nextNum(self: *Tokenizer) Token {
        var num: u64 = 0;

        while (self.idx < self.text.len and isDigit(self.text[self.idx])) {
            num = num * 10 + (self.text[self.idx] - '0');
            self.idx += 1;
        }

        return Token{ .num = num };
    }
};

const Mul = struct {
    left: u64,
    right: u64,
    enabled: bool,
    fn eval(self: *const Mul) u64 {
        return self.left * self.right;
    }
};

const Parser = struct {
    tokenizer: Tokenizer,
    enabled: bool = true,
    fn next(self: *Parser) ?Mul {
        // Basic state machine with 5 states:
        // 0: expecting mul(
        // 1: expecting left num
        // 2: expecting comma
        // 3: expecting right num
        // 4: expecting )
        var state: u8 = 0;
        var left: u64 = 0;
        var right: u64 = 0;

        while (self.tokenizer.next()) |token| {
            if (token == Token.enable) {
                self.enabled = token.enable;
                state = 0;
                continue;
            }

            if (state == 0) {
                if (token == Token.mul_start) {
                    state += 1;
                } else {
                    state = 0;
                }
            } else if (state == 1) {
                if (token == Token.num) {
                    left = token.num;
                    state += 1;
                } else {
                    state = 0;
                }
            } else if (state == 2) {
                if (token == Token.comma) {
                    state += 1;
                } else {
                    state = 0;
                }
            } else if (state == 3) {
                if (token == Token.num) {
                    right = token.num;
                    state += 1;
                } else {
                    state = 0;
                }
            } else if (state == 4) {
                if (token == Token.mul_end) {
                    // Done parsing a mul
                    return Mul{ .left = left, .right = right, .enabled = self.enabled };
                } else {
                    state = 0;
                }
            }

            if (token == Token.mul_start) {
                state = 1;
            }
        }

        return null;
    }
};

fn aoc3(reader: anytype) !struct { u64, u64 } {
    var total: u64 = 0;
    var total2: u64 = 0;
    var buffer: [100000]u8 = undefined;

    const bytes = try reader.readAll(&buffer);
    const t = Tokenizer{ .text = buffer[0..bytes] };
    var p = Parser{ .tokenizer = t };

    while (p.next()) |mul| {
        total += mul.eval();
        if (mul.enabled) {
            total2 += mul.eval();
        }
    }

    return .{ total, total2 };
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    const answers = try aoc3(stdin.reader());
    try stdout.writer().print("Part one: {d}\nPart two: {d}\n", .{ answers[0], answers[1] });
}

test "test tokenizer" {
    const example = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(64,64]then(mul(11,8)mul(8,5))";

    var t = Tokenizer{ .text = example };

    const expected = [_]Token{
        Token.junk,
        Token.mul_start,
        Token{ .num = 2 },
        Token.comma,
        Token{ .num = 4 },
        Token.mul_end,
        Token.junk,
        Token{ .num = 3 },
        Token.comma,
        Token{ .num = 7 },
        Token.junk,
        Token.mul_start,
        Token{ .num = 5 },
        Token.comma,
        Token{ .num = 5 },
        Token.mul_end,
        Token.junk,
        Token.mul_start,
        Token{ .num = 64 },
        Token.comma,
        Token{ .num = 64 },
        Token.junk,
        Token.mul_start,
        Token{ .num = 11 },
        Token.comma,
        Token{ .num = 8 },
        Token.mul_end,
        Token.mul_start,
        Token{ .num = 8 },
        Token.comma,
        Token{ .num = 5 },
        Token.mul_end,
        Token.mul_end,
    };

    for (expected) |token| {
        const actual = t.next().?;
        try T.expectEqual(actual, token);
    }

    try T.expectEqual(t.next(), null);
}

test "test parser" {
    const example = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(64,64]then(mul(11,8)mul(8,5))";

    const t = Tokenizer{ .text = example };
    var p = Parser{ .tokenizer = t };

    const expected = [_]Mul{
        Mul{ .left = 2, .right = 4, .enabled = true },
        Mul{ .left = 5, .right = 5, .enabled = true },
        Mul{ .left = 11, .right = 8, .enabled = true },
        Mul{ .left = 8, .right = 5, .enabled = true },
    };

    for (expected) |mul| {
        const actual = p.next().?;
        try T.expectEqual(actual, mul);
    }
}

test "test parser do / don't" {
    const example = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
    const t = Tokenizer{ .text = example };
    var p = Parser{ .tokenizer = t };

    const expected = [_]Mul{
        Mul{ .left = 2, .right = 4, .enabled = true },
        Mul{ .left = 5, .right = 5, .enabled = false },
        Mul{ .left = 11, .right = 8, .enabled = false },
        Mul{ .left = 8, .right = 5, .enabled = true },
    };

    for (expected) |mul| {
        const actual = p.next().?;
        try T.expectEqual(actual, mul);
    }
}

// test "both parts with given example" {
//     var test_allocator = std.testing.allocator;

//     var list = std.ArrayList(u8).init(test_allocator);
//     defer list.deinit();

//     try list.appendSlice("7 6 4 2 1\n1 2 7 8 9\n9 7 6 2 1\n1 3 2 4 5\n8 6 4 4 1\n1 3 6 7 9");

//     var stream = std.io.fixedBufferStream(list.items);

//     const answers = try aoc2(&test_allocator, stream.reader());

//     try expect(answers[0] == 2);
//     try expect(answers[1] == 4);
// }
