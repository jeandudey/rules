# rules

Buck2 rules for languages and tools that are not part of the Buck2 prelude.

| Language | Rules | Toolchains |
| -------- | ----- | ---------- |
| VHDL | `vhdl_library`, `vhdl_binary`, `vhdl_test` | `remote_vhdl_toolchain`, `system_vhdl_toolchain` (GHDL) |

## Setup

Add this repository as a cell of your project:

```ini
[cells]
  rules = third-party/rules
```

Register the toolchains you need in your `toolchains` cell:

```python
load("@rules//toolchains:vhdl.bzl", "remote_vhdl_toolchain")

remote_vhdl_toolchain(
    name = "vhdl",
    visibility = ["PUBLIC"],
)
```

## VHDL

The VHDL rules currently support [GHDL](https://github.com/ghdl/ghdl), through two toolchains:

- `remote_vhdl_toolchain` downloads a GHDL mcode release from GitHub, nothing needs to be
  installed. `version` defaults to the latest known release (`6.0.0`); releases and checksums
  are listed in `vhdl/ghdl_releases.bzl`. Supported execution platforms:

  | Version | Platforms |
  | ------- | --------- |
  | `6.0.0` | `linux-x86_64`, `windows-x86_64` |
  | `5.1.1` | `linux-x86_64`, `macos-x86_64`, `windows-x86_64` |

  The Linux releases are built on Ubuntu 24.04 and need glibc 2.38 or newer and `libz.so.1`.
  The Windows and macOS releases are untested.
- `system_vhdl_toolchain` uses GHDL installed on the system and found through `PATH` (for example
  `apt install ghdl`). Set `backend` to match the GHDL code generator: `mcode` (default), `llvm`
  or `gcc`.

Both toolchains can be offered at once by selecting between them with a constraint, which is
what `examples/toolchains/BUCK` does:

```python
constraint(
    name = "vhdl_toolchain",
    default = "remote",
    values = ["remote", "system"],
)

remote_vhdl_toolchain(name = "vhdl_remote")

system_vhdl_toolchain(name = "vhdl_system")

toolchain_alias(
    name = "vhdl",
    actual = select({
        ":vhdl_toolchain[remote]": ":vhdl_remote",
        ":vhdl_toolchain[system]": ":vhdl_system",
    }),
    visibility = ["PUBLIC"],
)

platform(
    name = "system_vhdl_platform",
    constraint_values = [":vhdl_toolchain[system]"],
    deps = ["prelude//platforms:default"],
)
```

```python
load("@rules//vhdl:vhdl_binary.bzl", "vhdl_binary")
load("@rules//vhdl:vhdl_library.bzl", "vhdl_library")
load("@rules//vhdl:vhdl_test.bzl", "vhdl_test")

vhdl_library(
    name = "counter",
    srcs = ["counter.vhd"],
)

vhdl_test(
    name = "counter_tb",
    srcs = ["counter_tb.vhd"],
    top = "counter_tb",
    deps = [":counter"],
)

vhdl_binary(
    name = "counter_sim",
    srcs = ["counter_tb.vhd"],
    top = "counter_tb",
    generics = {"CYCLES": "100"},
    deps = [":counter"],
)
```

- `top` is a design unit from the target's own `srcs`, or `library.unit` for a unit from a
  dependency.
- Every target analyzes its `srcs` into a VHDL library named after the target, or after
  `library_name` if set. Design units from dependencies are used through their library name,
  for example `library counter; ... entity counter.counter`.
- The VHDL standard defaults to the `@rules//vhdl/constraints:standard` constraint (`08`) and can
  be overridden per target with `standard`.
- `vhdl_test` fails on assertions of `error` severity or above.

## Examples

`examples/` is a Buck2 project used for integration testing:

```sh
buck2 build examples//...
buck2 test examples//...
buck2 run examples//vhdl/multi_lib:sim
```

The examples use the downloaded GHDL by default. To use GHDL from `PATH` instead:

```sh
buck2 test --target-platforms toolchains//:system_vhdl_platform examples//...
```
