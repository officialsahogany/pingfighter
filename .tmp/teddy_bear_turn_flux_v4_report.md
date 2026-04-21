# Teddy Bear Turn -- FLUX Walk-Locked V4 Report

Generated via `mcp__flux-kontext__flux_kontext_max` with walk reference only.

- Input image: `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`
- Prompt source: `.tmp/teddy_bear_turn_flux_walklocked_prompt_v4.txt`
- Output: `.tmp/teddy_bear_turn_flux_v4.jpeg` (4x2 grid, 16:9)

Route rationale per handoff v4: FLUX as correction / adaptation tool
rather than fresh inventor, to fix v3's detail-class drift from the walk.

---

## Identity-class audit vs accepted walk sheet

This is the gate that v3 Gemini underperformed on.

| Element | Walk sheet | FLUX v4 | Match? |
|---|---|---|---|
| Plush head + ear shape | rounder, wider | same | **PASS** |
| Outline weight | thick black | same | **PASS** |
| Bow style (pink gingham) | small-medium, on head | same | **PASS** (close to walk, not v3's stylized variant) |
| Red X button eye position | viewer-left | viewer-left ALL 8 frames | **PASS** |
| Empty socket + hanging button | viewer-right | viewer-right ALL 8 frames | **PASS** (no mirror) |
| Cream neck ribbon | visible | visible | **PASS** |
| Safety pin on upper chest | yes, distinctive | yes, matches walk pin class | **PASS** |
| Heart belly patch | brown stitched heart | brown stitched heart, same palette | **PASS** |
| Left paw black bow | small, present | small, present | **PASS** |
| Body proportions | chibi, short | same | **PASS** |
| Palette / saturation | controlled pastel | matches | **PASS** |

**Verdict:** FLUX Kontext Max DID hold the walk detail class cleanly.
This was the v3 Gemini failure axis, and v4 fixed it.

## Motion audit

This is where v4 collapses.

| Frame slot | Expected role | Actual |
|---|---|---|
| f1 | neutral entry | neutral frontal |
| f2 | tiny right-side tilt begins | near-identical to f1 |
| f3 | modest right-side peak tilt + ear lag | near-identical to f1 |
| f4 | rebound through center | near-identical to f1 |
| f5 | tiny left-side tilt begins | near-identical to f1 (very minor bow shift) |
| f6 | modest left-side peak tilt + ear lag | near-identical to f5 |
| f7 | settle | near-identical |
| f8 | neutral recovery | near-identical |

- No visible head-tilt angle on any frame
- No ear-lag / ear-compression variation
- No dangling-button swing
- No body rebound
- 8 near-duplicate neutral poses with minor bow / chest variation

The handoff's constitutional rule -- "if motion energy and identity
fidelity conflict, preserve identity fidelity" -- was obeyed TOO
strictly. FLUX chose pure identity fidelity at the cost of any visible
turn accent.

Likely cause: the input image was a 4x2 walk sheet, not a single pose.
FLUX Kontext image-to-image replicated the grid structure and produced
8 similar poses instead of 8 distinct turn frames.

## v3 Gemini vs v4 FLUX trade-off

| Axis | v3 Gemini | v4 FLUX Max |
|---|---|---|
| Walk detail-class match | weak | **strong** |
| Visible head tilt | modest but readable | **none** |
| Ear lag / flap | weak but present | **none** |
| Dangling button swing | pendulum motion | none |
| Sleepy-blink acting variety | f7 variation | no variety |
| Eye identity lock (red X / socket sides) | held | held |
| Safety pin / paw bow / ribbon preservation | held | held |
| Composition (no borders) | held | held |
| Body scale consistency | within +/-2% | within +/-2% (but all 8 are essentially one pose) |

v3 has motion but drifted in detail; v4 holds the walk but is effectively
a static sheet. Neither is shippable as a runtime turn accent by itself.

## Decision

**REJECT and stop** per handoff v4's 2-choice rule.

This is not a lazy rejection -- v4 proves FLUX Kontext Max CAN hold
the walk identity. It just also proves that feeding FLUX a 4x2 walk
sheet produces a 4x2 repeat of that walk pose, not a turn sequence.

## Next steps (user decision)

The turn branch has now consumed:
- v1 Gemini (borders + idle-gallery)
- v2 Gemini (eye-mirror blocker)
- v3 Gemini (ACCEPTED after strict prompt, then runtime concerns)
- v4 FLUX Max walk-locked (perfect identity, no motion)

Three remaining options, no in-between:

1. **Ship v3 as runtime-only auxiliary, non-anchor.** v3 did pass QA
   and nukki. The detail-class concern was the reason for the FLUX
   pivot; if in-game runtime review is acceptable, v3 is the best
   balance between identity and motion. Codex wires it, and if it
   reads poorly in-game, fall back to hop-only per CLAUDE.md.
2. **Stop visible-turn work entirely.** Accept the CLAUDE.md
   hop-only-without-visible-turn-sheet route as the permanent answer.
   No turn sheet ships.
3. **One more FLUX attempt, single-pose input.** Crop a single walk
   frame (e.g. f1 from the walk sheet) and feed that as the identity
   reference with an explicit instruction to produce a FRESH 8-frame
   4x2 turn (not modify the input layout). This is not an automatic
   ladder step -- it requires explicit user authorization, because
   we are already past the fast-mode stop and now past a second
   explicit-authorization branch.

## Files

- `.tmp/teddy_bear_turn_flux_v4.jpeg` -- FLUX output
- `.tmp/teddy_bear_turn_flux_v4_report.md` -- this report
