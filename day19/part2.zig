const std = @import("std");

const State = enum {
    towels,
    blank,
    patterns,
    done,
};

const Trie = struct {
    const Self = @This();
    const Node = struct {
        children: [26]?*Self.Node = [_]?*Self.Node{null} ** 26,
        terminal: bool = false,
        len: usize = 0,
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
            deinit_recursive(self, child);
        };
        self.allocator.destroy(node);
    }

    pub fn deinit(self: *Self) void {
        self.deinit_recursive(&self.parent);
    }

    pub fn insert(self: *Self, key: []const u8) !void {
        var node = &self.parent;
        for (key, 1..) |c, len| {
            if (node.children[c - 'a']) |child| {
                node = child;
            } else {
                const child = try self.allocator.create(Self.Node);
                @memset(&child.children, null);
                child.terminal = false;
                child.len = len;
                node.children[c - 'a'] = child;
                node = child;
            }
        }
        node.terminal = true;
    }

    const Iterator = struct {
        node: ?*Self.Node,
        key: []const u8,
        idx: usize = 0,

        pub fn next(it: *Iterator) ?usize {
            while (it.node != null and it.idx < it.key.len) {
                it.node = it.node.?.children[it.key[it.idx] - 'a'];
                it.idx += 1;
                if (it.node != null and it.node.?.terminal) {
                    return it.node.?.len;
                }
            }
            return null;
        }
    };

    pub fn iterate(self: *Self, key: []const u8) Iterator {
        return Self.Iterator{
            .node = &self.parent,
            .key = key,
        };
    }
};

fn count_valid(trie: *Trie, key: []u8, cache: []?usize) usize {
    if (cache[key.len]) |cached| return cached;
    if (key.len == 0) return 1;

    var cnt: usize = 0;
    var it = trie.iterate(key);
    while (it.next()) |len| {
        cnt += count_valid(trie, key[len..], cache);
    }
    cache[key.len] = cnt;
    return cnt;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var available_towels = Trie.init(allocator);
    defer available_towels.deinit();

    var buf: [4096]u8 = undefined;
    var state = State.towels;
    var valid: usize = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            .towels => {
                var it = std.mem.splitSequence(u8, line, ", ");
                while (it.next()) |towel| {
                    try available_towels.insert(towel);
                }
                state = State.blank;
            },
            .blank => state = State.patterns,
            .patterns => {
                const cache = try allocator.alloc(?usize, line.len + 1);
                @memset(cache, null);
                valid += count_valid(&available_towels, line, cache);
                allocator.free(cache);
            },
            .done => {},
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{valid});
}
