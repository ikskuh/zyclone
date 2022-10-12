const std = @import("std");
const eng = @import("basegame");

pub const engine_verification_export = eng;

pub fn main() !void {
    eng.level.load("foo.wmb");
    _ = eng.entity.create("player.mdl", eng.vector(0, 0, 0), Player);

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

    fn init(ent: *eng.Entity, p: *Player) void {
        p.* = Player{};
        ent.scale.x = 10;
    }

    fn update(ent: *eng.Entity, p: *Player) void {
        _ = p;
        ent.rot.pan += eng.time.step;
    }
};
