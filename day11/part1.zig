const std = @import("std");

const Stones = std.DoublyLinkedList(u64);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var stones = Stones{};
    defer {
        while (stones.pop()) |node| {
            allocator.destroy(node);
        }
    }

    // read file
    var buf: [32]u8 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, ' ')) |num| {
        const node = try allocator.create(Stones.Node);
        node.data = try std.fmt.parseUnsigned(u64, std.mem.trimRight(u8, num, &[_]u8{'\n'}), 10);
        stones.append(node);
    }

    // run steps
    for (0..25) |_| {
        var maybe_node = stones.first;
        while (maybe_node) |node| {
            if (node.data == 0) {
                node.data = 1;
            } else {
                const digits = std.math.log10_int(node.data) + 1;
                if (digits & 1 == 0) {
                    const pow = try std.math.powi(u64, 10, digits / 2);
                    const new_node = try allocator.create(Stones.Node);
                    new_node.data = node.data / pow;
                    node.data %= pow;
                    stones.insertBefore(node, new_node);
                } else {
                    node.data *= 2024;
                }
            }
            maybe_node = node.next;
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{stones.len});
}
