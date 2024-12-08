const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,
};

fn calc_antinodes(p1: Point, p2: Point) std.meta.Tuple(&.{ Point, Point }) {
    const diffx = p1.x - p2.x;
    const diffy = p1.y - p2.y;
    return .{
        Point{
            .x = p1.x + diffx,
            .y = p1.y + diffy,
        },
        Point{
            .x = p2.x - diffx,
            .y = p2.y - diffy,
        },
    };
}

fn point_within_bounds(p: Point, width: isize, height: isize) bool {
    return p.x >= 0 and p.x < width and p.y >= 0 and p.y < height;
}

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
    var it = antennas.iterator();
    y = 0;
    while (it.next()) |entry| : (y += 1) {
        for (entry.value_ptr.items, 1..) |p1, tail_idx| {
            for (entry.value_ptr.items[tail_idx..]) |p2| {
                const potential_antinodes = calc_antinodes(p1, p2);
                if (point_within_bounds(potential_antinodes[0], width, height) and !unique_locations.contains(potential_antinodes[0])) {
                    try unique_locations.put(potential_antinodes[0], {});
                    antinodes += 1;
                }
                if (point_within_bounds(potential_antinodes[1], width, height) and !unique_locations.contains(potential_antinodes[1])) {
                    try unique_locations.put(potential_antinodes[1], {});
                    antinodes += 1;
                }
            }
        }
    }
    try stdout.print("Result: {d}\n", .{antinodes});
}
