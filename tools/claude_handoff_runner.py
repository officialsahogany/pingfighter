import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run a Claude handoff prompt file and save outputs under .tmp/automation."
    )
    parser.add_argument(
        "handoff_path",
        nargs="?",
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--handoff",
        help="Path to the handoff markdown/text file to send to Claude.",
    )
    parser.add_argument(
        "--output-root",
        default=".tmp/automation",
        help="Directory where automation job artifacts are written.",
    )
    parser.add_argument(
        "--model",
        default="sonnet",
        help="Claude model alias or full model name. Default: sonnet",
    )
    parser.add_argument(
        "--permission-mode",
        default="acceptEdits",
        help="Claude permission mode. Default: acceptEdits",
    )
    parser.add_argument(
        "--label",
        default=None,
        help="Optional human-friendly job label. Defaults to the handoff stem.",
    )
    parser.add_argument(
        "--append-prompt",
        default=None,
        help="Optional extra text appended after the handoff file contents.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Prepare job metadata without launching Claude.",
    )
    return parser


def sanitize_label(value: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in ("-", "_") else "-" for ch in value)
    safe = safe.strip("-_")
    return safe or "claude-job"


def resolve_claude_executable() -> str:
    for candidate in ("claude", "claude.cmd", "claude.ps1"):
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise FileNotFoundError("Could not find Claude CLI on PATH.")


def read_handoff(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def resolve_repo_path(value: str, repo_root: Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path.resolve()
    return (repo_root / path).resolve()


def build_job_dir(output_root: Path, label: str) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    job_dir = (output_root / f"{timestamp}_{label}").resolve()
    job_dir.mkdir(parents=True, exist_ok=False)
    return job_dir


def write_latest_pointer(output_root: Path, job_dir: Path) -> None:
    latest_dir = (output_root / "latest").resolve()
    latest_dir.mkdir(parents=True, exist_ok=True)
    (latest_dir / "last_job.txt").write_text(str(job_dir), encoding="utf-8")


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    handoff_value = args.handoff or args.handoff_path
    if not handoff_value:
        parser.print_help(sys.stderr)
        print(
            "\nExample:\n"
            "  py -3 tools\\claude_handoff_runner.py --handoff .tmp\\example_handoff.md\n"
            "  .\\tools\\run_claude_handoff.ps1 .tmp\\example_handoff.md",
            file=sys.stderr,
        )
        return 2

    repo_root = Path(__file__).resolve().parents[1]
    handoff_path = resolve_repo_path(handoff_value, repo_root)
    if not handoff_path.exists():
        parser.error(f"Handoff file not found: {handoff_path}")

    label = sanitize_label(args.label or handoff_path.stem)
    output_root = resolve_repo_path(args.output_root, repo_root)
    job_dir = build_job_dir(output_root, label)

    handoff_text = read_handoff(handoff_path)
    prompt_text = handoff_text
    if args.append_prompt:
        prompt_text = f"{handoff_text.rstrip()}\n\n{args.append_prompt.strip()}\n"

    prompt_copy_path = job_dir / "prompt.md"
    stdout_path = job_dir / "response.txt"
    stderr_path = job_dir / "stderr.txt"
    metadata_path = job_dir / "job.json"

    write_text(prompt_copy_path, prompt_text)

    metadata = {
        "label": label,
        "handoff_path": str(handoff_path),
        "job_dir": str(job_dir),
        "repo_root": str(repo_root),
        "model": args.model,
        "permission_mode": args.permission_mode,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "dry_run": args.dry_run,
        "status": "prepared",
        "command": [
            "claude",
            "-p",
            "<prompt-from-prompt.md>",
            "--output-format",
            "text",
            "--model",
            args.model,
            "--permission-mode",
            args.permission_mode,
        ],
    }

    if args.dry_run:
        write_text(stdout_path, "")
        write_text(stderr_path, "")
        metadata["status"] = "dry_run"
        write_json(metadata_path, metadata)
        write_latest_pointer(output_root, job_dir)
        print(str(job_dir))
        return 0

    try:
        claude_executable = resolve_claude_executable()
        metadata["command"][0] = claude_executable
        completed = subprocess.run(
            [
                claude_executable,
                "-p",
                prompt_text,
                "--output-format",
                "text",
                "--model",
                args.model,
                "--permission-mode",
                args.permission_mode,
            ],
            cwd=repo_root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            shell=False,
        )
    except Exception as exc:
        metadata["status"] = "launcher_error"
        metadata["error"] = repr(exc)
        write_text(stdout_path, "")
        write_text(stderr_path, repr(exc))
        metadata["finished_at"] = datetime.now().isoformat(timespec="seconds")
        write_json(metadata_path, metadata)
        write_latest_pointer(output_root, job_dir)
        print(str(job_dir))
        return 1

    write_text(stdout_path, completed.stdout)
    write_text(stderr_path, completed.stderr)
    metadata["status"] = "ok" if completed.returncode == 0 else "error"
    metadata["returncode"] = completed.returncode
    metadata["finished_at"] = datetime.now().isoformat(timespec="seconds")
    write_json(metadata_path, metadata)
    write_latest_pointer(output_root, job_dir)

    print(str(job_dir))
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
