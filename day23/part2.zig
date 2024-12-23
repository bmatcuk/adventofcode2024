const std = @import("std");

fn compareStrings(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b).compare(std.math.CompareOperator.lt);
}

const Graph = struct {
    const Self = @This();
    const QueueContext = struct {
        updating: bool = false,
    };
    const Node = struct {
        name: []u8,
        neighbors: std.ArrayListUnmanaged(*Node),

        pub fn order(context: QueueContext, a: *Node, b: *Node) std.math.Order {
            if (context.updating) return std.mem.order(u8, a.name, b.name);
            return std.math.order(a.neighbors.items.len, b.neighbors.items.len);
        }
    };
    const NodeSet = std.StringHashMapUnmanaged(void);

    allocator: std.mem.Allocator,
    nodes: std.StringHashMapUnmanaged(*Node),
    degree_queue: std.PriorityQueue(*Node, QueueContext, Node.order),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .nodes = std.StringHashMapUnmanaged(*Node){},
            .degree_queue = std.PriorityQueue(*Node, QueueContext, Node.order).init(allocator, .{}),
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.nodes.valueIterator();
        while (it.next()) |node| {
            node.*.neighbors.deinit(self.allocator);
            self.allocator.free(node.*.name);
            self.allocator.destroy(node.*);
        }
        self.nodes.deinit(self.allocator);
        self.degree_queue.deinit();
    }

    /// Get a Node by name, or create the Node if it does not yet exist.
    pub fn getOrPutNode(self: *Self, name: []const u8) !*Node {
        if (self.nodes.get(name)) |node| return node;

        const our_name = try self.allocator.dupe(u8, name);
        const node = try self.allocator.create(Node);
        node.name = our_name;
        node.neighbors = std.ArrayListUnmanaged(*Node){};
        try self.nodes.put(self.allocator, our_name, node);
        try self.degree_queue.add(node);
        return node;
    }

    /// Add an edge to the Graph.
    pub fn addEdge(self: *Self, node1: *Node, node2: *Node) !void {
        self.degree_queue.context.updating = true;
        defer self.degree_queue.context.updating = false;

        try node1.neighbors.append(self.allocator, node2);
        try self.degree_queue.update(node1, node1);

        try node2.neighbors.append(self.allocator, node1);
        try self.degree_queue.update(node2, node2);
    }

    /// Removes the Node from the Graph. The Node is freed after this
    /// operation.
    pub fn removeNode(self: *Self, node: *Node) void {
        for (node.neighbors.items) |neighbor| {
            if (std.mem.indexOfScalar(*Node, neighbor.neighbors.items, node)) |idx| {
                _ = neighbor.neighbors.swapRemove(idx);
            }
        }

        _ = self.nodes.remove(node.name);
        self.allocator.free(node.name);
        node.neighbors.deinit(self.allocator);
        self.allocator.destroy(node);
    }

    fn nodeSetIntersection(self: Self, set: NodeSet, nodes: []*Node) !NodeSet {
        var new_set = NodeSet{};
        for (nodes) |node| {
            if (set.contains(node.name)) {
                try new_set.put(self.allocator, node.name, {});
            }
        }
        return new_set;
    }

    /// Bron–Kerbosch algorithm with vertex ordering
    /// Returns a sorted list of nodes in the largest clique. Caller is
    /// responsible for freeing the list, but the names themselves are owned by
    /// the Graph.
    pub fn findMaximumClique(self: *Self) !?[][]const u8 {
        var p = NodeSet{};
        defer p.deinit(self.allocator);

        var nodeKeyIt = self.nodes.keyIterator();
        while (nodeKeyIt.next()) |name| {
            try p.put(self.allocator, name.*, {});
        }

        var x = NodeSet{};
        defer x.deinit(self.allocator);

        var maximum_clique: ?NodeSet = null;
        defer if (maximum_clique) |*maximum| maximum.deinit(self.allocator);

        while (self.degree_queue.removeOrNull()) |node| {
            // r is a set containing only the current node
            var r = NodeSet{};
            defer r.deinit(self.allocator);
            try r.put(self.allocator, node.name, {});

            // new_p is the intersection of p and the neighbors
            var new_p = try self.nodeSetIntersection(p, node.neighbors.items);
            defer new_p.deinit(self.allocator);

            // new_x is the intersection of x and the neighbors
            var new_x = try self.nodeSetIntersection(x, node.neighbors.items);
            defer new_x.deinit(self.allocator);

            // recurse
            try self.bronKerbosch(r, new_p, new_x, &maximum_clique);

            // remove ourself from p, and add ourself to x
            _ = p.remove(node.name);
            try x.put(self.allocator, node.name, {});
        }

        if (maximum_clique) |maximum| {
            var sorted_list = try self.allocator.alloc([]const u8, maximum.count());
            var idx: usize = 0;
            var it = maximum.keyIterator();
            while (it.next()) |name| : (idx += 1) {
                sorted_list[idx] = name.*;
            }
            std.mem.sort([]const u8, sorted_list, {}, compareStrings);
            return sorted_list;
        }
        return null;
    }

    fn bronKerbosch(self: *Self, r: NodeSet, p: NodeSet, x: NodeSet, maximum_clique: *?NodeSet) !void {
        if (p.count() == 0 and x.count() == 0) {
            if (maximum_clique.*) |*current_maximum| {
                if (r.count() > current_maximum.count()) {
                    current_maximum.deinit(self.allocator);
                    maximum_clique.* = try r.clone(self.allocator);
                }
            } else {
                maximum_clique.* = try r.clone(self.allocator);
            }
            return;
        }

        var my_p = try p.clone(self.allocator);
        defer my_p.deinit(self.allocator);

        var my_x = try x.clone(self.allocator);
        defer my_x.deinit(self.allocator);

        var it = p.keyIterator();
        while (it.next()) |name| {
            const node = self.nodes.get(name.*) orelse return error.CouldNotFindNode;

            // new_r is r with the current name added
            var new_r = try r.clone(self.allocator);
            try new_r.put(self.allocator, name.*, {});

            // new_p is the intersection of p and the node's neighbors
            // new_x is the intersection of x and the node's neighbors
            const new_p = try self.nodeSetIntersection(my_p, node.neighbors.items);
            const new_x = try self.nodeSetIntersection(my_x, node.neighbors.items);

            try self.bronKerbosch(new_r, new_p, new_x, maximum_clique);

            // remove ourself from p, and add ourself to x
            _ = my_p.remove(name.*);
            try my_x.put(self.allocator, name.*, {});
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var graph = Graph.init(allocator);
    defer graph.deinit();

    var buf: [8]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const node1 = try graph.getOrPutNode(line[0..2]);
        const node2 = try graph.getOrPutNode(line[3..]);
        try graph.addEdge(node1, node2);
    }

    if (try graph.findMaximumClique()) |maximum| {
        defer allocator.free(maximum);

        const stdout = std.io.getStdOut().writer();
        try stdout.print("Password: ", .{});
        for (maximum) |name| {
            try stdout.print("{s},", .{name});
        }
        try stdout.print("{c} \n", .{std.ascii.control_code.bs});
    } else {
        return error.NoMaximum;
    }
}
