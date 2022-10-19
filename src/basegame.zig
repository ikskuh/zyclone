const std = @import("std");
const zlm = @import("zlm");
const zg = @import("zero-graphics");
const main = @import("entrypoint.zig");
const gamestudio = @import("libgamestudio");
const game = @import("@GAME@");

fn core() *zg.CoreApplication {
    return zg.CoreApplication.get();
}

pub const nullvector = zlm.vec3(0, 0, 0);
pub const vector = zlm.vec3;
pub const Vector3 = zlm.Vec3;

pub const Matrix4 = zlm.Mat4;

pub const Angle = struct {
    pub const zero = Angle{ .pan = 0, .tilt = 0, .roll = 0 };

    pan: f32,
    tilt: f32,
    roll: f32 = 0,
};

pub const Texture = zg.ResourceManager.Texture;

/// Shuts down the engine
pub fn exit() void {
    @"__implementation".quit_now = true;
}

////////////////////////////////////////////////
// Global behaviour system
////////////////////////////////////////////////

var global_behaviours: BehaviourSystem(mem, void) = .{};

pub fn attach(comptime Behaviour: type) *Behaviour {
    return global_behaviours.attach({}, Behaviour);
}

pub fn behaviour(comptime Behaviour: type) ?*Behaviour {
    return global_behaviours.behaviour(Behaviour);
}

pub fn detach(comptime Behaviour: type) void {
    return global_behaviours.detach(Behaviour);
}

////////////////////////////////////////////////
// Modules
////////////////////////////////////////////////

pub const time = struct {
    pub var step: f32 = 0;
    pub var total: f32 = 0;
};

pub const mem = struct {
    var backing: std.mem.Allocator = std.heap.c_allocator;

    pub fn create(comptime T: type) *T {
        return backing.create(T) catch oom();
    }

    pub fn destroy(ptr: anytype) void {
        backing.destroy(ptr);
    }

    pub fn alloc(comptime T: type, count: usize) []T {
        return backing.alloc(T, count) catch oom();
    }

    pub fn free(ptr: anytype) void {
        backing.free(ptr);
    }
};

pub const level = struct {
    var arena: std.heap.ArenaAllocator = undefined;
    var entities: std.TailQueue(Entity) = .{};
    var level_behaviours: BehaviourSystem(level, void) = .{};

    var palette: ?gamestudio.wmb.Palette = null;

    fn wmb2vec(v: gamestudio.Vector3) Vector3 {
        return vector(v.x, v.y, v.z);
    }

    /// Destroys all currently active entities, and provides a clean slate for 3D data.
    /// If `path` is provided, will also load the render object as the root of the level.
    /// Frees all memory allocated via the `level` abstraction.
    pub fn load(path: ?[]const u8) void {
        arena.deinit();
        arena = std.heap.ArenaAllocator.init(mem.backing);
        entities = .{};
        level_behaviours = .{};
        level.palette = null;

        if (path) |real_path| {
            var level_dir = std.fs.cwd().openDir(std.fs.path.dirname(real_path) orelse ".", .{}) catch |err| panic(err);
            defer level_dir.close();

            var level_file = level_dir.openFile(std.fs.path.basename(real_path), .{}) catch |err| panic(err);
            defer level_file.close();

            var level_source = std.io.StreamSource{ .file = level_file };

            var level_data = gamestudio.wmb.load(
                level.arena.allocator(),
                &level_source,
                .{
                    .target_coordinate_system = .opengl,
                    // .scale = 1.0 / 16.0,
                },
            ) catch |err| panic(err);

            level.palette = level_data.palette;

            var block_geometry = BlockGeometry.fromWmbData(arena.allocator(), level_data);

            // TODO: Implement setup of environment data

            // Create an entity that will be our "map"

            const map_ent = entity.create(null, nullvector, null);
            map_ent.geometry = .{ .blocks = block_geometry };

            for (level_data.objects) |object, oid| {
                switch (object) {
                    .position => std.log.warn("TODO: Implement loading of position object.", .{}),
                    .light => std.log.warn("TODO: Implement loading of light object.", .{}),
                    .sound => std.log.warn("TODO: Implement loading of sound object.", .{}),
                    .path => std.log.warn("TODO: Implement loading of path object.", .{}),
                    .entity => |def| {
                        const ent = entity.createAt(level_dir, def.file_name.get(), wmb2vec(def.origin), null);
                        ent.rot = Angle{ .pan = def.angle.pan, .tilt = def.angle.tilt, .roll = def.angle.roll };
                        ent.scale = wmb2vec(def.scale);
                        ent.skills = def.skills;

                        // Load terrain lightmap if possible
                        {
                            const maybe_lm: ?gamestudio.wmb.LightMap = for (level_data.terrain_light_maps) |lm| {
                                const oid_ref = lm.object orelse continue;
                                if (oid_ref == oid) break lm;
                            } else null;

                            if (maybe_lm) |lm| {
                                ent.lightmap = core().resources.createTexture(
                                    .@"3d",
                                    WmbLightmapLoader{ .lightmap = lm },
                                ) catch |err| panic(err);
                            }
                        }

                        // TODO: Copy more properties over
                        // - name
                        // - flags
                        // - ambient
                        // - albedo
                        // - path
                        // - attached_entity
                        // - material
                        // - string1
                        // - string2

                        // Attach behaviours
                        if (@hasDecl(game, "actions")) {
                            var iter = std.mem.tokenize(u8, def.action.get(), ", ");
                            while (iter.next()) |action_name| {
                                _ = action_name;

                                //
                            }
                        } else if (def.action.len() > 0) {
                            std.log.warn("Entity '{s}' has an action '{s}', but there's no global action list available.", .{
                                def.name,
                                def.action,
                            });
                        }
                    },
                    .region => std.log.warn("TODO: Implement loading of region object.", .{}),
                }
            }
        }
    }

    pub fn create(comptime T: type) *T {
        return arena.allocator().create(T) catch oom();
    }

    pub fn alloc(comptime T: type, count: usize) []T {
        return arena.allocator().alloc(T, count) catch oom();
    }

    pub fn destroy(ptr: anytype) void {
        arena.allocator().destroy(ptr);
    }

    pub fn free(ptr: anytype) void {
        arena.allocator().free(ptr);
    }

    pub fn attach(comptime Behaviour: type) *Behaviour {
        return level_behaviours.attach({}, Behaviour);
    }

    pub fn behaviour(comptime Behaviour: type) ?*Behaviour {
        return level_behaviours.behaviour(Behaviour);
    }

    pub fn detach(comptime Behaviour: type) void {
        return level_behaviours.detach(Behaviour);
    }
};

