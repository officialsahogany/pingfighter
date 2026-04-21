# Menhera Original-Identity Walk Recovery Prompt

Use this when the user-provided original Menhera reference image must become
the identity master, while the current victory sheet remains only a quality /
readability reference.

This prompt is for the NEXT walk candidate only. Do not regenerate the whole
set in one batch yet.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

This is an ORIGINAL-IDENTITY WALK RECOVERY pass.

Critical reference split:

1. Identity master:
- Use the user-provided ORIGINAL Menhera reference image already shown earlier
  in this chat as the identity master.
- If that original image is not actually available in chat context anymore,
  STOP and ask the user to resend it instead of guessing.

2. Quality / readability master only:
- items/menhera_boss_victory.png
- Use this ONLY for:
  - crispness / finish quality
  - gameplay-scale readability
  - clean pixel rendering confidence
  - clear face / trim / silhouette separation
- Do NOT use the victory sheet as the identity master.

3. Motion-intent reference only:
- items/menhera_boss_sheet.png
- Use this ONLY for broad front-biased walk intent and Stage 3 body class.
- Do NOT preserve its current identity drift if it conflicts with the original reference image.

Current problem:
- The current in-game Menhera identity drifted far away from the original
  reference image.
- The victory sheet is sharper and cleaner, but it is also identity-drifted.
- We need a NEW walk candidate that restores the ORIGINAL Menhera identity
  while matching the victory sheet's render quality tier.

Primary objective:
- Restore the ORIGINAL Menhera identity from the user-provided original image
- Keep the walk front-biased and gameplay-readable
- Match the current victory sheet's quality / sharpness tier
- Do NOT preserve the wrong bob-hair / cat-ear / olive-eye / striped-stocking version

Original identity lock (must follow the original image, not the current victory sheet):
- Fluffy, curly, short pink hair with soft white/cream mixed into the hair mass
- Pink / white check-pattern nurse cap
- Red ribbon attached to the cap
- Syringe visibly inserted into / attached to the cap
- NO black cat ears
- Large gray / silver eyes
- Stronger visible eyelashes than the current in-game version
- Heart cheek mark / heart blush motif on the cheek
- Pink nurse outfit with a white front panel
- Four black bow / butterfly-style front buttons
- Gray cat-paw gloves with pink toe beans
- Visible right-side emergency-kit accessory with a pink cross and bunny-ear motif
- Pink check-pattern cloth / square-tail motif instead of the current thin black cat tail
- White sheer thigh-highs
- Black X-shaped ankle accessories
- Chibi petite-human proportions
- Thick black pixel outlines

Explicitly reject these current-drift traits:
- Smooth bob hairstyle
- Solid white cap with only a pink cross
- Black cat ears
- Olive / green eyes
- Plain round blush instead of the heart cheek mark
- Simple black-trim dress without the four black front bows
- Black cat-paw gloves
- Missing med-kit / bunny-ear right-side accessory
- Thin black cat tail
- Pink striped stockings

Walk-specific direction:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character centered in every frame
- Keep foot / baseline position consistent
- Character remains front-facing in every frame
- Stable movement must read as "facing the player while moving laterally"
- This is a front-biased walk, NOT a hidden 3/4 walk

Head / gaze direction:
- During normal left/right movement, the head should feel slightly lifted
- The gaze should feel like she is looking a little farther into the middle distance
- This should read as mildly aloof / detached / dreamy
- Do NOT over-tilt upward
- Do NOT create left-looking or right-looking bias
- Do NOT turn the face into 3/4 just to get that effect

Motion direction:
- Normal lateral travel should feel composed, not bouncy
- Put motion energy mainly into leg alternation, hem movement, hair follow-through,
  ribbon movement, accessory motion, and cloth/tail follow-through
- Do NOT rely on exaggerated full-body bob as the main energy source
- Keep the walk cute and alive without losing frontal readability

Gameplay-scale readability is mandatory:
- Face, eyes, lashes, cheek heart mark, cap silhouette, red ribbon, syringe,
  gloves, front bows, med-kit accessory, legwear, and cloth/tail motif must
  remain readable at small in-game size
- Preserve clean separation between hair, face, arms, gloves, dress, accessory,
  and legwear
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
- Reject if the result still looks like the current in-game / victory identity
  instead of the original image
- Reject if black cat ears remain
- Reject if the hair is still a smooth bob instead of fluffy curly short hair
- Reject if the eyes are still olive / green instead of gray / silver
- Reject if the heart cheek mark is missing
- Reject if the four black front bows are missing
- Reject if the gray cat-paw gloves + pink toe beans are missing
- Reject if the med-kit / bunny-ear accessory is missing
- Reject if the pink check-pattern cloth/tail motif is missing
- Reject if stable movement becomes side-biased
- Reject if moving right feels like she is looking left
- Reject if moving left feels like she is looking right
- Reject if the sheet is lower-quality or blurrier than the victory sheet

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- First generate:
    .tmp/menhera_original_identity_walk_v1.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        .tmp/menhera_original_identity_walk_v1.jpeg \
        .tmp/menhera_original_identity_walk_v1.png

Stop after this walk candidate.
Do NOT regenerate victory / attack / dash / turn yet.
Those will be regenerated only after this NEW walk passes identity QA against
the original image and quality QA against the current victory sheet.
```
