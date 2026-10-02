DEFAULT_VERSION = "6.0.0"

def _linux(version: str, sha256: str) -> dict[str, str | None]:
    prefix = "ghdl-mcode-{}-ubuntu24.04-x86_64".format(version)
    return {
        "url": "https://github.com/ghdl/ghdl/releases/download/v{}/{}.tar.gz".format(version, prefix),
        "sha256": sha256,
        "strip_prefix": prefix,
        "executable": "bin/ghdl",
    }

def _macos(version: str, sha256: str) -> dict[str, str | None]:
    prefix = "ghdl-mcode-{}-macos13-x86_64".format(version)
    return {
        "url": "https://github.com/ghdl/ghdl/releases/download/v{}/{}.tar.gz".format(version, prefix),
        "sha256": sha256,
        "strip_prefix": prefix,
        "executable": "bin/ghdl",
    }

def _windows(version: str, sha256: str) -> dict[str, str | None]:
    return {
        "url": "https://github.com/ghdl/ghdl/releases/download/v{0}/ghdl-mcode-{0}-ucrt64.zip".format(version),
        "sha256": sha256,
        "strip_prefix": None,
        "executable": "bin/ghdl.exe",
    }

RELEASES = {
    "6.0.0": {
        "linux-x86_64": _linux("6.0.0", "30d6a977b8456d140bbafecbbe64b1947a3d92eeae8f5e6d9f528a174f9566e7"),
        "windows-x86_64": _windows("6.0.0", "76e160ceec35834c73ada6e4e484416d13aed4b64cbc7c74c5cca53a7ef60e41"),
    },
    "5.1.1": {
        "linux-x86_64": _linux("5.1.1", "1e388cd763d3f83015ac326d41b161ec290fa19628a81ebd92f2f8b688544cfe"),
        "macos-x86_64": _macos("5.1.1", "b386189fd6bcbaa8b7f215afcdadc619f9a2aecf273acbff86621564e2e70c76"),
        "windows-x86_64": _windows("5.1.1", "ac82b10bed0754db466640f49079e736da1de0b43b1196564aff5d8ebf435aaf"),
    },
}
