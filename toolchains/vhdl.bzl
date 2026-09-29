load("@prelude//os_lookup:defs.bzl", "OsLookup")
load("//vhdl:ghdl_releases.bzl", "GHDL_DEFAULT_VERSION", "GHDL_RELEASES")
load("//vhdl:vhdl_toolchain.bzl", "VHDL_GHDL_BACKENDS", "VHDL_SIMULATORS", "VhdlToolchainInfo")

_FLAG_ATTRS = {
    "analyze_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every analysis."),
    "elaborate_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every elaboration."),
    "run_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every simulation run."),
}

_DOWNLOADABLE_RELEASES = {
    "ghdl": GHDL_RELEASES,
}

_DOWNLOADABLE_DEFAULT_VERSIONS = {
    "ghdl": GHDL_DEFAULT_VERSION,
}

def _vhdl_toolchain_info(ctx: AnalysisContext, compiler: RunInfo, backend: str | None) -> VhdlToolchainInfo:
    return VhdlToolchainInfo(
        simulator = ctx.attrs.simulator,
        compiler = compiler,
        backend = backend,
        analyze_flags = ctx.attrs.analyze_flags,
        elaborate_flags = ctx.attrs.elaborate_flags,
        run_flags = ctx.attrs.run_flags,
    )

def _system_vhdl_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        _vhdl_toolchain_info(ctx, RunInfo(args = [ctx.attrs.compiler]), ctx.attrs.backend),
    ]

system_vhdl_toolchain = rule(
    impl = _system_vhdl_toolchain_impl,
    is_toolchain_rule = True,
    doc = "VHDL toolchain using a simulator installed on the system and found through `PATH`.",
    attrs = _FLAG_ATTRS | {
        "simulator": attrs.enum(VHDL_SIMULATORS, default = "ghdl", doc = "Simulator to use."),
        "compiler": attrs.string(default = "ghdl", doc = "Simulator executable name or path."),
        "backend": attrs.enum(
            VHDL_GHDL_BACKENDS,
            default = "mcode",
            doc = "GHDL code generator the executable was built with.",
        ),
    },
)

def __remote_vhdl_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    exec_os = ctx.attrs._exec_os_type[OsLookup]
    platform = "{}-{}".format(exec_os.os.value, exec_os.cpu)
    releases = _DOWNLOADABLE_RELEASES[ctx.attrs.simulator][ctx.attrs.version]
    if platform not in ctx.attrs.distributions or platform not in releases:
        fail("{} {} has no release for {}, supported platforms are {}; use `system_vhdl_toolchain` instead".format(
            ctx.attrs.simulator,
            ctx.attrs.version,
            platform,
            ", ".join(sorted(releases.keys())),
        ))

    distribution = ctx.attrs.distributions[platform][DefaultInfo].default_outputs[0]
    executable = distribution.project(releases[platform]["executable"])
    return [
        DefaultInfo(default_outputs = [distribution]),
        _vhdl_toolchain_info(ctx, RunInfo(args = cmd_args(executable, hidden = distribution)), "mcode"),
    ]

_remote_vhdl_toolchain = rule(
    impl = __remote_vhdl_toolchain_impl,
    is_toolchain_rule = True,
    doc = """
VHDL toolchain using a simulator release downloaded by Buck2, the release matching the execution
platform is used. Prefer the `remote_vhdl_toolchain` macro, which declares the downloads.
""",
    attrs = _FLAG_ATTRS | {
        "simulator": attrs.enum(_DOWNLOADABLE_RELEASES.keys(), default = "ghdl", doc = "Simulator to use."),
        "version": attrs.string(doc = "Simulator release version."),
        "distributions": attrs.dict(
            attrs.string(),
            attrs.exec_dep(),
            doc = "Unpacked simulator release per `<os>-<cpu>` execution platform.",
        ),
        "_exec_os_type": attrs.default_only(attrs.exec_dep(default = "prelude//os_lookup/targets:os_lookup")),
    },
)

def remote_vhdl_toolchain(
        name: str,
        simulator: str = "ghdl",
        version: str | None = None,
        visibility: list[str] = [],
        **kwargs):
    """
    Declares a `_remote_vhdl_toolchain` named `name` along with one `http_archive` per
    platform the simulator release supports. Only the archive for the execution platform is
    downloaded. `version` defaults to the latest known release of `simulator`.
    """
    if simulator not in _DOWNLOADABLE_RELEASES:
        fail("`{}` has no downloadable releases, supported simulators are {}".format(
            simulator,
            ", ".join(_DOWNLOADABLE_RELEASES.keys()),
        ))
    version = version or _DOWNLOADABLE_DEFAULT_VERSIONS[simulator]
    releases = _DOWNLOADABLE_RELEASES[simulator]
    if version not in releases:
        fail("{} {} is not a known release, known releases are {}".format(
            simulator,
            version,
            ", ".join(releases.keys()),
        ))

    distributions = {}
    for platform, release in releases[version].items():
        archive = "{}_{}_{}".format(name, simulator, platform)
        native.http_archive(
            name = archive,
            urls = [release["url"]],
            sha256 = release["sha256"],
            strip_prefix = release["strip_prefix"],
        )
        distributions[platform] = ":" + archive

    _remote_vhdl_toolchain(
        name = name,
        simulator = simulator,
        version = version,
        distributions = distributions,
        visibility = visibility,
        **kwargs
    )
