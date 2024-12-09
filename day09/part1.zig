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
    locations: std.ArrayList(Range),
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var files = std.ArrayList(Block).init(allocator);
    defer {
        for (files.items) |block| {
            block.locations.deinit();
        }
        files.deinit();
    }

    var free_space = std.ArrayList(Range).init(allocator);
    defer free_space.deinit();

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
                var locations = std.ArrayList(Range).init(allocator);
                try locations.append(range);
                try files.append(Block{
                    .id = file_id,
                    .locations = locations,
                });
                file_id += 1;
            } else {
                try free_space.append(range);
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
    var current_free_space: usize = 0;
    var current_file = files.items.len - 1;
    while (free_space.items[current_free_space].start < files.items[current_file].locations.items[0].end) {
        const free_block = &free_space.items[current_free_space];
        const location = &files.items[current_file].locations.items[0];
        if (free_block.length() >= location.length()) {
            // enough free space to move the entire location
            location.end = free_block.start + location.length() - 1;
            location.start = free_block.start;
            free_block.start = location.end + 1;
            current_file -= 1;
        } else {
            // not enough space for the whole location - take from end
            try files.items[current_file].locations.append(Range{
                .start = free_block.start,
                .end = free_block.end,
            });
            location.end -= free_block.length();
            free_block.start = free_block.end + 1;
        }

        if (free_block.length() == 0) {
            current_free_space += 1;
            if (current_free_space >= free_space.items.len) {
                break;
            }
        }
    }

    // calculate result
    var checksum: u64 = 0;
    for (files.items) |block| {
        for (block.locations.items) |location| {
            checksum += block.id * @as(u64, @intCast(location.length())) * (location.start + location.end) / 2;
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{checksum});
}
