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
- If items/[name]_boss_sheet.png already exists, treat it as the last
  accepted canonical walk reference until the new candidate passes QA
- The new walk is NOT allowed to become more side-facing than the last
  accepted walk just because it is livelier or more polished

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
- This is a FRONT-FACING walk, NOT a hidden 3/4 walk
- Express lateral movement through legs, arm swing, hair, ribbons,
  cloth, tail, and accessory motion -- NOT by turning the torso to the
  side
- Stride difference, weight shift, subtle shoulder/pelvis counter-swing
- Hair / ribbon / cloth / props / tail swing visibly across frames
- Preserve frontal combat readability: the boss should still look like
  it is facing the player and the ball in every frame, even while
  moving laterally
- Both left-travel and right-travel gameplay must still read as a
  forward-facing boss moving laterally
- Do NOT let hair mass, ribbon placement, eye placement, cheek
  exposure, hat tilt, shoulder angle, or torso angle create a
  persistent left-looking or right-looking bias
- Full side-facing walk is NOT the default for PingFighter bosses
- Even at small in-game size, presence of a boss and face readability
  must survive downscaling
- If the new walk would read more side-facing than the previous
  accepted walk, reject that design direction and keep the older
  frontal baseline

Shared walk+turn motion language (buoyant Menhera rule, always on):
- Walk and turn MUST feel like the same animation language: front-
  biased, softly bouncy, cute, and lively
- Use light body bob, soft weight shift, subtle chibi rebound, and
  small follow-through in hair, ribbon, tail, and hem so left/right
  movement feels natural, not stiff or mechanical
- Do NOT keep the torso frozen while only the limbs cycle -- the whole
  body should breathe and rebound together across frames
- Walk and turn are judged as one continuous motion style, not two
  separate cycles

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

Hard reject conditions:
- Reject if stable movement reads as consistently looking left or
  consistently looking right instead of facing the player
- Reject if moving right feels like the boss is looking left, or moving
  left feels like the boss is looking right
- Reject if one eye / cheek / shoulder exposure creates a persistent
  3/4-face read instead of a frontal face
- Reject if the candidate is more side-biased than the previous
  accepted walk even if animation energy improved
- Reject instead of expecting runtime flips, remaps, or facing hacks to
  rescue the sheet

Output:
- First generate items/[name]_boss_sheet.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/[name]_boss_sheet.jpeg items/[name]_boss_sheet.png
- Do NOT modify game code in this step; sheet creation only.
- Do NOT consider the new file promoted to canonical until it passes
  frontal-neutrality QA against the previous accepted walk
```
