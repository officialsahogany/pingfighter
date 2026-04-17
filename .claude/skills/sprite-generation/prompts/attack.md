# Attack Sheet Prompt Template

Copy, replace `[name]`, `[boss name]`, `[real stage number]`, `[code stage number]`,
and the per-boss blocks.

**Precondition:** `items/[name]_boss_sheet.png` (walking sheet) must already
exist and be accepted as the canonical identity + body-scale reference.

---

```
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, generate the
attack sprite sheet for real-stage [real stage number] boss [boss name]
(code current_stage == [code stage number]).

Goal:
- [character description]
- [attack concept]
- Expression: fierce / cool / dominant / serious
- Prioritize intimidation and charisma over cuteness

Fixed design elements (same as walking sheet — do not redesign):
- [outfit]
- [hair]
- [eye color]
- [weapon / flame / aura]
- Body scale identical to walking sheet

Canonical reference:
- Use items/[name]_boss_sheet.png as the canonical visual reference
- This character MUST look like the EXACT SAME person as in the walking sheet
- Do NOT redesign, reinterpret, or modernize the character
- Keep the SAME hair color, hairstyle, face shape, eye color, skin tone,
  outfit design, and all signature accessories
- If the result looks like a different character, reject and regenerate

Sheet composition:
- 8-frame attack sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- row1: ready, wind-up, backswing, max charge
- row2: swing start, impact with motion line, follow-through, recovery
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character view is exactly front-facing in every frame
- Keep foot/baseline position consistent across frames
- Character body scale must match the walking sheet (+/-5%)
- Effects may grow larger, but the body itself must not become larger or smaller
- Leave generous empty margin around each sprite

Attack motion:
- Clear ready -> charge -> twist -> release/impact -> recovery flow
- Arm trajectory, torso rotation, weight shift, hair/cloth swing visible
- Impact frame conveys forward energy and pressure

Style rules:
- 16-bit retro pixel art, chibi proportions, thick black pixel outlines
- Flat limited-saturation palette, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photorealism

Output:
- First generate items/[name]_boss_attack.jpeg
- Then run:
    py .claude/skills/sprite-generation/remove_bg.py \
        items/[name]_boss_attack.jpeg items/[name]_boss_attack.png
- Do NOT modify game code in this step; sheet creation only.
```
