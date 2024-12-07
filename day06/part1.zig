const std = @import("std");

const Direction = enum(u2) {
    const Self = @This();

    up,
    right,
    down,
    left,

    pub fn to_tuple(self: Self) std.meta.Tuple(&.{ isize, isize }) {
        return switch (self) {
            Self.up => .{ 0, -1 },
            Self.right => .{ 1, 0 },
            Self.down => .{ 0, 1 },
            Self.left => .{ -1, 0 },
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

    const visited = try allocator.alloc(bool, width * height);
    @memset(visited, false);
    visited[@intCast(current_y * @as(isize, @intCast(width)) + current_x)] = true;

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Puzzle {d}x{d}\n", .{ width, height });
    try stdout.print("Guard {d}x{d}\n", .{ current_x, current_y });

    var num_visited: u32 = 1;
    while (puzzle.try_get_direction(current_x, current_y, direction)) |char| switch (char) {
        '#' => direction = switch (direction) {
            Direction.up => Direction.right,
            Direction.right => Direction.down,
            Direction.down => Direction.left,
            Direction.left => Direction.up,
        },
        else => {
            const direction_tuple = direction.to_tuple();
            current_x += direction_tuple[0];
            current_y += direction_tuple[1];

            const idx: usize = @intCast(current_y * @as(isize, @intCast(width)) + current_x);
            if (!visited[idx]) {
                visited[idx] = true;
                num_visited += 1;
            }
        },
    };

    try stdout.print("Result: {d}\n", .{num_visited});
}
