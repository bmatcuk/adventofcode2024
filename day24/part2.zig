const std = @import("std");

// Binary addition is made up of "half adders" and "full adders".
//
// A half adder produces a sum bit using an XOR gate, and a carry bit using an
// AND gate. The least significant bits of the addition only use a half adder.
//
// A full adder is used to produce all of the remaining bits. It is basically a
// half adder whose sum is passed into a second half adder, along with the
// carry bit from the previous bit, to produce the sum. The carry bits from
// both half adders are then OR'd together to produce the carry bit for the
// next stage.
//
// That means there are 5 gates per bit, except the least significant bit,
// which only needs 2. The input has two 45-bit numbers, so I'd expect to see
// 44 * 5 + 2 = 222 gates, which I also see. So, the input isn't doing anything
// funny.
//
// To solve this, we don't need to actually "run" the gates - we just need to
// check that every input bit goes through the right gates, and lead to the
// right outputs. We don't even need to figure out _how_ the gates are wrong,
// just which gates are wrong.
//
// This code is _ugly_, and I was sure it wouldn't work because of some edge
// case I was missing... but it works! First try!

const State = enum { values, gates };

const Operator = enum { AND, OR, XOR };

const Gate = struct {
    operand1: []const u8,
    operand2: []const u8,
    output: []const u8,
    operator: Operator,
};

const Gates = std.StringHashMap(std.ArrayListUnmanaged(*Gate));

fn compareStrings(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b).compare(std.math.CompareOperator.lt);
}

fn getOrPutEntry(allocator: std.mem.Allocator, gates: *Gates, key: []const u8) !Gates.GetOrPutResult {
    const entry = try gates.getOrPut(key);
    if (!entry.found_existing) {
        entry.key_ptr.* = try allocator.dupe(u8, key);
        entry.value_ptr.* = std.ArrayListUnmanaged(*Gate){};
    }
    return entry;
}

