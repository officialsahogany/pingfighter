---
name: sprite-generation
description: |
  Boss/character sprite sheet creation pipeline for PingFighter. Covers walk,
  attack, dash, and turn (facing transition) sheets, character identity lock
  across sheets, body scale lock (+/-5%), color palette drift prevention,
  Gemini MCP / FLUX Kontext / AutoSprite prompt-and-reference workflows,
  content-filter bypass vocabulary, background removal (nukki) via a 2-step
  hard-edge algorithm on JPEG to PNG, file naming and output paths,
  reject/regenerate QA checklists, and hand-off to Codex for runtime
  integration (AGENTS.md). Use this skill whenever the
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
- Reuse or adapt a Gemini MCP / FLUX Kontext / AutoSprite prompt or
  reference workflow for a different boss
- Debug why a generated sheet looks wrong (palette drift, oversized body, painterly rendering)

If the user is working on `pingfighter.py` loader, render loop, or runtime
scaling, that is AGENTS.md territory -- do NOT drive it from this skill.

---

## 2. Role split -- Claude vs Codex

- **Claude (this skill):** prompt design, sheet layout, style calls, content-filter wording, nukki pipeline, output file naming, reject/regenerate judgment, canonical-reference continuity. Also authors the standalone `entities/[name]_boss_sprite.py` scaffold when creating a new sprite class.
- **Codex (AGENTS.md):** `pingfighter.py` import/init/reset wiring, stage render branch, loader caching, runtime scaling, per-frame hot-path performance, turn-vs-walk priority in update logic.

Claude writes the sheets and the sprite class skeleton; Codex welds the sprite class into the game loop.

Claude also owns the asset-side performance handoff note: when a motion set
is accepted, explicitly tell Codex how many sheets are new, what their
source resolution is, and whether a runtime-ready export should be
considered because the combined load cost or transparent effect area is
large.

### 2.1. Tool routing inside this skill

These tools are not interchangeable by default. Route deliberately:

- **FLUX Kontext**: preferred for reference-conditioned image-to-image work
  such as peak-pose correction, narrow prop touch-ups, and frame-expansion
  passes after a strong anchor already exists.
- **Gemini MCP**: known-good path for fresh full-sheet generation and for
  cases where FLUX or AutoSprite drift on pixel class, clarity class, or
  identity lock.
- **AutoSprite**: motion ideation, pose blocking, and structural probes.
  Do NOT promote AutoSprite output to final renderer status unless it
  independently passes the same pixel / identity / clarity QA as the rest
  of the set.
- **AutoSprite + FLUX best practice**: use AutoSprite to find motion /
  peak acting, then pass the strongest single pose into FLUX to lock a
  canonical peak anchor, then expand the remaining frames in FLUX.
  Do NOT assume `AutoSprite full-sheet -> FLUX full-sheet` will keep the
  same acting intensity.
- **Legacy motion-master caution**: if an old victory or other legacy
  sheet starts leaking obsolete design branches into FLUX, remove it from
  the generation stack and use it only as QA comparison, not as an input
  motion master.

Current repo-specific note:
- **Stage 3 Menhera turn branch** currently uses FLUX Kontext as the
  preferred renderer candidate, AutoSprite as motion ideation only, and
  Gemini MCP as the alternate known-good route.
- **Stage 3 Menhera victory branch** now treats AutoSprite as victory
  motion-block / peak-pose discovery only, then uses FLUX to lock the
  canonical peak and expand the rest of the sheet. Direct FLUX
  full-sheet passes were either too flat, or leaked legacy identity when
  old victory art was used as a strong reference.

### 2.2. Workflow mode switch (`fast` vs `precise`)

Before planning a new sprite branch, read:

- `d:\main\bosspong\.claude\sprite_workflow_settings.json`

Default:
- `spriteWorkflowMode = "fast"`

