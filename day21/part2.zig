/// Completely different approach vs part 1, but this is cool because all of
/// the real work actually happens at compile time to generate the lookup
/// tables. Runtime is just 4 lookups per code and a little math!

const std = @import("std");

const STEPS = 25;

fn KeyDirection(TKey: type) type {
    return struct {
        key: TKey,
        direction: DirectionKey,
    };
}

const DirectionKey = enum(u3) {
    const Self = @This();
    const Neighbor = KeyDirection(DirectionKey);

    up = 0,
    down,
    left,
    right,
    a,

    pub fn neighbors(self: Self) []const Neighbor {
        return switch (self) {
            .up => &[_]Neighbor{.{.key = .a, .direction = .right}, .{.key = .down, .direction = .down}},
            .down => &[_]Neighbor{.{.key = .up, .direction = .up}, .{.key = .left, .direction = .left}, .{.key = .right, .direction = .right}},
            .left => &[_]Neighbor{.{.key = .down, .direction = .right}},
            .right => &[_]Neighbor{.{.key = .a, .direction = .up}, .{.key = .down, .direction = .left}},
            .a => &[_]Neighbor{.{.key = .up, .direction = .left}, .{.key = .right, .direction = .down}},
        };
    }
};

const NumericKey = enum(u4) {
    const Self = @This();
    const Neighbor = KeyDirection(NumericKey);

    zero = 0,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    a,

    pub fn neighbors(self: Self) []const Neighbor {
        return switch (self) {
            .zero => &[_]Neighbor{.{.key = .two, .direction = .up}, .{.key = .a, .direction = .right}},
            .one => &[_]Neighbor{.{.key = .four, .direction = .up}, .{.key = .two, .direction = .right}},
            .two => &[_]Neighbor{.{.key = .one, .direction = .left}, .{.key = .five, .direction = .up}, .{.key = .three, .direction = .right}, .{.key = .zero, .direction = .down}},
            .three => &[_]Neighbor{.{.key = .two, .direction = .left}, .{.key = .six, .direction = .up}, .{.key = .a, .direction = .down}},
            .four => &[_]Neighbor{.{.key = .seven, .direction = .up}, .{.key = .five, .direction = .right}, .{.key = .one, .direction = .down}},
            .five => &[_]Neighbor{.{.key = .four, .direction = .left}, .{.key = .eight, .direction = .up}, .{.key = .six, .direction = .right}, .{.key = .two, .direction = .down}},
            .six => &[_]Neighbor{.{.key = .five, .direction = .left}, .{.key = .nine, .direction = .up}, .{.key = .three, .direction = .down}},
            .seven => &[_]Neighbor{.{.key = .four, .direction = .down}, .{.key = .eight, .direction = .down}},
            .eight => &[_]Neighbor{.{.key = .seven, .direction = .left}, .{.key = .five, .direction = .down}, .{.key = .nine, .direction = .right}},
            .nine => &[_]Neighbor{.{.key = .eight, .direction = .left}, .{.key = .six, .direction = .down}},
            .a => &[_]Neighbor{.{.key = .zero, .direction = .left}, .{.key = .three, .direction = .up}},
        };
    }
};

// precomputed lookup table of the cost to move from one direction to another
const directional_lookup: [5][5]u64 = init: {
    // costs is two 5x5 arrays, representing the number of button presses to
    // get from one directional key to another. There are two arrays because we
    // alternate between using one to represent the previous step's costs, vs
    // the current step's costs. Init to 1's because there's always the cost of
    // pushing the button.
    var costs: [2][5][5]u64 = undefined;
    for (0..5) |row| {
        for (0..5) |col| {
            costs[1][row][col] = 1;
        }
    }
    for (0..STEPS) |step| {
        const current_idx = step & 1;
        const prev_idx = current_idx ^ 1;
        for (0..5) |from| {
            for (0..5) |to| {
                costs[current_idx][from][to] = calculate_directional_costs(&costs[prev_idx], DirectionKey.a, @enumFromInt(from), @enumFromInt(to), 0).?;
            }
        }
    }
    break :init costs[(STEPS & 1) ^ 1];
};

fn calculate_directional_costs(prev_costs: *[5][5]u64, start: DirectionKey, from: DirectionKey, to: DirectionKey, prev_visited: u5) ?u64 {
    @setEvalBranchQuota(100000);
    if (from == to) return prev_costs[@intFromEnum(start)][@intFromEnum(DirectionKey.a)];

    const visited = prev_visited | (1 << @intFromEnum(from));
    var cost: ?u64 = null;
    for (from.neighbors()) |neighbor| {
        if (visited & (1 << @intFromEnum(neighbor.key)) != 0) continue;

        if (calculate_directional_costs(prev_costs, neighbor.direction, neighbor.key, to, visited)) |neighbor_cost| {
            const total_neighbor_cost = neighbor_cost + prev_costs[@intFromEnum(start)][@intFromEnum(neighbor.direction)];
            if (cost) |prev_cost| {
                cost = @min(prev_cost, total_neighbor_cost);
            } else {
                cost = total_neighbor_cost;
            }
        }
    }
    return cost;
}

const numerical_lookup: [11][11]u64 = init: {
    // similar to above, but we only need to compute the numerical lookup once,
    // so, only one 11x11 array
    var costs: [11][11]u64 = undefined;
    for (0..11) |from| {
        for (0..11) |to| {
            costs[from][to] = calculate_numerical_costs(DirectionKey.a, @enumFromInt(from), @enumFromInt(to), 0).?;
        }
    }
    break :init costs;
};

fn calculate_numerical_costs(start: DirectionKey, from: NumericKey, to: NumericKey, prev_visited: u11) ?u64 {
    @setEvalBranchQuota(100000);
    if (from == to) return directional_lookup[@intFromEnum(start)][@intFromEnum(DirectionKey.a)];

    const visited = prev_visited | (1 << @intFromEnum(from));
    var cost: ?u64 = null;
    for (from.neighbors()) |neighbor| {
        if (visited & (1 << @intFromEnum(neighbor.key)) != 0) continue;

        if (calculate_numerical_costs(neighbor.direction, neighbor.key, to, visited)) |neighbor_cost| {
            const total_neighbor_cost = neighbor_cost + directional_lookup[@intFromEnum(start)][@intFromEnum(neighbor.direction)];
            if (cost) |prev_cost| {
                cost = @min(prev_cost, total_neighbor_cost);
            } else {
                cost = total_neighbor_cost;
            }
        }
    }
    return cost;
}

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var buf: [8]u8 = undefined;
    var complexity: u128 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var previous_key: usize = @intFromEnum(NumericKey.a);
        var code: u128 = 0;
        var moves: u64 = 0;
        for (line) |c| {
            const current_key = if (c == 'A') @intFromEnum(NumericKey.a) else c - '0';
            if (c != 'A') {
                code = code * 10 + current_key;
            }
            moves += numerical_lookup[previous_key][current_key];
            previous_key = current_key;
        }
        complexity += code * moves;
    }

    // too high 292757881454310
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{complexity});
}
