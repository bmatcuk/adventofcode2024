const std = @import("std");

const Direction = enum(u4) {
    const Self = @This();

    up = 1,
    right = 2,
    down = 4,
    left = 8,

    pub fn to_tuple(self: Self) std.meta.Tuple(&.{ isize, isize }) {
        return switch (self) {
            Self.up => .{ 0, -1 },
            Self.right => .{ 1, 0 },
            Self.down => .{ 0, 1 },
            Self.left => .{ -1, 0 },
        };
    }

    pub fn to_the_left(self: Self) Direction {
        return switch (self) {
            Direction.up => Direction.left,
            Direction.right => Direction.up,
            Direction.down => Direction.right,
            Direction.left => Direction.down,
        };
    }

    pub fn to_the_right(self: Self) Direction {
        return switch (self) {
            Direction.up => Direction.right,
            Direction.right => Direction.down,
            Direction.down => Direction.left,
            Direction.left => Direction.up,
        };
    }

    pub fn backward(self: Self) Direction {
        return switch (self) {
            Direction.up => Direction.down,
            Direction.right => Direction.left,
            Direction.down => Direction.up,
            Direction.left => Direction.right,
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

    pub fn try_get(self: Self, x: usize, y: usize) ?u8 {
        if (x >= self.width or y >= self.height) {
            return null;
        }

        const idx = y * (self.width + 1) + x;
        return self.data[idx];
    }

    pub fn try_get_direction(self: Self, x: isize, y: isize, direction: Direction) ?u8 {
        const tuple = direction.to_tuple();
        const posx = x + tuple[0];
        const posy = y + tuple[1];
        if (posx < 0 or posy < 0) {
            return null;
        }
        return self.try_get(@intCast(posx), @intCast(posy));
    }
};

// Every time we turn and face a new direction, any _other_ path that would get
// us to the same point, facing the same direction, would create a loop. So,
// this function works backward, filling in moves that would get us here.
fn mark_paths(puzzle: *const Matrix, visited: []u4, start_x: isize, start_y: isize, direction: Direction) void {
    const left = direction.to_the_left();
    const backward_direction = direction.backward();
    const direction_tuple = backward_direction.to_tuple();
    var current_x = start_x;
    var current_y = start_y;
    while (puzzle.try_get_direction(current_x, current_y, backward_direction)) |char| switch (char) {
        '#' => break,
        else => {
            current_x += direction_tuple[0];
            current_y += direction_tuple[1];

            const idx: usize = @intCast(current_y * @as(isize, @intCast(puzzle.height)) + current_x);
            if ((visited[idx] & @intFromEnum(direction)) > 0) {
                // already marked this space, in this direction
                break;
            }
            visited[idx] |= @intFromEnum(direction);

            if (puzzle.try_get_direction(current_x, current_y, left) == '#') {
                // might have turned this way
                visited[idx] |= @intFromEnum(left);
                mark_paths(puzzle, visited, current_x, current_y, left);
            }
        },
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

    const width = std.mem.indexOfScalar(u8, data, '\n') orelse return error.NoNewLine;
    const height = data.len / (width + 1);
    const puzzle = Matrix{
        .data = data,
        .width = width,
        .height = height,
    };

    const posidx = std.mem.indexOfScalar(u8, data, '^') orelse return error.NoGuard;
    var current_x: isize = @intCast(posidx % (width + 1));
    var current_y: isize = @intCast(posidx / (width + 1));
    var direction = Direction.up;
    var direction_left = Direction.left;
    var direction_tuple = direction.to_tuple();

    const visited = try allocator.alloc(u4, width * height);
    @memset(visited, 0);
    visited[@intCast(current_y * @as(isize, @intCast(height)) + current_x)] = @intFromEnum(direction);
    mark_paths(&puzzle, visited, current_x, current_y, direction);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Puzzle {d}x{d}\n", .{ width, height });
    try stdout.print("Guard {d}x{d} ({d})\n", .{ current_x, current_y, posidx });

    var num_loops: u32 = 0;
    while (puzzle.try_get_direction(current_x, current_y, direction)) |char| switch (char) {
        '#' => {
            direction = direction.to_the_right();
            direction_left = direction.to_the_left();
            direction_tuple = direction.to_tuple();
            mark_paths(&puzzle, visited, current_x, current_y, direction);

            const turnidx: usize = @intCast(current_y * @as(isize, @intCast(height)) + current_x);
            visited[turnidx] |= @intFromEnum(direction);
        },
        else => {
            current_x += direction_tuple[0];
            current_y += direction_tuple[1];

            // If the current position has been visited in the past, traveling
            // in the direction 90 degrees to the right, and the next spot is
            // empty, we could put an obstacle there to create a loop.
            const idx: usize = @intCast(current_y * @as(isize, @intCast(height)) + current_x);
            const been_visited = visited[idx];
            if ((been_visited & @intFromEnum(direction.to_the_right())) > 0 and puzzle.try_get_direction(current_x, current_y, direction) == '.') {
                num_loops += 1;
            }
            visited[idx] |= @intFromEnum(direction);

            // If there is an obstacle directly to the left, then any path
            // coming from the right will cause a loop. So mark that.
            if (puzzle.try_get_direction(current_x, current_y, direction_left) == '#') {
                mark_paths(&puzzle, visited, current_x, current_y, direction_left);
            }
        },
    };

    try stdout.print("Result: {d}\n", .{num_loops});
}
