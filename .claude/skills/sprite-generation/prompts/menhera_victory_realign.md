# Menhera Victory Realign Prompt

Use this after the canonical walk sheet has been regenerated and accepted.
The goal is to redraw the victory sheet so it matches the new walk sheet's
identity, scale, and gameplay-scale readability.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
victory sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3),
aligned to the NEW accepted canonical walk sheet at items/menhera_boss_sheet.png.

Goal:
- Keep the SAME Stage 3 Menhera Girl character as the new canonical walk sheet
- Preserve the current victory-sheet intent if items/menhera_boss_victory.png
  already exists, but redraw it so the result matches the NEW canonical walk
  identity, body-scale reference, and readability level
- Emotional boss-win / round-win celebration: smug, pleased, relieved, or quietly triumphant
- Prioritize face readability, character continuity, and stable body read over oversized effects

Fixed design elements (must match the NEW walk sheet exactly):
- Very pale pastel pink bob haircut
- Pink nurse cap with pink cross
- Pink ribbon on the character's right side
- Black cat ears
- Olive eyes
- Black cat-paw gloves
- Thin cat tail
- Pink nurse dress with black trim
- Small black shoes
- Chibi 2-head proportions
- Thick black pixel outline
- Head / torso / pelvis scale identical to the NEW walking sheet

Canonical reference:
- Use items/menhera_boss_sheet.png as the canonical visual reference
- This character MUST look like the EXACT SAME person as in the NEW walk sheet
- Do NOT redesign, reinterpret, or modernize the character
- Keep the SAME hair color, hairstyle, face shape, eye color, skin tone,
  outfit design, and all signature accessories
- Match the NEW walk sheet's improved readability level:
  clearer bangs-to-face separation, clearer eyelid / iris boundary, clearer
  glove / arm / torso separation, and more readable black trim
- If the result looks like a different character or an older softer version,
  reject and regenerate

Sheet composition:
- 8-frame victory sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: notice the win, brighten expression, small lift / gather, proud pose setup
- row2: full victory pose, held triumph, softer satisfied hold, final hold
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Character body scale must match the NEW walking sheet (+/-5%)
- The character's HEAD, TORSO, and PELVIS must be the SAME SIZE as the NEW walking sheet
- Keep the VISIBLE BODY READ the same as on the NEW walking sheet
- Avoid oversized magic, giant props, or celebratory FX that visually compress the body
- Leave generous empty margin around each sprite

Victory motion:
- Clear emotional progression from recognition -> pride -> held triumph
- Use head lift, shoulder opening, hand / glove gesture, ribbon / hair bounce,
  tail motion, and dress settling
- Keep the pose front-readable and clean at gameplay size

Silhouette continuity:
- The head, hair, shoulders, and upper torso must read as one closed continuous shape
- Do NOT leave any transparent gap between side hair and shoulders / upper torso
- If needed, include a rear hair layer behind the shoulders so the silhouette connects cleanly

Gameplay-scale readability is mandatory from the first generation:
- The face, eyes, bangs, mouth, gloves, arms, trim, and silhouette must remain readable at small in-game size
- Preserve clear separation between hair, face, arms, dress, gloves, and tail
- Reduce muddy midtones; keep clean light / mid / dark separation
- Preserve pastel softness; do NOT solve readability with harsh saturation,
  edgy anime contrast, painterly rendering, or realism

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines,
  flat limited-saturation palette, clean hard-edged pixels,
  NO painterly rendering, NO soft shading, NO photorealism

Output:
- First generate items/menhera_boss_victory.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/menhera_boss_victory.jpeg items/menhera_boss_victory.png
- Do NOT modify game code in this step; sheet creation only
```
