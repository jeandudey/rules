load("//vhdl:vhdl_toolchain.bzl", "VHDL_GHDL_BACKENDS", "VHDL_SIMULATORS", "VhdlToolchainInfo")

def _system_vhdl_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        VhdlToolchainInfo(
            simulator = ctx.attrs.simulator,
            compiler = RunInfo(args = [ctx.attrs.compiler]),
            backend = ctx.attrs.backend,
            analyze_flags = ctx.attrs.analyze_flags,
            elaborate_flags = ctx.attrs.elaborate_flags,
            run_flags = ctx.attrs.run_flags,
        ),
    ]

system_vhdl_toolchain = rule(
    impl = _system_vhdl_toolchain_impl,
    is_toolchain_rule = True,
    doc = "VHDL toolchain using a simulator installed on the system and found through `PATH`.",
    attrs = {
        "simulator": attrs.enum(VHDL_SIMULATORS, default = "ghdl", doc = "Simulator to use."),
        "compiler": attrs.string(default = "ghdl", doc = "Simulator executable name or path."),
        "backend": attrs.enum(
            VHDL_GHDL_BACKENDS,
            default = "mcode",
            doc = "GHDL code generator the executable was built with.",
        ),
        "analyze_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every analysis."),
        "elaborate_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every elaboration."),
        "run_flags": attrs.list(attrs.string(), default = [], doc = "Extra flags for every simulation run."),
    },
)
