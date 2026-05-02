# Boss Sprite Runtime Contract

This document is the shared runtime vocabulary for boss sprite sheets in
PingFighter. It exists to keep asset names, gameplay events, and renderer
keys from drifting apart across the Python runtime and the Godot port.

Authority split:
- Asset generation, prompts, nukki, and sheet QA:
  `.claude/skills/sprite-generation/`.
- Python runtime integration, performance, and gameplay verification:
  `AGENTS.md`.
- Godot module boundaries and mirror/live sync rules:
  `docs/godot_port_architecture.md`.
- Per-boss accepted sheet notes:
  `docs/sprites/stage1_dalji.md` and future `docs/sprites/stageN_*.md`
  files.

## State Vocabulary

Use the gameplay meaning below when naming runtime keys or wiring event
handlers. Do not infer semantics from a historical variable name alone.

| Runtime state | Gameplay meaning | Normal asset | Trigger owner |
|---|---|---|---|
| `walk_left` | Boss moves left | `[name]_boss_walk_left.png` | movement/facing state |
| `walk_right` | Boss moves right | `[name]_boss_walk_right.png` | movement/facing state |
| `idle` | Boss is stationary and no higher-priority animation is active | `[name]_boss_idle.png` | renderer/animation idle timer |
| `attack` / `ball_contact` | Boss strikes or returns the ball | `[name]_boss_attack.png` | ball-contact prediction and/or paddle-bounce event |
| `dash` | Boss is in a dash/fast slide | `[name]_boss_dash.png` | dash timer/state |
| `turn` | Short facing-change accent | `[name]_boss_turn.png` | facing-edge state |
| `victory` | Boss won the round/game | `[name]_boss_victory.png` | match result flow |
| `defeat` | Boss lost the round/game | `[name]_boss_defeat.png` | match result flow |
| `stun` | Boss is incapacitated/electrocuted/frozen by a real stun source | `[name]_boss_stun.png` | stun timer/status effect |
| `skill:<id>` | Boss-specific skill animation | `[name]_boss_<id>.png` | skill timer/state |

## Hit vs Stun

`hit` is ambiguous and must be treated carefully:

- `boss_hit_sprite_sheet` in older Godot code is a compatibility key for
  **boss ball-contact attack**, meaning "the boss hit the ball."
- It must not be mapped to `[name]_boss_stun.png`.
- Real stun/electrocution must use a separate key/state such as
  `boss_stun_sheet`, `boss_stunned_timer`, or an explicit future Godot
  stun-state context.
- Paddle-bounce handlers should ask for `boss_attack_sheet` first. They
  may fall back to `boss_hit_sprite_sheet` only because older modules use
  that name for ball-contact animation.

Before signing off a boss sprite port, search both Python and Godot for:

```text
boss_hit_sprite_sheet
boss_attack_sheet
boss_stun_sheet
boss_stunned_timer
```

Then confirm the ball-contact path selects attack and the stun path selects
stun. This is a required regression check, not a cosmetic naming cleanup.

## Priority Model

When a boss has the full sheet set, use this conceptual priority from
highest to lowest:

```text
defeat > victory > stun > dash > skill-specific > attack > turn > walk > idle
```

Notes:
- Game-end states always win.
- Stun wins over movement and normal attacks because the boss cannot act.
- Dash or boss-specific skill sheets may temporarily override attack if
  that is the shipped gameplay behavior for that boss.
- Attack should be aligned to the gameplay event. For contact strikes with
  visible prep, use a short anticipatory trigger so the impact frame lands
  near ball contact, with a ball-contact fallback when prediction misses.

## Godot Port Keying

Godot modules should prefer explicit texture keys:

| Key | Meaning |
|---|---|
| `boss_walk_left_sheet` | movement-left walk sheet |
| `boss_walk_right_sheet` | movement-right walk sheet |
| `boss_idle_sheet` | idle loop |
| `boss_attack_sheet` | ball-contact attack |
| `boss_stun_sheet` | real stun/electrocution loop |
| `boss_hit_sprite_sheet` | legacy compatibility alias for ball-contact attack only |

If a Godot port introduces a real stun renderer, it must read
`boss_stun_sheet` or a clearly named equivalent, not
`boss_hit_sprite_sheet`.

## Verification Checklist

For every boss sprite runtime integration or Godot port:

- Asset paths resolve through the runtime loader (`resource_path()` in
  Python, `res://` plus `ProjectResourceLoader` in Godot).
- Every sheet is sliced with its real grid/cell size; do not drop a new
  4x2 sheet onto an old slicer.
- Attack and stun are tested as separate events.
- Stable movement still uses walk sheets, not turn sheets.
- Runtime mirror/live Godot files are hash-matched when the live project
  is outside the repo.
- A headless load check has proven the runtime can load the selected
  textures.
