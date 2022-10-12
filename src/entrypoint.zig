const std = @import("std");
const zg = @import("zero-graphics");
const game = @import("@GAME@");

pub const engine = @import("basegame.zig");

const Application = @This();

comptime {
    if (game.engine_verification_export.mem != engine.mem)
        @compileError("Invalid import loop!");
}

// pub var scheduler: Scheduler = undefined;

pub fn init(app: *Application) !void {
    app.* = .{};

    // scheduler = Scheduler.init();
    // defer scheduler.deinit();

    // Coroutine(game.main).start(.{});

    // var index: usize = 0;
    // while (index < 20) : (index += 1) {
    //     scheduler.nextFrame();
    // }

    try engine.@"__implementation".init();

    try game.main();
}
pub fn update(app: *Application) !bool {
    _ = app;
    while (zg.CoreApplication.get().input.fetch()) |event| {
        if (event == .quit)
            return false;
    }
    return true;
}
pub fn render(app: *Application) !void {
    //
    _ = app;
}
pub fn deinit(app: *Application) void {
    _ = app;
}

// Include when stage2 can async:

// pub const Scheduler = struct {
//     pub const TaskInfo = struct {
//         frame: anyframe,
//     };
//     pub const Process = struct {};
//     pub const WaitList = std.TailQueue(TaskInfo);
//     pub const WaitNode = WaitList.Node;
//     pub const ProcList = std.TailQueue(Process);
//     pub const ProcNode = ProcList.Node;

//     current_frame: WaitList = .{},
//     next_frame: WaitList = .{},
//     process_list: ProcList = .{},

//     fn init() Scheduler {
//         return Scheduler{};
//     }

//     pub fn deinit(sched: *Scheduler) void {
//         sched.* = undefined;
//     }

//     pub fn appendWaitNode(sched: *Scheduler, node: *WaitNode) void {
//         sched.next_frame.append(node);
//     }

//     pub fn nextFrame(sched: *Scheduler) void {
//         while (sched.current_frame.popFirst()) |func| {
//             resume func.data.frame;
//         }

//         sched.current_frame = sched.next_frame;
//         sched.next_frame = .{};
//     }
// };

// fn Coroutine(func: anytype) type {
//     const Func = @TypeOf(func);
//     const info: std.builtin.Type.Fn = @typeInfo(Func).Fn;
//     const return_type = info.return_type orelse @compileError("Must be non-generic function");

//     switch (@typeInfo(return_type)) {
//         .ErrorUnion, .Void => {},
//         else => @compileError("Coroutines can't return values!"),
//     }

//     return struct {
//         const Coro = @This();
//         const Frame = @Frame(wrappedCall);

//         const ProcNode = struct {
//             process: Scheduler.ProcNode,
//             frame: Frame,
//             result: void,
//         };

//         fn wrappedCall(mem: *ProcNode, args: std.meta.ArgsTuple(Func)) void {
//             var inner_result = @call(.{}, func, args);
//             switch (@typeInfo(return_type)) {
//                 .ErrorUnion => inner_result catch |err| std.log.err("{s} failed with error {s}", .{
//                     @typeName(Coro),
//                     @errorName(err),
//                 }),
//                 .Void => {},
//                 else => @compileError("Coroutines can't return values!"),
//             }
//             scheduler.process_list.remove(&mem.process);
//             engine.mem.destroy(mem);
//         }

//         pub fn start(args: anytype) void {
//             const mem = engine.mem.create(ProcNode);

//             mem.* = .{
//                 .process = .{ .data = Scheduler.Process{} },
//                 .frame = undefined,
//                 .result = {},
//             };
//             scheduler.process_list.append(&mem.process);
//             _ = @asyncCall(std.mem.asBytes(&mem.frame), &mem.result, wrappedCall, .{ mem, args });
//         }
//     };
// }
