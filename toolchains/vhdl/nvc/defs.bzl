load("@prelude//os_lookup:defs.bzl", "OsLookup")
load("//vhdl:vhdl_toolchain.bzl", "VhdlToolchainInfo")
load(":releases.bzl", "DEFAULT_VERSION", "RELEASES")

def _unpack_deb(ctx: AnalysisContext, package: Artifact, distribution: Artifact):
    ctx.actions.run(
        cmd_args("dpkg-deb", "-x", package, distribution.as_output()),
        category = "nvc_unpack",
    )

def _unpack_msi(ctx: AnalysisContext, package: Artifact, distribution: Artifact):
    script = ctx.actions.write(
        "nvc_unpack.bat",
        [
            "@echo off",
            "mkdir \"%~f2\"",
            "msiexec /a \"%~f1\" /qn TARGETDIR=\"%~f2\"",
            "exit /b %ERRORLEVEL%",
        ],
        is_executable = True,
    )
    ctx.actions.run(
        cmd_args(script, package, distribution.as_output()),
        category = "nvc_unpack",
    )

_UNPACK = {
    "deb": _unpack_deb,
    "msi": _unpack_msi,
}

def _remote_nvc_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    exec_os = ctx.attrs._exec_os_type[OsLookup]
    platform = "{}-{}".format(exec_os.os.value, exec_os.cpu)
    releases = RELEASES[ctx.attrs.version]
    if platform not in ctx.attrs.packages or platform not in releases:
        fail("NVC {} has no release for {}, supported platforms are {}; use `system_vhdl_toolchain` instead".format(
            ctx.attrs.version,
            platform,
            ", ".join(sorted(releases.keys())),
        ))

    release = releases[platform]
    package = ctx.attrs.packages[platform][DefaultInfo].default_outputs[0]
    distribution = ctx.actions.declare_output("nvc", dir = True)
    _UNPACK[release["format"]](ctx, package, distribution)

    library_path = release["library_path"]
    return [
        DefaultInfo(default_outputs = [distribution]),
        VhdlToolchainInfo(
            simulator = "nvc",
            compiler = RunInfo(args = cmd_args(
                distribution.project(release["executable"]),
                ["-L", distribution.project(library_path)] if library_path else [],
                hidden = distribution,
            )),
            analyze_flags = ctx.attrs.analyze_flags,
            elaborate_flags = ctx.attrs.elaborate_flags,
            run_flags = ctx.attrs.run_flags,
        ),
    ]

_remote_nvc_toolchain = rule(
    impl = _remote_nvc_toolchain_impl,
    is_toolchain_rule = True,
    doc = """
VHDL toolchain using an NVC release downloaded by Buck2, the release matching the execution
platform is used. Prefer the `remote_nvc_toolchain` macro, which declares the downloads.
""",
    attrs = {
        "version": attrs.string(doc = "NVC release version."),
        "packages": attrs.dict(
            attrs.string(),
            attrs.exec_dep(),
            doc = "NVC release package per `<os>-<cpu>` execution platform.",
        ),
        "analyze_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every analysis."),
        "elaborate_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every elaboration."),
        "run_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every simulation run."),
        "_exec_os_type": attrs.default_only(attrs.exec_dep(default = "prelude//os_lookup/targets:os_lookup")),
    },
)

def remote_nvc_toolchain(
        name: str,
        version: str = DEFAULT_VERSION,
        visibility: list[str] = [],
        **kwargs):
    """
    Declares a VHDL toolchain named `name` using an NVC release downloaded from GitHub, along
    with one `http_file` per platform the release supports. Only the package for the execution
    platform is downloaded and unpacked. `version` defaults to the latest known release.
    """
    if version not in RELEASES:
        fail("NVC {} is not a known release, known releases are {}".format(
            version,
            ", ".join(RELEASES.keys()),
        ))

    packages = {}
    for platform, release in RELEASES[version].items():
        package = "{}_nvc_{}".format(name, platform)
        native.http_file(
            name = package,
            urls = [release["url"]],
            sha256 = release["sha256"],
        )
        packages[platform] = ":" + package

    _remote_nvc_toolchain(
        name = name,
        version = version,
        packages = packages,
        visibility = visibility,
        **kwargs
    )
