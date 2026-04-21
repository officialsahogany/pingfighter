# Menhera Victory FLUX Kontext Full-Sheet — V1 Report

**Status: 8-FRAME DIRECT GENERATION MATERIALLY SUCCEEDED. Face / identity lock holds across all 8 cells — this was the primary risk and it cleared cleanly. One hard-reject drift remains: 4-bow count reads as 3 on every frame. At gameplay scale V1 is a CLEAR upgrade over the current live victory sheet. Recommendation: one narrow 4-bow touch-up pass first; if that fails, either relax bow-count rule under R1 anchor policy OR descend to framewise. Canonical overwrite NOT done. Runtime unchanged.**

## 1. Reference stack actually used

| Slot | File | Role |
|---|---|---|
| `input_image` | `items/menhera_boss_sheet.png` | **identity master** — sole canonical anchor per R1 |
| `input_image_2` | `items/menhera_boss_victory.png` | motion / celebration intent only (NOT identity master) |
| `input_image_3` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board for prop props preservation |

`items/menhera_boss_turn.png` was intentionally NOT used as a
reference. R1 explicitly bars turn-derived assets from serving as an
anchor or direct reference on future regens, and 8×1 turn layout has
no useful prop cues for a 4×2 victory sheet.

Model: `flux_kontext_max`, `aspect_ratio = 16:9`, `output_format = png`,
`safety_tolerance = 2`, seed not pinned. Output size: 1392×752 RGB.

## 2. Output files (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_v1.png` | 1392×752 RGB, 4×2 eight-frame victory sheet |
| `menhera_flux_kontext_victory_v1.jpeg` | JPEG q=95 export for future nukki / publishing |
| `menhera_flux_kontext_victory_v1_args.json` | FLUX request args log |
| `menhera_flux_kontext_victory_v1_zoom.png` | 4× nearest-neighbor zoom for QA readability |
| `menhera_flux_kontext_victory_v1_frame_{1..8}.png` | Per-frame 3× zooms |
| `menhera_victory_v1_bowstrip_audit.png` | 8-frame torso strip for bow-count audit |
| `menhera_victory_v1_hipstrip_audit.png` | 8-frame hip strip for med-kit audit |
| `menhera_flux_kontext_victory_v1_vs_current.png` | Side-by-side: new V1 (left) vs current live victory (right) |
| `menhera_flux_kontext_victory_v1_gameplay.png` | Gameplay-scale 3-row render (walk / V1 / current victory) |
| `menhera_flux_kontext_victory_v1_gameplay_4x.png` | 4× zoom of the above |
| `menhera_flux_kontext_victory_v1_report.md` | This report |

`items/menhera_boss_victory.{png,jpeg}` NOT overwritten. Runtime
untouched.

## 3. What improved vs current live victory

Read the 3-row gameplay-scale comparison (`..._gameplay_4x.png`):
row 1 is canonical walk, row 2 is new V1, row 3 is current live
`items/menhera_boss_victory.png`.

| Aspect | Current live victory | New V1 |
|---|---|---|
| Frame-to-frame face / identity | **drifts** — several cells read as visibly different Menhera (e.g. some closed-eye joyful face, some with different cheek blush, different hair treatment) | **consistent** — all 8 cells read as the same Menhera as the canonical walk |
| Eye / lash treatment | varies across frames | consistent, gray/silver with strong lashes on every cell |
| Hair color handling | varies (some cells look more saturated pink) | consistent pink outer + cream/blonde inner bangs on every cell |
| Cheek heart mark side | varies subtly | consistent on viewer-right cheek across all cells |
| Pose language | high-amplitude celebration (arms wide, eyes closed, ribbon flails) | conservative front-facing celebration arc (f1 neutral → f4/f5 raised paw peak → f7/f8 held satisfied) |
| Red-ribbon saturation | occasionally reads as unrelated-character cosplay ribbon | stays inside the canonical cap-accent language (small red accents on the gingham cap) |
| Gameplay-scale read vs walk | visibly different identity on several cells | sits in the same identity class as walk |

Net: V1 is a clear identity-lock upgrade over current live victory.
The biggest V1 vs current delta is exactly the thing current victory
was weakest on — "same Menhera across all 8 frames."

## 4. Canonical walk identity lock — per-item QA

