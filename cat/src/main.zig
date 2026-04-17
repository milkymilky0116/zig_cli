const std = @import("std");
const Io = std.Io;
const Writer = std.Io.File.Writer;

const Cli = struct {
    file_list: []const []const u8,
    is_version: bool,
    is_help: bool,
    is_non_blank_line: bool,
    is_line: bool,

    pub fn init(args_slice: []const []const u8) Cli {
        var cli = Cli{
            .file_list = .{},
            .is_version = false,
            .is_help = false,
            .is_non_blank_line = false,
            .is_line = false,
        };

        for (args_slice) |arg| {
            if (std.mem.eql([]const u8, arg, "-h") or std.mem.eql([]const u8, arg, "--help")) {
                cli.is_help = true;
            } else if (std.mem.eql([]const u8, arg, "-v") or std.mem.eql([]const u8, arg, "--version")) {
                cli.is_version = true;
            } else if (std.mem.eql([]const u8, arg, "-b") or std.mem.eql([]const u8, arg, "--number--nonblank")) {
                cli.is_non_blank_line = true;
            } else if (std.mem.eql([]const u8, arg, "-n") or std.mem.eql([]const u8, arg, "--number")) {
                cli.is_line = true;
            } else {}
        }

        return cli;
    }
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = Writer.init(std.Io.File.stdout(), init.io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    const cli = Cli.init(init.minimal.args.toSlice(arena));
    _ = cli;

    try stdout.flush();
}
