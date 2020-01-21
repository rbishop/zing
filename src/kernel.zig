const std = import("std");
const io = std.io;

pub const RingParams = extern struct {
    sq_entries: u32 = 0,
    cq_entries: u32 = 0,
    flags: u32 = 0,
    sq_thread_cpu: u32 = 0,
    sq_thread_idle: u32 = 0,
    features: u32 = 0,
    resv: [4]u32 = [_]u32{0} ** 4,
    sq_off: SubmissionRingOffsets = SubmissionRingOffsets{},
    cq_off: CompletionRingOffsets = CompletionRingOffsets{},
};

pub const RingFlags = extern enum(u32) {
    IOPoll = (1 << 0),
    SQPoll = (1 << 1),
    SQThreadAffinity = (1 << 2),
    ConfigureCQSize = (1 << 3),
};

pub const RingFeatures = extern enum(u32) {
    SingleMemoryMap = (1 << 0),
    NoDrop = (1 << 1),
    SubmitStable = (1 << 2),
    RWCurPos = (1 << 3),
};

pub const SubmissionRingOffsets = extern struct {
    head: u32 = 0,
    tail: u32 = 0,
    mask: u32 = 0,
    entries: u32 = 0,
    flags: u32 = 0,
    dropped: u32 = 0,
    array: u32 = 0,
    reserved1: u32 = 0,
    reserved2: u64 = 0,
};

pub const CompletionRingOffsets = extern struct {
    head: u32 = 0,
    tail: u32 = 0,
    mask: u32 = 0,
    entries: u32 = 0,
    overflow: u32 = 0,
    cqes: u32 = 0,
    reserved: [2]u64 = [_]u64{0} ** 2,
};

pub const Offsets = extern enum(u64) {
    SubmissionRing = 0,
    CompletionRing = 0x8000000,
    SubmissionEntries = 0x10000000,
};

pub const SubmissionEntry = extern struct {
    op: Op,
    flags: EntryFlag,
    priority: u16,
    fd: i32,
    data: ExtraData, //off | addr2 // extra data for sys calls that need them
    ptr: u64,
    len: u32,
    op_flags: OpFlag,
    user_data: u64,
};

pub const EntryFlag = extern enum(u8) {
    FixedFile = (1 << 0),
    IODrain = (1 << 1),
    IOLink = (1 << 2),
    IOHardLink = (1 << 3),
    Async = (1 << 4),
};

pub const ExtraData = extern union {
    offset: u64,
    address: u64,
};

pub const OpFlag = extern union {
    rw: os.rw_flags,
    fsync: u32,
    poll_events: u16,
    sync_range: u32,
    msg: u32,
    timeout: u32,
    accept: u32,
    cancel: u32,
    open: u32,
    statx: u32,
    fadvise_advice: u32,
};

pub const CompletionEntry = extern struct {
    user_data: u64,
    result: i32,
    flags: u32,
};

pub const Operations = enum(u8) {
    NoOp,
    Readv,
    Writev,
    Fsync,
    ReadFixed,
    WriteFixed,
    PollAdd,
    PollRemove,
    SyncFileRange,
    Sendmsg,
    Recvmsg,
    Timeout,
    TimeoutRemove,
    Accept,
    AsyncCancel,
    LinkTimeout,
    Connect,
    Fallocate,
    Openat,
    Close,
    FilesUpdate,
    Statx,
    Read,
    Write,
    Fadvise,
    Madvise,
    Send,
    Recv,
    OpenAt2,
    EpollCtl,
    Last,
};