| Locked element | Canonical walk | V1 result | Verdict |
|---|---|---|---|
| Fluffy pink outer hair + CREAM/BLONDE inner front bangs | present, asymmetric | present and consistent on all 8 cells | PASS |
| Rounded fluffy hair silhouette | present | present | PASS |
| Pink / white GINGHAM nurse cap | gingham check | gingham check | PASS |
| Red cross on cap | present | present on all cells | PASS |
| Small SYRINGE on cap | present | present on most cells, slightly reduced prominence on some but not lost | PASS (partial on brightness) |
| Red front ribbon language | single front-center | minor drift — cap shows small red accents on sides rather than a single front-center ribbon (same attractor seen on turn V2/V3/V4) | partial — identical in character to the drift R1 already accepted for turn |
| No black cat ears | absent | absent | PASS |
| Gray / silver eyes with strong lashes | present | present on all cells, highly consistent | PASS |
| ONE pink heart cheek mark on one cheek | one cheek (viewer-right) | on viewer-right cheek on every cell | PASS |
| Pink dress with white center front panel | present | present | PASS |
| **Exactly 4 black bows in vertical stack** | 4 | **3 visible on every cell** | **FAIL — hard-reject per handoff** |
| DARK GRAY cat-paw gloves | present | present | PASS |
| Visible pink paw pads | present | present on every cell where a paw is raised (f4, f5, f8 most clearly; others by glove edge) | PASS |
| White MED-KIT pouch with pink cross, same-side | present | present on cells where arm position does not occlude it (f3, f4, f6, f7, f8 clearly visible); occluded by arm/paw on f1, f2, f5 — which is natural for those celebration poses | PASS |
| Pink CHECK-PATTERN cloth-tail motif | present | present on every cell | PASS |
| PLAIN white thigh-high socks (no pink trim at top) | plain white | plain white, NO pink sock-top accent | PASS (R1 sock-top fix from turn V3 did NOT have to be re-applied here) |
| Black X ankle accessories | present | present | PASS |
| Thick black pixel outlines | thick | thick | PASS |
| 16-bit retro pixel-art clarity class | canonical | matches canonical | PASS |
| Body scale ±5% of walk | baseline | visually within ±5% — body reads same size as walk at gameplay scale | PASS |

**Face-drift-across-frames check** (the hardest risk of 8-frame
direct): PASS. All 8 cells hold the same Menhera face. No "hero frame"
becomes a cleaner / prettier-faced girl than the others. No bob-hair
simplification. No anime-soft regression.

## 5. The one hard-reject drift: 4-bow count

Every one of V1's 8 cells renders **3 black bows** stacked vertically on
the white center front panel, not 4. This is the same attractor we saw
on turn peak V1 (3 bows) and resolved on turn peak V2 (4 bows).

However, the structural context is different:
- Turn peak was a single 1024×1024 figure, giving FLUX a generous
  pixel budget to render all 4 bows.
- Victory V1 is 8 figures packed into 1392×752, so each figure is
  roughly 348×376. That is less pixel budget per torso than turn peak
  V2. FLUX appears to treat "3 bows" as the compact-rendering default
  at this per-cell size.

Under the handoff's hard-reject list, this 4→3 bow drift is a blocker
— but the handoff also offers the "descend to peak / framewise" path
specifically for when direct generation leaves one blocker.

## 6. Gameplay-scale reality check (matters for the recommendation)

At 79×88 per frame (sprite class's target size in
`entities/menhera_boss_sprite.py`), the bow count is **barely
distinguishable**. The publish-QA V1 report on turn already noted that
even the canonical walk's 4 bows often read as 3 after downscaling.

In the 3-row gameplay-scale render, V1's 3-bow panel and the canonical
walk's 4-bow panel both read as "short vertical dark-pixel stack on a
white chest panel." The user-facing readability impact at shipping
size is approximately zero.

This matters because the R1 policy specifically frames cap-ribbon drift
as an identity-anchor propagation problem rather than a gameplay-scale
problem. Bow-count drift on victory falls under the same frame:
- It IS a hard-reject per the handoff — cannot be ignored.
- It IS NOT a gameplay-readability problem at 79×88.
- It IS a propagation risk IF victory is ever used as an anchor for
  future regens. (But R1 already bars that.)

## 7. Is the direct 8-frame approach usable? — YES, with one caveat

Yes. The 8-frame direct pass confirmed what turn only confirmed
retroactively: **FLUX Kontext max can hold identity lock across 8 cells
in a single multi-reference pass** when the canonical walk is the
primary anchor. This is a meaningful validation of the user's new
workflow direction ("direct first, descend only when needed").

Caveat: detail density per cell is limited. 4 bows did not render,
consistent with per-cell pixel budget. Other high-frequency details
(syringe prominence, front-center vs side ribbon placement) also show
the same drift as seen on smaller-format turn outputs.

## 8. Promote-as-is, narrow touch-up, or descend? — recommendation

The handoff's own final-report gate is "바로 후보로 올릴 수 있는지,
아니면 peak/framewise 보정으로 내려가야 하는지". Three paths:

**Path P1 — One narrow 4-bow touch-up pass (recommended first step)**

- Model: `flux_kontext_max`, image-to-image edit
- Primary `input_image` = `.tmp/menhera_flux_kontext_victory_v1.png`
- Secondary: canonical walk, dense identity board, current victory
- Narrow instruction: "In every one of the 8 cells of the sheet, change
  the black bows on the white center front panel from 3 to EXACTLY 4.
  Add one more bow at the bottom of the existing vertical stack,
  matching the existing bow shape and spacing. Do NOT change anything
  else in any cell."
- Outcome space:
  - If FLUX lands 4 bows across the sheet: promote V2 as the new
    victory candidate, proceed to nukki + gameplay QA + Codex
    migration coordination.
  - If FLUX resists (likely, based on 3 narrow-pass data points from
    the turn branch): fall through to P2 or P3.

