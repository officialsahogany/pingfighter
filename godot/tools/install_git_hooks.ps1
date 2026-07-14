#requires -Version 5.1
<#
.SYNOPSIS
    Install / update the Godot pre-push gate into this repo's git hooks.

.DESCRIPTION
    .git/hooks is NOT tracked by Git, so the pre-push gate disappears on a fresh
    clone or a new machine. Run this script there to restore it.

    It writes .git/hooks/pre-push as a managed wrapper that:
      1. runs godot/tools/run_pre_push_checks.ps1 ONLY when the pushed commits
         touch godot/ OR root tools/ (headless load + asset-tool python
         regression + warning scan + focused smokes), and
      2. then chains to the preserved original hook saved as pre-push.local
         (typically the Git LFS pre-push hook) so LFS objects still upload.

    The first install preserves the existing pre-push (e.g. the Git LFS hook)
    verbatim as pre-push.local. Re-running is idempotent: it refreshes the
    wrapper and leaves the preserved downstream untouched. If no hook exists yet
    (and the repo uses Git LFS), it writes the standard LFS hook as the
    downstream.

    Usage (after cloning / on a new machine):
        powershell -ExecutionPolicy Bypass -File godot\tools\install_git_hooks.ps1

.PARAMETER Force
    Re-capture the downstream hook from the current pre-push even if
    pre-push.local already exists (backs up the old one to pre-push.local.bak).
#>
param([switch]$Force)

$ErrorActionPreference = "Stop"

function Resolve-HooksDir {
    # Derive the hooks dir from this script's location instead of calling git
    # (a malformed global safe.directory entry makes git print a stderr warning
    # that PowerShell 5.1 turns into a fatal NativeCommandError).
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $gitPath  = Join-Path $repoRoot ".git"

    if (Test-Path -LiteralPath $gitPath -PathType Container) {
        return (Join-Path $gitPath "hooks")
    }
    if (Test-Path -LiteralPath $gitPath -PathType Leaf) {
        # Linked worktree / submodule: ".git" is a file "gitdir: <path>".
        $line = (Get-Content -LiteralPath $gitPath -Raw).Trim()
        if ($line -match '^gitdir:\s*(.+)$') {
            $gd = $Matches[1].Trim()
            if (-not [System.IO.Path]::IsPathRooted($gd)) {
                $gd = (Resolve-Path (Join-Path $repoRoot $gd)).Path
            }
            $commonFile = Join-Path $gd "commondir"
            if (Test-Path -LiteralPath $commonFile -PathType Leaf) {
                $common = (Get-Content -LiteralPath $commonFile -Raw).Trim()
                if (-not [System.IO.Path]::IsPathRooted($common)) {
                    $common = (Resolve-Path (Join-Path $gd $common)).Path
                }
                return (Join-Path $common "hooks")
            }
            return (Join-Path $gd "hooks")
        }
    }
    throw "Could not locate .git for repo root $repoRoot"
}

function Write-TextLf {
    param([string]$Path, [string]$Text)
    # Hook files run through /bin/sh: force LF endings and no BOM, or the
    # shebang line breaks ("/bin/sh^M: bad interpreter").
    $lf = ($Text -replace "`r`n", "`n") -replace "`r", "`n"
    [System.IO.File]::WriteAllText($Path, $lf, (New-Object System.Text.UTF8Encoding($false)))
}

$MARKER = "godot-prepush-gate v2"

$wrapper = @'
#!/bin/sh
# godot-prepush-gate v2 (managed by godot/tools/install_git_hooks.ps1)
# Runs godot/tools/run_pre_push_checks.ps1 when pushed commits touch godot/
# OR root tools/ (asset-pipeline python tools carry committed regressions),
# then chains to the preserved original hook (pre-push.local, e.g. Git LFS).
# Bypass: SKIP_GODOT_PREPUSH=1 git push   or   git push --no-verify

stdin_data=$(cat)

all_zero() { case "$1" in (*[!0]*) return 1 ;; (*) return 0 ;; esac; }

godot_changed() {
	reflist="${TMPDIR:-/tmp}/godot_prepush_refs.$$"
	printf '%s\n' "$stdin_data" > "$reflist"
	changed=1
	while read -r l_ref l_sha r_ref r_sha; do
		[ -z "$l_sha" ] && continue
		all_zero "$l_sha" && continue            # branch delete -> nothing to check
		if all_zero "$r_sha"; then
			changed=0; break                     # new remote branch -> run to be safe
		elif git diff --name-only "$r_sha" "$l_sha" -- godot tools </dev/null 2>/dev/null | grep -q .; then
			changed=0; break
		fi
	done < "$reflist"
	rm -f "$reflist"
	return $changed
}

