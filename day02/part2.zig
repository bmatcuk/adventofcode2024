const std = @import("std");

fn simple_evaluate(items: []i32) bool {
    if (items.len < 2) {
        return true;
    }

    var last = items[0];
    var diff = items[1] - last;
    const sign = diff > 0;
    if (@abs(@as(i32, @intCast(@abs(diff))) - 2) > 1) {
        return false;
    }

    last = items[1];
    for (items[2..]) |item| {
        diff = item - last;
        if (sign != (diff > 0) or @abs(@as(i32, @intCast(@abs(diff))) - 2) > 1) {
            return false;
        }
        last = item;
    }
    return true;
}

fn dampener_evaluate(items: []i32, allocator: std.mem.Allocator) anyerror!bool {
    var new_list = try std.ArrayList(i32).initCapacity(allocator, items.len - 1);
    new_list.expandToCapacity();
    defer new_list.deinit();

    // try every permutation of skipping a number
    for (items, 0..) |_, skip_idx| {
        var item_idx: usize = 0;
        var copy_idx: usize = 0;
        while (item_idx < items.len) : (item_idx += 1) {
            if (item_idx != skip_idx) {
                new_list.items[copy_idx] = items[item_idx];
                copy_idx += 1;
            }
        }
        if (simple_evaluate(new_list.items)) {
            return true;
        }
    }
    return false;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();

    const stdout = std.io.getStdOut().writer();
    var buf: [64]u8 = undefined;
    var cnt: u32 = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // avoid reallocating space
        list.clearRetainingCapacity();

        // convert line to array of ints
        var it = std.mem.splitScalar(u8, line, ' ');
        while (it.next()) |num| {
            try list.append(try std.fmt.parseInt(i32, num, 10));
        }

        if (try dampener_evaluate(list.items, allocator)) {
            // it's good!
            cnt += 1;
        }
    }

    try stdout.print("Result: {d}\n", .{cnt});
}
