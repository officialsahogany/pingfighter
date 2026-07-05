# Stage 1 Gaksital Sprite Notes

This is the compact runtime contract for the Stage 1 Gaksital / 각시탈
variant in the current Godot project, DiskHearts - Lingpia.

Current status: asset export only. Runtime wiring is still a later slice.
The active runtime target remains the repo-local Godot project under
`godot/`.

## Asset Root

Accepted assets live under:

`godot/assets/sprites/stage1/gaksital/`

The authoritative metadata file is:

`godot/assets/sprites/stage1/gaksital/gaksital_boss_sprite_manifest.json`

Do not infer a shared grid. Use the manifest's per-sheet
`cols`, `rows`, `frames`, `cell_width`, and `cell_height` values.

## Asset Set

| State | Runtime asset | Layout |
|---|---|---|
| Walk left | `gaksital_boss_walk_left_front_sidestep_16f_mirrored_from_right_v3_pro.png` | 1024x1024, 4x4, cell 256x256, 16 frames |
| Walk right | `gaksital_boss_walk_right_front_sidestep_16f_autosprite_v3_pro.png` | 1024x1024, 4x4, cell 256x256, 16 frames |
| Idle | `gaksital_boss_idle_8f_autosprite_v1_pro.png` | 768x768, 3x3, cell 256x256, 8 used frames |
| Attack / ball contact | `gaksital_boss_attack_8f_autosprite_v1_pro.png` | 768x768, 3x3, cell 256x256, 8 used frames |
| Dash | `gaksital_boss_dash_8f_autosprite_v1_pro.png` | 768x768, 3x3, cell 256x256, 8 used frames |
| Stun | `gaksital_boss_stun_8f_autosprite_v1_pro.png` | 768x768, 3x3, cell 256x256, 8 used frames |
| Victory | `gaksital_boss_victory_round_8f_autosprite_v2_pro.png` | 768x768, 3x3, cell 256x256, 8 used frames |
| Defeat | `gaksital_boss_defeat_round_8f_autosprite_v2_pro.png` | 768x768, 3x3, cell 256x256, 8 used frames |
| Skill: fan_throw | `gaksital_boss_fan_throw_16f_autosprite_v1_pro.png` | 1024x1024, 4x4, cell 256x256, 16 frames |

The 8-frame sheets use an AutoSprite 3x3 export with one unused transparent
cell. Runtime loaders must stop at frame 8.

## Identity

Fixed elements:

- Red Hahoe-style mask
- Black topknot hair
- Saekdong rainbow-striped jeogori
- White pants
- Chibi 16-bit pixel-art body with thick black outline

The fan prop is intentionally not held during walk or idle. AutoSprite
repeatedly dropped the held fan in locomotion/idle attempts, while the
`fan_throw` skill sheet retained it clearly. Treat the fan as a skill identity
prop carried by the fan_throw sheet, later projectile VFX, and later HUD card.

## Walk Direction Note

The current accepted right walk is AutoSprite source sheet
`cmr5ctxud005pcgpw9njnf17i`, generated as a front-biased sidestep so horizontal
movement reads like other Stage 1 bosses instead of a strict profile walk.

The runtime left asset is a deterministic per-cell mirrored PNG export from the
accepted right sheet. This is a stored runtime file, not runtime horizontal
flipping, and the 4x4 frame order is preserved. If a future regeneration
produces a true native left walk that matches the same front-biased identity,
replace this file and update the manifest.

## Runtime Priority

Use the shared boss sprite priority model:

```text
defeat > victory > stun > dash > skill-specific > attack > walk > idle
```

For Gaksital, `skill-specific` currently means `fan_throw`.

## Provenance

AutoSprite character:

`cmqpewcsl003911vifeko0cwj`

Accepted source IDs, SHA-256 hashes, and notes are recorded in
`gaksital_boss_sprite_manifest.json`.

Preview montage:

`godot/assets/sprites/stage1/gaksital/gaksital_sprite_set_preview.png`

## Skill VFX Assets (fan_throw)

| Asset | Runtime file | Use |
|---|---|---|
| Fan projectile sprite | `gaksital_fan_projectile_imagegen_v1.png` | 256x256 RGBA. The thrown fan. Draw small (~hit_radius 24 band) and **rotate about texture center** at runtime by the per-frame fan spin (Python `_draw_fan_shape` parity). Square 1:1 canvas + centered fan avoids the continuous-rotation tumble trap. |
| Fan_throw skill HUD card | `gaksital_fan_throw_skillcard_imagegen_v2.png` | 408x120 RGBA, ~3.4:1, for the boss skill HUD gauge rect. No baked text/gauge bar — the HUD draws its own cooldown fill. |

Both are Gemini imagegen (non-sheet imagegen rule), recorded with sha256 /
source in the manifest under `skill_vfx_assets`. Both need a Godot re-import.

Boss-skillcard parity note: the Dalji boss skillcards referenced by
`stage1_dalji_boss_skill_hud_assets.gd`
(`res://assets/sprites/hud/stage1_dalji_*_skillcard_imagegen_v1.png`) do NOT
exist on disk (reserved null paths -> the HUD falls back to a plain gauge). The
Gaksital card above defines a new boss-skillcard style; for HUD consistency,
Dalji should get a matching card in a later pass, or Gaksital can run the same
null/fallback until then. Verify the `_draw_skillcard_gauge` fill interaction
when wiring the fan_throw HUD in Phase 3.


## Skill VFX Assets (fan_wind, 2026-07-03)

| Asset | Runtime file | Use |
|---|---|---|
| Fan_wind vortex effect sheet | `gaksital_fan_wind_vortex_16f_autosprite_v1.png` | 1024x1024, 4x4 grid, 16f loop, 256px cells (grid recorded in manifest -- per-asset authority). AutoSprite-derived (asset `cmr4ypt2a000fhx2c1mkf4j78`, looping animate + ultra removeBg). Texture key `boss_fan_wind_sheet`; drawn by `stage1_gaksital_fan_throw_renderer._draw_fan_wind_sheet` -- frame index from `spin_phase` (TAU -> 16 frames), draw diameter `128 * growth_scale`, alpha fades over the last 30f. The procedural vortex remains the null-texture fallback; capture ring / orbit ball accents stay procedural on top in both modes. |
| Fan_wind skill HUD card | `gaksital_fan_wind_skillcard_imagegen_v1.png` | 408x120 RGBA opaque, ~3.4:1, same authoring target as the fan_throw card. No baked text / gauge bar. Wired at `FAN_WIND_SKILLCARD_TEXTURE_PATH`. |

Both recorded with sha256 / provenance in the manifest (`skill_vfx_assets`).
Both need a Godot re-import after landing.
