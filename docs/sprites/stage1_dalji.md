# Stage 1 Dalji Sprite Notes

This is the compact per-boss runtime contract for Stage 1 Dalji. The long
provenance and generation history still lives in `CLAUDE.md` for now, but
new runtime work should start here plus
`docs/sprites/boss_sprite_runtime_contract.md`.

## Asset Set

Python source assets live under `assets/`. The Godot mirror copies the same
runtime PNGs under `godot/assets/sprites/stage1/dalji/`; when testing the
live Godot project, sync that folder to
`C:\Users\woduq\Documents\pingfighter\assets\sprites\stage1\dalji\`.

| State | Python asset | Godot mirror asset | Layout |
|---|---|---|---|
| Walk left | `assets/dalji_boss_walk_left.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_walk_left.png` | 1376x768, 4x2, cell 344x384 |
| Walk right | `assets/dalji_boss_walk_right.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_walk_right.png` | 1376x768, 4x2, cell 344x384 |
| Idle | `assets/dalji_boss_idle.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_idle.png` | 1536x1024, 4x2, cell 384x512 |
| Attack / ball contact | `assets/dalji_boss_attack.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_attack.png` | 1536x1024, 4x2, cell 384x512 |
| Dash | `assets/dalji_boss_dash.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_dash.png` | 1536x1024, 4x2, cell 384x512 |
| Turn | `assets/dalji_boss_turn.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_turn.png` | 1536x1024, 4x2, cell 384x512 |
| Victory | `assets/dalji_boss_victory.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_victory.png` | 1536x1024, 4x2, cell 384x512 |
| Defeat | `assets/dalji_boss_defeat.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_defeat.png` | 1536x1024, 4x2, cell 384x512 |
| Stun | `assets/dalji_boss_stun.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_stun.png` | 1536x1024, 4x2, cell 384x512 |
| Whip yaw skill | `assets/dalji_boss_whip.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_whip.png` | 1536x1024, 4x2, cell 384x512 |
| Paengi top-whip strike | `assets/dalji_boss_paengi.png` | `godot/assets/sprites/stage1/dalji/dalji_boss_paengi.png` | 1536x1024, 4x2, cell 384x512 |

## Runtime Identity

- Stage 1 boss display name: `달지` / Dalji. `풍악보이` is a legacy name and
  should not be used for new Godot labels or comments.
- Dalji's walk is the current per-boss exception to the default
  front-biased walk policy: she uses separate left/right off-frontal walk
  sheets and must not be runtime-mirrored.
- The walk pair is the identity anchor for future regeneration. Turn and
  skill sheets are runtime auxiliaries, not canonical identity anchors.

## Python Runtime Mapping

The Python runtime uses `entities/stage1_boss_sprite.py` and the Stage 1
branch in `pingfighter.py`.

| Gameplay state | Python path |
|---|---|
| Walk / idle / attack / turn | `stage1_boss_sprite.get_current_frame(...)` |
| Anticipatory ball contact | `stage1_boss_sprite.trigger_attack(...)`; F5 should align near predicted contact |
| Dash | `stage1_boss_sprite.get_dash_frame(...)` while `boss_dashing` |
| Whip yaw | `stage1_boss_sprite.get_whip_frame(...)` while `whip_active` |
| Paengi strike | `stage1_boss_sprite.get_paengi_frame(...)` while `whip_animation_timer > 0` |
| Stun | `stage1_boss_sprite.get_stun_frame(...)` while `boss_stunned_timer > 0` |
| Victory | `stage1_boss_sprite.get_victory_frame(...)` after boss win |
| Defeat | `stage1_boss_sprite.get_defeat_frame(...)` after boss loss |

Python conceptual priority:

```text
defeat > victory > stun > dash > paengi > whip > walk/attack/turn > idle
```

## Godot Runtime Mapping

Current Godot Stage 1 is a partial port. The live project is outside this
repo and must be kept hash-matched with `godot/`.

Current keys:

| Godot key | Dalji asset | Meaning |
|---|---|---|
| `boss_walk_left_sheet` | `dalji_boss_walk_left.png` | movement-left walk |
| `boss_walk_right_sheet` | `dalji_boss_walk_right.png` | movement-right walk |
| `boss_idle_sheet` | `dalji_boss_idle.png` | stationary idle loop |
| `boss_attack_sheet` | `dalji_boss_attack.png` | ball-contact attack |
| `boss_stun_sheet` | `dalji_boss_stun.png` | future real stun/electrocution |
| `boss_whip_sheet` | `dalji_boss_whip.png` | renderer-ready whip yaw auxiliary |
| `boss_sprite_sheet` | `dalji_boss_walk_right.png` | legacy `boss_has_sprite` compatibility |
| `boss_hit_sprite_sheet` | `dalji_boss_attack.png` | legacy compatibility for ball-contact attack |

Important: in Godot, `boss_hit_sprite_sheet` means "boss hit the ball,"
not "boss got hit." It must remain mapped to `dalji_boss_attack.png`.
Real stun must use `boss_stun_sheet` or another explicit stun key.

Current Godot renderer priority:

```text
whip context > ball-contact attack > walk_left/walk_right > idle
```

Current Godot animation timing:

- `boss_actor_animation_state.gd` predicts upward ball approaches and
  starts Dalji's attack before contact using the same conservative
  16/12/8/4-frame start-window model as the Python runtime.
- F5 (frame index 4) is the intended contact apex.
- The real paddle-bounce event still triggers the attack as a fallback
  when prediction misses, but it must not restart an already anticipated
  attack from F1.

Dash, turn, victory, defeat, paengi, and real stun are asset-copied but
not fully ported as gameplay states yet. Whip drawing is renderer-ready;
skill activation and ball/AI behavior are tracked as a separate runtime
slice.

## Regression Checks

Before claiming Dalji sprite work is done:

- Search for `풍악보이`, `Pungakboy`, and `pungak` in active Godot scripts;
  only legacy backup files should retain those names.
- Search for `boss_hit_sprite_sheet`; confirm it maps to attack, not stun.
- Confirm `boss_stun_sheet` exists separately if stun assets are loaded.
- Confirm anticipated attack and exact-contact fallback do not double-fire
  or restart the sheet from F1 at contact.
- Headless-load the live Godot project after syncing from `godot/`.
- For Godot, run a resource smoke that loads:
  `boss_walk_left_sheet`, `boss_walk_right_sheet`, `boss_idle_sheet`,
  `boss_attack_sheet`, and `boss_stun_sheet`.
- When the live project is outside the repo, verify mirror/live hashes for
  every edited `.gd` file and every copied Dalji PNG.
