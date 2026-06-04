---
name: sprite-generation
description: |
  Boss/character sprite sheet creation pipeline for DiskHearts - Ringpia. Covers walk,
  attack, dash, and turn (facing transition) sheets, character identity lock
  across sheets, body scale lock (+/-5%), color palette drift prevention,
  AutoSprite-MCP-first sprite-sheet workflows (Gemini/FLUX/built-in imagegen are not final sheet generators),
  content-filter bypass vocabulary, background removal (nukki) via a 2-step
  hard-edge algorithm on JPEG to PNG, file naming and output paths,
  reject/regenerate QA checklists, and end-to-end implementing-agent-owned runtime
  promotion (the current agent commits the final apply; previous cross-agent hand-off
  step is removed). Use this skill whenever the
  user asks to create, regenerate, reshoot, redraw, or fix a boss sprite
  sheet, walking sheet, attack sheet, dash sheet, turn sheet, or item icon,
  or to run background removal / nukki on a generated PNG or JPEG. 한국어
  트리거 키워드 - 스프라이트, 보스 시트, 걷기 시트, 공격 시트, 대쉬 시트, 턴 시트, 누끼,
  재생성, 스프라이트 시트, 보스 이미지, 배경 제거.
---

# Sprite Generation Pipeline (DiskHearts - Ringpia)

Asset-generation plays for boss and character sprite sheets.
Current runtime target is the Godot project **디스크하츠 - 링피아** under
`godot/`. Original Python/Pygame PingFighter sprite/runtime paths are legacy
porting references only.
**Updated 2026-05-03: the implementing agent owns the full pipeline end-to-end —
generation, QA, repo asset-tree commit, loader / cache wiring, runtime
scaling, and in-game QA. The previous cross-agent hand-off step is
removed.** `AGENTS.md` remains as a continuity reference for prior
boss-sprite runtime invariants, but it is no longer the single source of
truth for runtime promotion: the current agent commits the final apply.

Companion files in this skill directory:

- `remove_bg.py` -- runnable CLI nukki script (`py remove_bg.py <src.jpeg> <dst.png>`)
- `prompts/walk.md` / `attack.md` / `dash.md` / `turn.md` -- copy-paste prompt templates
- `prompts/handoff_codex.md` -- legacy / cross-agent integration request
  template; current default is direct Godot runtime promotion
- `checklists.md` -- reject/regenerate QA tables
- `examples.md` -- canonical references (Tauren / Menhera / Honglyeon)
- `references.md` -- links back to CLAUDE.md invariants and AGENTS.md
- `../../../docs/sprites/boss_sprite_runtime_contract.md` -- runtime
  state vocabulary such as attack-vs-stun semantics
- `../../../docs/sprites/stage1_dalji.md` -- compact Stage 1 Dalji
  Python/Godot sheet mapping

---

## 1. When to use this skill

Trigger on any of these user intents:

- If the user says "그려줘", "그려달라", "draw", or "redraw" for a sprite,
  sheet, boss image, or character image, use the image-generation path
  first. Do not replace that request with procedural / code-native art
  unless the user explicitly asks for it or accepts a fallback after
  imagegen is blocked.
- Create a new boss/character sprite sheet (walk/attack/dash/turn/icon)
- Regenerate or re-shoot an existing sheet (identity drift, scale drift, bad frames)
- Run background removal / nukki on a generated JPEG into PNG
- Reuse or adapt an AutoSprite MCP prompt / reference workflow for a
  different boss (Gemini / FLUX / built-in imagegen may assist planning
  only; see Section 2.1)
- Debug why a generated sheet looks wrong (palette drift, oversized body, painterly rendering)

If the user is working on Godot loader, render loop, or runtime scaling, use
`AGENTS.md` and the relevant Godot architecture docs for integration. If the
user mentions `pingfighter.py`, treat it as a legacy behavior reference unless
they explicitly request original Python source edits.
The same routing applies if the report is actually a runtime orb-tooltip
bug discovered during sprite work (for example: `\n` line breaks being
flattened, or a newly added synergy line disappearing because a shared
bonus-line budget is already saturated). Route that to
`docs/character_skill_perk_checklist.md` + `CLAUDE.md`, not this skill.

---

## 2. Role split (updated 2026-05-14 — implementing-agent end-to-end)

- **Current implementing agent + this skill:** prompt design, sheet
  layout, style calls, content-filter wording, nukki pipeline, output
  file naming, reject/regenerate judgment, canonical-reference
  continuity, Godot runtime module scaffold (`godot/scripts/...`), runtime integration
  (loader / cache wiring, per-frame scaling, render branch, turn-vs-
  walk priority), performance audit, and **final apply (commit the
  PNGs to the runtime asset path and verify they are loaded
  in-game)**. Legacy Python sprite classes such as
  `entities/[name]_boss_sprite.py` are touched only when the user
  explicitly asks for original PingFighter source work. There is no
  default cross-agent hand-off step.
- **AGENTS.md:** continuity reference for prior boss-sprite runtime
  invariants and shipped-art provenance. Read it before promotion to
  avoid breaking an existing invariant; do NOT treat it as the single
  source of truth for new runtime work — the current implementing agent
  commits the apply.

Performance + clone-overlay audit notes that used to be cross-agent hand-off
bullets are now implementing-agent self-checks before promotion:

- Track sheet count, source resolution, and whether a runtime-ready
  smaller export is needed because combined load cost or transparent
  effect area is large.
- If the accepted art will be used as a runtime clone, afterimage,
  glitch copy, or other tinted duplicate of the live sprite, ensure
  additive / scanline / damage / fade overlays are clipped to the
  non-transparent silhouette of the source sprite. Otherwise the
  transparent canvas shows up in gameplay as a visible rectangular box
  around the clone.

### 2.1. Tool routing inside this skill

**AutoSprite MCP is the required generation source for sprite sheets.**
For any final boss / character / player / runtime VFX / animated item or perk
sprite sheet, call `mcp__autosprite__*` first and keep the accepted source
frames AutoSprite-derived.

This applies to every sub-task, not just fresh full-sheet generation:

