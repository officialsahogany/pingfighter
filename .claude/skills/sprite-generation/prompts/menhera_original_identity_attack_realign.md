# Menhera Original-Identity Attack Realign Prompt

Use this after `.tmp/menhera_original_identity_walk_v1.png` has passed QA and is
being treated as the provisional canonical walk anchor.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
attack sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This pass is aligned to the PROVISIONAL canonical walk anchor:
- .tmp/menhera_original_identity_walk_v1.png

Reference split:

1. Identity / body / scale master:
- .tmp/menhera_original_identity_walk_v1.png
- This is the character anchor for the attack sheet.
- Attack must look like the EXACT SAME Menhera as this walk candidate.

2. Quality / readability tier only:
- items/menhera_boss_victory.png
- Use ONLY for crispness, finish quality, and gameplay-scale readability.
- Do NOT copy the current victory sheet's old identity drift.

3. Broad motion-intent reference only:
- items/menhera_boss_attack.png
- Use ONLY for broad attack flow ideas.
- Do NOT preserve its older lower-quality / identity-drifted rendering.

Goal:
- Keep the exact ORIGINAL-identity Menhera restored by the new walk candidate
- Match or exceed the current victory sheet's quality tier
- Preserve strong attack readability without changing body class
- Same character, same body read, same quality tier

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

Attack sheet composition:
- 8-frame attack sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: ready, wind-up, backswing, max charge
- row2: swing start, impact, follow-through, recovery
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character remains front-readable in every frame
- Keep foot / baseline position coherent
- Head / torso / pelvis scale within +/-5% of the walk anchor
- Effects may extend outward, but body read must not shrink

Attack motion direction:
- Emotionally intense, unstable, and threatening
- Strong arm trajectory, weight shift, hair/ribbon/cloth follow-through
- Preserve frontal combat readability even at impact
- Do NOT solve force by turning into a different character or shrinking the body

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
- Reject if body read is smaller than the walk anchor
- Reject if the med-kit accessory disappears
- Reject if the four black bows disappear
- Reject if the sheet looks blurrier or softer than items/menhera_boss_victory.png
- Reject if impact readability comes from making the face unreadable

Output safety rule:
- Do NOT overwrite items/menhera_boss_attack.png yet
- First generate:
    .tmp/menhera_original_identity_attack_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_attack_v1.jpeg \
        .tmp/menhera_original_identity_attack_v1.png
- Candidate only. Not canonical until QA passes against the walk anchor.
```
