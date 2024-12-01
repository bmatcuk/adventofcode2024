const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var list1 = std.ArrayList(i32).init(allocator);
    var list2 = std.ArrayList(i32).init(allocator);
    defer list1.deinit();
    defer list2.deinit();

    // read input
    var buf: [64]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // split line on three spaces
        var iterator = std.mem.splitSequence(u8, line, "   ");
        const val1 = iterator.next().?;
        const val2 = iterator.next().?;
        try list1.append(try std.fmt.parseInt(i32, val1, 10));
        try list2.append(try std.fmt.parseInt(i32, val2, 10));
    }

    // sort lists
    std.mem.sort(i32, list1.items, {}, std.sort.asc(i32));
    std.mem.sort(i32, list2.items, {}, std.sort.asc(i32));

    // sum the abs of the difference for each item
    var result: u32 = 0;
    for (list1.items, list2.items) |val1, val2| {
        result += @abs(val1 - val2);
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{result});
}
