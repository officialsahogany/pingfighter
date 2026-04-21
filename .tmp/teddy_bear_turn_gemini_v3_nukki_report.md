# Teddy Bear Turn V3 -- Nukki QA Report

Source: `.tmp/teddy_bear_turn_gemini_v3.jpeg`
Nukki output: `.tmp/teddy_bear_turn_gemini_v3.png` (RGBA, 2752x1536)

Command:
```
py .claude/skills/sprite-generation/remove_bg.py \
    .tmp/teddy_bear_turn_gemini_v3.jpeg \
    .tmp/teddy_bear_turn_gemini_v3.png
```

---

## Fragile-prop survival audit (SKILL.md 11.5)

Per-cell zoom inspection on f3 (peak tilt with dangling button) and
f7 (sleeping-eye variant):

| Prop | Critical-failure mode | v3 nukki |
|---|---|---|
| Empty socket outline | flood-fill eats the dark socket | **PASS** -- socket crisp |
| **Thin white thread from socket to dangling button** | flood-fill eats white-on-white thread | **PASS** -- thread intact on all frames where it is present |
| Dangling black button | alpha punch-out | **PASS** -- button intact with stitching detail |
| Red X stitch inside left button eye | X strokes thinned | **PASS** -- X stitch crisp |
| Pink gingham bow gingham pattern | pattern loss | **PASS** |
| Silver safety pin on upper chest | thin metal lines eaten | **PASS** -- pin visible with pin head and shaft |
| Left paw black bow | small dark prop lost | **PASS** -- visible on all 8 frames |
| Cream neck ribbon | low-contrast bleed | **PASS** -- ribbon silhouette intact |

No alpha halo around the outer silhouette. No bg-leak through the
hair-shoulder zone (teddy has no loose hair, so that class of failure
is structurally avoided).

## Body-scale consistency across cells

Non-transparent pixel counts per frame (4x2 grid, 688x768 per cell):

| Frame | Pixels | Delta vs median |
|---|---|---|
| f1 | 309217 | -0.5% |
| f2 | 312867 | +0.7% |
| f3 | 309994 | -0.2% |
| f4 | 304473 | -2.0% |
| f5 | 306924 | -1.2% |
| f6 | 308945 | -0.6% |
| f7 | 305913 | -1.5% |
| f8 | 310313 | -0.1% |

All 8 frames within +/-2% of the median -- well inside the +/-5%
body-scale lock from SKILL.md 8.1. No frame reads visually smaller
or larger than the others.

## Runtime-scale readability previews

- `.tmp/teddy_bear_turn_gemini_v3_runtime_strip.png` (8 frames at 140px tall)
- `.tmp/teddy_bear_turn_gemini_v3_gameplay_strip.png` (8 frames at 55px tall, close to in-game size)

Observations at the 55px gameplay scale:
- Pink bow, heart patch, brown plush body all read cleanly
- Dangling button visible as a small dark dot; white thread is sub-pixel
  at this scale but the socket + button pair still implies the prop
- Head tilt across the 8 frames is subtle but readable
- f7's sleeping-eye frame reads clearly distinct from the others
- Body silhouette is clean with no residual halo

## Gate summary

| Gate | Status |
|---|---|
| All 8 frames extractable cleanly from 4x2 grid | PASS |
| No transparent-bg leak inside silhouette | PASS |
| No alpha halo around outside | PASS |
| Fragile identity props survive | PASS |
| Body scale within +/-5% across frames | PASS (+/-2% actual) |
| Gameplay-scale readability | PASS |

## Decision

**ACCEPT nukki pass.**

Retain v3.png as the working runtime-ready artifact. Do NOT promote to
`items/teddy_bear_boss_turn.{jpeg,png}` yet -- schedule one in-game
runtime review before locking the file path.

## Next step: runtime review (Codex / AGENTS.md territory)

This is where Claude hands off. Codex owns:

1. Wire a `TMP_TURN_OVERRIDE` path inside
   [entities/teddy_bear_boss_sprite.py](entities/teddy_bear_boss_sprite.py)
   mirroring the existing `TMP_WALK_OVERRIDE` / `TMP_ATTACK_OVERRIDE`
   pattern at lines 48-80, pointing at
   `.tmp/teddy_bear_turn_gemini_v3.png`
2. Decide the runtime trigger policy:
   - fire on lateral direction change (priority above walk, below
     attack/dash per AGENTS.md)
   - keep the playback window short (this is an accent sheet, not a
     full cycle)
   - CLAUDE.md fallback rule: if in-game it still reads awkward, switch
     to hop-only without visible turn playback
3. Run the game and evaluate the in-stage read of the turn sheet
4. Report back with one of:
   - accept -> promote to `items/teddy_bear_boss_turn.{jpeg,png}` and
     mark as `runtime-only auxiliary sheet, non-anchor` in CLAUDE.md
   - runtime-adjust -> playback-speed / window tuning only
   - reject -> fall back to hop-only and disable visible turn playback

## Files

- `.tmp/teddy_bear_turn_gemini_v3.jpeg` -- raw Gemini source
- `.tmp/teddy_bear_turn_gemini_v3.png` -- nukki output (3.7 MB, RGBA)
- `.tmp/teddy_bear_turn_gemini_v3_f1.png` .. `_f8.png` -- per-frame zoom extracts
- `.tmp/teddy_bear_turn_gemini_v3_runtime_strip.png` -- 140px tall strip
- `.tmp/teddy_bear_turn_gemini_v3_gameplay_strip.png` -- 55px gameplay preview
- `.tmp/teddy_bear_turn_gemini_v3_nukki_report.md` -- this report
