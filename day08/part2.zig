const std = @import("std");

const AntinodeIterator = struct {
    const Self = @This();

    p1: Point,
    p2: Point,
    diff: Point,
    current: Point,
    width: isize,
    height: isize,
    adding: bool = true,

    pub fn next(self: *Self) ?Point {
        const ret = self.current;
        if (ret.valid(self.width, self.height)) {
            self.current = if (self.adding) self.current.add(self.diff) else self.current.sub(self.diff);
            return ret;
        } else if (self.adding) {
            self.adding = false;
            self.current = self.p1.sub(self.diff);
            return if (self.current.valid(self.width, self.height)) self.current else null;
        }
        return null;
    }
};

const Point = struct {
    const Self = @This();

    x: isize,
    y: isize,

    pub fn add(self: Self, p: Point) Point {
        return Point{
            .x = self.x + p.x,
            .y = self.y + p.y,
        };
    }

    pub fn sub(self: Self, p: Point) Point {
        return Point{
            .x = self.x - p.x,
            .y = self.y - p.y,
        };
    }

    pub fn valid(self: Self, width: isize, height: isize) bool {
        return self.x >= 0 and self.x < width and self.y >= 0 and self.y < height;
    }

    pub fn antinode_iterator(self: Self, p2: Point, width: isize, height: isize) AntinodeIterator {
        return AntinodeIterator{
            .p1 = self,
            .p2 = p2,
            .diff = self.sub(p2),
            .current = self,
            .width = width,
            .height = height,
        };
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

    var antennas = std.AutoHashMap(u8, std.ArrayList(Point)).init(allocator);
    defer {
        var it = antennas.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        antennas.deinit();
    }

    const stdout = std.io.getStdOut().writer();
    var buf: [64]u8 = undefined;
    var width: isize = 0;
    var y: isize = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (y += 1) {
        width = @intCast(line.len);
        for (line, 0..) |antenna, x| {
            if (antenna != '.') {
                const p = Point{ .x = @intCast(x), .y = y };
                const entry = try antennas.getOrPut(antenna);
                if (!entry.found_existing) {
                    entry.value_ptr.* = std.ArrayList(Point).init(allocator);
                }
                try entry.value_ptr.append(p);
            }
        }
    }

    var unique_locations = std.AutoHashMap(Point, void).init(allocator);
    defer unique_locations.deinit();

    const height = y;
    var antinodes: u32 = 0;
    var it = antennas.valueIterator();
    while (it.next()) |antenna_list| {
        for (antenna_list.items, 1..) |p1, tail_idx| {
            for (antenna_list.items[tail_idx..]) |p2| {
                var antinode_it = p1.antinode_iterator(p2, width, height);
                while (antinode_it.next()) |antinode| {
                    if (!unique_locations.contains(antinode)) {
                        try unique_locations.put(antinode, {});
                        antinodes += 1;
                    }
                }
            }
        }
    }
    try stdout.print("Result: {d}\n", .{antinodes});
}
