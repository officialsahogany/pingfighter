---
name: item-generation
description: |
  Item visual generation pipeline for PingFighter. Covers active item icons,
  passive item icons, legendary / mythic item icons (empty_legendary
  frame rules), character paddle-part equip visuals, mood-based glow /
  border / particle rules, Claude-ready copy-paste prompts, and the
  reject / regenerate QA checklist. This skill ONLY owns visual asset
  creation for items. Runtime integration (items.py registration, shop /
  gacha / crane / treasure hunt, active vs passive routing, roll
  options, polish perks, enhancement buffs, equip visual wiring) lives
  in docs/item_runtime_checklist.md and is NOT covered here. Boss /
  character sprite sheets live in the sprite-generation skill and are
  NOT covered here. Use this skill whenever the user asks to create,
  regenerate, redraw, or fix an item icon, an active / passive / legendary
  item visual, a character paddle-part equip visual, or item mood /
  theme art. 한국어 트리거 키워드 - 아이템 아이콘, 액티브 아이콘, 패시브 아이콘,
  전설 아이콘, 신화 아이콘, 장착 외형, 파츠 외형, 아이템 파티클, empty_legendary,
  아이템 비주얼, 아이템 프롬프트, 아이템 제작.
---

# Item Generation Pipeline (PingFighter)

Asset-generation plays for **item icons** and **character equip visuals**.
Runtime integration is NOT covered here — hand off to
`docs/item_runtime_checklist.md` after the asset is accepted.

Companion files in this skill directory:

- `references/active_icon_prompt.md` — copy-paste active item icon prompt
- `references/passive_icon_prompt.md` — copy-paste passive item icon prompt
- `references/legendary_icon_prompt.md` — copy-paste legendary / mythic icon prompt
- `references/equip_visual_prompt.md` — character paddle-part equip visual prompt
- `references/mood_palette.md` — theme → palette / glow / particle mapping

---

## 0. Scope boundary (do not confuse with sprite-generation)

This skill is narrow. Stay inside it.

Runtime character perk / skill work does NOT belong here. Use
`docs/character_skill_perk_checklist.md` for unlock perks, player-skill /
5-orb HUD integration, tooltip sync, skill-gold reward policy, and
save/load/reset audits, and use `CLAUDE.md` for the companion
`draw_skill_icon_mini()` and perk-text path invariants.

If the report is "a skill / perk icon still looks too small" or "the HUD
version and perk-card version do not match," treat that as runtime
character perk / skill integration, not item-asset work. The fix belongs
in `docs/character_skill_perk_checklist.md` + `CLAUDE.md` and must audit:

- `draw_skill_icon_mini()`
- `_draw_skill_icon_symbol()`
- live id aliases (`perk id`, unlock id, runtime skill id, legacy id)
- perceived subject size at the smallest real UI box

A generated mockup, PNG, or one successful large-card preview is not
enough to call a runtime character perk / skill icon "done."

| Question | Answer |
|---|---|
| Boss walk / attack / dash / turn sheet? | **sprite-generation skill** (not here) |
| Boss or character nukki (PNG background removal)? | **sprite-generation skill** (not here) |
| Item icon (active / passive / legendary)? | **this skill** |
| Character paddle-part visual for an equipped item? | **this skill** |
| Wiring the item into `items.py`, shop, gacha, reset, rolls? | **`docs/item_runtime_checklist.md`** (not here) |
| Registering a new viper perk / skill icon? | `CLAUDE.md` (Perk Icon Rendering) — not here |

Routing override:
- Any runtime character perk / skill icon registration or size/readability
  fix should route through
  `docs/character_skill_perk_checklist.md` + `CLAUDE.md`, not this skill.
- That review must cover mini icon rendering, orb symbol rendering, live id
  aliases, and the smallest real UI box where the icon appears.

Legacy wording note: the Viper-specific row in the table above is
representative only. For any runtime character perk / skill integration
work, use `docs/character_skill_perk_checklist.md` first, with
`CLAUDE.md` as the companion icon / UI trap reference.

