const std = @import("std");

const WIDTH = 101;
const HEIGHT = 103;

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
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var buf: [64]u8 = undefined;
    var quadrants = [_]u32{0} ** 4;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var robot = try parse_robot(line);
        robot.simulate(100);
        if (robot.x < @divTrunc(WIDTH, 2)) {
            if (robot.y < @divTrunc(HEIGHT, 2)) {
                quadrants[1] += 1;
            } else if (robot.y > @divTrunc(HEIGHT, 2)) {
                quadrants[2] += 1;
            }
        } else if (robot.x > @divTrunc(WIDTH, 2)) {
            if (robot.y < @divTrunc(HEIGHT, 2)) {
                quadrants[0] += 1;
            } else if (robot.y > @divTrunc(HEIGHT, 2)) {
                quadrants[3] += 1;
            }
        }
    }

    var total: u32 = 1;
    for (quadrants) |quadrant| {
        total *= quadrant;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{total});
}
