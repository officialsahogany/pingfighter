# Character Customization Direction

Status: accepted direction for Godot in-game player customization as of
2026-05-14.

This document applies to runtime player sprites in `godot/`. It does not
apply to character-select Live2D-style previews, cutscenes, boss dialogue
portraits, or large illustration animation tracks.

## Accepted Runtime Direction

- Keep character-specific base motion sheets. The common contract is timing,
  frame count, frame index, anchor points, and socket names, not one shared
  body animation for every character.
- Add customization through pose-locked overlay sheets drawn with the same
  `frame_index` as the base sheet.
- Extend the existing item visual-slot / `CharacterSkin.parts` style path
  when the runtime system is built. Do not create a separate equipment-visual
  lane that later has to be reconciled with item overlays.
- Do not use `Skeleton2D`, `Bone2D`, or cutout rigging for in-game player
  customization. Keep those techniques reserved for character-select
  previews, Live2D-style cutscenes, boss dialogue, and large portrait
  animation.

## Implementation Order

1. Define the Smasher slot contract first.
2. Decide the left/right sheet policy for every playable character before
   generating overlay art.
3. Build the Godot renderer prototype for Smasher only.

The first renderer prototype should only prove that base + overlay sheets
compose correctly. Full skin UI, full roster support, and hair/body
decomposition are later work.

Prototype debug hook: `F7` toggles a Smasher-only paddle overlay QA sheet in
Godot. This sheet is a temporary alignment marker, not production skin art;
final character / item overlay sheets still follow the AutoSprite-first asset
workflow.

## Smasher Slot Contract V1

Keep baked into the base sheet:

- Body / torso mass.
- Face and eye identity.
- Default head and hair silhouette.
- Default chibi proportions and limb silhouette.
- Any non-removable identity marks required by the canonical Smasher design.

Do not split these into independent customization layers in the first slice.
Hair and body separation can be revisited only after the simpler overlay path
is stable.

First overlay slots:

| Slot id | Existing-slot family | Purpose | V1 source strategy |
|---|---|---|---|
| `paddle` | weapon / accessory | Paddle or held striking prop | Pose-locked overlay sheet |
| `head_hat` | `head` | Hat, helmet accent, small head prop | Pose-locked overlay sheet |
| `back` | `back` | Back accessory, pack, wing, rear prop | Pose-locked overlay sheet |
| `accessory` | `accessory` | Small body-adjacent accessory | Pose-locked overlay sheet |
| `outfit_accent` | `top` | Trim, sash, badge, small costume accent | Pose-locked overlay sheet |

Suggested render order for the prototype:

1. `back`
2. base Smasher sheet
3. `outfit_accent`
4. `head_hat`
5. `accessory`
6. `paddle`

The order can become per-slot metadata if a real item needs to draw behind
or in front of a different layer.

## Overlay Data Contract

Prototype lookup keys:

- `character_id`
- `motion_id`
- `slot_id`
- `direction`

Every base and overlay sheet used together must agree on:

- motion id
- frame count
- frame interval
- grid rows / columns
- anchor origin
- source cell size or trim rect
- direction policy

Runtime composition rule: choose the current base frame, then draw every
visible overlay slot using that exact same `frame_index`.

## Direction Policy Table

These are the default art-routing decisions. Re-check a character before
generating final sheets if its accepted sprite design changes.

| Character | Runtime id | Base direction policy | Overlay policy |
|---|---|---|---|
| Smasher | `smasher` | `mirror_ok_v1` | Paddle mirrors OK. `head_hat`, `back`, `accessory`, and `outfit_accent` need separate L/R only when the prop is visibly asymmetric. |
| Viper | `viper` | `mirror_ok_likely` | No paddle by default. Back-view convention makes mirror viable unless a side-specific body prop is added. |
| Commando | `soldier` | `separate_lr_required` for firearm-facing sheets | Weapon and firearm overlays are separate L/R work. Do not revive weapon-only overlays until hand / arm / body perspective is revalidated. |
| Optimus / Io | `optimus` | `mirror_ok_likely` for the first in-game slice | Large paddle / energy body can mirror. Asymmetric mecha packs or one-sided props require separate L/R sheets. |
| Kohaku / Blacksmith / Baltor track | `blacksmith` or future runtime id | `separate_lr_likely` until audited | Hammer, shield, forge, back, or one-sided heavy props should default to separate L/R overlay sheets. |

Slot-level exceptions:

- `paddle`: mirror OK unless it has readable text, one-sided emblem placement,
  or a hand-side-specific grip.
- `head_hat`: mirror OK for centered hats and helmets; separate L/R for side
  ornaments, flowers, pins, or asymmetrical bangs.
- `back`: separate L/R when the prop is one-sided, diagonal, or tied to a
  visible shoulder.
- `accessory`: decide per item. Tiny centered accessories can mirror.
- `outfit_accent`: mirror only for centered trim; separate L/R for badges,
  one-shoulder pieces, text, or anatomy-locked markings.

## Prototype Acceptance Criteria

Smasher V1 is accepted only when:

- `idle`, `walk`, `dash`, and `attack` overlay frames stay within +/-1 px of
  their intended `head`, `hand`, and `back` sockets.
- Motion switches do not hide an active overlay for even one frame.
- Direction changes apply the same mirror or separate-sheet policy to base and
  overlays.
- The renderer falls back cleanly when an overlay sheet is missing.
- The path works with no Skeleton2D / Bone2D dependency.