| Task | Required route |
|------|----------------|
| Fresh full-sheet generation | AutoSprite MCP |
| Single peak-pose discovery that will become a sheet | AutoSprite MCP |
| Reference-conditioned touch-up / frame expansion | AutoSprite regeneration or AutoSprite-derived deterministic postprocess |
| Motion ideation / pose blocking | AutoSprite MCP |
| QA comparison input only | Gemini analyze or local visual/QC tools are OK |

Why the consolidation: project direction now requires production sprite
sheets to be generated through AutoSprite so provenance, motion intent, and
future regeneration are consistent. Do not replace AutoSprite output with
local interpolation, old 8-frame anchors, runtime drawing, Gemini, FLUX, or
built-in imagegen and describe the result as an AutoSprite sheet.

Allowed post-processing after AutoSprite:

```
1. Clean background / alpha / nukki.
2. Slice, align, scale, and export runtime-sized cells.
3. Expand or reduce frame count only from AutoSprite source frames.
4. Mirror or re-layout only when directionality, anatomy, and user approval
   are explicit; document it in the handoff.
```

Upscaling request rule:
- If the user says "upscale", "upscaling", "hires", "업스케일",
  "업스케일링", or "real / Real-ESRGAN처럼", route the accepted bitmap
  through the Real-ESRGAN upscale gate in `checklists.md` §0.1.
- Do not answer an upscale request with only runtime draw-size changes,
  simple resize, Godot import filtering, or a fresh imagegen redraw.
- For transparent sheets, split by frame or cell, alpha-bleed RGB before
  Real-ESRGAN, recombine the resized source alpha afterward, and reassemble
  the original grid with updated cell-size metadata.

If AutoSprite is not connected, fix MCP first or ask the user before using a
fallback. A fallback can be a temporary placeholder or still concept, not a
final sprite sheet.

- **Legacy motion-master caution**: if an old victory or other legacy
  sheet starts leaking obsolete design branches into new AutoSprite briefs,
  use it only as QA comparison, not as a motion master.

Historical accepted-sheet notes elsewhere in this skill and in `CLAUDE.md`
may mention FLUX Kontext, Gemini, or earlier non-AutoSprite routes. Those
describe already-shipped provenance only. Future regeneration follows the
AutoSprite MCP rule above.

Current repo-specific note:
- **Stage 3 Menhera turn / victory branches**: shipped sheets remain as
  accepted. Any future Menhera regeneration uses AutoSprite MCP.
- **Stage 1 Dalji attack v2 (sangmo whip)**: the v2 sheet is the
  current accepted asset. Future Dalji attack regeneration uses
  AutoSprite MCP; old Gemini/FLUX anchor notes are provenance only.

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

## 2.3. Runtime skill-effect sprite sheets

When this skill is used for gameplay VFX instead of a boss body sheet
(boss fields, character skill auras, projectiles, cast loops, impact
loops, shield / refraction / magnetic / elemental fields, and similar
live effects), the default deliverable is a **16-frame sprite sheet**.

Default composition:
- `4x4` grid, exactly 16 equal cells.
- Read order is left-to-right, top-to-bottom.
- The effect keeps the same center, scale, circular / directional
  silhouette, palette family, and alpha style across all frames.
- Frame 16 must connect cleanly back to frame 1 for a smooth loop.
- Use 2-frame / 4-frame / 8-frame sheets only for explicit rough concepts,
  icon-only animations, or deliberately short one-shot effects.

Required prompt fragment for runtime skill effects:

```
Create exactly 16 equal cells arranged in a 4x4 sprite sheet, read
left-to-right and top-to-bottom as a smooth looping game VFX animation.
Keep the same center, scale, silhouette, palette, and effect identity in
every frame. Frame 16 must loop cleanly back to frame 1. Leave generous
flat chroma-key or transparent margin on all four sides of every cell.
No spark, arc, glow, ripple, halo, trail, or ornament may touch or cross
any cell edge.
```

QA before handoff:
- Check all 16 frames for edge-touching VFX, scale drift, center drift,
  and accidental detached debris.
- Keep the accepted source PNG and a runtime-ready transparent PNG with
  versioned filenames.
- Tell Codex the sheet grid, frame count, intended frame interval, blend
  style (normal alpha vs additive), and any desired softness / opacity
  tuning so runtime can cache and render it correctly.

### 2.3.1. Character skill cut-in finishing parity (inward edge feather)

Character skill cut-in sheets (the per-skill 4x4 anime cut-in sheets
under `godot/assets/ui/skill_cutin/`, e.g. power-smash, ghost-smash) are
AutoSprite character sheets, not the looping VFX sheets above, but they
share the same edge-clip failure mode and MUST get the same finishing.

After the deterministic safe-margin repack (each AutoSprite cell scaled
to ~84% and re-centered), the auras, smoke, speed trails, and the final
foreground impact / racket disk usually still end on a **hard alpha
edge** inside the margin. That hard edge reads in-game as "the artwork is
clipped by an invisible square," even though no cell-edge alpha touch
exists and the standard `transparent_edge_alpha_count` QA passes.

Required finishing for every cut-in sheet:

- Apply a per-cell **inward smootherstep alpha feather** so the boundary
  fades to transparent instead of cutting hard. The shipped reference
  recipe (power-smash + ghost-smash) is `inner_source_bounds
  [82,82,941,941]`, `feather_px 130` on a 1024 source cell, applied
  BEFORE any Real-ESRGAN upscale. Replicate it, do not re-invent.
- This is AutoSprite-derived deterministic postprocess (allowed). Record
  it in the sheet manifest `postprocess.edge_feather` block with the new
  runtime sha256 and a pre-feather backup path.

