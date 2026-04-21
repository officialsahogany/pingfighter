# Menhera Victory FLUX Kontext V2 Bow-Only Touch-Up Report

**Status: FAILED — NOT LATERAL MOVE, CATASTROPHIC LAYOUT DRIFT. FLUX restructured the 4×2 sheet into an irregular multi-row mixed-size layout. V2 is unusable as a publishing candidate. Recommendation per the handoff: GO TO P2 — accept V1's 3-bow as cosmetic runtime drift because victory is a non-anchor sheet under R1.**

## 1. Fourth-bow correction — did it succeed?

**No — question is not even applicable.** V2 abandoned the 4×2 layout
entirely. Per-cell bow-count analysis cannot be performed because the
cells are no longer uniform or in a recoverable grid.

What FLUX produced:

- Top band: a row of ~4 small Menhera figures in a tight strip
- Middle band: a row of larger Menhera figures (~4) with different
  celebration poses
- Bottom area: irregular mix — some larger figures on the left side,
  then a vertical stack of 2 very-small figures near the bottom-right,
  then a strange **vertical stack of face / torso crops** in a thin
  column at the far right

The output reads more like a "reference sheet" or "character
exploration sheet" than a usable 4×2 sprite sheet. It cannot be sliced
by any existing 4×2 or any other grid loader.

## 2. Collateral drift — did everything else stay put?

No. Because the layout was restructured, nearly every per-frame
preservation check fails:

| Watched element | V1 | V2 |
|---|---|---|
| 4×2 grid layout | intact | **broken** — irregular multi-row, mixed cell sizes, an orphan column of crops on the right |
| Consistent per-cell size | 348×376 uniform | non-uniform; some figures ~2× larger than others |
| 8 figures total | exactly 8 | ~14–16 figures plus a column of face / torso crops |
| Face consistency across cells | strong — all 8 same Menhera | difficult to judge; some figures have softer/rounder faces than others |
| Per-cell pose continuity (f1 → f8 celebration arc) | clean arc | broken — figures now include side-facing 3/4 reads and a closed-eye joyful face that wasn't in the V1 plan |
| Plain white thigh-highs | present | appears to still be plain white on most figures, but the sample size is now non-standard |
| Other props | all PASS on V1 | not individually auditable given the broken grid |

FLUX **did** also adjust character density / composition in ways not
asked for:
- Some figures appear to have closed eyes (happy-face celebration) —
  this is a face-drift regression V1 had avoided.
- Some figures show a small pink accent / bow at the thigh-high sock
  top, re-introducing the drift R1 specifically stripped.
- Some figures are noticeably smaller than others — a cross-cell body
  scale break.

None of this was asked for in the prompt. This is the exact
"FLUX tries to 'improve' unrelated parts" failure mode the handoff
warned against.

## 3. Is V2 a clean upgrade over V1?

**No — it is strictly worse.** V1 was a strong, structurally valid 4×2
sheet with one drift (3 bows). V2 is not a 4×2 sheet at all.

The failure mode here is different from the turn V3 / V4 pattern:
- Turn V3, V4: lateral moves (sock fix OK, cap ribbon unchanged)
- Victory V2: **layout drift** — FLUX decided the "grid + add bow"
  task was better solved by re-imagining the composition

V2 is not a lateral move. It is a negative move. V1 remains the
stronger publishing candidate by a wide margin.

## 4. Can V2 be promoted as publishing candidate?

**No.** V2 is unusable:
- It cannot replace `items/menhera_boss_victory.png` because the
  existing runtime loader in
  `entities/menhera_boss_sprite.py` expects a 4×2 (or similar canonical
  grid) sheet. V2's irregular layout would not slice correctly.
- It does not match the canonical walk dimensions or the canonical
  victory dimensions.
- It introduces new drifts (face read, sock-top accent) that V1 had
  avoided.

V1 remains the only usable candidate so far.

## 5. Files written (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_v2.png` | 1392×752 RGB, FAILED layout-drifted sheet (kept for audit trail only) |
| `menhera_flux_kontext_victory_v2.jpeg` | matching JPEG (not for use) |
| `menhera_flux_kontext_victory_v2_args.json` | FLUX request args log |
| `menhera_flux_kontext_victory_v2_zoom.png` | 4× zoom (confirms layout drift) |
| `menhera_flux_kontext_victory_v1_vs_v2.png` | V1 (left) vs V2 (right) side-by-side at native size |
| `menhera_flux_kontext_victory_v1_vs_v2_2x.png` | 2× zoom of the side-by-side |
| `menhera_flux_kontext_victory_v2_report.md` | This report |

`items/menhera_boss_victory.{png,jpeg}` NOT overwritten. Runtime
untouched.

## 6. Why this happened — quick note for the record

The V1 sheet has a fairly compact per-cell torso region. Asking FLUX
to insert a 4th distinct bow at the bottom of each 3-bow stack, at that
per-cell pixel budget, seems to have pushed FLUX into a global
"re-plan the sheet" mode instead of a per-cell local edit. The
reference stack (canonical walk in slot 2, current victory in slot 3,
dense board in slot 4) all show larger characters with fuller torsos,
which may have biased FLUX toward re-laying-out the sheet with larger
figures — hence the irregular 14+ figure layout we got.

This is the same "prop add/modify requires bigger per-figure pixel
budget" pattern we saw on turn: peak V1 at 1024×1024 single-figure
rendered 3 bows; peak V2 at 1024×1024 single-figure with explicit
4-bow prompt landed 4 bows; turn frame expansion at 1024×1024
per-figure kept 4 bows across 6 separate calls; the stitched 4×2
publishing sheet preserved them at 2752×1536. The pattern now
confirmed on victory as well: **at ~348×376 per cell, FLUX renders 3
bows, and narrow-prompt attempts to add a 4th at that density either
fail (turn-style stay-at-3) or cause worse collateral drift (this
victory V2)**.

