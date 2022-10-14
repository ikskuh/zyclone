const std = @import("std");
const eng = @import("basegame");

pub fn main() !void {
    eng.level.load("levels/test.wmb");

    _ = eng.attach(eng.DefaultCamera);

    // _ = eng.entity.create("terrain.z3d", eng.nullvector, null);

    const player = eng.entity.create("cube.z3d", eng.vector(0, 0, -10), Player);
    _ = player.attach(YBouncer);

    // var i: usize = 0;
    // while (i < 10) : (i += 1) {
    //     std.log.info("i = {}", .{i});
    //     eng.waitForFrame();
    // }

    // return error.Poop;
}

const Player = struct {
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

const YBouncer = struct {
    pub fn update(ent: *eng.Entity, _: *YBouncer) void {
        ent.pos.y = 3.0 * @sin(eng.time.total);
    }
};
