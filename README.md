# zing

Put some zing in your I/O with the new io_uring interface on Linux

## Goals

**Fluency without losing configurability**
io_uring has a lot of knobs to make sure it can be ideal for various workloads.
I'd like to expose all those io_uring capabilities at varying levels of
abstraction without losing the ability to configure the rings for specific
workloads.

**Speed without being a UNIX wizard**
The various Linux IO mechanisms are loaded with trivia related to error codes,
forking/threading, signal handling, and all sorts of other things. Users of
this library should be able to write highly optimal disk and network I/O
routines without needing to be operating systems experts.

**Clear, correct code using Zig features and idioms**
Features such as ErrorSets, comptime Generics, and defer should make it easy to
write code with proper error handling as well as provide ways for users to
discover how to best use the library and maybe even learn a thing or two about
I/O APIs.

**Just have fun**
I don't have any skin in this game. I just wanna have some fun and experiment.
I might try some really weird shit.

## uring concerns/features

Here's a laundry list of things I want this library to support:

Bare minimum functionality:
- uring initialization, memory mapping
- memory ordering during entry submission and retrieval
- registering fixed buffers and files

Additional features:
- poll mode vs interrupt mode
- linked I/O operations
- deciding when to enter (and potentially block waiting on processed entries) vs add more entries

## Design

This library will provide abstractions at multiple layers. I'll prioritize
starting at the lower layers and working up to the higher layers. Off the top
of my head I can see:

**Layer 1**
Rudimentary wrapping of io_uring's APIs and data structures into an
implementation that feels more Zig-like. Take care of handling the memory
mapping and ordering to safely use the memory regions shared between the kernel
and user space.

**Layer 2**
Abstract away the manipulation of Submission and Completion Queues. Provide
ErrorSets over submitting and retrieving entries to the queues.

**Layer 3**
APIs with type constraints that help the user submit system calls correctly.
For example, use Zig's type system to enforce that the READV op code is also
combined with a SQE containing iov's.

**Layer 4**
Provide Socket and File abstractions that use io_uring underneath.

**Layer2.1**
An additional experiment might be to think of io_uring as a generic interface
for doing *all* system calls asynchronously and leave the concept of I/O out of
it. For example, consider an uring_os module with read, write, fsync, etc.
system calls defined that run on a global (thread local?) io_uring instance.


## TODO

- Add all the kernel syscalls and data structure signatures directly to this
  library so I'm not dependent on the ones in Zig's standard library
- Is Zig's type system good enough that I can create constraints such that
  using a particular OpCode requires setting other fields? I'd like to be able
  to raise mis-use errors at comptime rather than runtime.
- sys.zig module should only be used by this library. Remove any use of it from
  main.zig

## Experiments

- Using very fine-grained error types to try and help the user figure out the
  error. See RingSetupError in src/ring.zig for an example.
- Mapping the SQE operations to more clear names despite them not always
  exactly representing the system call. This reads nicer but might not make it
  obvious which system call is being used underneath. See Operations enum in
  src/kernel.zig for an example.
