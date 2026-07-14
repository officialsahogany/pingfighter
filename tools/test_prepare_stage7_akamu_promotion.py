# -*- coding: utf-8 -*-
"""Committed regression tests for the stage7 Akamu staging/verification path.

Run: python tools/test_prepare_stage7_akamu_promotion.py
Exits non-zero on the first failure.

The tool has NO live-promotion path (removed 2026-07-14 — per-file replacement
cannot be made set-atomic against interrupts).  These tests seal:
- the staged-set verification rejections (missing/extra file, sheet raster,
  manifest sha256 / duplicate state / path / grid fields),
- the manifest policy-string seal (a re-run cannot roll back the demotion /
  provenance notes), and
- the no-promotion-entry-point guard (the module must never regrow a
  promotion helper or a --promote flag).
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
TOOL_PATH = ROOT / "tools" / "prepare_stage7_akamu_sprites.py"
_SPEC = importlib.util.spec_from_file_location("prepare_stage7_akamu_sprites", TOOL_PATH)
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
        image = Image.new(
            "RGBA",
            (prep.OUTPUT_CELL_SIZE * prep.OUTPUT_COLS, prep.OUTPUT_CELL_SIZE * prep.OUTPUT_ROWS),
        )
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
    manifest = {
        "postprocess": prep.MANIFEST_POSTPROCESS_NOTE,
        "native_direction_policy": prep.MANIFEST_NATIVE_DIRECTION_POLICY,
        "assets": assets,
    }
    (staging / prep.MANIFEST_NAME).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return staging


def rewrite_manifest(staging: Path, mutate) -> None:
    manifest = json.loads((staging / prep.MANIFEST_NAME).read_text(encoding="utf-8"))
    mutate(manifest)
    (staging / prep.MANIFEST_NAME).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)

        # 1) valid staged set verifies clean
        staging = build_valid_staging(tmp / "case_ok")
        prep._verify_staged_export(staging)

        # 2) incomplete set rejected
        staging = build_valid_staging(tmp / "case_missing")
        (staging / "stage7_akamu_boss_stun.png").unlink()
        expect_value_error(lambda: prep._verify_staged_export(staging), "incomplete set must be rejected")

        # 3) extra (foreign importer sidecar) file rejected
        staging = build_valid_staging(tmp / "case_extra")
        (staging / "foreign.import").write_text("stale", encoding="utf-8")
        expect_value_error(lambda: prep._verify_staged_export(staging), "extra non-contract file must be rejected")

        # 4) wrong raster size rejected
        staging = build_valid_staging(tmp / "case_raster")
        Image.new("RGBA", (512, 512)).save(staging / "stage7_akamu_boss_attack.png")
        expect_value_error(lambda: prep._verify_staged_export(staging), "wrong sheet raster must be rejected")

        # 5) manifest sha256 mismatch rejected
        staging = build_valid_staging(tmp / "case_hash")
        rewrite_manifest(staging, lambda m: m["assets"][0].__setitem__("sha256", "0" * 64))
        expect_value_error(lambda: prep._verify_staged_export(staging), "manifest sha256 mismatch must be rejected")

        # 6) duplicate asset states rejected
        staging = build_valid_staging(tmp / "case_dup")
        rewrite_manifest(staging, lambda m: m["assets"].append(dict(m["assets"][0])))
        expect_value_error(lambda: prep._verify_staged_export(staging), "duplicate manifest states must be rejected")

        # 7) wrong grid field rejected
        staging = build_valid_staging(tmp / "case_grid")
        rewrite_manifest(staging, lambda m: m["assets"][2].__setitem__("frames", 9))
        expect_value_error(lambda: prep._verify_staged_export(staging), "wrong grid/frame field must be rejected")

        # 8) wrong asset path rejected
        staging = build_valid_staging(tmp / "case_path")
        rewrite_manifest(staging, lambda m: m["assets"][3].__setitem__("path", "res://wrong.png"))
        expect_value_error(lambda: prep._verify_staged_export(staging), "wrong manifest asset path must be rejected")

        # 9) policy-string seal: a manifest that rolls back the demotion note is rejected
        staging = build_valid_staging(tmp / "case_policy_post")
        rewrite_manifest(staging, lambda m: m.__setitem__(
            "postprocess",
            "tools/prepare_stage7_akamu_sprites.py; one fixed NEAREST transform per sheet.",
        ))
        expect_value_error(
            lambda: prep._verify_staged_export(staging),
            "postprocess rollback must be rejected by the policy seal",
        )
        staging = build_valid_staging(tmp / "case_policy_dir")
        rewrite_manifest(staging, lambda m: m.__setitem__(
            "native_direction_policy",
            "walk_left and walk_right are separate accepted AutoSprite motions.",
        ))
        expect_value_error(
            lambda: prep._verify_staged_export(staging),
            "direction-policy rollback must be rejected by the policy seal",
        )

        # 10) generator emits exactly the sealed policy strings — assert the
        # template dict literally references the shared constants (no inline
        # drift copies).
        tool_source = TOOL_PATH.read_text(encoding="utf-8")
        check(
            '"postprocess": MANIFEST_POSTPROCESS_NOTE' in tool_source
            and '"native_direction_policy": MANIFEST_NATIVE_DIRECTION_POLICY' in tool_source,
            "generator must emit the shared policy constants (no inline drift copies)",
        )

        # 11) live authoritative manifest matches the shared constants
        live_manifest_path = (
            ROOT / "godot" / "assets" / "sprites" / "bosses" / "stage7_akamu" / prep.MANIFEST_NAME
        )
        live_manifest = json.loads(live_manifest_path.read_text(encoding="utf-8"))
        check(
            str(live_manifest.get("postprocess", "")) == prep.MANIFEST_POSTPROCESS_NOTE,
            "live manifest postprocess must equal the shared constant",
        )
        check(
            str(live_manifest.get("native_direction_policy", "")) == prep.MANIFEST_NATIVE_DIRECTION_POLICY,
            "live manifest native_direction_policy must equal the shared constant",
        )

        # 12) no-promotion / no-arbitrary-write entry-point guard
        check(
            not hasattr(prep, "_promote_staged_export") and not hasattr(prep, "_replace_file"),
            "module must not expose a promotion helper",
        )
        check("--promote" not in tool_source, "tool must not expose a --promote flag")
        check(
            "--qa-output" not in tool_source,
            "tool must not expose an arbitrary QA output path (verified live-write bypass)",
        )
        check(
            "def prepare(source_dir: Path, output_dir: Path) -> " in tool_source,
            "prepare() must accept no promote/qa_path parameters",
        )

        # 13) E2E: synthetic sources → prepare() writes ONLY inside staging;
        # the real live directory (manifest + a sheet sentinel) is untouched.
        source_dir = tmp / "case_e2e_sources"
        source_dir.mkdir()
        for key, file_name in prep.SOURCE_FILES.items():
            source_image = Image.new(
                "RGBA", (prep.SOURCE_CELL_SIZE * 3, prep.SOURCE_CELL_SIZE * 3), (0, 0, 0, 0)
            )
            draw = ImageDraw.Draw(source_image)
            for frame_index in range(prep.FRAME_COUNT):
                col = frame_index % 3
                row = frame_index // 3
                x0 = col * prep.SOURCE_CELL_SIZE + 156
                y0 = row * prep.SOURCE_CELL_SIZE + 106
                draw.rectangle((x0, y0, x0 + 200, y0 + 300), fill=(200, 40, 40, 255))
            source_image.save(source_dir / file_name)
        live_dir = ROOT / "godot" / "assets" / "sprites" / "bosses" / "stage7_akamu"
        # 독립 리터럴 계약(SOURCE_FILES 파생 아님): 도구 쪽에서 state 하나가
        # 삭제되는 회귀가 나도 이 리터럴과의 대조가 잡는다.
        authoritative_files = [
            "stage7_akamu_boss_attack.png",
            "stage7_akamu_boss_dash_left.png",
            "stage7_akamu_boss_dash_right.png",
            "stage7_akamu_boss_defeat.png",
            "stage7_akamu_boss_idle.png",
            "stage7_akamu_boss_stun.png",
            "stage7_akamu_boss_victory.png",
            "stage7_akamu_boss_walk_left.png",
            "stage7_akamu_boss_walk_right.png",
            "stage7_akamu_boss_sprite_manifest.json",
        ]
        check(
            sorted(prep._expected_export_files()) == sorted(authoritative_files),
            "derived export whitelist must equal the independent 10-file literal contract",
        )
        # 라이브 센티널 = 디렉터리 '전체' 파일명 집합 + 각 파일 해시(기대
        # 10파일만 해싱하면 신규 파일 기록 회귀를 놓친다).
        sentinel_before = {
            path.relative_to(live_dir).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in live_dir.rglob("*")
            if path.is_file()
        }
        for name in authoritative_files:
            check(name in sentinel_before, f"authoritative live file missing before E2E: {name}")
        report = prep.prepare(source_dir, live_dir)
        e2e_staging = Path(report["staging_dir"])
        e2e_export = Path(report["export_dir"])
        try:
            sentinel_after = {
                path.relative_to(live_dir).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in live_dir.rglob("*")
                if path.is_file()
            }
            check(
                sentinel_before == sentinel_after,
                "prepare() must leave the ENTIRE live directory untouched (no new/changed/deleted files)",
            )
            check(
                str(e2e_staging).startswith(str(ROOT / ".tmp")),
                "prepare() staging must live under ROOT/.tmp (outside res://)",
            )
            check(
                e2e_export.parent == e2e_staging and e2e_export.name == "export",
                "runtime contract set must live in staging/export/",
            )
            check(
                Path(report["qa_report"]).parent == e2e_staging,
                "QA report must be a SIBLING of export/, inside the staging directory",
            )
            # QA 기록 후에도 export/는 정확한 계약 세트로 재검증 가능해야 한다.
            prep._verify_staged_export(e2e_export)
            staged_manifest = json.loads((e2e_export / prep.MANIFEST_NAME).read_text(encoding="utf-8"))
            check(
                staged_manifest.get("postprocess") == prep.MANIFEST_POSTPROCESS_NOTE
                and staged_manifest.get("native_direction_policy") == prep.MANIFEST_NATIVE_DIRECTION_POLICY,
                "E2E staged manifest must carry the sealed policy strings",
            )
            check(len(report["animations"]) == len(prep.SOURCE_FILES), "E2E should render all nine sheets")
        finally:
            shutil.rmtree(e2e_staging, ignore_errors=True)

    if FAILURES:
        print(f"{len(FAILURES)} failure(s)")
        return 1
    print("test_prepare_stage7_akamu_promotion: ok (13 cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
