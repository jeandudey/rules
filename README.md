# rules

Buck2 rules for languages and tools that are not part of the Buck2 prelude.

| Language | Rules | Toolchains |
| -------- | ----- | ---------- |
| VHDL | `vhdl_library`, `vhdl_binary`, `vhdl_test` | `remote_ghdl_toolchain`, `remote_nvc_toolchain`, `system_vhdl_toolchain` (GHDL, NVC) |

## Setup

Add this repository as a cell of your project:

```ini
[cells]
  rules = third-party/rules
```

Register the toolchains you need in your `toolchains` cell:

```python
load("@rules//toolchains/vhdl/ghdl:defs.bzl", "remote_ghdl_toolchain")

remote_ghdl_toolchain(
    name = "vhdl",
    visibility = ["PUBLIC"],
)
```

## VHDL

The VHDL rules support [GHDL](https://github.com/ghdl/ghdl) and [NVC](https://github.com/nickg/nvc),
through these toolchains:

- `remote_ghdl_toolchain` (`@rules//toolchains/vhdl/ghdl:defs.bzl`) downloads a GHDL mcode release from GitHub, nothing needs to be
  installed. `version` defaults to the latest known release (`6.0.0`); releases and checksums
  are listed in `toolchains/vhdl/ghdl/releases.bzl`. Supported execution platforms:

  | Version | Platforms |
  | ------- | --------- |
  | `6.0.0` | `linux-x86_64`, `windows-x86_64` |
  | `5.1.1` | `linux-x86_64`, `macos-x86_64`, `windows-x86_64` |

  The Linux releases are built on Ubuntu 24.04 and need glibc 2.38 or newer and `libz.so.1`.
  The Windows and macOS releases are untested.
- `remote_nvc_toolchain` (`@rules//toolchains/vhdl/nvc:defs.bzl`) downloads an NVC release package from GitHub
  and unpacks it. `version` defaults to the latest known release (`1.23.0`); releases and
  checksums are listed in `toolchains/vhdl/nvc/releases.bzl`. Supported execution platforms:

  | Version | Platforms |
  | ------- | --------- |
  | `1.23.0` | `linux-x86_64`, `windows-x86_64` |

  NVC only publishes Debian packages and a Windows installer. On Linux the Ubuntu 24.04
  package is unpacked with `dpkg-deb` and needs its shared libraries installed:
  `apt install libllvm18 libtcl8.6 libdw1t64 libreadline8t64 libffi8 libzstd1`. On Windows the
  installer is unpacked with `msiexec /a` and is self-contained.
- `system_vhdl_toolchain` (`@rules//toolchains:vhdl.bzl`) uses a simulator installed on the system and found through
  `PATH`. `simulator` is `ghdl` (default) or `nvc`, `compiler` defaults to the simulator name.
  For GHDL (for example `apt install ghdl`) set `backend` to match the code generator: `mcode`
  (default), `llvm` or `gcc`. NVC takes no `backend`.

NVC supports the `93`, `93c`, `00`, `02`, `08` and `19` standards; `87` is GHDL only.

Several toolchains can be offered at once by selecting between them with constraints, which is
what `examples/toolchains/BUCK` does:

```python
constraint(
    name = "vhdl_simulator",
    default = "ghdl",
    values = ["ghdl", "nvc"],
)

constraint(
    name = "vhdl_toolchain",
    default = "remote",
    values = ["remote", "system"],
)

remote_ghdl_toolchain(name = "vhdl_ghdl_remote")

system_vhdl_toolchain(name = "vhdl_ghdl_system")

remote_nvc_toolchain(name = "vhdl_nvc_remote")

system_vhdl_toolchain(
    name = "vhdl_nvc_system",
    simulator = "nvc",
)

toolchain_alias(
    name = "vhdl",
    actual = select({
        ":vhdl_simulator[ghdl]": select({
            ":vhdl_toolchain[remote]": ":vhdl_ghdl_remote",
            ":vhdl_toolchain[system]": ":vhdl_ghdl_system",
        }),
        ":vhdl_simulator[nvc]": select({
            ":vhdl_toolchain[remote]": ":vhdl_nvc_remote",
            ":vhdl_toolchain[system]": ":vhdl_nvc_system",
        }),
    }),
    visibility = ["PUBLIC"],
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

The examples use the downloaded GHDL by default. `examples/toolchains/BUCK` defines a platform
per simulator and toolchain: `ghdl_remote_platform`, `ghdl_system_platform`,
`nvc_remote_platform` and `nvc_system_platform`. For example, to use NVC from `PATH`:

```sh
buck2 test --target-platforms toolchains//:nvc_system_platform examples//...
```
