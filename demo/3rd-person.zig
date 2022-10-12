const std = @import("std");
const eng = @import("basegame");

pub const engine_verification_export = eng;

pub fn main() !void {
    eng.level.load("foo.wmb");
    _ = eng.entity.create("player.mdl", eng.vector(0, 0, 0), Player);

    _ = eng.attach(GameLoop);

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
