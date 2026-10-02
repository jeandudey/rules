YOSYS_NETLIST_FORMATS = ["json", "verilog", "blif", "edif", "rtlil"]

YosysNetlistInfo = provider(
    doc = """
Synthesized netlist.

`top` is the name of the top module and `netlists` maps each format of
`YOSYS_NETLIST_FORMATS` that was written to its netlist.
""",
    fields = {
        "top": provider_field(str),
        "netlists": provider_field(dict[str, Artifact]),
    },
)