pub const entity = struct {
    pub fn create(file: ?[]const u8, position: Vector3, comptime Behaviour: ?type) *Entity {
        return createAt(std.fs.cwd(), file, position, Behaviour);
    }

    pub fn createAt(folder: std.fs.Dir, file: ?[]const u8, position: Vector3, comptime Behaviour: ?type) *Entity {
        const ent = level.create(std.TailQueue(Entity).Node);
        ent.* = .{
            .data = Entity{
                .pos = position,
            },
        };

        if (file) |actual_file_path| {
            if (@"__implementation".loadRenderObject(folder, actual_file_path)) |geom| {
                ent.data.geometry = geom;
            } else {
                std.log.err("could not find entity '{s}'", .{actual_file_path});
            }
        }

        if (Behaviour) |ActualBehaviour| {
            _ = ent.data.attach(ActualBehaviour);
        }

        level.entities.append(ent);

        return &ent.data;
    }
};

pub const Entity = struct {
    const Behaviours = BehaviourSystem(level, *Entity);

    // public:
    pos: Vector3 = nullvector,
    scale: Vector3 = zlm.Vec3.one,
    rot: Angle = Angle.zero,

    user_data: [256]u8 = std.mem.zeroes([256]u8),
    skills: [20]f32 = std.mem.zeroes([20]f32),

    // visuals
    geometry: ?RenderObject = null,
    lightmap: ?*Texture = null,

    // private:
    behaviours: Behaviours = .{},

    pub fn destroy(e: *Entity) void {
        const node = @fieldParentPtr(std.TailQueue(Entity).Node, "data", e);
        level.entities.remove(node);
    }

    pub fn attach(ent: *Entity, comptime Behaviour: type) *Behaviour {
        return ent.behaviours.attach(ent, Behaviour);
    }

    pub fn behaviour(ent: *Entity, comptime Behaviour: type) ?*Behaviour {
        return ent.behaviours.behaviour(Behaviour);
    }

    pub fn detach(ent: *Entity, comptime Behaviour: type) void {
        return ent.behaviours.detach(Behaviour);
    }
};

pub const RenderObjectType = enum {
    model,
    sprite,
    blocks,
    terrain,
};

/// A render object is something that the engine can render.
pub const RenderObject = union(RenderObjectType) {
    /// A regular 3D model.
    model: *zg.ResourceManager.Geometry,

    /// A flat, camera-oriented billboard.
    sprite: *Texture,

    /// A level geometry constructed out of blocks.
    blocks: BlockGeometry,

    /// A heightmap geometry
    terrain: Terrain,
};

pub const Terrain = struct {
    // TODO
};

pub const BlockGeometry = struct {
    geometries: []*zg.ResourceManager.Geometry,

    fn fromWmbData(allocator: std.mem.Allocator, lvl: gamestudio.wmb.Level) BlockGeometry {
        // TODO: Implement loading of lightmaps

        var texture_cache = TextureCache.init(allocator);
        defer texture_cache.deinit();

        var geoms = allocator.alloc(*zg.ResourceManager.Geometry, lvl.blocks.len) catch oom();
        errdefer allocator.free(geoms);

        for (lvl.blocks) |src_block, i| {
            geoms[i] = core().resources.createGeometry(WmbGeometryLoader{
                .level = lvl,
                .block = src_block,
                .textures = &texture_cache,
            }) catch |err| panic(err);
        }

        return BlockGeometry{
            .geometries = geoms,
        };
    }
};

pub const View = struct {
    pos: Vector3 = nullvector,
    rot: Angle = Angle.zero,
    arc: f32 = 60.0,

    znear: f32 = 0.1,
    zfar: f32 = 10_000.0,

    viewport: zg.Rectangle = zg.Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 },
};

pub var camera: View = .{};

pub const Key = zg.Input.Scancode;

pub const key = struct {
    var held_keys: std.enums.EnumSet(zg.Input.Scancode) = .{};
    var pressed_keys: std.enums.EnumSet(zg.Input.Scancode) = .{};
    var released_keys: std.enums.EnumSet(zg.Input.Scancode) = .{};

    /// returns true if the `key` is currently held down.
    pub fn held(key_code: zg.Input.Scancode) bool {
        return held_keys.contains(key_code);
    }

    /// returns true if the `key` is was pressed this frame.
    pub fn pressed(key_code: zg.Input.Scancode) bool {
        return pressed_keys.contains(key_code);
    }

    /// returns true if the `key` is was released this frame.
    pub fn released(key_code: zg.Input.Scancode) bool {
        return released_keys.contains(key_code);
    }
};

