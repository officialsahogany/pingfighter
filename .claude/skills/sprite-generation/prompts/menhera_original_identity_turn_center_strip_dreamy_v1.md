# Menhera Original-Identity Turn Center Strip Dreamy V1

Use this when full-sheet turn generation collapsed mid-angles and the
fallback ladder has moved to strip generation. This file covers the CENTER strip
only.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
CENTER turn strip for real-stage 3 boss Menheragirl (code current_stage == 3).

This is TURN STRIP FALLBACK, CENTER ONLY.
This is an AUXILIARY facing-transition asset, not a walk replacement.

Reference split:

1. Identity / body / scale / mood master:
- items/menhera_boss_sheet.png
- This is the CURRENT canonical walk anchor.
- The result must look like the EXACT SAME Menhera as this walk sheet.
- Keep the same playful / slightly dreamy walk-connected mood.

2. Quality / readability tier only:
- items/menhera_boss_victory.png

3. Broad turn-intent reference only:
- items/menhera_boss_turn.png
- Use ONLY for broad idea of turn coverage if useful.
- Do NOT preserve older mismatch or fake-front collapse.

4. Negative full-sheet reference:
- .tmp/menhera_original_identity_turn_dreamy_lifted_gaze_v2.png
- This FAILED because close-to-front mid-angles collapsed into fake frontal copies.
- Do NOT reproduce that failure.

Goal:
- Keep the exact canonical Menhera identity from the current walk anchor
- Match or exceed the current victory sheet's quality tier
- Produce a clean CENTER strip with subtle but real angle separation
- Keep a slightly lifted head and middle-distance dreamy gaze
- Feel naturally connected to the playful current walk

Exact identity lock (must match the canonical walk exactly):
- Fluffy curly short pink + cream hair mass
- Rounded fluffy hair silhouette matching the walk anchor
- Pink remains visibly strong in the hair, not just a thin outer rim
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Exactly ONE heart cheek mark on one cheek only
- Pink outfit with white front panel
- Four black front bows
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross + bunny-ear motif
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

CENTER strip layout:
- EXACTLY 3 frames in a single horizontal strip
- Frame order left-to-right: +15, 0, -15
- aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF)
- NO grid lines, NO borders, NO dividers, NO labels
- Body scale within +/-5% of the walk anchor

Angle behavior:
- These are subtle near-frontal angles, but they must still be truly different
- +15 must read as gently turned right, not just frontal with eyes nudged
- 0 must be the clean frontal anchor
- -15 must read as gently turned left, not just frontal with eyes nudged
- Keep them soft, gentle, and close to front, but still distinct
- Do NOT return three near-identical fake-front copies

Head / gaze direction:
- Keep the head slightly lifted
- The gaze should feel like she is looking a little farther / middle-distance
- This should read as mildly dreamy / aloof / detached
- Do NOT over-tilt upward
- Do NOT make the gaze sharp or hostile

Walk-connection tone:
- This strip is the most important for feeling connected to the current walk
- Keep a subtle connection to the walk's playful energy
- Mild ribbon motion, mild hem / cloth follow-through, mild paw / arm rhythm
- 0 should feel like a natural bridge back into the current playful frontal walk

Gameplay-scale readability is mandatory:
- Eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves, bows,
  med-kit accessory, legwear, and cloth/tail motif must stay readable at
  in-game size
- Keep clean separation between hair, face, arms, outfit, accessory, and legs

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
- Reject if the result looks like a different Menhera from the current walk anchor
- Reject if +15 and -15 are effectively fake frontal copies of 0
- Reject if the sheet loses the dreamy lifted-head connection to the walk
- Reject if hair becomes cream/blonde-dominant or loses rounded fluffy mass
- Reject if bow count drops below the canonical read
- Reject if med-kit or cloth-tail readability disappears
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if body scale drifts or face scale pops across the strip

Output safety rule:
- Do NOT overwrite any items/ files yet
- First generate:
    .tmp/menhera_original_identity_turn_center_strip_dreamy_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_turn_center_strip_dreamy_v1.jpeg \
        .tmp/menhera_original_identity_turn_center_strip_dreamy_v1.png
- Candidate only. Not canonical until QA passes against the walk anchor.
```
