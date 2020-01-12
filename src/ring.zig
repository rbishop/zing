const std = @import("std");
const builtin = std.builtin;
const os = std.os;
const sys = os.system;
const io = std.io;

pub const Ring = struct {
    fd: i32,
    size: u32,
    subs: SubQueue,
    comps: CompQueue,

    pub fn init(size: u32, params: *os.io_uring_params) @This() {
        var ring: Ring = undefined;
        ring.fd = @intCast(i32, sys.io_uring_setup(size, params));
        ring.size = size;
        ring.subs = SubQueue.init(params.sq_entries, ring.fd, params.sq_off);
        ring.comps = CompQueue.init(params.cq_entries, ring.fd, params.cq_off);
        //var stdout = &io.getStdOut().outStream().stream;

        return ring;
    }
};

pub const SubQueue = struct {
    head: *u32,
    tail: *u32,
    mask: *u32,
    entries: *u32,
    flags: *u32,
    dropped: *u32,
    array: [*]u32,

    mmap_ptr: usize,
    size: u32,
    sqes: [*]os.io_uring_sqe,

    const Self = @This();

    pub fn init(entries: u32, ring_fd: i32, offsets: os.io_sqring_offsets) @This() {
        var subs: SubQueue = undefined;
        subs.size = offsets.array + (entries * @sizeOf(u32));
        subs.mmap_ptr = sys.mmap(null, subs.size, os.PROT_READ | os.PROT_WRITE, os.MAP_SHARED | os.MAP_POPULATE, @intCast(i32, ring_fd), os.IORING_OFF_SQ_RING);

        subs.head = @intToPtr(*u32, subs.mmap_ptr + offsets.head);
        subs.tail = @intToPtr(*u32, subs.mmap_ptr + offsets.tail);
        subs.mask = @intToPtr(*u32, subs.mmap_ptr + offsets.ring_mask);
        subs.entries = @intToPtr(*u32, subs.mmap_ptr + offsets.ring_entries);
        subs.flags = @intToPtr(*u32, subs.mmap_ptr + offsets.flags);
        subs.dropped = @intToPtr(*u32, subs.mmap_ptr + offsets.dropped);
        subs.array = @intToPtr([*]u32, subs.mmap_ptr + offsets.array);

        var sqe_size = entries + @sizeOf(os.io_uring_sqe);
        var sqe_ptr = sys.mmap(null, sqe_size, os.PROT_READ | os.PROT_WRITE, os.MAP_SHARED | os.MAP_POPULATE, ring_fd, os.IORING_OFF_SQES);
        subs.sqes = @intToPtr([*]os.io_uring_sqe, sqe_ptr);

        return subs;
    }

    // This can error, add error type later
    // I should also think of an API that makes this re-entrant
    // consider supporting multi threading, though maybe rings should be owned by threads
    pub fn next(self: *Self) *os.io_uring_sqe {
        var index = self.tail.* & self.mask.*;
        return &self.sqes[index];
    }

    // Let's the kernel know we've added submission entries
    // TODO: Make sure num is within the size of the ring
    pub fn signal(self: *Self, num: u16) void {
        @fence(builtin.AtomicOrder.SeqCst);
        self.tail.* += num;
        @fence(builtin.AtomicOrder.SeqCst);
    }

    pub fn print(self: *Self) void {
        var stdout = &io.getStdOut().outStream().stream;
        var idx: u16 = 0;

        while (idx < self.entries.*) {
            _ = stdout.print("sqe #{}: {}\n", .{ idx, &self.sqes[idx] }) catch |err| null;
            idx += 1;
        }
    }
};

pub const CompQueue = struct {
    head: *u32,
    tail: *u32,
    mask: *u32,
    entries: *u32,
    overflow: *u32,

    mmap_ptr: usize,
    size: u32,
    cqes: [*]os.io_uring_cqe,

    const Self = @This();

    pub fn init(entries: u32, ring_fd: i32, offsets: os.io_cqring_offsets) @This() {
        var comps: CompQueue = undefined;
        comps.size = offsets.cqes + (entries * @sizeOf(u32));
        comps.mmap_ptr = sys.mmap(null, comps.size, os.PROT_READ | os.PROT_WRITE, os.MAP_SHARED | os.MAP_POPULATE, ring_fd, os.IORING_OFF_SQ_RING);

        comps.head = @intToPtr(*u32, comps.mmap_ptr + offsets.head);
        comps.tail = @intToPtr(*u32, comps.mmap_ptr + offsets.tail);
        comps.mask = @intToPtr(*u32, comps.mmap_ptr + offsets.ring_mask);
        comps.entries = @intToPtr(*u32, comps.mmap_ptr + offsets.ring_entries);
        comps.overflow = @intToPtr(*u32, comps.mmap_ptr + offsets.overflow);
        comps.cqes = @intToPtr([*]os.io_uring_cqe, comps.mmap_ptr + offsets.cqes);

        return comps;
    }

    // this can probably error or return an optional
    pub fn get(self: *Self) *os.io_uring_cqe {
        @fence(builtin.AtomicOrder.SeqCst);
        var idx = self.head.* & self.mask.*;
        var entry = &self.cqes[idx];

        @fence(builtin.AtomicOrder.SeqCst);
        self.head.* += 1;
        @fence(builtin.AtomicOrder.SeqCst);

        return entry;
    }

    pub fn print(self: *Self) void {
        var stdout = &io.getStdOut().outStream().stream;
        var idx: u16 = 0;

        while (idx < self.entries.*) {
            _ = stdout.print("cqe #{}: {}\n", .{ idx, &self.cqes[idx] }) catch |err| null;
            idx += 1;
        }
    }
};
