# -*- coding: utf-8 -*-
"""Committed regression tests for the stage7 Akamu staging→verify→promote path.

Run: python tools/test_prepare_stage7_akamu_promotion.py
Exits non-zero on the first failure.  Covers the Codex review cases: exact
whitelist (extra-file rejection), manifest sha256/dup-state/path/grid checks,
manifest-last replacement ordering, and mid-set failure injection with full
rollback (no mixed live directory).
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
_SPEC = importlib.util.spec_from_file_location(
    "prepare_stage7_akamu_sprites", ROOT / "tools" / "prepare_stage7_akamu_sprites.py"
)
prep = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(prep)

FAILURES: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        FAILURES.append(message)
        print(f"FAIL: {message}")


def expect_value_error(fn, message: str) -> None:
    try:
        fn()
    except ValueError:
        return
    check(False, message)


def build_valid_staging(base: Path) -> Path:
    staging = base / "staging"
    staging.mkdir(parents=True)
    assets = []
    for key in prep.SOURCE_FILES:
        sheet_path = staging / f"stage7_akamu_boss_{key}.png"
        image = Image.new("RGBA", (prep.OUTPUT_CELL_SIZE * prep.OUTPUT_COLS, prep.OUTPUT_CELL_SIZE * prep.OUTPUT_ROWS))
        image.putpixel((0, 0), (len(key) % 256, 0, 0, 255))
        image.save(sheet_path)
        assets.append({
            "state": key,
            "path": f"res://assets/sprites/bosses/stage7_akamu/stage7_akamu_boss_{key}.png",
            "cols": prep.OUTPUT_COLS,
            "rows": prep.OUTPUT_ROWS,
            "frames": prep.FRAME_COUNT,
            "cell_width": prep.OUTPUT_CELL_SIZE,
            "cell_height": prep.OUTPUT_CELL_SIZE,
            "width": prep.OUTPUT_CELL_SIZE * prep.OUTPUT_COLS,
            "height": prep.OUTPUT_CELL_SIZE * prep.OUTPUT_ROWS,
            "sha256": hashlib.sha256(sheet_path.read_bytes()).hexdigest(),
        })
    (staging / prep.MANIFEST_NAME).write_text(
        json.dumps({"assets": assets}, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return staging


def rewrite_manifest(staging: Path, mutate) -> None:
    manifest = json.loads((staging / prep.MANIFEST_NAME).read_text(encoding="utf-8"))
    mutate(manifest)
    (staging / prep.MANIFEST_NAME).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def snapshot_dir(path: Path) -> dict[str, str]:
    return {
        child.name: hashlib.sha256(child.read_bytes()).hexdigest()
        for child in path.iterdir()
        if child.is_file()
    }


def make_live_with_old_set(base: Path) -> Path:
    live = base / "live"
    live.mkdir(parents=True, exist_ok=True)
    for name in prep._expected_export_files():
        (live / name).write_bytes(b"OLD:" + name.encode("utf-8"))
    return live


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)

        # 1) incomplete set rejected
        staging = build_valid_staging(tmp / "case1")
        (staging / "stage7_akamu_boss_stun.png").unlink()
        expect_value_error(lambda: prep._verify_staged_export(staging), "incomplete set must be rejected")

        # 2) extra (foreign importer sidecar) file rejected
        staging = build_valid_staging(tmp / "case2")
        (staging / "foreign.import").write_text("stale", encoding="utf-8")
        expect_value_error(lambda: prep._verify_staged_export(staging), "extra non-contract file must be rejected")

        # 3) manifest sha256 mismatch rejected
        staging = build_valid_staging(tmp / "case3")
        rewrite_manifest(staging, lambda m: m["assets"][0].__setitem__("sha256", "0" * 64))
        expect_value_error(lambda: prep._verify_staged_export(staging), "manifest sha256 mismatch must be rejected")

        # 4) duplicate asset states rejected
        staging = build_valid_staging(tmp / "case4")
        rewrite_manifest(staging, lambda m: m["assets"].append(dict(m["assets"][0])))
        expect_value_error(lambda: prep._verify_staged_export(staging), "duplicate manifest states must be rejected")

        # 5) wrong grid field rejected
        staging = build_valid_staging(tmp / "case5")
        rewrite_manifest(staging, lambda m: m["assets"][2].__setitem__("frames", 9))
        expect_value_error(lambda: prep._verify_staged_export(staging), "wrong grid/frame field must be rejected")

        # 6) wrong asset path rejected
        staging = build_valid_staging(tmp / "case6")
        rewrite_manifest(staging, lambda m: m["assets"][3].__setitem__("path", "res://wrong.png"))
        expect_value_error(lambda: prep._verify_staged_export(staging), "wrong manifest asset path must be rejected")

        # 7) valid set verifies and promotes atomically over an old live set
        staging = build_valid_staging(tmp / "case7")
        prep._verify_staged_export(staging)
        staged_snapshot = snapshot_dir(staging)
        live = make_live_with_old_set(tmp / "case7")
        prep._promote_staged_export(staging, live)
        check(snapshot_dir(live) == staged_snapshot, "promotion must land exactly the staged whitelist set")
        check(not staging.exists(), "promotion must consume the staging directory")

        # 8) manifest must be the LAST replacement
        staging = build_valid_staging(tmp / "case8")
        live = make_live_with_old_set(tmp / "case8")
        order: list[str] = []
        original_replace = prep._replace_file

        def recording_replace(source: Path, destination: Path) -> None:
            order.append(destination.name)
            original_replace(source, destination)

        prep._replace_file = recording_replace
        try:
            prep._promote_staged_export(staging, live)
        finally:
            prep._replace_file = original_replace
        check(len(order) == 10 and order[-1] == prep.MANIFEST_NAME, "manifest must be replaced last")

        # 9) mid-set failure injection → full rollback, live untouched
        staging = build_valid_staging(tmp / "case9")
        live = make_live_with_old_set(tmp / "case9")
        old_snapshot = snapshot_dir(live)
        calls = {"n": 0}

        def failing_replace(source: Path, destination: Path) -> None:
            calls["n"] += 1
            if calls["n"] == 7:
                raise OSError("injected mid-set failure")
            original_replace(source, destination)

        prep._replace_file = failing_replace
        raised = False
        try:
            prep._promote_staged_export(staging, live)
        except OSError:
            raised = True
        finally:
            prep._replace_file = original_replace
        check(raised, "mid-set failure must propagate")
        check(snapshot_dir(live) == old_snapshot, "mid-set failure must roll the live directory back to the pre-promotion set")

        # 10) mid-set failure with an EMPTY live directory → rollback removes partial files
        staging = build_valid_staging(tmp / "case10")
        live = tmp / "case10" / "live"
        live.mkdir(parents=True)
        calls["n"] = 0
        prep._replace_file = failing_replace
        raised = False
        try:
            prep._promote_staged_export(staging, live)
        except OSError:
            raised = True
        finally:
            prep._replace_file = original_replace
        check(raised, "mid-set failure on empty live must propagate")
        check(snapshot_dir(live) == {}, "mid-set failure on empty live must leave no partial files behind")

    if FAILURES:
        print(f"{len(FAILURES)} failure(s)")
        return 1
    print("test_prepare_stage7_akamu_promotion: ok (10 cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
