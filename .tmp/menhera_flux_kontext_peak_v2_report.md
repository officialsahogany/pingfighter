# Menhera Turn FLUX Kontext Peak Pose — V2 Report

**Status: 4-BOW CONSTRAINT SATISFIED. Identity lock holds. Style class holds. This is the usable primary anchor for entry / recovery expansion. Canonical turn NOT overwritten.**

## 1. What V2 adjusted vs V1

- Primary `input_image` switched from the dense identity board to **V1
  FLUX output itself** (`.tmp/menhera_flux_kontext_peak_v1.png`). V1
  had already solved identity + pixel class; V2 uses it as the strong
  style/identity anchor and only narrows the remaining drift.
- Prompt now explicitly requires **exactly FOUR black bows stacked in
  a clean vertical column on the white center front panel**, with the
  explicit permission to adjust paw / arm placement if needed so the
  count stays legible.
- Added the dense identity board, canonical walk, and victory as
  secondary references (inputs 2–4), so FLUX keeps resolving identity
  props against them rather than drifting from the anchor.
- Everything else (pose brief, style lock, bans) was preserved
  verbatim from V1.

## 2. References actually used

| Slot | File | Role |
|---|---|---|
| `input_image` | `.tmp/menhera_flux_kontext_peak_v1.png` | **primary anchor** (proven V1 FLUX peak) |
| `input_image_2` | `.tmp/menhera_autosprite_reference_board_v2.png` | dense identity board |
| `input_image_3` | `items/menhera_boss_sheet.png` | canonical walk anchor |
| `input_image_4` | `items/menhera_boss_victory.png` | quality / clarity class reference |

Model: `flux_kontext_max`, `aspect_ratio = 1:1`, `output_format = png`,
`safety_tolerance = 2`, seed not pinned.

## 3. Output files (`.tmp/`)

| File | Content |
|------|---------|
| `menhera_flux_kontext_peak_v2.png` | FLUX Kontext max output, 1024×1024 RGB PNG |
| `menhera_flux_kontext_peak_v2_args.json` | FLUX request args log |
| `menhera_flux_kontext_peak_v2_zoom.png` | 2× nearest-neighbor zoom |
| `menhera_flux_kontext_peak_v2_bows_crop.png` | 3× zoomed crop of the torso / bow region for bow-count audit |
| `menhera_flux_kontext_peak_v1_vs_v2.png` | V1 vs V2 side-by-side for quick diff |
| `menhera_flux_kontext_peak_v2_report.md` | This report |

`items/menhera_boss_turn.png` is **NOT** overwritten.

## 4. Bow-count audit (the targeted fix)

From the bow-region crop at 3× zoom, the white center front panel
clearly shows **FOUR (4) black bow shapes stacked in a clean vertical
column**, plus a small white collar tie above the first bow. The paw
no longer occludes the bottom bow. **Targeted constraint achieved.**

## 5. Identity lock QA vs canonical

| Element | V1 FLUX | V2 FLUX | Result |
|---|---|---|---|
| Exactly 4 black vertical bows on white panel | 3 | **4** | **FIXED** |
| Cream / blonde inner front bangs | present but asymmetric split | **present and more symmetric** with canonical | PASS (improved) |
| Pink fluffy outer hair silhouette | preserved | preserved | PASS |
| Pink / white gingham nurse cap + red cross | visible | visible (slightly cleaner gingham) | PASS |
| Syringe on cap | present | present | PASS |
| Red front ribbon | small front accent | small red accents on cap/hair sides (slight drift toward 2 side ribbons) | partial — not a regression from V1 |
| No black cat ears | absent | absent | PASS |
| Gray / silver eyes with lashes | preserved | preserved, slight blush accents on cheeks | PASS |
| One pink heart cheek mark | correct side | correct side | PASS |
| Pink outfit + white center panel | present | present | PASS |
| Dark gray cat-paw gloves + PINK PAW PADS | present, pads visible on raised paw | present, pads visible on raised paw | PASS |
| White med-kit pouch with pink cross, same side | present | **more prominently visible** | PASS (improved) |
| Pink check cloth-tail motif near med-kit | present | present | PASS |
| White thigh-high socks | present | present, now with small pink bow accent at sock-top (minor drift, not in canonical) | partial — **minor new drift** to watch in next pass |
| Black X ankle accessories | present | present on one ankle | PASS |
| Petite chibi body | present | present | PASS |
| Thick black pixel outlines | present | present, slightly cleaner | PASS |

**Net identity delta vs V1**: the intended fix (4 bows) is in, and cream
bangs symmetry + med-kit visibility improved as a bonus. One minor new
drift appeared (small pink bow accents on sock tops that are not on the
canonical walk) but it is cosmetic, does not break gameplay
readability, and can be addressed in a later narrow pass if needed.

## 6. Style class QA

| Rule | Result | Note |
|---|---|---|
| 16-bit retro pixel art | PASS | clearly pixelated, large block rendering |
| Chibi proportions | PASS | |
| Thick black pixel outlines | PASS | matches V1, possibly slightly cleaner |
| Flat limited-saturation pastel palette | PASS | remaining hair highlight is within canonical palette band |
| Clean hard-edged pixels | PASS | |
| No anti-aliased anime softness | PASS | |
| No painterly shading | PASS | |
| No modern mobile-game chibi rendering | PASS | |
| Same clarity class as canonical walk + victory | PASS | materially in the same PingFighter pixel family |