fn verifyHalfAdder(gates: []*Gate, sum_gate: **Gate, carry_gate: **Gate) bool {
    if (gates[0].operator == .XOR and gates[1].operator == .AND) {
        sum_gate.* = gates[0];
        carry_gate.* = gates[1];
    } else if (gates[0].operator == .AND and gates[1].operator == .XOR) {
        sum_gate.* = gates[1];
        carry_gate.* = gates[0];
    } else {
        return false;
    }
    return true;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    // Deallocating this mess is tricky... even though in previous days, I made
    // a strong attempt to deallocate everything "correctly", the truth is that
    // the arena allocator handles everything for us and all of that manual
    // deallocation was unnecessary. I had done it in the past as merely a
    // thought experiment - practice, if you will. But _this_ is going to be
    // difficult because I'm reusing allocated strings as keys to this hash
    // map, and as operands in the Gate objects. And, each Gate can appear in
    // multiple hash map values. So, it'll be hard to know when it's safe to
    // deallocate strings and Gates without additional bookkeeping.
    var gates = std.StringHashMap(std.ArrayListUnmanaged(*Gate)).init(allocator);

    var buf: [32]u8 = undefined;
    var state = State.values;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            .values => { if (line.len == 0) state = .gates; },
            .gates => {
                var gate = try allocator.create(Gate);
                const operand1_entry = try getOrPutEntry(allocator, &gates, line[0..3]);
                gate.operand1 = operand1_entry.key_ptr.*;
                try operand1_entry.value_ptr.append(allocator, gate);

                var operand2: []u8 = undefined;
                var output: []u8 = undefined;
                switch (line[4]) {
                    'A' => {
                        gate.operator = .AND;
                        operand2 = line[8..11];
                        output = line[15..];
                    },
                    'O' => {
                        gate.operator = .OR;
                        operand2 = line[7..10];
                        output = line[14..];
                    },
                    'X' => {
                        gate.operator = .XOR;
                        operand2 = line[8..11];
                        output = line[15..];
                    },
                    else => return error.UnknownOperator,
                }

                const operand2_entry = try getOrPutEntry(allocator, &gates, operand2);
                gate.operand2 = operand2_entry.key_ptr.*;
                try operand2_entry.value_ptr.append(allocator, gate);

                if (output[0] == 'z') {
                    gate.output = try allocator.dupe(u8, output);
                } else {
                    const output_entry = try getOrPutEntry(allocator, &gates, output);
                    gate.output = output_entry.key_ptr.*;
                }
            },
        }
    }

    var swapped_outputs = std.StringHashMap(void).init(allocator);
    defer swapped_outputs.deinit();

    var key = [_]u8{'x', '0', '0'};
    var carry_gate: ?*Gate = null;
    while (gates.get(&key)) |x_gates| {
        // Only outputs are wrong, so, there should be 2 gates here, and both
        // of them should have inputs x## and y##.
        std.debug.assert(x_gates.items.len == 2);
        std.debug.assert(std.mem.eql(u8, key[1..], x_gates.items[0].operand1[1..]));
        std.debug.assert(std.mem.eql(u8, key[1..], x_gates.items[0].operand2[1..]));
        std.debug.assert(std.mem.eql(u8, key[1..], x_gates.items[1].operand1[1..]));
        std.debug.assert(std.mem.eql(u8, key[1..], x_gates.items[1].operand2[1..]));
        if (key[2] != '0' or key[1] != '0') {
            // Expect a full adder. The first half adder shouldn't fail, since
            // inputs can't be wrong.
            var first_sum_gate: *Gate = undefined;
            var first_carry_gate: *Gate = undefined;
            std.debug.assert(verifyHalfAdder(x_gates.items, &first_sum_gate, &first_carry_gate));

            // the first_sum_gate should go to another half adder
            var second_carry_gate: ?*Gate = null;
            if (gates.get(first_sum_gate.output)) |sum_gates| {
                // we'd expect two gates
                if (sum_gates.items.len == 2) {
                    var sum_gate: *Gate = undefined;
                    var maybe_carry_gate: *Gate = undefined;
                    if (verifyHalfAdder(sum_gates.items, &sum_gate, &maybe_carry_gate)) {
                        // sum gate's inputs should be `first_sum_gate` and the
                        // `carry_gate`... we already know one is
                        // `first_sum_gate` because we fetched it from the
                        // hash. If we don't know the carry gate from the last
                        // step, just assume the inputs are correct? We also
                        // need to verify the output.
                        const correct_inputs = if (carry_gate) |carry| brk: {
                            break :brk std.mem.eql(u8, sum_gate.operand1, carry.output) or std.mem.eql(u8, sum_gate.operand2, carry.output);
                        } else true;
                        const correct_output = sum_gate.output[0] == 'z' and sum_gate.output[1] == key[1] and sum_gate.output[2] == key[2];
                        if (!correct_inputs) {
                            if (correct_output) {
                                // carry's output must be wrong
                                try swapped_outputs.put(carry_gate.?.output, {});
                            } else {
                                // both are wrong, so it's probably
                                // first_sum_gate's output that is wrong
                                try swapped_outputs.put(first_sum_gate.output, {});
                            }
                        } else if (!correct_output) {
                            // incorrect output
                            try swapped_outputs.put(sum_gate.output, {});
                        }
                        second_carry_gate = maybe_carry_gate;
                    } else {
                        // sum gate's output must be wrong
                        try swapped_outputs.put(first_sum_gate.output, {});
                    }
                } else {
                    // sum gate's output must be wrong
                    try swapped_outputs.put(first_sum_gate.output, {});
                }
            } else {
                // sum gate's output must be wrong
                try swapped_outputs.put(first_sum_gate.output, {});
            }

            // the first_carry_gate should go to an OR gate
            carry_gate = null;
            if (gates.get(first_carry_gate.output)) |carry_gates| {
                // should only be one gate
                if (carry_gates.items.len == 1) {
                    // I think this has to be true
                    std.debug.assert(carry_gates.items[0].operator == .OR);

                    // if we have a carry gate from the second half adder
                    // above, it should be an input to this or gate... if we
                    // don't have a carry from above, just assume it's right?
                    const correct_inputs = if (second_carry_gate) |input_carry| brk: {
                        break :brk std.mem.eql(u8, carry_gates.items[0].operand1, input_carry.output) or std.mem.eql(u8, carry_gates.items[0].operand2, input_carry.output);
                    } else true;
                    if (!correct_inputs) {
                        // that second_carry_gate must have the wrong output
                        try swapped_outputs.put(second_carry_gate.?.output, {});
                    }
                    carry_gate = carry_gates.items[0];
                } else {
                    // first_carry_gate's output must be wrong
                    try swapped_outputs.put(first_carry_gate.output, {});
                }
            } else {
                // first_carry_gate's output must be wrong
                try swapped_outputs.put(first_carry_gate.output, {});
            }
        } else {
            // Least significant bit only needs a half adder - since inputs
            // can't be wrong, this shouldn't fail.
            var sum_gate: *Gate = undefined;
            var new_carry_gate: *Gate = undefined;
            std.debug.assert(verifyHalfAdder(x_gates.items, &sum_gate, &new_carry_gate));
            carry_gate = new_carry_gate;
            if (sum_gate.output[0] != 'z' or sum_gate.output[1] != key[1] or sum_gate.output[2] != key[2]) {
                try swapped_outputs.put(sum_gate.output, {});
            }
        }

        if (key[2] == '9') {
            key[1] += 1;
            key[2] = '0';
        } else {
            key[2] += 1;
        }
    }

    var swapped_outputs_list = try allocator.alloc([]const u8, swapped_outputs.count());
    defer allocator.free(swapped_outputs_list);

    var it = swapped_outputs.keyIterator();
    var idx: usize = 0;
    while (it.next()) |output| : (idx += 1) {
        swapped_outputs_list[idx] = output.*;
    }
    std.mem.sort([]const u8, swapped_outputs_list, {}, compareStrings);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: ", .{});
    for (swapped_outputs_list) |output| {
        try stdout.print("{s},", .{output});
    }
    try stdout.print("{c} \n", .{std.ascii.control_code.bs});
}
