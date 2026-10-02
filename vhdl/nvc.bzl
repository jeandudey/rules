load("@prelude//:paths.bzl", "paths")
load(":launcher.bzl", "project_root_launcher")
load(":vhdl_info.bzl", "VhdlLibrary", "VhdlLibraryTSet")
load(":vhdl_toolchain.bzl", "VhdlToolchainInfo")

_STANDARDS = {
    "93": "1993",
    "93c": "1993",
    "00": "2000",
    "02": "2002",
    "08": "2008",
    "19": "2019",
}

def _standard_arg(ctx: AnalysisContext, standard: str) -> str:
    if standard not in _STANDARDS:
        fail("{} uses VHDL standard `{}` which NVC does not support".format(ctx.label.raw_target(), standard))
    return "--std=" + _STANDARDS[standard]

def _library_arg(option: str, name: str, directory: Artifact | OutputArtifact) -> cmd_args:
    return cmd_args(directory, format = "--{}={}:{{}}".format(option, name))

def _map_args(libraries: VhdlLibraryTSet, work: str) -> list[cmd_args]:
    return [
        _library_arg("map", library.name, library.library_file)
        for library in libraries.traverse()
        if library.name.lower() != work.lower()
    ]

def nvc_analyze(
        ctx: AnalysisContext,
        toolchain: VhdlToolchainInfo,
        name: str,
        standard: str,
        srcs: list[Artifact],
        deps: VhdlLibraryTSet,
        flags: list[str]) -> VhdlLibrary:
    library_dir = ctx.actions.declare_output(paths.join("nvc_library", name.lower()), dir = True)
    ctx.actions.run(
        cmd_args(
            toolchain.compiler,
            _standard_arg(ctx, standard),
            "--ignore-time",
            _map_args(deps, name),
            _library_arg("work", name, library_dir.as_output()),
            "-a",
            toolchain.analyze_flags,
            flags,
            srcs,
        ),
        category = "nvc_analyze",
        identifier = name,
    )
    return VhdlLibrary(
        name = name,
        standard = standard,
        library_file = library_dir,
        objects = [],
        srcs = srcs,
    )

def nvc_executable(
        ctx: AnalysisContext,
        toolchain: VhdlToolchainInfo,
        library: VhdlLibrary,
        libraries: VhdlLibraryTSet,
        top: str,
        generics: dict[str, str],
        run_args: list[str],
        stop_on_error: bool) -> (cmd_args, list[Artifact]):
    return cmd_args(
        project_root_launcher(ctx),
        toolchain.compiler,
        _standard_arg(ctx, library.standard),
        "--ignore-time",
        _map_args(libraries, library.name),
        _library_arg("work", library.name, library.library_file),
        "-e",
        "--jit",
        "--no-save",
        ["-g{}={}".format(generic, value) for generic, value in generics.items()],
        toolchain.elaborate_flags,
        top,
        "-r",
        "--exit-severity=" + ("error" if stop_on_error else "failure"),
        toolchain.run_flags,
        run_args,
        hidden = libraries.project_as_args("inputs"),
    ), [library.library_file]
