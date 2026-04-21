# Menhera Turn FLUX Kontext Peak V3 Narrow Touch-Up Report

**Status: MIXED RESULT. Sock-top pink accent removal SUCCESS. Cap ribbon front-center restoration FAILED (still side accents). Small pose/face proportion drift introduced as collateral. V3 is NOT recommended as the new primary anchor. Canonical turn NOT overwritten.**

## 1. V2 → V3 what actually changed

- **Intended change 1 — sock-top pink accent**: REMOVED. V3 thigh-highs
  read as plain white without the pink band/bow that was on V2. PASS.
- **Intended change 2 — cap ribbon restoration toward single
  front-center**: NOT achieved. V3 still has two side-placed red accents
  on the cap; there is no new, clear single front-center red bow/ribbon.
  FAIL.
- **Unintended drift 1 — body proportion**: V3 shows a larger visible
  thigh gap between the dress hem and the sock top. Either the dress
  reads slightly shorter or the legs read slightly longer. Not named
  in the brief. Minor but visible at 6× zoom.
- **Unintended drift 2 — face softness / blush**: V3 face is a touch
  softer (slightly more anime-ish cheek blush and a slightly wider
  face read) than the crispness of V2. Not an outright style-class
  regression, but a perceptible softening direction the brief asked
  to avoid.
- **Unintended drift 3 — syringe legibility**: V3's syringe on the cap
  side reads slightly less prominent than V2. Not fully lost, but
  weakened. Inside the "stop and ask" watch list.

## 2. References actually used

| Slot | File | Role |
|---|---|---|
| `input_image` | `.tmp/menhera_flux_kontext_peak_v2.png` | primary anchor (required) |
| `input_image_2` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board |
| `input_image_3` | `items/menhera_boss_sheet.png` | canonical walk (target for both edits) |
| `input_image_4` | `items/menhera_boss_victory.png` | quality / clarity reference |

Model: `flux_kontext_max`, `aspect_ratio = 1:1`, `output_format = png`,
`safety_tolerance = 2`, seed not pinned.

## 3. Output files (`.tmp/`)

| File | Contents |
|------|---------|
| `menhera_flux_kontext_peak_v3.png` | FLUX Kontext max V3 output, 1024×1024 RGB PNG |
| `menhera_flux_kontext_peak_v3_args.json` | FLUX request args log |
| `menhera_flux_kontext_peak_v3_zoom.png` | 2× nearest-neighbor zoom |
| `menhera_flux_kontext_peak_v3_socks_crop.png` | 4× zoomed sock-top region for sock-fix audit |
| `menhera_flux_kontext_peak_v3_cap_crop.png` | 4× zoomed cap region for cap-ribbon audit |
| `menhera_flux_kontext_peak_v3_bows_crop.png` | 4× zoomed torso/bow region for bow-count audit |
| `menhera_flux_kontext_peak_v2_socks_crop.png`, `_cap_crop.png`, `_bows_crop.png` | Matching V2 crops at the same coords for direct compare |
| `menhera_flux_kontext_peak_v2_vs_v3.png` | V2 on left, V3 on right for quick visual diff |
| `menhera_flux_kontext_peak_v3_report.md` | This report |

`items/menhera_boss_turn.png` is **NOT** overwritten. Runtime still on
hop-only fallback; `entities/menhera_boss_sprite.py` unchanged and its
`TURN_GRID_COLS=8, TURN_GRID_ROWS=1` blocker is still open (promotion
cannot proceed even if V3 were clean).

## 4. Sock-top pink accent — SUCCESS

Sock crop V3 vs V2:

- V2: a distinct pink pixel band / small pink bow accent sits directly
  on top of the white thigh-high band, visible as pink pixels between
  the skin/dress hem and the sock fabric.
- V3: the sock tops are plain white, with only the normal flesh-tone
  skin showing above them from the dress hem. No pink trim, no pink
  bow, no pink fringe at the sock top. Matches the canonical walk's
  plain-white thigh-high language.

Pass.

## 5. Cap ribbon front-center restoration — FAIL

Cap crop V3 vs V2:

- V2: gingham check cap with red cross at the top-front center, and
  **two prominent red ribbon accents** on the viewer-left and
  viewer-right sides of the cap base (the drift we wanted to undo).
- V3: gingham check cap with red cross still at the top-front center,
  **still two red accents**, one on each side of the cap base. The
  left-side red accent is actually slightly more prominent than on V2;
  the right-side red accent persists as a smaller pink/white bow-like
  detail. No clear new single front-center ribbon was synthesized.

This is exactly the "cap ribbon still reading as side-accent branch
rather than front-center language" hard-reject condition. The targeted
edit did not land.

## 6. Collateral damage check (strict stop-and-ask list)

| Watched item | V2 | V3 | Result |
|---|---|---|---|
| Exactly 4 black bows on white panel | 4 | **4 preserved** | PASS |
| Pink paw pads on raised paw | visible | **visible** | PASS |
| Med-kit pouch + pink cross, same side | present | **present** | PASS |
| Cream / blonde inner front bangs | present | **present** (if anything slightly more pronounced on viewer-right) | PASS |
| Syringe on cap | visible | weaker but still present | partial — watch |

Under the handoff's stop-and-ask ("if removing the sock accent or
restoring cap ribbon causes collateral damage to 4 bows / paw pads /
med-kit / cream bangs / syringe, stop and do not promote V3"): the
four hard-priority identity props survived cleanly. The syringe took a
small readability hit but was not lost. So the stop-and-ask does NOT
trigger on the explicit list.