## 7. Recommendation — go to P2

Per the handoff's closing gate:

> if V2 becomes a lateral move, explicitly recommend P2:
> accept 3-bow as cosmetic runtime drift because victory is non-anchor

V2 is worse than lateral — it is a negative move. The P2 recommendation
applies with even more confidence:

**Adopt V1 as the victory publishing candidate under the R1 guardrails.**

R1 framing, restated for victory:

- Canonical walk = sole identity anchor
- Victory = runtime playback asset only, NOT an identity anchor
- Victory's 3-bow-on-white-panel count divergence from the canonical
  walk's 4-bow count is a runtime-only cosmetic deviation
- It does not propagate to future attack / dash / defeat regens
  because those regens are built off the canonical walk, not victory
- At 79×88 shipping size, 3 vs 4 bows is perceptually equivalent
  (confirmed via earlier gameplay-scale QA)
- Any future worker tempted to anchor a new sheet on victory must
  re-read the R1 close-out note; this should not happen

Under P2, the next-step pipeline is the mirror of turn publish-QA:

1. **Publishing stitch / upscale**: V1 is 1392×752; canonical victory
   dims are 2752×1536. Build a 2752×1536 publishing sheet by scaling
   each of V1's 8 cells up into 688×768 canonical cells with trim +
   LANCZOS scale. Save as
   `.tmp/menhera_flux_kontext_victory_publish_v1.png` and matching
   `.jpeg`.
2. **Nukki**:
   `py d:/main/bosspong/.claude/skills/sprite-generation/remove_bg.py
    .tmp/menhera_flux_kontext_victory_publish_v1.jpeg
    .tmp/menhera_flux_kontext_victory_publish_v1_nukki.png`
3. **Edge QA immediately after nukki**: same stop-and-ask rule used
   for turn — audit 3-bow row (which will be the new accepted count),
   pink paw pads, med-kit, cream bangs, syringe. Any collateral
   damage from nukki → stop.
4. **Gameplay-scale QA vs canonical walk + current live victory**:
   confirm V1 is still a clear upgrade over current live victory at
   79×88 after the stitch / upscale round-trip. Expected: yes.
5. **Codex handoff**: propose
   `items/menhera_boss_victory.{png,jpeg}` swap. Unlike turn, victory
   already expects a 4×2 grid, so no `GRID_COLS / GRID_ROWS` change
   is needed in `entities/menhera_boss_sprite.py`. The loader at
   `VICTORY_FRAME_DURATION` / existing `FRAME_ORDER` reuses the walk
   grid and should load the new 2752×1536 asset without loader edits.
   Local playback QA still required before shipping.

## 8. Codex handoff note (no runtime change in this pass)

```
FLUX Kontext victory V2 bow-only touch-up failed with catastrophic
layout drift. V1 remains the stronger publishing candidate.
Recommendation under R1 is to adopt V1 as-is with the 3-bow cosmetic
deviation accepted (non-anchor role).

- items/menhera_boss_sheet.png                             -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                           -> current live victory (unchanged; weaker than V1)
- items/menhera_boss_turn.png                              -> separate R1 branch, unchanged
- .tmp/menhera_flux_kontext_victory_v1.png                 -> V1 publishing candidate (accept under P2)
- .tmp/menhera_flux_kontext_victory_v1.jpeg                -> V1 JPEG
- .tmp/menhera_flux_kontext_victory_v2.png                 -> FAILED (layout drift, audit only)
- .tmp/menhera_flux_kontext_victory_v1_vs_v2.png           -> failure evidence
- .tmp/menhera_flux_kontext_victory_v2_report.md           -> this report

Pending before any victory runtime migration (P2 path):
- publishing stitch / upscale V1 from 1392x752 to 2752x1536
  (match canonical walk / current victory dims)
- JPEG export + remove_bg.py nukki
- edge QA (3-bow row, paw pads, med-kit, cream bangs, syringe)
- gameplay-scale QA vs canonical walk + current live victory
- Codex swap of items/menhera_boss_victory.{png,jpeg}
- local playback QA on live runtime before shipping

Unlike turn: the victory loader in entities/menhera_boss_sprite.py
already expects 4x2, so no GRID_COLS / GRID_ROWS change is needed.
This is a pure asset swap + local QA.

No runtime changes in this pass. No code edits.
```

## 9. Summary (one-screen read)

1. **Fourth-bow correction success**: NO. FLUX abandoned the 4×2
   layout and produced an irregular multi-row mixed-size sheet. Per
   cell bow count is not even auditable.
2. **Collateral drift**: severe — layout restructure, new face-read
   variance, re-introduction of sock-top pink accent on some figures,
   body scale inconsistency across figures.
3. **V2 upgrade over V1**: no — V2 is a **negative move**, strictly
   worse than V1.
4. **Publish V2 directly**: no, V2 is unusable.
5. **Accept P2 (3-bow cosmetic acceptance on V1)**: YES, recommended.
   This is the handoff-sanctioned fallback path, and it matches the
   R1 policy exactly (victory is non-anchor, so the bow-count drift
   stops at this sheet).

No code changes. Runtime unchanged. Turn R1 branch remains closed.
Next action is asset-side publishing pipeline for V1 under P2 — NOT
another FLUX narrow pass on victory.
