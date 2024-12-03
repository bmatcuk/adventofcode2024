const std = @import("std");

const State = enum {
    start,
    M,
    U,
    L,
    num1,
    num2,
};

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    const stdout = std.io.getStdOut().writer();
    var current_state = State.start;
    var total: i32 = 0;
    var num1: i32 = 0;
    var num2: i32 = 0;
    loop: while (true) {
        switch (current_state) {
            State.start => {
                try stream.skipUntilDelimiterOrEof('m');
                current_state = State.M;
            },
            State.M => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        'u' => State.U,
                        'm' => State.M,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.U => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        'l' => State.L,
                        'm' => State.M,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.L => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        '(' => blk: {
                            num1 = 0;
                            num2 = 0;
                            break :blk State.num1;
                        },
                        'm' => State.M,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.num1 => {
                if (stream.readByte()) |char| {
                    switch (char) {
                        '0'...'9' => num1 = num1 * 10 + char - '0',
                        ',' => current_state = State.num2,
                        'm' => current_state = State.M,
                        else => current_state = State.start,
                    }
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.num2 => {
                if (stream.readByte()) |char| {
                    switch (char) {
                        '0'...'9' => num2 = num2 * 10 + char - '0',
                        ')' => {
                            total += num1 * num2;
                            current_state = State.start;
                        },
                        'm' => current_state = State.M,
                        else => current_state = State.start,
                    }
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
        }
    }

    try stdout.print("Result: {d}\n", .{total});
}
