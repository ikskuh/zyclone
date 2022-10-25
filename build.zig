const std = @import("std");
const zpm = @import("zpm.zig");

const ode_config = zpm.sdks.ode.Config{
    .index_size = .u16,
    .no_builtin_threading_impl = true,
    .no_threading_intf = true,
    .trimesh = .opcode,
    .libccd = null,
    .ou = false,
    .precision = .single,
};

const Options = struct {
    android: bool,
    web: bool,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
};

pub fn compileGame(zg: *zpm.sdks.@"zero-graphics", ode: *zpm.sdks.ode, file_name: []const u8, display_name: []const u8, source_file: []const u8, options: Options) void {
    const app = zg.createApplication(file_name, "src/entrypoint.zig");
    app.setDisplayName(display_name);
    app.setPackageName(zg.builder.fmt("net.random_projects.games.{s}", .{file_name}));
    app.setBuildMode(options.mode);

    // app.enable_code_editor = false;

    app.addPackage(zpm.pkgs.zlm);
    app.addPackage(zpm.pkgs.libgamestudio);
    app.addPackage(ode.getPackage("ode", ode_config));
    app.addPackage(std.build.Pkg{
        .name = "@GAME@",
        .source = .{ .path = source_file },
        .dependencies = &.{std.build.Pkg{
            .name = "basegame",
            .source = .{ .path = "src/package.zig" },
        }},
    });

    const instance = app.compileFor(.{ .desktop = options.target });
    ode.linkTo(instance.data.desktop, .static, ode_config);
    instance.install();

    if (options.android) {
        const android_app = app.compileFor(.android);
        android_app.install();
    }
}

pub fn build(b: *std.build.Builder) void {
    const use_android = b.option(bool, "android", "Enable the android SDK") orelse false;

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const sdk = zpm.sdks.@"zero-graphics".init(b, use_android);
    const ode = zpm.sdks.ode.init(b);

    const opts = Options{
        .android = use_android,
        .web = false,
        .target = target,
        .mode = mode,
    };

    compileGame(sdk, ode, "future_demo", "Zyclone Future Demo", "demo/future/future.zig", opts);
    compileGame(sdk, ode, "playground", "Zyclone Developer Playground", "demo/playground.zig", opts);
}