Interpretation:
- **fast** = exploration mode. Prefer 1-2 quick generations, visual taste
  checks, and immediate rejection of weak branches. Do not sink time into
  pair expansion, publish-pack, nukki restitch, or runtime wire-up unless
  the candidate already looks strong.
- **precise** = promotion mode. Use full strip QA, frame expansion,
  publish staging, nukki, and runtime handoff when the user explicitly
  wants depth or when the branch already looks close to ship.

Rule:
- If the user does not explicitly request depth, default to `fast`.
- If a branch has already proven itself and the user wants to ship it,
  switch to `precise`.

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

Stable-movement direction neutrality is part of that readability rule:
a "front-biased" walk fails if, in motion, the boss reads as persistently
looking left or persistently looking right because of asymmetric hair
mass, ribbon placement, cheek exposure, eye placement, hat tilt, or
torso / shoulder angle. That is not a successful front-biased walk -- it
is a side-biased walk wearing frontal vocabulary.

### 3.1.1. Cross-sheet clarity consistency

Gameplay readability is not judged per sheet in isolation. A motion set
fails QA if one accepted sheet reads obviously cleaner, crisper, pinker,
or more face-readable than the others at gameplay size. In practice,
victory sheets often expose this failure mode: the celebration sheet can
look sharp and lively while walk / attack / dash / turn look softer,
washed out, or muddier.

Acceptance rule:

- Match the same **clarity class** across walk / attack / dash / turn /
  victory, not just the same identity and scale.
- If one sheet has clearly stronger face readability, cleaner outline
  read, cleaner black trim, or better light / mid / dark separation,
  regenerate the weaker sheets to that level.
- Do NOT "solve" this by over-saturating the weak sheets or by turning
  them into harsh anime contrast. Keep the pastel / 16-bit look, but
  keep the readability tier consistent across the whole set.

Required prompt fragment:

```
Cross-sheet clarity must stay consistent across walk, attack, dash,
turn, and victory. Do NOT accept a mixed set where one sheet looks
obviously cleaner, sharper, pinker, or more readable than the others at
gameplay size. Match the same readability tier across the full motion
set while preserving the same pastel identity.
```

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

### 7.1.1. Perceptual frontal neutrality -- required for acceptance

A front-biased walk must not only be "not full-profile"; it must also
remain **perceptually neutral** during stable movement. In-game, the
boss should read as "facing me while moving laterally," not as "secretly
looking left" or "secretly looking right."

Reject the walk sheet if any of the following happen during stable walk
playback:

- One eye is consistently much more exposed than the other in a way that
  reads as a 3/4 face rather than a frontal face.
- Hair mass or ribbon placement keeps the head visually pulled toward a
  side-facing read.
- Shoulder / torso angle makes the body feel turned to one side instead
  of facing the player.
- In gameplay-size playback, moving right makes the boss feel like it is
  looking left, or moving left makes it feel like it is looking right.
- The new walk is visibly more side-facing than the previous accepted
  walk even if the new one is more lively.

Required prompt fragment:

```
This is a FRONT-FACING walk, not a 3/4 walk. The boss must keep reading
as facing the player during stable movement. Do NOT let hair mass,
ribbon placement, eye placement, cheek exposure, hat tilt, shoulder
angle, or torso angle create a persistent left-looking or right-looking
bias. Both left-travel and right-travel gameplay should still read as a
forward-facing boss moving laterally.
```

### 7.1.2. Canonical walk promotion gate

When regenerating an already-accepted walk sheet, the new file does NOT
automatically become the new canonical just because it has better energy
or a more polished source render.

Promotion gate:

- Keep the previous accepted walk sheet as the rollback reference until
  the candidate passes gameplay-scale QA.
- Compare the candidate directly against the previous accepted walk, not
  just in isolation.
- If the candidate improves animation energy but regresses frontal read,
  reject it and keep the older canonical walk.
- Do NOT hand off a side-biased candidate to Codex as an accepted walk
  with the expectation that runtime facing logic will rescue it.
