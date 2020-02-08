const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const net = std.net;
const os = std.os;
const io = std.io;
const Address = std.net.Address;
const Ring = @import("ring.zig").Ring;
const sys = @import("sys.zig");
const RingParams = @import("sys.zig").RingParams;

pub fn main() anyerror!void {
    // std.debug.warn("All your base are belong to us.\n", .{});
    var stdout = &io.getStdOut().outStream().stream;
    var addr: Address = try Address.parseIp4("127.0.0.1", @as(u16, 8000));

    var params = RingParams{};
    var ring = try Ring.init(8, &params);
    _ = try stdout.print("params: {}\n", .{params});
    _ = try stdout.print("ring: {}\n", .{ring});

    var socket = try os.socket(os.AF_INET, os.SOCK_STREAM | os.SOCK_NONBLOCK, os.IPPROTO_TCP);

    while (true) {
        var res = os.connect(socket, @ptrCast(*os.sockaddr, &addr.in), @sizeOf(os.sockaddr_in)) catch |err| {
            switch (err) {
                os.ConnectError.WouldBlock => continue, // not ready, retry
                else => return err,
            }
        };

        _ = try stdout.print("Connected!\n", .{});
        break;
    }

    var buf: [16]u8 = undefined;
    var iov = [1]os.iovec{os.iovec{
        .iov_base = &buf,
        .iov_len = buf.len,
    }};

    //var priority = ioprio_get(1, 0);

    var sqe = ring.subs.next();

    sqe.op = sys.Operation.Readv;
    sqe.fd = socket;
    sqe.data = sys.ExtraData{ .offset = 0 };
    sqe.ptr = @ptrToInt(&iov);
    sqe.len = 1;
    sqe.user_data = 79;

    ring.subs.signal(1);

    var consumed = os.system.io_uring_enter(ring.fd, 1, 1, os.IORING_ENTER_GETEVENTS, null); // do the procsigmask stuff later
    _ = try stdout.print("sqes consumed: {}\n", .{consumed});

    //_ = std.time.sleep(5 * std.time.second);

    var cqe = ring.comps.get();

    _ = try stdout.print("cqe: {}\n", .{cqe});

    if (cqe.result < 0) {
        try stdout.print("Error: {}\n", .{cqe.result});
    }

    _ = try stdout.print("Received: {}\n", .{buf[0..@intCast(usize, cqe.result)]});
}

//extern "c" fn ioprio_get(which: u32, who: u32) u16;
