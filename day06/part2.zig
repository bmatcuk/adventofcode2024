const std = @import("std");

const State = enum {
    guard_path,
    modified_guard_path,
    done,
};

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

    pub fn to_the_right(self: Self) Direction {
        return switch (self) {
            Direction.up => Direction.right,
            Direction.right => Direction.down,
            Direction.down => Direction.left,
            Direction.left => Direction.up,
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

    pub fn try_get(self: Self, x: usize, y: usize) ?u8 {
        if (x >= self.width or y >= self.height) {
            return null;
        }

        const idx = self.get_idx(x, y);
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

    pub fn set_obstacle(self: Self, x: usize, y: usize) void {
        const idx = self.get_idx(x, y);
        self.data[idx] = '#';
    }

    pub fn clear_obstacle(self: Self, x: usize, y: usize) void {
        const idx = self.get_idx(x, y);
        self.data[idx] = '.';
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
    var direction_tuple = direction.to_tuple();

    const visited = try allocator.alloc(u4, width * height);
    const visited_copy = try allocator.alloc(u4, visited.len);
    @memset(visited, 0);
    visited[@intCast(current_y * @as(isize, @intCast(width)) + current_x)] = @intFromEnum(direction);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Puzzle {d}x{d}\n", .{ width, height });
    try stdout.print("Guard {d}x{d}\n", .{ current_x, current_y });

    var save_x = current_x;
    var save_y = current_y;
    var save_direction = direction;
    var state = State.guard_path;
    var loops: u32 = 0;
    var step: u32 = 1;
    try stdout.print("Step {d: >4}", .{0});
    while (state != State.done) : (step += 1) {
        try stdout.print("\rStep {d: >4}", .{step});
        while (puzzle.try_get_direction(current_x, current_y, direction)) |char| {
            switch (char) {
                '#' => {
                    direction = direction.to_the_right();
                    direction_tuple = direction.to_tuple();

                    const idx: usize = @intCast(current_y * @as(isize, @intCast(width)) + current_x);
                    if (state == State.guard_path) {
                        visited[idx] |= @intFromEnum(direction);
                    } else if (state == State.modified_guard_path) {
                        if ((visited_copy[idx] & @intFromEnum(direction)) > 0) {
                            // turning here caused a loop
                            loops += 1;
                            break;
                        }
                        visited_copy[idx] |= @intFromEnum(direction);
                    }
                },
                else => {
                    if (state == State.guard_path) {
                        const current_idx: usize = @intCast(current_y * @as(isize, @intCast(width)) + current_x);

                        // update the next real position for the guard
                        save_x = current_x + direction_tuple[0];
                        save_y = current_y + direction_tuple[1];
                        save_direction = direction;

                        const future_idx: usize = @intCast(save_y * @as(isize, @intCast(width)) + save_x);

                        if (visited[future_idx] > 0) {
                            // can't put an obstacle in a place the guard has
                            // already been, because that would have changed
                            // his movement earlier
                            current_x = save_x;
                            current_y = save_y;
                        } else if ((visited[current_idx] & @intFromEnum(direction.to_the_right())) > 0) {
                            // placing an obstacle in front will definitely
                            // cause a loop because it will cause the guard to
                            // turn to a direction they've already been. So,
                            // just continue on.
                            loops += 1;
                            current_x = save_x;
                            current_y = save_y;
                        } else {
                            // duplicate the map of the guard's visited spots
                            @memcpy(visited_copy, visited);

                            // save the direction, then pretend the guard hit an
                            // obstacle and turned right
                            direction = direction.to_the_right();
                            direction_tuple = direction.to_tuple();
                            state = State.modified_guard_path;
                            puzzle.set_obstacle(@intCast(save_x), @intCast(save_y));

                            visited_copy[current_idx] |= @intFromEnum(direction);
                        }

                        // mark that the guard will be there in the future
                        visited[future_idx] |= @intFromEnum(save_direction);
                    } else if (state == State.modified_guard_path) {
                        // update the guard position
                        current_x += direction_tuple[0];
                        current_y += direction_tuple[1];

                        // check if the guard has been here, facing the same
                        // direction as before
                        const idx: usize = @intCast(current_y * @as(isize, @intCast(width)) + current_x);
                        if ((visited_copy[idx] & @intFromEnum(direction)) > 0) {
                            // found a loop - quit
                            loops += 1;
                            break;
                        }
                        visited_copy[idx] |= @intFromEnum(direction);
                    }
                },
            }
        }

        state = switch (state) {
            State.guard_path => State.done,
            State.modified_guard_path => brk: {
                // clear the obstacle and reset the guard to the saved position
                puzzle.clear_obstacle(@intCast(save_x), @intCast(save_y));
                current_x = save_x;
                current_y = save_y;
                direction = save_direction;
                direction_tuple = direction.to_tuple();
                break :brk State.guard_path;
            },
            else => state,
        };
    }

    try stdout.print("\nResult: {d}\n", .{loops});
}
