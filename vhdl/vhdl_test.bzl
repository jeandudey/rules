load(":vhdl_binary.bzl", "vhdl_executable", "vhdl_executable_attrs")

def _vhdl_test_impl(ctx: AnalysisContext) -> list[Provider]:
    args, outputs = vhdl_executable(ctx, stop_on_error = True)
    return [
        DefaultInfo(default_outputs = outputs),
        RunInfo(args = args),
        ExternalRunnerTestInfo(
            type = "vhdl",
            command = [args],
            labels = ctx.attrs.labels,
            contacts = ctx.attrs.contacts,
        ),
    ]

vhdl_test = rule(
    impl = _vhdl_test_impl,
    doc = """
Simulates a VHDL testbench as a test. The test fails when the simulation exits with a failure,
including assertions of `error` severity or above.
""",
    attrs = vhdl_executable_attrs | {
        "labels": attrs.list(attrs.string(), default = [], doc = "Test labels."),
        "contacts": attrs.list(attrs.string(), default = [], doc = "Test owners."),
    },
)
