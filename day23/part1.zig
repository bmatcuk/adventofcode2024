const std = @import("std");

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
            return std.math.order(b.neighbors.items.len, a.neighbors.items.len);
        }
    };

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
        if (our_name[0] == 't') {
            try self.degree_queue.add(node);
        }
        return node;
    }

    /// Add an edge to the Graph.
    pub fn addEdge(self: *Self, node1: *Node, node2: *Node) !void {
        self.degree_queue.context.updating = true;
        defer self.degree_queue.context.updating = false;

        try node1.neighbors.append(self.allocator, node2);
        if (node1.name[0] == 't') {
            try self.degree_queue.update(node1, node1);
        }

        try node2.neighbors.append(self.allocator, node1);
        if (node2.name[0] == 't') {
            try self.degree_queue.update(node2, node2);
        }
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

    // The problem is to basically find cliques of size 3 (ie, triangles) where
    // at least one of the computers started with a "t". While we built the
    // graph, we created a PriorityQueue of each computer that started with a
    // "t", prioritized by greatest degree.
    var marks = std.StringHashMap(void).init(allocator);
    defer marks.deinit();

    var chief_triangles: u32 = 0;
    while (graph.degree_queue.removeOrNull()) |node| {
        // mark neighbors
        marks.clearRetainingCapacity();
        for (node.neighbors.items) |neighbor| {
            try marks.put(neighbor.name, {});
        }

        // For each neighbor, check if _they_ have a marked neighbor. If they
        // do, there's a triangle!
        for (node.neighbors.items) |neighbor| {
            _ = marks.remove(neighbor.name);
            for (neighbor.neighbors.items) |distant_neighbor| {
                if (marks.contains(distant_neighbor.name)) {
                    chief_triangles += 1;
                }
            }
        }

        // Remove this node from the graph so we don't consider it again. This
        // can technically change priorities in the PriorityQueue, but, at this
        // point, we don't really care.
        graph.removeNode(node);
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{chief_triangles});
}
