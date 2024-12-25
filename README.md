# Advent of Code, 2024 :christmas_tree:
My solutions to the [Advent of Code 2024] in [zig].

I like to use the Advent of Code as a learning opportunity. This year, I
decided on learning [zig]. I have zero experience with the language.

## Retrospective :santa:
I was a bit worried about trying AoC with another low-level language - the year
I used rust was _rough_. Low-level languages inherently don't have much
built-in and require more hand-rolled algos and data structures. But I really
enjoyed writing zig!

I'd put zig somewhere between C and rust. It has the power and flexibility of
C, with some niceties and less foot-guns. The language was a pleasure to write
with a familiar syntax and a compiler that didn't have many (negative)
surprises. Compared to rust, where I spent hours fighting with the
borrow-checker, I only found myself stumped by the compiler once or twice. Of
course, zig doesn't have the guarantees that rust has, and I definitely
segfaulted a few times :laughing:

I also like that zig can run code at compile-time. I saw that other AoCers used
this to great effect by using `@embedFile` to do all of the input-massaging at
compile-time. I opted not to do that, as I feel like the input isn't part of
the program (ie, I wanted my program to read input at runtime). But, I made
really good use of it on [day 21] to build lookup tables at compile-time,
reducing runtime to just a few lookups and some math.

I have two complaints and a minor nit:
* Performing any math on an unsigned operand with a signed operand is verbose
  (one of the operands needs to be cast with `@as(whatever,
  @intCast(variable))` which seems unnecessarily long);
* The compiler seems to die after finding just one error so it often took
  several cycles of compile, fix error, compile, etc;
* And, my nit, the language server seems slow.

## Notable Algorithms and Data Structures :snowflake:
* State Machine - [day 3] made good use of a state machine while reading the
  input. I rather liked this pattern, and made use of it on several other days,
  too.
* Cramer's Rule - for [day 13], we had to solve a 2x2 simultaneous equation.
* Modular Arithmetic and the Chinese Remainder Theorem - in [day 14], we found
  an iteration of the puzzle that minimized variance in the x direction, and
  another iteration that minimized variance in the y direction. Then, using the
  Chinese Remainder Theorem and some modular arithmetic, found the iteration
  that minimized both.
* Dijkstra's - a mainstay of AoC, [day 16] saw my first use of it.
* Binary Search - [day 18] combined a binary search with Dijkstra's.
* Trie - [day 19] made good use of a trie.
* Cliques and Bron-Kerbosch - on [day 23], we needed to find all "cliques" of
  size three in part 1 (ie, all complete sub-graphs of size three). For part 2,
  we needed to find the maximum clique. For that, I used the Bron-Kerbosch
  algorithm.

:snowman_with_snow:

[Advent of Code 2024]: https://adventofcode.com/2024
[zig]: https://ziglang.org/
[day 3]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day03/part2.zig
[day 13]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day13/part2.zig
[day 14]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day14/part2.zig
[day 16]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day16/part2.zig
[day 18]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day18/part2.zig
[day 19]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day19/part2.zig
[day 21]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day21/part2.zig
[day 23]: https://github.com/bmatcuk/adventofcode2024/blob/26d39e2d6f02bbc9bc3cd7081fda253eb43fde57/day23/part2.zig
