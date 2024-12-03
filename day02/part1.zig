const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var buf: [64]u8 = undefined;
    var cnt: u32 = 0;
    loop: while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // split line on spaces
        var it = std.mem.splitScalar(u8, line, ' ');
        var last_num = try std.fmt.parseInt(i32, it.next().?, 10);
        var next_num = try std.fmt.parseInt(i32, it.next().?, 10);
        const inc = next_num > last_num;
        if (@abs(@as(i32, @intCast(@abs(next_num - last_num))) - 2) <= 1) {
            last_num = next_num;
            while (it.next()) |num| {
                next_num = try std.fmt.parseInt(i32, num, 10);
                if ((inc and next_num <= last_num) or (!inc and next_num >= last_num) or @abs(@as(i32, @intCast(@abs(next_num - last_num))) - 2) > 1) {
                    continue :loop;
                }
                last_num = next_num;
            }
            cnt += 1;
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{cnt});
}