**Path P2 — Accept 3-bow under a relaxed rule (fallback if P1 fails)**

- Reread R1: canonical walk is sole identity anchor. Victory is NOT an
  anchor. Bow-count drift on a non-anchor sheet cannot propagate to
  attack / dash / defeat regens because those regens are built off
  walk, not victory.
- At 79×88 shipping size, 3 vs 4 bows is perceptually identical.
- Under that reading, V1's 3-bow count is the exact same class of
  drift as turn's cap side-accent ribbons — runtime-only cosmetic
  deviation that stops at this sheet.
- If adopted, promote V1 directly and let Codex migrate
  `items/menhera_boss_victory.{png,jpeg}` once local playback QA
  passes.

**Path P3 — Descend to peak + framewise (guaranteed but expensive)**

- If both P1 and P2 feel wrong, fall back to the turn workflow: peak
  V1 first (1024×1024, 4-bow guaranteed), then narrow touch-ups as
  needed, then 7 derived frames, then 4×2 stitch, then nukki, then
  gameplay QA.
- Cost: ~8+ FLUX calls, plus stitch / nukki / QA effort.
- Confidence: high — turn workflow proved this pipeline works.
- Risk: framewise generation might introduce the face-drift-across-
  frames problem that direct generation just avoided. Turn had 8
  faces all very similar because V3 was used as the common anchor;
  for victory, we'd need to pick whichever V1 frame lands cleanest
  and use it as the framewise anchor.

My recommendation: **try P1 first** (one narrow pass, low cost), and
if it does not land cleanly, **go to P2** (accept 3-bow as cosmetic).
P3 is the most-conservative fallback but is the most expensive and is
not strictly necessary given that V1 at gameplay scale is already a
clear upgrade over current live victory.

## 9. Canonical overwrite?

**No.** `items/menhera_boss_victory.{png,jpeg}` NOT overwritten in
this pass. Promotion waits on P1 / P2 / P3 outcome.

Runtime policy unchanged:
- `entities/menhera_boss_sprite.py` victory loader is at
  `VICTORY_SHEET_PATH_PNG = items/menhera_boss_victory.png`
  and assumes 4×2 (like walk), so the publishing target dimensions
  should match canonical walk at 2752×1536 before overwrite. V1 is
  currently 1392×752 — this needs a separate publishing stitch /
  upscale step before it can actually replace the live asset, even
  after the 4-bow decision.
- If the user chooses P2 (accept 3-bow), the next step is: upscale
  or re-stitch V1 to 2752×1536, do JPEG export, run `remove_bg.py`
  nukki, then hand off to Codex for swap. Mirrors the turn publish-QA
  pipeline.

## 10. Codex handoff note (no runtime change in this pass)

```
FLUX Kontext victory full-sheet V1 completed. Face / identity lock holds
across all 8 cells at gameplay scale. One drift remaining: 4-bow count
renders as 3 on every cell. Canonical victory asset + runtime unchanged.

- items/menhera_boss_sheet.png                         -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                       -> current live victory (unchanged; V1 is a clear identity-lock upgrade)
- items/menhera_boss_turn.png                          -> previous 8x1 turn (unchanged, separate R1 branch)
- .tmp/menhera_flux_kontext_victory_v1.png             -> NEW candidate (NOT for runtime)
- .tmp/menhera_flux_kontext_victory_v1.jpeg            -> JPEG for future nukki input
- .tmp/menhera_flux_kontext_victory_v1_gameplay_4x.png -> 3-row gameplay-scale QA (walk / V1 / current victory)
- .tmp/menhera_victory_v1_bowstrip_audit.png           -> 8-cell bow-count audit (confirms 3 across all 8)
- .tmp/menhera_flux_kontext_victory_v1_report.md       -> QA report

Pending before any victory runtime migration:
- 4-bow decision (P1 narrow pass, P2 relax rule, or P3 descend)
- publishing stitch / upscale from 1392x752 to 2752x1536 (to match
  canonical walk dims if accepted)
- JPEG + remove_bg.py nukki + gameplay QA

No runtime changes in this pass. No code edits. Turn branch remains
closed under R1 per the asset-side close-out note.
```

## 11. Summary (one-screen read)

- Reference stack: canonical walk (primary), current victory (motion
  intent only), dense identity board.
- Improvements over current live victory: **major identity-lock
  upgrade** — V1 reads as the same Menhera across all 8 cells, current
  live victory does not.
- Canonical walk face / identity lock: **PASS except for 4→3 bow-count
  drift**. Front-ribbon is side-accent (same drift as turn, within R1
  policy).
- 8-frame direct generation usable: **YES**. This is a meaningful
  validation of the direct-first workflow.
- Promotion recommendation: **P1 narrow 4-bow touch-up first; if it
  fails, P2 accept 3-bow as cosmetic drift (non-anchor victory)**.
  P3 framewise descent is the conservative fallback but not required.
- Canonical overwrite: NOT DONE. Runtime unchanged.
