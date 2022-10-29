const std = @import("std");
const eng = @import("zyclone");

pub fn main() !void {
    _ = eng.attach(Interface);
}

pub const Interface = struct {
    var snd: *eng.Sound = undefined;

    pub fn init(_: *Interface) void {
        snd = eng.Sound.load("ribanna.mid");
    }

    pub fn update(_: *Interface) void {
        if (eng.key.pressed(.escape))
            eng.exit();

        if (eng.key.pressed(.space))
            _ = snd.play();
    }
};
