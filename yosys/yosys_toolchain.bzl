YosysToolchainInfo = provider(
    doc = """
Yosys synthesis toolchain.

`yosys` is the Yosys executable and `flags` are appended to every Yosys command line.
`ghdl_plugin` is the name or path of the GHDL plugin loaded with `-m` to synthesize VHDL,
`None` when the toolchain cannot synthesize VHDL. `ghdl_flags` are passed to every `ghdl`
command, for example `--PREFIX=` when the plugin does not find the VHDL standard libraries.
""",
    fields = {
        "yosys": provider_field(RunInfo),
        "flags": provider_field(list[str], default = []),
        "ghdl_plugin": provider_field(str | None, default = None),
        "ghdl_flags": provider_field(list[str], default = []),
    },
)
