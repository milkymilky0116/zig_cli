const std = @import("std");
const build_options = @import("build_options");
const Io = std.Io;
const Writer = Io.File.Writer;
const Test = std.testing;

const help_text =
    \\Usage: echo [OPTION]... [STRING]...
    \\Print STRING(s) to standard output.
    \\
    \\Options:
    \\  -n         do not output the trailing newline
    \\  --help     display this help and exit
    \\  --version  output version information and exit
    \\
;

const Cli = struct {
    stdout: *Io.Writer,
    has_trailing_line: bool,
    is_help: bool,
    is_version: bool,
    input: []const []const u8,

    pub fn init(stdout: *std.Io.Writer, args: []const []const u8) !Cli {
        var cli = Cli{
            .stdout = stdout,
            .has_trailing_line = true,
            .is_help = false,
            .is_version = false,
            .input = &.{},
        };
        if (args.len == 1) {
            return cli;
        }
        if (std.mem.startsWith(u8, args[1], "-")) {
            if (std.mem.eql(u8, args[1], "--help")) {
                cli.is_help = true;
                return cli;
            }

            if (std.mem.eql(u8, args[1], "--version")) {
                cli.is_version = true;
                return cli;
            }

            if (std.mem.eql(u8, args[1], "-n")) {
                cli.has_trailing_line = false;
            }
        }

        var start_point: usize = 1;
        if (cli.is_help or cli.is_version or !cli.has_trailing_line) {
            start_point = 2;
        }
        cli.input = args[start_point..];
        return cli;
    }
    pub fn run(self: *Cli) !void {
        if (self.is_help) {
            try self.stdout.writeAll(help_text);
            return;
        }

        if (self.is_version) {
            try self.stdout.print("echo {s}\n", .{build_options.version});
            return;
        }

        if (self.input.len == 0) {
            if (self.has_trailing_line) {
                try self.stdout.writeAll("\n");
            }
            return;
        }

        var seperator: []const u8 = " ";
        for (self.input, 0..) |arg, index| {
            if (index == self.input.len - 1) {
                if (self.has_trailing_line) {
                    seperator = "\n";
                } else {
                    seperator = "";
                }
            }

            try self.stdout.print("{s}{s}", .{ arg, seperator });
        }
    }
};

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = Writer.init(Io.File.stdout(), init.io, &stdout_buffer);
    const arena = init.arena.allocator();
    const stdout = &stdout_writer.interface;
    const argSlice = try init.minimal.args.toSlice(arena);
    var cli = try Cli.init(stdout, argSlice);
    try cli.run();
    try stdout.flush();
}

test "help should parse correctly" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{
        "echo",
        "--help",
    };

    const cli = try Cli.init(&stdout_writer, args);
    try Test.expect(cli.is_help);

    const short_args = &[_][]const u8{
        "echo",
        "-h",
    };

    const short_cli = try Cli.init(&stdout_writer, short_args);
    try Test.expect(!short_cli.is_help);
}

test "version should parse correctly" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{
        "echo",
        "--version",
    };

    const cli = try Cli.init(&stdout_writer, args);
    try Test.expect(cli.is_version);

    const short_args = &[_][]const u8{
        "echo",
        "-v",
    };

    const short_cli = try Cli.init(&stdout_writer, short_args);
    try Test.expect(!short_cli.is_version);
}

test "trailing line should parse correctly" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{
        "echo",
        "-n",
    };

    const cli = try Cli.init(&stdout_writer, args);
    try Test.expect(!cli.has_trailing_line);
}

test "trailing line option should be first of arguments" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "test", "-n" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expect(cli.has_trailing_line);
    try Test.expectEqualStrings("test -n\n", stdout_buffer[0..stdout_writer.end]);
}

test "print args correctly" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "test", "1", "2", "3" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("test 1 2 3\n", stdout_buffer[0..stdout_writer.end]);
}

test "no trailing option print args correctly" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "-n", "test", "1", "2", "3" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("test 1 2 3", stdout_buffer[0..stdout_writer.end]);
}

test "no arguments should print only newline" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{"echo"};

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("\n", stdout_buffer[0..stdout_writer.end]);
}

test "empty string argument should be preserved" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("\n", stdout_buffer[0..stdout_writer.end]);
}

test "empty string argument between words should be preserved" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "hello", "", "world" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("hello  world\n", stdout_buffer[0..stdout_writer.end]);
}

test "double dash should be printed as string" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "--", "hello" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("-- hello\n", stdout_buffer[0..stdout_writer.end]);
}

test "unknown option-like argument should be printed as string" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "-x", "hello" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("-x hello\n", stdout_buffer[0..stdout_writer.end]);
}

test "help should print usage to stdout" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "--help", "ignored" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    const actual = stdout_buffer[0..stdout_writer.end];
    try Test.expect(std.mem.indexOf(u8, actual, "Usage: echo [OPTION]... [STRING]...") != null);
    try Test.expect(std.mem.indexOf(u8, actual, "-n") != null);
    try Test.expect(std.mem.indexOf(u8, actual, "--help") != null);
    try Test.expect(std.mem.indexOf(u8, actual, "--version") != null);
}

test "version should print project version to stdout" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "--version", "ignored" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("echo 0.0.1\n", stdout_buffer[0..stdout_writer.end]);
}

test "argument contents should not be changed" {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.Writer.fixed(&stdout_buffer);
    const args = &[_][]const u8{ "echo", "a b", "c\td", "한글" };

    var cli = try Cli.init(&stdout_writer, args);
    try cli.run();
    try Test.expectEqualStrings("a b c\td 한글\n", stdout_buffer[0..stdout_writer.end]);
}
