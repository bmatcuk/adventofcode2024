const std = @import("std");

const WIDTH = 101;
const HEIGHT = 103;
// const WIDTH = 11;
// const HEIGHT = 7;

const Robot = struct {
    const Self = @This();

    x: i32,
    y: i32,
    vx: i32,
    vy: i32,

    pub fn simulate(self: *Self, runs: i32) void {
        self.x = @mod(self.vx * runs + self.x, WIDTH);
        self.y = @mod(self.vy * runs + self.y, HEIGHT);
    }
};

fn parse_robot(line: []u8) !Robot {
    var idx = std.mem.indexOfScalar(u8, line, ',') orelse return error.NoComma;
    const x = try std.fmt.parseInt(i32, line[2..idx], 10);

    const idx2 = std.mem.indexOfScalar(u8, line, ' ') orelse return error.NoSpace;
    const y = try std.fmt.parseInt(i32, line[(idx + 1)..idx2], 10);

    idx = std.mem.indexOfScalar(u8, line[idx2..], ',') orelse return error.NoSecondComma;
    idx += idx2;

    const vx = try std.fmt.parseInt(i32, line[(idx2 + 3)..idx], 10);
    const vy = try std.fmt.parseInt(i32, line[(idx + 1)..], 10);

    return Robot{
        .x = x,
        .y = y,
        .vx = vx,
        .vy = vy,
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var robots = std.ArrayList(Robot).init(allocator);
    defer robots.deinit();

    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try robots.append(try parse_robot(line));
    }

    // find a time when the variance is minimized in the x direction, and
    // another when the variance of y is minimized.
    const n = @as(f64, @floatFromInt(robots.items.len));
    var sum_x: i32 = undefined;
    var sum_y: i32 = undefined;
    var min_variance_x: f64 = 1_000_000.0;
    var min_variance_y: f64 = 1_000_000.0;
    var best_tx: i32 = 0;
    var best_ty: i32 = 0;
    for (1..@max(WIDTH, HEIGHT) + 1) |step| {
        sum_x = 0;
        sum_y = 0;
        for (robots.items) |*robot| {
            robot.simulate(1);
            sum_x += robot.x;
            sum_y += robot.y;
        }

        const mean_x = @as(f64, @floatFromInt(sum_x)) / n;
        const mean_y = @as(f64, @floatFromInt(sum_y)) / n;
        var variance_x: f64 = 0.0;
        var variance_y: f64 = 0.0;
        for (robots.items) |robot| {
            variance_x += std.math.pow(f64, @as(f64, @floatFromInt(robot.x)) - mean_x, 2.0);
            variance_y += std.math.pow(f64, @as(f64, @floatFromInt(robot.y)) - mean_y, 2.0);
        }
        variance_x /= n;
        variance_y /= n;

        if (variance_x < min_variance_x) {
            min_variance_x = variance_x;
            best_tx = @intCast(step);
        }
        if (variance_y < min_variance_y) {
            min_variance_y = variance_y;
            best_ty = @intCast(step);
        }
    }

    // Idea is that the x coordinates will reach a point of low variance every
    // WIDTH time steps, ie, every time `t mod WIDTH = best_tx`. The same is
    // true of the y coordinates. Mathematically, it could be written as:
    //   t = best_tx (mod WIDTH)
    //   t = best_ty (mod HEIGHT)
    //
    // Where `(mod X)` indicates "modular arithmetic".
    //
    // The first equation can be rewritten as `t = best_tx + k * WIDTH`. And,
    // so, since both equations must be equal to one-another:
    //   best_tx + k * WIDTH = best_ty (mod HEIGHT)
    //   k * WIDTH = best_ty - best_tx (mod HEIGHT)
    //   k = inverse(WIDTH) * (best_ty - best_tx) (mod HEIGHT)
    //
    // Modular arithmetic does not have division, which is why we cannot simply
    // divide by WIDTH. We must compute the modular inverse. Luckily, it's a
    // constant, so we can precompute it using Wolfram Alpha, for example:
    //   https://www.wolframalpha.com/input?i=inverse+of+101+modulo+103
    //
    // Answer is 51.
    //
    // Plugging `k` back into `t = best_tx + k * WIDTH` will give the answer.
    const k = @mod(51 * (best_ty - best_tx), HEIGHT);
    const t = best_tx + k * WIDTH;

    const stdout = std.io.getStdOut().writer();
    var board = [_]u8{undefined} ** (WIDTH * HEIGHT);
    @memset(&board, '.');
    for (robots.items) |*robot| {
        robot.simulate(@intCast(t - @max(WIDTH, HEIGHT)));
        board[@intCast(robot.y * WIDTH + robot.x)] = '#';
    }

    for (0..HEIGHT) |y| {
        try stdout.print("{s}\n", .{board[(y * WIDTH)..((y + 1) * WIDTH)]});
    }
    try stdout.print("Result: {d}\n", .{t});
}
