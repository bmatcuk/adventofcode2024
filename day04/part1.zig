const std = @import("std");

const Matrix = struct {
    const Self = @This();

    /// data includes newline characters
    data: []u8,

    /// width does _not_ include newline characters
    width: usize,
    height: usize,

    pub fn try_get_row(self: Self, row: usize) ?[]u8 {
        if (row >= self.height) {
            return null;
        }

        const idx = row * (self.width + 1);
        return self.data[idx..(idx + self.width)];
    }

    pub fn try_get(self: Self, x: usize, y: usize) ?u8 {
        if (x >= self.width or y >= self.height) {
            return null;
        }

        const idx = y * (self.width + 1) + x;
        return self.data[idx];
    }

    pub fn row_iterator(self: Self) RowIterator {
        return .{ .matrix = self };
    }

    pub fn check_xmas(self: Self, startx: usize, starty: usize, dirx: isize, diry: isize) bool {
        var posx = startx;
        var posy = starty;
        for ("XMAS") |char| {
            if (self.try_get(posx, posy) != char) {
                return false;
            }

            {
                // zig complains about casting signed to unsigned and I don't
                // care enough to figure out how to make it happy... when posx
                // or posy "goes negative", the cast to unsigned makes it a
                // really big positive number, which will cause try_get() to
                // just return null, which is expected behavior.
                @setRuntimeSafety(false);
                posx = @as(usize, @intCast(@as(isize, @intCast(posx)) +% dirx));
                posy = @as(usize, @intCast(@as(isize, @intCast(posy)) +% diry));
            }
        }
        return true;
    }

    pub fn num_xmas_at_pos(self: Self, posx: usize, posy: usize) u32 {
        const directions = [8][2]isize{
            [_]isize{ -1, -1 },
            [_]isize{ -1, 0 },
            [_]isize{ -1, 1 },
            [_]isize{ 0, -1 },
            [_]isize{ 0, 1 },
            [_]isize{ 1, -1 },
            [_]isize{ 1, 0 },
            [_]isize{ 1, 1 },
        };
        var cnt: u32 = 0;
        for (directions) |dir| {
            if (self.check_xmas(posx, posy, dir[0], dir[1])) {
                cnt += 1;
            }
        }
        return cnt;
    }
};

const RowIterator = struct {
    const Self = @This();

    matrix: Matrix,
    row: usize = 0,
    started: bool = false,

    pub fn next(self: *Self) ?[]u8 {
        if (self.started) {
            self.row += 1;
        } else {
            self.started = true;
        }
        if (self.row < self.matrix.height) {
            return self.matrix.try_get_row(self.row);
        }
        return null;
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

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Puzzle {d}x{d}\n", .{ width, height });

    var cnt: u32 = 0;
    var it = puzzle.row_iterator();
    while (it.next()) |row| {
        for (row, 0..) |_, x| {
            cnt += puzzle.num_xmas_at_pos(x, it.row);
        }
    }

    try stdout.print("Result: {d}\n", .{cnt});
}