pub const mouse = struct {
    pub const Button = zg.Input.MouseButton;

    pub var position: zg.Point = zg.Point.zero;
    pub var delta: zg.Point = zg.Point.zero;

    var held_buttons: std.enums.EnumSet(Button) = .{};
    var pressed_buttons: std.enums.EnumSet(Button) = .{};
    var released_buttons: std.enums.EnumSet(Button) = .{};

    /// returns true if the `key` is currently held down.
    pub fn held(button_index: Button) bool {
        return held_buttons.contains(button_index);
    }

    /// returns true if the `key` is was pressed this frame.
    pub fn pressed(button_index: Button) bool {
        return pressed_buttons.contains(button_index);
    }

    /// returns true if the `key` is was released this frame.
    pub fn released(button_index: Button) bool {
        return released_buttons.contains(button_index);
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

pub const mat = struct {
    pub fn forAngle(ang: Angle) Matrix4 {
        return zlm.Mat4.batchMul(&.{
            zlm.Mat4.createAngleAxis(Vector3.unitZ, zlm.toRadians(ang.roll)),
            zlm.Mat4.createAngleAxis(Vector3.unitX, zlm.toRadians(ang.tilt)),
            zlm.Mat4.createAngleAxis(Vector3.unitY, zlm.toRadians(ang.pan)),
        });
    }
};

pub const vec = struct {
    pub fn rotate(v: Vector3, ang: Angle) Vector3 {
        return v.transformDirection(mat.forAngle(ang));
    }

    pub fn forAngle(ang: Angle) Vector3 {
        const pan = zlm.toRadians(ang.pan);
        const tilt = zlm.toRadians(ang.tilt);
        return vector(
            @sin(pan) * @cos(tilt),
            -@sin(tilt),
            -@cos(pan) * @cos(tilt),
        );
    }
};

pub const screen = struct {
    pub var color: zg.Color = .{ .r = 0, .g = 0, .b = 0x80 };
};

pub const DefaultCamera = struct {
    pub var vel_slow: f32 = 10.0;
    pub var vel_high: f32 = 45.0;

    // const Mode = enum {
    //     no_visualization,
    //     only_stats,
    //     with_objects,
    // };

    pub fn update(_: *@This()) void {
        if (key.pressed(.escape))
            exit();

        const fps_mode = mouse.held(.secondary);

        const velocity: f32 = if (key.held(.shift_left))
            vel_high
        else
            vel_slow;

        if (key.held(.left))
            camera.rot.pan += 90 * time.step;
        if (key.held(.right))
            camera.rot.pan -= 90 * time.step;
        if (key.held(.page_up))
            camera.rot.tilt -= 90 * time.step;
        if (key.held(.page_down))
            camera.rot.tilt += 90 * time.step;

        if (fps_mode) {
            camera.rot.pan -= @intToFloat(f32, mouse.delta.x);
            camera.rot.tilt += @intToFloat(f32, mouse.delta.y);
        }

        const fwd = vec.forAngle(camera.rot).scale(velocity * time.step);
        const left = vec.rotate(vector(1, 0, 0), camera.rot).scale(velocity * time.step);

        if (key.held(.up) or key.held(.w))
            camera.pos = camera.pos.add(fwd);
        if (key.held(.down) or key.held(.s))
            camera.pos = camera.pos.sub(fwd);

        if (key.held(.a))
            camera.pos = camera.pos.add(left);
        if (key.held(.d))
            camera.pos = camera.pos.sub(left);
    }
};

/// do not use this!
/// it's meant for internal use of the engine
pub const @"__implementation" = struct {
    const Application = main;
    var quit_now = false;

    var geometry_cache: std.StringHashMapUnmanaged(RenderObject) = .{};
    var texture_cache: std.StringHashMapUnmanaged(*Texture) = .{};

    // pub var scheduler: Scheduler = undefined;

    var last_frame_time: i64 = undefined;
    var r2d: zg.Renderer2D = undefined;
    var r3d: zg.Renderer3D = undefined;

    pub fn init(app: *Application) !void {
        app.* = .{};

        r2d = try core().resources.createRenderer2D();
        r3d = try core().resources.createRenderer3D();

        mem.backing = core().allocator;
        level.arena = std.heap.ArenaAllocator.init(mem.backing);

        // scheduler = Scheduler.init();
        // defer scheduler.deinit();

        // Coroutine(game.main).start(.{});
        try game.main();

        last_frame_time = zg.milliTimestamp();
    }

    pub fn update(_: *Application) !bool {
        const timestamp = zg.milliTimestamp();
        defer last_frame_time = timestamp;

        time.total = @intToFloat(f32, timestamp) / 1000.0;
        time.step = @intToFloat(f32, timestamp - last_frame_time) / 1000.0;

        key.pressed_keys = .{};
        key.released_keys = .{};

        mouse.pressed_buttons = .{};
        mouse.released_buttons = .{};

        const prev_mouse_pos = mouse.position;
        while (zg.CoreApplication.get().input.fetch()) |event| {
            switch (event) {
                .quit => return false,

                .key_down => |key_code| {
                    key.pressed_keys.insert(key_code);
                    key.held_keys.insert(key_code);
                },

                .key_up => |key_code| {
                    key.released_keys.insert(key_code);
                    key.held_keys.remove(key_code);
                },

                .pointer_motion => |position| {
                    mouse.position = position;
                },

                .pointer_press => |button| {
                    mouse.pressed_buttons.insert(button);
                    mouse.held_buttons.insert(button);
                },
                .pointer_release => |button| {
                    mouse.released_buttons.insert(button);
                    mouse.held_buttons.remove(button);
                },

                .text_input => |input| {
                    _ = input;
                },
            }
        }

        mouse.delta = .{
            .x = mouse.position.x - prev_mouse_pos.x,
            .y = mouse.position.y - prev_mouse_pos.y,
        };

        // global update process
        {
            global_behaviours.updateAll({});
        }

        // level update process
        {
            level.level_behaviours.updateAll({});
        }

        // entity update process
        {
            var it = level.entities.first;
            while (it) |node| : (it = node.next) {
                const ent: *Entity = &node.data;

                ent.behaviours.updateAll(ent);
            }
        }

        // schedule coroutines
        {
            // scheduler.nextFrame();
        }

        if (quit_now)
            return false;

        r2d.reset();
        r3d.reset();

        // render all entities
        {
            var it = level.entities.first;
            while (it) |node| : (it = node.next) {
                const ent: *Entity = &node.data;

                if (ent.geometry) |render_object| {
                    const mat_pos = zlm.Mat4.createTranslation(ent.pos);
                    const mat_rot = mat.forAngle(ent.rot);
                    const mat_scale = zlm.Mat4.createScale(ent.scale.x, ent.scale.y, ent.scale.z);

                    const trafo = zlm.Mat4.batchMul(&.{
                        mat_scale,
                        mat_rot,
                        mat_pos,
                    });

                    switch (render_object) {
                        .sprite => |texture| {
                            try r3d.drawSprite(texture, trafo.fields);

                            // @panic("sprite not supported yet");
                        },
                        .model => |geometry| try r3d.drawGeometry(geometry, trafo.fields),
                        .blocks => |blocks| {
                            for (blocks.geometries) |geometry| {
                                try r3d.drawGeometry(geometry, trafo.fields);
                            }
                        },
                        .terrain => @panic("terrain not supported yet"),
                    }
                }
            }
        }

        return (quit_now == false);
    }

    pub fn render(_: *Application) !void {
        const gl = zg.gles;

        gl.clearColor(
            @intToFloat(f32, screen.color.r) / 255.0,
            @intToFloat(f32, screen.color.g) / 255.0,
            @intToFloat(f32, screen.color.b) / 255.0,
            @intToFloat(f32, screen.color.a) / 255.0,
        );
        gl.clearDepthf(1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const ss = core().screen_size;

        const aspect = @intToFloat(f32, ss.width) / @intToFloat(f32, ss.height);

        const camera_fwd = vec.rotate(vector(0, 0, -1), camera.rot);
        const camera_up = vec.rotate(vector(0, 1, 0), camera.rot);

        const projection_matrix = zlm.Mat4.createPerspective(
            zlm.toRadians(camera.arc),
            aspect,
            camera.znear,
            camera.zfar,
        );
        const view_matrix = zlm.Mat4.createLook(camera.pos, camera_fwd, camera_up);

        const camera_view_proj = zlm.Mat4.batchMul(&.{
            view_matrix,
            projection_matrix,
        });

        r3d.render(camera_view_proj.fields);

        r2d.render(ss);
    }

    pub fn deinit(_: *Application) void {
        {
            var iter = geometry_cache.keyIterator();
            while (iter.next()) |file_name| {
                mem.backing.free(file_name.*);
            }
        }
        {
            var iter = texture_cache.keyIterator();
            while (iter.next()) |file_name| {
                mem.backing.free(file_name.*);
            }
        }

        geometry_cache.deinit(mem.backing);
        texture_cache.deinit(mem.backing);
    }

    fn load3DTexture(dir: std.fs.Dir, path: []const u8) ?*Texture {
        const full_path = dir.realpathAlloc(mem.backing, path) catch |err| panic(err);
        const gop = texture_cache.getOrPut(mem.backing, full_path) catch oom();

        if (gop.found_existing) {
            mem.free(full_path);
            return gop.value_ptr.*;
        }

        var file_data = dir.readFileAlloc(
            mem.backing,
            full_path,
            1 << 30, // GB
        ) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.err("could not find texture file '{s}'", .{full_path});
                return null;
            },
            else => |e| panic(e),
        };

        var spec = zg.ResourceManager.DecodeImageData{
            .data = file_data,
        };

        gop.value_ptr.* = core().resources.createTexture(.@"3d", spec) catch |err| panic(err);

        return gop.value_ptr.*;
    }

    fn loadRenderObject(dir: std.fs.Dir, path: []const u8) ?RenderObject {
        const ext = std.fs.path.extension(path);
        const extension_map = .{
            .wmb = .blocks,

            .z3d = .model,
            .mdl = .model,

            .png = .sprite,
            .qoi = .sprite,
            .tga = .sprite,

            .hmp = .terrain,
        };

        const object_type: RenderObjectType = inline for (@typeInfo(@TypeOf(extension_map)).Struct.fields) |fld| {
            if (std.mem.eql(u8, ext, "." ++ fld.name))
                break @field(RenderObjectType, @tagName(@field(extension_map, fld.name)));
        } else {
            std.log.warn("tried to load unsupported file '{s}'", .{path});
            return null;
        };

        const full_path = dir.realpathAlloc(mem.backing, path) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.err("could not find file '{s}'", .{path});
                return null;
            },
            else => |e| panic(e),
        };
        const gop = geometry_cache.getOrPut(mem.backing, full_path) catch oom();
        if (gop.found_existing) {
            mem.free(full_path);
            return gop.value_ptr.*;
        }

        gop.value_ptr.* = switch (object_type) {
            .sprite => blk: {
                const tex = load3DTexture(dir, path) orelse {
                    std.debug.assert(geometry_cache.remove(full_path));
                    return null;
                };
                break :blk .{ .sprite = tex };
            },

            .model => blk: {
                if (std.mem.eql(u8, ext, ".mdl")) {
                    // const TextureLoader = struct {
                    //     dir: std.fs.Dir,
                    //     pub fn load(loader: @This(), rm: *zg.ResourceManager, name: []const u8) !?*Texture {
                    //         std.debug.assert(&core().resources == rm);
                    //         if (std.mem.startsWith(u8, name, "*")) {
                    //             // TODO: Implement internal texture loading ("*0")
                    //             std.log.err("TODO: Implement internal texture loading for texture {s}", .{name});
                    //             return null;
                    //         }
                    //         return load3DTexture(loader.dir, name);
                    //     }
                    // };

                    var file = dir.openFile(full_path, .{}) catch |err| switch (err) {
                        error.FileNotFound => {
                            std.debug.assert(geometry_cache.remove(full_path));
                            return null;
                        },
                        else => |e| panic(e),
                    };
                    defer file.close();

                    var source = std.io.StreamSource{ .file = file };

                    var mdl_data = gamestudio.mdl.load(
                        mem.backing,
                        &source,
                        .{
                            .target_coordinate_system = .opengl,
                            // .scale = 1.0 / 16.0, // don't scale models, they will be automatically scaled down in the level loader if necessary
                        },
                    ) catch |err| {
                        std.log.err("failed to load level file '{s}': {s}", .{
                            path,
                            @errorName(err),
                        });
                        std.debug.assert(geometry_cache.remove(full_path));
                        return null;
                    };

                    var spec = MdlGeometryLoader{
                        .mdl = mdl_data,
                        // .loader = TextureLoader{ .dir = dir },
                    };

                    break :blk .{ .model = core().resources.createGeometry(spec) catch |err| panic(err) };
                } else {
                    var file_data = dir.readFileAlloc(
                        mem.backing,
                        full_path,
                        1 << 30, // GB
                    ) catch |err| switch (err) {
                        error.FileNotFound => return null,
                        else => |e| panic(e),
                    };

                    const TextureLoader = struct {
                        dir: std.fs.Dir,
                        pub fn load(loader: @This(), rm: *zg.ResourceManager, name: []const u8) !?*Texture {
                            std.debug.assert(&core().resources == rm);
                            if (std.mem.startsWith(u8, name, "*")) {
                                // TODO: Implement internal texture loading ("*0")
                                std.log.err("TODO: Implement internal texture loading for texture {s}", .{name});
                                return null;
                            }
                            return load3DTexture(loader.dir, name);
                        }
                    };

                    var spec = zg.ResourceManager.Z3DGeometry(TextureLoader){
                        .data = file_data,
                        .loader = TextureLoader{ .dir = dir },
                    };

                    break :blk .{ .model = core().resources.createGeometry(spec) catch |err| panic(err) };
                }
            },

            .blocks => blk: {
                var level_dir = dir.openDir(std.fs.path.dirname(path) orelse ".", .{}) catch |err| panic(err);
                defer level_dir.close();

                var level_file = level_dir.openFile(std.fs.path.basename(path), .{}) catch |err| panic(err);
                defer level_file.close();

                var level_source = std.io.StreamSource{ .file = level_file };

                var level_data = gamestudio.wmb.load(
                    level.arena.allocator(),
                    &level_source,
                    .{
                        .target_coordinate_system = .opengl,
                        // .scale = 1.0 / 16.0,
                    },
                ) catch |err| {
                    std.log.err("failed to load level file '{s}': {s}", .{
                        path,
                        @errorName(err),
                    });
                    std.debug.assert(geometry_cache.remove(full_path));
                    return null;
                };

                break :blk .{ .blocks = BlockGeometry.fromWmbData(mem.backing, level_data) };
            },

            .terrain => {
                @panic("terrain loading not implemented yet!");
            },
        };

        // Make sure we've loaded the right thing
        std.debug.assert(@as(RenderObjectType, gop.value_ptr.*) == object_type);

        return gop.value_ptr.*;
    }
};

