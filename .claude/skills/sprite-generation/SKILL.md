---
name: sprite-generation
description: |
  Boss/character sprite sheet creation pipeline for PingFighter. Covers walk,
  attack, dash, and turn (facing transition) sheets, character identity lock
  across sheets, body scale lock (+/-5%), color palette drift prevention,
  Gemini MCP prompt engineering, content-filter bypass vocabulary, background
  removal (nukki) via a 2-step hard-edge algorithm on JPEG to PNG, file
  naming and output paths, reject/regenerate QA checklists, and hand-off to
  Codex for runtime integration (AGENTS.md). Use this skill whenever the
  user asks to create, regenerate, reshoot, redraw, or fix a boss sprite
  sheet, walking sheet, attack sheet, dash sheet, turn sheet, or item icon,
  or to run background removal / nukki on a generated PNG or JPEG. 한국어
  트리거 키워드 - 스프라이트, 보스 시트, 걷기 시트, 공격 시트, 대쉬 시트, 턴 시트, 누끼,
  재생성, 스프라이트 시트, 보스 이미지, 배경 제거.
---

# Sprite Generation Pipeline (PingFighter)

Asset-generation plays for boss and character sprite sheets. Runtime
integration is NOT covered here -- hand off to Codex using `AGENTS.md`
after sheet acceptance. The runtime side lives in `AGENTS.md` and should
not be duplicated into this skill.

Companion files in this skill directory:

- `remove_bg.py` -- runnable CLI nukki script (`py remove_bg.py <src.jpeg> <dst.png>`)
- `prompts/walk.md` / `attack.md` / `dash.md` / `turn.md` -- copy-paste prompt templates
- `prompts/handoff_codex.md` -- final Codex integration request
- `checklists.md` -- reject/regenerate QA tables
- `examples.md` -- canonical references (Tauren / Menhera / Honglyeon)
- `references.md` -- links back to CLAUDE.md invariants and AGENTS.md

---

## 1. When to use this skill

Trigger on any of these user intents:

- Create a new boss/character sprite sheet (walk/attack/dash/turn/icon)
- Regenerate or re-shoot an existing sheet (identity drift, scale drift, bad frames)
- Run background removal / nukki on a generated JPEG into PNG
- Reuse a Gemini MCP prompt template for a different boss
- Debug why a generated sheet looks wrong (palette drift, oversized body, painterly rendering)

If the user is working on `pingfighter.py` loader, render loop, or runtime
scaling, that is AGENTS.md territory -- do NOT drive it from this skill.

---

## 2. Role split -- Claude vs Codex

- **Claude (this skill):** prompt design, sheet layout, style calls, content-filter wording, nukki pipeline, output file naming, reject/regenerate judgment, canonical-reference continuity. Also authors the standalone `entities/[name]_boss_sprite.py` scaffold when creating a new sprite class.
- **Codex (AGENTS.md):** `pingfighter.py` import/init/reset wiring, stage render branch, loader caching, runtime scaling, per-frame hot-path performance, turn-vs-walk priority in update logic.

Claude writes the sheets and the sprite class skeleton; Codex welds the sprite class into the game loop.

---

## 3. Style unification (do not drift)

All existing bosses (`boss_stage1` through the latest stage) share a single
look: 16-bit retro pixel art, chibi proportions, thick black pixel outlines,
flat limited-saturation palette. Warcraft painterly, anime illustration,
and photoreal are all forbidden.

Required English phrasing inside every prompt:

```
16-bit retro pixel art, chibi proportions, thick black pixel outlines,
flat limited-saturation palette, clean hard-edged pixels,
NO painterly rendering, NO soft shading, NO photorealism
```

Style knobs:

| Aspect | Required |
|---|---|
| Art style | 16-bit pixel art, SNES / Stardew / Pokemon feel |
| Proportions | Chibi / super-deformed -- head ~40-50% of total height |
| Outline | Thick black pixel outline |
| Color | Flat, limited-saturation, hard-edged |
| Forbidden | Painterly shading, soft gradients, photoreal, anti-aliased blur |

### 3.1. Readability at gameplay scale (first-generation requirement)

Readability at small in-game size is **mandatory from the first
generation**, not a later polish pass. Sheets that read well only at
source-size (2K) and blur out at gameplay size must be regenerated, not
patched after the fact. Treat "downscale survivability" as a core
acceptance criterion, same level as identity lock and scale lock.

Every sheet prompt must ask the first generation to already deliver:

- Clear eye contrast (iris and upper lash line readable at small scale)
- Clear bangs / forehead / cheek boundary (hair does not blend into face)
- Slightly defined eyebrows and mouth so expression survives downscaling
- Clear glove / arm / torso separation so limbs do not merge with the body
- Clean light / mid / dark separation -- no muddy midtones
- Pastel softness and identity preserved while improving legibility

Legibility must come from shape and value separation inside the
canonical soft pastel / 16-bit style. Increasing saturation, hardening
outlines into anime-edgy lines, or introducing painterly contrast to
force legibility are all out of bounds.

Required prompt fragment (include verbatim or close-to-verbatim in every
sheet prompt, whether walk / attack / dash / turn):

```
Gameplay-scale readability is mandatory from the first generation.
The face, eyes, bangs, mouth, gloves, arms, and silhouette must remain
readable at small in-game size. Reduce muddy midtones. Preserve clear
separation between hair, face, arms, and torso. Keep identity and
pastel softness, but do NOT treat readability as an optional later
polish pass -- build it in during this first generation.
```

If a generated sheet fails this at gameplay scale, reject and regenerate
rather than scheduling a separate "polish" pass.

Frontal face readability also drives the walk design choice in Section
7.1 (front-biased walk): for PingFighter ping-pong framing, human /
chibi bosses keep the face mostly readable from the front during walk
cycles, not turned to the side.

---

## 4. Character size & scale inside each cell

A chibi character that fills the whole cell will look oversized in-game
compared to other bosses. Target 45-55% cell-height fill with generous
empty margin.

Required prompt fragment:

```
Each character fills only about 45-55% of each cell's height.
Keep the character SMALL and COMPACT -- do NOT fill the cell.
Leave generous empty white/transparent margin around each sprite.
This is a small chibi boss sprite, NOT a full-body portrait.
```

Do NOT mix weapon wording ("paddle-wielding", etc.) into this block. Weapon
identity belongs in Section 6.

### 4.1. Baseline size reference -- petite human / chibi bosses

The current Stage 3 Menhera in-game body class, after her latest +10%
upscale, is the preferred baseline reference for petite human /
chibi-proportion bosses. When designing a new human-shaped chibi boss
without a specific oversize / undersize design concept, aim so the final
in-game rendering lands in roughly that silhouette class.

This is a **baseline reference, not a universal hard rule.** Explicitly
out of scope:

| Out of scope | Why |
|---|---|
| Large-frame bosses (e.g. Tauren) | Bigger body class is correct on purpose |
| Tall vertical-silhouette bosses (e.g. Honglyeon) | Taller silhouette is correct on purpose |
| Deliberate oversized / undersized concept bosses | Design-led sizing wins |

Use this baseline to avoid accidental drift where similar-silhouette
human / chibi bosses end up visibly smaller or larger than Menhera for
no design reason. Do NOT hard-code it as an absolute pixel rule inside
prompts; describe it as the default target class.

Runtime-side guardrails for this same idea live in `AGENTS.md` (Boss
Sprite Workflow).

---

## 5. Facial expression -- fierce, not cute

Default Gemini output trends cute. Force a stronger face with:

- `fierce and cool, NOT cute`
- `serious / determined / intense expression`
- `narrow focused eyes with glowing white pupils`
- `furrowed brow`
- `slight frown showing tusks/fangs` (when species appropriate)
- `tribal markings or battle scars on face` (when appropriate)

Filter-safe vocabulary only -- see Section 12 for words that trip 400
INVALID_ARGUMENT on Gemini.

---

## 6. Weapon & identity

Weapons must be specified concretely per boss. Generic defaults will
produce generic weapons.

Examples:

- Ping-pong arcade boss: `holding a red ping-pong paddle in his right hand`
- Giant totem boss: `holds a MASSIVE tribal totem pole diagonally across body in both hands -- giant wooden staff taller than himself, carved with ancestral faces and runes, decorated with red and yellow feathers and bone charms, leather wraps around grip`
- Remove unwanted props: `NO ping-pong paddle anywhere`, `NO [unwanted item]`

If the weapon moves hand across frames, the animation reads wrong. Pin it:

```
weapon stays in same hand position across all frames
```

---

## 7. Sheet composition -- 8-frame 4x2

| Purpose | Grid | aspectRatio | Frames | Frame plan |
|---|---|---|---|---|
| Walk cycle | 4x2 | 16:9 | 8 | r1: left-foot contact, left-foot high, passing, right-foot contact / r2: right-foot high, passing, left-foot variant, loop transition |
| Attack | 4x2 | 16:9 | 8 | r1: ready, wind-up, backswing, max charge / r2: swing start, impact + motion line, follow-through, recovery |
| Dash / slide | 4x2 | 16:9 | 8 | r1: crouch prep, push-off, low slide, full extension + trail / r2: sustained slide + particles, deceleration, recovery rise, standing return |
| Item icon | single | 1:1 | 1 | centered, 32 or 64 px |

