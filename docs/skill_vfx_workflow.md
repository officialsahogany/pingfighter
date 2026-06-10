# Skill VFX Workflow

This document is the shared Claude / Codex workflow for imagegen assets,
Live2D-style assets, and modular 2D skill / VFX work in the Godot project.
It complements `CLAUDE.md`, `AGENTS.md`, and the Godot VFX remaster policy in
`docs/godot_port_architecture.md`.

## Tool Boundary

- Claude leads aesthetic direction: effect concept, mood, palette, silhouette,
  role-by-role layer recipe, prompt wording, alpha / nukki visual review, and
  the final "does this look right" pass.
- Codex leads executable delivery: Codex imagegen or Live2D-style asset
  generation when used, copying accepted files into `godot/`, `res://` loader
  and prewarm wiring, shader family presets, `GPUParticles2D`,
  `Tween` / `AnimationPlayer`, audio, hitstop, camera shake, flash, lifecycle
  cleanup, and automated / live verification.
- Human review remains important for visual taste, alpha edges, character read,
  and whether a generated asset actually fits the intended identity.

The split is repository policy, not tool-local memory. Durable rules belong in
repo docs so a later Claude or Codex session sees the same standard.

## Default VFX Shape

New 2D skill / boss / item VFX defaults to modular VFX layering:

- Static PNG texture pieces provide readable identity.
- Runtime composition places those pieces in phase-specific z-order.
- Shader uniforms, particles, and tweens make the static pieces move.

The canonical starting template is:

| Piece | Role | Typical host |
|---|---|---|
| Backplate | mood, depth, presence | `TextureRect`, `ColorRect`, or `Sprite2D` |
| Particle texture | density, sparks, motes, debris | `GPUParticles2D` |
| Arc / trail segment | rhythm, direction, impact accent | `Sprite2D` or draw-layer texture |

Three pieces are a baseline, not a hard cap. Effects may grow to more texture
layers and more particle layers when the visual read requires it. For smoke,
flame masses, dust clouds, explosion clouds, or any effect where the changing
shape itself is the visual identity, use a flipbook or sprite sheet alongside
the modular pieces instead of forcing everything into three static PNGs.

## Shader Policy

- Prefer reusable shader families with per-effect presets over one-off inline
  shader code.
- Use `WritheEmberMaterial` presets when the effect is a bright alpha-backed
  texture that can share UV writhe, flow, flicker, chroma, breath, or color-ramp
  behavior.
- Create a new shader family only when the effect needs behavior that cannot be
  represented cleanly as a preset on an existing family. New families should
  still expose reusable uniform presets.
- Do not paste a fresh inline `ShaderMaterial` into each skill just to vary
  colors or speeds.

## Host Selection

Follow the current FX host's type and coordinate space:

- Control-based overlay or cinematic hosts use `TextureRect`, `ColorRect`, and
  full game-canvas `clip_contents = true` containers where appropriate.
- Node-based battle FX hosts use `Node2D`, `Sprite2D`, `GPUParticles2D`, and
  node transforms / `z_index`.
- Do not force `TextureRect` into a `Node2D` pipeline, or force `Sprite2D` into
  a Control overlay, unless the surrounding owner already uses that pattern.

## Host Coordinate Reality

Choose coordinates by where the host is parented, not by what the effect looks
like:

- Battle playfield detached hosts use the battle layout transform:

```gdscript
screen_pos = game_offset + (playfield_pos + shake_offset) * render_scale
```

- UI `Control` hosts, including menus, character select, settings, pause
  overlays, and `LivePreview`-style child panels, use the owning `Control`'s
  local rect coordinates. Stay inside the parent's `clip_contents` boundary
  when the parent clips its children.
- Fullscreen cinematic overlays authored in game coordinates render inside a
  Control whose local rect matches the full game canvas and has
  `clip_contents = true`.

Do not apply the battle playfield `game_offset` / `render_scale` formula to UI
Control panels such as character select. Do not rely on a legacy 80 px pillar
inset to prevent letterbox leaks.

## Runtime Checklist

Before calling a VFX implementation done:

- Load visual resources through `res://` paths and existing resource helpers.
- Prewarm textures, shaders, materials, and runtime nodes on a staged or
  documented safe path. Do not build large caches in hot `_draw()` /
  `_process()` paths or on the first visible battle frame.
- Drive shader intensity, particle emission, scale, alpha, and tween state from
  the owning phase clock or explicit phase transitions.
- Keep blend intent clear: additive for light / glow / energy, mix for solid
  matter such as leaves, talismans, cracks, or debris.
- Verify generated PNG alpha margins, transparent corners, and absence of baked
  checkerboard or square-edge residue.
- Avoid `draw_set_transform(IDENTITY)` leaks and restore `canvas.material` after
  any immediate-mode material pass.
- Give every persistent or pooled FX host a direct hide / `set_active(false)` /
  `tear_down()` path for round reset, score event, serve wait, stage transition,
  full reset, character / item swap, and explicit cancel.
- Include audio, hitstop, camera shake, flash, and HUD timer feedback when the
  effect needs them to read as the same gameplay event.

## Verification

Use the narrowest focused checks available, but do not skip the repo baseline:

- Run `.\tools\run_headless_load_check.ps1` from `godot/` after Godot code or
  asset import changes.
- Run `.\tools\run_warning_scan.ps1` from `godot/` after `.gd` edits.
- Add or update focused smoke tests for resource loading, lifecycle cleanup,
  host visibility, coordinate invariants, and audio loop cleanup when the
  touched path owns those risks.
- For visible VFX changes, perform a scaled or windowed live visual check when
  feasible. Headless checks do not prove GPU node positions, clip behavior,
  alpha edge quality, or render-scale alignment.

## Handoff Shape

Claude-side art handoff should name:

- texture pieces and their roles;
- palette, silhouette target, and prompt notes;
- blend intent for each layer;
- alpha / nukki / margin status;
- any suggested shader preset mood or timing.

Codex-side runtime handoff should name:

- final asset paths under `godot/`;
- loader / prewarm path;
- layer manifest, blend modes, z-order, and owning phases;
- shader family and preset names;
- particle layers and tween / animation envelopes;
- audio / hitstop / shake / flash hooks;
- cleanup paths and tests run.