const AcknexTextureLoader = struct {
    pub fn create(width: usize, height: usize, format: gamestudio.TextureFormat, pal: ?gamestudio.wmb.Palette, src_data: []const u8, rm: *zg.ResourceManager) zg.ResourceManager.CreateResourceDataError!zg.ResourceManager.TextureData {
        var data = zg.ResourceManager.TextureData{
            .width = std.math.cast(u15, width) orelse return error.InvalidFormat,
            .height = std.math.cast(u15, height) orelse return error.InvalidFormat,
            .pixels = undefined,
        };

        const pixel_count = @as(usize, width) * @as(usize, height);

        const pixels = try rm.allocator.alloc(u8, 4 * pixel_count);
        errdefer rm.allocator.free(pixels);

        data.pixels = pixels;

        switch (format) {
            .rgba8888 => std.mem.copy(u8, data.pixels.?, src_data), // equal size

            .rgb888 => {
                var i: usize = 0;
                while (i < pixel_count) : (i += 1) {
                    pixels[4 * i + 0] = src_data[3 * i + 0];
                    pixels[4 * i + 1] = src_data[3 * i + 1];
                    pixels[4 * i + 2] = src_data[3 * i + 2];
                    pixels[4 * i + 3] = 0xFF;
                }
            },

            .rgb565 => {
                var i: usize = 0;
                while (i < pixel_count) : (i += 1) {
                    const Rgb = packed struct {
                        r: u5,
                        g: u6,
                        b: u5,
                    };
                    const rgb = @bitCast(Rgb, src_data[2 * i ..][0..2].*);

                    pixels[4 * i + 0] = (@as(u8, rgb.b) << 3) | (rgb.b >> 2);
                    pixels[4 * i + 1] = (@as(u8, rgb.g) << 2) | (rgb.g >> 4);
                    pixels[4 * i + 2] = (@as(u8, rgb.r) << 3) | (rgb.r >> 2);
                    pixels[4 * i + 3] = 0xFF;
                }
            },

            .rgb4444 => {
                var i: usize = 0;
                while (i < pixel_count) : (i += 1) {
                    const Rgba = packed struct {
                        r: u4,
                        g: u4,
                        b: u4,
                        a: u4,
                    };
                    const rgba = @bitCast(Rgba, src_data[2 * i ..][0..2].*);
                    pixels[4 * i + 0] = (@as(u8, rgba.b) << 4) | rgba.b;
                    pixels[4 * i + 1] = (@as(u8, rgba.g) << 4) | rgba.g;
                    pixels[4 * i + 2] = (@as(u8, rgba.r) << 4) | rgba.r;
                    pixels[4 * i + 3] = (@as(u8, rgba.a) << 4) | rgba.a;
                }
            },

            .pal256 => {
                const palette = pal orelse gamestudio.default_palette;
                //  {
                //     std.log.err("cannot load texture of type pal256: missing palette", .{});
                //     return error.InvalidFormat;
                // };
                var i: usize = 0;
                while (i < pixel_count) : (i += 1) {
                    const index = src_data[i];
                    pixels[4 * i + 0] = @floatToInt(u8, 255 * palette[index].b);
                    pixels[4 * i + 1] = @floatToInt(u8, 255 * palette[index].g);
                    pixels[4 * i + 2] = @floatToInt(u8, 255 * palette[index].r);
                    pixels[4 * i + 3] = 0xFF;
                }
            },

            .dds, .@"extern" => {
                std.log.err("cannot load texture of type {s}", .{@tagName(format)});
                return error.InvalidFormat;
            },
        }

        return data;
    }
};

