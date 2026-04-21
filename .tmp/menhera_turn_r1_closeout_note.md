# Menhera Boss Turn — R1 Close-Out Note

Single entry point for the asset-side state of Stage 3 Menheragirl turn
work after the R1 decision. Written as the asset-side close-out — no
more generation passes for this branch, no code changes in this note's
scope.

---

## 1. TL;DR

- **Decision**: R1 accepted. Canonical walk = sole identity anchor.
  Turn V3 = runtime playback auxiliary sheet, **non-anchor**.
- **Cap ribbon side-accent drift**: accepted as runtime-only cosmetic
  deviation. Must not propagate to any other sheet.
- **Asset-side status**: **CLOSED for generation**. No more FLUX /
  AutoSprite / Gemini narrow passes on this branch.
- **Runtime status**: unchanged. Code still has `RENDER_TURN_FRAMES =
  False` and the 8×1 turn loader. Runtime migration to the 4×2 loader
  and the new turn asset is **Codex scope**, gated on local playback
  QA.

## 2. Decision pointers (authoritative)

| Topic | File |
|---|---|
| Asset-side R1 decision + accepted divergence + guardrails | [menhera_turn_r1_decision.md](menhera_turn_r1_decision.md) |
| Codex runtime migration plan + QA gates + rollback plan | [codex_menhera_turn_runtime_migration_handoff_v1.md](codex_menhera_turn_runtime_migration_handoff_v1.md) |

Those two files are authoritative. This note is the asset-side close-out
and the single file-index entry point; it defers policy to the two
files above.

## 3. Canonical-walk-only rule (guardrail)

Recorded in `menhera_turn_r1_decision.md` §Guardrails. Restated here so
the rule is impossible to miss when a future worker opens this `.tmp`
tree and starts from whichever file they land on first:

- `items/menhera_boss_sheet.png` is the **only** identity anchor for
  any future Menhera boss sprite regen (attack / dash / victory /
  defeat / any corrective pass).
- `items/menhera_boss_turn.png` / `.tmp/menhera_flux_kontext_peak_v3.png`
  / `.tmp/menhera_flux_kontext_peak_v4.png` / any other turn-derived
  asset is **NOT** to be used as an identity reference for those
  regens.
- If a new work needs a turn motion reference, turn V3 is a **motion /
  playback** reference only — never an identity reference.
- The cap side-accent ribbon is the cosmetic drift that this rule is
  specifically guarding against. It must not appear on attack / dash /
  victory / defeat sheets.

## 4. Non-anchor rule for turn V3 (guardrail)

- `turn V3` is accepted as the runtime playback candidate.
- `turn V3` is NOT canonical.
- `turn V3` does NOT promote the canonical walk's role as anchor.
- `turn V4` is rejected (lateral move vs V3 with extra pose/med-kit
  drifts, see V4 report).
- Any future art worker who is tempted to anchor a new sheet on turn
  V3 (or V4) must re-read `menhera_turn_r1_decision.md` first. If they
  still want to, the correct next step is NOT doing it — it is raising
  that desire back to the user, because propagating turn V3 drifts to
  the rest of the boss set is the exact failure mode R1 is preventing.

## 5. Asset-side backup / rollback policy

This policy covers **assets only**. Code / runtime rollback is in the
Codex handoff file.

### 5.1. What must be preserved (no overwrites)

| File | Role | Reason to preserve |
|---|---|---|
| `items/menhera_boss_sheet.png` / `.jpeg` | canonical walk | sole identity anchor — do NOT overwrite, even with a "cleaner" walk |
| `items/menhera_boss_turn.png` (current 10664×1536, 8×1) | **rollback backup** for the existing runtime loader | must stay in place until the Codex runtime migration lands AND local playback QA passes. If migration fails, runtime can fall back to this file without re-downloading |
| `items/menhera_boss_turn.jpeg` (if present) | rollback backup | same as above |
| `items/menhera_boss_victory.png` / `.jpeg` | quality / clarity-class reference | do NOT overwrite |
| `items/menhera_boss_attack.*`, `menhera_boss_dash.*`, `menhera_boss_defeat.*` | other Menhera sheets | out of scope for R1; unchanged |

### 5.2. What is the migration target

When Codex is ready to promote (see §6):

- `.tmp/menhera_flux_kontext_turn_sheet_v1.png` (2752×1536 publishing
  PNG, 4×2, matches canonical walk dims) → target for
  `items/menhera_boss_turn.png`
