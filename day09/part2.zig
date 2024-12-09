const std = @import("std");

/// Range is inclusive of start and end
const Range = struct {
    const Self = @This();

    start: u32,
    end: u32,

    pub fn length(self: Self) u32 {
        return 1 + self.end - self.start;
    }
};

const Block = struct {
    id: u32,
    location: Range,
};

const FreeSpaceQueue = std.DoublyLinkedList(Range);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var files = std.ArrayList(Block).init(allocator);
    defer files.deinit();

    var free_space = [_]FreeSpaceQueue{.{}} ** 10;
    defer {
        for (&free_space) |*spaces| {
            while (spaces.pop()) |space| {
                allocator.destroy(space);
            }
        }
    }

    // read file
    var file_id: u32 = 0;
    var position: u32 = 0;
    var reading_file = true;
    while (stream.readByte()) |char| {
        if (char == '\n') {
            break;
        }
        const num = char - '0';
        if (num > 0) {
            const range = Range{
                .start = position,
                .end = position + num - 1,
            };
            if (reading_file) {
                try files.append(Block{
                    .id = file_id,
                    .location = range,
                });
                file_id += 1;
            } else {
                const node = try allocator.create(FreeSpaceQueue.Node);
                free_space[range.length()].append(node);
                node.data = range;
            }
            position += num;
        } else if (reading_file) {
            file_id += 1;
        }
        reading_file = !reading_file;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    // move data blocks
    var current_file = files.items.len - 1;
    while (current_file > 0) : (current_file -= 1) {
        // find the left-most free space that'll fit the file
        const location = &files.items[current_file].location;
        var target_queue: ?*FreeSpaceQueue = null;
        for (location.length()..free_space.len) |idx| {
            if (free_space[idx].len > 0 and free_space[idx].first.?.data.start < location.start and (target_queue == null or free_space[idx].first.?.data.start < target_queue.?.first.?.data.start)) {
                target_queue = &free_space[idx];
            }
        }

        if (target_queue) |queue| {
            var space = queue.popFirst().?;
            location.end = space.data.start + location.length() - 1;
            location.start = space.data.start;

            space.data.start = location.end + 1;
            if (space.data.length() > 0) {
                var update_spaces = &free_space[space.data.length()];
                var node = update_spaces.first;
                while (node != null and node.?.data.start < space.data.start) {
                    node = node.?.next;
                }
                if (node) |next_node| {
                    update_spaces.insertBefore(next_node, space);
                } else {
                    update_spaces.append(space);
                }
            } else {
                allocator.destroy(space);
            }
        }
    }

    // calculate result
    var checksum: u64 = 0;
    for (files.items) |block| {
        checksum += block.id * @as(u64, @intCast(block.location.length())) * (block.location.start + block.location.end) / 2;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{checksum});
}