**Do not import sprite-sheet rules (scale lock, turn-sheet layout,
front-biased walk, etc.) into this skill.** Item icons are flat 32 or
64 px single-cell renders; cross-sheet identity lock is not relevant.

---

## 1. When to use this skill

Trigger on any of these user intents:

- Create a new item icon (active / passive / legendary / mythic)
- Regenerate or repaint an item icon that reads poorly in HUD
- Draw a character paddle-part equip visual for a new passive item
- Decide the glow / border / particle mood for an item's theme
- Prepare a Claude-ready prompt to hand to Gemini MCP for an item asset
- Resolve the `empty_legendary` frame convention for a new legendary icon

If the user is wiring the item into `items.py`, the shop, the gacha, the
crane, treasure hunt, reset flow, or roll options — that is
**`docs/item_runtime_checklist.md`** territory. Do not drive it from here.
If the user is wiring a runtime character perk, unlock skill, 5-orb
skill HUD path, or deciding a new character skill's gold reward /
anti-double-pay behavior, that is
**`docs/character_skill_perk_checklist.md`** territory. Do not drive it
from here either.

---

## 2. Role split (three-way source-of-truth)

| Document | Owns |
|---|---|
| `.claude/skills/item-generation/` (this) | Item icons, equip visuals, prompts, mood rules, icon QA |
| `docs/item_runtime_checklist.md` | Every code location that must be touched to make the item work at runtime |
| `CLAUDE.md` | Thin routing rule pointing at both of the above |

Do not copy runtime rules into this skill. Do not copy icon / prompt
rules into `docs/item_runtime_checklist.md`. If the two documents
conflict, the runtime checklist wins for runtime behavior; this skill
wins for visual asset decisions.

---

## 3. Style unification — match existing icon wall

All existing item icons share one look: 32 or 64 px pixel art, thick
black pixel outlines, flat limited-saturation palette, clear center
subject, readable at ~24 px in the inventory HUD. Painterly rendering,
anti-aliased blur, photoreal product shots, and oil-painting style are
all forbidden.

Required English phrasing inside every item icon prompt:

```
pixel art item icon, 32px (or 64px) canvas, centered subject,
thick black pixel outline, flat limited-saturation palette,
clean hard-edged pixels, readable at ~24px in-game HUD,
NO painterly rendering, NO soft shading, NO photoreal product shot
```

Style knobs:

| Aspect | Required |
|---|---|
| Canvas | 32 × 32 px (inventory / HUD icon) or 64 × 64 px (shop card) |
| Subject fill | 60–75 % of canvas, centered, with breathing room |
| Outline | 1–2 px thick black pixel outline |
| Color | Flat, limited-saturation, hard-edged; no gradient-heavy renders |
| Background | Pure transparent OR the legendary frame stack (see §6) |
| Forbidden | Painterly shading, anti-aliased blur, photoreal, realistic metal SSS |

### 3.1. Readability at HUD scale is a first-generation requirement

Item icons must read at roughly 24 px in the inventory / HUD — not
just at 256 px preview size. An icon that is clear at source size but
becomes a colored blob in-game must be regenerated, not patched with a
runtime outline.

Required prompt fragment:

```
HUD-scale readability is mandatory from the first generation.
The item must remain identifiable at ~24px in-game: keep the
silhouette strong, keep the central motif high-contrast, avoid muddy
midtones, and keep any text / numerals out of the icon. Outline must
survive downscaling without breaking.
```

### 3.2. Transparency-indicator caveat (Gemini outputs)

Some Gemini outputs bake the editor's transparency-indicator checker
pattern into the actual pixels instead of giving a real transparent
background. The common failure case is a neutral gray checkerboard
behind the icon, which can survive naive "whitish background" nukki and
then show up in inventory cells in-game.

Rules:

- Non-legendary item icons must end with a real transparent background,
  not a fake checkerboard baked into the canvas.
- During QA, explicitly inspect the four corners and a few empty-margin
  pixels; background corners should read as transparent after nukki.
- If a Gemini render contains a gray checker transparency-indicator
  pattern, route it through the checker-aware nukki path in
  `.claude/skills/sprite-generation/remove_bg.py` instead of accepting
  the asset as-is.

---

## 4. Active item icon