Required per-cell discipline (include verbatim in prompt):

```
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels between cells
- Each cell exactly equal size, character centered
- Character view is exactly front-facing in every frame
- Identical character design/palette/scale across all frames
- Keep foot/baseline position consistent across frames
```

### 7.1. Front-biased walk for human / chibi bosses (PingFighter default)

For PingFighter boss gameplay, human / chibi bosses should usually keep
a **front-biased walk** rather than a full side-facing walk. This is the
default baseline, confirmed via the Stage 3 Menhera walk iteration.

Why: the boss fight is framed like ping-pong, not a side-scroller. The
player reads the boss as "the thing across the table facing me," and the
boss should continue to feel like it is facing the player and the ball
even while moving laterally. Full side-facing locomotion breaks that
combat framing and costs frontal face readability at gameplay scale
(ties back to Section 3.1).

Rules:

- Body and face stay mostly front-facing across all 8 walk frames.
- Lateral movement is expressed through **legs, arm swing, hair, ribbons,
  cloth, tail, and accessory motion** -- not by turning the torso to the
  side.
- A subtle shoulder / pelvis counter-swing and small torso lean is fine,
  but the face should remain mostly readable from the front in every
  frame.
- The character should still look like it is facing the player / ball,
  not walking across the screen.

Not a hard ban:

- Full side-facing walk is **optional and special-case**, not the
  default. Only use it when a specific design beat needs it (a cinematic
  crossing, a non-combat intro, a specific boss whose identity demands
  profile locomotion).
- When in doubt, prefer the front-biased walk.

Relation to turn / angled walk sheets:

- Turn sheets (Section 9) remain the approved tool for **brief** left/
  right facing transitions on top of the front-biased walk.
- Angled walk sheets are treated as experimental only (see Appendix A).

Required prompt fragment for human / chibi boss walk sheets:

```
Front-biased walk: body and face stay mostly front-facing across all
frames. Express lateral movement through legs, arm swing, hair, ribbons,
cloth, tail, and accessories -- NOT by turning the torso to the side.
Preserve frontal combat readability: the boss should still look like it
is facing the player and the ball in every frame, even while moving
laterally. Full side-facing walk is NOT the default for PingFighter
bosses.
```

---

## 8. Cross-sheet consistency (the most important chapter)

Walk / attack / dash / turn for the same boss must read as the same
character at the same size. Three locks enforce this.

### 8.1. Body scale lock (+/-5%)

- Walking sheet is the body-scale reference.
- Attack and dash sheets must keep head / torso / pelvis within +/-5%.
- Express speed with pose, lean, limb compression, hair/cloth trail, and
  motion lines. NEVER by shrinking or enlarging the body.
- Effects (dust, flame, trail) may extend past cell edges; the body does not.

Prompt fragment:

```
The character's HEAD, TORSO, and PELVIS must be the SAME SIZE as the walking sheet.
Do NOT shrink the body to show speed -- use pose, lean, and motion lines instead.
Effects (dust, flames, trails) may extend outward, but the body itself stays the same scale.
```

### 8.2. Character identity lock

`items/[name]_boss_sheet.png` (the walking sheet) is the canonical identity
reference. All later sheets must preserve every item on this list:

| Fixed element (never change) | Example |
|---|---|
| Hair color | pink stays pink (no magenta drift) |
| Hairstyle / silhouette | curly wave stays curly wave |
| Face shape / impression | chibi round stays chibi round |
| Eye color / shape | olive large eyes stay olive large eyes |
| Skin tone | bright stays bright |
| Body proportions | 2-head chibi stays 2-head chibi |
| Outfit design / silhouette / trim | pink nurse uniform with black trim stays same |
| Species / signature accessories | cat tail, cat-paw gloves, nurse cap ribbon stay |

Allowed to change (dynamism only): pose, tilt, motion lines, particle/flame
effects, cloth/hair swing, trails.

Prompt fragment (replace `[name]`):

```
Use items/[name]_boss_sheet.png as the canonical visual reference for identity, palette, and design continuity.
This character MUST look like the EXACT SAME person as in the walking sheet.
Do NOT redesign, reinterpret, or modernize the character.
Keep the SAME hair color, hairstyle, face shape, eye color, skin tone, outfit design, and all signature accessories.
If the result looks like a different character, it must be rejected and regenerated.
```

### 8.3. Color palette drift prevention

Forbidden drift patterns:

