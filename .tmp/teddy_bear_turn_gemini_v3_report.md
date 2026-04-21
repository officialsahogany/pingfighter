# Teddy Bear Turn -- Gemini Full-Sheet V3 Report

Generated via `mcp__gemini__gemini-generate-image` using
`.tmp/teddy_bear_turn_gemini_prompt_v3.txt`.

Source: `.tmp/teddy_bear_turn_gemini_v3.jpeg` (2K, 16:9, 4x2 grid)

Remake after v2 REJECT (eye-mirror blocker) under explicit user
authorization to bypass fast-mode stop.

---

## QA gates (from handoff v3)

| # | Gate | Result |
|---|------|--------|
| 1 | Teddy front-facing in every frame | **PASS** -- all 8 cells frontal, no profile |
| 2 | Zero printed borders / dividers / frame outlines | **PASS** -- unbroken white field |
| 3 | More natural and less exaggerated than rejected runtime version | **PASS** -- soft hesitation feel, no "no-no" wag |
| 4 | Head tilt readable but modest | **PASS** -- visible without being theatrical |
| 5 | Ears visibly lag / flap | **WEAK-PASS** -- ears shift shape/height modestly; per brief "modest" motion was the goal |
| 6 | Middle frames distinct | **PASS** -- f7 sleeping-eye accent is a strong differentiator, f3/f4 slight-bow variance, f5/f6 clear opposite-direction tilt |
| 7 | Eye assignments locked with no mirroring across rows | **PASS** -- red X stays on viewer-LEFT eye in ALL 8 frames; empty socket stays on viewer-RIGHT in ALL 8 frames (dangling button swings with pendulum momentum = correct behavior, not identity swap) |
| 8 | Ribbon / safety pin / heart patch / left paw bow readable | **PASS** -- all four preserved cleanly |
| 9 | Reads as brief turn accent, not idle/walk | **PASS** |

## Identity lock audit vs v1 / v2

| Element | v1 | v2 | v3 |
|---|---|---|---|
| Cocoa-brown plush body | ok | ok | ok |
| Pink gingham head bow | consistent | size varies | consistent, size stable |
| LEFT eye red X button | viewer-left | viewer-left top / **viewer-right bottom (mirror)** | **viewer-left ALL 8 frames** |
| RIGHT empty socket + dangling button | viewer-right | viewer-right top / **viewer-left bottom (mirror)** | **viewer-right ALL 8 frames** (button pendulum-swings with tilt) |
| Cream neck ribbon | visible | shrunk to near-invisible | **restored, clearly visible** |
| Heart belly patch | partly occluded by pin | fully visible (red heart) | **fully visible (brown stitched heart, matches v1 palette)** |
| Safety pin on upper chest | on chest but overlapping heart | shrunk / displaced from chest | **restored on upper chest next to heart, no overlap** |
| Left paw black bow | visible | nearly lost | **restored, visible on left paw all 8 frames** |
| Body scale | within +/-5% | within +/-5% | **within +/-5%** |

v3 is the only version that keeps every identity element locked across
all 8 frames simultaneously.

## v1/v2 failures vs v3 outcomes

| Failure source | v3 status |
|---|---|
| v1: printed cell borders | **FIXED** (v2 already fixed; held) |
| v1: weak head sway | **FIXED** (v2 already fixed; held at modest level) |
| v1: subtle ear flap | **HELD** -- ears flap modestly per "natural, not theatrical" brief |
| v1: near-duplicate middle frames | **FIXED** (sleeping-eye f7 + directional distinctness) |
| v1: heart occluded by safety pin | **FIXED** (v2 already fixed; held) |
| v2: eye red-X / socket side-swap | **FIXED** -- strict viewer-side lock held |
| v2: cream ribbon shrunk | **FIXED** -- ribbon clearly readable |
| v2: safety pin displaced | **FIXED** -- back on upper chest |
| v2: paw bow lost | **FIXED** -- visible on left paw |
| v2: bow size variance | **FIXED** -- bow size stable |

## Bonus acting

f7 shows eyes closed (soft sleepy/blink look) during the settle phase.
This is inside the brief's allowed "blink, tiny mouth change, soft
sleepy look" acting range and adds a distinct accent that helps the
sequence not collapse into an idle gallery.

## Silhouette check

Head -> ears -> bow -> shoulders read as one closed shape in every
frame. No transparent hair/shoulder gap (teddy has no loose hair, so
silhouette continuity is structurally safer than for Menhera).

## Decision

**ACCEPT for runtime-facing candidate.**

Per CLAUDE.md / SKILL.md turn-sheet policy: accept as
**runtime-only auxiliary sheet, non-anchor**. The walking sheet
(`items/teddy_bear_boss_sheet.png` once promoted from the plush
locomotion candidate) remains the sole identity anchor. Do NOT use
this turn sheet as a regeneration reference for future attack / dash /
victory / defeat work.

## Next steps (in order)

1. Run nukki on v3:
   ```
   py .claude/skills/sprite-generation/remove_bg.py \
       .tmp/teddy_bear_turn_gemini_v3.jpeg \
       .tmp/teddy_bear_turn_gemini_v3.png
   ```
2. Inspect post-nukki PNG for any alpha damage on the small props
   (dangling button, thin white thread, safety pin, paw bow). These
   are the teddy's fragile identity props and are the most likely
   nukki failure points (per SKILL.md 11.5).
3. If nukki passes QA, promote to final locations:
   - `items/teddy_bear_boss_turn.jpeg`
   - `items/teddy_bear_boss_turn.png`
4. Hand off to Codex via AGENTS.md with explicit notes:
   - runtime-only auxiliary sheet, non-anchor
   - walking sheet remains canonical identity anchor
   - 4x2 grid, 8 frames, f1 entry -> f8 recovery
   - motion is modest plush hesitation, pair with short playback window
   - if runtime still reads awkward, fall back to hop-only without
     visible turn sheet per CLAUDE.md

## Files

- `.tmp/teddy_bear_turn_gemini_v3.jpeg` -- raw Gemini source (this pass)
- `.tmp/teddy_bear_turn_gemini_v3_report.md` -- this report
- `.tmp/teddy_bear_turn_gemini_v3.png` -- pending nukki pass
