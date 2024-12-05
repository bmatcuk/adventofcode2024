const std = @import("std");

const State = enum {
    page_orders,
    updates,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var page_orders = std.AutoHashMap(u8, std.ArrayList(u8)).init(allocator);
    defer page_orders.deinit();

    var pages = std.ArrayList(u8).init(allocator);
    defer pages.deinit();

    var seen_pages = std.AutoHashMap(u8, void).init(allocator);

    const stdout = std.io.getStdOut().writer();
    var buf: [128]u8 = undefined;
    var total: u32 = 0;
    var state = State.page_orders;
    loop: while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            State.page_orders => {
                if (line.len == 0) {
                    state = State.updates;
                    continue :loop;
                }

                // each line is xx|yy
                const page1 = try std.fmt.parseInt(u8, line[0..2], 10);
                const page2 = try std.fmt.parseInt(u8, line[3..5], 10);

                const entry = try page_orders.getOrPut(page1);
                if (!entry.found_existing) {
                    // technically speaking, this will "leak", but the arena
                    // will clean it up
                    entry.value_ptr.* = std.ArrayList(u8).init(allocator);
                }
                try entry.value_ptr.*.append(page2);
            },
            State.updates => {
                pages.clearRetainingCapacity();
                seen_pages.clearRetainingCapacity();

                var it = std.mem.splitScalar(u8, line, ',');
                while (it.next()) |page_str| {
                    const page = try std.fmt.parseInt(u8, page_str, 10);
                    if (page_orders.getEntry(page)) |order_entry| {
                        for (order_entry.value_ptr.*.items) |item| {
                            if (seen_pages.contains(item)) {
                                continue :loop;
                            }
                        }
                    }
                    try pages.append(page);
                    try seen_pages.put(page, {});
                }

                total += pages.items[pages.items.len / 2];
            },
        }
    }

    try stdout.print("Result: {d}\n", .{total});
}