const MdlTextureLoader = struct {
    skin: gamestudio.mdl.Skin,

    pub fn create(self: @This(), rm: *zg.ResourceManager) zg.ResourceManager.CreateResourceDataError!zg.ResourceManager.TextureData {
        var skin: gamestudio.mdl.Skin = self.skin;
        return try AcknexTextureLoader.create(
            skin.width,
            skin.height,
            skin.format,
            null,
            skin.data,
            rm,
        );
    }
};

const WmbTextureLoader = struct {
    level: gamestudio.wmb.Level,
    index: usize,

    pub fn create(loader: @This(), rm: *zg.ResourceManager) !zg.ResourceManager.TextureData {
        const source: gamestudio.wmb.Texture = loader.level.textures[loader.index];
        return AcknexTextureLoader.create(
            source.width,
            source.height,
            source.format,
            loader.level.palette,
            source.data,
            rm,
        );
    }
};

const MdlGeometryLoader = struct {
    const Vertex = zg.ResourceManager.Vertex;
    const Mesh = zg.ResourceManager.Mesh;

    mdl: gamestudio.mdl.Model,
    frame: usize = 0,

    pub fn create(self: @This(), rm: *zg.ResourceManager) zg.ResourceManager.CreateResourceDataError!zg.ResourceManager.GeometryData {
        const mdl: gamestudio.mdl.Model = self.mdl;

        var vertices = std.ArrayList(Vertex).init(rm.allocator);
        defer vertices.deinit();
        var indices = std.ArrayList(u16).init(rm.allocator);
        defer indices.deinit();
        var meshes = std.ArrayList(Mesh).init(rm.allocator);
        defer meshes.deinit();

        const frame = mdl.frames[self.frame];
        const skin = mdl.skins[0]; // TODO: check for correct skin!

        const texture = try rm.createTexture(.@"3d", MdlTextureLoader{
            .skin = skin,
        });

        try indices.ensureTotalCapacity(3 * mdl.triangles.len);
        try vertices.ensureTotalCapacity(frame.vertices.len); // rough estimate

        for (mdl.triangles) |tris| {
            var i: usize = 0;
            while (i < 3) : (i += 1) {
                const uv = mdl.skin_vertices.getUV(tris.indices_uv1[i], skin.width, skin.height);
                const vtx = frame.vertices[tris.indices_3d[i]];

                var vertex = Vertex{
                    .x = vtx.position.x,
                    .y = vtx.position.y,
                    .z = vtx.position.z,
                    .nx = vtx.normal.x,
                    .ny = vtx.normal.y,
                    .nz = vtx.normal.z,
                    .u = uv.u,
                    .v = uv.v,
                };

                const vtx_idx = for (vertices.items) |v, j| {
                    if (Vertex.eql(vertex, v, 0.001, 0.95, 1.0 / 32768.0))
                        break j;
                } else vertices.items.len;

                try indices.append(@intCast(u16, vtx_idx));

                if (vtx_idx == vertices.items.len) {
                    try vertices.append(vertex);
                }
            }
        }

        try meshes.append(Mesh{
            .offset = 0,
            .count = indices.items.len,
            .texture = texture,
        });

        return zg.ResourceManager.GeometryData{
            .vertices = vertices.toOwnedSlice(),
            .indices = indices.toOwnedSlice(),
            .meshes = meshes.toOwnedSlice(),
        };
    }
};

