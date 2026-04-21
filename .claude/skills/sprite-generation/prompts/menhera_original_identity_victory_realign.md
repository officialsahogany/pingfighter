# Menhera Original-Identity Victory Realign Prompt

Use this after `.tmp/menhera_original_identity_walk_v1.png` has passed QA and is
being treated as the provisional canonical walk anchor.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
victory sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This pass is aligned to the PROVISIONAL canonical walk anchor:
- .tmp/menhera_original_identity_walk_v1.png

Reference split:

1. Identity / body / scale master:
- .tmp/menhera_original_identity_walk_v1.png

2. Quality / finish / celebration-beat reference only:
- items/menhera_boss_victory.png
- Use ONLY for quality tier, clarity, and broad celebration pacing.
- Do NOT copy its old identity drift.

Goal:
- Rebuild victory so it finally matches the restored ORIGINAL Menhera identity
- Keep or exceed the current victory sheet's quality tier
- Preserve a readable boss-win / round-win celebration

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

Victory sheet composition:
- 8-frame victory sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: notice the win, brighten expression, gather pride, pose setup
- row2: full triumph, held pose, softer satisfied hold, final hold
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character front-readable in every frame
- Keep foot / baseline position consistent
- Head / torso / pelvis scale within +/-5% of the walk anchor
- Avoid oversized celebratory FX that make the body feel smaller

Victory motion direction:
- Emotionally triumphant, smug, pleased, or quietly delighted
- Use head lift, shoulder opening, glove gesture, ribbon/hair/cloth motion,
  and accessory motion
- Keep the pose clean and front-readable at gameplay scale

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
- Reject if the med-kit accessory, four black bows, or cloth/tail motif disappear
- Reject if the sheet looks blurrier or softer than the current items/menhera_boss_victory.png
- Reject if the body reads smaller because of celebratory FX

Output safety rule:
- Do NOT overwrite items/menhera_boss_victory.png yet
- First generate:
    .tmp/menhera_original_identity_victory_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_victory_v1.jpeg \
        .tmp/menhera_original_identity_victory_v1.png
- Candidate only. Not canonical until QA passes against the walk anchor.
```
