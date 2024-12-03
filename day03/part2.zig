const std = @import("std");

const State = enum {
    start,
    M,
    U,
    L,
    num1,
    num2,
    D,
    O,
    N,
    apostrophe,
    T,
    open_paren,
};

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    const stdout = std.io.getStdOut().writer();
    var current_state = State.start;
    var has_do = false;
    var enabled = true;
    var total: i32 = 0;
    var num1: i32 = 0;
    var num2: i32 = 0;
    loop: while (true) {
        switch (current_state) {
            State.start => {
                current_state = skip: while (stream.readByte()) |char| {
                    switch (char) {
                        'm' => break :skip State.M,
                        'd' => break :skip State.D,
                        else => {},
                    }
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                };
            },
            State.M => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        'u' => State.U,
                        'm' => State.M,
                        'd' => State.D,
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
                        'd' => State.D,
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
                        'd' => State.D,
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
                        'd' => current_state = State.D,
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
                            if (enabled) {
                                total += num1 * num2;
                            }
                            current_state = State.start;
                        },
                        'm' => current_state = State.M,
                        'd' => current_state = State.D,
                        else => current_state = State.start,
                    }
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.D => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        'o' => State.O,
                        'm' => State.M,
                        'd' => State.D,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.O => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        '(' => blk: {
                            has_do = true;
                            break :blk State.open_paren;
                        },
                        'n' => State.N,
                        'm' => State.M,
                        'd' => State.D,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.N => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        '\'' => State.apostrophe,
                        'm' => State.M,
                        'd' => State.D,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.apostrophe => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        't' => State.T,
                        'm' => State.M,
                        'd' => State.D,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.T => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        '(' => blk: {
                            has_do = false;
                            break :blk State.open_paren;
                        },
                        'm' => State.M,
                        'd' => State.D,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
            State.open_paren => {
                if (stream.readByte()) |char| {
                    current_state = switch (char) {
                        ')' => blk: {
                            enabled = has_do;
                            break :blk State.start;
                        },
                        'm' => State.M,
                        'd' => State.D,
                        else => State.start,
                    };
                } else |err| switch (err) {
                    error.EndOfStream => break :loop,
                    else => return err,
                }
            },
        }
    }

    try stdout.print("Result: {d}\n", .{total});
}
