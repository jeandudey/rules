load("//vhdl:vhdl_info.bzl", "VhdlLibrary", "VhdlLibraryInfo", "VhdlLibraryTSet")
load(":yosys_info.bzl", "YOSYS_NETLIST_FORMATS", "YosysNetlistInfo")
load(":yosys_toolchain.bzl", "YosysToolchainInfo")

_WRITE_COMMANDS = {
    "json": ("write_json", "json"),
    "verilog": ("write_verilog", "v"),
    "blif": ("write_blif", "blif"),
    "edif": ("write_edif", "edif"),
    "rtlil": ("write_rtlil", "il"),
}

def _vhdl_libraries(ctx: AnalysisContext) -> list[VhdlLibrary]:
    libraries = ctx.actions.tset(
        VhdlLibraryTSet,
        children = [dep[VhdlLibraryInfo].tset for dep in ctx.attrs.deps],
    )
    return list(libraries.traverse(ordering = "postorder"))

def _vhdl_standard(ctx: AnalysisContext, libraries: list[VhdlLibrary]) -> str:
    standards = {library.standard: None for library in libraries}
    if len(standards) != 1:
        fail("{} depends on VHDL libraries using different standards: {}".format(
            ctx.label.raw_target(),
            ", ".join(sorted(standards.keys())),
        ))
    return libraries[0].standard

def _vhdl_unit(ctx: AnalysisContext, libraries: list[VhdlLibrary], unit: str) -> (str, str):
    if "." not in unit:
        if len(ctx.attrs.deps) != 1:
            fail("{} has several VHDL dependencies, `{}` must be written as `library.unit`".format(
                ctx.label.raw_target(),
                unit,
            ))
        return ctx.attrs.deps[0][VhdlLibraryInfo].library.name, unit

    library_name, unit_name = unit.split(".", 1)
    for library in libraries:
        if library.name.lower() == library_name.lower():
            return library.name, unit_name
    fail("{} has no VHDL library named `{}`".format(ctx.label.raw_target(), library_name))

def _vhdl_units(ctx: AnalysisContext) -> list[str]:
    if ctx.attrs.vhdl_units != None:
        return ctx.attrs.vhdl_units
    if ctx.attrs.srcs:
        return []
    return [ctx.attrs.top]

def _ghdl_command(
        toolchain: YosysToolchainInfo,
        standard: str,
        libraries: list[VhdlLibrary],
        library_name: str,
        unit: str,
        generics: dict[str, str]) -> cmd_args:
    return cmd_args(
        "ghdl",
        "--std=" + standard,
        toolchain.ghdl_flags,
        [cmd_args("--work=" + library.name, library.srcs) for library in libraries],
        ["-g{}={}".format(generic, value) for generic, value in generics.items()],
        "--work=" + library_name,
        "-e",
        unit,
        delimiter = " ",
    )

def _read_verilog_command(src: Artifact) -> cmd_args:
    return cmd_args(
        "read_verilog",
        ["-sv"] if src.extension == ".sv" else [],
        src,
        delimiter = " ",
    )

