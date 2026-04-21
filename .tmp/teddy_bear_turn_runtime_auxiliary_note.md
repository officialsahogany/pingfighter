# Teddy Bear Turn Runtime Auxiliary Note

## Decision

Visible runtime turn playback is currently **disabled again** after local
review.

Reason:
- the turn sheet reads materially different from the accepted walk in
  fine details / identity class
- in-game it feels mismatched against the walk rather than like the same
  teddy doing a short transition accent

This sheet stays only as a rejected review artifact, not as an active
runtime candidate.

## Policy

- source: `.tmp/teddy_bear_turn_gemini_v3.png`
- layout: `4x2`, `8` frames
- active runtime role: NONE (disabled)
- non-anchor: YES
- canonical identity anchor: still the accepted walk sheet only

## Guardrail

Do NOT use this turn sheet as a regeneration anchor for future
attack / dash / victory / defeat work.

The accepted walk sheet remains the sole teddy identity anchor unless
explicitly reclassified later.

## Runtime policy now

Use walk / hop-only direction changes for teddy until a future turn sheet
lands with the same detail class and identity read as the accepted walk.
