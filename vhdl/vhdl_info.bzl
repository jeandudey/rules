VHDL_STANDARDS = ["87", "93", "93c", "00", "02", "08", "19"]

VhdlLibrary = record(
    name = str,
    standard = str,
    library_file = Artifact,
    objects = list[Artifact],
    srcs = list[Artifact],
)

def _include_args(library: VhdlLibrary) -> cmd_args:
    return cmd_args(library.library_file, format = "-P{}", parent = 1)

def _inputs_args(library: VhdlLibrary) -> cmd_args:
    return cmd_args(library.library_file, library.objects, library.srcs)

VhdlLibraryTSet = transitive_set(
    args_projections = {
        "include": _include_args,
        "inputs": _inputs_args,
    },
)

VhdlLibraryInfo = provider(
    doc = """
Analyzed VHDL library.

`library` is the analyzed library of this target, `tset` holds it together with all of its
transitive dependencies. The `include` projection of `tset` yields the simulator flags needed
to find the libraries and the `inputs` projection yields every artifact needed to use them.
""",
    fields = {
        "library": provider_field(VhdlLibrary),
        "tset": provider_field(VhdlLibraryTSet),
    },
)
