const std = @import("std");
const zpm = @import("zpm.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const sdk = zpm.sdks.@"zero-graphics".init(b, false);

    const app = sdk.createApplication("3rd_person", "src/entrypoint.zig");
    app.setBuildMode(mode);

    app.addPackage(zpm.pkgs.zlm);
    app.addPackage(std.build.Pkg{
        .name = "@GAME@",
        .source = .{ .path = "demo/3rd-person.zig" },
        .dependencies = &.{std.build.Pkg{
            .name = "basegame",
            .source = .{ .path = "src/package.zig" },
        }},
    });

    const instance = app.compileFor(.{ .desktop = target });
    instance.install();

    const run_cmd = instance.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
