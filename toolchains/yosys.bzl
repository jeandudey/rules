load("//yosys:yosys_toolchain.bzl", "YosysToolchainInfo")

def _system_yosys_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        YosysToolchainInfo(
            yosys = RunInfo(args = [ctx.attrs.yosys]),
            flags = ctx.attrs.flags,
            ghdl_plugin = ctx.attrs.ghdl_plugin if ctx.attrs.vhdl else None,
            ghdl_flags = ctx.attrs.ghdl_flags,
        ),
    ]

system_yosys_toolchain = rule(
    impl = _system_yosys_toolchain_impl,
    is_toolchain_rule = True,
    doc = "Yosys toolchain using a Yosys installed on the system and found through `PATH`.",
    attrs = {
        "yosys": attrs.string(default = "yosys", doc = "Yosys executable name or path."),
        "flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every Yosys command line."),
        "vhdl": attrs.bool(default = True, doc = "Whether VHDL is synthesized through the GHDL plugin."),
        "ghdl_plugin": attrs.string(default = "ghdl", doc = "GHDL plugin name or path."),
        "ghdl_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every `ghdl` command."),
    },
)
