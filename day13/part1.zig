const std = @import("std");

const State = enum(u2) {
    button_a = 0,
    button_b,
    prize,
    blank,
};

const Point = struct {
    x: i32 = 0,
    y: i32 = 0,
};

fn parse_point(line: []u8, at: usize, point: *Point) !void {
    // all numbers seem to be positive in my input
    const comma = std.mem.indexOfScalar(u8, line, ',') orelse return error.NoComma;
    point.x = try std.fmt.parseUnsigned(i32, line[at..comma], 10);
    point.y = try std.fmt.parseUnsigned(i32, line[(comma + 4)..], 10);
}

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var buf: [64]u8 = undefined;
    var state = State.button_a;
    var button_a = Point{};
    var button_b = Point{};
    var prize = Point{};
    var total: u32 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            State.button_a => try parse_point(line, 12, &button_a),
            State.button_b => try parse_point(line, 12, &button_b),
            State.prize => {
                try parse_point(line, 9, &prize);

                // Xprize = A * Xa + B * Xb
                // Yprize = A * Ya + B * Yb
                // Solve for A and B and ensure they are positive integers
                //
                // Using Cramer's Rule:
                // denominator = det([Xa Xb; Ya Yb]) = Xa * Yb - Ya * Xb
                // a = det([Xprize Xb; Yprize Yb]) / denominator
                // b = det([Xa Xprize; Ya Yprize]) / denominator
                const denominator = button_a.x * button_b.y - button_a.y * button_b.x;
                const a_numerator = prize.x * button_b.y - prize.y * button_b.x;
                const b_numerator = button_a.x * prize.y - button_a.y * prize.x;
                if (denominator != 0 and @mod(a_numerator, denominator) == 0 and @mod(b_numerator, denominator) == 0) {
                    total += @intCast(@divTrunc((3 * a_numerator + b_numerator), denominator));
                }
            },
            State.blank => {},
        }
        state = @enumFromInt(@intFromEnum(state) +% 1);
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{total});
}
