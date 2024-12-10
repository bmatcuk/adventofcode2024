const std = @import("std");

const Point = struct {
    const Self = @This();

    x: isize,
    y: isize,

    pub fn add(self: Self, point: Point) Point {
        return Point{
            .x = self.x + point.x,
            .y = self.y + point.y,
        };
    }
};

const Matrix = struct {
    const Self = @This();

    /// data includes newline characters
    data: []u8,

    /// width does _not_ include newline characters
    width: usize,
    height: usize,

    fn get_idx(self: Self, x: usize, y: usize) usize {
        return y * (self.width + 1) + x;
    }

    pub fn try_get(self: Self, point: Point) ?u8 {
        if (point.x < 0 or point.x >= self.width or point.y < 0 or point.y >= self.height) {
            return null;
        }

        const idx = self.get_idx(@intCast(point.x), @intCast(point.y));
        return self.data[idx];
    }
};

fn find_trails(puzzle: *const Matrix, point: Point, height: u8, visited: *std.AutoHashMap(Point, void)) !usize {
    const directions = [_]Point{
        Point{ .x = 0, .y = -1 },
        Point{ .x = 1, .y = 0 },
        Point{ .x = 0, .y = 1 },
        Point{ .x = -1, .y = 0 },
    };

    if (visited.contains(point)) {
        return 0;
    }
    try visited.put(point, {});

    if (height == '9') {
        return 1;
    }

    const next_height = height + 1;
    var cnt: usize = 0;
    for (directions) |direction| {
        const next_point = point.add(direction);
        if (puzzle.try_get(next_point) == next_height) {
            cnt += try find_trails(puzzle, next_point, next_height, visited);
        }
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
    const puzzle = Matrix{
        .data = data,
        .width = width,
        .height = height,
    };

    // tranverse map
    var visited = std.AutoHashMap(Point, void).init(allocator);
    defer visited.deinit();

    var trails: usize = 0;
    for (0..height) |y| {
        for (0..width) |x| {
            const point = Point{ .x = @intCast(x), .y = @intCast(y) };
            if (puzzle.try_get(point) == '0') {
                visited.clearRetainingCapacity();
                trails += try find_trails(&puzzle, point, '0', &visited);
            }
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("\nResult: {d}\n", .{trails});
}