- If the user wants "walk stays frontal, turn gets a hop," it is valid
  to preserve the frontal walk and let Codex use a hop-only runtime turn
  accent rather than forcing visible turn-sheet playback.

### 7.1.3. Front-facing but lively -- limb-wiggle-only is forbidden

Front-biased / front-facing does NOT mean "torso nailed to the spot with
only the feet shuffling." Limb-wiggle-only walk cycles read as stiff and
mechanical at gameplay scale and were the primary failure mode in early
Honglyeon iterations. The rule is "strict frontal lock + lively
whole-body rhythm" -- frontal framing is preserved, but the body is
clearly alive.

Life must come from a combination of the following, not just legs and
arms:

| Rhythm channel | What it contributes |
|---|---|
| Body bob | Vertical head / torso rise and fall per step |
| Weight shift | Pelvis shifts laterally onto the grounded leg |
| Hip sway | Pelvis rotates subtly opposite the shoulders |
| Shoulder counter-sway | Small twist against the hips |
| Hair sway | Side hair and ponytail follow body motion with slight lag |
| Ribbon / accessory motion | Ribbons, sashes, charms, tails trail the body rhythm |
| Cloth / hem flutter | Skirt hem, robe hem, sleeves flutter with each step |
| Flame / aura / effect motion | Ambient effects (flame, sparks, glow) breathe with the step |

A walk cycle that only moves the arms and legs, leaving hair / cloth /
body completely static, must be rejected and regenerated -- not patched
with runtime tweaks.

Lateral travel must still feel alive when the boss moves left or right
in-game. If the cycle preserves frontal lock but reads like the torso is
nailed in place while only feet / paws shuffle underneath, it has
failed the walk brief and must be regenerated.

Walk-sheet hard gate before any publish / Codex handoff:

- Inspect the direct `f1..f8` strip side by side, not only a stitched
  preview, gameplay-scale mockup, or runtime loop.
- If the eight accepted frames still read like near-identical static
  posing with only tiny limb offsets, reject the sheet even if identity,
  style, and sequence-level "walk vibe" seem acceptable.
- `F1↔F5` mirror success alone is not enough. The intermediate slots must
  also separate clearly enough that the sheet does not collapse into
  "same teddy / same girl / same boss repeated eight times."
- For plush or chibi bosses, "soft waddling" is allowed; "barely changed
  idle gallery" is not.

Required prompt fragment for human / chibi boss walk sheets:

```
Front-biased walk: body and face stay mostly front-facing across all
frames. Express lateral movement through legs, arm swing, hair, ribbons,
cloth, tail, and accessories -- NOT by turning the torso to the side.
Preserve frontal combat readability: the boss should still look like it
is facing the player and the ball in every frame, even while moving
laterally. Full side-facing walk is NOT the default for PingFighter
bosses.

Front-facing but lively: do NOT restrict motion to limb wiggle only.
Express life through body bob, weight shift, hip / shoulder sway, hair
sway, ribbon motion, cloth / hem flutter, and any flame / aura / effect
motion the character carries. A stiff "only legs and arms move" walk is
NOT acceptable. Left / right travel must still feel alive at gameplay
size -- not like the torso is frozen while only the limbs cycle.
```

### 7.2. Silhouette continuity -- no hair-shoulder gap

The head -> hair -> shoulder -> torso chain must read as one closed,
continuous silhouette. This was a Honglyeon-specific failure mode: on
the walk sheet, background showed through the gap between the side hair
and the shoulder / upper torso, and the nukki pipeline could not fix it
because the transparent gap existed in the original drawing, not just
in the background. Silhouette continuity is a **generation-time**
requirement, not a nukki post-processing problem.

Rules:

- No visible transparent gap between side hair and shoulders / upper
  torso in any gameplay-facing frame (walk / attack / dash / turn).
- The overall silhouette must read as a closed shape at gameplay scale.
- If the hairstyle naturally falls behind the shoulders, include a rear
  hair layer so the shoulder silhouette connects cleanly to the torso.
