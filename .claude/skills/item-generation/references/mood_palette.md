# Item Mood → Palette / Glow / Border / Particle Map

Reference only. The per-item-type prompt files already inline the
relevant bands — use this file when the item's theme does not fall
cleanly into the shortlists.

## Legendary / mythic background hue

Pick this FIRST, before drawing the central subject. See `SKILL.md`
§6.1 for the short list tied to existing legendary items.

| Theme family | Background hue | In-game signal |
|---|---|---|
| Thunder / hammer / storm | Electric blue | aggressive, tempo-pushing |
| Sky / wind / speed | Cyan-teal | mobility, dash-adjacent |
| Ocean / tide / ice | Deep teal | control, area denial |
| Fire / rage / burn | Orange-red | sustained damage |
| Holy / blessing / heal | Warm gold / white | defensive, recovery |
| Chaos / mystery | Purple-magenta | random, RNG, Pandora-like |
| Divine judgment / crown | Deep violet with gold | late-game power spike |
| Sight / prophecy / radar | Amber-gold | information, detection |
| Nature / poison / venom | Toxic green | damage-over-time |
| Shadow / stealth | Deep purple / charcoal | evasion, assassin-style |

## Active item accent (single-color)

For active items, pick ONE accent color tied to the effect — see
`active_icon_prompt.md` for the short list. Do not stack multiple
accent colors on an active icon; it flattens HUD readability.

## Passive item palette bands

For passive items, keep the overall hue inside a palette band. See
`passive_icon_prompt.md` for the default bands per slot family.

## Border rules

| Item tier | Border treatment |
|---|---|
| Normal active | No frame, transparent BG |
| Normal passive | No frame, transparent BG |
| Legendary / mythic | Full `LEGENDARY_ITEM_TEMPLATE.md` stack baked in |

Do NOT draw a legendary border on a non-legendary item "for visual
pop." The border is a tier signal — abusing it breaks HUD reading.

## Particle theme prescriptions

For legendary / mythic items, state the particle theme in the Codex /
runtime hand-off. The icon PNG does NOT animate particles on its own
— the effects manager at runtime spawns them. See `SKILL.md` §6.3
for the shortlist.

Extended table (use as starting points for new themes):

| Theme family | Particle prescription |
|---|---|
| Thunder / hammer | blue-white spark bursts, short zigzag bolts |
| Sky / wind / speed | pale cyan streaks, soft feather puffs |
| Ocean / tide / ice | teal droplet arcs, foam ring |
| Fire / rage / burn | orange ember rise, black smoke tail |
| Holy / blessing / heal | gold dust upward, soft halo |
| Chaos / mystery | purple magenta shimmer, flicker crackle |
| Divine judgment | deep violet + gold flare, star snap |
| Sight / prophecy / radar | amber rune glyph flicker, narrow beam |
| Nature / poison / venom | toxic green bubbles, drip trail |
| Shadow / stealth | charcoal smoke tendrils, flicker fade |
| Earth / quake | brown dust plume, cracked ground shards |
| Bone / spirit | pale bone-white wisps, drifting skulls (stylized only) |

## When to break the pattern

If the item's concept is so specific that none of the bands fit
cleanly, propose a new band in the hand-off so it can be tracked —
but keep the frame stack rules from `LEGENDARY_ITEM_TEMPLATE.md`
intact. Never skip the red outer border or the corner ornaments on
a legendary tier.
