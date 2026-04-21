# Legendary / Mythic Item Icon — Copy-Paste Prompt

Replace `[ITEM_NAME]`, `[CONCEPT]`, `[THEME_HUE]`,
`[SIGNATURE_PARTICLE]` before sending to Gemini MCP. See `SKILL.md`
§6 for the rules behind this prompt, and read
`LEGENDARY_ITEM_TEMPLATE.md` in the repo root for the exact pixel
values of the frame stack.

```
Pixel art legendary item icon for "[ITEM_NAME]" — [CONCEPT].

Canvas: 32 x 32 px (square). The full legendary frame stack must be
BAKED into the PNG (not composed at runtime). 8 animation frames,
saved per the file naming in SKILL.md §8.

Frame stack (read LEGENDARY_ITEM_TEMPLATE.md for exact pixel values):
- Oversized solid circular background (~28 px radius), frame-animated
  across 8 frames in the [THEME_HUE] band.
- 3 x 3 silver / purple corner ornaments, frame-animated.
- 2 px red outer border, frame-animated across 8 frames.
- Central item subject drawn on TOP of the frame stack, identical
  across all 8 frames (only the frame colors animate — the subject
  must NOT drift).

Subject style:
- 16-bit retro pixel art, flat limited-saturation palette
- 1–2 px thick black pixel outline, clean hard-edged pixels
- NO painterly rendering, NO soft shading, NO photoreal product shot
- NO anti-aliased blur, NO oil-painting style
- Subject fills ~50-65% of the canvas (smaller than a normal icon
  because the frame stack occupies the outer ring).

No text, no numerals, no watermarks inside the canvas.

HUD-scale readability is mandatory from the first generation: the
legendary subject must remain identifiable at ~24px in-game on top
of the frame. Keep the silhouette strong, avoid muddy midtones, and
make sure the frame's red outer border survives downscaling.

Signature particle (documented here for runtime hand-off, NOT drawn
into the icon): [SIGNATURE_PARTICLE].
```

## Picking `[THEME_HUE]`

See `SKILL.md` §6.1. Shortlist:

| Concept | Theme hue |
|---|---|
| Thunder / hammer | electric blue |
| Sky / wind / speed | cyan-teal |
| Ocean / tide | deep teal |
| Fire / rage | orange-red |
| Holy / blessing | warm gold / white |
| Chaos / mystery | purple-magenta |
| Divine judgment | deep violet with gold |
| Sight / prophecy | amber-gold |

## Picking `[SIGNATURE_PARTICLE]`

See `SKILL.md` §6.3. Shortlist:

| Theme | Particle |
|---|---|
| Thunder / hammer | blue-white spark bursts, short zigzag bolts |
| Sky / wind / speed | pale cyan streaks, soft feather puffs |
| Ocean / tide | teal droplet arcs, foam ring |
| Fire / rage | orange ember rise, black smoke tail |
| Holy / blessing | gold dust upward, soft halo |
| Chaos / mystery | purple magenta shimmer, flicker crackle |
| Divine judgment | deep violet + gold flare, star snap |
| Sight / prophecy | amber rune glyph flicker, narrow beam |

## `empty_legendary` placeholders

Do NOT generate an asset for `empty_legendary`, `empty_legendary2` …
`empty_legendary6`. These are blank developer-mode grid slots; the
icon function in `pingfighter.py` returns an empty Surface for any
name starting with `empty_legendary`. Wiring a new mythic icon into
the developer-mode grid is a runtime step — see
`docs/item_runtime_checklist.md`.

## Output

Save the 8 frames as `items/[item_name]_frame_0.png` …
`items/[item_name]_frame_7.png`, and a stand-alone preview as
`items/[item_name].png` (optional). Follow whatever existing
legendary item (ragnarok_hammer / hermes_shoes / poseidon_trident)
uses on disk and match its scheme.
