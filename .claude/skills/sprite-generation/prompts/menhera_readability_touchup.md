# Menhera Readability Touch-Up Prompt

Readability-focused regeneration prompt for the Stage 3 Menhera canonical walk
sheet. Use this when the character identity is correct but the in-game
small-size read feels softer / blurrier than Honglyeon.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
walking sprite sheet for real-stage 3 boss Menheragirl (code current_stage == 3),
with the specific goal of improving gameplay-scale readability while preserving
the exact accepted character identity.

Goal:
- Keep the SAME Stage 3 Menhera Girl character
- Fix soft in-game readability so the sheet reads more clearly at gameplay size
- Preserve pastel softness and chibi charm, but increase value separation and
  silhouette clarity
- Improve clarity WITHOUT redesign, WITHOUT increasing saturation too much,
  and WITHOUT making the art look harsher or more mature

Canonical continuity reference:
- Use the current items/menhera_boss_sheet.png as the identity continuity anchor
- This character MUST look like the EXACT SAME person as the current sheet
- Do NOT redesign, reinterpret, or modernize the character
- If the result looks like a different character, reject and regenerate

Fixed design elements (must remain identical):
- Very pale pastel pink bob haircut / soft pink hair mass
- Pink nurse cap with pink cross
- Pink ribbon on the character's right side
- Black cat ears
- Olive eyes
- Cat-paw gloves
- Thin cat tail
- Pink nurse dress with black trim
- Chibi 2-head proportions
- Thick black pixel outline

Readability fixes required:
- Hair / face separation: make the bangs and front hair read slightly darker or
  more clearly separated from the face so the forehead, cheeks, and eye area do
  not visually melt together at small in-game size
- Face readability: make the upper lash line, eye outline, iris edge, eyebrows,
  and small mouth more readable at gameplay scale
- Arm / glove / torso separation: the cat-paw gloves must read clearly darker
  than the arms and must not visually merge into the dress body
- Dress / skin separation: the pink dress should read one value step darker than
  the skin so the body silhouette stays legible after downscaling
- Tail readability: the tail must remain visible and clean at small size
- Reduce muddy midtones; keep cleaner light / mid / dark separation across hair,
  face, dress, gloves, and tail
- Preserve soft pastel identity; do NOT solve readability by pushing the design
  into harsh saturation, edgy anime contrast, painterly rendering, or realism

Size / composition rules:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Identical character design/palette/scale across all frames
- Use this walking sheet as the body-scale reference for this boss
- Body silhouette size must stay consistent across all future attack/dash/turn/defeat/victory sheets (+/-5%)
- Leave generous empty margin around each sprite
- Each character fills only about 45-55% of each cell's height

Walk motion requirements (front-biased walk, PingFighter default):
- Body and face stay mostly front-facing across all frames
- Express lateral movement through legs, arm swing, hair, ribbon, dress hem,
  tail, and accessory motion -- NOT by turning the torso to the side
- Front-facing but lively: do NOT restrict motion to limb wiggle only
- Add body bob, weight shift, subtle hip / shoulder counter-sway, hair sway,
  ribbon motion, cloth flutter, and tail motion
- Preserve frontal combat readability: the boss should still look like it is
  facing the player and the ball in every frame

Silhouette continuity:
- The head, hair, shoulders, and upper torso must read as one closed continuous shape
- Do NOT leave any transparent gap between side hair and shoulders / upper torso
- If needed, include a rear hair layer behind the shoulders so the silhouette
  connects cleanly

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines,
  flat limited-saturation palette, clean hard-edged pixels,
  NO painterly rendering, NO soft shading, NO photorealism

Gameplay-scale readability is mandatory from the first generation:
- The face, eyes, bangs, mouth, gloves, arms, and silhouette must remain
  readable at small in-game size
- Preserve clear separation between hair, face, arms, and torso
- Keep identity and pastel softness, but do NOT treat readability as an
  optional later polish pass -- build it in during this first generation

Output:
- First generate items/menhera_boss_sheet.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/menhera_boss_sheet.jpeg items/menhera_boss_sheet.png
- Do NOT modify game code in this step; sheet creation only
```
