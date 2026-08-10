# Godot Laptop / External Drive Handoff

This note records the portable Godot launch setup for working on
**환격전** from a laptop or an external drive. The English product title is
undecided; existing filesystem and export names remain compatibility IDs.

## Current Project

- Live Godot project: `godot/project.godot`
- Tool wrappers: `godot/tools/*.ps1`
- Shared Godot executable resolver:
  `godot/tools/resolve_godot_exe.ps1`

Do not open or sync the old external live project under
`C:\Users\woduq\Documents\pingfighter` unless a future task explicitly
reintroduces it. The repo-local `godot/` project is the current target.

## What Was Fixed

The Godot wrapper scripts no longer depend on the desktop-only path:

```text
C:\Users\woduq\Downloads\Godot_v4.6.2-stable_win64.exe\...
```

They now use `resolve_godot_exe.ps1`, which can find Godot through:

1. The script parameter `-GodotExe`
2. `GODOT_CONSOLE_EXE`
3. `GODOT_EXE`
4. PATH commands such as `godot_console`, `godot4`, or `godot`
5. The current user's `Downloads`
6. Connected drives under common folders:
   `Godot`, `Tools`, `Apps`, `PortableApps`, `Downloads`, `dev`, `main`

This is intended to survive drive-letter changes when the repo or Godot is
opened from a laptop with an external drive attached.

## Recommended Laptop Setup

Put the Godot executable in a predictable folder on the external drive, for
example:

```text
E:\Godot\Godot_v4.6.2-stable_win64.exe
E:\Godot\Godot_v4.6.2-stable_win64_console.exe
```

If the drive letter may change, the resolver should still find it as long as
the folder is named one of the common search roots above.

For the most stable setup, set one environment variable on the laptop:

```powershell
setx GODOT_EXE "E:\Godot\Godot_v4.6.2-stable_win64.exe"
```

Or, if using the console executable directly:

```powershell
setx GODOT_CONSOLE_EXE "E:\Godot\Godot_v4.6.2-stable_win64_console.exe"
```

Open a new terminal after `setx`, because existing shells do not receive the
new environment variable automatically.

## Quick Verification

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command ". .\godot\tools\resolve_godot_exe.ps1; Resolve-GodotConsolePath"
```

Expected result: it prints the Godot console executable path.

Then verify the project:

```powershell
cd godot
.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

Both should pass. A Windows headless message about failing to read the root
certificate store is currently treated as unrelated environment noise by the
wrappers.

## Opening The Editor

Use the repo wrapper instead of launching Godot manually:

```powershell
cd godot
.\tools\open_godot_safe.ps1
```

If auto-detection fails, pass the executable explicitly:

```powershell
.\tools\open_godot_safe.ps1 -GodotExe "E:\Godot\Godot_v4.6.2-stable_win64.exe"
```

The wrapper checks that `project.godot` exists, is not empty, and still points
to `res://scenes/boot_flow.tscn` before opening the editor.

## If Godot Still Does Not Connect

Check these in order:

1. Confirm the external drive is ready in Windows Explorer.
2. Confirm the repo path contains `godot/project.godot`.
3. Run `Resolve-GodotConsolePath` from the quick verification section.
4. If it fails, set `GODOT_EXE` or `GODOT_CONSOLE_EXE` with `setx`.
5. Open a new PowerShell window and run the quick verification again.
6. If the editor opens but behaves strangely, close Godot and run:

```powershell
cd godot
.\tools\fix_godot_editor_crash_workaround.ps1 -Launch
```

That script avoids force-closing unsaved editor work. It will stop and ask you
to close Godot first if an editor process is still running.

## Sign-Off State

Verified on the desktop workspace after the resolver change:

- `godot/tools/run_headless_load_check.ps1` passed.
- `godot/tools/run_warning_scan.ps1` passed with no GDScript warnings.
- `godot/tools` no longer contains the old hardcoded Godot download path.
