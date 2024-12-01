const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var list = std.ArrayList(i32).init(allocator);
    var items = std.AutoHashMap(i32, i32).init(allocator);
    defer list.deinit();
    defer items.deinit();

    // read input
    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // split line on three spaces
        var iterator = std.mem.splitSequence(u8, line, "   ");
        const val = try std.fmt.parseInt(i32, iterator.next().?, 10);
        const item = try std.fmt.parseInt(i32, iterator.next().?, 10);
        try list.append(val);

        const entry = try items.getOrPutValue(item, 0);
        entry.value_ptr.* += 1;
    }

    // sum the abs of the difference for each item
    var result: i32 = 0;
    for (list.items) |val| {
        const cnt = items.get(val) orelse 0;
        result += val * cnt;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{result});
}
