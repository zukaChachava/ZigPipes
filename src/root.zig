const std = @import("std");
const channels = @import("channels");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const PipeWriter = channels.ChannelWriter;
const PipeReader = channels.ChannelReader;

pub fn Pipe(comptime T: type) type {
    return struct {
        allocator: Allocator,
        continuation: *Continuation(T),

        const Self = @This();

        pub fn init(allocator: Allocator) PipeError!Self {
            const continuation = Continuation(T).init() catch | err | switch (err) {
                error.OutOfMemory => return PipeError.OutOfMemory,
                else => unreachable,
            };

            return .{
                .allocator = allocator,
                .continuation = continuation
            };
        }

        pub fn begin(self: *Self) *Continuation(T) {
            return self.continuation;
        }
    };
}

fn Continuation(comptime T: type) type {
    return struct {
        allocator: Allocator,
        units: std.DoublyLinkedList(UnitOfWork(T)),

        const Self = @This();

        fn init(allocator: Allocator) PipeError!*Self {
            const ptr = allocator.create(Continuation(T)) catch | err | switch (err) {
                error.OutOfMemory => return PipeError.OutOfMemory,
                else => unreachable,
            };

            ptr.* = .{
                .allocator = allocator,
                .units = std.DoublyLinkedList(UnitOfWork(T)){},
            };

            return ptr;
        }

        fn run(self: *Self, comptime function: fn(writer: PipeWriter(T)) void) channels.ChannelError!*Self {
            var unitOfWork = try UnitOfWork(T).init(self.allocator);

            const thread = Thread.spawn(.{.allocator = self.allocator}, function, .{unitOfWork.channel.getWriter()}) catch | err | switch (err) {
                error.OutOfMemory => return PipeError.OutOfMemory,
                error.ThreadQuotaExceeded => return PipeError.ThreadQuotaExceeded,
                error.SystemResources => return PipeError.SystemResources,
                error.LockedMemoryLimitExceeded => return PipeError.LockedMemoryLimitExceeded,
                error.Unexpected => return PipeError.Unexpected,
                else => unreachable,
            };

            thread.setName("Pipe 1");
            unitOfWork.thread = thread;
            self.units.append(unitOfWork);
            return self;
        }

        pub fn then(self: *Self, comptime function: fn(reader: PipeReader(T), writer: PipeWriter(T)) channels.ChannelError!void) PipeError!*Self {
            var unitOfWork = try UnitOfWork(T).init(self.allocator);
            const previousUnitOfWork = self.units.pop().?;

            const thread = Thread.spawn(.{.allocator = self.allocator}, function, .{previousUnitOfWork.channel.getReader(), unitOfWork.channel.getWriter()}) catch | err | switch (err) {
                error.OutOfMemory => return PipeError.OutOfMemory,
                error.ThreadQuotaExceeded => return PipeError.ThreadQuotaExceeded,
                error.SystemResources => return PipeError.SystemResources,
                error.LockedMemoryLimitExceeded => return PipeError.LockedMemoryLimitExceeded,
                error.Unexpected => return PipeError.Unexpected,
                else => unreachable,
            };

            const buffer: [10]u8 = undefined;
            std.fmt.bufPrint(buffer, "Pipe {}",.{self.units.len});
            thread.setName(buffer);
            unitOfWork.thread = thread;
            self.units.append(previousUnitOfWork);
            self.units.append(unitOfWork);
            return self;
        }

        pub fn finally(self: *Self, comptime function: fn(reader: PipeReader(T)) void) PipeError!*Self {
            const lastUnitOfWork = self.units.pop().?;
            const reader = lastUnitOfWork.channel.getReader();

            const thread = Thread.spawn(.{.allocator = self.allocator}, function, .{reader}) catch | err | switch (err) {
                error.OutOfMemory => return PipeError.OutOfMemory,
                error.ThreadQuotaExceeded => return PipeError.ThreadQuotaExceeded,
                error.SystemResources => return PipeError.SystemResources,
                error.LockedMemoryLimitExceeded => return PipeError.LockedMemoryLimitExceeded,
                error.Unexpected => return PipeError.Unexpected,
                else => unreachable,
            };

            const buffer: [10]u8 = undefined;
            std.fmt.bufPrint(buffer, "Pipe {}",.{self.units.len});
            thread.setName(buffer);
            
            // ToDo: Is this okey ?
            thread.detach();
            return self;
        }

        pub fn deinit(self: *Self) void {
            while(self.units.popFirst) | unitOfWork | {
                unitOfWork.deinit();
            }

            self.allocator.destroy(self);
        }
    };
}

fn UnitOfWork(comptime T: type) type {
    return struct {
        channel: *channels.Channel(T),
        allocator: Allocator,
        thread: ?Thread,

        const Self = @This();

        fn init(allocator: Allocator) PipeError!Self {
            const channel = channels.Channel(T).init(allocator) catch | err | switch (err) {
                error.OutOfMemory => return PipeError.OutOfMemory,
                else => unreachable,
            };
            
            return .{
                .allocator = allocator,
                .channel = channel,
                .thread = null,
            };
        }

        fn deinit(self: Self) void {
            self.thread.?.detach();
            self.channel.deinit();
        }
    };
}

pub const PipeError = error {
    OutOfMemory,
    ThreadQuotaExceeded,
    SystemResources,
    LockedMemoryLimitExceeded,
    Unexpected,
};