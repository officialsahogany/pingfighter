# Teddy Bear Turn -- FLUX Walk-Locked Micro-Turn V4

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Why this route

The previous Gemini turn attempts proved two things:
- Gemini can invent plausible turn acting
- but it drifts away from the accepted walk detail class in runtime

That makes this a better fit for **FLUX as a correction / adaptation tool**
rather than Gemini as a fresh full-sheet inventor.

We are no longer asking for "a new turn idea."
We are asking for:
- the same exact teddy from the accepted walk
- with only a tiny front-facing turn accent layered on top

## Identity master

Primary reference / absolute anchor:
- `.tmp/teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`

Optional secondary support if useful:
- `.tmp/teddy_bear_attack_gemini_v2.png`

But the walk sheet is the stronger truth.

## Target

Generate:
- `.tmp/teddy_bear_turn_flux_v4.jpeg` or `.png`
- 8 frames
- 4x2 grid
- front-facing only
- brief micro-turn / hesitation accent

## Requirements

Keep EXACT identity:
- viewer-left eye = red X button
- viewer-right eye = empty socket + dangling button on white thread
- same head bow on the head
- same cream neck ribbon
- same safety pin upper chest
- same heart belly patch
- same black bow on left paw
- same detail class as walk

Motion target:
- tiny head tilt
- soft ear lag
- subtle body rebound
- very modest, natural turn accent

This is not the place to be expressive.
If motion energy and identity fidelity conflict, preserve identity fidelity.

## Hard reject

Reject immediately if:
- the sheet looks materially different from the accepted walk in detail class
- eye sides swap or face mirrors
- the bow / ribbon / safety pin / heart / paw bow drift
- side-facing or 3/4 frames appear
- panel borders / dividers appear

## Decision rule

End with one of:
- `ACCEPT for runtime-facing candidate`
- `REJECT and stop`

If the result still does not match the walk detail class, stop and keep
turn disabled. Do not start a long ladder automatically.
