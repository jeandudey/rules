load("@prelude//:paths.bzl", "paths")
load("@prelude//os_lookup:defs.bzl", "OsLookup", "ScriptLanguage")
load(":vhdl_info.bzl", "VhdlLibrary", "VhdlLibraryTSet")
load(":vhdl_toolchain.bzl", "VhdlToolchainInfo")

_LIBRARY_FILE_SUFFIXES = {
    "87": "87",
    "93": "93",
    "93c": "93",
    "00": "93",
    "02": "93",
    "08": "08",
    "19": "19",
}

_SOURCE_DIRECTORY_PREFIX = "file \""

def _library_file_name(name: str, standard: str) -> str:
    return "{}-obj{}.cf".format(name.lower(), _LIBRARY_FILE_SUFFIXES[standard])

def _relocatable_library_file(content: str) -> str:
    lines = []
    for line in content.splitlines():
        if line.startswith(_SOURCE_DIRECTORY_PREFIX):
            directory_end = line.index("\"", len(_SOURCE_DIRECTORY_PREFIX))
            line = _SOURCE_DIRECTORY_PREFIX + "\"" + line[directory_end + 1:]
        lines.append(line)
    return "\n".join(lines) + "\n"

def _relocate_library_file_impl(actions: AnalysisActions, analyzed: ArtifactValue, library_file: OutputArtifact) -> list[Provider]:
    actions.write(library_file, _relocatable_library_file(analyzed.read_string()))
    return []

_relocate_library_file = dynamic_actions(
    impl = _relocate_library_file_impl,
    attrs = {
        "analyzed": dynattrs.artifact_value(),
        "library_file": dynattrs.output(),
    },
)

def _workdir_arg(library: VhdlLibrary) -> cmd_args:
    return cmd_args(library.library_file, format = "--workdir={}", parent = 1)

def ghdl_analyze(
        ctx: AnalysisContext,
        toolchain: VhdlToolchainInfo,
        name: str,
        standard: str,
        srcs: list[Artifact],
        deps: VhdlLibraryTSet,
        flags: list[str]) -> VhdlLibrary:
    file_name = _library_file_name(name, standard)
    analysis_dir = paths.join("ghdl_analysis", name)
    library_dir = paths.join("ghdl_library", name)

    analyzed = ctx.actions.declare_output(paths.join(analysis_dir, file_name))
    analyzed_objects = []
    if toolchain.backend != "mcode":
        analyzed_objects = [
            ctx.actions.declare_output(paths.join(analysis_dir, paths.split_extension(src.basename)[0] + ".o"))
            for src in srcs
        ]

    ctx.actions.run(
        cmd_args(
            toolchain.compiler,
            "-a",
            "--std=" + standard,
            "--work=" + name,
            cmd_args(analyzed.as_output(), format = "--workdir={}", parent = 1),
            deps.project_as_args("include"),
            toolchain.analyze_flags,
            flags,
            srcs,
            hidden = [obj.as_output() for obj in analyzed_objects],
        ),
        category = "ghdl_analyze",
        identifier = name,
    )

    library_file = ctx.actions.declare_output(paths.join(library_dir, file_name))
    ctx.actions.dynamic_output_new(_relocate_library_file(
        analyzed = analyzed,
        library_file = library_file.as_output(),
    ))

    objects = [
        ctx.actions.symlink_file(paths.join(library_dir, obj.basename), obj)
        for obj in analyzed_objects
    ]

    return VhdlLibrary(
        name = name,
        standard = standard,
        library_file = library_file,
        objects = objects,
        srcs = srcs,
    )

def _project_root_launcher(ctx: AnalysisContext) -> Artifact:
    if ctx.attrs._target_os_type[OsLookup].script == ScriptLanguage("bat"):
        launcher = ctx.actions.declare_output("ghdl_launcher.bat")
        content = cmd_args(
            "@echo off",
            cmd_args("cd /d \"%~dp0", ctx.label.project_root, "\"", delimiter = ""),
            "%*",
            "exit /b %ERRORLEVEL%",
            relative_to = (launcher, 1),
        )
    else:
        launcher = ctx.actions.declare_output("ghdl_launcher.sh")
        content = cmd_args(
            "#!/bin/sh",
            cmd_args("cd \"$(dirname \"$0\")/", ctx.label.project_root, "\" || exit 1", delimiter = ""),
            "exec \"$@\"",
            relative_to = (launcher, 1),
        )
    ctx.actions.write(launcher, content, is_executable = True)
    return launcher

def ghdl_executable(
        ctx: AnalysisContext,
        toolchain: VhdlToolchainInfo,
        library: VhdlLibrary,
        libraries: VhdlLibraryTSet,
        top: str,
        generics: dict[str, str],
        run_args: list[str],
        stop_on_error: bool) -> (cmd_args, list[Artifact]):
    design_args = cmd_args(
        "--std=" + library.standard,
        "--work=" + library.name,
        _workdir_arg(library),
        libraries.project_as_args("include"),
        toolchain.elaborate_flags,
    )
    simulation_args = cmd_args(
        ["-g{}={}".format(generic, value) for generic, value in generics.items()],
        ["--assert-level=error"] if stop_on_error else [],
        toolchain.run_flags,
        run_args,
    )

    if toolchain.backend == "mcode":
        return cmd_args(
            _project_root_launcher(ctx),
            toolchain.compiler,
            "-r",
            design_args,
            top,
            simulation_args,
            hidden = libraries.project_as_args("inputs"),
        ), [library.library_file]

    executable = ctx.actions.declare_output(paths.join("ghdl_executable", top))
    ctx.actions.run(
        cmd_args(
            toolchain.compiler,
            "-e",
            design_args,
            "-o",
            executable.as_output(),
            top,
            hidden = libraries.project_as_args("inputs"),
        ),
        category = "ghdl_elaborate",
        identifier = top,
    )
    return cmd_args(executable, simulation_args), [executable]
