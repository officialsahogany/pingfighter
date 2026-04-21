# Teddy Bear Dash -- Gemini Full-Sheet V2 Report

Generated via `mcp__gemini__gemini-generate-image` using
`.tmp/teddy_bear_dash_gemini_fullsheet_prompt_v2.txt`.

Source: `.tmp/teddy_bear_dash_gemini_v2.jpeg` (2K, 16:9, 4x2 grid)

Retake after v1 HOLD (fast-mode single allowed retake).

---

## Immediate hard-reject finding

**Labels are printed into the sheet.**

All 8 cells have black text labels directly rendered beneath the
character: "Ready", "Crouch Prep", "Push-off", "Burst-Extension",
"Sustained Slide", "Deceleration Rebound", "Rise", "Recovery".

Both the prompt and SKILL.md Section 7 explicitly forbid labels. The
prompt's hard-reject list includes "any printed border or divider
appears"; labels fall under the same no-print rule.

This alone triggers a hard reject regardless of the other axes.

## QA gates (from handoff v2)

| # | Gate | Result |
|---|------|--------|
| 1 | Teddy front-facing in every frame | PASS |
| 2 | Avoids side-profile / 3/4 run | PASS |
| 3 | v1 burst-slide motion arc preserved | PASS |
| 4 | f4/f5 strongest speed-read frames | PASS |
| 5 | Dangling eye survives (socket + button + thread) | PASS (button swings with velocity on f5) |
| 6 | Safety pin + black paw bow pinned to same viewer-side all 8 frames | **MIXED** -- consistent across frames but on the **opposite** viewer-side from the prompt pin (pin: viewer-LEFT / paw bow: viewer-LEFT; prompt asked pin: viewer-LEFT / paw bow: viewer-RIGHT) |
| 7 | Heart fully visible in all 8 frames | **PARTIAL** -- visible but occluded in f2 and f5 by safety pin / paw |
| 8 | Body scale matches walk class | **PARTIAL** -- smaller than v1 but still noticeably larger than walk (approx 55-60% vs walk's 45-50% cell-height fill) |
| 9 | Pixel-art detail class matches walk | **PARTIAL** -- outline weight closer to walk, but shading still slightly more volumetric |

## v1 -> v2 changes

| Axis | v1 | v2 |
|---|---|---|
| Printed labels | none | **printed under every cell (hard reject)** |
| Body-scale drift | 55-65% cell fill | 55-60% cell fill (partial fix) |
| Detail-class drift | noticeably heavier than walk | closer to walk but not matched |
| Cream ribbon billow | oversized during burst | more modest (fixed) |
| Heart occlusion | partial in some frames | partial in f2/f5 (not fully fixed) |
| Paw bow viewer-side | ambiguous | consistent but on wrong side vs prompt pin |
| Safety pin viewer-side | varied | consistent on viewer-LEFT (matches prompt) |
| Motion arc | strong | **preserved** |
| Eye identity lock | held | held |
| Dangling button swing | present | present with clear velocity on f5 |

## Decision

**REJECT and stop** per handoff v2's 2-choice fast-mode rule.

Labels printed into the sheet are a hard reject, and the fast-mode
retake quota is exhausted. Per handoff: "this is the one allowed
retake after v1 HOLD. Do not start a deeper ladder automatically."

## Teddy-bear-dash branch state

| Version | Renderer | Outcome |
|---|---|---|
| v1 | Gemini full-sheet | HOLD -- strong motion, body-scale / detail-class drift |
| v2 | Gemini full-sheet retake | **REJECT** -- printed labels + partial scale fix |

## User-decision options

Three paths remain. None is automatic -- this needs an explicit call.

1. **Ship v1 as-is.** v1 has no printed labels, strong motion, and
   eye identity lock. Accept the body-scale drift and plan to
   compensate at runtime by tuning the dash-sheet scale factor in
   `entities/teddy_bear_boss_sprite.py` so the in-game body reads at
   walk scale. This pushes the problem from asset side to runtime side
   (AGENTS.md) but the asset is usable.
2. **Switch renderer to AutoSprite + FLUX per SKILL.md 2.1.**
   AutoSprite for motion ideation -> lock a canonical peak pose in
   FLUX -> expand the other 7 frames in FLUX using the walk sheet as
   identity anchor. This is the role-split pipeline the skill
   specifically recommends for mixed motion-and-identity jobs. Slower
   but avoids Gemini's drift patterns.
3. **Explicit authorization for Gemini v3.** User overrides the
   fast-mode stop. v3 prompt would reinforce "no labels, no text, no
   captions, no printed words anywhere" with multiple anti-text
   restatements, plus tighten body-scale language further. Risk: each
   Gemini retake has a history of fixing one axis while regressing
   another.

## Files

- `.tmp/teddy_bear_dash_gemini_v2.jpeg` -- raw Gemini source
- `.tmp/teddy_bear_dash_gemini_v2_report.md` -- this report

No nukki performed (rejected).