| Forbidden drift | Reason |
|---|---|
| pink hair -> magenta hair | saturation/hue shift |
| pastel tone -> saturated tone | tone shift |
| cute round face -> sharp mature face | impression shift |
| chibi 2-head -> semi-realistic 3-head | proportion shift |
| thick outlines -> thin outlines | style shift |

If any of these show up in the output, reject and regenerate. Do not "fix"
with code/post-processing.

---

## 9. Turn / facing-transition sheet (optional aux sheet)

A turn sheet is **not** a replacement for the walking cycle. It is a
13-frame 7x2 aux sheet that plays only during a brief left<->right facing
change, then returns to the main walking sheet. Runtime priority is
`dash > attack > turn-transition > walk > idle` (see AGENTS.md).

### 9.1. Purpose

- left -> right direction change
- right -> left direction change
- idle return to front-facing from a turned stance

Normal locomotion keeps using the main walking sheet.

### 9.2. Canonical reference

Same rules as 8.2 -- walking sheet is the identity anchor. All eight fixed
elements (hair color, hairstyle, face, eyes, skin tone, proportions,
outfit, accessories) must stay. Only body orientation, gaze, shoulder/
pelvis angle, and limb overlap may change.

"Simple image rotation" is not acceptable. Each angle must be a fresh
redraw at that angle.

### 9.3. Recommended layout

| Field | Value |
|---|---|
| Frames | 13 (7x2 grid, last cell blank) |
| Row 1 | +90, +75, +60, +45, +30, +15, 0 |
| Row 2 | -15, -30, -45, -60, -75, -90, (blank) |
| Sign convention | +90 = full right profile, 0 = front, -90 = full left profile |
| aspectRatio | 16:9 |
| imageSize | 2K |
| Background | pure white #FFFFFF, no grid/border/divider/label |
| Body scale | within +/-5% of walking sheet |

### 9.4. Neighboring-frame interpolation

Adjacent angle frames must read as a smooth 15-degree step. If a frame
pops, the runtime transition will flicker.

### 9.5. File placement

- Raw: `items/[name]_boss_turn.jpeg`
- Nukki: `items/[name]_boss_turn.png`

### 9.6. Turn sheet QA checklist

| # | Check | Pass |
|---|---|---|
| 1 | Same character as walking sheet | yes |
| 2 | All fixed elements preserved | yes |
| 3 | Adjacent angles interpolate smoothly | yes |
| 4 | Only orientation / overlap / gaze change | yes |
| 5 | Reads as fresh redraw per angle, not rotation filter | yes |
| 6 | Body scale within +/-5% of walking sheet | yes |

If the turn sheet reads as a different character, reject and regenerate.

---

## 10. Resolution & aspect

| Parameter | Recommended | Notes |
|---|---|---|
| `aspectRatio` | `16:9` for 4x2, `1:1` for single/2x2 | 4:1 not directly supported |
| `imageSize` | `2K` | 4K nukki is slow, 1K loses detail |
| `style` | `"16-bit retro pixel art, chibi, flat colors, thick outlines"` | required |

---

## 11. Background removal (nukki)

Gemini JPEG outputs carry compression halos around edges. A simple white
colorkey will leave a visible rim. Use the offline 2-step hard-edge
algorithm packaged as `remove_bg.py` in this skill directory.

### 11.1. CLI usage

```
py remove_bg.py <src.jpeg> <dst.png>
```

Example:

```
py .claude/skills/sprite-generation/remove_bg.py items/mynewboss_boss_sheet.jpeg items/mynewboss_boss_sheet.png
```

### 11.2. What the algorithm does (why, not how)

1. **Border flood-fill.** Every edge pixel that is both bright (`lum >= 200`) and near-gray (`sat <= 30`) is a seed. Flood-fill inward while staying in the whitish range. Result = confirmed background mask.
2. **2-ring hard halo kill.** Pixels within 1-2 px of the background mask that are still bright (`lum >= 150`) and near-gray (`sat <= 40`) are halo and get alpha 0.
3. **Mild halo sweep.** One more ring at `lum >= 180` and `sat <= 60` to catch slightly-colored fringe.

Why hard-kill instead of alpha feathering: pixel art requires crisp
outlines; feathering blurs the silhouette.

Why this preserves interior highlights: bright spots like horns or gold
trim are not reachable by flood-fill from the border, so they stay opaque
automatically.

### 11.3. Commit policy

Commit BOTH `[name]_boss_*.jpeg` (raw Gemini output) and
`[name]_boss_*.png` (post-nukki) so the algorithm can be rerun with
tuned thresholds if needed.

### 11.4. Runtime-side fallback

