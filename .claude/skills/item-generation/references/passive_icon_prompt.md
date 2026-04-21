# Passive Item Icon — Copy-Paste Prompt

Replace `[ITEM_NAME]`, `[CONCEPT]`, `[BODY_PART]`, `[PALETTE_BAND]`
before sending to Gemini MCP. See `SKILL.md` §5 for the rules behind
this prompt.

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
- The silhouette must read as wearable gear for the [BODY_PART] slot
  (e.g. boots / belt / helmet / vest / ring / amulet / goggles /
  glove / pendant / pouch).
- Do NOT imply an explosion, projectile, or consumable — those read
  as active items.
- Palette band: [PALETTE_BAND] (keep the overall hue inside the band;
  accent highlights may vary within the band).
- No text, no numerals, no watermarks inside the canvas.

HUD-scale readability is mandatory from the first generation: the
item must be recognizable as the correct body-part slot at ~24px.
Keep the silhouette strong, avoid muddy midtones, and make sure the
outline survives downscaling.
```

## Slot → body-part hint

Use `[BODY_PART]` values that match the runtime `PASSIVE_SLOT_ORDER`
family. These are the eight slots the player has:

| Korean label | English hint for prompt |
|---|---|
| 머리 | head-worn (helmet, hat, goggles, mask) |
| 상의 | torso-worn (vest, armor, jacket) |
| 팔 | arm-worn (glove, gauntlet, bracer, phone) |
| 벨트 | waist-worn (belt, sash, buckle) |
| 무릎 | knee-worn (pad, guard, brace) |
| 신발 | foot-worn (boots, shoes, sandals) |
| 등 | back-worn (backpack, cape, wing, jetpack) |
| 장신구 | accessory (ring, amulet, pendant, whistle, detector) |

## Palette bands (starting points)

| Theme family | Palette band |
|---|---|
| Leather / pouch / belt | warm brown, tan, dark brown |
| Steel armor | cool gray, blue-gray, silver |
| Gold accessory | warm gold, ivory, soft yellow |
| Nature passive | forest green, moss, earth brown |
| Tech passive | neon cyan, black, electric blue |
| Mystic passive | deep purple, indigo, soft violet |

## Equip visual note

If the passive item visually attaches to the player character when
equipped (e.g. chargebag on back, technical_vest on torso), a second
asset is required: see `equip_visual_prompt.md`.

## Output

Save as `items/[item_name].png` or `items/[item_name]_icon.png` per
existing naming convention.
