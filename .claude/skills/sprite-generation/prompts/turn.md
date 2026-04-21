# Turn / Facing-Transition Sheet Prompt Template

Turn sheets are **optional aux sheets** for brief left<->right facing changes.
Normal locomotion still uses the main walking sheet. See `SKILL.md` Section 9.

**Precondition:** `items/[name]_boss_sheet.png` (walking sheet) must exist
and be accepted as the canonical identity + body-scale reference.

---

```
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate a
turn / facing-transition sprite sheet for real-stage [real stage number]
boss [boss name] (code current_stage == [code stage number]).

This is a turn / facing transition sheet, NOT a replacement for the main
walking sheet. Normal movement will continue to use items/[name]_boss_sheet.png.
This sheet is intended for brief runtime direction changes (left <-> right
facing, idle return to front), not for the full walking cycle.

Goal:
- Create a BRIEF direction-change transition sheet for the same frontal
  walk character
- This is NOT a side-view rotation chart and NOT a +90 -> 0 -> -90 angle sheet
- The character should stay visually connected to the front-facing walk
  while showing a short signature "kuse" during the direction change
- Use the turn to express personality: for example a head lift, chin tilt,
  shoulder hitch, arm pose swap, one-knee lift, tiny hop / pivot, ribbon /
  hem rebound, or another boss-specific habit that suits the concept
- The result should read as "the same boss briefly changing direction
  with style," not as "the camera rotates around the boss"

Canonical reference:
- Use items/[name]_boss_sheet.png as the canonical visual reference
- This character MUST look like the EXACT SAME person as in the walking sheet
- Do NOT redesign, reinterpret, or modernize the character
- Keep the SAME hair color, hairstyle, face shape, eye color, skin tone,
  outfit design, and all signature accessories
- If the turn sheet looks like a different character, reject and regenerate
- Do NOT produce a simple image-rotation output
- Do NOT turn the character into a profile showcase or angle chart
- Keep the same frontal combat readability as the walk

Allowed to change (only these):
- temporary asymmetry in pose
- head / chin lift or tilt
- shoulder / torso hitch
- arm pose change
- one-leg / knee lift
- small hop / pivot accent
- hair / ribbon / tail / cloth rebound and overlap changes that support
  the transition gesture

Must stay identical:
- hair color / hairstyle / face shape
- proportions / art style
- outfit design / accessories

Shared walk+turn motion language (buoyant Menhera rule, always on):
- Walk and turn MUST feel like the same animation language: front-
  biased, softly bouncy, cute, and lively
- Use light body bob, soft weight shift, subtle chibi rebound, and
  small follow-through in hair, ribbon, tail, and hem so the facing
  transition feels natural and springy, not stiff or mechanical
- Do NOT keep the torso frozen while only the head or limbs twitch --
  the whole body should breathe and rebound together through the short
  transition sequence
- Walk and turn are judged as one continuous motion style, not two
  separate cycles

Sheet composition:
- 8 frames total in a 4x2 grid
- aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Body scale stays within +/-5% of the walking sheet (SKILL.md Section 8.1)
- Frame plan:
  - Row 1: walk-compatible carry-in, compress / plant, accent wind-up, peak transition pose
  - Row 2: rebound, recovery, settle, walk-compatible return
- Neighboring frames must read as one short continuous gesture sequence
  that can enter from walk and return to walk cleanly

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- Flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

Output:
- First generate items/[name]_boss_turn.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/[name]_boss_turn.jpeg items/[name]_boss_turn.png
- Do NOT modify game code in this step; sheet creation only.
```
