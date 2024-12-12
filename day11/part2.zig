const std = @import("std");

fn blink_stone(stone: u64, depth: u8, cache: *std.AutoHashMap(u72, u64)) !u64 {
    if (depth == 0) {
        return 1;
    }

    const key: u72 = (stone << 8) + depth;
    if (cache.get(key)) |result| {
        return result;
    }

    var result: u64 = 0;
    if (stone == 0) {
        result = try blink_stone(1, depth - 1, cache);
    } else {
        const digits = std.math.log10_int(stone) + 1;
        if (digits & 1 == 0) {
            const pow = try std.math.powi(u64, 10, digits / 2);
            result = try blink_stone(stone / pow, depth - 1, cache) + try blink_stone(stone % pow, depth - 1, cache);
        } else {
            result = try blink_stone(stone * 2024, depth - 1, cache);
        }
    }
    try cache.put(key, result);
    return result;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var cache = std.AutoHashMap(u72, u64).init(allocator);
    defer cache.deinit();

    var buf: [32]u8 = undefined;
    var total: u64 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, ' ')) |num| {
        const stone = try std.fmt.parseUnsigned(u64, std.mem.trimRight(u8, num, &[_]u8{'\n'}), 10);
        total += try blink_stone(stone, 75, &cache);
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{total});
}
