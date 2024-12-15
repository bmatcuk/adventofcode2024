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

fn check_vertical_movement(map: *std.ArrayList([]u8), position: Point, delta: Point) bool {
    var check = position.clone();
    check.add(delta);
    while (true) switch (map.items[@intCast(check.y)][@intCast(check.x)]) {
        '#' => return false,
        '.' => return true,
        '[' => {
            var neighbor = check.clone();
            neighbor.x += 1;
            if (!check_vertical_movement(map, neighbor, delta)) {
                return false;
            }
            check.add(delta);
        },
        ']' => {
            var neighbor = check.clone();
            neighbor.x -= 1;
            if (!check_vertical_movement(map, neighbor, delta)) {
                return false;
            }
            check.add(delta);
        },
        else => check.add(delta),
    };
}

fn do_vertical_movement(map: *std.ArrayList([]u8), position: Point, delta: Point) void {
    var check = position.clone();
    check.add(delta);
    while (true) switch (map.items[@intCast(check.y)][@intCast(check.x)]) {
        // shouldn't ever see a wall here 'cause we've already verified the
        // movement is valid with check_vertical_movement
        '.' => break,
        '[' => {
            var neighbor = check.clone();
            neighbor.x += 1;
            do_vertical_movement(map, neighbor, delta);
            check.add(delta);
        },
        ']' => {
            var neighbor = check.clone();
            neighbor.x -= 1;
            do_vertical_movement(map, neighbor, delta);
            check.add(delta);
        },
        else => check.add(delta),
    };
    while (!check.eq(position)) {
        map.items[@intCast(check.y)][@intCast(check.x)] = map.items[@intCast(check.y - delta.y)][@intCast(check.x - delta.x)];
        check.sub(delta);
    }
    map.items[@intCast(position.y)][@intCast(position.x)] = '.';
}

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
                elem.* = try allocator.alloc(u8, line.len * 2);

                for (line, 0..) |char, idx| switch (char) {
                    'O' => {
                        elem.*[idx * 2] = '[';
                        elem.*[idx * 2 + 1] = ']';
                    },
                    '@' => {
                        robot.x = @intCast(idx * 2);
                        elem.*[idx * 2] = '@';
                        elem.*[idx * 2 + 1] = '.';
                    },
                    else => {
                        elem.*[idx * 2] = char;
                        elem.*[idx * 2 + 1] = char;
                    },
                };

                if (robot.x == 0) {
                    robot.y += 1;
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

                if (delta.x == 0) {
                    // vertical movement is more complicated
                    if (check_vertical_movement(&map, robot, delta)) {
                        do_vertical_movement(&map, robot, delta);
                        robot.add(delta);
                    }
                } else {
                    // horizontal movement
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
                }
            },
        }
    }

    var total: usize = 0;
    for (map.items, 0..) |row, yidx| {
        for (row, 0..) |elem, xidx| {
            if (elem == '[') {
                total += 100 * yidx + xidx;
            }
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{total});
}
