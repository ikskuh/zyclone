const std = @import("std");
const zlm = @import("zlm");
const main = @import("entrypoint.zig");

pub const nullvector = zlm.vec3(0, 0, 0);
pub const vector = zlm.vec3;
pub const Vector3 = zlm.Vec3;

pub const @"__implementation" = struct {
    pub fn init() !void {
        level.arena = std.heap.ArenaAllocator.init(mem.backing);
    }
};

pub const Angle = struct {
    pub const zero = Angle{ .pan = 0, .tilt = 0, .roll = 0 };

    pan: f32,
    tilt: f32,
    roll: f32 = 0,
};

pub const time = struct {
    pub var step: f32 = 0;
    pub var total: f32 = 0;
};

pub const mem = struct {
    var backing: std.mem.Allocator = std.heap.c_allocator;

    pub fn create(comptime T: type) *T {
        return backing.create(T) catch @panic("out of memory");
    }

    pub fn destroy(ptr: anytype) void {
        backing.destroy(ptr);
    }

    pub fn alloc(comptime T: type, count: usize) []T {
        return backing.alloc(T, count) catch @panic("out of memory");
    }

    pub fn free(ptr: anytype) void {
        backing.free(ptr);
    }
};

pub const level = struct {
    var arena: std.heap.ArenaAllocator = undefined;

    var entities: std.TailQueue(Entity) = .{};

    pub fn load(path: ?[]const u8) void {
        arena.deinit();
        arena = std.heap.ArenaAllocator.init(mem.backing);
        entities = .{};

        if (path) |real_path| {
            std.log.err("implement loading level file '{s}'", .{real_path});
        }
    }

    pub fn create(comptime T: type) *T {
        return arena.allocator().create(T) catch @panic("out of memory");
    }

    pub fn alloc(comptime T: type, count: usize) []T {
        return arena.allocator().alloc(T, count) catch @panic("out of memory");
    }
};

pub const entity = struct {
    pub fn create(file: ?[]const u8, position: Vector3, comptime Behaviour: ?type) *Entity {
        const ent = level.create(std.TailQueue(Entity).Node);
        ent.* = .{
            .data = Entity{
                .pos = position,
            },
        };

        if (file) |actual_file_path| {
            // TODO: Load geometry and attach to file
            std.log.err("implement loading model file '{s}'", .{actual_file_path});
        }

        if (Behaviour) |ActualBehaviour| {
            _ = ent.data.attach(ActualBehaviour);
        }

        return &ent.data;
    }
};

pub const Entity = struct {
    const BehaviourID = enum(usize) {
        _,

        pub fn isType(self: BehaviourID, comptime T: type) bool {
            return (self == BehaviourStorage(T).id());
        }
    };

    pos: Vector3 = nullvector,
    scale: Vector3 = zlm.Vec3.one,
    rot: Angle = Angle.zero,

    behaviours: std.TailQueue(BehaviourID) = .{},

    pub fn destroy(e: *Entity) void {
        const node = @fieldParentPtr(std.TailQueue(Entity).Node, "data", e);
        level.entities.remove(node);
    }

    pub fn attach(instance: *Entity, comptime Behaviour: type) *Behaviour {
        if (instance.behaviour(Behaviour)) |oh_behave|
            return oh_behave;

        const Storage = BehaviourStorage(Behaviour);

        const storage = level.create(Storage);
        storage.* = Storage{
            .node = .{ .data = Storage.id() },
            .data = undefined,
        };

        if (@hasDecl(Storage, "init")) {
            storage.data.init(instance, &storage.data);
        } else {
            // If no init function is present,
            // we use a default initalization.
            storage.data = Behaviour{};
        }

        instance.behaviours.append(&storage.node);

        return &storage.data;
    }

    pub fn behaviour(instance: *Entity, comptime Behaviour: type) ?*Behaviour {
        const Storage = BehaviourStorage(Behaviour);

        var it = instance.behaviours.first;
        while (it) |node| : (it = node.next) {
            if (node.data == Storage.id()) {
                return &@fieldParentPtr(Storage, "node", node).data;
            }
        }
        return null;
    }

    pub fn detach(instance: *Entity, comptime Behaviour: type) void {
        const Storage = BehaviourStorage(Behaviour);

        var it = instance.behaviours;
        while (it) |node| : (it = node.next) {
            if (node.data == Storage.id()) {
                instance.behaviours.remove(node);

                const storage = @fieldParentPtr(Storage, "node", node);

                if (@hasDecl(Behaviour, "deinit")) {
                    storage.data.deinit();
                }

                std.log.err("TODO: Free the node here", .{});

                return;
            }
        }
    }

    fn BehaviourStorage(comptime Behaviour: type) type {
        return struct {
            var storage_id_buffer: u8 = 0;

            pub inline fn id() BehaviourID {
                return @intToEnum(BehaviourID, @ptrToInt(&storage_id_buffer));
            }

            node: std.TailQueue(BehaviourID).Node,
            data: Behaviour,
        };
    }
};

// Include when stage2 can async:

// pub fn waitForFrame() void {
//     var node = main.Scheduler.WaitNode{
//         .data = main.Scheduler.TaskInfo{
//             .frame = undefined,
//         },
//     };
//     suspend {
//         node.data.frame = @frame();
//         main.scheduler.appendWaitNode(&node);
//     }
// }

// pub const scheduler = struct {
//     //
// };
