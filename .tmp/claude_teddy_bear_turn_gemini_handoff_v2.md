# Teddy Bear Turn -- Gemini Front-Facing Head-Sway Retake V2

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Objective

Run the one allowed fast-mode retake for the teddy turn sheet.

`v1` was close in identity and frontal read, but it failed on:
- printed black cell borders / dividers
- head sway amplitude too weak
- ear flap too subtle
- middle frames collapsing toward an idle gallery
- heart belly patch partly occluded by the safety pin

This `v2` retake must preserve the good parts and fix only those failures.

## Identity locks

Keep the exact same teddy identity in all 8 frames:
- LEFT red X button eye
- RIGHT empty socket + detached hanging button on white thread
- large pink gingham head bow on the head
- cream neck ribbon under the head
- heart belly patch fully visible
- upper chest safety pin only
- left paw black bow
- same cocoa plush body and same body scale

## Motion brief

This remains a **front-facing plush pivot accent**, not a body-angle chart.

Desired feel:
- quick head wag / side-to-side wobble
- visible head tilt at the two peak frames
- ears visibly lag, compress, and lift with the wag
- dangling eye swings slightly with momentum
- bow reacts softly
- face acting changes slightly through the sequence
- body stays mostly centered and front-facing

Not allowed:
- side-facing turn sheet
- 3/4 angle turn
- rotation chart
- literal walk loop reuse
- dead idle gallery

## Sequence target

Treat the 8 frames as:
- f1 neutral entry
- f2 sway starts to one side
- f3 clear one-side peak tilt
- f4 rebound through center
- f5 sway starts to the opposite side
- f6 clear opposite-side peak tilt
- f7 settle
- f8 neutral recovery

The key fix versus `v1`:
- `f3` and `f6` must have a clearly readable tilt from silhouette
- `f2`, `f4`, `f5`, `f7`, `f8` must not look like near-duplicates
- ears must visibly deform / lag, not only show wobble lines
- facial acting must not stay frozen across all 8 frames
- a tiny paw-near-face / eye-rub accent is allowed in one brief transition frame
  only if it stays subtle, front-facing, and does not hide the dangling-eye read

## Composition lock

The biggest hard reject from `v1` was printed borders.

You must explicitly reject any result that has:
- black rectangular cell outlines
- divider lines
- grid lines
- panel separators
- any printed border between frames

The background must be one unbroken flat white field inside and between cells.

## Output

Save:
- `.tmp/teddy_bear_turn_gemini_v2.jpeg` or `.png`
- `.tmp/teddy_bear_turn_gemini_v2_zoom.png`
- `.tmp/teddy_bear_turn_gemini_v2_report.md`

## QA gates

Report explicitly:

1. Is the teddy still front-facing in every frame?
2. Are there zero printed borders / divider lines / frame outlines?
3. Is the left-right head sway clearly readable now?
4. Do the ears visibly flap / lag at the two peak frames?
5. Are `f2`, `f4`, `f5`, `f7`, and `f8` clearly distinct from each other?
6. Does the dangling eye survive as socket + hanging button?
7. Does the heart belly patch remain fully visible in every frame?
8. Is there at least a small readable facial-acting change across the sequence?
9. Does the sheet read more like a brief turn gesture than an idle gallery?

## Decision

End with one of:
- `ACCEPT for runtime-facing candidate`
- `REJECT and stop`

Fast-mode rule:
- this is the one allowed retake after `v1`
- do not start a deeper ladder automatically
- if `v2` still fails, stop the turn branch and wait for user direction
