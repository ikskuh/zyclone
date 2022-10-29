const std = @import("std");
const eng = @import("zyclone");

pub fn main() !void {
    eng.DefaultCamera.vel_slow = 64.0;
    eng.DefaultCamera.vel_high = 256.0;

    eng.level.load("levels/physics.wmb");

    // eng.level.load("levels/import-test/flagtest.wmb");
    // eng.level.load("levels/import-test/regions.wmb");
    // eng.level.load("levels/import-test/lights.wmb");
    // eng.level.load("levels/import-test/paths.wmb");

    _ = eng.attach(eng.DefaultCamera);
    _ = eng.attach(eng.DebugPanels);

    // eng.camera.pos.z = 10;

    // eng.level.load("levels/future/doorlft1.wmb");
    // eng.level.load("levels/wmb6-demo.wmb");

    // _ = eng.entity.create("terrain.z3d", eng.nullvector, null);

    // _ = eng.entity.create("levels/test.wmb", eng.vector(0, 0, 0), _actions.Spinner);
    // _ = eng.entity.create("levels/future/sign+5.tga", eng.vector(0, 0, 0), null);

    // const sprite = eng.entity.create("levels/future/arrows.tga", eng.vector(0, 0, 0), _actions.Spinner);
    // sprite.scale = eng.Vector3.all(0.01);

    // _ = player.attach(_actions.YBouncer);

    // var i: usize = 0;
    // while (i < 10) : (i += 1) {
    //     std.log.info("i = {}", .{i});
    //     eng.waitForFrame();
    // }

    const ball = eng.Entity.create("3ball.mdl", eng.vector(0, 3, 0), Kicker);
    // ball.scale = eng.Vector3.all(1.0 / 16.0);
    ball.setPhysicsType(.rigid, .sphere);
}

const Kicker = struct {
    pub fn update(ent: *eng.Entity, _: *@This()) void {
        const kick = eng.ui.button(
            .{ .x = 10, .y = 300, .width = 100, .height = 30 },
            "Kick me",
            null,
            .{},
        );

        if (eng.key.pressed(.space) or kick) {
            var kick_dir = eng.vec.forAngle(.{ .pan = eng.camera.rot.pan, .tilt = 0, .roll = 0 });
            kick_dir.y = 0.7;
            ent.addForceCentral(kick_dir.scale(1500000));
        }
    }
};

/// Exposing a global namespace "actions"
/// will allow the engine to actually instantiate
/// these actions in entities loaded from a level.
/// Every pub structure in here can be loaded.
pub const actions = struct {
    pub const Player = struct {
        health: u32 = 100,
        shield: u32 = 0,

        pub fn init(ent: *eng.Entity, p: *Player) void {
            p.* = Player{};
            ent.scale.y = 0.1;
            ent.scale.z = 0.1;
        }

        pub fn update(ent: *eng.Entity, p: *Player) void {
            _ = p;
            ent.rot.pan += 10.0 * eng.time.step;
        }
    };

    pub const YBouncer = struct {
        pub fn update(ent: *eng.Entity, _: *YBouncer) void {
            ent.pos.y = 3.0 * @sin(eng.time.total);
        }
    };

    pub const Spinner = struct {
        pub fn update(ent: *eng.Entity, _: *Spinner) void {
            ent.rot.pan += 10.0 * eng.time.step;
        }
    };
};
