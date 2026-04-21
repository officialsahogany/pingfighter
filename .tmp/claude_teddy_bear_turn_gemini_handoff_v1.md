# Teddy Bear Turn -- Gemini Front-Facing Head-Sway Pass

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Objective

Generate the first teddy bear turn / facing-transition sheet candidate.

This turn must follow the repo turn rules exactly:
- do NOT build a profile-angle chart
- do NOT replace normal walking
- keep the teddy front-facing
- express the direction change through a short characterful accent

## Character direction

The user wants:
- head swaying left-right during turn
- ears flapping / bouncing with that motion

That is the correct design direction for this boss.

## Identity locks

Keep the exact same teddy identity:
- LEFT red X button eye
- RIGHT empty socket + detached hanging button on white thread
- large pink gingham head bow on head
- cream neck ribbon
- heart belly patch
- upper chest safety pin
- left paw black bow
- same cocoa plush body and same body scale

## Motion brief

This is a **front-facing plush pivot accent**.

Desired feel:
- quick head wag / side-to-side wobble
- ears lag and flap slightly
- dangling eye swings a little with momentum
- bow reacts softly
- body remains mostly centered and front-facing

Not allowed:
- side-facing turn sheet
- 3/4 angle turn
- rotation chart
- literal walk loop reuse
- dead idle gallery

## Sequence target

Treat the 8 frames as:
- f1 neutral entry
- f2 sway starts
- f3 one-side peak
- f4 rebound through center
- f5 opposite sway
- f6 opposite peak
- f7 settle
- f8 neutral recovery

## Route

Use **Gemini full-sheet fast route** first.

Why:
- fresh full-sheet invention has worked better than FLUX for teddy sequence creation
- this is a new auxiliary motion concept, not a surgical FLUX touch-up

## Output

Save:
- `.tmp/teddy_bear_turn_gemini_v1.jpeg` or `.png`
- `.tmp/teddy_bear_turn_gemini_v1_zoom.png`
- `.tmp/teddy_bear_turn_gemini_v1_report.md`

## QA gates

Report explicitly:

1. Is the teddy still front-facing in every frame?
2. Does the turn avoid becoming a side-profile chart?
3. Is there a readable left-right head sway?
4. Do the ears actually flap / bounce with the sway?
5. Does the dangling eye survive as socket + hanging button?
6. Does the sequence read more like a brief turn gesture than a walk loop?

## Decision

End with one of:
- `ACCEPT for runtime-facing candidate`
- `HOLD for one Gemini retake`
- `REJECT and stop`

Fast-mode rule:
- one strong first candidate
- if close-but-not-there, at most one retake
- do not start a deep ladder automatically