const WmbLightmapLoader = struct {
    lightmap: gamestudio.wmb.LightMap,

    pub fn create(loader: @This(), rm: *zg.ResourceManager) !zg.ResourceManager.TextureData {
        const source: gamestudio.wmb.LightMap = loader.lightmap;

        var data = zg.ResourceManager.TextureData{
            .width = std.math.cast(u15, source.width) orelse return error.InvalidFormat,
            .height = std.math.cast(u15, source.height) orelse return error.InvalidFormat,
            .pixels = undefined,
        };

        const pixel_count = @as(usize, data.width) * @as(usize, data.height);

        data.pixels = try rm.allocator.alloc(u8, 4 * pixel_count);
        errdefer rm.allocator.free(data.pixels.?);

        var i: usize = 0;
        while (i < pixel_count) : (i += 1) {
            data.pixels.?[4 * i + 0] = source.data[3 * i + 0];
            data.pixels.?[4 * i + 1] = source.data[3 * i + 1];
            data.pixels.?[4 * i + 2] = source.data[3 * i + 2];
            data.pixels.?[4 * i + 3] = 0xFF;
        }

        return data;
    }
};

const TextureCache = std.AutoHashMap(u16, ?*Texture);

const WmbGeometryLoader = struct {
    const Vertex = zg.ResourceManager.Vertex;
    const Mesh = zg.ResourceManager.Mesh;

    level: gamestudio.wmb.Level,
    block: gamestudio.wmb.Block,
    textures: *TextureCache,

    fn vert2pos(v: Vertex) Vector3 {
        return vector(v.x, v.y, v.z);
    }

    fn normal2vert(v: *Vertex, normal: Vector3) void {
        v.nx = normal.x;
        v.ny = normal.y;
        v.nz = normal.z;
    }

    fn mapVec(in: gamestudio.Vector3) Vector3 {
        return Vector3{ .x = in.x, .y = in.y, .z = in.z };
    }

    pub fn create(loader: @This(), rm: *zg.ResourceManager) !zg.ResourceManager.GeometryData {
        const block = loader.block;

        var data = zg.ResourceManager.GeometryData{
            .vertices = undefined, // []Vertex,
            .indices = undefined, // []u16,
            .meshes = undefined, // []Mesh,
        };

        data.indices = try rm.allocator.alloc(u16, 3 * block.triangles.len);
        errdefer rm.allocator.free(data.indices);

        var vertices = std.ArrayList(Vertex).init(rm.allocator);
        defer vertices.deinit();

        try vertices.ensureTotalCapacity(block.vertices.len);

        // pre-sort triangles so we can easily created
        // meshes based on the texture alone.
        std.sort.sort(gamestudio.wmb.Triangle, block.triangles, block, struct {
            fn lt(ctx: gamestudio.wmb.Block, lhs: gamestudio.wmb.Triangle, rhs: gamestudio.wmb.Triangle) bool {
                const lhs_tex = ctx.skins[lhs.skin].texture;
                const rhs_tex = ctx.skins[rhs.skin].texture;
                return lhs_tex < rhs_tex;
            }
        }.lt);

        var meshes = std.ArrayList(Mesh).init(rm.allocator);
        defer meshes.deinit();

        if (block.triangles.len > 0) {
            var mesh: *Mesh = undefined;
            var current_texture: u16 = ~@as(u16, 0);

            for (block.triangles) |tris, i| {
                const skin = block.skins[tris.skin];
                const material = loader.level.materials[skin.material];
                if (i == 0 or skin.texture != current_texture) {
                    current_texture = skin.texture;

                    const texture = try loader.textures.getOrPut(skin.texture);

                    if (!texture.found_existing) {
                        texture.value_ptr.* = rm.createTexture(.@"3d", WmbTextureLoader{
                            .level = loader.level,
                            .index = skin.texture,
                        }) catch |err| blk: {
                            std.log.err("failed to decode texture: {s}", .{@errorName(err)});
                            break :blk null;
                        };
                    }

                    mesh = try meshes.addOne();
                    mesh.* = Mesh{
                        .offset = 3 * i,
                        .count = 0,
                        .texture = texture.value_ptr.*,
                    };
                }

                // Phase 1: Fetch the requested vertices
                var face_vertices: [3]Vertex = undefined;
                for (tris.indices) |src_index, j| {
                    const src_vertex = block.vertices[src_index];

                    face_vertices[j] = Vertex{
                        .x = src_vertex.position.x,
                        .y = src_vertex.position.y,
                        .z = src_vertex.position.z,

                        // will be computed in phase 2
                        .nx = undefined,
                        .ny = undefined,
                        .nz = undefined,

                        .u = src_vertex.texture_coord.x,
                        .v = src_vertex.texture_coord.y,
                    };

                    if (loader.level.file_version == .WMB6) {
                        const tex = mesh.texture.?;

                        // WMB6 has implicit texture coordinates via the material
                        // we need to compute the correct UV coordinates here!
                        face_vertices[j].u = (Vector3.dot(vert2pos(face_vertices[j]), mapVec(material.vec_s)) + material.offset_s) / @intToFloat(f32, tex.width - 1);
                        face_vertices[j].v = (Vector3.dot(vert2pos(face_vertices[j]), mapVec(material.vec_t)) + material.offset_t) / @intToFloat(f32, tex.height - 1);
                    }
                }

                // Phase 2: Compute surface normal
                {
                    const p0 = vert2pos(face_vertices[0]);
                    const p1 = vert2pos(face_vertices[1]);
                    const p2 = vert2pos(face_vertices[2]);

                    var p10 = p1.sub(p0).normalize();
                    var p20 = p2.sub(p0).normalize();

                    var n = p20.cross(p10).normalize();

                    normal2vert(&face_vertices[0], n);
                    normal2vert(&face_vertices[1], n);
                    normal2vert(&face_vertices[2], n);
                }

                // Phase 3: Deduplicate vertices
                const indices = data.indices[3 * i ..][0..3];
                for (face_vertices) |dst_vertex, j| {
                    const dst_index = &indices[j];

                    dst_index.* = @intCast(u16, for (vertices.items) |v, k| {
                        if (Vertex.eql(dst_vertex, v, 1.0 / 1024.0, 0.9, 1.0 / 32768.0))
                            break k;
                    } else vertices.items.len);

                    if (dst_index.* == vertices.items.len) {
                        try vertices.append(dst_vertex);
                    }
                }

                mesh.count += 3;
            }
        }
        data.meshes = meshes.toOwnedSlice();
        data.vertices = vertices.toOwnedSlice();

        return data;
    }
};

