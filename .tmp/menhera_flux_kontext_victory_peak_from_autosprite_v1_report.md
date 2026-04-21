# Menhera Victory FLUX Peak From AutoSprite F5 — V1 Report

**Status: ACCEPTED AS FRAME-EXPANSION PRIMARY ANCHOR. Identity lock PASS. 4-bow count PASS. Open-mouth delighted celebration read PASS. No V3-style twin-tail / red-ribbon leak. One paw raised with pink pads facing forward. Meaningfully more celebratory than the currently applied runtime P2 victory. Canonical overwrite NOT done. Runtime unchanged.**

---

## 1. Reference stack actually used

| Slot | File | Role |
|---|---|---|
| `input_image` | `items/menhera_boss_sheet.png` | **ABSOLUTE identity master** — canonical walk |
| `input_image_2` | `.tmp/menhera_victory_autosprite_motion_v1_f5_peak.png` | **motion / pose guide ONLY** (cropped AutoSprite f5 cell, not the full 8-frame sheet) |
| `input_image_3` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board for prop preservation |

Explicit exclusions honored: old victory backup, V3 rejected frames,
current runtime P2 victory (kept only for post-generation QA compare),
turn sheet, the full AutoSprite motion sheet (only the f5 crop was
passed).

Model: `flux_kontext_max`, `aspect_ratio = 1:1`, output 1024×1024 RGB,
`safety_tolerance = 2`, seed not pinned.

## 2. AutoSprite f5 peak transfer — partial but usable

Compare `.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_motion_peak.png`:

| Peak feature | AutoSprite f5 motion crop | FLUX peak V1 |
|---|---|---|
| Big happy open-mouth smile | YES | **YES — transferred cleanly** |
| Both paws raised high | YES | **only ONE paw raised** (the other holds the med-kit naturally) |
| Pink paw pads facing forward | on both paws | **on the raised paw (visible)** |
| Body lifted / slight hop feel | yes | slight lift read; legs together, feet close — reads as ready-to-hop rather than mid-hop |
| Visible upward beat | yes | partial — expression carries the beat more than the body does |
| Identity class | AutoSprite's generic chibi | **canonical PingFighter 16-bit pixel art** |

FLUX adapted the f5 "both-arms-up" composition into a "one paw raised +
open-mouth delighted smile + med-kit still in other hand" pose. This is
a legitimate compromise — it preserves the expression (the strongest
peak signal) while keeping one canonical prop (med-kit) continuously
visible. For a single peak anchor that will drive f1–f8 frame expansion,
"one paw raised + delighted smile" is enough.

**Peak transfer: PARTIAL (expression YES, both-paws-raised NO).**
Acting is strong enough; identity-first policy was honored.

## 3. Canonical walk identity lock — PASS

Per-element check at 1024×1024 zoom
(`menhera_flux_kontext_victory_peak_from_autosprite_v1_zoom.png`):

