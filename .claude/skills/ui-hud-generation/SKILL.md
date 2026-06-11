---
name: ui-hud-generation
description: |
  Image-generation pipeline for DiskHearts - Ringpia fullscreen / pillar HUD frame
  art. Covers bottom unified HUD frames, pillar backplates, orb collars,
  dash-token decorative frames, active-item slot trays, transparent PNG
  prep, source-anchor measurement, reject / regenerate checks, and handoff
  notes for Codex runtime alignment in AGENTS.md. Use this skill whenever
  the user asks to draw, redesign, regenerate, or clean up large HUD chrome
  rather than item icons or boss / character sprites.
---

# UI HUD Generation Pipeline (DiskHearts - Ringpia)

This skill owns generated bitmap art for large Godot **디스크하츠 - 링피아**
HUD chrome. Original Python/Pygame PingFighter HUD art is legacy reference
material for porting and visual parity only.

Current scope:
fullscreen bottom HUD frames, pillar backplates, orb collars, dash-token
frames, active-item slot trays, and matching rails / lower aprons.

Runtime integration is NOT covered here. After the asset is accepted,
use `AGENTS.md` plus the relevant Godot runtime owner for PNG-first loading,
source-anchor constants, region caching, live coordinate alignment, and
screenshot QA.

## 1. Scope Boundary

Use this skill for:

- bottom unified HUD frames that wrap left / right orb gauges and the
  active-item slot tray
- left or right pillar background frames / backplates
- decorative orb collars or dash-token frame art
- generated rails, lower aprons, slot trays, and full-width HUD chrome
- alpha cleanup and source-anchor handoff for those HUD assets

Do NOT use this skill for:

- boss / character walk, attack, dash, turn, or victory sheets
  (`sprite-generation`)
- active / passive / legendary item icons or character equip visuals
  (`item-generation`)
- item runtime registration / reward routing (`docs/item_runtime_checklist.md`)
- character perk / 5-orb runtime wiring
  (`docs/character_skill_perk_checklist.md`)

Upscaling override:
- If the user asks to "upscale", "upscaling", "hires", "업스케일",
  "업스케일링", or "real / Real-ESRGAN처럼" for HUD chrome, pillar art,
  orb collars, slot trays, or any other bitmap HUD asset, run the
  Real-ESRGAN upscale gate in
  `.claude/skills/sprite-generation/checklists.md` §0.1.
- Do not treat runtime scale changes, slice/stretch placement, Godot import
  filtering, ordinary resampling, or imagegen repainting as completion of
  an upscale request.
- Preserve transparent holes, corners, and measured anchors by upscaling
  RGB separately from alpha, recombining the resized source alpha, and
  remeasuring anchors on the final upscaled PNG.

## 2. Lessons From The Bottom Unified HUD Pass

The frame should be designed for PingFighter first, not as a Diablo clone.
Keep the visual language clean, mechanical, readable, and game-specific:
dark graphite / steel body, restrained gold bevels, blue energy accents,
compact jewel details, and no skull / demon / gothic overstatement unless
the user explicitly asks for that theme.

Avoid the failed patterns:

- generating separate left orb, right orb, rail, and slot pieces that look
  related but do not actually meet at runtime
- simply stretching an old frame downward to fill bottom whitespace
- drawing a new frame on top of the old active-slot panel / old rails
- making orb holes or slot wells that do not match the real gauge / slot
  sizes
- making the lower HUD so tall that it covers the player paddle or game
  action
- copying a reference game's exact silhouette, demon heads, or layout
  language too closely

The good pattern is one coherent generated source image with all visual
motifs designed together. Runtime may still slice rails / lower body /
orb modules / slot tray from that one source to fit the actual fullscreen
geometry, but the source art should read as one intentionally connected
HUD frame.

## 3. Prompt Requirements

For a bottom unified HUD frame, ask for:

- one wide, clean, cohesive PingFighter sci-fi arcade HUD frame
- left circular orb collar and right circular orb collar integrated into
  one continuous bottom bar
- a central recessed active-item slot tray with evenly spaced square wells
- side rails and lower apron that visually fill the bottom whitespace
- transparent-looking orb holes and slot wells, with closed clean rims
- no text, numbers, icons, characters, game scene, watermark, or logo
- no old screenshot background; use a flat removable chroma-key background
- no cast shadows or floor plane
- generous padding around the full frame so alpha cleanup does not clip
  bevels or glows

Suggested prompt skeleton:

