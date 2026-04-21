# Teddy Bear Turn -- Gemini Natural Front-Facing Remake V3

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Status

The previous runtime auxiliary turn was disabled after in-game review felt
unnatural.

This `v3` branch is an explicit user-authorized remake after runtime
feedback, so it is allowed despite the earlier fast-mode stop.

## Objective

Generate a more natural teddy turn sheet that keeps the good frontal read
but avoids:
- unnatural exaggerated wagging
- mirrored lower-row face identity
- visible turn-sheet awkwardness at runtime

## Design direction

This should feel like:
- a short plush hesitation / direction-change accent
- gentle head tilt and return
- ears lagging softly
- a tiny body rebound
- maybe a subtle paw adjustment

This should NOT feel like:
- a rotation chart
- a spin
- a greeting wave
- a big comedic head-shake

## Absolute identity lock

These must stay fixed in every frame:
- viewer-left eye = red X button
- viewer-right eye = empty socket + hanging detached button on white thread
- pink gingham bow stays on the head
- cream neck ribbon stays clearly readable
- safety pin stays on upper chest
- heart belly patch stays centered and visible
- black bow stays on the left paw

Explicitly reject any result where the face mirrors or swaps sides between
top and bottom rows.

## Motion target

Use the 8 frames as:
- f1 neutral entry
- f2 slight tilt starts
- f3 gentle peak tilt one side
- f4 rebound through center
- f5 slight opposite tilt starts
- f6 gentle opposite peak tilt
- f7 settle
- f8 neutral recovery

Notes:
- tilt should be modest but readable
- ears must visibly change shape / height
- intermediates must be distinct
- facial acting can vary slightly
- optional tiny paw-near-face cue is allowed in one brief frame only if it
  does not hide the dangling-eye read

## Composition lock

Zero printed borders / dividers / frame outlines.
Background must be one unbroken flat white field.

## Output

Save:
- `.tmp/teddy_bear_turn_gemini_v3.jpeg` or `.png`
- `.tmp/teddy_bear_turn_gemini_v3_zoom.png`
- `.tmp/teddy_bear_turn_gemini_v3_report.md`

## QA gates

Report explicitly:

1. Is the teddy front-facing in every frame?
2. Are there zero printed borders / dividers / frame outlines?
3. Is the turn more natural and less exaggerated than the rejected runtime version?
4. Is the head tilt readable but modest?
5. Do the ears visibly lag / flap?
6. Are the middle frames distinct?
7. Do the eye assignments stay locked with no mirroring across rows?
8. Do ribbon, safety pin, heart patch, and left paw bow stay readable?
9. Does the sequence read like a brief turn accent rather than idle or walk?

## Decision

End with one of:
- `ACCEPT for runtime-facing candidate`
- `HOLD for one narrow touch-up`
- `REJECT and stop`

Do not start another open-ended ladder automatically.