## 7. Pose QA

| Rule | Result |
|---|---|
| Body and face FRONT-FACING | PASS |
| Slight chin lift / dreamy upward gaze | present, soft |
| Tiny outward paw preparation | **present** — one paw-gloved hand raised with pink pads visible |
| Tiny knee gather | weak / present |
| Compact whole-body redirect accent | present in aggregate |
| NOT greeting wave | PASS |
| NOT attack swing | PASS |
| NOT dance / theatrical | PASS |
| NOT tray hold | PASS |
| NOT side profile / 3/4 turn | PASS |

Same caveat as V1: the pose reads slightly more as "conservative charm-idle
with a paw out" than a strongly telegraphed peak redirect. That is
acceptable here because the full turn-arc read will come from the
surrounding entry / recovery frames, not from the peak alone.

## 8. Is V2 a usable primary anchor for entry / recovery / full turn?

**Yes.** V2 satisfies the V1 handoff's original success criteria plus
the V2 targeted fix:

- Same Menhera identity as canonical walk ✓
- Same PingFighter 16-bit pixel clarity class ✓
- Micro-turn peak pose with conservative amplitude ✓
- 4-bow count locked ✓

Treat `menhera_flux_kontext_peak_v2.png` as the **primary anchor for
the next phase**: entry (`plant → chin-lift → peak-v2`) and recovery
(`peak-v2 → rebound → settle → walk-return`) frames should all be
generated with V2 in `input_image`, plus the dense identity board and
the canonical walk in secondary slots. Do not regenerate the peak
again unless a future pass surfaces a new, hard-to-accept drift.

Minor things to watch in future passes (NOT blockers for expansion):

- Sock-top pink bow accent is not in the canonical walk. Can be
  stripped in a later narrow edit pass, but is not a gameplay-scale
  readability failure.
- Front cap ribbon vs side ribbons — V2 landed on small side accents
  instead of a single front ribbon. Keep an eye on it across the turn
  arc; if it drifts further, narrow-prompt it back.

## 9. Canonical overwrite?

**No.** Keep `items/menhera_boss_turn.png` untouched. Canonical
promotion still waits for a full stitched 4×2 8-frame turn sheet
passing the `sprite-generation/checklists.md` turn-sheet QA. V2 is the
now-approved peak anchor that unlocks generating the other seven
frames with discipline, not a finished sheet.

Runtime behavior unchanged: front-biased canonical walk + hop-only
direction-change accent. No `pingfighter.py` / `entities/menhera_boss_sprite.py`
edits from this pass.

## 10. Recommended next actions (user decides)

1. **Entry frames** (3 images) via `flux_kontext_max`:
   - `input_image = .tmp/menhera_flux_kontext_peak_v2.png` (primary)
   - `input_image_2 = .tmp/menhera_autosprite_reference_board_v2.png`
   - `input_image_3 = items/menhera_boss_sheet.png`
   - `input_image_4 = items/menhera_boss_victory.png`
   - narrow prompts for: (a) walk-compatible carry-in, (b) small plant /
     compress, (c) slight chin-lift pre-peak
   - outputs: `.tmp/menhera_flux_kontext_entry_{1,2,3}.png`
2. **Recovery frames** (3 images), same stack:
   - narrow prompts for: (a) tiny rebound from peak, (b) settle toward
     neutral frontal, (c) walk-compatible return
   - outputs: `.tmp/menhera_flux_kontext_recovery_{1,2,3}.png`
3. **Stitch** into 4×2 8-frame layout:
   - frame 1 = entry 1, 2 = entry 2, 3 = entry 3, 4 = peak v2,
     5 = recovery 1, 6 = recovery 2, 7 = recovery 3, 8 = walk-return
   - save as `.tmp/menhera_turn_flux_sheet_v1.png`
4. **Nukki** using `.claude/skills/sprite-generation/remove_bg.py` on
   the stitched JPEG export.
5. Run the full `sprite-generation/checklists.md` turn-sheet QA and
   only then decide on canonical promotion.

## 11. Codex handoff note

```
FLUX Kontext peak pose V2 accepted as the primary anchor for Menhera
turn expansion. Canonical turn asset still unchanged.

- items/menhera_boss_sheet.png                       -> canonical walk (unchanged)
- items/menhera_boss_turn.png                        -> previous turn (unchanged)
- items/menhera_boss_victory.png                     -> quality reference (unchanged)
- .tmp/menhera_flux_kontext_peak_v2.png              -> ACCEPTED peak anchor (NOT for runtime)
- .tmp/menhera_flux_kontext_peak_v2_zoom.png         -> QA zoom
- .tmp/menhera_flux_kontext_peak_v2_bows_crop.png    -> bow-count audit crop
- .tmp/menhera_flux_kontext_peak_v1_vs_v2.png        -> V1 vs V2 diff
- .tmp/menhera_flux_kontext_peak_v2_report.md        -> QA report

Runtime policy unchanged:
  - front-biased canonical walk stays canonical
  - direction change uses hop-only runtime accent
  - visible turn-sheet playback stays off until a FULL stitched
    FLUX-based 8-frame turn sheet passes sprite-generation QA

FLUX Kontext max is now the approved final renderer path for Menhera
turn art. AutoSprite stays in motion / pose-blocking ideation role.
Gemini MCP remains a parallel known-good path if FLUX regresses.

No runtime wiring changes required from this experiment.
```
