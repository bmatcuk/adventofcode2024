const std = @import("std");

const WIDTH: usize = 71;
const HEIGHT: usize = 71;

const Direction = enum(u2) {
    north = 0,
    east,
    south,
    west,
};

/// A point along the path
const Point = struct {
    const Self = @This();

    x: usize,
    y: usize,

    pub fn eq(self: Self, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn go(self: Self, direction: Direction) ?Point {
        return switch(direction) {
            Direction.north => if (self.y > 0) Point{.x = self.x, .y = self.y - 1} else null,
            Direction.east => if (self.x < WIDTH - 1) Point{.x = self.x + 1, .y = self.y} else null,
            Direction.south => if (self.y < HEIGHT - 1) Point{.x = self.x, .y = self.y + 1} else null,
            Direction.west => if (self.x > 0) Point{.x = self.x - 1, .y = self.y} else null,
        };
    }
};

/// Information about the node
const Node = struct {
    const Self = @This();

    cost: usize,
    point: Point,

    /// Function to order the PriorityQueue - see below
    pub fn order(_: void, a: Node, b: Node) std.math.Order {
        if (a.point.eq(b.point)) {
            // Return equal if the points are equal - don't care about the
            // cost. See algo below.
            return std.math.Order.eq;
        } else if (a.cost > b.cost) {
            return std.math.Order.gt;
        } else {
            return std.math.Order.lt;
        }
    }
};

const NodeState = union(enum) {
    unknown: void,
    queued: usize,
    visited: void,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var memory = comptime init: {
        @setEvalBranchQuota(20000);
        var mem: [HEIGHT][WIDTH]u8 = undefined;
        for (0..HEIGHT) |y| {
            for (0..WIDTH) |x| {
                mem[y][x] = '.';
            }
        }
        break :init mem;
    };

    var buf: [64]u8 = undefined;
    var line_cnt: u16 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_cnt += 1) {
        if (line_cnt == 1024) break;

        const comma = std.mem.indexOfScalar(u8, line, ',').?;
        const x = try std.fmt.parseUnsigned(usize, line[0..comma], 10);
        const y = try std.fmt.parseUnsigned(usize, line[(comma + 1)..], 10);
        memory[y][x] = '#';
    }

    // Used to keep track of the state of each location on the map
    var node_states = comptime init: {
        @setEvalBranchQuota(20000);
        var states: [HEIGHT][WIDTH]NodeState = undefined;
        for (0..HEIGHT) |y| {
            for (0..WIDTH) |x| {
                states[y][x] = NodeState{.unknown = {}};
            }
        }
        break :init states;
    };

    // PriorityQueue is used for the main loop of Dijkstra's algorithm
    var queue = std.PriorityQueue(Node, void, Node.order).init(allocator, {});
    defer queue.deinit();

    try queue.add(Node{.cost = 0, .point = Point{.x = 0, .y = 0}});
    node_states[0][0] = NodeState{.queued = 0};

    // Main loop of Dijkstra's algorithm - pop the lowest cost node
    const end_point = Point{.x = WIDTH - 1, .y = HEIGHT - 1};
    var cost: usize = 0;
    while (queue.removeOrNull()) |node| {
        if (node.point.eq(end_point)) {
            cost = node.cost;
            break;
        }

        // mark the node visited
        node_states[node.point.y][node.point.x] = NodeState{.visited = {}};

        // check all four directions
        for (0..4) |direction_idx| if (node.point.go(@enumFromInt(direction_idx))) |point| {
            // is the spot empty?
            if (memory[point.y][point.x] == '.') {
                switch (node_states[point.y][point.x]) {
                    NodeState.unknown => {
                        // haven't seen this node before - queue it
                        try queue.add(Node{.cost = node.cost + 1, .point = point});
                        node_states[point.y][point.x] = NodeState{.queued = node.cost + 1};
                    },
                    NodeState.queued => |queued_cost| {
                        if (node.cost + 1 < queued_cost) {
                            // We've already queued this node, but we found a
                            // quicker way to get there. `PriorityQueue.update`
                            // is undocumented. But, what it does is: finds a
                            // node where the first argument is equal,
                            // according to the comparison function set on
                            // `PriorityQueue` creation. `Node.order`
                            // specifically returns Order.eq when the points
                            // are equal, disregarding cost or direction, so
                            // that `PriorityQueue.update` will find it. Then,
                            // it replaces the node with the second argument
                            // and reprioritizes the queue. Since the first
                            // argument is only used for comparing the point, I
                            // can use the same node for both arguments.
                            const next_node = Node{.cost = node.cost + 1, .point = point};
                            try queue.update(next_node, next_node);
                            node_states[point.y][point.x] = NodeState{.queued = next_node.cost};
                        }
                    },
                    NodeState.visited => {},
                }
            }
        };
    } else {
        return error.NoPathToEnd;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{cost});
}
