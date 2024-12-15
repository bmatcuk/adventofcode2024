const std = @import("std");

const Point = struct {
    const Self = @This();

    x: isize,
    y: isize,

    pub fn add(self: *Self, point: Point) void {
        self.x += point.x;
        self.y += point.y;
    }

    pub fn sub(self: *Self, point: Point) void {
        self.x -= point.x;
        self.y -= point.y;
    }

    pub fn clone(self: Self) Point {
        return Point{
            .x = self.x,
            .y = self.y,
        };
    }

    pub fn eq(self: Self, point: Point) bool {
        return self.x == point.x and self.y == point.y;
    }
};

const State = enum {
    map,
    moves,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var map = std.ArrayList([]u8).init(allocator);
    defer {
        for (map.items) |line| {
            allocator.free(line);
        }
        map.deinit();
    }

    var buf: [1024]u8 = undefined;
    var state = State.map;
    var robot = Point{.x = 0, .y = 0};
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            State.map => {
                if (line.len == 0) {
                    // done reading the map
                    state = State.moves;
                    continue;
                }

                // copy line to map
                const elem = try map.addOne();
                elem.* = try allocator.alloc(u8, line.len);
                @memcpy(elem.*, line);

                if (robot.x == 0) {
                    // if we haven't found the initial robot position yet,
                    // check if it is on this line
                    if (std.mem.indexOfScalar(u8, line, '@')) |idx| {
                        robot.x = @intCast(idx);
                    } else {
                        robot.y += 1;
                    }
                }
            },
            State.moves => moves: for (line) |move| {
                const delta = switch (move) {
                    '^' => Point{.x = 0, .y = -1},
                    '<' => Point{.x = -1, .y = 0},
                    '>' => Point{.x = 1, .y = 0},
                    'v' => Point{.x = 0, .y = 1},
                    else => return error.UnknownMove,
                };

                var check = robot.clone();
                check.add(delta);
                while (true) switch (map.items[@intCast(check.y)][@intCast(check.x)]) {
                    '#' => continue :moves,
                    '.' => break,
                    else => check.add(delta),
                };
                while (!check.eq(robot)) {
                    map.items[@intCast(check.y)][@intCast(check.x)] = map.items[@intCast(check.y - delta.y)][@intCast(check.x - delta.x)];
                    check.sub(delta);
                }
                map.items[@intCast(robot.y)][@intCast(robot.x)] = '.';
                robot.add(delta);
            },
        }
    }

    var total: usize = 0;
    for (map.items, 0..) |row, yidx| {
        for (row, 0..) |elem, xidx| {
            if (elem == 'O') {
                total += 100 * yidx + xidx;
            }
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{total});
}
