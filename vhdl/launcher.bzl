load("@prelude//os_lookup:defs.bzl", "OsLookup", "ScriptLanguage")

def project_root_launcher(ctx: AnalysisContext) -> Artifact:
    """
    Writes a launcher that runs its arguments from the project root, so simulators given paths
    relative to the project root work wherever the command is run from. Needs the
    `_target_os_type` attribute.
    """
    if ctx.attrs._target_os_type[OsLookup].script == ScriptLanguage("bat"):
        launcher = ctx.actions.declare_output("vhdl_launcher.bat")
        content = cmd_args(
            "@echo off",
            cmd_args("cd /d \"%~dp0", ctx.label.project_root, "\"", delimiter = ""),
            "%*",
            "exit /b %ERRORLEVEL%",
            relative_to = (launcher, 1),
        )
    else:
        launcher = ctx.actions.declare_output("vhdl_launcher.sh")
        content = cmd_args(
            "#!/bin/sh",
            cmd_args("cd \"$(dirname \"$0\")/", ctx.label.project_root, "\" || exit 1", delimiter = ""),
            "exec \"$@\"",
            relative_to = (launcher, 1),
        )
    ctx.actions.write(launcher, content, is_executable = True)
    return launcher