QA gate (do NOT trust the editor's white background):

- Measure the **hard-perimeter metric**: percent of each frame's content
  bbox perimeter still strongly opaque (alpha > 180). The accepted
  reference sheet measures **0.0** mean/max; a sheet that skips the
  feather measures double digits (the ghost-smash v1 regression was
  21.4% mean / 33.4% max across 12 of 16 cells before the feather was
  added). Anything materially above 0 means the edges will read clipped.
- A passing `transparent_edge_alpha_count` / corner check is NOT enough —
  it only catches true cell-edge touches, not the inside-the-margin hard
  cut that produces the clipped look.
- If a new cut-in is generated WITHOUT this feather (the ghost-smash v1
  mistake), it will look visibly "cut off at the outline" next to a
  feathered sibling cut-in. Apply the feather before promotion.

### 2.3.2. Character skill cut-in anti-jitter + bust bottom-fade

Two failure modes that are separate from the §2.3.1 edge feather and were
NOT covered by it. Both shipped on the Viper phantom-kick cut-in v2 (the
sheet "jittered / vibrated and looked weird" in-game) and had to be
regenerated. Apply these whenever a cut-in is built by reframing an
AutoSprite source into a 4x4 sheet.

**1. One fixed transform across ALL cells — never per-cell re-center.**

The cut-in's per-cell crop/scale/placement must be a SINGLE fixed
transform computed once (e.g. from the union bbox of all 16 frames) and
applied identically to every cell. Do NOT crop each cell to its own alpha
bbox / re-center each cell independently — even a 1-8px per-frame
difference in the crop window reads in-game as high-frequency vibration.
The v2 regression alternated the left crop edge 80/88px and crept the
bottom bbox frame-to-frame, which is exactly what produced the shake. The
character's own subtle internal motion still plays under a fixed
transform; what you are removing is the recenter/scale snap.

**2. Never use a back-and-forth / sawtooth source frame sequence.**

If you pick a subset of source frames, keep the order monotonic
(forward, or a clean ease-with-holds). A sequence like
`[7,8,9,10,11,8,9,10,11,9,10,11,...]` that jumps back (11->8, 11->9)
makes the body snap backward repeatedly = jitter. Best practice for a
HELD dramatic cut-in (brace / charge / wind-up that should not travel
out of frame): generate the AutoSprite animation with the SAME pose on
`first_frame_pose_id` AND `last_frame_pose_id` so the source itself holds
the pose with near-zero drift (the Viper v3 fix measured cx span ~6px /
cy span ~15px with no snapping). Then the fixed-transform reframe above
is trivially smooth.

**3. Upper-body / bust crops need a bottom-fade.**

When the user wants an upper-body / "상반신 위주" cut-in and you crop the
legs, the waist crop leaves a hard horizontal edge in the middle of the
cell. The §2.3.1 cell-edge inward feather does NOT touch it (it only
fades near the cell border), so the hard-perimeter metric stays high
(~9% in the Viper case) and the bust reads as "clipped by an invisible
box" at the bottom. Add a smootherstep BOTTOM-FADE that dissolves the
lower ~200-230px (on a 1024 cell) of the placed content to transparent,
the way anime busts fade out at the bottom. With it, hard-perimeter
returns to 0.0.

QA: keep the same hard-perimeter-0.0 gate from §2.3.1, AND verify
per-frame bbox drift on the SOURCE (cx/cy span small, no back-and-forth)
before reframing. Record the fixed-transform values, frame order, and
bottom-fade px in the sheet manifest.

### 2.4. Character Live2D source-art background rule

For character Live2D source illustrations / 원화 / full-body anchors that will
later need nukki, rigging, sheet generation, or runtime cutout use, generate
the raw source on a perfectly flat solid chroma-key background. Default to
`#ff00ff` magenta; switch to `#00ff00` green only when magenta conflicts with
the character palette. Do not request black, white, dark studio, scenic,
gradient, checkerboard, or "transparent-looking" backgrounds for these
production anchors.

Use the checklist gate in `checklists.md` §0.4 before accepting the source
art. Keep both the raw chroma-key source and the cleaned alpha PNG, and record
the key color plus cleanup method in the handoff / manifest.

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
7.1 (front-biased walk): for DiskHearts - Ringpia ping-pong framing, human /
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

### 4.1. Standard size reference -- Stage 3 Menhera body class

**Stage 3 Menhera's in-game body class is the STANDARD size for boss
sprites in DiskHearts - Ringpia, not just a "preferred baseline".** Every
new boss must land at this size class unless the boss is explicitly listed
under "Out of scope" below. Sprite sheets ship across the codebase with
visibly drifting body sizes when this rule is treated as a soft preference,
so every runtime promotion must verify the size match before the work is
considered done.

Concrete runtime reference (from `pingfighter.py` Menhera init):

| Reference | Value | Source |
|---|---|---|
| `BOSS_IMG_WIDTH` | `160` | base width constant |
| `BOSS_IMG_HEIGHT` | `80` | base height constant |
| Menhera target frame canvas | `width = round(BOSS_IMG_WIDTH * 1.1) = 176`, `height = round(BOSS_IMG_HEIGHT * 1.1) = 88` | Menhera's `+10%` upscale |
| Menhera class-default args | `width=79, height=88` | LEGACY default; do NOT use as the size reference |

Use **176 x 88** as the parity target frame canvas / body-read reference
for any new petite human / chibi boss. In the current Godot runtime, encode
the equivalent canvas, source-rect, stage-scale, and cadence metadata in
the owning renderer or catalog rather than editing a Python init call. Body
silhouette, head, face, and torso must read at the same gameplay-size class
as Menhera. Do NOT carry the legacy `79 x 88` class default into a new
Godot boss configuration -- it produces a sub-Menhera body class.

Pure-pixel size matching is not enough by itself. Visible body read
matters more than canvas dimensions: a sheet whose figure fills only
60% of the canvas reads smaller in-game than one that fills 80%. After
runtime install, the gameplay-size body of the new boss must match
Menhera's body class side by side (head height, face size, torso
silhouette).

Out of scope (size-class exceptions, must be design-led, must be
documented per boss):

| Out of scope | Why |
|---|---|
| Large-frame bosses (e.g. Tauren) | Bigger body class is the design intent |
| Tall vertical-silhouette bosses (e.g. Honglyeon) | Taller silhouette is the design intent |
| Deliberate oversized / undersized concept bosses | Design-led sizing wins |

If a boss falls into one of those exceptions, record the size override
explicitly: state the Godot canvas / scale target and the design reason
both in the implementation / handoff note and in `CLAUDE.md` under that
boss's per-boss policy section. Never let a size override slip in
implicitly via a copied legacy class default.

