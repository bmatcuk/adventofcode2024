const std = @import("std");

const Trie = struct {
    const Self = @This();
    const Node = struct {
        // Expected numbers in keys are [-9,9]
        children: [19]?*Self.Node = [_]?*Self.Node{null} ** 19,
        last_updated_for_monkey: usize = 0,
        value: u32 = 0,
    };

    allocator: std.mem.Allocator,
    parent: Self.Node,

    pub fn init(allocator: std.mem.Allocator) Trie {
        return Trie{
            .allocator = allocator,
            .parent = Self.Node{},
        };
    }

    fn deinit_recursive(self: *Self, node: *Node) void {
        for (node.children) |maybe_child| if (maybe_child) |child| {
            self.deinit_recursive(child);
        };
        self.allocator.destroy(node);
    }

    pub fn deinit(self: *Self) void {
        for (self.parent.children) |maybe_child| if (maybe_child) |child| {
            self.deinit_recursive(child);
        };
    }

    pub fn insert(self: *Self, monkey: usize, key: []const i8, value: u8) !u32 {
        var node = &self.parent;
        for (key) |c| {
            const idx: usize = @intCast(c + 9);
            if (node.children[idx]) |child| {
                node = child;
            } else {
                const child = try self.allocator.create(Self.Node);
                @memset(&child.children, null);
                child.last_updated_for_monkey = 0;
                child.value = 0;
                node.children[idx] = child;
                node = child;
            }
        }

        // ignore updates from the same monkey later in the sequence
        if (node.last_updated_for_monkey != monkey) {
            node.last_updated_for_monkey = monkey;
            node.value += value;
        }
        return node.value;
    }
};

fn calculate_secret_number(secret: u64) u64 {
    const one = ((secret * 64) ^ secret) % 16777216;
    const two = ((one / 32) ^ one) % 16777216;
    return ((two * 2048) ^ two) % 16777216;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var bids = Trie.init(allocator);
    defer bids.deinit();

    var buf: [16]u8 = undefined;
    var sequence: [2000]i8 = undefined;
    var max_bananas: u32 = 0;
    var monkey: usize = 1;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (monkey += 1) {
        var secret = try std.fmt.parseUnsigned(u64, line, 10);
        var prev_bid: i8 = @intCast(secret % 10);
        for (0..2000) |idx| {
            secret = calculate_secret_number(secret);

            const bid: u8 = @intCast(secret % 10);
            sequence[idx] = @as(i8, @intCast(bid)) - prev_bid;
            prev_bid = @intCast(bid);
            if (idx >= 3) {
                const bananas = try bids.insert(monkey, sequence[(idx - 3)..(idx + 1)], bid);
                max_bananas = @max(max_bananas, bananas);
            }
        }
    }

    // too high: 1948
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{max_bananas});
}
