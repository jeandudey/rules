load(":ghdl.bzl", "ghdl_analyze", "ghdl_executable")
load(":nvc.bzl", "nvc_analyze", "nvc_executable")
load(":vhdl_toolchain.bzl", "VhdlToolchainInfo")

VhdlSimulator = record(
    analyze = typing.Callable,
    executable = typing.Callable,
)

_SIMULATORS = {
    "ghdl": VhdlSimulator(
        analyze = ghdl_analyze,
        executable = ghdl_executable,
    ),
    "nvc": VhdlSimulator(
        analyze = nvc_analyze,
        executable = nvc_executable,
    ),
}

def vhdl_simulator(toolchain: VhdlToolchainInfo) -> VhdlSimulator:
    return _SIMULATORS[toolchain.simulator]
