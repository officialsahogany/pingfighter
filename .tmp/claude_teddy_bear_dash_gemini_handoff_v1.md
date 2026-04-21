# Teddy Bear Dash -- Gemini Full-Sheet V1

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Objective

Generate the first teddy bear dash sheet candidate.

This should follow the repo dash rules:
- front-facing combat read preserved
- body scale consistent with walk
- speed expressed through pose / drag / rebound rather than body shrink

## Character and reference truth

Current teddy identity truth:
- accepted walk candidate in runtime:
  `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`
- accepted attack candidate:
  `.tmp/teddy_bear_attack_gemini_v2.png`

Use those as the mental identity target for QA, even if Gemini
`generate-image` is text-only for the actual first pass.

## Motion brief

This dash is a **front-facing plush burst-slide**.

Desired feel:
- quick crouch prep
- explosive low burst
- short glide
- soft plush rebound back up

Not allowed:
- side-profile run
- 3/4 dash
- human sprint
- teleport blink
- repeated walk loop

## Sequence target

Use 8 frames:
- f1 ready
- f2 crouch prep
- f3 push-off
- f4 strongest burst-extension
- f5 sustained glide / speed peak
- f6 deceleration rebound
- f7 rise
- f8 neutral recovery

## Identity locks

Keep the exact same teddy:
- viewer-left eye = red X button
- viewer-right eye = empty socket + dangling button on white thread
- pink gingham head bow stays on the head
- cream neck ribbon stays readable
- heart patch stays centered and visible
- safety pin stays on upper chest
- black bow stays on the left paw
- same cocoa plush body and same body scale

## Output

Save:
- `.tmp/teddy_bear_dash_gemini_v1.jpeg` or `.png`
- `.tmp/teddy_bear_dash_gemini_v1_zoom.png`
- `.tmp/teddy_bear_dash_gemini_v1_report.md`

## QA gates

Report explicitly:

1. Is the teddy still front-facing in every frame?
2. Does the dash avoid side-profile / 3/4 run behavior?
3. Is there a readable burst-slide arc across the 8 frames?
4. Are f4/f5 clearly the fastest / strongest speed-read frames?
5. Does the dangling eye survive as socket + hanging button + thread?
6. Do bow / ribbon / heart / safety pin / paw bow all stay readable?
7. Does the body scale still match the walk class?
8. Does the sheet read like a dash rather than a walk loop?

## Decision

End with one of:
- `ACCEPT for runtime-facing candidate`
- `HOLD for one Gemini retake`
- `REJECT and stop`

Fast-mode rule:
- one strong first candidate
- if close-but-not-there, at most one retake
- do not start a deep ladder automatically
