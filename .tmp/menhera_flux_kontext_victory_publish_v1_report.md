# Menhera Victory P2 Publish Pipeline — V1 Report

**Status: P2 accepted. Victory V1 publish pack is approved as a runtime-only non-anchor auxiliary sheet. Canonical walk remains the sole identity anchor.**

---

## 1. Publish pack generated successfully?

**Yes.** V1 (1392×752) was upscaled and re-packaged into the canonical
victory canvas size `2752×1536` with the 4×2 layout preserved and each
cell landing on the canonical `688×768` cell grid.

Packing approach (deliberately conservative — packaging, not
regeneration):

1. Split V1 into its 8 native cells (348×376 each).
2. For each cell, trim to the character's visible white-background
   bounding box.
3. Compute a single **uniform scale factor** across all 8 trimmed
   figures (from the largest trimmed dimension to fit within 92% of
   the canonical 688×768 cell). No per-frame over-fitting, so no
   frame ends up larger or smaller than another.
4. Apply that single factor to all 8 trimmed figures with LANCZOS.
5. Paste each scaled figure centered on a pure-white 688×768 cell.
6. Compose a pure-white 2752×1536 sheet as 4×2.
7. Export matching PNG + JPEG.

Log of trimmed sizes and uniform scale:

```
f1 trimmed: 244x336
f2 trimmed: 243x336
f3 trimmed: 330x339
f4 trimmed: 248x339
f5 trimmed: 255x355
f6 trimmed: 255x355
f7 trimmed: 257x355
f8 trimmed: 257x355
max trimmed: 330x355
uniform scale: 1.9152 (single factor across all 8)
output: 2752x1536, 4x2
```

## 2. Nukki pair generated successfully?

**Yes.**
`py .claude/skills/sprite-generation/remove_bg.py
 .tmp/menhera_flux_kontext_victory_publish_v1.jpeg
 .tmp/menhera_flux_kontext_victory_publish_v1_nukki.png`
completed without errors. Output is 2752×1536 RGBA with crisp
hard-edge alpha, consistent with the skill's 2-step flood-fill + halo
kill algorithm.

## 3. Post-nukki edge QA

Pre / post nukki crops (`_victory_edgeqa_{pre,post_nukki}_f{1..8}.png`)
were inspected for the stop-and-ask list:

| Edge region | Expected | Post-nukki observed |
|---|---|---|
| Accepted 3-bow stack on white center panel | 3 intact | **3 intact on every cell** |
| Pink paw pads on raised / visible paw | visible | visible, no alpha punch-out |
| Med-kit pouch edge + pink cross | clean edge | clean edge, no halo |
| Cream / blonde inner front bangs | present | present, no color bleed |
| Syringe on cap | visible | visible, no outline break |

No halo ring, no alpha punch-out around props, no outline break on
any of the 8 cells. **Post-nukki edge QA PASS.** The stop-and-ask
condition ("halo, alpha punch-out, or prop damage appears") did not
trigger.

## 4. Drift QA — publish V1 vs canonical walk + current live victory

Two side-by-sides at full 2752×1536 scale and a 3-row gameplay-scale
render at 79×88 were produced. Summary:

| Check | Canonical walk | Publish V1 | Current live victory |
|---|---|---|---|
| Same Menhera face across all 8 cells | YES (baseline) | **YES** | drifts — some cells show a noticeably different Menhera (closed-eye joyful face, different cheek blush, different hair treatment) |
| Cream/blonde inner bangs preserved per cell | YES | **YES** | drifts |
| Gingham cap + red cross + front ribbon language | YES | match | partial — red ribbon reads more saturated / relocated on some cells |
| Heart cheek mark side | viewer-right | **viewer-right on all 8** | drifts subtly |
| Gray cat-paw gloves with pink paw pads | visible | **visible per cell, clear on raised-paw frames** | visible |
| Med-kit pouch w/ pink cross, same-side | present | present on every cell where arm does not occlude (natural per-pose variation) | present |
| White thigh-highs — NO pink trim at sock top | plain white | **plain white, no trim** | plain white |
| Black X ankle | present | present | present |
| 4-bow count on white panel | 4 | **3** (accepted divergence) | varies — sometimes reads as 3-4, sometimes unclear |
| Body read vs walk at 79×88 | baseline | **same 88px body-height, same silhouette class** | similar body size but more varied across frames |

