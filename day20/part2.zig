const std = @import("std");

/// A point along the path
const Point = struct {
    const Self = @This();

    x: i32,
    y: i32,

    pub fn eq(self: Self, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn add(self: Self, other: Point) Point {
        return Point{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }
};

const Cheat = struct {
    point: Point,
    distance: u32,
};

/// All cheats up to 20 piceseconds away
const cheats = init: {
    // An array large enough to hold a diamond shape, minus the center point,
    // and the four orthogonal points around the center.
    var array: [836]Cheat = undefined;
    var idx: usize = 0;
    var x: i32 = 0;
    var y: i32 = 20;
    while (y > 0) : (y -= 1) {
        x = 0;
        while (x <= (20 - y)) : (x += 1) {
            const distance = x + y;
            if (distance > 1) {
                array[idx] = Cheat{.point = .{.x = x, .y = y}, .distance = distance};
                array[idx + 1] = Cheat{.point = .{.x = x, .y = -y}, .distance = distance};
                idx += 2;
                if (x > 0) {
                    array[idx] = Cheat{.point = .{.x = -x, .y = y}, .distance = distance};
                    array[idx + 1] = Cheat{.point = .{.x = -x, .y = -y}, .distance = distance};
                    idx += 2;
                }
            }
        }
    }

    x = 2;
    while (x <= 20) : (x += 1) {
        const distance = x;
        array[idx] = Cheat{.point = .{.x = x, .y = 0}, .distance = distance};
        array[idx + 1] = Cheat{.point = .{.x = -x, .y = 0}, .distance = distance};
        idx += 2;
    }

    std.debug.assert(idx == 836);
    break :init array;
};

const directions = [_]Point{
    .{.x = -1, .y = 0},
    .{.x = 0, .y = -1},
    .{.x = 1, .y = 0},
    .{.x = 0, .y = 1},
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

        pub fn unchecked_get(self: Self, point: Point) T {
            return self.data[self.get_idx(@intCast(point.x), @intCast(point.y))];
        }

        pub fn try_get(self: Self, point: Point) ?T {
            if (point.x >= 0 and point.x < self.width and point.y >= 0 and point.y < self.height) {
                return self.unchecked_get(point);
            }
            return null;
        }

        pub fn unchecked_set(self: *Self, point: Point, data: T) void {
            self.data[self.get_idx(@intCast(point.x), @intCast(point.y))] = data;
        }

        pub fn try_set(self: *Self, point: Point, data: T) void {
            if (point.x >= 0 and point.x < self.width and point.y >= 0 and point.y < self.height) {
                self.unchecked_set(point, data);
            }
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

    // puzzle input
    const width = std.mem.indexOfScalar(u8, data, '\n') orelse return error.NoNewLine;
    const height = data.len / (width + 1);
    var puzzle = Matrix(u8){
        .data = data,
        .width = width,
        .height = height,
    };

    // keep track of picoseconds through the track
    var track = Matrix(?u32){
        .data = try allocator.alloc(?u32, data.len),
        .width = width,
        .height = height,
    };
    @memset(track.data, null);

    // keep track of potential cheats: key = end point, value = list of start
    // points that get to this end point
    var potential_cheats = std.AutoHashMap(Point, std.ArrayList(Cheat)).init(allocator);
    defer {
        var it = potential_cheats.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        potential_cheats.deinit();
    }

    const start_idx = std.mem.indexOfScalar(u8, data, 'S') orelse return error.NoStart;
    const start_point = Point{
        .x = @intCast(start_idx % (width + 1)),
        .y = @intCast(start_idx / (width + 1)),
    };
    data[start_idx] = '.';
    track.data[start_idx] = 0;

    const end_idx = std.mem.indexOfScalar(u8, data, 'E') orelse return error.NoEnd;
    const end_point = Point{
        .x = @intCast(end_idx % (width + 1)),
        .y = @intCast(end_idx / (width + 1)),
    };
    data[end_idx] = '.';

    // there's only one way through the track, so nothing fancy
    var current = start_point;
    var time: u32 = 1;
    var num_cheats: u32 = 0;
    while (!current.eq(end_point)) : (time += 1) {
        // find all potential cheats from this position
        for (cheats) |cheat| {
            const next_point = current.add(cheat.point);
            if (puzzle.try_get(next_point)) |c| {
                // only interested in potential cheats that lead back to the
                // track, and lead to a place we haven't been before (otherwise
                // we'd cause a loop)
                if (c == '.' and track.unchecked_get(next_point) == null) {
                    const entry = try potential_cheats.getOrPut(next_point);
                    if (!entry.found_existing) {
                        entry.value_ptr.* = std.ArrayList(Cheat).init(allocator);
                    }
                    try entry.value_ptr.append(.{.point = current, .distance = cheat.distance});
                }
            }
        }

        // find next point on the track
        for (directions) |direction| {
            const next_point = current.add(direction);
            if (puzzle.try_get(next_point)) |c| {
                if (c == '.' and track.unchecked_get(next_point) == null) {
                    track.unchecked_set(next_point, time);
                    current = next_point;
                    break;
                }
            }
        }

        // check if there are any potential cheats to the new point
        if (potential_cheats.fetchRemove(current)) |cheats_to_here| {
            for (cheats_to_here.value.items) |cheat_start| {
                const cheat_time = track.unchecked_get(cheat_start.point).? + cheat_start.distance;
                if (cheat_time + 100 <= time) {
                    // cheat saves us at least 100 picoseconds
                    num_cheats += 1;
                }
            }
            cheats_to_here.value.deinit();
        }
    }

    // too high: 3967
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{num_cheats});
}
