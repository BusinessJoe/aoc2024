const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;
const input = @import("input");
const Grid = input.Grid;
const IPos = input.IPos;
const types = @import("types");
const AocError = types.AocError;
const Answer = types.Answer;

const Dir = enum {
    left,
    right,
    up,
    down,

    fn turnLeft(self: Dir) Dir {
        return switch (self) {
            .left => .down,
            .right => .up,
            .up => .left,
            .down => .right,
        };
    }

    fn turnRight(self: Dir) Dir {
        return switch (self) {
            .left => .up,
            .right => .down,
            .up => .right,
            .down => .left,
        };
    }
};

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

const PosDir = struct {
    pos: IPos,
    dir: Dir,
};

fn AdjacencyList(comptime T: type) type {
    return struct {
        const Map = std.AutoHashMap(T, std.ArrayList(EdgeCost));
        const EdgeCost = struct {
            cost: u64,
            to: T,
        };

        map: Map,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{
                .map = Map.init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.map.valueIterator();
            while (it.next()) |list| {
                list.deinit();
            }
            self.map.deinit();
        }

        pub fn costBetween(self: Self, from: T, to: T) u64 {
            if (self.map.get(from)) |list| {
                for (list.items) |edge_cost| {
                    if (std.meta.eql(edge_cost.to, to)) {
                        return edge_cost.cost;
                    }
                }
                return 0;
            } else {
                return 0;
            }
        }

        pub fn addEdge(self: *Self, from: T, to: T, cost: u64) !void {
            if (self.map.getPtr(from)) |list| {
                var l = list.*;
                try l.append(EdgeCost{ .to = to, .cost = cost });
                try self.map.put(from, l);
            } else {
                var list = std.ArrayList(EdgeCost).init(self.allocator);
                try list.append(EdgeCost{ .to = to, .cost = cost });
                try self.map.put(from, list);
            }
        }

        pub fn neighbors(self: Self, from: T) ?[]EdgeCost {
            if (self.map.get(from)) |list| {
                return list.items;
            }
            return null;
        }
    };
}

fn buildGraph(allocator: Allocator, grid: Grid) !AdjacencyList(PosDir) {
    var adj_list = AdjacencyList(PosDir).init(allocator);

    for (0..grid.height) |row| {
        for (0..grid.width) |col| {
            const pos = IPos{ .row = @intCast(row), .col = @intCast(col) };

            const tile = grid.get(pos).?;
            if (tile == '#') {
                continue;
            }

            // This is an empty space so we consider its adjacencies

            const dirs = [_]Dir{ .left, .right, .up, .down };
            for (dirs) |dir| {
                // Add adjacent tiles
                if (grid.get(move(pos, dir))) |adj| {
                    if (adj != '#') {
                        const from = PosDir{ .pos = pos, .dir = dir };
                        const to = PosDir{ .pos = move(pos, dir), .dir = dir };
                        try adj_list.addEdge(from, to, 1);
                    }
                }

                // Add turns
                {
                    const from = PosDir{ .pos = pos, .dir = dir };
                    const to = PosDir{ .pos = pos, .dir = dir.turnLeft() };
                    try adj_list.addEdge(from, to, 1000);
                }
                {
                    const from = PosDir{ .pos = pos, .dir = dir };
                    const to = PosDir{ .pos = pos, .dir = dir.turnRight() };
                    try adj_list.addEdge(from, to, 1000);
                }
            }
        }
    }

    return adj_list;
}

fn Dist(comptime T: type) type {
    return struct {
        vertex: T,
        dist: ?u64,

        const Self = @This();

        fn lessThan(context: void, a: Self, b: Self) Order {
            _ = context;
            if (a.dist == null and b.dist == null) return Order.eq;
            if (a.dist == null) return Order.gt;
            if (b.dist == null) return Order.lt;

            if (a.dist.? < b.dist.?) return Order.lt;
            if (a.dist.? == b.dist.?) return Order.eq;
            return Order.gt;
        }
    };
}

fn MapList(comptime K: type, comptime V: type) type {
    return struct {
        map: std.AutoHashMap(K, std.ArrayList(V)),
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{
                .map = std.AutoHashMap(K, std.ArrayList(V)).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.map.valueIterator();
            while (it.next()) |list| {
                list.deinit();
            }
            self.map.deinit();
        }

        pub fn add(self: *Self, key: K, value: V) !void {
            if (self.map.getPtr(key)) |list| {
                var l = list.*;
                try l.append(value);
                try self.map.put(key, l);
            } else {
                var l = std.ArrayList(V).init(self.allocator);
                try l.append(value);
                try self.map.put(key, l);
            }
        }

        pub fn get(self: Self, key: K) []V {
            if (self.map.get(key)) |list| return list.items;
            return {};
        }
    };
}

/// Returns length of shortest path between source and target
fn shortestPath(
    comptime T: type,
    allocator: Allocator,
    source: T,
    target: T,
    graph: AdjacencyList(T),
) !u64 {
    var unvisited = std.PriorityQueue(Dist(T), void, Dist(T).lessThan).init(allocator, {});
    defer unvisited.deinit();
    var dist_from_src = std.AutoHashMap(T, u64).init(allocator);
    defer dist_from_src.deinit();
    var prev = std.AutoHashMap(T, T).init(allocator);
    defer prev.deinit();

    try dist_from_src.put(source, 0);
    try unvisited.add(.{ .vertex = source, .dist = 0 });

    while (unvisited.removeOrNull()) |u| {
        if (std.meta.eql(u.vertex, target)) break;

        const neighbors = graph.neighbors(u.vertex) orelse continue;
        for (neighbors) |ec| {
            const v = ec.to;
            const alt = dist_from_src.get(u.vertex).? + graph.costBetween(u.vertex, v);
            if (dist_from_src.get(v) == null or alt < dist_from_src.get(v).?) {
                if (prev.contains(v)) {
                    std.debug.print("re\n", .{});
                }
                try prev.put(v, u.vertex);
                try dist_from_src.put(v, alt);
                try unvisited.add(.{ .vertex = v, .dist = alt });
            }
        }
    }

    // Calculate shortest path by reverse iteration
    var u: T = target;
    var length: u64 = 0;
    while (true) {
        const p = prev.get(u) orelse break;
        length += graph.costBetween(p, u);
        u = p;
    }

    return length;
}

pub fn Solution(comptime R: type) type {
    return struct {
        pub fn solve(allocator: Allocator, reader: R) AocError!Answer {
            const grid = Grid.fromReader(allocator, reader) catch return error.ParseFailure;
            defer grid.deinit();

            var adj_list = try buildGraph(allocator, grid);
            defer adj_list.deinit();

            const source_pos = grid.find('S').?;
            const target_pos = grid.find('E').?;

            const source = PosDir{ .pos = source_pos, .dir = Dir.right };
            // We assume that we have to reach the target by going up (true for my input)
            const target = PosDir{ .pos = target_pos, .dir = Dir.up };

            return .{
                .part1 = try shortestPath(PosDir, allocator, source, target, adj_list),
                .part2 = 0,
            };
        }
    };
}
