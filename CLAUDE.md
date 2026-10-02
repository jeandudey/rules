# Buck2 rules

This is a set of Buck2 rules for software that is not in the Buck2 prelude, if something is in the
Buck2 prelude we shouldn't reimplement it without a good reason, we should aim to interop with
the prelude as much as possible.

## Code style

- Rule names should follow Buck2 naming guidelines.
  - Binaries, e.g. rules that provide a RunInfo should be named `<prefix>_binary`, for example, `cxx_binary`.
  - Libraries, e.g. rules that group or compile artifacts that are used by other rules should be named `<prefix>_library`, for example, `cxx_library`.

- Starlark rule files (`*.bzl`) should also follow the `<prefix>_<rule>.bzl` naming, for example `vhdl_library`.
- One rule per Starlark file.
- No code comments, either document using the proper documentation means in Starlark rules. If something is not clear and requires a comment then the code is not clear and requires a better implementation.
- `<prefix>` should be something generic and not tied to vendor rules unless it is actually provided by a single vendor, for example, VHDL has several simulators and compilers, thus prefix should be `vhdl` instead of `ghdl` for example.
- Rules that deal with vendor compiler should try to work with all of the vendors we support, if not supported, it should be worked by keeping it in
mind that the code will be extended.
- Rules for a specific language should have a dedicated directory for example, vhdl goes in `vhdl` at the root of the repository.
- Rules for languages that depend on external tooling should have a `<prefix>_toolchain.bzl` with toolchain providers, no toolchain rules.
- Providers related to a set of rules should use a `<prefix>_info.bzl` for defining the providers.
- Constraints related to a set of rules goes under `<prefix>/constraints/BUCK`. Only constraints the rules read belong there, project specific constraints (such as selecting a toolchain) belong to the project using the rules, for example `examples/`.
- Use the new `constraints` rule for defining constraints always.
- If a compiler provides pre-built binaries we should strive to provide rules to download the toolchain remotely by specifying the needed version and making it work on Buck2.
- If not we should strive to make the toolchain providers as generic as possible to allow the user to specify where the toolchain comes from with their own rules.
- We should strive at minimum to provide toolchain rules that can use the system toolchain from PATH.
- Toolchain rules go in the `toolchains/` directory at the root of the repository, one file per language named `<prefix>.bzl`, for example `toolchains/vhdl.bzl`. Toolchain providers stay in `<prefix>/<prefix>_toolchain.bzl`.
- Toolchains downloaded from vendor releases follow the prelude zig toolchain layout: `toolchains/<prefix>/<vendor>/releases.bzl` holds the release table (versions, per platform URLs and checksums) and `toolchains/<prefix>/<vendor>/defs.bzl` holds the toolchain rule, for example `toolchains/vhdl/ghdl/defs.bzl`.
- Downloadable toolchain rules are named `remote_<vendor>_toolchain`, for example `remote_ghdl_toolchain`. Toolchains from `PATH` that work with several vendors are named `system_<prefix>_toolchain`, for example `system_vhdl_toolchain`.
- Do not create empty `BUCK` files unless Buck2 strictly requires them, a directory containing only `.bzl` files does not need a `BUCK` file.
- Never create `private/` (or similar internal) folders, helper modules live next to the rules in the language directory.
- Rules must work on both Unix and Windows execution platforms, do not assume `sh` or other Unix tools are available. Use the prelude `OsLookup` provider when the command differs per platform.
- The `examples/` directory is a Buck2 project (created with `buck2 init`) used for integration testing, examples for each language go under `examples/<prefix>/`.