Active items go into the active slot (5-orb cooldown UI). The icon must
read as a **usable consumable or gadget** — a thing the player clicks
to trigger an effect.

Required mood cues:

- **Silhouette reads as an object, not a buff aura.** A potion looks
  like a bottle; a bomb looks like a bomb; a dice looks like a dice.
- **No character limbs / body parts.** Active icons are props.
- **Subtle shine / spec highlight** on the object's main face — 1–2 px
  of lighter tone, not a painted gradient.
- **Bright saturated accent color** tied to the item's theme (red for
  damage, cyan for utility, gold for reward, purple for chaotic /
  pandora-like, green for heal / poison by context).

Transparent background. **No legendary frame stack.** (Active items
never use the legendary frame — that is reserved for legendary /
mythic items, see §6.)

Copy-paste prompt: `references/active_icon_prompt.md`.

File naming & path: §8.

---

## 5. Passive item icon

Passive items go into a body-part slot (head / 상의 / 팔 / 벨트 / 무릎 /
신발 / 등 / 장신구). The icon must read as a **wearable part or
equipment**, not a consumable.

Required mood cues:

- **Silhouette reads as gear** — boots, belt, helmet, vest, ring,
  amulet, goggles, glove, pendant, pouch.
- **Body-part hinting.** A belt icon should read as a belt at a
  glance, not an abstract buckle close-up; a helmet icon should be
  recognizable as head-worn.
- **Warm or utility palette** that matches the slot family. Rough
  palette bands: leather / brown for belts and pouches, steel / gray
  for armor, gold / white for rings and amulets, green for
  nature-themed passives, neon for tech-themed passives.
- **No weapon / projectile / explosion hint** — those read as active.

Transparent background. **No legendary frame stack** unless the item
is legendary or mythic.

Copy-paste prompt: `references/passive_icon_prompt.md`.

If the passive item also modifies the character's paddle / body when
equipped, you must also produce an equip visual (§7) and flag it in the
runtime hand-off (see §10 and `docs/item_runtime_checklist.md`).

---

## 6. Legendary / mythic item icon

Legendary items always have the full legendary frame stack (see
`LEGENDARY_ITEM_TEMPLATE.md` in the repo root for the exact pixel
values). This skill does not replace that template — it refers to it.
Read `LEGENDARY_ITEM_TEMPLATE.md` before generating any legendary
icon.

Summary of the frame stack (details in `LEGENDARY_ITEM_TEMPLATE.md`):

| Layer | Role |
|---|---|
| Oversized solid circular background (~28 px radius) | Frame-animated color band tied to item theme |
| 3 × 3 silver / purple corner ornaments | Frame-animated corner palette |
| 2 px red outer border, frame-animated | Legendary-tier signal |
| Central item subject | Drawn on top of the frame stack |
| 8 frames total | Animation is baked into the PNG(s), not composed at runtime |

### 6.1. Theme palette — pick before drawing

Pick the background-circle hue from the item's theme BEFORE drawing
the subject. Do not let the subject decide the frame color — the frame
color is a brand signal and should match the concept.