Runtime-side guardrails for the same rule live in `AGENTS.md`. The
runtime promotion path requires an explicit Menhera-tier body-read match
check, and the size-tier QA gate is in `checklists.md` §10.

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

### 7.1. Front-biased walk for human / chibi bosses (DiskHearts default)

For DiskHearts - Ringpia boss gameplay, human / chibi bosses should usually keep
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

Walk-sheet hard gate before any publish / runtime promotion:

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
laterally. Full side-facing walk is NOT the default for DiskHearts - Ringpia
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

For DiskHearts - Ringpia's front-biased / front-facing bosses, turn no longer
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
  may be better than asking the Godot startup / prewarm path to absorb the
  cost.
- Prefer the smallest delivery asset that preserves gameplay-scale
  readability, identity lock, and body-scale lock.
- The runtime promotion note should mention total sheet count, source
  resolution, and whether stage-entry hitch / aggregate load cost should be
  checked.

### 10.2. Gemini chat-history limit guardrail

- A `2K` Gemini generation may succeed, then cause the *next* request in
  the same chat to fail as a `many-image request` if the `2048` result is
  still attached in conversation history.
- The trigger is the client-side `>2000 px` long-side limit, not a prompt
  failure or a broken generation candidate.
- For iterative same-session work, prefer `1536` or `1024`; reserve `2K`
  for single-shot high-detail passes or a fresh session.
- If a `2048` result must be reused in chat for analysis or continuation,
  resize it to `<=2000 px` first.

### 10.3. Gemini MCP connection-stability guardrail

If Gemini MCP reports `connection timed out after 30000ms`, diagnose the
MCP server launch path before changing prompts or abandoning the tool:

- Prefer `.claude/gemini_mcp_launcher.mjs` launched by an absolute
  `node.exe` path over `npx -y @rlabs-inc/gemini-mcp`; `npx` can spend the
  whole MCP startup budget on package resolution.
- Keep `@rlabs-inc/gemini-mcp` pinned in `mcp/package.json` and reinstall
  `mcp/node_modules` cleanly if package folders are missing their `dist`,
  `build`, or `lib` contents.
- Startup must not wait on a Gemini API probe. Let the MCP transport
  initialize first; real API failures should surface on the actual tool
  call.
- MCP stdout is JSON-RPC only. Route startup / progress logging to stderr
  or quiet mode, otherwise the client can close the connection as corrupt
  stdio.
- After a fix, verify `initialize`, `listTools`, and one lightweight tool
  call before resuming sheet generation.

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

### 11.6. AI pastel-halo residue trap (item icons especially)

`remove_bg.py` 의 기본 임계값 (`WHITISH_LUM >= 200`, `WHITISH_SAT <= 30`,
`HALO_SAT <= 40`, `MILD_SAT <= 60`) 은 Gemini JPEG compression fringe를
타깃으로 튜닝돼 있다. 하지만 AI 이미지 생성기는 아이콘을 흰 배경 위에
그릴 때 자주 **피사체 바깥으로 저채도 파스텔 halo / aura / glow** 를
의도적으로 그려낸다 (예: cyan fairy aura, red fury glow, yellow vitamin
shimmer). 이 halo는:

- 파스텔이라 완전히 흰색이 아니다 (`WHITISH_SAT <= 30` 을 벗어남) →
  border flood-fill이 절대 halo를 배경으로 못 인식함.
- 반대로 `lum` 은 220 이상으로 충분히 밝아서 피사체 본체보다는 확실히
  약하다 → 본체 silhouette 에는 영향 없이 halo 만 따로 구별 가능.

표준 3-step nukki 가 끝나도 **halo 는 semi-opaque pastel ring 으로
아이콘 주변에 남는다**. 1024 원본에서는 예쁜 발광 효과처럼 보이지만,
32px HUD 아이콘으로 다운샘플되면 아이콘 가장자리에 `1~2px 컬러 envelope
border` 로 변한다. dev 모드 / 획득 연출 / 슬롯 HUD 에서 아이콘 테두리가
이상하다고 느끼면 거의 이 패턴이다.

**두 가지 대응책 — 같이 써라:**