The runtime loader has a simple JPEG colorkey as a safety net, NOT a
replacement for this offline algorithm. The source of truth is the
offline PNG. See AGENTS.md for the runtime fallback rules.

---

## 12. Gemini content-filter bypass vocabulary

400 INVALID_ARGUMENT from Gemini image generation usually means a word
tripped the filter. Verified replacements:

| Blocked (caused 400) | Replace with |
|---|---|
| `battle`, `weapon` | `champion`, `guardian`, `wielding [concrete tool name]` |
| `angry`, `scarred` | `serious`, `determined`, `focused`, `fierce` |
| `skull`, `blood`, `gore` | `stylized animal head`, `ceremonial`, `tribal` |
| `intimidating`, `threatening` | `imposing`, `heroic`, `cool` |

`fierce` and `warrior` are filter-safe on their own (production-verified).
If a filter error has no obvious cause, shorten the prompt or split the
sheet into two generations and manually merge.

---

## 13. File placement convention

| File | Path | Example |
|---|---|---|
| Walk sheet (raw) | `items/[name]_boss_sheet.jpeg` | `items/tauren_boss_sheet.jpeg` |
| Walk sheet (nukki) | `items/[name]_boss_sheet.png` | `items/tauren_boss_sheet.png` |
| Attack sheet | `items/[name]_boss_attack.{jpeg,png}` | `items/tauren_boss_attack.png` |
| Dash sheet | `items/[name]_boss_dash.{jpeg,png}` | `items/honglyeon_boss_dash.png` |
| Turn sheet (optional) | `items/[name]_boss_turn.{jpeg,png}` | `items/menhera_boss_turn.png` |
| Background image | `backgrounds/stage[N]_*.jpeg` | `backgrounds/stage9_pillar_left.jpeg` |
| Sprite class | `entities/[name]_boss_sprite.py` | `entities/tauren_boss_sprite.py` |

Keep BOTH jpeg and png -- see Section 11.3.

---

## 14. Prompt templates

See `prompts/` in this skill directory. Each template has `[name]`,
`[boss name]`, and stage number placeholders.

| Task | Template |
|---|---|
| Walk sheet | `prompts/walk.md` |
| Attack sheet | `prompts/attack.md` |
| Dash sheet | `prompts/dash.md` |
| Turn sheet | `prompts/turn.md` |
| Codex hand-off | `prompts/handoff_codex.md` |

Every sheet template must include the Section 3.1 readability fragment
at first generation, and petite human / chibi bosses should lean on the
Section 4.1 baseline size reference rather than reinventing size targets
per boss.

Stage mapping reminder: code `current_stage == 5` is Stage 6 Honglyeon,
code `current_stage == 6` is Stage 5 Nemesis. Always state both the real
stage number and the code stage number in the prompt when they might
disagree. Full mapping lives in `CLAUDE.md`.

---

## 15. QA checklists & reject/regenerate

See `checklists.md` in this skill directory for the full tables
(identity lock, scale lock, palette drift, turn sheet).

Global rule: if any fixed element (Section 8.2) drifts, reject and
regenerate. Do not paper over with post-processing.

---

## 16. Hand-off to Codex after sheet acceptance

Once a sheet passes QA and nukki is committed, use
`prompts/handoff_codex.md` to request Codex integration per AGENTS.md.
Typical payload: list of new assets, expected sprite class name, notes on
body-scale reference, any dash/attack/turn priority nuances.

---

## Appendix A. Angled walk / full side-facing walk -- interesting experiment, not preferred default

Angled walk sheets (multiple facing directions inside the walking cycle)
and full side-facing walk sheets are treated as **interesting experiments,
not the preferred default** for PingFighter human / chibi bosses.

Background: the Stage 3 Menhera iteration showed that front-biased walk
reads better in the ping-pong boss framing than a natural side-scroller
style full side-facing walk. Frontal combat readability and "the boss is
facing me / the ball" feel matter more here than realistic locomotion.
That finding was promoted into the Section 7.1 default.

Therefore:

- Front-biased walk (Section 7.1) is the approved default for human /
  chibi bosses.
- Full side-facing walk is optional and special-case only.
- Angled walk sheets (multi-direction walking cycle) remain experimental.
  Do NOT promote angled walk to standard.
- Do NOT treat angled walk as a replacement for the turn sheet pattern
  in Section 9.
- Document outcomes in `examples.md` when an angled-walk experiment is
  attempted.

The normal approved design is: one front-biased main walking sheet per
boss, an optional turn aux sheet for brief facing transitions, and
angled / full side-facing walk only when a specific design beat justifies
stepping outside the default.
