const std = @import("std");

const Plot = struct {
    const Self = @This();

    plant: u8,
    area: usize,
    perimeter: usize,

    pub fn cost(self: Self) usize {
        return self.area * self.perimeter;
    }
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

        pub fn try_get(self: Self, x: isize, y: isize) ?T {
            if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
                return null;
            }
            return self.unchecked_get(@intCast(x), @intCast(y));
        }

        pub fn unchecked_get(self: Self, x: usize, y: usize) T {
            const idx = self.get_idx(@intCast(x), @intCast(y));
            return self.data[idx];
        }

        pub fn unchecked_set(self: *Self, x: usize, y: usize, val: T) void {
            const idx = self.get_idx(@intCast(x), @intCast(y));
            self.data[idx] = val;
        }
    };
}

fn flood(puzzle: *const Matrix(u8), visited: *Matrix(bool), plot: *Plot, x: isize, y: isize) void {
    const directions = [_]std.meta.Tuple(&.{ isize, isize }){
        .{0, -1},
        .{1, 0},
        .{0, 1},
        .{-1, 0},
    };
    for (directions) |direction| {
        const new_x = x + direction[0];
        const new_y = y + direction[1];
        if (puzzle.try_get(new_x, new_y)) |plant| {
            if (plant == plot.plant) {
                if (!visited.unchecked_get(@intCast(new_x), @intCast(new_y))) {
                    visited.unchecked_set(@intCast(new_x), @intCast(new_y), true);
                    plot.area += 1;
                    flood(puzzle, visited, plot, new_x, new_y);
                }
            } else {
                plot.perimeter += 1;
            }
        } else {
            plot.perimeter += 1;
        }
    }
}

fn process_plot(puzzle: *const Matrix(u8), visited: *Matrix(bool), x: isize, y: isize) usize {
    if (visited.try_get(x, y)) |has_visited| {
        if (has_visited) {
            return 0;
        }
    } else {
        return 0;
    }
    visited.unchecked_set(@intCast(x), @intCast(y), true);

    var plot = Plot{
        .plant = puzzle.unchecked_get(@intCast(x), @intCast(y)),
        .area = 1,
        .perimeter = 0,
    };
    flood(puzzle, visited, &plot, x, y);
    return plot.cost();
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
    const puzzle = Matrix(u8){
        .data = data,
        .width = width,
        .height = height,
    };

    var visited = Matrix(bool){
        .data = try allocator.alloc(bool, data.len),
        .width = width,
        .height = height,
    };
    @memset(visited.data, false);
    defer allocator.free(visited.data);

    var total: usize = 0;
    var y: isize = 0;
    while (y < height) : (y += 1) {
        var x: isize = 0;
        while (x < width) : (x += 1) {
            total += process_plot(&puzzle, &visited, x, y);
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{total});
}
