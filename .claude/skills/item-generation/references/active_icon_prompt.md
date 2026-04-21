# Active Item Icon — Copy-Paste Prompt

Replace `[ITEM_NAME]`, `[CONCEPT]`, `[ACCENT_COLOR]` before sending to
Gemini MCP. See `SKILL.md` §4 for the rules behind this prompt.

```
Pixel art item icon for "[ITEM_NAME]" — [CONCEPT].

Canvas: 32 x 32 px (square), transparent background.
Subject fills 60–75% of the canvas, centered with breathing room.

Style:
- 16-bit retro pixel art, flat limited-saturation palette
- 1–2 px thick black pixel outline, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photoreal product shot
- NO anti-aliased blur, NO oil-painting style

Subject rules:
- The silhouette must read as a usable consumable / gadget (a thing
  the player clicks to trigger an effect) — not a buff aura, not a
  body part, not a character limb.
- No text, no numerals, no watermarks inside the canvas.
- Apply a single accent color [ACCENT_COLOR] on the main face of the
  object, 1–2 px of lighter tone for subtle shine (no painted
  gradients).

HUD-scale readability is mandatory from the first generation: the
item must remain identifiable at ~24px in-game. Keep the silhouette
strong, keep the central motif high-contrast, avoid muddy midtones,
and make sure the outline survives downscaling.
```

Accent-color examples:

| Effect | Accent color |
|---|---|
| Damage / explosive | red / orange-red |
| Utility / gadget | cyan / electric blue |
| Reward / gold | warm gold / yellow |
| Pandora / chaos | purple / magenta |
| Heal / medical | green / soft green |
| Poison / venom | neon green / toxic yellow |

## Output

Save as `items/[item_name].png` or `items/[item_name]_icon.png` per
existing naming convention. Do NOT overwrite `items/unknown_item.png`.