- Background must not show through hair / shoulder / neck gaps on any
  sheet intended for runtime use.

Required prompt fragment (include verbatim or close-to-verbatim in
walk / attack / dash / turn prompts for any character whose hair falls
around the shoulders):

```
Silhouette continuity: the head, hair, shoulders, and upper torso must
read as one closed continuous shape. Do NOT leave any transparent gap
between side hair and shoulders / upper torso -- background must not
show through. If needed, include a rear hair layer behind the shoulders
so the silhouette connects cleanly. This applies to every frame of the
sheet at gameplay scale.
```

If a generated sheet shows a hair-shoulder gap on any frame, reject and
regenerate. Do NOT try to close the gap via nukki tuning or runtime
masking -- the drawing itself is wrong.

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

#### 8.1.1. Judge by visible body read, not only canvas / frame size

"Same scale" means the body and face must read the same size in-game,
not just "the cell dimensions are equal." Honglyeon's attack and dash
sheets passed raw-canvas scale checks but still felt visibly smaller
because flame / trail effects pushed outward and visually compressed the
body read. A sheet that is technically the same frame size but reads
smaller in gameplay has failed the scale lock, even if a ruler says it
is fine.

Rules for QA:

- Judge cross-sheet consistency by comparing the **visible body read**
  (head height, face size, torso silhouette) at gameplay scale, not by
  comparing cell / canvas dimensions.
- Attack / dash effects may expand outward, but they must not cause the
  character's body or face to read smaller than the walk baseline.
- Effect trails, flame halos, and motion lines are allowed to push
  outside the body silhouette; they are NOT allowed to force the body
  inward.
- If an action sheet makes the face / body feel smaller in-game, reject
  the sheet or schedule a runtime correction (AGENTS.md owns the
  runtime side of this rule).

Prompt reinforcement (add to attack / dash prompts in addition to 8.1):

```
Keep the VISIBLE BODY READ the same as on the walking sheet.
Flame, dust, trails, motion lines, and impact effects may extend
outward, but they must NOT visually compress the body. The character's
head, face, and torso must read the SAME SIZE in-game as they do on the
walking sheet -- equal canvas size alone is not enough.
```

### 8.4. Projectile-cast animation alignment

For bosses that launch projectiles (Honglyeon's fire bolts, for
example), each actual projectile launch should coincide with a matching
attack / cast animation. A boss who stands idle while fireballs come
out of them reads as broken, even if the walking / attack sheets
themselves are fine.

Generation-side rules:

- Projectile-casting bosses must have an attack / cast sheet whose
  motion clearly reads as "this is the frame that throws the projectile"
  (wind-up -> release -> follow-through).
- The release frame should be visually unambiguous so runtime can pair
  it with the actual projectile spawn.
- Dedicated cast sheets are allowed when the attack sheet is a melee
  swing and the cast motion is a different pose.

The runtime side of this rule -- wiring projectile launch events to the
matching animation trigger -- lives in `AGENTS.md` (Stage Integration
Checklist). The skill only guarantees that the sheets support it.

### 8.4.1. Anticipatory contact-hit alignment (default for strike sheets)

For most non-projectile attack sheets that are meant to connect with the
ball or with an on-table hit moment, the default runtime assumption is
**anticipatory / pre-contact triggering**, not "start the animation only
when the ball already hit."

Why: if a sheet has readable prep before impact and runtime starts it
only at the exact contact frame, the strongest strike pose often appears
a beat late and the early frames are never seen. The correct default is
to start slightly before predicted contact so the player sees the coil /
intent and the impact frame lands at or near the actual hit.

Important nuance from the Menhera iteration: the desired result is a
SHORT, conservative pre-contact window. The purpose is to expose a
little prep before contact, not to start the whole attack so early that
the downswing visibly happens in empty air before the ball arrives.

Generation-side rules:

