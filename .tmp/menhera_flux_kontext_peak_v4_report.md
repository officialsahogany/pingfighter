# Menhera Turn FLUX Kontext Peak V4 Cap-Only Touch-Up Report

**Status: LATERAL MOVE (NOT A CLEAN UPGRADE). Sock fix from V3 retained. Cap ribbon correction did NOT cleanly land — side-accent language partially reduced but no clear single front-center ribbon synthesized. Small pose/med-kit/syringe drifts added. V4 is NOT recommended as the new primary anchor. STOP narrow-pass chain and propose criterion reset.**

## 1. Cap ribbon correction — did it succeed?

**Partial / inconclusive, not a clean success.**

V4 cap crop vs V3 cap crop:

- V3: gingham cap with red cross front-center, plus a prominent red
  bow-like accent on the viewer-left side of the cap base, and a
  smaller red/pink detail on the viewer-right side.
- V4: gingham cap with red cross front-center, the viewer-left red
  bow-like accent is still present (similarly prominent), the
  viewer-right has been slightly simplified (less obvious red accent,
  more hair / skin filling that area).

No new clear single front-center red ribbon was synthesized below or
above the existing red cross. The cap still reads as "gingham cap with
a red cross and at least one side red accent." Under the handoff's
hard-reject rule ("cap ribbon still reading as side-accent branch
rather than front-center language"), this still triggers.

## 2. Plain white socks — retained?

**Yes, retained cleanly.**

V4 sock crop shows plain white thigh-high tops exactly like V3: no
pink band, no pink bow, no pink trim. The V3 sock fix carried forward
into V4 without regression.

## 3. Thigh-gap / face softness / syringe — collateral drift?

| Watch item | V3 | V4 | Drift? |
|---|---|---|---|
| Thigh-gap / dress length | V3 baseline (already widened vs V2) | similar to V3, maybe a hair wider | marginal, not a new blocker |
| Face softness | V3 baseline (already softer than V2) | similar to V3 | no new regression |
| Syringe on cap | visible but weakened vs V2 | similar to V3, possibly slightly weaker | marginal, watch |
| Pose amplitude of the raised paw | V3 raised paw with pink pads clearly forward | paw still raised but lower / less emphatic read | **small pose drift** |
| Med-kit pouch + pink cross | visible at right hip | still present but smaller / less prominent read | **small drift** |
| 4 black bows on white panel | 4 visible | 4 still visible | PASS |
| Pink paw pads | visible | still visible on the raised paw | PASS |
| Cream / blonde inner front bangs | present | present | PASS |

Stop-and-ask check: the handoff's explicit collateral watchlist —
plain white socks, dress length / thigh gap, face softness, syringe,
4 bows, paw pads, med-kit — has two items in the "small drift" column
(paw pose and med-kit clarity). Not catastrophic losses, but by the
handoff's definition ("V4 is only acceptable if it is a true upgrade
over V3, not another lateral move") these do count against V4.

## 4. Is V4 a clean upgrade over V3?

**No.** V4 keeps V3's sock fix without regression, but:

- The targeted cap-ribbon fix did not land cleanly — the single
  front-center ribbon was not synthesized, one side accent was kept
  roughly intact, and the other was simplified (not replaced with a
  new ribbon). Under the stricter rule the cap still reads as
  side-accent branch.
- The raised paw pose is slightly less emphatic than on V3. Peak
  gesture amplitude softened a hair.
- The med-kit pouch reads slightly smaller / less prominent than on V3.

So V4 is a lateral move: +0 net on the two original blockers (socks
fixed, cap still open) and -small on pose amplitude and med-kit
clarity. That fails the handoff's "true upgrade over V3" gate.

## 5. Can V4 be used as the new primary anchor for derived frames?

**No.** Same conclusion as V3. Anchoring f1/f2/f3/f5/f6/f7 on V4
propagates both the remaining cap drift AND V4's new small pose /
med-kit drifts. V2 remains the cleanest single peak so far; V3 is
tied on solved props except for socks; V4 does not meaningfully move
past either of them.

## 6. Interpretation — why this is happening

Three narrow passes have now confirmed a pattern worth naming
explicitly:

1. FLUX Kontext max reliably **keeps** already-solved identity props
   when base/anchor is strong (V3 → V4 all major props survive).
2. FLUX Kontext max reliably **strips** a small added detail when told
   to remove it (V2 sock accent → V3 plain white succeeded first try).
3. FLUX Kontext max does NOT reliably **relocate** a pre-existing
   prominent color element (V2/V3 side red cap accents → V4 single
   front-center ribbon). After two attempts it is still a side-accent
   cap.

So the problem is not "FLUX can't do narrow edits." The problem is
specifically "cap ribbon moves" — FLUX treats the side red accents as
part of the cap's established identity and refuses to relocate them.
Further V5 / V6 narrow passes with the same reference stack are likely
to keep landing in this same attractor.

## 7. Files written (`.tmp/`)

| File | Contents |
|------|---------|
| `menhera_flux_kontext_peak_v4.png` | FLUX Kontext max V4 output, 1024×1024 RGB PNG |
| `menhera_flux_kontext_peak_v4_args.json` | FLUX request args log |
| `menhera_flux_kontext_peak_v4_zoom.png` | 2× nearest-neighbor zoom |
| `menhera_flux_kontext_peak_v4_cap_crop.png` | 4× cap region audit |
| `menhera_flux_kontext_peak_v4_socks_crop.png` | 4× socks region audit |
| `menhera_flux_kontext_peak_v4_bows_crop.png` | 4× torso / bows region audit |
| `menhera_flux_kontext_peak_v4_paw_crop.png` | 4× raised-paw region audit |
| `menhera_flux_kontext_peak_v3_paw_crop.png` | V3 paw region for compare |
| `menhera_flux_kontext_peak_v3_vs_v4.png` | V3 vs V4 side-by-side |
| `menhera_flux_kontext_peak_v2_v3_v4_triple.png` | V2 + V3 + V4 triple panel |
| `menhera_flux_kontext_peak_v4_report.md` | This report |

Canonical asset + runtime unchanged. `items/menhera_boss_turn.png` was
NOT overwritten. `entities/menhera_boss_sprite.py` still has
`RENDER_TURN_FRAMES = False` and the `TURN_GRID_COLS = 8,
TURN_GRID_ROWS = 1` runtime blocker is still open.

## 8. Recommended next actions (choose one — no more narrow passes
until the rule is re-calibrated)

