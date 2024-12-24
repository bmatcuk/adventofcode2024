const std = @import("std");

const State = enum { values, gates };

const Operator = enum {
    const Self = @This();

    AND,
    OR,
    XOR,

    pub fn do(self: Self, operand1: u1, operand2: u1) u1 {
        return switch (self) {
            .AND => operand1 & operand2,
            .OR => operand1 | operand2,
            .XOR => operand1 ^ operand2,
        };
    }
};

const Gate = struct {
    operand1: []u8,
    operand2: []u8,
    output: []u8,
    operator: Operator,
};

const Gates = std.DoublyLinkedList(Gate);

/// Attempts to run the gate. If successful (ie, both operands have values in
/// `wires`), true is returned and the gate's `output` is stolen to record the
/// result in `wires`. Caller should free the gate's operands and the node.
fn tryRunGate(wires: *std.StringHashMap(u1), gate: Gate) !bool {
    if (wires.get(gate.operand1)) |operand1| {
        if (wires.get(gate.operand2)) |operand2| {
            try wires.put(gate.output, gate.operator.do(operand1, operand2));
            return true;
        }
    }
    return false;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    // represents known wire values
    var wires = std.StringHashMap(u1).init(allocator);
    defer {
        var it = wires.keyIterator();
        while (it.next()) |key| {
            allocator.free(key.*);
        }
        wires.deinit();
    }

    // represents gate operations we still need to run
    var remaining_gates = Gates{};
    defer {
        while (remaining_gates.pop()) |node| {
            allocator.free(node.data.operand1);
            allocator.free(node.data.operand2);
            allocator.destroy(node);
        }
    }

    var buf: [32]u8 = undefined;
    var state = State.values;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (state) {
            .values => {
                if (line.len == 0) {
                    state = .gates;
                    continue;
                }

                const wire = try allocator.dupe(u8, line[0..3]);
                try wires.put(wire, @intCast(line[5] - '0'));
            },
            .gates => {
                var node = try allocator.create(Gates.Node);
                node.data.operand1 = try allocator.dupe(u8, line[0..3]);
                switch (line[4]) {
                    'A' => {
                        node.data.operator = .AND;
                        node.data.operand2 = try allocator.dupe(u8, line[8..11]);
                        node.data.output = try allocator.dupe(u8, line[15..]);
                    },
                    'O' => {
                        node.data.operator = .OR;
                        node.data.operand2 = try allocator.dupe(u8, line[7..10]);
                        node.data.output = try allocator.dupe(u8, line[14..]);
                    },
                    'X' => {
                        node.data.operator = .XOR;
                        node.data.operand2 = try allocator.dupe(u8, line[8..11]);
                        node.data.output = try allocator.dupe(u8, line[15..]);
                    },
                    else => return error.UnknownOperator,
                }

                if (try tryRunGate(&wires, node.data)) {
                    allocator.free(node.data.operand1);
                    allocator.free(node.data.operand2);
                    allocator.destroy(node);
                } else {
                    remaining_gates.append(node);
                }
            },
        }
    }

    // some gate operations might depend on other gate operations running
    // first, so we'll iterate through the list multiple times until empty
    while (remaining_gates.first) |first_node| {
        var current_node: ?*Gates.Node = first_node;
        while (current_node) |node| {
            current_node = node.next;
            if (try tryRunGate(&wires, node.data)) {
                remaining_gates.remove(node);
                allocator.free(node.data.operand1);
                allocator.free(node.data.operand2);
                allocator.destroy(node);
            }
        }
    }

    var result: u64 = 0;
    var idx: u6 = 0;
    var z = [3]u8{'z', '0', '0'};
    while (wires.get(&z)) |bit| : (idx += 1) {
        result |= @as(u64, @intCast(bit)) << idx;
        if (z[2] == '9') {
            z[1] += 1;
            z[2] = '0';
        } else {
            z[2] += 1;
        }
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{result});
}
