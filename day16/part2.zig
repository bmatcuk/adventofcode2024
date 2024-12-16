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

    pub fn can_go_double(self: Self, direction: Direction, width: usize, height: usize) bool {
        return switch(direction) {
            Direction.north => self.y > 1,
            Direction.east => self.x < width - 2,
            Direction.south => self.y < height - 2,
            Direction.west => self.x > 1,
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
        const Movement = enum(u3) { straight, double_straight, left, right, done };

        node: Node,
        width: usize,
        height: usize,
        move: Movement = .straight,

        pub fn next(self: *NextIterator, skip_double: bool) ?Node {
            if (skip_double and self.move == .double_straight) {
                self.move = .left;
            }
            return switch (self.move) {
                .straight => brk: {
                    if (self.node.point.can_go_double(self.node.direction, self.width, self.height)) {
                        self.move = .double_straight;
                    } else {
                        self.move = .left;
                    }
                    break :brk Node{
                        .direction = self.node.direction,
                        .cost = self.node.cost + 1,
                        .point = self.node.point.go(self.node.direction),
                    };
                },
                .double_straight => brk: {
                    self.move = .left;
                    break :brk Node{
                        .direction = self.node.direction,
                        .cost = self.node.cost + 2,
                        .point = self.node.point.go(self.node.direction).go(self.node.direction),
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
    pub fn move(self: Self, width: usize, height: usize) Node.NextIterator {
        return Node.NextIterator{.node = self, .width = width, .height = height};
    }
};

const NodeState = union(enum) {
    unknown: void,
    queued: struct {
        cost: usize,
        from: *std.ArrayListUnmanaged(Point),
    },
    visited: struct {
        cost: usize,
        from: *std.ArrayListUnmanaged(Point),
    },
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

fn count_visited_nodes(puzzle: *Matrix(u8), node_states: *Matrix(NodeState), point: Point, visited: *std.AutoHashMap(Point, void)) !usize {
    var cnt: usize = 1;
    try visited.put(point, {});
    puzzle.set(point, 'O');
    switch (node_states.get(point)) {
        NodeState.unknown, NodeState.queued => return error.HowdWeGetHere,
        NodeState.visited => |node| {
            for (node.from.items) |from| {
                if (!visited.contains(from)) {
                    cnt += try count_visited_nodes(puzzle, node_states, from, visited);
                }
            }
        },
    }
    return cnt;
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
    @memset(node_states.data, NodeState{.unknown = {}});
    defer {
        for (node_states.data) |state| switch (state) {
            NodeState.unknown => {},
            NodeState.queued => |node| {
                node.from.deinit(allocator);
                allocator.destroy(node.from);
            },
            NodeState.visited => |node| {
                node.from.deinit(allocator);
                allocator.destroy(node.from);
            },
        };
        allocator.free(node_states.data);
    }

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

    // zig doesn't want to let me mutate an ArrayList inside a struct, inside a
    // union. So this is a little hacky. I'll allocate the ArrayList on the
    // heap, then store the pointer in the struct, in the union. Because
    // allocator.create doesn't actually initialize the struct, I need to
    // manually initialize `items` and `capacity`, otherwise they just pick up
    // whatever garbage is in the heap at the moment and bad things happen(tm).
    // It's hacky, but I didn't feel like figuring out the right way to it.
    const empty_from = try allocator.create(std.ArrayListUnmanaged(Point));
    empty_from.items = &[_]Point{};
    empty_from.capacity = 0;
    try queue.add(Node{.direction = Direction.east, .cost = 0, .point = start_point});
    node_states.set(start_point, NodeState{.queued = .{.cost = 0, .from = empty_from}});

    // Main loop of Dijkstra's algorithm - pop the lowest cost node. Except we
    // aren't finishing when we reach the end this time.
    while (queue.removeOrNull()) |node| {
        // mark the node visited
        switch (node_states.get(node.point)) {
            .unknown => return error.UnknownState,
            .queued => |queued| node_states.set(node.point, NodeState{.visited = .{.cost = queued.cost, .from = queued.from}}),
            .visited => return error.AlreadyVisited,
        }

        // Check the nodes that the reindeer can move to from here. The
        // iterator will return a forward move, then a double forward move,
        // before checking left and right. The reason is that we might, for
        // example, get to a node from the left with some cost, and then turn
        // up, incurring a large cost. A different path might get to the same
        // node from the bottom with a higher cost, but then continuing to move
        // up is cheaper, since it doesn't have to turn. So, it may actually
        // reach that second node with less cost.
        //
        // But, we want to skip that double move if the first forward move is
        // already the cheapest, or if the first forward move hits a wall.
        var it = node.move(width, height);
        var skip_double = false;
        while (it.next(skip_double)) |next_node| {
            // is the spot empty?
            if (puzzle.get(next_node.point) == '.') {
                switch (node_states.get(next_node.point)) {
                    NodeState.unknown => {
                        // haven't seen this node before - queue it
                        var from = try allocator.create(std.ArrayListUnmanaged(Point));
                        from.items = &[_]Point{};
                        from.capacity = 0;
                        try from.append(allocator, node.point);

                        node_states.set(next_node.point, NodeState{.queued = .{.cost = next_node.cost, .from = from}});
                        try queue.add(next_node);

                        skip_double = true;
                    },
                    NodeState.queued => |*queued| {
                        if (next_node.cost < queued.cost) {
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
                            queued.from.clearRetainingCapacity();
                            try queued.from.append(allocator, node.point);

                            node_states.set(next_node.point, NodeState{.queued = .{.cost = next_node.cost, .from = queued.from}});
                            try queue.update(next_node, next_node);

                            skip_double = true;
                        } else if (next_node.cost == queued.cost) {
                            // Another path to this node with the same cost.
                            try queued.from.append(allocator, node.point);
                            skip_double = true;
                        }
                    },
                    NodeState.visited => |*visited| {
                        if (next_node.cost == visited.cost) {
                            // Another path to this node with the same cost.
                            try visited.from.append(allocator, node.point);
                            skip_double = true;
                        }
                    },
                }
            } else {
                skip_double = true;
            }
        }
    }

    // Count all of the nodes we visited to get to the end
    var visited = std.AutoHashMap(Point, void).init(allocator);
    const node_count = try count_visited_nodes(&puzzle, &node_states, end_point, &visited);

    // too low: 629
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{node_count});
}