1. **생성 단계 — 프롬프트에서 halo 금지.** HUD 아이템 아이콘을 만들 때
   프롬프트에 `no glow halo`, `no aura`, `no soft shimmer around the
   object` 를 명시하고, 불가피하면 halo를 본체 실루엣 *안쪽* 에 그리게
   유도한다 (예: "flame only around the bottle cork, not in the
   background"). AI 는 여전히 halo 를 그려낼 수 있으므로 2단계가 필요.

2. **누끼 단계 — halo strip 2차 패스 돌려라.** `remove_bg.py` 출력에
   halo 가 남아 있는 게 확인되면 `remove_bg.py` 의 `WHITISH_SAT` /
   `HALO_SAT` 를 직접 낮추지 말고, 별도의 보조 스크립트를 돌린다.
   낮추면 보스 스프라이트의 고채도 하이라이트가 배경으로 오인돼 먹힌다.

   정식 CLI:
   ```
   py .claude/skills/sprite-generation/halo_strip.py <src.png> <dst.png>
   ```

   동작:
   ```
   기존 투명 픽셀에서 BFS 확장
     → 이웃 픽셀이 `V >= 220 AND (maxRGB - minRGB) <= 110` 이면 같이 투명화
     → 이 조건은 "밝고 저채도" 파스텔 halo 만 잡음
   실루엣 내부의 채도 있는 픽셀은 BFS 가 도달 못 해서 안전
   ```

   파이프라인:
   ```
   <src.jpeg> → remove_bg.py → <nukki.png> → halo_strip.py → <clean.png> → resample
   ```

**QA 순서 — 순서를 꼭 지켜라:**
- 1024 `*_nukki_1024.png` 를 **원본 해상도로 먼저 본다.** AI halo가
  여기서 파스텔 envelope 로 이미 보이면 2차 strip 없이 32px 로
  내리면 안 된다.
- 32px / 64px 다운샘플은 halo strip 후 생성해라. 다운샘플된 결과만
  보고 판정하면 halo 잔재가 1~2px 만큼 미묘하게 남아 있어도 그냥
  "에지 anti-alias" 로 착각해서 통과시킬 수 있다.
- 게임 안에서 **어두운 HUD 배경 위에 띄워보는 게 최종 QA.** 흰색
  에디터 배경 위에서는 halo 가 안 보인다.

이 트랩은 아이템 아이콘 쪽에서 특히 자주 터진다 (repair_kit,
berserk_potion, vitamin_pill, weather_capsule 사례). 보스 스프라이트는
피사체가 프레임을 꽉 채우고 halo 를 안 그리는 프롬프트가 이미 많아서
덜 터지지만, 풀 바디 + 발광 이펙트를 같은 프레임에 넣을 때 (예: 승리
포즈에 aura 를 넣으면) 그 때 똑같이 터진다.

### 11.7. Enclosed near-white pocket residue (legs / arms / shield-arm gap)

`remove_bg.py` 의 border flood-fill 과 `halo_strip.py` 의 BFS 확장은 모두
**외부 alpha=0 영역에서 도달 가능한** near-white 픽셀만 제거한다.
캐릭터의 silhouette 이 닫힌 모양으로 둘러싸 외부와 cut off 된
enclosed pocket — 다리 사이, 팔과 몸 사이, 방패와 어깨 사이, 호버보드
위 두 발 사이의 좁은 V 형 구역 — 은 두 알고리즘이 모두 못 잡는다.
흰 에디터 배경 위에서는 안 보이지만, **어두운 인게임 배경 (스테이지
바닥, 보스전 BG) 위에 띄우면 흰 박스 / 흰 사다리꼴 잔여물로 보인다.**

자동 후처리로 enclosed pocket 을 잡으려는 시도는 **두 가지 알고리즘
모두 silhouette-internal 의도적 흰 panel 을 함께 잡아버리는 한계가
있다.** 어느 쪽이든 단독으로는 안전하지 않다:

**Approach A — Connected-components + size threshold.**
```
(alpha=255 AND near-white) 픽셀의 connected-component size 측정,
<= MAX_POCKET_SIZE (예: 400px) 면 누끼 잔여로 간주 → 제거.
> threshold 면 의도적 흰 panel 로 간주 → 보존.
```
- 한계: 큰 enclosed pocket (예: SD chibi 다리 사이가 가로 100 x 세로 50
  = 5000px 넘는 경우, 또는 팔과 몸 사이의 큰 V 자 구역) 은 size 만
  으로는 캐릭터의 진짜 흰 panel 과 구분이 안 된다. Smasher subculture
  idle 의 1차 cleanup 에서 다리 사이 + 6번 프레임 방패 뒤 잔여가 이
  threshold (400px) 를 넘어서 통과해 버린 사례가 있다.

**Approach B — Outer-BFS connectivity (외부 alpha=0 도달성).**
```
이미지 border 의 모든 alpha<임계값 픽셀에서 BFS 로 외부 영역 expand.
(alpha=255 AND near-white) 픽셀 중 외부 영역에 도달 불가능한 것은
모두 enclosed pocket → size 무관하게 제거.
```
- 한계: silhouette **안쪽**의 의도적 흰 panel — 캐릭터 등 spine 의 흰
  부분, 호버보드 아래 cyan/white hover light pool, 패들 흰 face,
  바디수트 흰 트림 — 도 BFS 기준 "외부에서 도달 불가능" 이라 enclosed
  pocket 과 구분되지 않는다. 컬러 outline 으로 둘러싸여 있어서 자동
  으로 보호되리라는 가정은 **틀렸다**: outline 은 BFS-connectivity 의
  도달성을 막을 뿐, near-white 마스크 안의 panel 자체는 그대로
  enclosed 로 분류된다. Smasher subculture walk 시트의 등 흰 spine
  panel + 호버보드 hover light pool 이 BFS-cleanup 으로 통째 날아간
  사례가 있다.

**자동 cleanup 의 안전한 default 는 "둘 다 사용하지 않고 nukki +
halo_strip 까지만 적용" 이다.** 누끼 잔여가 보이면:

- 작은 잔여물 (다리 사이 < 400px, 팔 사이 좁은 통로) → Approach A
  를 보수적 threshold (300~400px) 로 적용해도 비교적 안전. 단, 캐릭터
  silhouette 안쪽에 작은 흰 디테일 (작은 흰 점 highlight, 작은 흰
  로고 등) 이 있으면 그것도 함께 제거되니 사전 검증 필수.
- 큰 잔여물 (Smasher 다리 사이, 방패 뒤 큰 V 자 등) → 자동 알고리즘
  으로는 의도적 panel 과 구분이 어렵다. **외부 도구 (Codex 같은
  agent 가 frame-by-frame 으로 의도적 panel 위치를 알고 마스크 처리)
  에 위임하는 것이 가장 안전**. PingFighter 의 Smasher idle 시트는
  이 방식으로 정합성 처리됐다.
- 중간 케이스 (size 가 모호하거나 캐릭터 디자인이 silhouette 안쪽
  흰 panel 을 많이 가진 경우) → 자동 cleanup 시도하지 말고 nukki +
  halo_strip 만 적용 후 인게임 QA. 사용자가 어두운 BG 에서 보고
  거슬리는 영역을 명확히 짚어주면 그때 마스크 처리.

QA:
- **흰 배경 위에서는 절대 검증하지 말 것.** false negative 가 크다.
- 어두운 인게임 배경 (스테이지 바닥, 보스전 BG) 또는 디버그 용
  체커보드 / 단색 어두운 패널 위에 띄워서 다리 / 팔 / 무기 사이에
  흰 박스 / 흰 사다리꼴 잔여물이 안 보이는지 8 프레임 모두 확인.
- **자동 cleanup 적용 후에는 의도적 흰 panel 도 같이 점검**: spine
  panel, 패들 face, 호버보드 hover light pool, 바디수트 트림 등이
  사라지지 않았는지 sample 픽셀로 검증 (PIL 로 raw vs cleaned 비교
  pixel diff). 자동 알고리즘은 의도적 panel 을 의외로 자주 잡는다.
- 잔여 픽셀 수를 직접 카운트하는 자동 검사도 도움이 된다 (PIL 로
  `(alpha=255) AND (V>=220) AND (S<=30) AND (외부 alpha=0 에 BFS-도달
  불가)` 픽셀 0 개인지 검사). 단, 이것이 0 이라고 해서 자동 cleanup
  이 안전했다는 뜻은 아니다 — 의도적 panel 도 같이 0 이 됐을 수 있다.

이 트랩은 SD chibi 캐릭터 시트에서 특히 자주 터진다 — 다리 사이가
호버보드 위에 좁게 닫혀 있거나, 패들 / 쉴드를 양 옆으로 들고 있을 때
팔과 몸 사이가 cut off 되거나, 방패와 어깨 사이 작은 enclosed
구역이 생기는 패턴. Viper / Commando / Smasher 같은 백뷰 idle / walk
시트 post-process 시 자동 cleanup 의 default 는 **적용하지 않음**.
nukki + halo_strip 만 거친 결과를 인게임에서 QA 하고, 잔여가 발견되면
크기와 위치에 따라 위 결정 트리로 처리한다. **자동 cleanup 한 번 돌리고
의도적 panel 이 살아있는지 별도 점검하지 않으면 등 흰 spine / 호버
글로우 / 패들 face 가 통째 날아가는 회귀가 발생한다.**

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

Walk sheets are now produced as a **separate left-walk + right-walk pair**
(Section 13.1). The single-sheet + runtime-flip pattern is deprecated.

`items/` paths below are asset-generation scratch / staging outputs. For
the current DiskHearts - Ringpia runtime, accepted PNGs must be copied into
the repo-local Godot asset tree and wired from the owning Godot module under
`godot/scripts/`. Legacy Python paths remain porting references only.

| File | Path | Example |
|---|---|---|
| Walk sheet LEFT (raw staging) | `items/[name]_boss_walk_left.jpeg` | `items/tauren_boss_walk_left.jpeg` |
| Walk sheet LEFT (nukki staging) | `items/[name]_boss_walk_left.png` | `items/tauren_boss_walk_left.png` |
| Walk sheet RIGHT (raw staging) | `items/[name]_boss_walk_right.jpeg` | `items/tauren_boss_walk_right.jpeg` |
| Walk sheet RIGHT (nukki staging) | `items/[name]_boss_walk_right.png` | `items/tauren_boss_walk_right.png` |
| Attack sheet (staging) | `items/[name]_boss_attack.{jpeg,png}` | `items/tauren_boss_attack.png` |
| Dash sheet (staging) | `items/[name]_boss_dash.{jpeg,png}` | `items/honglyeon_boss_dash.png` |
| Turn sheet (optional staging) | `items/[name]_boss_turn.{jpeg,png}` | `items/menhera_boss_turn.png` |
| Godot runtime boss assets | `godot/assets/sprites/bosses/[name]/...` or the stage owner's established asset folder | `godot/assets/sprites/bosses/menhera/...` |
| Godot runtime owner | `godot/scripts/...` owning stage / boss / renderer module | `godot/scripts/stages/...` |
| Legacy Python background reference | `backgrounds/stage[N]_*.jpeg` | `backgrounds/stage9_pillar_left.jpeg` |
| Legacy Python sprite class reference | `entities/[name]_boss_sprite.py` | `entities/tauren_boss_sprite.py` |

Keep BOTH jpeg and png -- see Section 11.3.

Stage-1 Dalji exception: per `CLAUDE.md`, Dalji uses
`assets/dalji_boss_walk_left.png` and `assets/dalji_boss_walk_right.png`
instead of `items/...`. The legacy `assets/dalji_boss_walk.png`
single-sheet asset is preserved on disk only as a runtime rollback
reference until the loader migration completes.

### 13.1. Separate L/R walk pair model (current convention)

The current DiskHearts - Ringpia walk-sheet convention is a **separate left-walk
sheet + separate right-walk sheet pair**. This replaces the older
"single combined sheet + runtime horizontal flip" pattern.

Why this matters:

- Direction-asymmetric props (a hair flower pinned to one specific side
  of the head, an instrument carried on one specific hip, an arm-mounted
  weapon, a sash hanging on one specific side) cannot be safely produced
  by mirroring a single-direction source. A blind runtime horizontal
  flip puts those props on the WRONG anatomical side for the mirrored
  direction, which silently regresses character identity.
- Sash, ribbon, hair, and cloth physics also trail OPPOSITE the motion
  direction. A runtime mirror of a right-walker swaps left and right
  but does not reverse motion physics, so the trail visually pops at
  direction transitions.
- Drawing both directions natively keeps every prop on the same
  anatomical body side and keeps every physics trail in the correct
  direction relative to motion.

Default deliverable for any new walk-sheet brief:

| Sheet | Layout | Frames | Facing | File |
|---|---|---|---|---|
| Walk LEFT | 4x2 grid | 8 | All cells off-frontal toward viewer's LEFT | `[name]_boss_walk_left.{jpeg,png}` |
| Walk RIGHT | 4x2 grid | 8 | All cells off-frontal toward viewer's RIGHT | `[name]_boss_walk_right.{jpeg,png}` |

Cross-sheet QA is now a hard gate, not optional polish:

- Both sheets must read as the SAME chibi character at the SAME scale.
  Run the §3.1.1 cross-sheet clarity check on the L/R pair, not just on
  walk-vs-attack.
- Identity-fixed props must stay on the same anatomical body side in
  both sheets. Mentally label each prop (flower, drum, weapon, sash) by
  the character's anatomy (her left vs her right), not by viewer-side.
  At taste-judge time, verify the prop appears on the matching anatomy
  side in both sheets.
- Ribbon / sash / hair trails must trail OPPOSITE the motion direction
  in each sheet (left-walker trails toward viewer-right, right-walker
  trails toward viewer-left).
- Walk energy (knee lift height, body bob amplitude, stride length)
  should match across the pair. If one sheet is bouncy and the other
  is calm, that asymmetry will visibly pop on direction change.

Prompt-family rule:

- The stronger pair comes from a SHARED prompt family. Use the same
  chibi-style lock, anti-grid wording, ribbon-length lock, clothing-
  color lock, and prop-visibility lock in BOTH sheet prompts. Only the
  facing direction and per-prop anatomical-side wording flip between
  the two prompts.
- After accepting one sheet, reuse its accepted prompt verbatim for the
  companion sheet, with only the facing / anatomy flips edited. This
  is the proven way to keep cross-sheet identity drift low (the v8
  Dalji pair was promoted on c5-LEFT + c7-RIGHT after 6 rejections,
  most of which were single-side regenerations that drifted).

Do NOT use the deprecated single-sheet + runtime-flip pattern for new
work. Existing shipped sheets that still use the old pattern remain as
historical record until they are individually regenerated.

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
| Legacy / cross-agent hand-off | `prompts/handoff_codex.md` |

Every sheet template must include the Section 3.1 readability fragment
at first generation, and petite human / chibi bosses should lean on the
Section 4.1 baseline size reference rather than reinventing size targets
per boss. Walk templates for human / chibi bosses must also include the
Section 7.1 front-biased walk fragment -- front-biased walk is the
DiskHearts - Ringpia default, full side-facing walk is optional and special-case.

Stage mapping reminder: code `current_stage == 5` is Stage 6 Honglyeon,
code `current_stage == 6` is Stage 5 Nemesis. Always state both the real
stage number and the code stage number in the prompt when they might
disagree. Full mapping lives in `CLAUDE.md`.

---

## 15. QA checklists & reject/regenerate

See `checklists.md` in this skill directory for the full tables
(AutoSprite source gate, Real-ESRGAN upscale gate, character Live2D
source-art chroma-key gate, character-select Live2D card loop gate,
identity lock, scale lock, palette drift, turn sheet).

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

## 16. Runtime promotion after sheet acceptance

Once a sheet passes QA and nukki is committed, promote it directly into the
current Godot asset tree and update the owning Godot renderer / catalog per
AGENTS.md. If a separate cross-agent note is still needed, use
`prompts/handoff_codex.md` as a legacy template but keep the target Godot-
first. Typical payload: list of new assets, owning Godot module, notes on
body-scale reference, preferred impact frame for attack sheets when relevant,
whether anticipatory / pre-contact attack triggering is recommended, any
dash/attack/turn priority nuances.

If the promotion can touch attack, stun, or Godot texture keys, include
`docs/sprites/boss_sprite_runtime_contract.md`. For Stage 1 Dalji work,
also include `docs/sprites/stage1_dalji.md` so the implementation does not
infer state meanings from legacy names such as `boss_hit_sprite_sheet`.

If a turn sheet changed layout (for example `8x1` -> `4x2`), call out the
required loader-grid and frame-order changes explicitly in the handoff.
If a turn sheet is accepted as runtime-only non-anchor, say that plainly in
the handoff too.

---

## 17. Character / Boss standard sheet set

When creating a new boss or character, use this standard sheet set as the
checklist. Established during the Stage 1 Dalji buildout (2026-04-28) and
validated against Menhera (Stage 3) and other shipped bosses.

All sheets share the same standard layout:
- Canvas: **1536x1024 PNG**, 4 cols x 2 rows grid, cell **384x512** (the
  Dalji family standard; matches attack / turn / whip / dash / victory /
  defeat / stun / idle / paengi loaders so no per-sheet geometry change is
  needed). Walk pair is the one exception — uses **1376x768**, cell
  344x384 (slightly more compact since walk has no overhead structure).
- Frame count: **8 frames** per sheet (a single 4x4 grid is reserved for
  16-frame VFX effect sheets — see Section 2.3 for that case).
- Identity locks (Section 8.2) preserved across every sheet of the same
  character.

### 17.1. Basic 7 — required for every character / boss

| # | Sheet | Filename | When it shows |
|---|---|---|---|
| 1 | Walk LEFT | `[name]_boss_walk_left.png` | Boss moving leftward |
| 2 | Walk RIGHT | `[name]_boss_walk_right.png` | Boss moving rightward |
| 3 | Idle / breathing | `[name]_boss_idle.png` | Boss stationary, no other animation |
| 4 | Dash | `[name]_boss_dash.png` | Boss in fast slide / dash motion |
| 5 | Victory | `[name]_boss_victory.png` | Boss won the round / game |
| 6 | Defeat | `[name]_boss_defeat.png` | Boss lost the round / game |
| 7 | Stun | `[name]_boss_stun.png` | Boss is stunned / electrocuted |

### 17.2. Boss combat (recommended for any boss that hits the ball)

| # | Sheet | Filename | When it shows |
|---|---|---|---|
| 8 | Attack | `[name]_boss_attack.png` | Boss strikes the ball |

Plain paddle / minor characters that just bounce the ball without an
explicit strike pose can skip this. Bosses with personality should always
include it (Section 8.4.1 anticipatory contact-hit alignment applies).

### 17.3. Optional / per-character

| # | Sheet | Filename | When it shows |
|---|---|---|---|
| 9 | Turn / facing transition | `[name]_boss_turn.png` | Brief left<->right facing change accent |
| 10+ | Skill-specific | `[name]_boss_<skill_id>.png` | Each unique boss skill (one sheet per skill) |

Turn is the most-skipped optional sheet. For front-biased walk
characters (Section 7.1, the DiskHearts default), a runtime hop-only
fallback is acceptable instead of a real turn sheet — see Section 9.1.4.

Skill-specific sheets are added per-boss. Examples from the Dalji buildout:
- `dalji_boss_whip.png` — sangmo (상모돌리기) yaw rotation skill
- `dalji_boss_paengi.png` — top-whip (팽이치기) strike skill

### 17.4. Per-sheet post-processing pattern

Each sheet category uses a different post-processing pattern after
nukki, depending on what kind of variance it carries:

| Sheet | Per-cell scale? | Feet anchor | Reasoning |
|---|---|---|---|
| Walk pair | none | natural cycle | Walk-cycle bob is the feature |
| Idle / breathing | **single** uniform scale | grounded uniform | Breathing variance is the feature — per-cell would erase it |
| Attack (with overhead arc) | per-cell silhouette + chibi-face upscale (v9 → v11 pattern) | per-cell preserved | Silhouette uniformity then chibi walk-match midpoint |
| Turn | per-cell uniform | grounded uniform | Pose drift is artist noise, normalize away |
| Dash | per-cell uniform | grounded uniform + slide-sustained mapping | Slide pose dominates progress 0.18-0.99 |
| Victory | per-cell uniform | **per-cell preserved (jump arc)** | Jump frames keep their lifted feet y |
| Defeat | per-cell uniform | grounded uniform | Collapse is artist noise, normalize |
| Stun | per-cell uniform | grounded uniform | Vibration variance is artist noise |
| Skill (overhead VFX, e.g. spinning halo) | per-cell uniform + chibi-face upscale to walk-alpha+ | grounded uniform | Halo dominance shrinks chibi visually — over-correct upscale |
| Skill (strike, e.g. paengi) | per-cell uniform + chibi-face midpoint upscale | per-cell preserved | Same as attack — pose variance natural |

The chibi-face upscale step (per attack v9 → v11 / idle v1 → v2 / whip
v1 → v2 / victory v1 → v2 / paengi v1 patterns) targets:
- **Default**: chibi body gp at midpoint between walk-chibi (~78 gp)
  and walk-alpha (~89 gp) — about **84 gp**
- **Overhead VFX sheets** (spinning halo, aura ring, charge field):
  chibi body gp at walk-alpha or slightly above — about **88-92 gp**
  (over-correct for VFX visual contrast that shrinks the chibi)

### 17.5. Per-sheet runtime mapping pattern

| Sheet | Lifecycle owner | Frame mapping |
|---|---|---|
| Walk L / R | direction state | per-frame index advance |
| Idle | wall-clock time | `(get_ticks() // 250) % 8` (2 sec breath cycle) |
| Attack | internal timer + Menhera-style trigger | F5 = strike apex, anticipatory pre-contact |
| Turn | facing-edge triggered | short subset of frames, returns to walk |
| Dash | external timer (`boss_dash_timer`) | slide-sustained: F1/F2 brief intro, F3/F4 dominate |
| Victory | internal timer + Menhera-style trigger | plays once, holds on F8 |
| Defeat | internal timer + Menhera-style trigger | plays once, holds on F8; trigger_defeat clears is_victorious |
| Stun | external timer (`boss_stunned_timer`) | `(get_ticks() // 80) % 8` (640ms loop) |
| Skill (external-driven, e.g. whip / paengi) | existing skill timer | progress-based or angle-based mapping |
| Skill (internal-driven, e.g. spin) | new internal timer | one-shot, holds on last frame |

### 17.6. Render priority chain (highest first)

```
defeat > victory > stun > dash > skill-specific > walk/attack/turn > idle
```

- Defeat at the top — boss who just lost cannot suddenly celebrate
  or dash. `trigger_defeat()` should actively clear `is_victorious`
  to enforce this.
- Game-end animations (defeat/victory) ALWAYS win.
- Stun beats movement and skills (a stunned boss can't act).
- Dash beats walk/attack (slide pose during high-velocity travel).
- Skill-specific sheets (e.g. paengi strike, whip yaw rotation) beat
  walk/attack/turn for their active window.
- Idle is the floor — fallback for "nothing else is happening".

### 17.7. Sprite class wiring template

For each new sheet beyond walk pair, the sprite class needs:

Legacy Python/Pygame reference template only. For current runtime promotion,
map the same sheet metadata to the owning Godot renderer/catalog and asset
path under `godot/`.

```python
# In __init__:
self.frames_<name> = []
self._scaled_frames_<name> = []
self.<name>_total_frames = 8
# Internal-timer sheets also need:
self.is_<name> = False
self.<name>_frame = 0
self.<name>_timer = 0.0
self.<name>_animation_speed = 0.18  # sec per frame
self.<name>_finished = False

# Also in __init__:
<name>_path = resource_path(os.path.join("assets", "[name]_boss_<name>.png"))
self.load_<name>_sprite_sheet(<name>_path)

# Loader: copy the load_attack_sprite_sheet() / load_turn_sprite_sheet() pattern.
# Getter: copy the get_dash_frame() / get_stun_frame() / get_victory_frame() pattern
# depending on whether the sheet is external-timer or internal-timer driven.
# Cache: extend _build_scaled_cache() with one more rebuild flag + branch.
```

For internal-timer sheets (attack/victory/defeat), also add a branch
to `update()` that advances the frame and clamps when finished. For
victory/defeat specifically, victory_finished/defeat_finished and the
mutual-exclusion check (defeat clears is_victorious) are required.

### 17.8. Legacy Python reference — `pingfighter.py` wiring template

Each non-walk sheet overrides `boss_img` in the stage's render branch:

```python
if <skill_active_condition>:
    _img = boss_sprite.get_<name>_frame(<args>, (boss_w, boss_h))
    if _img is not None:
        boss_img = _img
        boss_img_prescaled = True
```

Place the override blocks in **reverse priority order** (lowest priority
first, highest priority last) so each higher-priority condition writes
on top of the previous boss_img.

### 17.9. Runtime promotion / hand-off requirements

For each new sheet, the runtime promotion note or legacy cross-agent
hand-off (`prompts/handoff_codex.md` template) must include:
- Asset path + md5
- Sheet category (basic 7 / boss combat / optional / skill-specific)
- Post-processing pattern used (which row of §17.4)
- Runtime mapping pattern (which row of §17.5)
- Priority position (where it sits in §17.6 chain)
- Identity locks vs walk pair anchor
- Cross-sheet QA result (gp body match)
- Backup file paths

---

## Appendix A. Angled walk / full side-facing walk -- interesting experiment, not preferred default

Angled walk sheets (multiple facing directions inside the walking cycle)
and full side-facing walk sheets are treated as **interesting experiments,
not the preferred default** for DiskHearts - Ringpia human / chibi bosses.

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