However the handoff's broader hard reject list includes:
- cap ribbon still reading as side-accent branch → **TRIGGERED**
- anime-soft regression → slight face softness drift, marginal
- pose drift away from peak_v2 → thigh-gap / proportion drift,
  marginal but visible

## 7. Is V3 usable as the new primary anchor for derived frames?

**No, not recommended.** Two reasons:

1. **Cap ribbon drift is still open.** V3 inherited the same side-accent
   cap ribbon pattern as V2. The original blocker that motivated this
   pass was 50% fixed (socks) and 0% fixed (cap ribbon). If we anchor
   f1/f2/f3/f5/f6/f7 on V3, we propagate the cap drift just as we
   would have with V2 — with the added cost of also propagating V3's
   new small pose/face-softness drifts.
2. **V3 introduces small collateral drifts** (thigh-gap proportion,
   face softness). Those are not blockers in isolation, but they are
   *new* drifts we did not have on V2. Accepting V3 as the anchor is
   a lateral move, not a clean upgrade.

## 8. Recommended next actions (user decides)

I see three viable paths. They are ordered by "most conservative
forward step" first.

**Option A1 — V4 targeting only the cap ribbon, V3 as base**

- Primary anchor: `.tmp/menhera_flux_kontext_peak_v3.png` (keeps sock
  fix; keeps bows / pads / med-kit / cream bangs / syringe intact)
- Brief: single narrow edit — remove the two side red accents from the
  cap base, put a single red front-center ribbon / small bow just
  above the cap's forehead band, matching the canonical walk. Do not
  change anything else. Do not change proportions or face rendering.
- Reference stack: input 1 = V3, input 2 = dense identity board,
  input 3 = canonical walk, input 4 = victory.
- Outcome: either cap cleanly lands and V4 becomes the new primary
  anchor, or the cap resists the edit and we move to A2.

**Option A2 — V4 targeting only the cap ribbon, V2 as base**

- Primary anchor: `.tmp/menhera_flux_kontext_peak_v2.png` (gives up
  the sock fix for this pass)
- Same narrow cap-ribbon brief as A1.
- If the cap is the stubborn prop, we isolate it first on V2, then a
  later V5 can restack the sock fix on top.
- Advantage: avoids stacking both an unproven cap fix and a proven
  sock fix on the same pass.

**Option A3 — accept cap ribbon as an acceptable minor drift**

- Re-evaluate the cap ribbon drift under a relaxed rule: "does the
  two-side-accent cap read as a different Menhera branch at gameplay
  size, or is it inside pose-variance?"
- Under the publish-QA V1 report, the cap drift was flagged as
  blocker primarily because this turn may seed future attack / dash
  realigns. If the user explicitly decides that the canonical walk
  remains the only anchor for any future regen, the cap drift drops to
  "cosmetic, accept."
- In that case: promote V2 (not V3 — V3 adds the thigh-gap drift) once
  the sock-top pink accent is separately touched up, or accept V3 if
  sock-fix + cap-drift is the agreed trade.
- This is the path recommended only if the user explicitly relaxes the
  stricter rule.

My own recommendation: **Option A1**. V3 already bought the sock fix,
and the cap is the one remaining blocker. One more narrow pass focused
on just the cap is the cheapest next step.

## 9. Codex handoff note (no runtime change)

```
FLUX Kontext peak V3 narrow touch-up completed with mixed result.
Asset state + runtime unchanged.

- items/menhera_boss_sheet.png                       -> canonical walk (unchanged)
- items/menhera_boss_turn.png                        -> previous 8x1 turn (unchanged)
- items/menhera_boss_victory.png                     -> quality reference (unchanged)
- .tmp/menhera_flux_kontext_peak_v2.png              -> previous best peak anchor (UNCHANGED, still the current strongest anchor)
- .tmp/menhera_flux_kontext_peak_v3.png              -> V3 touch-up (sock fix PASS, cap ribbon FAIL, pose drift)
- .tmp/menhera_flux_kontext_peak_v2_vs_v3.png        -> side-by-side visual
- .tmp/menhera_flux_kontext_peak_v3_socks_crop.png   -> sock fix audit crop (PASS)
- .tmp/menhera_flux_kontext_peak_v3_cap_crop.png     -> cap ribbon audit crop (FAIL)
- .tmp/menhera_flux_kontext_peak_v3_bows_crop.png    -> bow-count audit crop (4 PASS)
- .tmp/menhera_flux_kontext_peak_v3_report.md        -> QA report

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off
  - RENDER_TURN_FRAMES = False in entities/menhera_boss_sprite.py

Pre-promotion blockers still open:
  - cap ribbon drift (Option A1 / A2 / A3 above decides the next move)
  - runtime TURN_GRID_COLS/ROWS flip from 8x1 to 4x2 (Codex side,
    deferred until asset-side is locked)

No runtime wiring changes in this pass.
```

## 10. Summary (one-screen read)

- V2 vs V3 actual change: sock-top pink accent REMOVED ✓; cap ribbon
  unchanged (still side accents) ✗
- Sock-top removal success: YES
- Cap-ribbon front-center restoration success: NO
- Collateral drift: slight thigh-gap proportion drift + slight face
  softness + slightly weaker syringe; no loss of 4 bows / paw pads /
  med-kit / cream bangs
- V3 as new primary anchor: NOT recommended (cap drift still open,
  new small collateral drifts added)
- Recommended next step: **Option A1** — V4 narrow pass focused only on
  cap ribbon, using V3 as base to keep the sock fix
- Canonical promotion still HELD. Runtime unchanged.
