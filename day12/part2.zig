const std = @import("std");

const Plot = struct {
    const Self = @This();

    plant: u8,
    area: usize,
    sides: usize,

    pub fn cost(self: Self) usize {
        return self.area * self.sides;
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
    const directions = [_]std.meta.Tuple(&.{isize, isize}){
        .{0, -1},
        .{1, 0},
        .{0, 1},
        .{-1, 0},
    };

    // First two numbers are deltas to add to x and y.
    // Second two are indexes into `fenced_sides`. If both are true, then we
    // need to check the corresponding diagonal.
    const diagonals = [_]std.meta.Tuple(&.{isize, isize, usize, usize}){
        .{-1, -1, 0, 3},
        .{1, -1, 0, 1},
        .{-1, 1, 2, 3},
        .{1, 1, 1, 2},
    };

    // Number of corners equals the number of sides of the plot. So, keep track
    // of which edges continue the plot.
    var plotted_sides = [_]bool{false} ** directions.len;
    for (directions, 0..) |direction, idx| {
        const new_x = x + direction[0];
        const new_y = y + direction[1];
        if (puzzle.try_get(new_x, new_y)) |plant| {
            if (plant == plot.plant) {
                plotted_sides[idx] = true;
                if (!visited.unchecked_get(@intCast(new_x), @intCast(new_y))) {
                    visited.unchecked_set(@intCast(new_x), @intCast(new_y), true);
                    plot.area += 1;
                    flood(puzzle, visited, plot, new_x, new_y);
                }
            }
        }
    }

    // count corners, ie, adjascent sides that are not part of this plot
    if (!plotted_sides[0] and !plotted_sides[1]) {
        plot.sides += 1;
    }
    if (!plotted_sides[1] and !plotted_sides[2]) {
        plot.sides += 1;
    }
    if (!plotted_sides[2] and !plotted_sides[3]) {
        plot.sides += 1;
    }
    if (!plotted_sides[3] and !plotted_sides[0]) {
        plot.sides += 1;
    }

    // We also have to handle "inside" corners, like the inside of an "L".
    // Those a little trickier. If two adjascent sides are part of the plot,
    // and the diagonal between it is _not_, then it's an inside corner.
    var inside_corners: u8 = 0;
    for (diagonals) |diagonal| {
        if (plotted_sides[diagonal[2]] and plotted_sides[diagonal[3]]) {
            if (puzzle.unchecked_get(@intCast(x + diagonal[0]), @intCast(y + diagonal[1])) != plot.plant) {
                inside_corners += 1;
            }
        }
    }
    plot.sides += inside_corners;
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
        .sides = 0,
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