- Contact-based strike sheets should have a clear `prep -> impact ->
  recovery` arc.
- Early prep frames must show meaningful compression / coil / intent,
  not dead-air posing.
- The main impact frame should be visually unambiguous so runtime can
  align it with actual contact and optionally hold it briefly.
- The prep arc should be compact enough that runtime can usually trigger
  it only a little before contact. If the readable hit requires a very
  early trigger, the sheet is too slow and should be regenerated tighter.
- If the sheet is intended to feel like a near-instant snap hit with
  almost no prep, that must be explicitly stated in the prompt.
- When handing accepted sheets to Codex, note the intended impact frame
  if one frame is clearly the hit moment, and note if the sheet wants a
  narrow / conservative lead window.

Prompt fragment:

```
Default runtime assumption: this attack will usually be triggered
slightly BEFORE predicted ball contact, not only on the exact hit frame.
Therefore the sheet must have a clear prep -> impact -> recovery arc.
Early frames must show meaningful tension / coil, and the strongest hit
frame must be visually unambiguous so runtime can align it to contact.
Do NOT make a sheet whose only readable strike arrives long after frame 1
unless that delayed timing is explicitly intended. The preferred trigger
window is short and conservative: enough to reveal prep, not so early
that the visible downswing completes before the ball arrives.
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
brief aux sheet that plays only during a short left<->right facing
change, then returns to the main walking sheet. Runtime priority is
`dash > attack > turn-transition > walk > idle` (see AGENTS.md).

### 9.1. Purpose

- left -> right direction change
- right -> left direction change
- brief pivot / habit / accent gesture during the direction change

Normal locomotion keeps using the main walking sheet.

### 9.1.1. Core rule -- turn is not an angle-rotation chart

For PingFighter's front-biased / front-facing bosses, turn no longer
means "rotate the body through a camera-angle chart." The walk sheet is
already front-facing, so the direction-change sheet should stay visually
connected to that frontal read and express the direction change through a
short characterful motion accent instead.

Turn is where the boss briefly shows a characteristic "kuse" while
switching direction: chin lift, head tilt, shoulder hitch, arm pose
swap, one-knee lift, heel plant, tiny hop / pivot, ribbon / skirt /
hem snap, tail rebound, or another boss-specific habit that fits the
character concept.

The result should read like "the same frontal walker briefly changing
direction with personality," not "the camera is orbiting around the
character to show profile views."

### 9.1.2. Motion language requirements

Turn must feel like it belongs to the same motion language as the walk.
It is not random acting pasted between walk frames.

Required qualities:

- carry-in from the established walk silhouette
- brief compression / plant / prep
- one readable signature accent pose or micro-sequence
- recovery / rebound that leads cleanly back into walk
- the same whole-body rhythm as the walk: body bob, weight shift, hair /
  ribbon / cloth follow-through, small bounce where appropriate

Good turn sheets usually keep the face and torso mostly front-biased
while letting asymmetry and gesture do the work. The player should still
feel like the boss is facing the player / ball during the transition.

### 9.1.3. Hard-fail patterns for the new turn brief

Reject and regenerate if any of these happen:

- the sheet becomes a visible side-profile / multi-angle showcase
- the sheet reads like a camera orbit or rotation chart instead of a
  direction-change gesture
- the gesture feels unrelated to the established walk language
- the boss suddenly looks away from the player / ball in a way the walk
  never does
- the transition feels like unrelated acting pasted on top of the walk
- labels, numbers, or layout text print into the cells

### 9.1.4. Apparent face-clipping guardrail (do not misdiagnose as runtime crop)

Turn-sheet failures often present as "the face looks clipped" even when
no runtime crop is actually removing pixels. This often shows up on the
peak transition pose, where the head can read forehead-cut, vertically
squashed, or like the top of the face was trimmed away even though the
canvas technically fits.

Required diagnosis order before blaming runtime:

1. Compare the raw generated cell.
2. Compare the post-inset crop used to remove borders / labels.
3. Compare the trimmed visible-bounds frame.
4. Compare the gameplay-size render against the accepted walk.

If the clipped-looking face read already exists at any pre-runtime stage
(raw cell, inset crop, or trimmed frame), it is an **asset-side failure**
and must be rejected / regenerated. Do NOT assume Codex can fix it with
turn-only scale tweaks, anchor nudges, or crop changes.

Important rule: repeated turn-only downscale is **not** the default fix.
Making the same bad transition pose smaller can reduce its footprint while
leaving the clipped / squashed face impression intact. If the accepted
runtime slice still makes the face look chopped after a conservative
fit, hand off "disable visible turn playback / use hop-only fallback"
to Codex via `AGENTS.md` until replacement art exists.

### 9.2. Canonical reference

Same rules as 8.2 -- walking sheet is the identity anchor. All eight fixed
elements (hair color, hairstyle, face, eyes, skin tone, proportions,
outfit, accessories) must stay. For front-biased bosses, the face and
torso should usually remain mostly front-facing. What changes is the
gesture emphasis: head / chin lift, shoulder shift, temporary asymmetry,
arm pose, one-leg lift, hop / pivot accent, and related overlap.

Simple image rotation is not acceptable, and a side-profile angle chart
is not the goal. Each frame should be a fresh redraw of the same frontal
combat-facing character performing the short transition gesture.

### 9.2.1. Runtime-only auxiliary acceptance vs canonical anchor

- A turn sheet may be accepted for runtime playback while still remaining a
  **non-anchor** asset.
- In that case, the walking sheet remains the sole identity anchor for any
  future regeneration work (attack / dash / victory / defeat / derived
  motion).
- If you take this route, document it explicitly as:
  `runtime-only auxiliary turn sheet, non-anchor`.
- Do NOT let a runtime-accepted cosmetic divergence silently become the new
  regeneration baseline just because the turn sheet ships.

Current repo-specific example:
- **Stage 3 Menhera R1** accepts FLUX-derived turn V3 for runtime playback
  only. `items/menhera_boss_sheet.png` remains the sole identity anchor.
  Menhera turn V3 / V4 are not approved regeneration anchors.

### 9.3. Recommended layout

| Field | Value |
|---|---|
| Frames | 8 (4x2 grid) |
| Row 1 | walk-compatible carry-in, compress / plant, accent wind-up, peak transition pose |
| Row 2 | rebound, recovery, settle, walk-compatible return |
| aspectRatio | 16:9 |
| imageSize | 2K |
| Background | pure white #FFFFFF, no grid/border/divider/label |
| Body scale | within +/-5% of walking sheet |

Layout note:

- Preferred output is one compact transition sheet that already reads as
  a brief directional accent.
- Runtime may consume only the strongest usable slice of the sequence if
  that preserves readability and timing.
- If the brief repeatedly drifts back toward side-profile rotation,
  restate the front-biased gesture brief and regenerate rather than
  inventing more angle coverage.

### 9.4. Neighboring-frame interpolation

Adjacent frames must read as one short continuous gesture sequence. The
entry and exit frames should connect cleanly to the established walk so
the transition does not pop when runtime swaps between walk and turn.

### 9.5. File placement

- Raw: `items/[name]_boss_turn.jpeg`
- Nukki: `items/[name]_boss_turn.png`

### 9.6. Turn sheet QA checklist

| # | Check | Pass |
|---|---|---|
| 1 | Same character as walking sheet | yes |
| 2 | All fixed elements preserved | yes |
| 3 | Reads as a brief characterful direction-change gesture, not a profile-spin or angle chart | yes |
| 4 | Peak transition pose preserves the same frontal combat read as walk instead of becoming a side-facing showcase | yes |
| 5 | Entry and exit frames connect cleanly back into the accepted walk | yes |
| 6 | Body scale within +/-5% of walking sheet | yes |
| 7 | The motion includes a boss-specific habit / accent (head lift, arm cue, knee lift, pivot, ribbon rebound, etc.) rather than generic filler acting | yes |
| 8 | Raw cell -> inset crop -> trimmed frame -> gameplay-size comparison confirms any clipped-looking face read is not already present before runtime | yes |

If the turn sheet reads as a different character, reject and regenerate.

---

## 10. Resolution & aspect

| Parameter | Recommended | Notes |
|---|---|---|
| `aspectRatio` | `16:9` for 4x2, `1:1` for single/2x2 | 4:1 not directly supported |
| `imageSize` | `2K` | Default generation size only -- not an automatic final ship size. 4K nukki is slow, 1K often loses detail |
| `style` | `"16-bit retro pixel art, chibi, flat colors, thick outlines"` | required |

### 10.1. Delivery-size rule

- `2K` is the default generation size, not a mandate that every accepted
  sheet ships unchanged as the runtime delivery asset.
- If one boss now has walk + attack + dash + turn all at `2K`, treat the
  combined source load as part of the handoff, not just each sheet in
  isolation.
- If large trails, halos, or ambient effects force a lot of dead
  transparent area around a small body, flag that a runtime-ready export
  may be better than asking Python to absorb the cost at startup.
- Prefer the smallest delivery asset that preserves gameplay-scale
  readability, identity lock, and body-scale lock.
- The handoff to Codex should mention total sheet count, source
  resolution, and whether stage-entry hitch / aggregate load cost should
  be checked.

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

### 11.5. Immediate post-nukki stop-and-ask QA

Immediately after nukki, run a focused edge audit on the most fragile
identity props before moving on to promotion or runtime handoff.

- If the generated sheet had critical small props such as black bows, pink
  paw pads, med-kit edges, syringe edges, or similar high-risk details,
  inspect them **before and after** nukki.
- If the hard-edge algorithm introduces halo break, alpha punch-out,
  outline loss, or prop disappearance on those identity-critical regions,
  stop there.
- In that case, do **not** continue to canonical promotion or runtime
  handoff until the asset is repaired or regenerated.

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
per boss. Walk templates for human / chibi bosses must also include the
Section 7.1 front-biased walk fragment -- front-biased walk is the
PingFighter default, full side-facing walk is optional and special-case.

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

Drift judgment rule for optional turn sheets:

- Do NOT judge drift from the turn sheet in isolation.
- Always compare the turn directly against the canonical walk sheet side by
  side at gameplay scale.
- A detail that feels "cute" or harmless on the turn sheet alone can still
  be a blocker if, when paired with the walk, it reads like a different
  identity branch and would be dangerous to propagate into future attack /
  dash / victory / defeat regeneration.
- If a project explicitly accepts a turn sheet as `runtime-only auxiliary,
  non-anchor`, then a small cosmetic divergence may be downgraded to
  runtime-only deviation -- but only after that non-anchor policy is
  documented clearly.

If a turn frame looks face-clipped or forehead-cut, do NOT jump straight
to "Codex should shrink / clamp it more." First run the Section 9.1.3
raw-cell -> inset -> trimmed -> gameplay-size comparison. If the bad
read survives before runtime fitting, reject / regenerate the art or
hand off turn disable / hop-only fallback.

---

## 16. Hand-off to Codex after sheet acceptance

Once a sheet passes QA and nukki is committed, use
`prompts/handoff_codex.md` to request Codex integration per AGENTS.md.
Typical payload: list of new assets, expected sprite class name, notes on
body-scale reference, preferred impact frame for attack sheets when
relevant, whether anticipatory / pre-contact attack triggering is
recommended, any dash/attack/turn priority nuances.

If a turn sheet changed layout (for example `8x1` -> `4x2`), call out the
required loader-grid and frame-order changes explicitly in the handoff.
If a turn sheet is accepted as runtime-only non-anchor, say that plainly in
the handoff too.

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
