# Teddy Bear Dash -- Gemini Full-Sheet V1 Report

Generated via `mcp__gemini__gemini-generate-image` using
`.tmp/teddy_bear_dash_gemini_fullsheet_prompt_v1.txt`.

Source: `.tmp/teddy_bear_dash_gemini_v1.jpeg` (2K, 16:9, 4x2 grid)
Cell size: 688x768 (same as walk sheet cell size)

---

## QA gates (from handoff v1)

| # | Gate | Result |
|---|------|--------|
| 1 | Teddy front-facing in every frame | **PASS** -- no side-profile, no 3/4 run |
| 2 | Avoids side-profile / 3/4 run behavior | **PASS** |
| 3 | Readable burst-slide arc across 8 frames | **PASS** -- clear ready -> crouch -> push-off -> peak burst -> glide -> decel -> rise -> recovery |
| 4 | f4/f5 clearly the fastest / strongest speed-read frames | **PASS** -- f4 low extension + trailing lines, f5 sustained glide with strongest motion streaks |
| 5 | Dangling eye survives as socket + button + thread | **PASS** -- thread visible on all frames, button visibly swings with velocity on f3/f4/f5 |
| 6 | Bow / ribbon / heart / safety pin / paw bow all readable | **MIXED** -- see identity audit below |
| 7 | Body scale matches walk class | **FAIL** -- see body-scale audit below |
| 8 | Reads like a dash rather than walk loop | **PASS** -- strong dash language |

## Identity lock audit vs walk sheet

Walk canonical: `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`

| Element | Walk | Dash v1 | Match? |
|---|---|---|---|
| Red X button eye | viewer-LEFT | viewer-LEFT ALL 8 frames | **PASS** |
| Empty socket + dangling button + thread | viewer-RIGHT | viewer-RIGHT ALL 8 frames | **PASS** (button swings with velocity = correct behavior) |
| Pink gingham head bow | small-medium, on head | on head all frames, but **size and angle vary more across frames than walk** | drift |
| Cream neck ribbon | modest scarf, tucked | **larger and more flowy**, billows outward on burst frames | drift |
| Heart belly patch | centered brown stitched | present but **smaller and partly occluded in several frames** | drift |
| Silver safety pin on upper chest | right side of chest (viewer-left), upper | **upper chest but position varies**, sometimes viewer-left sometimes viewer-right | drift / side mirror possible |
| Black paw bow | visible on one paw | **position appears to swap viewer-side across frames** | drift |
| Cocoa-brown plush body | matte cocoa | **slightly more saturated brown**, more volumetric shading | slight palette + shading drift |

## Body-scale audit (SKILL.md 8.1 / 8.1.1)

This is the biggest concern.

- Walk cell: 688x768 per cell, teddy fills roughly 45-50% of cell height
- Dash v1 cell: 688x768 per cell (identical canvas), but teddy visually
  fills roughly **55-65%** of cell height, especially on standing frames
  (f1, f2, f7, f8)
- Head, torso, and pelvis read larger than the walk teddy at matched
  cell dimensions

This violates SKILL.md 8.1.1's "judge by visible body read, not only
canvas / frame size" rule. Same canvas size, but the body reads bigger
in dash than in walk.

Consequence: at runtime, when both sheets are loaded into the sprite
class and scaled to the same target height, the dash teddy will look
larger than the walk teddy in-game -- the boss will appear to grow
during a dash.

## Style-class audit

| Axis | Walk | Dash v1 |
|---|---|---|
| Outline weight | thick, consistent | thicker on dash, small edge variance |
| Shading | flat | **slightly more volumetric** -- more roundness to plush body |
| Palette saturation | controlled pastel-cocoa | **slightly more saturated, richer brown** |
| Gingham bow pattern fidelity | consistent | fluctuates |

The dash is drawn in a slightly heavier / more rendered pixel-art class
than the walk. This is a detail-class drift of the kind v4 FLUX
walk-locked was explicitly trying to fix on the turn branch.

## Strengths

- **Motion arc is excellent**: clear dash beat, f4/f5 speed peak
  unambiguous, f6 decel rebound, f7 rise, f8 recovery
- **Intermediate frames all distinct**: no idle-gallery collapse
- **No printed borders / dividers / labels**: composition rule held
- **Eye identity sides stay locked**: no mirror across frames (v2 turn
  blocker stayed fixed)
- **Dangling button swings with velocity**: correct pendulum motion
  instead of static button

## Weaknesses

- **Body scale drift** -- the biggest blocker. Dash teddy reads bigger
  than walk teddy at matched cell dimensions
- **Style-class drift** -- heavier / more volumetric than walk
- **Paw bow / safety pin viewer-side** may mirror across frames; needs
  explicit viewer-side pinning in retake
- **Cream neck ribbon size drift** -- billows too big during burst
- **Heart patch occlusion** in several frames

## Decision

**HOLD for one Gemini retake.**

This is not a reject-and-stop. v1 gives us strong motion -- the single
biggest thing the FLUX walk-locked turn route could NOT deliver -- and
the fixable problems are all about asking Gemini to match the walk
size and detail class.

## Recommended retake adjustments for v2

- **Explicit body-scale clamp against walk**: "the teddy must fill the
  same percentage of each cell as it does in the walk sheet; if the
  walk teddy fills about 45-50% of cell height, dash teddy must also
  fill about 45-50%; do NOT draw a bigger bear for the dash"
- **Detail-class match to walk**: "match the same pixel-art class,
  outline weight, palette saturation, and shading flatness as the walk
  sheet; do NOT use heavier outlines or more volumetric shading for
  the dash; this is the same teddy in dash motion, not a redesigned
  heroic-pose bear"
- **Explicit viewer-side paw bow pin**: "the small black paw bow is
  ALWAYS on the teddy's left paw = viewer-right in every frame; it does
  NOT swap sides"
- **Explicit viewer-side safety pin pin**: "the silver safety pin is
  ALWAYS on the teddy's upper right chest = viewer-left in every frame;
  it does NOT swap sides"
- **Heart visibility lock**: "heart belly patch must remain centered
  on the belly and fully visible, not occluded by the safety pin or
  any paw on any frame"
- **Cream ribbon size clamp**: "cream neck ribbon stays the same modest
  scarf size as the walk sheet; do NOT let it billow bigger during
  burst frames"
- **Preserve what worked**: keep the strong f1-f8 motion arc, keep eye
  identity locked to viewer-left red X and viewer-right empty socket,
  keep the dangling button swinging with velocity

## Files

- `.tmp/teddy_bear_dash_gemini_v1.jpeg` -- raw Gemini source
- `.tmp/teddy_bear_dash_gemini_v1_report.md` -- this report

No nukki pass performed (held for retake).