Drift judgment under the handoff's explicit rule ("compare to walk,
compare to current live victory, if walk pairing makes V1 read as a
different character → HOLD; if V1 still reads materially more stable
than current live victory → say so clearly"):

- **Walk pairing does NOT make V1 read as a different character.**
  V1 is in the same identity class as walk; the only per-frame
  divergence is the 3-bow count (accepted under P2).
- **V1 reads materially more stable than current live victory.**
  Current live victory's frame-to-frame face drift is visible on
  the 3-row gameplay-scale render. V1 holds one Menhera across all 8
  cells.

## 5. Gameplay-scale QA at 79×88

The 3-row gameplay-scale render (`..._gameplay_4x.png`) stacks canonical
walk (top), publish V1 (middle), current live victory (bottom).

| Check | Result |
|---|---|
| Publish V1 body-read vs walk at 79×88 | MATCH — bbox 79×88 on every cell, same as walk |
| Face consistency survives the upscale / JPEG / nukki round-trip | **YES** — all 8 V1 cells still read as same Menhera |
| New closed-eye happy-face drift | **none introduced** (unlike current live victory, which has it) |
| Pink trim reappears on thigh-highs | **no** — sock tops still plain white |
| 3 vs 4 bow count perceptually distinguishable at 79×88 | **NO** — both collapse to "short dark vertical stack on white panel". Matches the earlier walk-bow observation that even canonical's 4 bows read as ~3 after downscaling. |
| Publish V1 upgrade over current live victory at shipping size | **YES — clear upgrade** |

**Gameplay QA PASS.**

## 6. Accepted 3-bow cosmetic divergence — runtime shipping safety

The V1 publish pack lands 3 bows on the white center panel on every
frame instead of canonical walk's 4. Under P2 and R1:

- Victory is NOT a future identity anchor. No attack / dash / defeat
  regen will be built off victory. So the 3-bow drift cannot
  propagate.
- At 79×88 gameplay size, 3 vs 4 bows is perceptually identical.
- Edge QA after nukki shows no new regressions vs V1's original
  asset state.
- The divergence is contained: it is only this sheet, only this
  shipping role, and only a runtime playback cosmetic difference
  from walk.

**No runtime shipping safety issue.** Shipping as-is is safe.

## 7. Can Codex swap `items/menhera_boss_victory.{png,jpeg}` directly?

**Yes, with the usual local playback QA gate.**

Key points for the Codex migration, short form:

- Target path: `items/menhera_boss_victory.png` and
  `items/menhera_boss_victory.jpeg`.
- Target dimensions: `2752×1536`, 4×2 — **same as the current live
  file**. No loader-side grid change needed (unlike turn, which
  required `TURN_GRID_COLS / TURN_GRID_ROWS` flip).
- Loader path referenced in
  `entities/menhera_boss_sprite.py:38-39`
  (`VICTORY_SHEET_PATH_PNG` / `VICTORY_SHEET_PATH_JPEG`) expects a
  walk-style 4×2 sheet. The publish V1 pack meets that assumption.
- Swap order:
  1. Back up current `items/menhera_boss_victory.png` and
     `items/menhera_boss_victory.jpeg` (git working tree is fine).
  2. Copy `.tmp/menhera_flux_kontext_victory_publish_v1.png` →
     `items/menhera_boss_victory.png` (or use the nukki PNG —
     `..._publish_v1_nukki.png` — both are 2752×1536; pick nukki PNG
     if the runtime loader benefits from precomputed alpha).
  3. Copy `.tmp/menhera_flux_kontext_victory_publish_v1.jpeg` →
     `items/menhera_boss_victory.jpeg`.
- Local playback QA before shipping: trigger victory pose in-game,
  watch for:
  - correct 4×2 slicing on the new asset
  - face / identity stays consistent across the victory cycle
  - no face-clipping on any frame
  - body-read matches walk at gameplay size
  - no regression in non-victory states (walk / attack / dash / turn
    loaders are independent of this swap but sanity check anyway)
- Rollback: if any of the above fails, restore the prior victory
  asset from git. The R1 turn guardrails remain in force —
  this swap does not reopen turn work.

