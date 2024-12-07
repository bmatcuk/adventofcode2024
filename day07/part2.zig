const std = @import("std");

fn check(result: u128, running_total: u128, tail: []u128) !bool {
    if (tail.len == 0) {
        return result == running_total;
    }

    const digits = std.math.log10_int(tail[0]) + 1;
    const pow = try std.math.powi(u128, 10, digits);
    return try check(result, running_total + tail[0], tail[1..]) or try check(result, running_total * tail[0], tail[1..]) or try check(result, running_total * pow + tail[0], tail[1..]);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var operands = std.ArrayList(u128).init(allocator);
    defer operands.deinit();

    const stdout = std.io.getStdOut().writer();
    var buf: [64]u8 = undefined;
    var total: u128 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        operands.clearRetainingCapacity();

        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.NoColon;
        const result = try std.fmt.parseUnsigned(u128, line[0..colon], 10);

        var it = std.mem.splitScalar(u8, line[(colon + 2)..], ' ');
        while (it.next()) |num| {
            try operands.append(try std.fmt.parseUnsigned(u128, num, 10));
        }

        if (try check(result, operands.items[0], operands.items[1..])) {
            total += result;
        }
    }

    try stdout.print("Result: {d}\n", .{total});
}