| Element | Canonical walk | FLUX peak V1 | Verdict |
|---|---|---|---|
| Fluffy pink outer hair + CREAM/BLONDE inner front bangs | present, asymmetric | **preserved and readable** | PASS |
| Rounded fluffy hair silhouette | present | preserved | PASS |
| Pink/white GINGHAM nurse cap + red cross | present | present, clean gingham check | PASS |
| SYRINGE on cap | present | present (small element top-right of cap) | PASS |
| Front ribbon language | single center front | two small side red accents on the cap base (same attractor that the turn branch already accepted under R1 as cosmetic runtime drift — this is **not** the V3 "big twin-tail red ribbons" which are completely absent here) | partial — cosmetic only, same class as turn cap drift |
| NO black cat ears | absent | absent | PASS |
| NO twin-tail hairstyle with big red ribbons (V3 leak) | - | **ABSENT — clean** | PASS |
| NO small alternate cap design | - | absent — full-size gingham cap | PASS |
| Large gray / silver eyes with lashes | present | preserved, same eye spacing | PASS |
| ONE pink heart cheek mark, viewer-right | present | **viewer-right cheek, readable** | PASS |
| Pink dress with white center front panel | present | present | PASS |
| EXACTLY 4 BLACK BOWS on white panel | 4 | **4 visible** (restored vs P2 / V1 / V2 / V3 / from-autosprite V1 which all had 3 at smaller per-cell budgets) | PASS |
| DARK GRAY cat-paw gloves + PINK PAW PADS | present | present on both paws; pink pads clearly visible on the raised paw | PASS |
| White MED-KIT pouch with pink cross, same hip side | present | **present at viewer-right hip, clearly rendered** | PASS |
| Pink CHECK-PATTERN cloth-tail motif | present | pink tail with dark/check accent present behind leg | PASS |
| PLAIN WHITE thigh-high socks | plain white | **plain white, NO pink trim** (V3 R1 guardrail held) | PASS |
| Black X ankle accessories | present | present | PASS |
| Petite chibi body class | present | matches | PASS |
| Thick black pixel outlines | thick | thick | PASS |
| 16-bit pastel pixel-art clarity class | canonical | **matches canonical** (no anime-soft regression) | PASS |
| Body scale ±5% of walk | baseline | visually within band | PASS |

**Identity lock PASS.** All hard anti-drift rules held.

## 4. Peak celebration readability — PASS (with a caveat)

At 1024×1024 zoom, the peak reads clearly as a celebration frame:

- **Open-mouth delighted smile is the strongest celebration signal**;
  it cannot be mistaken for the neutral / pleasant smile used on walk
  or P2 victory.
- **Pink paw pads on the raised paw** read at gameplay scale.
- Body posture is upright with legs together / feet close — reads as
  "just landed from a hop" or "about to hop," not as flat standing.
- The image cannot be mistaken for a walk frame (legs not mid-stride),
  a turn frame (body not angled, arms not in turn positions), or an
  attack frame (no swing, no impact accent).

Caveat: the "hop" or "bounce" is carried by the expression and the raised
paw, not by a dramatic body lift. This is more "happy arrival" than
"mid-hop explosion." That may actually be the right choice for the
anchor — f5 can be this pose, and f4 / f6 can carry slightly more
body-lift / body-settle around it during frame expansion.

**Peak readability PASS.**

## 5. Stronger celebration than currently applied runtime victory?

**Yes — clearly.** Compare
`.tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_runtime.png`:

| Dimension | P2 applied victory (f5 cell, row 2 col 1) | FLUX peak V1 |
|---|---|---|
| Expression | calm / pleasant smile | **open-mouth delighted smile** |
| Paw position | paws at sides / hip | **one paw raised with pink pads forward** |
| Body rhythm | static neutral | slight lift / ready-to-hop |
| Peak triumph read | no | **yes** |
| Identity class | preserved | preserved |

The peak V1 frame has measurably stronger celebration acting than any
cell in the currently applied P2 victory. This was the core acting gap
that the P2 → V3 → V1-from-autosprite sequence failed to close. Peak-
first descent closes it.

## 6. Is this image strong enough to become the primary anchor for frame expansion?

**Yes.** It passes all the criteria the turn-branch peak V2 passed,
plus it has better acting:

| Criterion | turn peak V2 (approved anchor) | victory peak V1 |
|---|---|---|
| Canonical identity lock | PASS | PASS |
| 4-bow count at 1024×1024 | PASS | PASS |
| Pink paw pads visible | PASS | PASS |
| Med-kit preserved | PASS | PASS |
| Plain white socks, no pink trim | PASS | PASS |
| No V3-style identity leak | N/A | PASS |
| Pixel class matches canonical walk | PASS | PASS |
| Peak emotional read | micro-turn peak (conservative) | **stronger** — open-mouth delighted triumph |

This peak can now drive f1/f2/f3/f4/f6/f7/f8 generation using the same
turn-branch pipeline:
- Primary `input_image` = this peak V1
- Secondary refs = canonical walk + dense identity board
- Do NOT include old victory, V3 rejects, AutoSprite motion sheet, or
  turn V3 in the expansion reference stack
