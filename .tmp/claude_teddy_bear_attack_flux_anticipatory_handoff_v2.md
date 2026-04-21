# Teddy Bear Attack V2 -- Tight Scoped Retry

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

This is the ONE allowed scoped retry for teddy attack after `teddy_bear_attack_v1`
failed.

If this retry still misses layout, style class, or dangling-eye identity,
STOP the branch. Do not start a long retry ladder.

## Why V1 failed

V1 failed on:
- wrong layout (`6 frames / 3x2` instead of `8 / 4x2`)
- style class drift to painterly / illustrated
- dangling-eye collapse
- eye-side swaps
- safety pin drift
- partial 3/4 framing

## Retry goal

Generate a front-facing 8-frame plush teddy attack sheet that supports
short anticipatory runtime triggering and keeps the exact walk identity.

## References

Primary:
- `d:\main\bosspong\.tmp\teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`

Secondary:
- `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`

Do NOT use:
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`
- rejected attack V1 outputs
- any rejected teddy walk sheets

## Tool route

Prefer `FLUX Kontext max`.

Recommended stack:
- `input_image` = current accepted walk candidate
- `input_image_2` = redesign anchor
- omit extra references unless truly necessary

The goal is to reduce style drift, not add more competing signals.

## Non-negotiable constraints

### Layout
- exactly 8 frames
- exactly 4 columns x 2 rows
- no other layout is acceptable

### Style
- exact pixel-art class of the walk candidate
- same outline weight
- same color quantization
- same hard-edged pixels
- reject any painterly or illustrated rendering immediately

### Identity
- LEFT eye = red X button
- RIGHT eye = empty socket + hanging detached button on white thread
- big pink gingham head bow stays on head
- cream neck ribbon stays under head
- safety pin stays on upper chest
- heart patch keeps same family as walk
- left paw black bow remains

### Frontal read
- every frame front-facing
- zero 3/4
- zero side turn

## Timing and acting

This sheet is for SHORT conservative anticipatory runtime use.

Target sequence:
- f1 ready
- f2 gather
- f3 compact coil
- f4 max charge
- f5 launch
- f6 strongest impact frame
- f7 short follow-through
- f8 recovery

The early prep must be readable but compact.
Do NOT make a long cinematic wind-up.

## Output files

Save:
- `.tmp/teddy_bear_attack_v2.jpeg`
- `.tmp/teddy_bear_attack_v2.png` if available
- `.tmp/teddy_bear_attack_v2_zoom.png`
- `.tmp/teddy_bear_attack_v2_report.md`

## QA gates

Report explicitly:

1. Is the sheet exactly `8 frames / 4x2`?
2. Did the pixel-art class stay matched to walk?
3. Did the RIGHT dangling eye keep the detached-button-on-thread structure?
4. Did any frame drift to 3/4?
5. Is frame 6 clearly the strongest impact frame?
6. Are early frames meaningful prep rather than idle posing?

## Decision policy

Allowed outcomes:
- `ACCEPT for runtime-facing candidate`
- `REJECT and STOP`

Do NOT recommend another retry after this one.