```text
Create a wide integrated bottom HUD frame for the game PingFighter on a
perfectly flat solid #00ff00 chroma-key background for background removal.

The design is clean sci-fi arcade UI chrome: dark graphite and polished
steel frame, restrained warm gold bevel lines, crisp blue energy accents,
small red / blue jewel nodes, high-contrast readable pixel-game styling.
It must feel original to PingFighter, not Diablo, not gothic, not demonic.

Composition: left circular orb collar, right circular orb collar, and a
central active-item slot tray are all connected by one continuous bottom
rail and lower apron. The left and right orb holes are empty transparent
spaces with closed circular rims. The center tray has evenly spaced square
item wells, sized consistently, with enough lower frame mass below them so
the bottom does not look hollow.

No text, no numbers, no icons, no characters, no gameplay screenshot, no
watermark. Background must be exactly flat #00ff00 with no gradient,
shadow, reflection, texture, or floor plane. Do not use #00ff00 anywhere
inside the HUD frame.
```

For a small orb / dash-token frame, keep the same material language and ask
for a centered circular ring with a transparent hole, not a full UI panel.

### Layered Pillar Background Asset Sets

For stage pillar backgrounds that include scenery, atmosphere, or
reactive props, generate a coordinated imagegen layer set instead of one
flat screenshot-like picture.

World premise:

- PingFighter takes place inside a full-immersion virtual reality. Stage
  themes may differ wildly, but every pillar background should preserve a
  shared cyberpunk / parallel-universe signal.
- Blend the stage-specific theme with restrained virtual-world motifs:
  holographic seams, neon circuitry, dimensional rifts, data-glitch
  accents, scanline light, synthetic particles, or impossible
  parallel-world overlays.
- The cyberpunk / parallel-universe layer should feel integrated into the
  local theme. Do not erase the stage identity, and do not make every
  stage read as the same generic neon city.

Required set:

- `base`: one clean static fullscreen / pillar backdrop PNG. It should
  establish the left, bottom, and right pillar background as one coherent
  scene, but omit any object that should move independently.
- `motion_sprites`: transparent sprite sheet(s) for slow ambient elements
  such as clouds, mist, drifting paper, water shimmer, lantern glow, or
  other repeating atmosphere.
- `reactive_sprites`: transparent sprite sheet(s) for objects that should
  respond to gameplay, such as left / right trees shaking on wall impact,
  banners fluttering, hanging ornaments, dust bursts, or stage-specific
  environmental props.

Outer picture-frame borders:

- When the user asks for an "outer frame", "picture-frame border", or a
  border that decorates the central background, design it as pillar chrome
  around a transparent central gameplay window. It should not be a frame
  painted inside the gameplay field.
- The accepted composition is: left and right vertical posts live in the
  side pillar regions, top and bottom rails live in any available top /
  bottom pillar bands, and the central gameplay rectangle stays empty /
  transparent. The frame visually wraps the field from outside.
- Author the frame so runtime can fit live geometry: keep side posts,
  top rail, bottom rail, and corner joints readable under independent X/Y
  scaling or slice-and-stretch placement. Do not make the source so tall
  that preserving aspect ratio is required for the design to read.
- Keep the border minimal enough that it supports the stage pillar
  background without covering the ball, paddles, boss, or central action.

Prompt the base layer with explicit exclusions:

```text
Create the static base layer only for a PingFighter stage pillar
background. It must feel like one unified left, bottom, and right pillar
scene around a transparent central gameplay field.

Do not include the elements that will be animated as separate sprites:
no moving clouds, no foreground trees, no shake-reactive props, no
particles, no gameplay objects, no characters, no text, no watermark.
Keep the composition clean enough for transparent sprite layers to be
drawn on top.
```

Prompt outer picture-frame borders like this:

```text
Create an outer picture-frame border for a PingFighter stage pillar
background on a perfectly flat solid #00ff00 chroma-key background for
background removal.

The border must wrap around a transparent central gameplay rectangle from
the outside: left and right vertical posts for the side pillars, top and
bottom rails for the pillar bands, clean corner joints, and a completely
empty central window. It must not include a gameplay screenshot, field
background, characters, text, numbers, or icons.

Keep the frame minimal, readable, and slice-friendly. The top and bottom
rails must remain visibly present after runtime scaling to the live game
area. No cast shadow, no floor plane, no watermark, and do not use #00ff00
inside the frame.
```

