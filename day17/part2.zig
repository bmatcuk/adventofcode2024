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

fn solve(program: []u3, solve_idx: usize, a_start: u64) !?u64 {
    // The "program" mostly operates on the least significant 3 bits of the A
    // register. However, higher bits can influence the computations. So, we
    // recursively solve the puzzle in reverse:
    // 1. Find a value of A that satisfies the last program value. There are
    //    only 8 possibilities (0-7).
    // 2. Bit-shift to the left 3 bits, then recursively run step 1 to find a
    //    value that satisfies the last two program values.
    // 3. etc
    var a = a_start << 3;
    loop: while (a & 4 < 8) : (a += 1) {
        var registers = Registers{.a = a, .b = 0, .c = 0};
        var test_idx = solve_idx;
        var ip: usize = 0;
        while (ip < program.len) {
            switch (program[ip]) {
                0 => {
                    const operand = try combo_operand(program[ip + 1], &registers);
                    registers.a /= try std.math.powi(u64, 2, operand);
                },
                1 => registers.b ^= program[ip + 1],
                2 => registers.b = try combo_operand(program[ip + 1], &registers) & 7,
                3 => if (registers.a != 0) {
                    ip = program[ip + 1];
                    continue;
                },
                4 => registers.b ^= registers.c,
                5 => {
                    const num = try combo_operand(program[ip + 1], &registers) & 7;
                    if (num == program[@intCast(test_idx)]) {
                        test_idx += 1;
                    } else {
                        continue :loop;
                    }
                },
                6 => {
                    const operand = try combo_operand(program[ip + 1], &registers);
                    registers.b = registers.a / try std.math.powi(u64, 2, operand);
                },
                7 => {
                    const operand = try combo_operand(program[ip + 1], &registers);
                    registers.c = registers.a / try std.math.powi(u64, 2, operand);
                },
            }
            ip += 2;
        }

        if (solve_idx == 0) {
            // done
            return a;
        }

        // Try to recursively solve using this value of A. If this returns
        // null, that value didn't work. So, try again.
        if (try solve(program, solve_idx - 1, a)) |num| {
            return num;
        }
    }
    return null;
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
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            State.register_a, State.register_b, State.register_c, State.blank => {},
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
    const a = try solve(program.items, program.items.len - 1, 0);
    try stdout.print("Result: {?d}\n", .{a});
}
