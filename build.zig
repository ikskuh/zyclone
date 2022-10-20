const std = @import("std");
const zpm = @import("zpm.zig");

pub fn build(b: *std.build.Builder) void {
    const use_android = b.option(bool, "android", "Enable the android SDK") orelse false;

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const sdk = zpm.sdks.@"zero-graphics".init(b, use_android);

    const ode = zpm.sdks.ode.init(b);
    const ode_config = zpm.sdks.ode.Config{
        .index_size = .u16,
        .no_builtin_threading_impl = true,
        .no_threading_intf = true,
        .trimesh = .opcode,
        .libccd = null,
        .ou = false,
        .precision = .single,
    };

    const app = sdk.createApplication("3rd_person", "src/entrypoint.zig");
    app.setDisplayName("Acknex Clone");
    app.setPackageName("net.random_projects.games.acknex_clone");
    app.setBuildMode(mode);

    // app.enable_code_editor = false;

    app.addPackage(zpm.pkgs.zlm);
    app.addPackage(zpm.pkgs.libgamestudio);
    app.addPackage(ode.getPackage("ode", ode_config));
    app.addPackage(std.build.Pkg{
        .name = "@GAME@",
        .source = .{ .path = "demo/future.zig" },
        .dependencies = &.{std.build.Pkg{
            .name = "basegame",
            .source = .{ .path = "src/package.zig" },
        }},
    });

    const instance = app.compileFor(.{ .desktop = target });
    ode.linkTo(instance.data.desktop, .static, ode_config);
    instance.install();

    if (use_android) {
        const android_app = app.compileFor(.android);

        const android_step = b.step("app", "Builds the android app");

        android_step.dependOn(android_app.getStep());
    }

    const run_cmd = instance.run();
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.cwd = "demo";
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
