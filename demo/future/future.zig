const std = @import("std");
const eng = @import("basegame");

pub fn main() !void {
    eng.DefaultCamera.vel_slow = 64.0;
    eng.DefaultCamera.vel_high = 256.0;

    eng.level.load("future.wmb");

    _ = eng.attach(eng.DefaultCamera);
    _ = eng.attach(eng.DebugPanels);

    eng.camera.pos.y = 64;
}

/// Exposing a global namespace "actions"
/// will allow the engine to actually instantiate
/// these actions in entities loaded from a level.
/// Every pub structure in here can be loaded.
pub const actions = struct {
    /// Appears to be some kind of blinking light action
    pub const FXA_LightBlink = struct {
        pub fn init(ent: *eng.Entity, _: *@This()) void {
            ent.flags.visible = false;
        }
        pub fn update(ent: *eng.Entity, _: *@This()) void {
            _ = ent;
        }
    };

    /// The spawn point, attached to the sprite.
    pub const a = struct {
        pub fn init(ent: *eng.Entity, _: *@This()) void {
            _ = ent;
        }
        pub fn update(ent: *eng.Entity, _: *@This()) void {
            _ = ent;
        }
    };

    /// The "ga"te to the crystal in the teleporter room.
    /// Attached directly to the sprite.
    pub const ga = struct {
        pub fn update(ent: *eng.Entity, _: *@This()) void {
            _ = ent;
        }
    };

    /// - The trigger that opens the door to the final room
    pub const @".wmb" = struct {
        pub fn init(ent: *eng.Entity, _: *@This()) void {
            ent.flags.visible = false;
        }
        pub fn update(ent: *eng.Entity, _: *@This()) void {
            _ = ent;
        }
    };
};
