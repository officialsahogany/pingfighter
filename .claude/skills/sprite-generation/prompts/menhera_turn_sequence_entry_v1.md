# Menhera Turn Sequence Entry V1 Prompt

Use this after `peak_keypose_v3` has been accepted as the best single-frame
reference for Menhera's turn gesture, and we want to generate ONLY the entry
arc that leads into that exact peak pose.

This is an ENTRY-ONLY multi-frame strip, not the full turn sheet.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate the
ENTRY strip only for real-stage 3 boss Menheragirl (code current_stage == 3).

This is MENHERA TURN SEQUENCE ENTRY V1.

Important:
- Generate ONLY the entry arc, not the full 8-frame sheet.
- Generate EXACTLY 4 frames in a single horizontal strip.
- This is NOT a side-view rotation chart.
- This is NOT a profile-angle turn sheet.
- This strip must lead INTO the accepted peak pose.

Current plan:
- We are using `.tmp/menhera_turn_peak_keypose_v3.png` as the accepted peak
  transition reference.
- Frame 4 of this strip must replicate that peak pose as closely as possible.
- Frames 1-3 must show the clean lead-in / wind-up into that exact pose.
- Later, a separate recovery strip will handle frames 5-8.

Reference split:

1. Identity / scale / frontal-read master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- All 4 frames must look like the EXACT SAME Menhera as this walk sheet.

2. Peak-pose master (highest frame-specific reference):
- .tmp/menhera_turn_peak_keypose_v3.png
- Frame 4 must match this image as closely as possible.
- Keep the same heart cheek mark, bow stack, med-kit side, bunny-ear hint,
  eye color, paw sweep, knee lift, and overall silhouette read.

3. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.

Primary brief:
- Build the ENTRY HALF of Menhera's short front-facing direction-change gesture.
- The strip must feel like:
  walk-compatible carry-in -> plant/compress -> lifted-chin wind-up -> exact peak pose
- All motion must stay connected to the accepted frontal walk language.
- The strip must feel compact, dreamy, quirky, and character-specific.
- The strip must NOT read like random acting or a camera-angle showcase.

Exact identity lock (all 4 frames must match the walk anchor exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy cloud-like hair silhouette
- PINK dominant outer hair mass, CREAM front bangs / forelock
- Pink / white check nurse cap
- Dome-tall puffy cap silhouette
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- HEART CHEEK MARK REQUIRED on the LEFT cheek (viewer’s right)
- Pink outfit with white front panel
- EXACTLY 4 black bows in a vertical centerline stack
- Gray cat-paw gloves with pink toe beans
- Med-kit with pink cross + bunny-ear motif in the SAME placement as the walk anchor
- Pink check-pattern cloth / square-tail motif visible
- White sheer thigh-highs
- Black X ankle marks
- Chibi petite-human proportions
- Thick black pixel outlines

Frame-specific motion plan:
- Frame 1:
  - walk-compatible carry-in
  - still close to neutral frontal walk language
  - slight readiness / subtle asymmetry begins
- Frame 2:
  - visible plant / compress
  - weight shift starts
  - body bob and soft torso preparation become readable
- Frame 3:
  - lifted-chin wind-up
  - dreamy upward gaze begins clearly
  - paw starts preparing the outward sweep
  - knee begins lifting
- Frame 4:
  - MUST match `.tmp/menhera_turn_peak_keypose_v3.png` as closely as possible
  - this is the accepted peak transition pose

Peak-pose continuity rule:
- Frame 4 is NOT "inspired by" the peak reference.
- Frame 4 should be treated as an attempt to recreate that accepted key pose
  inside the strip with minimal drift.
- If frame 4 loses the heart cheek mark, bow stack, med-kit, eye color, or
  knee-lift / paw-sweep read, the strip has failed.

Gaze and expression rule:
- The dreamy upward gaze should strengthen across frames 2 -> 3 -> 4.
- Pupils should rise progressively toward the peak pose.
- Do NOT keep all three frames on a flat straight-at-camera stare.
- Do NOT become sad / droopy.

Body-language rule:
- The torso must visibly participate.
- Weight shift, slight body bob, and soft preparatory rebound should build
  from frame 1 to frame 4.
- Do NOT make the strip feel like only the arm changes while the body freezes.

Gesture rule:
- The left paw outward sweep should build gradually into frame 4.
- Do NOT let it become a greeting wave or palm-up hello.
- One-knee lift should become readable by frame 3 and clear in frame 4.

Composition:
- EXACTLY 4 frames in a single horizontal strip
- Left-to-right order: frame 1, frame 2, frame 3, frame 4
- Pure flat white background (#FFFFFF)
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered in every frame
- Full body visible in every frame
- Body scale must stay within +/-5% of the walking sheet

Gameplay-scale readability is mandatory:
- Eyes, lashes, heart cheek mark, cap silhouette, ribbon, syringe, gloves,
  bows, med-kit accessory, bunny-ear hint, cloth-tail motif, ankle X marks,
  and legwear must stay readable
- Preserve clean separation between hair, face, arms, outfit, accessory, and legs
- The face must NOT read clipped, forehead-cut, or vertically squashed

Style rules:
- 16-bit retro pixel art
- Chibi proportions
- Thick black pixel outlines
- Flat limited-saturation palette
- Clean hard-edged pixels
- NO painterly rendering
- NO soft shading
- NO photorealism

Hard reject conditions:
- Reject if the strip looks like a different Menhera from the current walk anchor
- Reject if frame 4 drifts meaningfully from `.tmp/menhera_turn_peak_keypose_v3.png`
- Reject if the heart cheek mark disappears in any frame where the cheek is visible
- Reject if the 4-bow center stack collapses
- Reject if the med-kit side changes or disappears
- Reject if the dreamy upward gaze does not clearly build into frame 4
- Reject if frames 1-3 do not feel like a true lead-in to the peak pose
- Reject if the strip reads like a side-profile rotation attempt
- Reject if torso/body rhythm freezes

Output safety rule:
- Do NOT overwrite any runtime asset
- First generate:
    .tmp/menhera_turn_sequence_entry_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_turn_sequence_entry_v1.jpeg \
        .tmp/menhera_turn_sequence_entry_v1.png

- Candidate only. Not canonical until QA passes against the walk anchor and peak reference.
```