## 8. Output files (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_publish_v1.png` | 2752×1536 RGB 4×2 victory publish sheet (pre-nukki) |
| `menhera_flux_kontext_victory_publish_v1.jpeg` | JPEG q=95 for nukki input |
| `menhera_flux_kontext_victory_publish_v1_nukki.png` | 2752×1536 RGBA post-`remove_bg.py` (hard-edge alpha) |
| `menhera_flux_kontext_victory_publish_v1_zoom.png` | half-size quick-view of the publish PNG |
| `menhera_flux_kontext_victory_publish_v1_vs_walk.png` | full-scale side-by-side publish vs canonical walk |
| `menhera_flux_kontext_victory_publish_v1_vs_current.png` | full-scale side-by-side current live victory vs publish |
| `menhera_flux_kontext_victory_publish_v1_gameplay.png` | 3-row gameplay-scale render (walk / publish / current) at 79×88 per cell |
| `menhera_flux_kontext_victory_publish_v1_gameplay_4x.png` | 4× NN zoom of the above for readable QA |
| `_victory_edgeqa_pre_f{1..8}.png` | torso/bow crops pre-nukki |
| `_victory_edgeqa_post_nukki_f{1..8}.png` | torso/bow crops post-nukki |
| `menhera_flux_kontext_victory_publish_v1_report.md` | this report |

`items/menhera_boss_victory.{png,jpeg}` NOT overwritten in this pass.

## 9. Final recommendation (answers to the handoff's §최종 보고 형식)

1. **Publish pack generated successfully**: YES.
2. **Nukki pair generated successfully**: YES.
3. **Post-nukki edge QA**: PASS (3-bow row / pink paw pads / med-kit
   / cream bangs / syringe all intact).
4. **Gameplay-scale QA upgrade over current live victory**: YES —
   clear upgrade. V1 preserves one Menhera identity across all 8
   cells; current live victory does not.
5. **Accepted 3-bow cosmetic divergence — runtime shipping safe?**:
   YES under P2 / R1 (victory non-anchor, 3 vs 4 indistinguishable at
   79×88, propagation contained).
6. **Can Codex swap `items/menhera_boss_victory.{png,jpeg}` directly?**:
   YES, pending local playback QA. No loader code change needed
   (4×2 grid assumption already matches).

## 10. Key conclusion phrases

- **P2 accepted**
- **Victory V1 publish pack is approved as a runtime-only non-anchor
  auxiliary sheet**
- **Canonical walk remains the sole identity anchor**

## 11. Codex handoff note (no runtime change in this pass)

```
Victory V1 publish pipeline passed P2 QA. Asset swap is safe pending
local playback QA. Canonical walk remains the sole identity anchor.

- items/menhera_boss_sheet.png                                 -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                               -> current live (unchanged; will be swapped below)
- items/menhera_boss_victory.jpeg                              -> current live JPEG (unchanged; will be swapped)
- items/menhera_boss_turn.png                                  -> separate R1 branch (unchanged)
- .tmp/menhera_flux_kontext_victory_publish_v1.png             -> NEW 2752x1536 4x2 publish candidate
- .tmp/menhera_flux_kontext_victory_publish_v1.jpeg            -> NEW 4x2 JPEG
- .tmp/menhera_flux_kontext_victory_publish_v1_nukki.png       -> alt runtime-ready PNG (post remove_bg.py)
- .tmp/menhera_flux_kontext_victory_publish_v1_gameplay_4x.png -> 3-row gameplay QA (walk / publish / current)
- .tmp/menhera_flux_kontext_victory_publish_v1_report.md       -> this report

Runtime swap requirements (Codex scope):
  - NO loader code change required — victory already assumes 4x2 grid
    via the walk-style FRAME_ORDER in entities/menhera_boss_sprite.py.
  - Copy .tmp/menhera_flux_kontext_victory_publish_v1.png (or _nukki.png)
    to items/menhera_boss_victory.png.
  - Copy .tmp/menhera_flux_kontext_victory_publish_v1.jpeg
    to items/menhera_boss_victory.jpeg.
  - Back up the replaced files via git working tree for rollback.
  - Run local playback QA: trigger victory in-game, verify slicing,
    face consistency across cycle, no face-clipping, body-read parity
    with walk, no regression on walk/attack/dash/turn.
  - If QA fails: revert the two files, no other state to undo.

Accepted divergence (document only, do not treat as a new rule):
  - V1's white center panel shows 3 bows per cell instead of the
    canonical walk's 4. This is a cosmetic runtime-only deviation for
    this sheet. DO NOT use victory V1 as a future identity anchor.
    Canonical walk + approved prop references remain the anchor set.

Turn R1 branch is unaffected by this swap. No other assets move.

No runtime wiring changes required from the asset-side pass.
```
