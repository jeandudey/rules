load(":vhdl_info.bzl", "VHDL_STANDARDS", "VhdlLibrary", "VhdlLibraryInfo", "VhdlLibraryTSet")
load(":vhdl_simulator.bzl", "vhdl_simulator")
load(":vhdl_toolchain.bzl", "VhdlToolchainInfo")

_LIBRARY_NAME_REGEX = regex("^[A-Za-z][A-Za-z0-9_]*$")

vhdl_analysis_attrs = {
    "srcs": attrs.list(
        attrs.source(),
        default = [],
        doc = "VHDL sources, analyzed in the order they are listed.",
    ),
    "deps": attrs.list(
        attrs.dep(providers = [VhdlLibraryInfo]),
        default = [],
        doc = "VHDL libraries used by `srcs`.",
    ),
    "library_name": attrs.option(
        attrs.string(),
        default = None,
        doc = "VHDL library name `srcs` are analyzed into, defaults to the target name.",
    ),
    "standard": attrs.enum(
        VHDL_STANDARDS,
        default = select({
            "//vhdl/constraints:standard[{}]".format(standard): standard
            for standard in VHDL_STANDARDS
        }),
        doc = "VHDL standard revision, defaults to the `//vhdl/constraints:standard` constraint value.",
    ),
    "flags": attrs.list(
        attrs.string(),
        default = [],
        doc = "Extra simulator flags used when analyzing `srcs`.",
    ),
    "_vhdl_toolchain": attrs.toolchain_dep(
        default = "toolchains//:vhdl",
        providers = [VhdlToolchainInfo],
    ),
}

def _check_libraries(ctx: AnalysisContext, name: str, libraries: VhdlLibraryTSet):
    owners = {}
    for library in libraries.traverse():
        owner = library.library_file.owner.raw_target()
        library_name = library.name.lower()
        if library.standard != ctx.attrs.standard:
            fail("{} uses VHDL standard `{}` but dependency {} uses `{}`".format(
                ctx.label.raw_target(),
                ctx.attrs.standard,
                owner,
                library.standard,
            ))
        if library_name == name.lower():
            fail("{} defines library `{}` which is also defined by dependency {}".format(
                ctx.label.raw_target(),
                name,
                owner,
            ))
        if library_name in owners and owners[library_name] != owner:
            fail("library `{}` is defined by both {} and {}".format(library.name, owners[library_name], owner))
        owners[library_name] = owner

def vhdl_analyze(ctx: AnalysisContext) -> (VhdlLibrary | None, VhdlLibraryTSet):
    """
    Analyzes `srcs` into a library and returns it along with the transitive set of every library
    it depends on, the analyzed library is `None` when there are no `srcs`.
    """
    toolchain = ctx.attrs._vhdl_toolchain[VhdlToolchainInfo]
    name = ctx.attrs.library_name or ctx.label.name
    if not _LIBRARY_NAME_REGEX.match(name):
        fail("`{}` is not a valid VHDL library name, set `library_name`".format(name))

    deps = ctx.actions.tset(
        VhdlLibraryTSet,
        children = [dep[VhdlLibraryInfo].tset for dep in ctx.attrs.deps],
    )
    _check_libraries(ctx, name, deps)

    if not ctx.attrs.srcs:
        return None, deps

    library = vhdl_simulator(toolchain).analyze(
        ctx,
        toolchain,
        name,
        ctx.attrs.standard,
        ctx.attrs.srcs,
        deps,
        ctx.attrs.flags,
    )
    return library, ctx.actions.tset(VhdlLibraryTSet, value = library, children = [deps])

def _vhdl_library_impl(ctx: AnalysisContext) -> list[Provider]:
    if not ctx.attrs.srcs:
        fail("{} has no `srcs`".format(ctx.label.raw_target()))
    library, libraries = vhdl_analyze(ctx)
    return [
        DefaultInfo(default_outputs = [library.library_file], other_outputs = library.objects),
        VhdlLibraryInfo(library = library, tset = libraries),
    ]

vhdl_library = rule(
    impl = _vhdl_library_impl,
    doc = "Analyzes VHDL sources into a named VHDL library that other VHDL targets can depend on.",
    attrs = vhdl_analysis_attrs,
)
