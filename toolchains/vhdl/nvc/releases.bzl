DEFAULT_VERSION = "1.23.0"

def _ubuntu(version: str, sha256: str) -> dict[str, str | None]:
    return {
        "url": "https://github.com/nickg/nvc/releases/download/r{0}/nvc_{0}-1_amd64_ubuntu-24.04.deb".format(version),
        "sha256": sha256,
        "format": "deb",
        "executable": "usr/bin/nvc",
        "library_path": "usr/lib/x86_64-linux-gnu/nvc",
    }

def _windows(version: str, sha256: str) -> dict[str, str | None]:
    return {
        "url": "https://github.com/nickg/nvc/releases/download/r{0}/nvc-{0}.msi".format(version),
        "sha256": sha256,
        "format": "msi",
        "executable": "PFiles/NVC/bin/nvc.exe",
        "library_path": None,
    }

RELEASES = {
    "1.23.0": {
        "linux-x86_64": _ubuntu("1.23.0", "33d65eafb83d83352716895e44c116002f94d8a198a9486a3cee6df3e4fdfb89"),
        "windows-x86_64": _windows("1.23.0", "591b33a5b9890194da89d3915449ea7cbb40d4ad928abeac92d3bbf4b3dfe083"),
    },
}