The handoff's own closing line applies now: "더 이상 옆걸음 반복하지
말고 기준을 다시 조정해야 합니다." Picking one of these is cheaper
than another V5 that will most likely repeat the same pattern.

### Option R1 — Relax the cap-ribbon rule (recommended)

Re-read the publish QA V1 drift-judgment: the cap side-accent drift
was called a blocker primarily because this turn may later anchor
attack / dash realign. Two mitigations are available:

1. **Explicitly keep the canonical walk as the only identity anchor
   for any future attack / dash / victory / defeat regen.** The turn
   never becomes an anchor source. Under that policy the cap drift
   never propagates and can be downgraded to "acceptable minor drift."
2. **Run a gameplay-scale walk-vs-turn cap comparison at the native
   79×88 target size.** If the cap side-accents are indistinguishable
   from the canonical walk cap at that size (they almost certainly
   are), the drift is formally cosmetic.

With those two guardrails in place, V3 becomes promotable: V3 has
the plain-white sock fix AND preserves all V2 strengths except for
the unchanged cap. That is the cheapest net forward.

### Option R2 — Change the reference mix on a single fresh cap-only pass

Drop V3 as the primary anchor for the cap-only pass. Instead:
- `input_image` = canonical walk cell (the cap shape we actually want)
- `input_image_2` = V3 (to preserve everything below the neck)
- `input_image_3` = victory reference
- `input_image_4` = dense identity board
- Narrow prompt: "generate the same character as input 2, but with
  the cap EXACTLY from input 1: gingham, red cross, single red
  front-center ribbon, no side accents."

This flips the attractor: the primary image IS the cap we want. Risk:
primary-anchor change may bring in minor body / face drift from the
canonical walk. If it does, that's another lateral move and we go to R3.

