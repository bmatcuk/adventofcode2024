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

    pub fn try_get_offset(self: Self, x: usize, y: usize, offsetx: isize, offsety: isize) ?u8 {
        // zig complains about casting signed to unsigned and I don't care
        // enough to figure out how to make it happy... when posx or posy "goes
        // negative", the cast to unsigned makes it a really big positive
        // number, which will cause try_get() to just return null, which is
        // expected behavior.
        @setRuntimeSafety(false);
        const posx = @as(usize, @intCast(@as(isize, @intCast(x)) +% offsetx));
        const posy = @as(usize, @intCast(@as(isize, @intCast(y)) +% offsety));
        return self.try_get(posx, posy);
    }

    pub fn row_iterator(self: Self) RowIterator {
        return .{ .matrix = self };
    }

    pub fn check_xmas(self: Self, posx: usize, posy: usize) bool {
        if (self.try_get(posx, posy) == 'A') {
            const top_left = self.try_get_offset(posx, posy, -1, -1);
            if ((top_left == 'M' and self.try_get_offset(posx, posy, 1, 1) == 'S') or (top_left == 'S' and self.try_get_offset(posx, posy, 1, 1) == 'M')) {
                const top_right = self.try_get_offset(posx, posy, 1, -1);
                return (top_right == 'M' and self.try_get_offset(posx, posy, -1, 1) == 'S') or (top_right == 'S' and self.try_get_offset(posx, posy, -1, 1) == 'M');
            }
        }
        return false;
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
            if (puzzle.check_xmas(x, it.row)) {
                cnt += 1;
            }
        }
    }

    try stdout.print("Result: {d}\n", .{cnt});
}