if [ -n "$SKIP_GODOT_PREPUSH" ]; then
	echo "[pre-push] SKIP_GODOT_PREPUSH set -> skipping Godot checks"
elif godot_changed; then
	psexe=""
	if command -v pwsh >/dev/null 2>&1; then
		psexe="pwsh"
	elif command -v powershell.exe >/dev/null 2>&1; then
		psexe="powershell.exe"
	fi
	if [ -z "$psexe" ]; then
		echo "[pre-push] no PowerShell found -> skipping Godot checks (non-Windows clone?)"
	else
		root=$(git rev-parse --show-toplevel)
		script="$root/godot/tools/run_pre_push_checks.ps1"
		if [ ! -f "$script" ]; then
			echo "[pre-push] $script missing -> skipping Godot checks"
		else
			if command -v cygpath >/dev/null 2>&1; then
				script=$(cygpath -w "$script")
			fi
			echo "[pre-push] running Godot checks (bypass: SKIP_GODOT_PREPUSH=1 or git push --no-verify)"
			"$psexe" -NoProfile -ExecutionPolicy Bypass -File "$script"
			gstatus=$?
			if [ "$gstatus" -ne 0 ]; then
				printf >&2 "\n[pre-push] Godot checks FAILED (exit %s) -> push aborted\n\n" "$gstatus"
				exit 1
			fi
		fi
	fi
else
	echo "[pre-push] no godot/ or tools/ changes in pushed commits -> skipping Godot checks"
fi

# --- chain to preserved original hook (e.g. Git LFS) ---
downstream="${0}.local"
if [ -f "$downstream" ]; then
	printf '%s\n' "$stdin_data" | sh "$downstream" "$@"
	exit $?
fi
exit 0
'@

$lfsHook = @'
#!/bin/sh
command -v git-lfs >/dev/null 2>&1 || { printf >&2 "\n%s\n\n" "This repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting the 'pre-push' file in the hooks directory (set by 'core.hookspath'; usually '.git/hooks')."; exit 2; }
git lfs pre-push "$@"
'@

$hooksDir   = Resolve-HooksDir
$prePush    = Join-Path $hooksDir "pre-push"
$downstream = Join-Path $hooksDir "pre-push.local"

Write-Host "Hooks dir: $hooksDir"

# 1) Preserve any existing non-managed hook as the downstream (pre-push.local).
if (Test-Path -LiteralPath $prePush -PathType Leaf) {
    $existing = Get-Content -LiteralPath $prePush -Raw
    if ($existing -match [regex]::Escape($MARKER)) {
        Write-Host "Existing pre-push is already the managed gate; keeping downstream as-is."
    }
    elseif ((Test-Path -LiteralPath $downstream -PathType Leaf) -and -not $Force) {
        Write-Host "pre-push.local already exists; leaving it (use -Force to re-capture)."
    }
    else {
        if (Test-Path -LiteralPath $downstream -PathType Leaf) {
            Copy-Item -LiteralPath $downstream -Destination "$downstream.bak" -Force
            Write-Host "Backed up existing pre-push.local -> pre-push.local.bak"
        }
        Write-TextLf -Path $downstream -Text $existing
        Write-Host "Preserved existing pre-push -> pre-push.local"
    }
}

# 2) Ensure a downstream exists (repo uses Git LFS -> default to the LFS hook).
if (-not (Test-Path -LiteralPath $downstream -PathType Leaf)) {
    Write-TextLf -Path $downstream -Text $lfsHook
    Write-Host "No downstream found; wrote default Git LFS hook -> pre-push.local"
}

# 3) Install / refresh the managed wrapper.
Write-TextLf -Path $prePush -Text $wrapper
Write-Host "Installed managed gate -> pre-push"

# 4) Best-effort executable bit (matters on non-Windows clones).
$chmod = Get-Command chmod -ErrorAction SilentlyContinue
if ($chmod) { & $chmod.Source +x $prePush $downstream 2>$null }

Write-Host ""
Write-Host "Done. pre-push gate active: godot/ or tools/ changes -> Godot checks, then $([System.IO.Path]::GetFileName($downstream))."
Write-Host "Bypass once: SKIP_GODOT_PREPUSH=1 git push   or   git push --no-verify"
