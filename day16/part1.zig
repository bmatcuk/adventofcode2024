const std = @import("std");

/// Direction reindeer is facing
const Direction = enum(u2) {
    const Self = @This();

    north,
    east,
    south,
    west,

    pub fn left(self: Self) Direction {
        return switch (self) {
            Direction.north => Direction.west,
            Direction.east => Direction.north,
            Direction.south => Direction.east,
            Direction.west => Direction.south,
        };
    }

    pub fn right(self: Self) Direction {
        return switch (self) {
            Direction.north => Direction.east,
            Direction.east => Direction.south,
            Direction.south => Direction.west,
            Direction.west => Direction.north,
        };
    }
};

/// A point along the path
const Point = struct {
    const Self = @This();

    x: usize,
    y: usize,

    pub fn eq(self: Self, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn go(self: Self, direction: Direction) Point {
        return switch(direction) {
            Direction.north => Point{.x = self.x, .y = self.y - 1},
            Direction.east => Point{.x = self.x + 1, .y = self.y},
            Direction.south => Point{.x = self.x, .y = self.y + 1},
            Direction.west => Point{.x = self.x - 1, .y = self.y},
        };
    }
};

/// Information about the node
const Node = struct {
    const Self = @This();

    direction: Direction,
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

    const NextIterator = struct {
        const Movement = enum(u2) { straight, left, right, done };

        node: Node,
        move: Movement = .straight,

        pub fn next(self: *NextIterator) ?Node {
            return switch (self.move) {
                .straight => brk: {
                    self.move = .left;
                    break :brk Node{
                        .direction = self.node.direction,
                        .cost = self.node.cost + 1,
                        .point = self.node.point.go(self.node.direction),
                    };
                },
                .left => brk: {
                    self.move = .right;
                    const dir = self.node.direction.left();
                    break :brk Node{
                        .direction = dir,
                        .cost = self.node.cost + 1001,
                        .point = self.node.point.go(dir),
                    };
                },
                .right => brk: {
                    self.move = .done;
                    const dir = self.node.direction.right();
                    break :brk Node{
                        .direction = dir,
                        .cost = self.node.cost + 1001,
                        .point = self.node.point.go(dir),
                    };
                },
                .done => null,
            };
        }
    };

    /// Returns an iterator of the next moves the reindeer could take
    pub fn move(self: Self) Node.NextIterator {
        return Node.NextIterator{.node = self};
    }
};

const NodeState = union(enum) {
    unknown: void,
    queued: usize,
    visited: void,
};

fn Matrix(comptime T: type) type {
    return struct {
        const Self = @This();

        /// data includes newline characters
        data: []T,

        /// width does _not_ include newline characters
        width: usize,
        height: usize,

        fn get_idx(self: Self, x: usize, y: usize) usize {
            return y * (self.width + 1) + x;
        }

        fn get(self: Self, point: Point) T {
            return self.data[self.get_idx(point.x, point.y)];
        }

        fn set(self: *Self, point: Point, data: T) void {
            self.data[self.get_idx(point.x, point.y)] = data;
        }
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    // assume board is square (ie, every row is the same length)
    var reader = file.reader();
    const data = try reader.readAllAlloc(allocator, 1_000_000);
    defer allocator.free(data);

    const width = std.mem.indexOfScalar(u8, data, '\n') orelse return error.NoNewLine;
    const height = data.len / (width + 1);
    var puzzle = Matrix(u8){
        .data = data,
        .width = width,
        .height = height,
    };

    // Used to keep track of the state of each location on the map
    var node_states = Matrix(NodeState){
        .data = try allocator.alloc(NodeState, data.len),
        .width = width,
        .height = height,
    };
    defer allocator.free(node_states.data);
    @memset(node_states.data, NodeState{.unknown = {}});

    const start_idx = std.mem.indexOfScalar(u8, data, 'S') orelse return error.NoStart;
    const start_point = Point{
        .x = start_idx % (width + 1),
        .y = start_idx / (width + 1),
    };

    // set the end to '.' to simplify the algo below
    const end_idx = std.mem.indexOfScalar(u8, data, 'E') orelse return error.NoEnd;
    const end_point = Point{
        .x = end_idx % (width + 1),
        .y = end_idx / (width + 1),
    };
    puzzle.set(end_point, '.');

    // PriorityQueue is used for the main loop of Dijkstra's algorithm
    var queue = std.PriorityQueue(Node, void, Node.order).init(allocator, {});
    defer queue.deinit();

    try queue.add(Node{.direction = Direction.east, .cost = 0, .point = start_point});
    node_states.set(start_point, NodeState{.queued = 0});

    // Main loop of Dijkstra's algorithm - pop the lowest cost node
    var cost: usize = 0;
    while (queue.removeOrNull()) |node| {
        if (node.point.eq(end_point)) {
            cost = node.cost;
            break;
        }

        // mark the node visited
        node_states.set(node.point, NodeState{.visited = {}});

        // check the nodes that the reindeer can move to from here
        var it = node.move();
        while (it.next()) |next_node| {
            // is the spot empty?
            if (puzzle.get(next_node.point) == '.') {
                switch (node_states.get(next_node.point)) {
                    NodeState.unknown => {
                        // haven't seen this node before - queue it
                        node_states.set(next_node.point, NodeState{.queued = next_node.cost});
                        try queue.add(next_node);
                    },
                    NodeState.queued => |queued_cost| {
                        if (next_node.cost < queued_cost) {
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
                            node_states.set(next_node.point, NodeState{.queued = next_node.cost});
                            try queue.update(next_node, next_node);
                        }
                    },
                    NodeState.visited => {},
                }
            }
        }
    } else {
        return error.NoPathToEnd;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{cost});
}
