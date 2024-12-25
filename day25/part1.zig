const std = @import("std");

const Reading = enum { lock, key };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var locks = std.ArrayList([5]u4).init(allocator);
    defer locks.deinit();

    var keys = std.ArrayList([5]u4).init(allocator);
    defer keys.deinit();

    var buf: [8]u8 = undefined;
    var line_idx: u4 = 1;
    var reading: Reading = undefined;
    var storage: *[5]u4 = undefined;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_idx += 1) {
        if (line_idx == 1) {
            if (std.mem.eql(u8, line, "#####")) {
                reading = .lock;
                storage = try locks.addOne();
                @memset(storage, 0);
            } else {
                reading = .key;
                storage = try keys.addOne();
                @memset(storage, 5);
            }
        } else if (line_idx == 8) {
            line_idx = 0;
        } else if (reading == .lock) {
            for (line, 0..) |c, idx| {
                if (c == '#') storage[idx] += 1;
            }
        } else {
            for (line, 0..) |c, idx| {
                if (c == '.') storage[idx] -= 1;
            }
        }
    }

    var cnt: u32 = 0;
    for (locks.items) |lock| {
        loop: for (keys.items) |key| {
            for (0..5) |idx| {
                if (lock[idx] + key[idx] > 5) continue :loop;
            }
            cnt += 1;
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{cnt});
}
