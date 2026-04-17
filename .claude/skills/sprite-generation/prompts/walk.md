# Walk Sheet Prompt Template

Copy, replace `[name]`, `[boss name]`, `[real stage number]`, `[code stage number]`,
and the per-boss blocks in brackets.

Stage mapping reminder: code `current_stage == 5` is real Stage 6 Honglyeon,
code `current_stage == 6` is real Stage 5 Nemesis. State both when they differ.

---

```
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate the
walking sprite sheet for real-stage [real stage number] boss [boss name]
(code current_stage == [code stage number]).

Goal:
- [character description]
- [item in hand / atmosphere / expression]
- Prioritize [desired impression] over cuteness
- If items/[name]_boss_sheet.png already exists, preserve design continuity with it

Fixed design elements (must not drift in later sheets):
- [outfit]
- [hair]
- [eye color]
- [signature props / effects]
- Thick black pixel outline

Size / composition rules:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Identical character design/palette/scale across all frames
- Use this walking sheet as the body-scale reference for this boss
- Body silhouette size must stay consistent across all future attack/dash sheets (+/-5%)
- Leave generous empty margin around each sprite
- Each character fills only about 45-55% of each cell's height

Walk motion requirements (front-biased walk, PingFighter default):
- Body and face stay mostly front-facing across all frames
- Express lateral movement through legs, arm swing, hair, ribbons,
  cloth, tail, and accessory motion -- NOT by turning the torso to the
  side
- Stride difference, weight shift, subtle shoulder/pelvis counter-swing
- Hair / ribbon / cloth / props / tail swing visibly across frames
- Preserve frontal combat readability: the boss should still look like
  it is facing the player and the ball in every frame, even while
  moving laterally
- Full side-facing walk is NOT the default for PingFighter bosses
- Even at small in-game size, presence of a boss and face readability
  must survive downscaling

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- Flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

Gameplay-scale readability (mandatory from first generation):
- The face, eyes, bangs, mouth, gloves, arms, and silhouette must
  remain readable at small in-game size
- Reduce muddy midtones; keep clear light / mid / dark separation
- Preserve clear separation between hair, face, arms, and torso
- Keep identity and pastel/16-bit softness, but do NOT treat
  readability as an optional later polish pass -- build it in during
  this first generation

Output:
- First generate items/[name]_boss_sheet.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/[name]_boss_sheet.jpeg items/[name]_boss_sheet.png
- Do NOT modify game code in this step; sheet creation only.
```
