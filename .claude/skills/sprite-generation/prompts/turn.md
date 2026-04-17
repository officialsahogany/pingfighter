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
- Redraw the same character at 13 angles of body orientation
- Row 1: +90, +75, +60, +45, +30, +15, 0 degrees
- Row 2: -15, -30, -45, -60, -75, -90, (blank last cell)
- Sign convention: +90 = full right profile, 0 = front, -90 = full left profile

Canonical reference:
- Use items/[name]_boss_sheet.png as the canonical visual reference
- This character MUST look like the EXACT SAME person as in the walking sheet
- Do NOT redesign, reinterpret, or modernize the character
- Keep the SAME hair color, hairstyle, face shape, eye color, skin tone,
  outfit design, and all signature accessories
- If the turn sheet looks like a different character, reject and regenerate
- Do NOT produce a simple image-rotation output; each angle must be a
  fresh redraw at that angle

Allowed to change (only these):
- body orientation
- gaze direction
- shoulder / pelvis angle
- limb / tail / ribbon / cloth front-back overlap at each angle

Must stay identical:
- hair color / hairstyle / face shape
- proportions / art style
- outfit design / accessories

Sheet composition:
- 13 frames total in a 7x2 grid (last cell blank)
- aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Body scale stays within +/-5% of the walking sheet (SKILL.md Section 8.1)
- Neighboring frames must interpolate cleanly from one body orientation
  to the next; a smooth 15-degree step between adjacent cells

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
