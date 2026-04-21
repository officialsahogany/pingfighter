# Menhera Original-Identity Dash Realign Prompt

Use this after `.tmp/menhera_original_identity_walk_v1.png` has passed QA and is
being treated as the provisional canonical walk anchor.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
dash sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This pass is aligned to the PROVISIONAL canonical walk anchor:
- .tmp/menhera_original_identity_walk_v1.png

Reference split:

1. Identity / body / scale master:
- .tmp/menhera_original_identity_walk_v1.png

2. Quality / readability tier only:
- items/menhera_boss_victory.png

3. Broad dash-intent reference only:
- items/menhera_boss_dash.png

Goal:
- Keep the exact ORIGINAL-identity Menhera restored by the new walk candidate
- Match or exceed the current victory sheet's quality tier
- Preserve speed and instability without shrinking the body or losing readability

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

Dash sheet composition:
- 8-frame dash sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: crouch prep, push-off, low burst, full extension
- row2: sustained dash, deceleration, recovery rise, standing return
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character stays front-readable even in fast frames
- Keep foot / baseline logic coherent where possible
- Head / torso / pelvis scale within +/-5% of the walk anchor
- Trails / motion accents may extend outward but must not visually compress the body

Dash motion direction:
- Quick, unstable, low-profile burst
- Speed through pose, drag, cloth/hair/accessory follow-through, not body resize
- Preserve readable face and identity even at fastest moment

Gameplay-scale readability is mandatory:
- Eyes, lashes, cheek heart, cap silhouette, ribbon, syringe, gloves, bows,
  med-kit accessory, legwear, and cloth/tail motif must stay readable at
  in-game size
- Keep clean separation between hair, face, arms, outfit, accessory, and legs
- Reduce muddy midtones

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
- Reject if the body reads smaller than the walk anchor because of speed trails
- Reject if the face collapses into muddy blur
- Reject if the med-kit accessory, four black bows, or cloth/tail motif disappear
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png

Output safety rule:
- Do NOT overwrite items/menhera_boss_dash.png yet
- First generate:
    .tmp/menhera_original_identity_dash_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_dash_v1.jpeg \
        .tmp/menhera_original_identity_dash_v1.png
- Candidate only. Not canonical until QA passes against the walk anchor.
```
