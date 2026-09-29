load(":vhdl_info.bzl", "VhdlLibrary", "VhdlLibraryTSet")
load(":vhdl_library.bzl", "vhdl_analysis_attrs", "vhdl_analyze")
load(":vhdl_simulator.bzl", "vhdl_simulator")
load(":vhdl_toolchain.bzl", "VhdlToolchainInfo")

vhdl_executable_attrs = vhdl_analysis_attrs | {
    "top": attrs.string(
        doc = """
Top level design unit to elaborate. Units from `srcs` are referenced by name, units from a
dependency are referenced as `library.unit`.
""",
    ),
    "generics": attrs.dict(
        attrs.string(),
        attrs.string(),
        default = {},
        doc = "Values for the generics of `top`.",
    ),
    "run_args": attrs.list(
        attrs.string(),
        default = [],
        doc = "Extra simulator flags used when running the simulation.",
    ),
    "_target_os_type": attrs.default_only(attrs.dep(default = "prelude//os_lookup/targets:os_lookup")),
}

def _top_library(ctx: AnalysisContext, library: VhdlLibrary | None, libraries: VhdlLibraryTSet) -> (VhdlLibrary, str):
    if "." not in ctx.attrs.top:
        if library == None:
            fail("{} has no `srcs`, `top` must be written as `library.unit`".format(ctx.label.raw_target()))
        return library, ctx.attrs.top

    library_name, unit = ctx.attrs.top.split(".", 1)
    for candidate in libraries.traverse():
        if candidate.name.lower() == library_name.lower():
            return candidate, unit
    fail("{} has no library named `{}`".format(ctx.label.raw_target(), library_name))

def vhdl_executable(ctx: AnalysisContext, stop_on_error: bool) -> (cmd_args, list[Artifact]):
    """
    Analyzes `srcs` and returns the command that simulates `top` along with the outputs needed
    to run it. When `stop_on_error` is set assertions of `error` severity end the simulation with
    a failure exit code.
    """
    toolchain = ctx.attrs._vhdl_toolchain[VhdlToolchainInfo]
    library, libraries = vhdl_analyze(ctx)
    top_library, top = _top_library(ctx, library, libraries)
    return vhdl_simulator(toolchain).executable(
        ctx,
        toolchain,
        top_library,
        libraries,
        top,
        ctx.attrs.generics,
        ctx.attrs.run_args,
        stop_on_error,
    )

def _vhdl_binary_impl(ctx: AnalysisContext) -> list[Provider]:
    args, outputs = vhdl_executable(ctx, stop_on_error = False)
    return [
        DefaultInfo(default_outputs = outputs),
        RunInfo(args = args),
    ]

vhdl_binary = rule(
    impl = _vhdl_binary_impl,
    doc = "Elaborates a VHDL design and simulates it when run.",
    attrs = vhdl_executable_attrs,
)
