# Menhera Attack Realign Prompt

Use this after the canonical walk sheet has been regenerated and accepted.
The goal is to redraw the attack sheet so it matches the new walk sheet's
identity, scale, and gameplay-scale readability.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
attack sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3),
aligned to the NEW accepted canonical walk sheet at items/menhera_boss_sheet.png.

Goal:
- Keep the SAME Stage 3 Menhera Girl character as the new canonical walk sheet
- Preserve the current attack-sheet motion intent if items/menhera_boss_attack.png
  already exists, but redraw it so the result matches the NEW canonical walk
  identity, body-scale reference, and readability level
- Expression: fierce / unstable / emotionally intense, but still readable and
  still the same character
- Prioritize same-character continuity and small-size clarity over dramatic FX

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
- 8-frame attack sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: ready, wind-up, backswing, max charge
- row2: swing start, impact with motion line, follow-through, recovery
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Character body scale must match the NEW walking sheet (+/-5%)
- The character's HEAD, TORSO, and PELVIS must be the SAME SIZE as the NEW walking sheet
- Effects may grow larger, but the body itself must not become larger or smaller
- Keep the VISIBLE BODY READ the same as on the NEW walking sheet
- Leave generous empty margin around each sprite

Attack motion:
- Clear ready -> charge -> twist -> release / impact -> recovery flow
- Arm trajectory, torso rotation, weight shift, hair / ribbon / tail / cloth swing visible
- Impact frame conveys forward pressure and emotional force
- Preserve frontal combat readability even during the strongest frame

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
- First generate items/menhera_boss_attack.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/menhera_boss_attack.jpeg items/menhera_boss_attack.png
- Do NOT modify game code in this step; sheet creation only
```