def _yosys_synthesis_impl(ctx: AnalysisContext) -> list[Provider]:
    toolchain = ctx.attrs._yosys_toolchain[YosysToolchainInfo]
    libraries = _vhdl_libraries(ctx)
    vhdl_units = _vhdl_units(ctx)
    if not ctx.attrs.srcs and not libraries:
        fail("{} has no `srcs` nor VHDL `deps`".format(ctx.label.raw_target()))
    if libraries and not vhdl_units:
        fail("{} has VHDL `deps` but no `vhdl_units` to synthesize".format(ctx.label.raw_target()))
    if vhdl_units and toolchain.ghdl_plugin == None:
        fail("{} synthesizes VHDL but the Yosys toolchain has no GHDL plugin".format(ctx.label.raw_target()))

    top = ctx.attrs.top
    commands = []
    if vhdl_units:
        standard = _vhdl_standard(ctx, libraries)
        for unit in vhdl_units:
            library_name, unit_name = _vhdl_unit(ctx, libraries, unit)
            is_top = not ctx.attrs.srcs and unit == ctx.attrs.top
            if is_top:
                top = unit_name.lower()
            commands.append(_ghdl_command(
                toolchain,
                standard,
                libraries,
                library_name,
                unit_name,
                ctx.attrs.parameters if is_top else {},
            ))

    commands.extend([_read_verilog_command(src) for src in ctx.attrs.srcs])
    if ctx.attrs.srcs:
        commands.extend([
            cmd_args("chparam", "-set", parameter, value, top, delimiter = " ")
            for parameter, value in ctx.attrs.parameters.items()
        ])
    commands.append(cmd_args(ctx.attrs.synth, "-top", top, ctx.attrs.synth_flags, delimiter = " "))

    script, _ = ctx.actions.write(
        "{}.ys".format(ctx.label.name),
        commands,
        allow_args = True,
        with_inputs = True,
    )

    netlists = {}
    writes = []
    for format in ctx.attrs.formats:
        command, extension = _WRITE_COMMANDS[format]
        netlist = ctx.actions.declare_output("{}.{}".format(ctx.label.name, extension))
        netlists[format] = netlist
        writes.append(cmd_args(command, netlist.as_output(), delimiter = " "))

    log = ctx.actions.declare_output("{}.log".format(ctx.label.name))
    ctx.actions.run(
        cmd_args(
            toolchain.yosys,
            "-q",
            ["-m", toolchain.ghdl_plugin] if vhdl_units else [],
            toolchain.flags,
            "-l",
            log.as_output(),
            "-s",
            script,
            "-p",
            cmd_args(writes, delimiter = "; "),
        ),
        category = "yosys_synthesis",
    )

    return [
        DefaultInfo(
            default_outputs = netlists.values(),
            other_outputs = [log],
            sub_targets = {
                format: [DefaultInfo(default_output = netlist)]
                for format, netlist in netlists.items()
            } | {
                "log": [DefaultInfo(default_output = log)],
                "script": [DefaultInfo(default_output = script)],
            },
        ),
        YosysNetlistInfo(top = top, netlists = netlists),
    ]

yosys_synthesis = rule(
    impl = _yosys_synthesis_impl,
    doc = """
Synthesizes Verilog, SystemVerilog and VHDL sources into netlists with Yosys. VHDL is read
through the GHDL plugin from the sources of the VHDL libraries in `deps`, so it does not depend
on the simulator used by the VHDL toolchain.
""",
    attrs = {
        "srcs": attrs.list(
            attrs.source(),
            default = [],
            doc = "Verilog sources, files ending in `.sv` are read as SystemVerilog.",
        ),
        "deps": attrs.list(
            attrs.dep(providers = [VhdlLibraryInfo]),
            default = [],
            doc = "VHDL libraries to synthesize along with `srcs`.",
        ),
        "top": attrs.string(
            doc = """
Top level module. Without `srcs` it is the VHDL unit to synthesize, written as `library.unit`
or as `unit` when there is a single dependency.
""",
        ),
        "vhdl_units": attrs.option(
            attrs.list(attrs.string()),
            default = None,
            doc = """
VHDL units the design instantiates, written as `top`. Defaults to `top` without `srcs` and
must be set when Verilog instantiates VHDL.
""",
        ),
        "parameters": attrs.dict(
            attrs.string(),
            attrs.string(),
            default = {},
            doc = "Values for the parameters or generics of `top`.",
        ),
        "synth": attrs.string(
            default = "synth",
            doc = "Yosys synthesis command, for example `synth_ice40` or `synth_ecp5`.",
        ),
        "synth_flags": attrs.list(
            attrs.string(),
            default = [],
            doc = "Extra flags for the synthesis command.",
        ),
        "formats": attrs.list(
            attrs.enum(YOSYS_NETLIST_FORMATS),
            default = ["json"],
            doc = "Netlist formats to write, each is available as a sub-target.",
        ),
        "_yosys_toolchain": attrs.toolchain_dep(
            default = "toolchains//:yosys",
            providers = [YosysToolchainInfo],
        ),
    },
)
