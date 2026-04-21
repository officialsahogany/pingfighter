# Menhera Defeat Sheet Prompt

Ready-to-send prompt for Claude / Gemini image generation.

**Precondition:** `items/menhera_boss_sheet.png` (walking sheet) must already
exist and be accepted as the canonical identity + body-scale reference.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate the
defeat sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3).

Goal:
- Same Stage 3 Menhera Girl character as the NEW accepted walking sheet
- A non-graphic defeat / collapse sequence: emotionally defeated, dazed,
  exhausted, unstable, and vulnerable, but NOT dead, grotesque, or horror-coded
- Prioritize same-character continuity, gameplay readability, and body-scale
  continuity over dramatic exaggeration
- This should read as a boss-loss / round-loss animation sheet, not a death scene

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
- Head / torso / pelvis scale identical to walking sheet

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
- 8-frame defeat sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: light stagger, stronger stagger, knees weakening, drop to one knee
- row2: seated / collapsed landing, slumped dazed defeat, final defeated hold,
  tiny settle / breathing hold
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Each cell exactly equal size, character centered
- Character view stays front-facing in every frame; express asymmetry through
  head tilt, shoulder drop, torso slump, arm placement, hair swing, ribbon
  motion, and tail / cloth follow-through -- NOT by turning into side profile
- Keep the body anchored to one consistent ground plane across frames
- Character body scale must match the NEW walking sheet (+/-5%)
- The character's HEAD, TORSO, and PELVIS must be the SAME SIZE as the NEW walking sheet
- Do NOT shrink the body to sell defeat or fatigue -- use pose, slump,
  compression, and cloth / hair settling instead
- Keep the VISIBLE BODY READ the same as on the NEW walking sheet
- Effects, cloth spread, hair spread, or emotional accents may extend outward,
  but they must NOT visually compress the body
- Each character fills only about 45-55% of each cell's height
- Leave generous empty margin around each sprite

Defeat motion requirements:
- Clear readable progression from balance loss -> collapse -> defeated hold
- The sequence should feel like a boss who has just lost composure and dropped
  into an exhausted defeated pose
- Use body slump, shoulder drop, pelvis collapse, hair/ribbon/tail settling,
  and small cloth drag to convey impact and fatigue
- Expression progression: shocked / unsteady -> pained / dazed -> drained /
  defeated
- Keep the face readable from the front in every frame
- Avoid comedic slapstick, cute pout posing, or overacted cartoon flailing

Silhouette continuity:
- The head, hair, shoulders, and upper torso must read as one closed continuous shape
- Do NOT leave any transparent gap between side hair and shoulders / upper torso
- If needed, include a rear hair layer behind the shoulders so the silhouette
  connects cleanly
- This applies to every frame of the sheet at gameplay scale

Gameplay-scale readability is mandatory from the first generation:
- The face, eyes, bangs, mouth, gloves, arms, and silhouette must remain
  readable at small in-game size
- Reduce muddy midtones
- Preserve clear separation between hair, face, arms, and torso
- Keep identity and pastel softness, but do NOT treat readability as an
  optional later polish pass -- build it in during this first generation

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines,
  flat limited-saturation palette, clean hard-edged pixels,
  NO painterly rendering, NO soft shading, NO photorealism

Output:
- First generate items/menhera_boss_defeat.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/menhera_boss_defeat.jpeg items/menhera_boss_defeat.png
- Do NOT modify game code in this step; sheet creation only
```
