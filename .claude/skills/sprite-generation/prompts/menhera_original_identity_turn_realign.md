# Menhera Original-Identity Turn Realign Prompt

Use this after `.tmp/menhera_original_identity_walk_v1.png` has passed QA and is
being treated as the provisional canonical walk anchor.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
turn sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is an AUXILIARY turn-support pass.
Turn is NOT a replacement for the main walk cycle.

This pass is aligned to the PROVISIONAL canonical walk anchor:
- .tmp/menhera_original_identity_walk_v1.png

Reference split:

1. Identity / body / scale master:
- .tmp/menhera_original_identity_walk_v1.png

2. Quality / readability tier only:
- items/menhera_boss_victory.png

3. Broad turn-intent reference only:
- items/menhera_boss_turn.png
- Use ONLY for broad coverage intent if useful.
- Do NOT preserve its older mismatched identity.

Goal:
- Keep the exact ORIGINAL-identity Menhera restored by the new walk candidate
- Match or exceed the current victory sheet's quality tier
- Provide brief facing-transition support only
- Keep the same character read across angles

Exact identity lock (must match the walk anchor exactly):
- Fluffy curly short pink + cream hair mass
- Pink / white check nurse cap
- Red ribbon on the cap
- Syringe attached to / inserted into the cap
- NO black cat ears
- Large gray / silver eyes with strong lashes
- Heart cheek mark
- Pink outfit with white front panel
- Four black front bows
- Gray cat-paw gloves with pink toe beans
- Right-side med-kit accessory with pink cross + bunny-ear motif
- Pink check-pattern cloth / square-tail motif
- White sheer thigh-highs
- Black X ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Preferred layout:
- 13-frame turn sheet, 7x2 grid, last cell blank, aspectRatio 16:9, imageSize 2K
- row1: +90, +75, +60, +45, +30, +15, 0
- row2: -15, -30, -45, -60, -75, -90, blank
- Pure flat white background (#FFFFFF)
- NO grid lines, NO borders, NO dividers, NO labels
- Body scale within +/-5% of the walk anchor

Turn direction:
- This is for brief left/right facing transitions only
- Keep the same crisp identity and body read as the walk anchor
- Smooth 15-degree interpolation between neighboring frames
- Each angle must be a fresh redraw, not a filtered rotation
- Preserve face-scale and hair/cap/accessory consistency across the sheet

Fallback rule:
- If the model collapses the 3/4 angles, use the skill's strip fallback ladder
  rather than brute-forcing the same failed full sheet repeatedly
- A documented usable subset is acceptable only if the full set repeatedly fails

Gameplay-scale readability is mandatory:
- Eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves, bows,
  med-kit accessory, legwear, and cloth/tail motif must stay readable at
  in-game size when the angle allows it
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
- Reject if the result looks like the older bob-hair / cat-ear / olive-eye Menhera
- Reject if the turn sheet reads like a different character from the walk anchor
- Reject if mid-angles collapse into fake frontal copies
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if body scale drifts or face scale pops between adjacent angles

Output safety rule:
- Do NOT overwrite items/menhera_boss_turn.png yet
- First generate:
    .tmp/menhera_original_identity_turn_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_turn_v1.jpeg \
        .tmp/menhera_original_identity_turn_v1.png
- Candidate only. Not canonical until QA passes against the walk anchor.
```
