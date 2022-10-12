const std = @import("std");
const eng = @import("basegame");

pub const engine_verification_export = eng;

pub fn main() !void {
    eng.level.load("foo.wmb");

    _ = eng.attach(GameLoop);

    _ = eng.entity.create("terrain.z3d", eng.nullvector, null);

    const player = eng.entity.create("cube.z3d", eng.vector(0, 0, -10), Player);

    _ = player.attach(YBouncer);

    // var i: usize = 0;
    // while (i < 10) : (i += 1) {
    //     std.log.info("i = {}", .{i});
    //     eng.waitForFrame();
    // }

    // return error.Poop;
}

const GameLoop = struct {
    pub fn update(_: *GameLoop) void {
        if (eng.key.pressed(.escape))
            eng.exit();

        if (eng.key.held(.left))
            eng.camera.rot.pan += 90 * eng.time.step;
        if (eng.key.held(.right))
            eng.camera.rot.pan -= 90 * eng.time.step;
        if (eng.key.held(.page_up))
            eng.camera.rot.tilt -= 90 * eng.time.step;
        if (eng.key.held(.page_down)) {
            eng.camera.rot.tilt += 90 * eng.time.step;
        }

        if (eng.mouse.held(.secondary)) {
            eng.camera.rot.pan -= @intToFloat(f32, eng.mouse.delta.x);
            eng.camera.rot.tilt += @intToFloat(f32, eng.mouse.delta.y);
        }

        const fwd = eng.vec.forAngle(eng.camera.rot).scale(10.0 * eng.time.step);
        const left = eng.vec.rotate(eng.vector(1, 0, 0), eng.camera.rot).scale(10.0 * eng.time.step);

        if (eng.key.held(.up) or (eng.mouse.held(.secondary) and eng.key.held(.w)))
            eng.camera.pos = eng.camera.pos.add(fwd);
        if (eng.key.held(.down) or (eng.mouse.held(.secondary) and eng.key.held(.s)))
            eng.camera.pos = eng.camera.pos.sub(fwd);

        if (eng.mouse.held(.secondary) and eng.key.held(.a))
            eng.camera.pos = eng.camera.pos.add(left);
        if (eng.mouse.held(.secondary) and eng.key.held(.d))
            eng.camera.pos = eng.camera.pos.sub(left);
    }
};

const Player = struct {
    health: u32 = 100,
    shield: u32 = 0,

    pub fn init(ent: *eng.Entity, p: *Player) void {
        p.* = Player{};
        ent.scale.x = 10;
    }

    pub fn update(ent: *eng.Entity, p: *Player) void {
        _ = p;
        ent.rot.pan += eng.time.step;
    }
};

const YBouncer = struct {
    pub fn update(ent: *eng.Entity, _: *YBouncer) void {
        ent.pos.y = 3.0 * @sin(eng.time.total);
    }
};