| Concept | Background hue |
|---|---|
| Thunder / hammer / storm (Ragnarok Hammer) | Electric blue |
| Sky / wind / speed (Hermes Shoes) | Cyan-teal |
| Ocean / tide (Poseidon Trident) | Deep teal |
| Fire / rage (Megingjord-like) | Orange-red |
| Holy / blessing (Angel Blessing, Sacred Laurel) | Warm gold / white |
| Chaos / mystery (Pandora Legacy) | Purple-magenta |
| Divine judgment / crown (Transcendent Crown) | Deep violet with gold |
| Sight / prophecy (Odin's Eye) | Amber-gold |

When in doubt, consult `references/mood_palette.md`.

### 6.2. `empty_legendary` convention

`empty_legendary`, `empty_legendary2` … `empty_legendary6` are **blank
slots** in the developer-mode legendary grid. They are NOT real items
and have no visual. In `pingfighter.py` the icon function for anything
starting with `empty_legendary` returns an empty `Surface` on purpose
so the grid cell renders blank.

Rules:

- Do NOT generate an icon asset for `empty_legendary*`.
- When adding a new legendary item, **do not replace `empty_legendary*`
  strings in code.** They are placeholders the developer-mode grid
  relies on to keep its layout.
- If the user says "use empty_legendary for the mythic icon", they
  mean: slot the new mythic item's icon into a developer-mode grid
  cell that currently renders blank. Wiring that into the grid is a
  runtime step — see `docs/item_runtime_checklist.md`.

Copy-paste prompt: `references/legendary_icon_prompt.md`.

### 6.3. Theme particle rules (for mythic-tier pieces)

Every legendary / mythic item should have a theme-consistent particle
idea documented in the hand-off to runtime, even if the icon itself is
a still frame. The runtime side (effects manager) is the one who
actually spawns particles; this skill only prescribes the theme.

| Theme | Particle prescription |
|---|---|
| Thunder / hammer | Blue-white spark bursts, short zigzag bolts |
| Sky / wind / speed | Pale cyan streaks, soft feather puffs |
| Ocean / tide | Teal droplet arcs, foam ring |
| Fire / rage | Orange ember rise, black smoke tail |
| Holy / blessing | Gold dust upward, soft halo |
| Chaos / mystery | Purple magenta shimmer, flicker crackle |
| Divine judgment | Deep violet + gold flare, star snap |
| Sight / prophecy | Amber rune glyph flicker, narrow beam |

State the particle theme in the Codex / runtime hand-off (not in the
icon PNG).

---

## 7. Character paddle-part equip visual

For passive items that visually attach to the player character when
equipped (e.g. chargebag on the back, technical_vest on the torso,
bulletproof_hat on the head, bulkup on the arms), a second asset is
needed: the **equip visual** that overlays on the player paddle /
character skin.

This is a separate asset from the item icon — it is the thing that
renders ON the character, not the thing that renders IN the inventory.

Rules:

- Same 16-bit pixel art style as the player paddle and the item icons.
- Pose-locked to the paddle / player rig — the asset is drawn in the
  pose it will be composited in, not a standalone portrait.
- Consistent outline thickness and palette with the player character.
- Include an attach-point note (head top / torso / arms / legs / back
  / accessory) in the hand-off — runtime needs this to place the
  overlay correctly.
- Include the **intended visual overlay slot** in the hand-off
  (`head`, `torso`, `belt`, `back`, `l_arm`, etc.). The gameplay
  body-part family and the runtime visual slot are NOT always the same.
- If the item belongs to a wearable family that commonly coexists with
  another visible family (for example `top + belt`), design the equip
  visual as an independent overlay, not as torso art that assumes the
  other family is absent.
- Belt-family visuals should read as a **waist / buckle overlay** and
  be hand-offed as a belt-layer asset, not silently merged into a vest
  or torso layer.
- When the overlay could plausibly collide with another visible family,
  name at least one coexistence QA pair in the hand-off (for example
  `technical_vest + timer_belt` or `bulkup + megingjord`).

Runtime hook is
`entities/body_parts/item_parts_registry.apply_item_to_skin()`
(see `docs/item_runtime_checklist.md`). This skill only owns the
asset; the wiring belongs in the runtime checklist.

Copy-paste prompt: `references/equip_visual_prompt.md`.

---

## 8. File naming & output paths

All item assets live under `items/`.

| Asset | Path | Notes |
|---|---|---|
| Active item icon | `items/[name].png` or `items/[name]_icon.png` | 32 × 32 px, transparent BG |
| Passive item icon | `items/[name].png` or `items/[name]_icon.png` | 32 × 32 px, transparent BG |
| Legendary item icon | `items/[name].png` or `items/[name]_icon.png` | 32 × 32 px, legendary frame stack baked in |
| Legendary animation frames (if any) | `items/[name]_frame_0.png` … `items/[name]_frame_7.png` | 8 frames, baked into PNGs |
| Equip visual (paddle-part) | `items/[name]_equip.png` or `entities/body_parts/[name].png` | Pose-locked overlay |
| Unknown-item placeholder | `items/unknown_item.png` | Already exists — do NOT overwrite |

**Do NOT overwrite `items/unknown_item.png`.** It is the fallback icon
for anything without a loaded texture. If a new item fails to load,
the HUD falls back to this asset.

**Do NOT generate an asset file named `empty_legendary*.png`.** See §6.2.

**Match the existing runtime loader key exactly.** If the repo already
expects `items/[name].png`, do not silently save `items/[name]_v2.png`
or another variant unless the runtime hand-off explicitly includes the
loader update.

---

## 9. QA checklist — reject or regenerate

Apply before accepting any item asset.

| # | Check | Reject if |
|---|---|---|
| 1 | Reads as the correct item at ~24 px HUD scale | silhouette blurs into a colored blob |
| 2 | Outline survives downscaling (1–2 px thick black) | outline breaks into dots or disappears |
| 3 | Palette matches theme band in §6.1 or §5 mood cues | hue drifts away from concept (e.g. fire item rendered cool gray) |
| 4 | Active icons read as props, not character parts | an active icon looks like an arm or head |
| 5 | Passive icons read as wearable gear | a passive icon looks like a bottle or bomb |
| 6 | Legendary icons have the full frame stack baked in | frame missing, corners missing, or frame drawn at runtime |
| 7 | No stray text / numerals / watermarks | any letters or numbers inside the canvas |
| 8 | Transparent background (non-legendary) | any off-white fringe, JPEG halo, or baked gray checkerboard transparency pattern |
| 9 | If legendary: 8 frames consistent, only frame-color animates | subject drifts between frames |
| 10 | If equip visual: pose-locked to player rig, outline matches paddle | freestanding portrait or different outline weight |
| 11 | No painterly rendering / anti-aliased blur | soft gradient or oil-paint feel |
| 12 | Runtime loader precedence sanity check for replacements | the repo still shows an old/procedural icon because a special-case branch returns before reading the new PNG |

If any check fails, regenerate — do not patch with post-processing.

Known failure pattern:

- The PNG exists on disk and passes art QA, but `items.py` or
  `pingfighter.py` has a special-case icon branch or cache that returns
  a procedural fallback before the file path is consulted. Treat this as
  a failed accept state until runtime precedence is verified.

---

## 10. Hand-off to runtime integration

Once an item asset passes QA, route the **runtime integration** to
`docs/item_runtime_checklist.md`. The runtime checklist is the single
source of truth for every code location that must be touched (items.py
registration, active / passive routing, shop / gacha / crane, dev
mode, reset, rolls, polish, enhancement, equip visual wiring).

Typical hand-off payload to include in the follow-up message:

- Asset type: active / passive / legendary / mythic / equip visual
- File path(s) written (see Section 8)
- For passive: which body-part slot it belongs to (`PASSIVE_SLOT_ORDER`
  family - head / top / arms / belt / knees / shoes / back / accessory)
- For equip visual: attach point (head top / torso / arms / back etc.)
  **and** intended visual overlay slot (`head`, `torso`, `belt`,
  `back`, `l_arm`, etc.)
- For legendary / mythic: roll-option concept, polish-perk applicability,
  enhancement-buff applicability, theme particle (from Section 6.3)
- If the user referenced a blank `empty_legendary*` cell, state the
  real item name that runtime should wire into the dev grid. Do not
  replace the placeholder strings themselves.
- Whether duplicates are allowed (affects `PASSIVE_DUPLICATE_ALLOWED`
  and `skip_append` rules - see runtime checklist)
- If the item can visually coexist with a neighboring wearable family,
  name at least one coexistence QA pair for runtime verification.
- For icon replacements or regenerations, explicitly require a runtime
  asset-precedence audit: verify that the written PNG wins over any
  procedural fallback / special-case loader branch and that relevant
  icon caches are refreshed for QA.

- If the item changes any HUD-visible cooldown / charge readout
  (especially player-skill cooldowns on the left 5-orb HUD), say so
  explicitly in the hand-off and require runtime to update the orb
  countdown text, cooldown wedge timing, and tooltip cooldown line to
  the **final effective value**, not only the underlying gameplay
  cooldown logic.

Do not attempt the runtime wiring from this skill. Point to the
checklist and stop.
