# Teddy Bear Turn -- Gemini Full-Sheet V2 Report

Generated via `mcp__gemini__gemini-generate-image` using
`.tmp/teddy_bear_turn_gemini_prompt_v2.txt`.

Source: `.tmp/teddy_bear_turn_gemini_v2.jpeg` (2K, 16:9, 4x2 grid)

Retake after v1 HOLD. This is the only allowed fast-mode retake.

---

## QA gates (from handoff v2)

| # | Gate | Result |
|---|------|--------|
| 1 | Teddy still front-facing in every frame | **PASS** (see 1a below) |
| 2 | Zero printed borders / dividers / frame outlines | **PASS** -- v1's hard-reject fixed |
| 3 | Left-right head sway clearly readable | **PASS** -- head angle now visibly varies |
| 4 | Ears visibly flap / lag at peak frames | **PASS** -- ear shapes deform across frames |
| 5 | f2, f4, f5, f7, f8 clearly distinct | **PASS** -- intermediates are now distinct |
| 6 | Dangling eye survives as socket + hanging button | **MIXED** -- survives, but the eye side SWAPS across rows (see 6a) |
| 7 | Heart belly patch fully visible | **PASS** -- heart visible in all 8 frames |
| 8 | Facial-acting change across sequence | **PASS** -- mouths vary (smile / 'O' / frown) |
| 9 | Reads like a brief turn gesture, not idle gallery | **PASS** |

### 1a. Frontal-read footnote

Frames are not a side-profile / 3/4 chart, so gate 1 technically passes.
However, the bottom-row head pose reads as enough of a head-yaw that the
opposite side of the face becomes visible -- see 6a.

### 6a. Eye identity drift (NEW v2 regression)

- **Top row (f1-f4):** red X button on viewer-LEFT eye, empty socket +
  dangling button on viewer-RIGHT eye. Matches the identity brief
  (`LEFT eye red X`, `RIGHT eye empty socket` -- teddy's left = viewer's
  right).
- **Bottom row (f5-f8):** red X button is on viewer-RIGHT eye, empty
  socket + dangling button swings to viewer-LEFT side. The face is
  effectively mirrored.

Either:
- the teddy's face is literally flipped left-right across rows (identity
  break), or
- the head is yawing enough to expose "the other side" of the face
  during the peak tilt, which skirts the 3/4-chart hard-reject even
  though individual frames still look roughly frontal.

Either way the eye-assignment is no longer locked, which propagates
into any future attack / dash / victory / defeat regeneration that uses
this sheet as reference.

## Other identity drift (new v2 regressions)

| Element | v1 | v2 |
|---|---|---|
| Cream neck ribbon | clearly visible, sized like bow | shrunk to a small faint shape under the neck, barely readable at gameplay scale |
| Silver safety pin on upper chest | clearly on upper chest, next to heart | shrunk, dangling-ish near neck, no longer reads as "safety pin on upper chest" |
| Left paw black bow | clearly visible on left paw | nearly invisible in most frames |
| Pink gingham head bow size | consistent across frames | size varies noticeably between frames |

## v1 failures vs v2 outcomes

| v1 failure | v2 outcome |
|---|---|
| Printed cell borders | **FIXED** |
| Weak head sway amplitude | **FIXED** |
| Subtle ear flap | **FIXED** |
| Near-duplicate middle frames | **FIXED** |
| Heart occluded by safety pin | **FIXED** |

## New v2 failures

| New failure | Severity |
|---|---|
| Eye red-X / empty-socket positions swap between top and bottom rows | **Blocker** -- identity lock broken |
| Cream neck ribbon shrunk to near-invisible | **Drift** -- identity element downgraded |
| Safety pin lost its "upper chest" placement | **Drift** |
| Left paw black bow almost lost | **Drift** |
| Pink gingham bow size varies across frames | **Drift** |

## Decision

**REJECT and stop.**

Fast-mode rule from handoff v2: "if v2 still fails, stop the turn branch
and wait for user direction." v2 fixed every v1 failure cleanly, but
introduced a new blocker (eye-side swap / face-mirror) and several
identity drifts. Promoting this sheet would poison future teddy sheets
that use it as cross-reference.

## Recommended user-direction options

The user should pick one before any further teddy turn work:

1. **Stop teddy turn work.** Ship the walk + attack set; use a hop-only
   runtime turn accent with no visible turn sheet (per SKILL.md 9.1.4 /
   CLAUDE.md "turn-hop requests do not require visible turn-sheet
   playback").
2. **Salvage v2 as runtime-only auxiliary, non-anchor.** Use only the 4
   top-row frames (f1-f4) where eye identity is correct, loop them as a
   short half-wobble. Document as `runtime-only auxiliary turn sheet,
   non-anchor` per CLAUDE.md. The walk sheet remains the sole identity
   anchor.
3. **Switch renderer.** Send the brief to FLUX Kontext using the
   accepted walk sheet as an identity reference, or to AutoSprite for
   motion ideation. Gemini has now eaten both fast-mode attempts on this
   branch.
4. **Explicit retry authorization.** User explicitly overrides the
   fast-mode stop rule and authorizes a v3 Gemini pass with a stricter
   eye-identity lock ("red X button ONLY on the teddy's right side of
   face -- viewer-left -- in every single frame; dangling button ONLY
   on the teddy's left side of face -- viewer-right -- in every single
   frame; the face does NOT mirror between frames").

## Files

- `.tmp/teddy_bear_turn_gemini_v2.jpeg` -- raw Gemini source
- `.tmp/teddy_bear_turn_gemini_v2_report.md` -- this report

No nukki pass was performed (rejected).
