# Codex Handoff: Menhera Turn Runtime Migration V1

Use this after the asset-side `R1` decision is accepted.

## Asset Decision

- Runtime turn candidate: `turn V3`
- Asset role: runtime-only auxiliary turn sheet
- Non-anchor rule: `turn V3` must **not** become a future identity anchor
- Sole identity anchor remains:
  - `items/menhera_boss_sheet.png`

See:
- [menhera_turn_r1_decision.md](/d:/main/bosspong/.tmp/menhera_turn_r1_decision.md)

## Required Runtime Change

Current loader still assumes the old `8x1` Menhera turn layout:
- [entities/menhera_boss_sprite.py](/d:/main/bosspong/entities/menhera_boss_sprite.py:48)
- [entities/menhera_boss_sprite.py](/d:/main/bosspong/entities/menhera_boss_sprite.py:49)
- [entities/menhera_boss_sprite.py](/d:/main/bosspong/entities/menhera_boss_sprite.py:50)

Before swapping runtime assets, change the loader from:
- `TURN_GRID_COLS = 8`
- `TURN_GRID_ROWS = 1`
- row-0-only `TURN_FRAME_ORDER`

To a `4x2` loader matching the new FLUX packaging:
- `TURN_GRID_COLS = 4`
- `TURN_GRID_ROWS = 2`
- explicit 8-frame order:
  - `(0,0),(1,0),(2,0),(3,0),(0,1),(1,1),(2,1),(3,1)`

Do not rely on implicit row-major assumptions; keep the intended playback order
spelled out explicitly.

## Safe Migration Order

1. Keep `RENDER_TURN_FRAMES = False`.
2. Update the `4x2` turn loader and `TURN_FRAME_ORDER`.
3. Point runtime at the new `items/menhera_boss_turn.{jpeg,png}` pair.
4. Run local playback QA with visible turn playback temporarily enabled.
5. Validate slicing, scale, reconnect, and no face clipping.
6. Return shipping default to `RENDER_TURN_FRAMES = False` unless the user
   explicitly wants visible turn playback enabled right now.

## Playback QA Checklist

- correct `4x2` slicing on all 8 frames
- no accidental use of wrong row/column order
- no face clipping after load / trim / scale
- body read stays aligned with walk
- f7 -> f8 -> walk reconnect remains natural
- no stable-walk hijack
- hop-only fallback behavior remains safe if visible turn playback is disabled

## Policy Guardrail

When documenting or handing off this work, keep the terminology split:

- canonical walk = sole identity anchor
- turn V3 = runtime playback auxiliary sheet

Do not describe `turn V3` as a "canonical turn anchor."

## Rollback

If runtime playback QA fails:
- keep existing hop-only fallback
- keep `RENDER_TURN_FRAMES = False`
- retain old `8x1` turn asset as rollback backup