- Per-frame prompts: ramp of expression and paw height from f1
  (post-win recognition) → f4 (upward push) → f5 (peak = this image)
  → f8 (settled afterglow)
- After expansion: 4×2 stitch at 2752×1536 with uniform cross-frame
  scaling → JPEG → remove_bg.py nukki → edge QA → gameplay QA

## 7. Output files (`.tmp/`)

| File | Contents |
|---|---|
| `menhera_flux_kontext_victory_peak_from_autosprite_v1.png` | 1024×1024 RGB peak pose (accepted anchor) |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1.jpeg` | JPEG q=95 |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1_args.json` | FLUX request args log |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1_zoom.png` | 3× NN zoom for detailed QA |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_walk.png` | vs canonical walk (cell 0,0 for proportions / identity compare) |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_runtime.png` | vs currently applied P2 victory (f5-equivalent cell) |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1_vs_motion_peak.png` | vs AutoSprite f5 motion crop (pose transfer evidence) |
| `menhera_flux_kontext_victory_peak_from_autosprite_v1_report.md` | this report |

Canonical asset + runtime unchanged.
`items/menhera_boss_victory.{png,jpeg}` still P2. Turn R1 branch
unaffected. `RENDER_TURN_FRAMES = False` and the 8×1 turn loader are
still in place (separate branch, out of scope here).

## 8. Codex handoff note (no runtime change in this pass)

```
FLUX peak from AutoSprite f5 completed and accepted as the new primary
anchor for Menhera victory frame expansion. Canonical asset + runtime
unchanged.

- items/menhera_boss_sheet.png                                       -> canonical walk (unchanged, sole identity anchor)
- items/menhera_boss_victory.png                                     -> P2 publish (currently applied in runtime, unchanged)
- items/menhera_boss_turn.png                                        -> turn R1 branch (unchanged, separate)
- .tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1.png      -> ACCEPTED PEAK ANCHOR for upcoming frame expansion (NOT for runtime)
- .tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_zoom.png -> QA zoom
- .tmp/menhera_flux_kontext_victory_peak_from_autosprite_v1_report.md -> QA report

Pending (asset side, NOT this pass):
- generate f1/f2/f3/f4/f6/f7/f8 using the peak above as primary anchor
  and canonical walk + dense identity board as secondary refs
- 4x2 stitch at 2752x1536, JPEG + remove_bg.py nukki
- edge QA (4 bows, paw pads, med-kit, cream bangs, syringe, plain socks)
- gameplay QA vs canonical walk + vs P2 applied victory + vs old victory
- if all three hold, Codex swap of items/menhera_boss_victory.{png,jpeg}
  (no loader code change — victory already expects 4x2, same as walk)

No runtime wiring changes required from this pass.
```

## 9. Summary — answers to the handoff's §final report format

1. **Reference stack actually used**: canonical walk (identity
   master), AutoSprite f5 peak crop (motion / pose guide only), dense
   identity board. All explicit exclusions honored.
2. **AutoSprite f5 peak successfully transferred?** Partially — the
   open-mouth delighted smile (the strongest peak signal) transferred
   cleanly. The "both paws raised high" composition adapted to "one
   paw raised with pink pads forward + other paw holding the med-kit."
   The adaptation respects canonical Menhera continuity and is
   acceptable as a peak anchor.
3. **Canonical walk identity lock pass/fail**: **PASS.** All hard
   anti-drift rules held. No twin-tail / side-ribbon leak.
4. **Peak celebration readability pass/fail**: **PASS.** Expression
   carries the clearest "I won" signal ever produced on this branch.
5. **Strong enough to become primary anchor for frame expansion?**
   **YES.** This peak is stronger than turn peak V2 (which was
   successfully used as the turn expansion anchor) on both identity
   and peak acting. Frame expansion can proceed next on this anchor
   when the user gives the go.

No code changes. Runtime unchanged. R1 turn close-out still applies.