### Option R3 — Inpaint-style manual cap-only surgery

Bypass FLUX for the cap entirely:
- Start from the V3 PNG
- Composite the canonical walk's cap region (pixel-copy the cap from
  a canonical walk cell, scaled to match V3's head size) onto V3
- Optionally blend at the cap/hair boundary with a soft mask

This is guaranteed to land a single-front-center-ribbon cap, at the
cost of a hand-assembled anchor. The composite would only need to be
good enough to serve as a FLUX "final anchor" for the derived frames
pass — FLUX would then redistribute the pixel class consistently in
those generations.

### Not recommended

- Another `flux_kontext_max` V5 narrow cap-ribbon pass with the same
  reference stack. Three consecutive narrow passes have already shown
  FLUX does not relocate this specific prop. A fourth is unlikely to
  do better and will burn more credits.

## 9. Codex handoff note (no runtime change)

```
FLUX Kontext peak V4 cap-only touch-up completed with a lateral
result (sock fix retained, cap ribbon not cleanly restored). Asset
state + runtime unchanged.

- items/menhera_boss_sheet.png                       -> canonical walk (unchanged)
- items/menhera_boss_turn.png                        -> previous 8x1 turn (unchanged)
- items/menhera_boss_victory.png                     -> quality reference (unchanged)
- .tmp/menhera_flux_kontext_peak_v2.png              -> cleanest peak so far (sock accent + cap side-ribbon drifts)
- .tmp/menhera_flux_kontext_peak_v3.png              -> V3 (sock fix PASS, cap still side accents, minor pose/face drift)
- .tmp/menhera_flux_kontext_peak_v4.png              -> V4 (sock fix retained, cap ribbon still side-accent read, small pose/med-kit softening)
- .tmp/menhera_flux_kontext_peak_v3_vs_v4.png        -> V3 vs V4 visual
- .tmp/menhera_flux_kontext_peak_v2_v3_v4_triple.png -> V2/V3/V4 triple panel
- .tmp/menhera_flux_kontext_peak_v4_cap_crop.png     -> cap audit crop (cap still side-accent branch)
- .tmp/menhera_flux_kontext_peak_v4_socks_crop.png   -> socks audit crop (plain white PASS)
- .tmp/menhera_flux_kontext_peak_v4_bows_crop.png    -> bows audit crop (4 PASS)
- .tmp/menhera_flux_kontext_peak_v4_report.md        -> QA report

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off
  - RENDER_TURN_FRAMES = False in entities/menhera_boss_sprite.py

Pre-promotion blockers still open:
  - cap ribbon drift — recommendation is Option R1 (relax rule under
    "canonical walk remains only identity anchor") or Option R3
    (manual composite surgery). Another FLUX narrow pass (R2 / V5)
    is not recommended.
  - runtime TURN_GRID_COLS/ROWS flip from 8x1 to 4x2 (Codex side,
    deferred until asset-side is locked)

No runtime wiring changes in this pass.
```

## 10. Summary (one-screen read)

- **Cap ribbon correction: did NOT cleanly land.** V4 still reads as a
  side-accent cap; no single front-center ribbon synthesized.
- **Plain white socks: retained from V3.** ✓
- **Collateral drift**: raised paw pose slightly softer, med-kit pouch
  slightly smaller / less prominent, syringe marginally weaker. No
  hard prop losses (4 bows, paw pads, cream bangs, med-kit side all
  preserved).
- **V4 is NOT a clean upgrade over V3** — it is a lateral move.
- **NOT recommended as new primary anchor.**
- **Recommended next step**: stop narrow passes. Pick Option R1
  (relax the cap-ribbon rule and promote V3 under the "canonical walk
  is the only identity anchor for future regens" guardrail) OR
  Option R3 (manual pixel-composite cap surgery). R2 (re-mix
  references on one more FLUX pass) is the weakest of the three but
  still cheaper than another V5. Another same-reference narrow pass
  is NOT recommended.
- **Canonical promotion still HELD. Runtime unchanged.**