fn oom() noreturn {
    @panic("out of memory");
}

fn panic(val: anytype) noreturn {
    const T = @TypeOf(val);
    if (T == []const u8)
        @panic(val);

    const info = @typeInfo(T);

    if (info == .Array and info.Array.child == u8) {
        return panic(@as([]const u8, &val));
    }

    if (info == .Pointer and info.Pointer.size == .One) {
        panic(val.*);
        unreachable;
    }

    switch (info) {
        .ErrorSet => {
            if (val == error.OutOfMemory) oom();
            std.debug.panic("unhandled error: {s}", .{@errorName(val)});
            if (@errorReturnTrace()) |err_trace| {
                std.debug.dumpStackTrace(err_trace.*);
            }
        },
        .Enum => std.debug.panic("unhandled error: {s}", .{@tagName(val)}),
        else => std.debug.panic("unhandled error: {any}", .{val}),
    }
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

const BehaviourID = enum(usize) { _ };

fn BehaviourSystem(comptime memory_module: type, comptime Context: type) type {
    return struct {
        const System = @This();

        const Instance = struct {
            update: std.meta.FnPtr(fn (context: Context, node: *Node) void),
            id: BehaviourID,
        };

        pub const List = std.TailQueue(Instance);
        pub const Node = List.Node;

        list: List = .{},

        pub fn attach(instance: *System, context: Context, comptime Behaviour: type) *Behaviour {
            if (instance.behaviour(Behaviour)) |oh_behave|
                return oh_behave;

            const Storage = BehaviourStorage(Behaviour);

            const Updater = struct {
                fn update(ctx: Context, node: *Node) void {
                    if (!@hasDecl(Behaviour, "update"))
                        return;
                    const storage = @fieldParentPtr(Storage, "node", node);
                    // void is used to differentiate between basic and context based update.
                    // as void as a nonsensical value to pass, we can distinct on that.
                    if (Context != void) {
                        Behaviour.update(ctx, &storage.data);
                    } else {
                        Behaviour.update(&storage.data);
                    }
                }
            };

            const storage: *Storage = memory_module.create(Storage);
            storage.* = Storage{
                .node = .{
                    .data = .{
                        .id = Storage.id(),
                        .update = Updater.update,
                    },
                },
                .data = undefined,
            };

            if (@hasDecl(Behaviour, "init")) {
                Behaviour.init(context, &storage.data);
            } else {
                // If no init function is present,
                // we use a default initalization.
                storage.data = Behaviour{};
            }

            instance.list.append(&storage.node);

            return &storage.data;
        }

        pub fn behaviour(instance: *System, comptime Behaviour: type) ?*Behaviour {
            const Storage = BehaviourStorage(Behaviour);

            var it = instance.list.first;
            while (it) |node| : (it = node.next) {
                if (node.data.id == Storage.id()) {
                    return &@fieldParentPtr(Storage, "node", node).data;
                }
            }
            return null;
        }

        pub fn updateAll(instance: *System, context: Context) void {
            var behave_it = instance.list.first;
            while (behave_it) |behave_node| : (behave_it = behave_node.next) {
                behave_node.data.update(context, behave_node);
            }
        }

        pub fn detach(instance: *System, comptime Behaviour: type) void {
            const Storage = BehaviourStorage(Behaviour);

            var it = instance.list;
            while (it) |node| : (it = node.next) {
                if (node.data == Storage.id()) {
                    instance.list.remove(node);

                    const storage = @fieldParentPtr(Storage, "node", node);

                    if (@hasDecl(Behaviour, "deinit")) {
                        storage.data.deinit();
                    }

                    memory_module.destroy(storage);

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

                node: Node,
                data: Behaviour,
            };
        }
    };
}
