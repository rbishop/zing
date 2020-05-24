const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const net = std.net;
const os = std.os;
const io = std.io;
const errno = os.errno;
const Address = std.net.Address;

const Ring = @import("ring.zig").Ring;
const sys = @import("sys.zig");
const RingParams = @import("sys.zig").RingParams;

pub fn main() anyerror!void {
    var stdout = &io.getStdOut().outStream();
    var addr: Address = try Address.parseIp4("127.0.0.1", @as(u16, 8000));

    var params = RingParams{};
    var ring = try Ring.init(8, &params);

    // TODO: Make connect work with os.SOCK_NONBLOCK
    var socket = try os.socket(os.AF_INET, os.SOCK_STREAM, os.IPPROTO_TCP);

    var connect_sqe = ring.subs.next();
    connect_sqe.op = sys.Operation.Connect;
    connect_sqe.fd = socket;
    connect_sqe.ptr = @ptrToInt(&addr.in);
    connect_sqe.len = 0;
    connect_sqe.data = sys.ExtraData{ .offset = addr.getOsSockLen() };
    connect_sqe.user_data = 14;

    ring.subs.signal(1);

    //    while (true) {
    //        var res = os.connect(socket, @ptrCast(*os.sockaddr, &addr.in), addr.getOsSockLen()) catch |err| {
    //            switch (err) {
    //                os.ConnectError.WouldBlock => continue, // not ready, retry
    //                else => return err,
    //            }
    //        };
    //        _ = try stdout.print("Connected!\n", .{});
    //        break;
    //    }

    var consumed = ring.enter(1, 1);
    var connect_cqe = ring.comps.get();

    // TODO: Wrap uring results in errno and turn into Zig ErrorSets
    var rc = errno(@bitCast(usize, @as(isize, connect_cqe.result)));
    switch (rc) {
        0 => try stdout.print("connected, no need to poll add\n", .{}),
        os.EAGAIN, os.EINPROGRESS => {
            _ = try stdout.print("Need to Poll!\n", .{});
            // Add a Poll event for this socket
            var poll_sqe = ring.subs.next();
            poll_sqe.fd = socket;
            poll_sqe.op = sys.Operation.PollAdd;
            poll_sqe.op_flags = sys.OpFlag{ .poll_events = os.POLLIN | os.POLLOUT | os.POLLERR };
            ring.subs.signal(1);
            _ = ring.enter(1, 1);
            var poll_cqe = ring.comps.get();

            switch (poll_cqe.result) {
                0 => try stdout.print("connected! we can read/write\n", .{}),
                os.EFAULT => try stdout.print("pollfds not in process memory bounds\n", .{}),
                os.EINTR => try stdout.print("signal received\n", .{}),
                os.EINVAL => try stdout.print("invalid fd\n", .{}),
                os.ENOMEM => try stdout.print("not enough memory\n", .{}),
                else => {
                    try stdout.print("unknown error {}\n", .{poll_cqe.result});
                    return;
                },
            }
        },
        else => {
            try stdout.print("unrecoverable error: {} cqe={} einval={}\n", .{ rc, connect_cqe, os.EINVAL });
            return;
        },
    }

    ring.comps.signal();

    var buf: [16]u8 = undefined;
    var iov = [1]os.iovec{os.iovec{
        .iov_base = &buf,
        .iov_len = buf.len,
    }};

    var read_sqe = ring.subs.next();

    // create the Read operation
    read_sqe.op = sys.Operation.Readv;
    read_sqe.fd = socket;
    read_sqe.data = sys.ExtraData{ .offset = 0 };
    read_sqe.ptr = @ptrToInt(&iov);
    read_sqe.len = 1;
    read_sqe.user_data = 79;

    // create the PollAdd operation
    //var sqe = ring.subs.next();
    //sqe.op = sys.Operation.PollAdd;
    //sqe.fd = socket;
    //sqe.op_flags = sys.OpFlag { .poll_events = };

    ring.subs.signal(1);

    //consumed = os.system.io_uring_enter(ring.fd, 1, 1, os.IORING_ENTER_GETEVENTS, null); // do the procsigmask stuff later
    consumed = ring.enter(1, 1);

    //_ = std.time.sleep(5 * std.time.second);

    var cqe = ring.comps.get();
    ring.comps.signal();

    _ = try stdout.print("cqe: {}\n", .{cqe});

    if (cqe.result < 0) {
        try stdout.print("Error: {}\n", .{cqe.result});
        return;
    }

    _ = try stdout.print("Received: {}\n", .{buf[0..@intCast(usize, cqe.result)]});
}

//extern "c" fn ioprio_get(which: u32, who: u32) u16;
