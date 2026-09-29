VHDL_SIMULATORS = ["ghdl"]

VHDL_GHDL_BACKENDS = ["mcode", "llvm", "gcc"]

VhdlToolchainInfo = provider(
    doc = """
VHDL simulator toolchain.

`simulator` selects how commands are built and must be one of `VHDL_SIMULATORS`. `compiler` is
the simulator executable. `backend` is simulator specific, for GHDL it is one of
`VHDL_GHDL_BACKENDS` and decides whether elaboration produces an executable (`llvm` and `gcc`)
or the design is run by the simulator itself (`mcode`). The flag lists are appended to every
analysis, elaboration and run command respectively.
""",
    fields = {
        "simulator": provider_field(str),
        "compiler": provider_field(RunInfo),
        "backend": provider_field(str | None, default = None),
        "analyze_flags": provider_field(list[str], default = []),
        "elaborate_flags": provider_field(list[str], default = []),
        "run_flags": provider_field(list[str], default = []),
    },
)
