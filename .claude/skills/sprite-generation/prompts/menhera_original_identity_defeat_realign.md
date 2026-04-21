# Menhera Original-Identity Defeat Realign Prompt

Use this after `.tmp/menhera_original_identity_walk_v1.png` has passed QA and is
being treated as the provisional canonical walk anchor.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
defeat sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This pass is aligned to the PROVISIONAL canonical walk anchor:
- .tmp/menhera_original_identity_walk_v1.png

Reference split:

1. Identity / body / scale master:
- .tmp/menhera_original_identity_walk_v1.png

2. Quality / readability tier only:
- items/menhera_boss_victory.png

Goal:
- Keep the exact ORIGINAL-identity Menhera restored by the walk anchor
- Match or exceed the current victory sheet's quality tier
- Deliver a readable non-graphic defeat / collapse sequence

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

Defeat sheet composition:
- 8-frame defeat sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: stagger, stronger stagger, knees weakening, drop
- row2: collapse landing, defeated slump, final hold, tiny settle
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character stays front-readable in every frame
- Keep the body anchored to one coherent ground plane
- Head / torso / pelvis scale within +/-5% of the walk anchor
- Do NOT shrink the body to sell defeat

Defeat motion direction:
- Clear progression from balance loss -> collapse -> defeated hold
- Emotion: shocked / pained / dazed / drained
- Use slump, shoulder drop, cloth/hair/accessory settling, not side-profile cheats

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
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if defeat readability comes from turning into a side-profile-dominant pose

Output safety rule:
- Do NOT overwrite items/menhera_boss_defeat.png yet
- First generate:
    .tmp/menhera_original_identity_defeat_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_defeat_v1.jpeg \
        .tmp/menhera_original_identity_defeat_v1.png
- Candidate only. Not canonical until QA passes against the walk anchor.
```
