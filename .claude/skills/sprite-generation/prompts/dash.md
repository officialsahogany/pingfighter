# Dash Sheet Prompt Template

Copy, replace `[name]`, `[boss name]`, `[real stage number]`, `[code stage number]`,
and the per-boss blocks.

**Precondition:** `items/[name]_boss_sheet.png` (walking sheet) must already
exist and be accepted as the canonical identity + body-scale reference.

---

```
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate the
dash sprite sheet for real-stage [real stage number] boss [boss name]
(code current_stage == [code stage number]).

Goal:
- [character description]
- [dash style: charging / sliding / blink / low-profile glide]
- Fast and intimidating, but body scale stays identical to walking sheet

Fixed design elements (same as walking sheet — do not redesign):
- [outfit]
- [hair]
- [eye color]
- [dash particles / trails]
- Head / torso / pelvis scale identical to walking sheet

Canonical reference:
- Use items/[name]_boss_sheet.png as the canonical visual reference
- This character MUST look like the EXACT SAME person as in the walking sheet
- Do NOT redesign, reinterpret, or modernize the character
- Keep the SAME hair color, hairstyle, face shape, eye color, skin tone,
  outfit design, and all signature accessories
- If the result looks like a different character, reject and regenerate

Sheet composition:
- 8-frame dash sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: crouch prep, push-off, low slide, full extension + trail
- row2: sustained slide + particles, deceleration, recovery rise, standing return
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent where possible
- Character body scale must match the walking sheet (+/-5%)
- Dash should feel faster through pose, lean, trail, motion lines, cloth/hair drag
- Do NOT shrink or enlarge the body to convey speed
- Leave generous empty margin around each sprite

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- Flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

Output:
- First generate items/[name]_boss_dash.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/[name]_boss_dash.jpeg items/[name]_boss_dash.png
- Do NOT modify game code in this step; sheet creation only.
```
