const std = @import("std");

fn calculate_secret_number(secret: u64) u64 {
    const one = ((secret * 64) ^ secret) % 16777216;
    const two = ((one / 32) ^ one) % 16777216;
    return ((two * 2048) ^ two) % 16777216;
}

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var buf: [16]u8 = undefined;
    var sum: u64 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var secret = try std.fmt.parseUnsigned(u64, line, 10);
        for (0..2000) |_| {
            secret = calculate_secret_number(secret);
        }
        sum += secret;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{sum});
}
