const std = @import("std");

const NumericKey = enum(u8) {
    const Self = @This();

    one = '1',
    two = '2',
    three = '3',
    four = '4',
    five = '5',
    six = '6',
    seven = '7',
    eight = '8',
    nine = '9',
    zero = '0',
    a = 'A',

    fn is_above_and_left(self: Self, to: NumericKey) bool {
        return switch (self) {
            .a => to == .two or to == .five or to == .eight,
            .zero => false,
            else => self.is_above(to) and self.is_left(to),
        };
    }

    fn is_below_and_right(self: Self, to: NumericKey) bool {
        return if (self.is_below(to) and self.is_right(to)) switch (self) {
            .one, .four, .seven => to != .zero and to != .a,
            else => true,
        } else false;
    }

    fn is_above(self: Self, to: NumericKey) bool {
        return switch (self) {
            .zero, .a => to != .zero and to != .a,
            .one, .two, .three => to != .a and @intFromEnum(to) > '3',
            .four, .five, .six => to != .a and @intFromEnum(to) > '6',
            else => false,
        };
    }

    fn is_below(self: Self, to: NumericKey) bool {
        return switch (self) {
            .seven, .eight, .nine => to != .seven and to != .eight and to != .nine,
            .four, .five, .six => to == .a or @intFromEnum(to) < '4',
            .one, .two, .three => to == .zero or to == .a,
            else => false,
        };
    }

    fn is_left(self: Self, to: NumericKey) bool {
        return switch (self) {
            .a, .three, .six, .nine => to != .a and to != .three and to != .six and to != .nine,
            .two, .five, .eight => to == .one or to == .four or to == .seven,
            else => false,
        };
    }

    fn is_right(self: Self, to: NumericKey) bool {
        return switch (self) {
            .one, .four, .seven => to != .one and to != .four and to != .seven,
            .zero, .two, .five, .eight => to == .a or to == .three or to == .six or to == .nine,
            else => false,
        };
    }

    fn move_up(self: Self) !NumericKey {
        return switch (self) {
            .seven, .eight, .nine => error.InvalidNumericMove,
            .zero => .two,
            .a => .three,
            else => @enumFromInt(@intFromEnum(self) + 3),
        };
    }

    fn move_down(self: Self) !NumericKey {
        return switch (self) {
            .zero, .one, .a => error.InvalidNumericMove,
            .two => .zero,
            .three => .a,
            else => @enumFromInt(@intFromEnum(self) - 3),
        };
    }

    fn move_left(self: Self) !NumericKey {
        return switch (self) {
            .zero, .one, .four, .seven => error.InvalidNumericMove,
            .a => .zero,
            else => @enumFromInt(@intFromEnum(self) - 1),
        };
    }

    fn move_right(self: Self) !NumericKey {
        return switch (self) {
            .a, .three, .six, .nine => error.InvalidNumericMove,
            .zero => .a,
            else => @enumFromInt(@intFromEnum(self) + 1),
        };
    }

    pub fn move_to(self: Self, to: NumericKey, moves: *std.ArrayList(DirectionalKey)) !NumericKey {
        var key = self;
        if (key.is_above_and_left(to)) {
            // little bit of a special case
            // more efficient to move left first, then up
            while (key.is_left(to)) {
                key = try key.move_left();
                try moves.append(.left);
            }
        } else if (key.is_below_and_right(to)) {
            // another special case
            // more efficient to move down first, then right
            while (key.is_below(to)) {
                key = try key.move_down();
                try moves.append(.down);
            }
        }
        while (key.is_above(to)) {
            key = try key.move_up();
            try moves.append(.up);
        }
        while (key.is_right(to)) {
            key = try key.move_right();
            try moves.append(.right);
        }
        while (key.is_below(to)) {
            key = try key.move_down();
            try moves.append(.down);
        }
        while (key.is_left(to)) {
            key = try key.move_left();
            try moves.append(.left);
        }
        try moves.append(.a);
        return to;
    }
};

const DirectionalKey = enum {
    const Self = @This();

    up,
    down,
    left,
    right,
    a,

    pub fn move_to(self: Self, to: DirectionalKey, moves: *std.ArrayList(DirectionalKey)) !DirectionalKey {
        if (self != to) {
            switch (self) {
                .up => if (to == .a) {
                    try moves.append(.right);
                } else {
                    try moves.append(.down);
                    if (to == .left or to == .right) {
                        try moves.append(to);
                    }
                },
                .down => if (to == .left or to == .right) {
                    try moves.append(to);
                } else {
                    try moves.append(.up);
                    if (to == .a) {
                        try moves.append(.right);
                    }
                },
                .left => {
                    try moves.append(.right);
                    if (to == .up) {
                        try moves.append(.up);
                    } else if (to != .down) {
                        try moves.append(.right);
                        if (to == .a) {
                            try moves.append(.up);
                        }
                    }
                },
                .right => if (to == .a) {
                    try moves.append(.up);
                } else {
                    try moves.append(.left);
                    if (to != .down) {
                        try moves.append(to);
                    }
                },
                .a => if (to == .up) {
                    try moves.append(.left);
                } else {
                    try moves.append(.down);
                    if (to != .right) {
                        try moves.append(.left);
                        if (to == .left) {
                            try moves.append(.left);
                        }
                    }
                },
            }
        }
        try moves.append(.a);
        return to;
    }
};

fn calculate_numeric_pad_moves(code: []u8, moves: *std.ArrayList(DirectionalKey)) !void {
    var key = NumericKey.a;
    for (code) |c| {
        key = try key.move_to(@enumFromInt(c), moves);
    }
}

fn calculate_directional_keypad_moves(code: []DirectionalKey, moves: *std.ArrayList(DirectionalKey)) !void {
    var key = DirectionalKey.a;
    for (code) |c| {
        key = try key.move_to(c, moves);
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var moves1 = std.ArrayList(DirectionalKey).init(allocator);
    var moves2 = std.ArrayList(DirectionalKey).init(allocator);
    defer moves1.deinit();
    defer moves2.deinit();

    var buf: [8]u8 = undefined;
    var complexity: usize = 0;
    while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        moves1.clearRetainingCapacity();
        moves2.clearRetainingCapacity();
        try calculate_numeric_pad_moves(line, &moves1);
        try calculate_directional_keypad_moves(moves1.items, &moves2);
        moves1.clearRetainingCapacity();
        try calculate_directional_keypad_moves(moves2.items, &moves1);

        var code: usize = 0;
        for (line) |c| {
            if (c >= '0' and c <= '9') {
                code = code * 10 + c - '0';
            }
        }
        complexity += code * moves1.items.len;
    }

    // too high: 158428
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Result: {d}\n", .{complexity});
}