Prompt sprite sheets on a flat chroma-key background:

```text
Create separate transparent-ready sprite assets for the same PingFighter
stage pillar background on a perfectly flat solid #00ff00 chroma-key
background. Arrange the sprites in an evenly spaced sheet with generous
padding. No shadows, no floor plane, no text, no watermark, and do not use
#00ff00 inside the sprites.
```

Asset-side checks:

- The base, motion sprites, and reactive sprites must share the same
  visual language, palette, lighting, and stage theme.
- Sprite sheets should contain separated cells with enough padding for
  alpha cleanup and trimming.
- Keep side-specific props, such as left tree and right tree, in known
  cell positions so runtime can slice them deterministically.
- Avoid baking motion blur, ghosted duplicates, or blurry duplicate
  silhouettes into the sprite. Runtime should create motion by moving the
  layer, not by showing a hazy copied patch.
- Hand off the final base PNG, source chroma-key sprite sheet(s), cleaned
  alpha sprite sheet(s), expected cell grid, intended draw order, and
  which sprites are ambient versus event-reactive.

## 4. Transparent Prep

Default path:

1. Generate on flat `#00ff00` or another safe chroma key.
2. Copy the selected source into `images/ui/hud/` with a versioned
   `_source.png` suffix.
3. Run the chroma-key remover
   `py .claude/skills/sprite-generation/chroma_key.py <src> <dst.png>`
   (auto-detects `#00ff00` green or `#ff00ff` magenta; border-seeded
   flood-fill + 2-ring halo kill + edge despill + alpha-bbox crop).
   **Do NOT use `remove_bg.py` for a chroma source** — it only keys
   WHITISH / neutral-gray-checker backgrounds and leaves a green/magenta
   source FULLY OPAQUE (every corner stays alpha 255, no error). `green`
   is the tested path (result-scroll v2); pass `--key magenta` for
   magenta sources. Cyan neon edges survive green keying because
   dominance is `g - max(r, b)`.
4. Save the alpha-prepped output with a versioned `_alpha.png` suffix.
5. Crop to the alpha bbox with a small padding and save the runtime PNG
   with the clean versioned name.

Keep source / alpha / runtime siblings when the asset will be iterated:

- `images/ui/hud/<name>_imagegen_vN_source.png`
- `images/ui/hud/<name>_imagegen_vN_alpha.png`
- `images/ui/hud/<name>_imagegen_vN.png`

Validate the runtime PNG:

- alpha channel exists
- all four corners are transparent
- alpha bbox does not touch the image edge unless intentional
- no chroma fringe remains on bevels, blue lights, or jewel edges
- orb holes and slot wells are transparent or cleanly dark, according to
  the requested runtime plan

## 5. Source Anchor Handoff

Before handing the asset to runtime, measure and record:

- final runtime PNG size
- alpha bbox of the source and cropped runtime PNG
- left orb-hole center and right orb-hole center
- for outer picture-frame borders: central transparent window rect, left /
  right post widths, top / bottom rail heights, corner joint rects, and
  whether the design expects independent X/Y scaling or slice-stretched
  rails instead of aspect-preserving full-image scaling
- left / right module rects if the runtime may slice modules
- top rail, center body, lower apron, and bottom rail source rects
- slot tray source rect
- first slot well source position, slot pitch, slot well width / height,
  and max visible slot count
- vertical anchor used to align the generated frame to real orb centers
- current player skill orb radius, gauge-to-skill-orb gap, left pillar
  internal X inset, left pillar bottom inset, and dash-token bottom inset
  if the frame visually wraps or touches those orbs
- whether the current live game can show five skill orbs only, or six
  skill orbs with Heavenly Cape equipped

Closed transparent orb holes can be measured by finding connected
transparent components after chroma-key removal. The two large interior
transparent components usually correspond to the left and right orb holes.

Important handoff rule: if the generated full image aspect does not match
the real fullscreen bottom area, do not require Codex to blindly scale the
entire bitmap. Tell Codex to keep this one source as the visual authority,
but slice / stretch only repeatable spans such as rails, center body, lower
apron, and slot tray while anchoring orb modules to measured live centers.

Player skill orb placement is dynamic. The normal 5-orb layout has a
manual visual-gap correction for the 4th / 5th orb, and Heavenly Cape can
open a 6th orb with a slightly left-rotated dial: slot 1 sits lower and
slot 6 follows slot 5 without entering the map. If the generated HUD frame
includes skill-orb sockets, side ornaments near those orbs, or a left
pillar backplate that frames them, include enough clearance for both the
5-orb and 6-orb states.