- `.tmp/menhera_flux_kontext_turn_sheet_v1.jpeg` → target for
  `items/menhera_boss_turn.jpeg`
- `.tmp/menhera_flux_kontext_turn_sheet_v1_nukki.png` is the
  nukki-cleaned version in case Codex prefers that over the direct
  PNG as the PNG swap target. Either the raw or the nukki-cleaned PNG
  is acceptable; they are both 2752×1536.

### 5.3. Rollback triggers (asset side)

If any of these are seen during or after Codex migration, roll back
the asset swap (restore `items/menhera_boss_turn.*` from git / local
backup, set `RENDER_TURN_FRAMES = False`) and file the issue:

- 4-bow count reads as 3 or less at any gameplay frame
- pink paw pads disappear on any gameplay frame
- med-kit pouch disappears or changes hip side on any gameplay frame
- any turn frame reads as a different character from the canonical walk
- face/forehead clipped-looking read reappears on any gameplay frame
- stable walk gets hijacked by turn playback (turn dominates the cycle)
- hop-only fallback stops working when `RENDER_TURN_FRAMES = False`

Rollback does **not** re-open the asset-side generation branch.
Rollback means "use the existing 8×1 turn asset at runtime again and
keep hop-only fallback as today."

## 6. What's next (Codex scope, NOT this Claude pass)

Detail is in [codex_menhera_turn_runtime_migration_handoff_v1.md](codex_menhera_turn_runtime_migration_handoff_v1.md).
Short form:

1. Flip turn loader to 4×2 in
   [entities/menhera_boss_sprite.py:48-53](../entities/menhera_boss_sprite.py#L48-L53)
   (`TURN_GRID_COLS = 4`, `TURN_GRID_ROWS = 2`, explicit 8-pair
   `TURN_FRAME_ORDER`).
2. Keep `RENDER_TURN_FRAMES = False` during migration.
3. Swap `items/menhera_boss_turn.{jpeg,png}` from this note's
   publishing candidate paths.
4. Temporarily enable visible turn playback to run local QA (slicing,
   scale, reconnect, no face clipping, no stable-walk hijack).
5. Return `RENDER_TURN_FRAMES` to `False` at shipping default unless
   the user explicitly asks to ship with visible turn playback.
6. If QA fails: asset-side rollback per §5.3 and keep hop-only.

## 7. Asset file index (what's in `.tmp/` and `items/`)

Grouped by role. Not exhaustive for every diagnostic crop; the reports
in §7.5 already catalog their own crops.

### 7.1. Canonical source-of-truth assets (`items/`)

| File | Size | Role |
|---|---|---|
| `items/menhera_boss_sheet.png` | 2752×1536 (4×2, 688×768/cell) | canonical walk + sole identity anchor |
| `items/menhera_boss_sheet.jpeg` | (if present) | walk JPEG |
| `items/menhera_boss_turn.png` | 10664×1536 (8×1) | **rollback backup** — current runtime asset until Codex migration |
| `items/menhera_boss_turn.jpeg` | (if present) | rollback JPEG |
| `items/menhera_boss_victory.png` | 2752×1536 (4×2) | quality / clarity-class reference |

### 7.2. Publishing candidates (migration targets)

| File | Role |
|---|---|
| [`menhera_flux_kontext_turn_sheet_v1.png`](menhera_flux_kontext_turn_sheet_v1.png) | 2752×1536 4×2 candidate for `items/menhera_boss_turn.png` |
| [`menhera_flux_kontext_turn_sheet_v1.jpeg`](menhera_flux_kontext_turn_sheet_v1.jpeg) | JPEG candidate for `items/menhera_boss_turn.jpeg` |
| [`menhera_flux_kontext_turn_sheet_v1_nukki.png`](menhera_flux_kontext_turn_sheet_v1_nukki.png) | `remove_bg.py`-cleaned RGBA PNG, alt migration target |

### 7.3. Frame sources (one PNG per cell)

Used to stitch the publishing sheet in §7.2. Order: f1 = (0,0), f4 =
peak v3 at (3,0), f8 = f1 reuse at (3,1).

| Frame | File | Note |
|---|---|---|
| f1 (carry-in) | [`menhera_flux_kontext_turn_f1_v1.png`](menhera_flux_kontext_turn_f1_v1.png) | also reused as f8 |
| f2 (plant) | [`menhera_flux_kontext_turn_f2_v1.png`](menhera_flux_kontext_turn_f2_v1.png) | |
| f3 (wind-up) | [`menhera_flux_kontext_turn_f3_v1.png`](menhera_flux_kontext_turn_f3_v1.png) | |
| f4 (peak, ACCEPTED ANCHOR) | [`menhera_flux_kontext_peak_v3.png`](menhera_flux_kontext_peak_v3.png) | runtime playback asset role (non-anchor per §4) |
| f5 (rebound) | [`menhera_flux_kontext_turn_f5_v1.png`](menhera_flux_kontext_turn_f5_v1.png) | |
| f6 (recovery) | [`menhera_flux_kontext_turn_f6_v1.png`](menhera_flux_kontext_turn_f6_v1.png) | |
| f7 (settle) | [`menhera_flux_kontext_turn_f7_v1.png`](menhera_flux_kontext_turn_f7_v1.png) | |
| f8 (loop close) | same file as f1 | f1 reuse — no separate PNG |

NOTE on peak: the frame files above were originally generated against
peak **V2** as their anchor, not V3. R1 accepts the publishing candidate
stitched against that lineage because V3 is effectively V2 with the
sock-top pink-accent band stripped, and the publishing stitch treats
the V3 peak as the anchor frame only (f4 cell), not as the regen anchor
for the other seven frames. If a future Codex local-QA pass surfaces a
visible mismatch between f4 (V3) and f1/f2/f3/f5/f6/f7 (V2-lineage),
the correct response is to rebuild the publishing stitch with peak V2
as f4 instead (sock accent returns, but the sheet becomes internally
consistent) — not to re-open generation. The user explicitly closed
asset-side generation under R1.

### 7.4. Reference inputs used during generation

| File | Role |
|---|---|
| [`menhera_autosprite_reference_board_v2.png`](menhera_autosprite_reference_board_v2.png) | dense identity board used as FLUX secondary reference |
| `items/menhera_boss_sheet.png` | canonical walk as FLUX secondary reference |
| `items/menhera_boss_victory.png` | clarity-class reference |

### 7.5. QA reports and renders (history / audit trail)

Read these top-to-bottom for the full evolution. Later reports assume
earlier ones.

| File | What it documents |
|---|---|
| [`menhera_turn_autosprite_v1_report.md`](menhera_turn_autosprite_v1_report.md) | AutoSprite V1 — rejected (generic nurse drift) |
| [`menhera_turn_autosprite_v2_report.md`](menhera_turn_autosprite_v2_report.md) | AutoSprite V2 — motion ideation only, not final renderer |
| [`menhera_flux_kontext_peak_v1_report.md`](menhera_flux_kontext_peak_v1_report.md) | FLUX peak V1 — first usable identity + pixel class |
| [`menhera_flux_kontext_peak_v2_report.md`](menhera_flux_kontext_peak_v2_report.md) | FLUX peak V2 — 4-bow locked |
| [`menhera_flux_kontext_turn_frame_expansion_v1_report.md`](menhera_flux_kontext_turn_frame_expansion_v1_report.md) | 8-frame expansion pass (f1/f2/f3/f5/f6/f7 + f4 peak + f8 reuse) |
| [`menhera_flux_kontext_turn_publish_qa_v1_report.md`](menhera_flux_kontext_turn_publish_qa_v1_report.md) | 4×2 publishing candidate + edge QA + gameplay-scale QA + strict drift judgment |
| [`menhera_flux_kontext_peak_v3_report.md`](menhera_flux_kontext_peak_v3_report.md) | Narrow touch-up V3 — sock fix PASS, cap ribbon fail, minor pose drift |
| [`menhera_flux_kontext_peak_v4_report.md`](menhera_flux_kontext_peak_v4_report.md) | Narrow touch-up V4 — lateral move; end of generation branch |

Key gameplay-scale QA renders worth saving for Codex's local playback
QA reference:

- [`menhera_flux_kontext_turn_sheet_v1_gameplay_4x.png`](menhera_flux_kontext_turn_sheet_v1_gameplay_4x.png)
- [`menhera_flux_kontext_turn_vs_walk_paired_4x.png`](menhera_flux_kontext_turn_vs_walk_paired_4x.png)
- [`menhera_turn_walk_pair_f1_6x.png`](menhera_turn_walk_pair_f1_6x.png),
  [`menhera_turn_walk_pair_f4_peak_6x.png`](menhera_turn_walk_pair_f4_peak_6x.png),
  [`menhera_turn_walk_pair_f7_settle_6x.png`](menhera_turn_walk_pair_f7_settle_6x.png)

### 7.6. Handoff prompt archive (closed chain)

These are the user-authored handoffs that drove the branch. Kept as
a read-only history of the decision chain; no future action required
on them.

| File | Purpose |
|---|---|
| [`claude_menhera_turn_autosprite_handoff_prompt_v1.md`](claude_menhera_turn_autosprite_handoff_prompt_v1.md) | AutoSprite V1 brief |
| [`claude_menhera_turn_autosprite_handoff_prompt_v2.md`](claude_menhera_turn_autosprite_handoff_prompt_v2.md) | AutoSprite V2 (dense board) brief |
| [`claude_menhera_turn_flux_kontext_handoff_prompt_v1.md`](claude_menhera_turn_flux_kontext_handoff_prompt_v1.md) | FLUX peak V1 brief |
| [`claude_menhera_turn_flux_kontext_peak_v2_handoff_prompt.md`](claude_menhera_turn_flux_kontext_peak_v2_handoff_prompt.md) | FLUX peak V2 (4-bow) brief |
| [`claude_menhera_turn_flux_kontext_frame_expansion_handoff_v1.md`](claude_menhera_turn_flux_kontext_frame_expansion_handoff_v1.md) | Frame expansion brief |
| [`claude_menhera_turn_flux_kontext_publish_qa_handoff_v1.md`](claude_menhera_turn_flux_kontext_publish_qa_handoff_v1.md) | Publish QA brief + stricter drift rule |
| [`claude_menhera_turn_flux_kontext_peak_v3_touchup_handoff.md`](claude_menhera_turn_flux_kontext_peak_v3_touchup_handoff.md) | V3 narrow touch-up brief |
| [`claude_menhera_turn_flux_kontext_peak_v4_cap_only_touchup_handoff.md`](claude_menhera_turn_flux_kontext_peak_v4_cap_only_touchup_handoff.md) | V4 cap-only touch-up brief |
| [`claude_menhera_turn_r1_closeout_handoff.md`](claude_menhera_turn_r1_closeout_handoff.md) | This close-out brief |

## 8. Explicit "no more asset-side tests" marker

- No more FLUX Kontext narrow passes on this branch.
- No more AutoSprite passes on this branch.
- No more Gemini passes on this branch.
- No more framewise stitching experiments on this branch.
- No manual pixel-composite cap surgery on this branch under R1
  (R3 is logged in the V4 report as an option but was NOT selected —
  R1 was).
- If a future pass is opened to replace turn V3, it must be opened as
  a new branch with a new handoff and must restate the canonical-walk-
  only rule; it cannot inherit that turn V3 drifts as baseline.

## 9. Close-out report (answers to the handoff's §최종 보고 형식)

1. **Decision / note files written or confirmed**:
   - Existing: [`menhera_turn_r1_decision.md`](menhera_turn_r1_decision.md),
     [`codex_menhera_turn_runtime_migration_handoff_v1.md`](codex_menhera_turn_runtime_migration_handoff_v1.md).
   - New (this pass): [`menhera_turn_r1_closeout_note.md`](menhera_turn_r1_closeout_note.md) —
     single entry point tying R1 decision + Codex migration + backup /
     rollback policy + asset file index together.
2. **Canonical-walk-only rule recorded where**:
   - `menhera_turn_r1_decision.md` §Guardrails (authoritative).
   - `codex_menhera_turn_runtime_migration_handoff_v1.md` §Policy Guardrail
     (runtime-phrased).
   - `menhera_turn_r1_closeout_note.md` §3 (close-out restatement) and
     §4 (non-anchor rule for turn V3).
3. **Runtime migration: what Codex has to do**:
   - Flip turn loader from 8×1 to 4×2 in
     [entities/menhera_boss_sprite.py:48-53](../entities/menhera_boss_sprite.py#L48-L53).
   - Keep `RENDER_TURN_FRAMES = False` during migration.
   - Swap `items/menhera_boss_turn.{jpeg,png}` from the publishing
     candidates (see §5.2 / §7.2).
   - Run local playback QA per
     `codex_menhera_turn_runtime_migration_handoff_v1.md` checklist.
   - Keep the old 8×1 asset as rollback backup.
   - Return shipping default to `RENDER_TURN_FRAMES = False` unless
     the user explicitly asks to ship with visible turn playback.
4. **Is there any asset-side test still worth doing?**
   - **No.** Asset-side is closed under R1. The Menhera turn branch is
     now waiting on Codex runtime migration, not on more assets.
