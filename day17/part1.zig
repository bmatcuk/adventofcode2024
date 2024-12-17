const std = @import("std");

const State = enum(u3) {
    register_a = 0,
    register_b,
    register_c,
    blank,
    program,
    done,
};

const Registers = struct {
    a: u64,
    b: u64,
    c: u64,
};

fn combo_operand(operand: u3, registers: *Registers) !u64 {
    return switch (operand) {
        0, 1, 2, 3 => operand,
        4 => registers.a,
        5 => registers.b,
        6 => registers.c,
        7 => error.InvalidOperand,
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var program = std.ArrayList(u3).init(allocator);
    defer program.deinit();

    var buf: [64]u8 = undefined;
    var state = State.register_a;
    var registers = Registers{.a = 0, .b = 0, .c = 0};
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            State.register_a => registers.a = try std.fmt.parseUnsigned(u64, line[12..], 10),
            State.register_b => registers.b = try std.fmt.parseUnsigned(u64, line[12..], 10),
            State.register_c => registers.c = try std.fmt.parseUnsigned(u64, line[12..], 10),
            State.blank => {},
            State.program => {
                var it = std.mem.splitScalar(u8, line[9..], ',');
                while (it.next()) |num| {
                    try program.append(try std.fmt.parseUnsigned(u3, num, 10));
                }
            },
            State.done => break,
        }
        state = @enumFromInt(@intFromEnum(state) + 1);
    }

    const stdout = std.io.getStdOut().writer();
    var ip: usize = 0;
    while (ip < program.items.len) {
        switch (program.items[ip]) {
            0 => {
                const operand = try combo_operand(program.items[ip + 1], &registers);
                registers.a /= try std.math.powi(u64, 2, operand);
            },
            1 => registers.b ^= program.items[ip + 1],
            2 => registers.b = try combo_operand(program.items[ip + 1], &registers) & 7,
            3 => if (registers.a != 0) {
                ip = program.items[ip + 1];
                continue;
            },
            4 => registers.b ^= registers.c,
            5 => try stdout.print("{d},", .{try combo_operand(program.items[ip + 1], &registers) & 7}),
            6 => {
                const operand = try combo_operand(program.items[ip + 1], &registers);
                registers.b = registers.a / try std.math.powi(u64, 2, operand);
            },
            7 => {
                const operand = try combo_operand(program.items[ip + 1], &registers);
                registers.c = registers.a / try std.math.powi(u64, 2, operand);
            },
        }
        ip += 2;
    }
    try stdout.print("\n", .{});
}
