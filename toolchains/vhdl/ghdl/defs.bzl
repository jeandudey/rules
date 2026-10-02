load("@prelude//os_lookup:defs.bzl", "OsLookup")
load("//vhdl:vhdl_toolchain.bzl", "VhdlToolchainInfo")
load(":releases.bzl", "DEFAULT_VERSION", "RELEASES")

def _remote_ghdl_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    exec_os = ctx.attrs._exec_os_type[OsLookup]
    platform = "{}-{}".format(exec_os.os.value, exec_os.cpu)
    releases = RELEASES[ctx.attrs.version]
    if platform not in ctx.attrs.distributions or platform not in releases:
        fail("GHDL {} has no release for {}, supported platforms are {}; use `system_vhdl_toolchain` instead".format(
            ctx.attrs.version,
            platform,
            ", ".join(sorted(releases.keys())),
        ))

    distribution = ctx.attrs.distributions[platform][DefaultInfo].default_outputs[0]
    executable = distribution.project(releases[platform]["executable"])
    return [
        DefaultInfo(default_outputs = [distribution]),
        VhdlToolchainInfo(
            simulator = "ghdl",
            compiler = RunInfo(args = cmd_args(executable, hidden = distribution)),
            backend = "mcode",
            analyze_flags = ctx.attrs.analyze_flags,
            elaborate_flags = ctx.attrs.elaborate_flags,
            run_flags = ctx.attrs.run_flags,
        ),
    ]

_remote_ghdl_toolchain = rule(
    impl = _remote_ghdl_toolchain_impl,
    is_toolchain_rule = True,
    doc = """
VHDL toolchain using a GHDL release downloaded by Buck2, the release matching the execution
platform is used. Prefer the `remote_ghdl_toolchain` macro, which declares the downloads.
""",
    attrs = {
        "version": attrs.string(doc = "GHDL release version."),
        "distributions": attrs.dict(
            attrs.string(),
            attrs.exec_dep(),
            doc = "Unpacked GHDL release per `<os>-<cpu>` execution platform.",
        ),
        "analyze_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every analysis."),
        "elaborate_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every elaboration."),
        "run_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every simulation run."),
        "_exec_os_type": attrs.default_only(attrs.exec_dep(default = "prelude//os_lookup/targets:os_lookup")),
    },
)

def remote_ghdl_toolchain(
        name: str,
        version: str = DEFAULT_VERSION,
        visibility: list[str] = [],
        **kwargs):
    """
    Declares a VHDL toolchain named `name` using a GHDL mcode release downloaded from GitHub,
    along with one `http_archive` per platform the release supports. Only the archive for the
    execution platform is downloaded. `version` defaults to the latest known release.
    """
    if version not in RELEASES:
        fail("GHDL {} is not a known release, known releases are {}".format(
            version,
            ", ".join(RELEASES.keys()),
        ))

    distributions = {}
    for platform, release in RELEASES[version].items():
        archive = "{}_ghdl_{}".format(name, platform)
        native.http_archive(
            name = archive,
            urls = [release["url"]],
            sha256 = release["sha256"],
            strip_prefix = release["strip_prefix"],
        )
        distributions[platform] = ":" + archive

    _remote_ghdl_toolchain(
        name = name,
        version = version,
        distributions = distributions,
        visibility = visibility,
        **kwargs
    )