## 6. Reject / Regenerate Checklist

Reject or regenerate if any of these are true:

- the left / right orb holes are visibly different sizes or not circular
  enough for the real gauges
- the frame only fits the current five skill orbs and would visibly clip
  or cover the Heavenly Cape sixth-orb layout
- the frame assumes old skill-orb / dash-token coordinates and leaves the
  current live orbs off-center inside their decorative sockets
- active-item wells are too large, too small, unevenly spaced, or too high
  for the live item icons
- the lower frame is mostly empty and still exposes the old pillar
  background where the user expects a filled base
- the frame is so tall that it covers the player paddle or central action
- the image reads as a direct Diablo copy rather than PingFighter UI
- the source contains text, numbers, item icons, game characters, or a
  baked screenshot
- the chroma key leaks into blue lights / greenish highlights
- the frame only works as a mockup and cannot provide measurable anchors
- an outer picture-frame border paints inside the central gameplay window,
  requires overlaying the center field, or loses the top / bottom rails
  when fitted to the live aspect ratio
- the user asked for upscaling but the final asset was only runtime-scaled,
  resized with a normal resampler, import-filtered, or repainted instead of
  passing the Real-ESRGAN gate

Accept only when the frame has a clean one-piece read at preview scale and
also has enough regular structure for runtime alignment.

## 7. Runtime Handoff Checklist

When the visual asset is accepted, hand off:

- final runtime PNG path
- source / alpha sibling paths if kept
- Real-ESRGAN tool / model / scale / source path details if the user asked
  for upscaling
- measured source anchors and rects
- measured live orb assumptions: skill orb radius / gap, 5-orb vs 6-orb
  support, dash-token inset, and left / right pillar offsets if relevant
- intended draw order: rails / lower fill first, orb modules over joins,
  slot tray over center wells when needed
- for outer picture-frame borders: draw from the pillar / background layer,
  clip out the live central gameplay rect, keep the center alpha-empty, and
  fit X/Y or slice rails to live geometry so all four sides stay visible
- whether the existing active-slot panel / borders should be suppressed
- whether item icons need a small vertical nudge to sit inside the wells
- required verification: Godot PNG resource load / import check,
  `.\tools\run_headless_load_check.ps1`,
  `.\tools\run_warning_scan.ps1`, and fullscreen screenshot / preview at
  the user's reported aspect ratio
- **`.import` sidecar gate (every newly staged PNG)**: a PNG copied into
  `godot/` is NOT staged until an import pass has generated
  `<file>.png.import` plus its dest `.ctex` under `.godot/imported/`.
  `run_headless_load_check.ps1` passing is NOT proof — the
  `ProjectResourceLoader` raw-PNG fallback decodes the source file
  directly, so editor / headless runs look correct while the export
  build can drop the texture entirely. Run an editor import pass (or
  `--headless --import`), verify the sidecar + ctex exist, and commit
  the `.import` together with the PNG. Reference miss: the character
  select chamber backplate (2026-06-11) shipped without its sidecar and
  passed every headless check.
- **atlas grid declaration (multi-cell sheets only)**: if the accepted PNG is
  a multi-cell atlas (lantern mirror pair, lotus pulse strip, dragon-head
  16-frame strip, motion ambient grid, etc.), the runtime handoff and the
  asset migration manifest MUST record the exact `(cols, rows)` and total
  frame count. Renderers slice via `draw_texture_rect_region` so a wrong grid
  silently slices unrelated cells into one rect — the in-game result reads as
  a box with stray fragments inside, not as a runtime error. Do NOT rely on
  a shared `SHEET_COLS = 4 / SHEET_ROWS = 4` assumption inherited from a
  previous stage; real Stage 5 홍련 atlases land as 2x1 / 8x1 / 16x1 / 3x2
  mixes. The asset manifest table should grow a `Grid` column for atlas PNGs
  (e.g. `2x1 mirror`, `8x1 horizontal strip`, `16x1 sheet`, `3x2`), and the
  owner module must declare per-asset `<NAME>_COLS / _ROWS / _FRAMES`
  constants. See AGENTS.md "Atlas sheet grid authority" for the runtime side.

Use this short handoff phrase:

```text
Use this HUD PNG as the single visual source. Runtime may slice repeatable
regions from it, but should not mix old HUD pieces underneath it.
```
