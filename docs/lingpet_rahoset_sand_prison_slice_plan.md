# 라호세트 모래감옥 (Rahoset Sand Prison) — Active Skill Port Slice Plan

**Status:** DESIGN — ready for wiring. Owner split: **Codex/사용자 배선 → Claude 적대리뷰**
(per [[feedback_design_slice_review_division]]). This doc is the SSOT; do not
re-derive rules from memory.

**Source parity:** Python arena hero "모래감옥" — `downtown/hero_skills.py`
`class SandPrison` (lines ~15233–15670). Sound `sounds/prisonopen.wav`.
**This is a NEW lingpet design, not a 1:1 port.** The Python is the
visual/sound/structural reference only; the gameplay (escape window, level
scaling, probabilistic re-summon) is the user's redesign below.

**Golden template:** Koyora `lingpet_puppet_grab_skill.gd` — it already has the
**identical escape→MISS→level-gated per-opportunity retry** shape. Copy its
structure; the divergences are enumerated in §3.

---

## 0. Decisions locked (2026-07-02, user)

| Question | Decision |
|---|---|
| Delivery | Design plan doc → 사용자/Codex 배선 → Claude 적대리뷰 |
| Boss defense while caged | **보스 튕김 유지** — cage restricts **X movement only**; boss still bounces the ball inside the band |
| Cooldown | **30.0s** |
| Target | **Boss paddle** (top). The lingpet is the player's ally; "상대"=보스 |
| Per-level tuning location | **Module-owned constant arrays** (puppet-grab style), NOT catalog `_by_level` (avoids touching the `FLOAT_PAYLOAD_DEFAULTS` whitelist). See §3.4 |

---

## 1. Gameplay spec

Rahoset conjures a rectangular **sand cage** around the boss paddle.

**Lifecycle:** CREATING (cage builds) → escape check → IMPRISON (boss X-clamped)
→ DISSOLVE (visual only) → done. On a failed capture, a level-gated re-summon
may fire.

### Level tables (`level ∈ 1..5`, index `level-1`)

| Field | Lv.1 | Lv.2 | Lv.3 | Lv.4 | Lv.5 |
|---|---|---|---|---|---|
| **생성(CREATION) 초** | 1.5 | 1.3 | 1.1 | 0.9 | 0.7 |
| **가두기(IMPRISON) 초** | 2.3 | 2.725 | 3.15 | 3.575 | 4.0 |
| **최대 재소환 횟수** | 0 | 0 | 1 | 1 | 2 |
| **재소환 확률(%)** | — | — | 30 | 30 | 50 |

> 2026-07-02 리튠(사용자 지시): 생성 2.0→1.0 표를 1.5→0.7로, 가두기 1.5→3.0
> 표를 2.3→4.0으로 상향. 카탈로그 description/effect_text 수치 동기화 완료.
> 초판 수치는 히스토리로만 유효.

- **CREATION**: cage forms; boss is **free** (not clamped). The longer Lv.1
  window (1.5s) is what lets the boss "도망" — it can slide its center out of
  the cage band before the cage locks.
- **Escape check** (once, at end of CREATION): capture succeeds iff the boss
  **center x** is still inside `[cage_left, cage_right]`. Else = MISS.
- **IMPRISON**: `lingpet_sand_prison_clamp_active` on; boss X-clamped to the
  cage band for the level's imprison seconds. Boss AI still runs and the boss
  **still bounces the ball** — only its X range is restricted (§4).
- **DISSOLVE**: fixed ~0.5s cosmetic fade; clamp is **already released** at
  dissolve start.
- **Re-summon** (only on MISS): Lv.3–4 → one retry at **30%**; Lv.5 → up to two
  retries at **50%** each (roll for retry 1; if it fires and also MISSes, roll
  again for retry 2). Retry re-targets the boss's **current** position after a
  short `RETRY_DELAY` (~0.5s). This is a **per-opportunity** roll — see §5 trap.

### Cage geometry

- `PRISON_HALF_MIN = 100`, `PRISON_HALF_MAX = 150` (Python parity; total
  200–300px). `half = randf_range(MIN, MAX)` per summon.
- At cast, read boss center `bx = boss_pos.x + boss_width*0.5`.
  `center = clampf(bx, half, FIELD_WIDTH - half)`;
  `cage_left = center - half`; `cage_right = center + half`.
- Imprison clamp band: `boss_pos.x ∈ [cage_left, cage_right - boss_width]`.
- Draw Y band (boss is at top): mirror Python top-paddle
  `y_top = max(0, boss_y - 50)`, `y_bot = boss_y + 80`.

### Cooldown / windup

- `cooldown: 30.0`. `windup_seconds: 0.4` (short staff-raise before CREATION).
  Note: the CREATION phase is the *visible* cage build; `windup_seconds` is the
  separate pre-launch companion cock. Keep it short to avoid a double wind-up
  feel. Tunable.

---

## 2. Source-parity notes (Python `SandPrison`)

Keep for the DRAW (§7) and sound (§6). Do **not** copy the gameplay — it's
replaced by §1.

- Python phases: BUILD 1.0 / ACTIVE 2.0 / DISSOLVE 1.0 (fixed). Wall height via
  ease-out `1 - (1-p)^2.5`; alpha 0→200; dissolve ease-in `p^2.0`, 200→0.
- Python clamp starts at `build_progress >= 0.5` with **no escape** — we replace
  this with a full-window free CREATION + end-of-window escape check.
- Python has **no** level scaling and **no** re-summon — both are new here.
- Sand walls 8px wide (3px textured strips), floor fill (210,180,100 @ α22),
  corner glyphs, upward sand particles during build, downward during dissolve.
- Sound: `prisonopen.wav` @ 0.5 vol, once at activation.

---

## 3. Divergences from the puppet-grab template (`lingpet_puppet_grab_skill.gd`)

Copy the template's **skeleton**; change exactly these:

### 3.1 Boss is CLAMPED, not FROZEN/dragged
Puppet-grab **writes `boss_pos` every frame** + sets `lingpet_puppet_grab_active`
so `boss_ai_state` **early-returns `{boss_pos, boss_vel:0}`** (full freeze at a
scripted point). **Sand prison must NOT do this.** It sets a *clamp* flag +
band; `boss_ai_state` computes the boss's normal move, then **clamps only x**
into the band (§4). The skill **never writes `boss_pos`** and never displaces the
boss. This preserves "보스 튕김 유지, X이동만 제한".
> ⚠️ The extraction agent's first draft proposed the puppet-grab freeze
> early-return — that is WRONG for this skill (it would freeze the boss and kill
> the "still bounces" requirement). Use the post-movement clamp in §4.

### 3.2 Escape check is an X-BAND test, not a distance test
Puppet-grab: `arrival_center.distance_to(_predicted_target_center) <= hit_tolerance()`.
Sand prison: `boss_center_x ∈ [cage_left, cage_right]`. (Optional small pad, but
default to plain band membership.)

### 3.3 Retry chance is LEVEL-dependent (30/50), not flat 50
Puppet-grab uses a single `RETRY_CHANCE_PCT = 50.0` const. Sand prison needs
`_get_retry_chance_pct(level)` → `50.0 if level >= 5 else 30.0` (only reached at
level ≥ 3). `_get_max_retries_for_level` is IDENTICAL to puppet-grab
(`2 if level>=5, 1 if level>=3, else 0`).

### 3.4 Per-level durations are module-owned arrays
Add `CREATION_SECONDS_BY_LEVEL := [1.5,1.3,1.1,0.9,0.7]` and
`IMPRISON_SECONDS_BY_LEVEL := [2.3,2.725,3.15,3.575,4.0]` as module constants
(2026-07-02 리튠 반영; 초판은 2.0→1.0 / 1.5→3.0),
indexed by `_active_skill_level - 1`. The catalog entry carries only
id/kind/name/description/cooldown/windup/card/icon — **no `_by_level`** (that path
would require whitelisting new keys in
`lingpet_companion_skill_launch_payload_builder.FLOAT_PAYLOAD_DEFAULTS`; module
tables avoid it, matching puppet-grab).

### 3.5 `_release` clears a CLAMP flag, not a boss_pos restore
Puppet-grab `_release` restores `boss_pos = _boss_original_center - size*0.5`.
Sand prison never moved the boss, so `_release` only clears
`lingpet_sand_prison_clamp_active` + the two bound keys. **No `boss_pos`
restore, no `boss_y` round-reset needed** (§8 is lighter than the puppet-grab
round-reset trap).

---

## 4. Boss AI clamp integration (post-movement, NOT freeze)

**File `godot/scripts/core/boss_ai_state.gd`** — add a clamp on the boss's
FINAL, normally-computed `boss_pos` at the END of `update()` (after every
existing early-return freeze branch, e.g. the `lingpet_puppet_grab_active`
block, and after normal movement math), just before the normal-path return
`{ "boss_pos": ..., "boss_vel": ... }`:

```gdscript
if bool(context.get("lingpet_sand_prison_clamp_active", false)):
    var cage_left: float = float(context.get("lingpet_sand_prison_cage_left", 0.0))
    var cage_right: float = float(context.get("lingpet_sand_prison_cage_right", FIELD_WIDTH))
    # X-clamp only: the boss keeps its normal vertical/tracking motion and its
    # ball collision — the cage just walls off its horizontal range.
    boss_pos.x = clampf(boss_pos.x, cage_left, maxf(cage_left, cage_right - boss_paddle_width))
# ...then the existing normal-path return {boss_pos, boss_vel}
```

- Do **NOT** `return {boss_pos, boss_vel: 0}` here — that is the freeze pattern
  and is wrong. Preserve the normally computed `boss_vel`.
- `sand_prison` and every other boss-scripting skill are `POS_OVERRIDE`
  (§9.2 dispatcher), so two of them can never co-run in the two slots — the clamp
  only needs to coexist with the *normal* AI path.
- `boss_paddle_width` name: use whatever the file already reads for boss paddle
  width (grep `boss_paddle_width` in `boss_ai_state.gd`).

**File `godot/scripts/.../battle_update_boss_ai_context_builder.gd`** — copy the
three owner flags into the boss-AI context (after the `lingpet_dwarf_magic_*`
lines, ~L122):

```gdscript
"lingpet_sand_prison_clamp_active": bool(_get_owner_value(owner, "lingpet_sand_prison_clamp_active", false)),
"lingpet_sand_prison_cage_left": float(_get_owner_value(owner, "lingpet_sand_prison_cage_left", 0.0)),
"lingpet_sand_prison_cage_right": float(_get_owner_value(owner, "lingpet_sand_prison_cage_right", 760.0)),
```

> The skill WRITES the flags onto the owner; the context builder READS the owner
> → this is the safe cross-path pattern (same as puppet-grab). NOT a
> two-update-path context-flag trap, because we route through the owner, not a
> per-path context dict. But the owner keys MUST be schema-declared (§9.3) or the
> `owner.set()` silently no-ops (Owner-Field Schema Trap).

---

## 5. Per-opportunity roll compliance (CRITICAL — CLAUDE.md "Per-Frame Probability Roll Trap")

Both stochastic gates are rolled **once per opportunity**, never per frame:

- **Escape/capture check**: evaluated exactly once, at the CREATING→(IMPRISON|MISS)
  phase transition. Not in a per-frame loop.
- **Re-summon roll**: rolled once inside `_enter_miss_or_retry()` (mirror
  puppet-grab). Use `_roll_retry()` with a **test-injectable queue**
  (`_retry_roll_queue_for_tests` + `set_retry_roll_queue_for_tests`) exactly like
  puppet-grab, so smokes can force success/failure deterministically.

`_roll_retry()`:
```gdscript
func _roll_retry() -> bool:
    if not _retry_roll_queue_for_tests.is_empty():
        return bool(_retry_roll_queue_for_tests.pop_front())
    return randf() < _get_retry_chance_pct(_active_skill_level) / 100.0
```

Smokes MUST include a **reverse-verified** per-opportunity case (§10): a *failed*
retry roll does not re-fire within the same MISS, and a fresh cast re-arms
exactly the level's retry budget. A success-only test passes even with a
per-frame bug — do not ship one.

---

## 6. Sound (already staged)

- Asset copied: `godot/assets/sounds/lingpet/rahoset_sand_prison_open.wav`
  (from `sounds/prisonopen.wav`). **A Godot import pass must run** (open editor
  or headless import) so the `.import` is generated before runtime load.
- **`godot/scripts/audio/game_audio.gd`** — 5 edits mirroring
  `play_lingpet_puppet_grab_cast`:
  1. `const LINGPET_SAND_PRISON_OPEN_SOUND_PATH := "res://assets/sounds/lingpet/rahoset_sand_prison_open.wav"`
  2. `const LINGPET_SAND_PRISON_OPEN_GAIN_DB := -6.0` (Python played @0.5 vol; -6 dB ≈ half)
  3. `var lingpet_sand_prison_open_sfx: AudioStreamPlayer`
  4. In `setup()`: `lingpet_sand_prison_open_sfx = player_factory.create(owner_node, "LingpetSandPrisonOpenSfx", LINGPET_SAND_PRISON_OPEN_SOUND_PATH, LINGPET_SAND_PRISON_OPEN_GAIN_DB)`
  5. ```gdscript
     func play_lingpet_sand_prison_cast() -> void:
         if not _play_with_pitch(lingpet_sand_prison_open_sfx, randf_range(0.98, 1.02)):
             play_active_item()
     ```
- **Play site:** call `_play_audio(registry, "play_lingpet_sand_prison_cast")`
  at the start of **every** summon — the initial `launch` AND each retry
  re-summon (`_begin_shot`). Mirrors puppet-grab's cast sound on retry.

---

## 7. The skill module — `godot/scripts/lingpet/lingpet_sand_prison_skill.gd`

`extends RefCounted`. Copy the puppet-grab skeleton and apply §3 divergences.
Backbone (the tricky logic is spelled out; DRAW is a parity spec):

### Constants
```gdscript
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PHASE_CREATING := 0
const PHASE_IMPRISON := 1
const PHASE_DISSOLVE := 2
const PHASE_MISSING := 3
const PHASE_RETRY_WAIT := 4
const CREATION_SECONDS_BY_LEVEL := [1.5, 1.3, 1.1, 0.9, 0.7]
const IMPRISON_SECONDS_BY_LEVEL := [2.3, 2.725, 3.15, 3.575, 4.0]
const DISSOLVE_SECONDS := 0.5
const MISS_SECONDS := 0.45
const RETRY_DELAY_SECONDS := 0.5
const PRISON_HALF_MIN := 100.0
const PRISON_HALF_MAX := 150.0
const BOSS_Y_FALLBACK := 25.0
```

### State
```gdscript
var _active := false
var _phase := PHASE_CREATING
var _phase_timer := 0.0
var _active_skill_level := 1
var _cast_pos := Vector2.ZERO
var _boss_width := 100.0
var _cage_left := 0.0
var _cage_right := FIELD_WIDTH
var _cage_center := FIELD_WIDTH * 0.5
var _cage_half := 125.0
var _boss_y := BOSS_Y_FALLBACK
var _retries_remaining := 0
var _retry_count := 0
var _shot_count := 0
var _missed := false
var _owns_clamp := false           # survives owner-less cancel() (self-heal)
var _retry_roll_queue_for_tests: Array[bool] = []
# + particle/anim arrays for DRAW
```

### Lifecycle (key logic — mirror puppet-grab where identical)
- `launch(origin, owner, launch_context)`: `owner==null → false`;
  `_active_skill_level = clampi(int(launch_context.active_skill_level), 1, 5)`;
  `_retries_remaining = _get_max_retries_for_level(level)`; reset counters;
  return `_begin_summon(origin, owner)`.
- `_begin_summon(origin, owner)`: read `_boss_width` from owner
  `boss_paddle_width`, `_boss_y` from owner `boss_pos.y`; compute cage geometry
  from the boss center (§1); `_cast_pos = origin`; `_phase = PHASE_CREATING`;
  `_phase_timer = 0`; `_owns_clamp = false` (do NOT own boss yet — CREATION is
  the escape window). `_shot_count += 1`. Play cast sound is done by the
  update/host caller, or call `_play_audio` here.
- `update(delta, owner, registry, launch_context)`:
  - **Deferred self-heal** (top, mirror puppet-grab): `if not _active: if
    _owns_clamp and owner != null: _release(owner); return`.
  - `_phase_timer += maxf(0.0, delta)`; run `_advance_phase(owner, registry)`
    (roll multiple completed phases in one frame via `while _active`).
  - While `_owns_clamp` (IMPRISON), **re-write the owner flags every frame**
    (freshness): `owner.set("lingpet_sand_prison_clamp_active", true)`,
    `owner.set("lingpet_sand_prison_cage_left", _cage_left)`,
    `owner.set("lingpet_sand_prison_cage_right", _cage_right)`.
  - On natural finish (`_active` became false in `_advance_phase`): if
    `_owns_clamp and owner != null: _release(owner)` else local `reset()`.
- `_advance_phase`:
  - `PHASE_CREATING`: when `_phase_timer >= creation_secs`: subtract; run
    **escape check** `_capture_succeeds(owner)`. HIT → commit clamp
    (`_owns_clamp=true`, write owner flags), `_phase = PHASE_IMPRISON`. MISS →
    `_enter_miss_or_retry(registry)`.
  - `PHASE_IMPRISON`: when `>= imprison_secs`: release clamp
    (`owner.set(clamp_active,false)` + clear owns), `_phase = PHASE_DISSOLVE`.
  - `PHASE_DISSOLVE`: when `>= DISSOLVE_SECONDS`: `_active = false`.
  - `PHASE_MISSING`: when `>= MISS_SECONDS`: `_active = false`.
  - `PHASE_RETRY_WAIT`: when `>= RETRY_DELAY_SECONDS`: `_retry_count += 1`;
    `_begin_summon(_cast_pos, owner)`; carry timer remainder; play cast sound.
- `_capture_succeeds(owner)`: `bx = boss_pos.x + _boss_width*0.5`; return
  `bx >= _cage_left and bx <= _cage_right`.
- `_enter_miss_or_retry(registry)`: `_missed = true`; if `_retries_remaining <=
  0: _phase = PHASE_MISSING; return`. `if _roll_retry(): _retries_remaining -=
  1; _phase = PHASE_RETRY_WAIT` else `_retries_remaining = 0; _phase =
  PHASE_MISSING`.
- `_get_max_retries_for_level(l)`: `2 if l>=5 else (1 if l>=3 else 0)`.
- `_get_retry_chance_pct(l)`: `50.0 if l>=5 else 30.0`.
- `_release(owner)`: `if owner and _owns_clamp: owner.set(clamp_active,false);
  owner.set(cage_left,0.0); owner.set(cage_right,FIELD_WIDTH)`; `_owns_clamp =
  false`; `reset()`.
- `cancel(owner=null, registry=null)`: `_active=false; _clear_visuals(); if
  owner: _release(owner) elif not _owns_clamp: reset()`. (Owner-less cancel keeps
  `_owns_clamp` so the next `update(owner)` self-heals — mirror puppet-grab.)
- `reset()`: full state clear (idempotent); `_owns_clamp=false`,
  `_retry_roll_queue_for_tests.clear()`.
- `prewarm()`: `pass` (no heavy textures; cage is procedural). If any font/atlas
  is preloaded for DRAW, load it here.

### Interface methods (mirror the shared skill contract)
- `is_active() -> bool: return _active`
- `has_visible_effects() -> bool` (active or particles)
- `can_arm(params) -> bool`: **sortie_flight gate** — require
  `params.companion_visible` and companion on-screen (copy
  `lingpet_headbutt_skill._is_companion_onscreen`). See [[feedback_lingpet_sortie_skill_arm_gate]].
- `has_companion_position_override() -> bool: return _active`
- `get_companion_position_override(fallback): return _cast_pos if _active else fallback`
- `get_companion_cast_pose_progress() -> float`: CREATING lerp 0→~0.56, IMPRISON
  hold ~0.7, else -1 (mirror puppet-grab/doll-curse so the animator picks the
  cast pose sheet).
- `draw(canvas, shake_offset)`: procedural sand cage (§7.1).
- `get_snapshot() -> Dictionary`: expose at minimum
  `"sand_prison_active": _active`, `"sand_prison_phase"`, `"sand_prison_cage_left"`,
  `"sand_prison_cage_right"`, `"sand_prison_creating"`, `"sand_prison_imprison"`,
  `"sand_prison_retries_remaining"`, `"sand_prison_retry_count"`,
  `"sand_prison_shot_count"`, `"sand_prison_missed"`, `"sand_prison_owns_clamp"`,
  plus the per-level durations for tests. `"sand_prison_active"` is the rail-card
  casting flag (§9.6).

### 7.1 DRAW (parity spec — VFX is Codex runtime territory)
Mirror Python `SandPrison.draw` (hero_skills.py:15528–15657) with phase-timer
driven animation:
- CREATING: two vertical sand walls at `cage_left`/`cage_right`, height grows via
  ease-out on `creating_ratio`; floor fill; upward sand particles.
- IMPRISON: full walls + floor at steady alpha; occasional ambient particles.
- DISSOLVE: walls shrink/fade via ease-in on `dissolve_ratio`; downward sand.
- **Traps:** drive ALL animation from `_phase_timer`/phase ratios, NOT
  `Time.get_ticks_msec()` (CLAUDE.md "Effect Drawer Static-Frame Trap"). Use
  `draw_rect`/`draw_line` for walls; if any `draw_colored_polygon` is used for a
  jagged sand edge, guard it with `Geometry2D.triangulate_polygon` (CLAUDE.md
  "Animated Polygon Triangulation Trap"). Cull draws including the letterbox band
  is not needed (cage is inside the field), but the cage sits at the top boss
  band — keep it inside `0..FIELD_WIDTH`.

---

## 8. Round-reset normalization (lighter than puppet-grab)

**File `godot/scripts/.../ball_round_state.gd`** `build_common_snapshot()` — add
(after the `lingpet_dwarf_magic_*` normalizers):
```gdscript
"lingpet_sand_prison_clamp_active": false,
"lingpet_sand_prison_cage_left": 0.0,
"lingpet_sand_prison_cage_right": 760.0,
```
No `boss_pos`/`boss_y` restore is needed (the skill never displaced the boss).
The `_owns_clamp` self-heal (§7) + this normalization together guarantee no
clamp leaks across a round boundary or an owner-less teardown.

---

## 9. File-by-file wiring checklist

| # | File | Edit |
|---|---|---|
| 9.1 | `lingpet_skill_dispatcher.gd` | Add `const SKILL_KIND_SAND_PRISON := "sand_prison"`; add to `SUPPORTED_SKILL_KINDS`; add `sand_prison` skill_id → kind in `get_skill_kind()` (catalog `runtime_kind:"sand_prison"` drives this — verify the catalog-first lookup resolves it, else add to the hardcoded match); add `SKILL_KIND_SAND_PRISON` to the **POS_OVERRIDE** branch of `get_exclusive_resource_classes()` |
| 9.2 | `lingpet_sand_prison_skill.gd` | **NEW** module (§7) |
| 9.3 | `battle_scene_state.gd` `DEFAULT_VALUES` | Add `"lingpet_sand_prison_clamp_active": false`, `"lingpet_sand_prison_cage_left": 0.0`, `"lingpet_sand_prison_cage_right": 760.0` (Owner-Field Schema Trap — REQUIRED or writes no-op) |
| 9.4 | `boss_ai_state.gd` | §4 post-movement X-clamp (NOT freeze) |
| 9.5 | `battle_update_boss_ai_context_builder.gd` | §4 copy 3 flags to boss-AI context |
| 9.6 | `lingpet_skill_runtime_host.gd` | `const SAND_PRISON_SKILL_PATH`; `var _sand_prison_skill`; `_get_sand_prison_skill()` lazy init; wire into `reset()`, `reset_round()`, `update()` dispatch, `launch()`, `can_arm()` (call the module gate), `prewarm()`, `get_snapshot()` (`_merge_skill_snapshot(snapshot, _sand_prison_skill)`), and the override/`suppresses_companion_body_hit` accessors as needed. **Match every place the puppet-grab/doll-curse kinds are already listed** — grep `puppet_grab` in this file and add a sibling `sand_prison` line at each |
| 9.7 | `ball_round_state.gd` | §8 normalization |
| 9.8 | `game_audio.gd` | §6 sound (5 edits) |
| 9.9 | `lingpet_catalog.gd` (rahoset ~L1053) | Replace `"active_skill": []` with the single-dict entry below |
| 9.10 | `lingpet_rail_card.gd` `_casting_flag_keys_for_skill` | Add `LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON: return ["sand_prison_active"]` so the rail's per-slot casting gauge fills during the cast (2nd-active-slot HUD parity) |

### 9.9 Catalog entry (rahoset)
```gdscript
"active_skill": {
    "id": "rahoset_sand_prison",
    "runtime_kind": "sand_prison",
    "name": "모래감옥",
    "description": "라호세트가 보스 주위에 모래감옥을 세웁니다. 생성되는 동안(Lv.1 2초~Lv.5 1초) 보스가 감옥 밖으로 도망치면 실패하고, 가두는 데 성공하면 보스의 좌우 이동을 감옥 폭 안으로 묶습니다(Lv.1 1.5초~Lv.5 3초). Lv.3부터 가두기 실패 시 30% 확률로 한 번 더 소환하고, Lv.5는 50% 확률로 최대 2번까지 재소환합니다.",
    "cooldown": 30.0,
    "windup_seconds": 0.4,
    "card_texture_path": "res://assets/sprites/lingpet/rahoset_sand_prison_skillcard_imagegen_v1.png",
    "icon_texture_path": "res://assets/sprites/lingpet/rahoset_sand_prison_skill_icon_imagegen_v1.png",
},
```
- Rahoset stays `enabled: false, debug_enabled: true` — wiring the skill does NOT
  ship the pet. QA via **F7 debug picker** (§11).
- **Asset dependency (non-blocking):** the card/icon PNGs above don't exist yet.
  `lingpet_rail_card.texture()` falls back to the default maribo card, and the
  TAB icon falls back gracefully, so wiring + gameplay work without them.
  Generate the art via `/item-generation` before shipping the pet. Until then,
  either leave the paths (fallback) or point them at an existing placeholder.

---

## 10. Smoke tests (reverse-verify each; put in `godot/tests/lingpet_egg_runtime_smoke.gd` and/or a new `lingpet_sand_prison_skill_smoke.gd`)

Every assertion is an **OUTCOME**, and each must be reverse-verified (prove it
FAILS on the buggy code via an in-place toggle — never `git reset`/`stash`, per
[[reference_godot_live_path]] SAFE反증검증).

1. **Level tables**: level 1/5 launch → creation/imprison durations match the
   table.
2. **Escape = MISS**: boss center moved OUT of band by end of CREATION → phase =
   MISSING (or RETRY_WAIT), clamp never activated. Reverse: with the boss left in
   band, capture succeeds.
3. **Capture → clamp OUTCOME**: boss in band at end of CREATION → during IMPRISON,
   drive `boss_ai_state.update()` with the clamp context and assert the returned
   `boss_pos.x` is clamped into `[cage_left, cage_right - boss_width]` **AND**
   `boss_vel` is NOT forced to 0 (boss still moves/bounces). Use a **non-trivial
   boss width** and a boss that tries to move outside. Reverse: drop the §4 clamp →
   boss escapes the band (FAIL).
4. **Per-opportunity retry** (Per-Frame Roll Trap): with
   `set_retry_roll_queue_for_tests([false])` at Lv.3, a MISS → exactly one roll,
   no re-fire, phase ends MISSING. With `[true]` → one RETRY_WAIT then re-summon;
   the retry budget decremented by exactly 1. Lv.5 `[true,true]` → two re-summons
   max; `[true,false]` → one re-summon then stop. A success-only test is
   insufficient.
5. **Round-reset normalization**: mid-IMPRISON, run
   `BallRoundState.build_common_snapshot()`/`reset_ball` path → `clamp_active`
   false, bounds reset. Reverse: remove §8 → flag leaks (FAIL).
6. **Owner-less cancel self-heal**: mid-IMPRISON call `cancel(null)` → `_owns_clamp`
   stays true; next `update(owner)` clears `lingpet_sand_prison_clamp_active`.
   Reverse: make `cancel(null)` full-reset → clamp leaks into next round (FAIL).
7. **Owner schema**: use a **schema-gated owner** (delegating to
   `BattleSceneState`, like `battle_scene_shell`), NOT a plain-dict fake, and
   assert `owner.set("lingpet_sand_prison_clamp_active", true)` actually reads
   back true (proves §9.3 declared the key). Reverse: remove the DEFAULT_VALUES
   key → readback null (FAIL).
8. **sortie can_arm gate**: `can_arm({companion_visible:false})` → false;
   on-screen visible → true.
9. **Rail-card casting**: a dual-slot snapshot with sand_prison casting → its rail
   entry status is "casting" and the OTHER slot's card is not force-filled (2nd
   active-slot casting independence, per CLAUDE.md).

---

## 11. QA / live verification

- Rahoset is debug-only → pick it via **F7 debug picker** in a battle, cast the
  skill, and verify in-game: (a) cage forms over the boss, (b) at low Lv the boss
  can slide out during the long CREATION → MISS + (Lv3+) re-summon, (c) on capture
  the boss is walled to the band but **still bounces balls landing inside the
  band** while balls outside the band score, (d) `prisonopen.wav` plays on each
  summon, (e) the boss-skill rail shows the cage card with a filling cast gauge,
  (f) no clamp leak into the next round (win/lose a point mid-imprison).
- Pixel/felt check per [[feedback_fable_grade_operating_posture]].

---

## 12. CLAUDE.md traps that apply (and how this design satisfies them)

- **Per-Frame Probability Roll Trap** → §5: escape + retry are per-opportunity;
  test-injectable queue; reverse-verified.
- **Owner-Field Schema Trap** → §9.3: 3 keys in `DEFAULT_VALUES`; schema-gated
  owner smoke.
- **Two-Update-Path Context-Flag Trap** → §4: skill writes owner, context builder
  reads owner (safe); no effects-only context read.
- **Boss-Paddle-Scripting Skill Trap** → this is a **new sibling class**: a
  post-movement CLAMP (boss keeps motion + collision), NOT a freeze/drag. §3.1
  warns explicitly against the freeze early-return. Self-heal `_owns_clamp` +
  round-reset normalization (§7/§8) mirror the trap's cleanup requirements.
- **Lingpet Second-Active-Slot HUD Parity Trap** → §9.10: rail casting flag keyed
  by kind.
- **Effect Drawer Static-Frame / Animated Polygon Triangulation Traps** → §7.1.
- **Companion Incapacitation Body-Hit Trap** → N/A: the lingpet casts remotely and
  is not incapacitated; do NOT add `suppresses_companion_body_hit` unless a future
  design self-stuns Rahoset during the cast.

---

## 13. Post-fix / doc-backfill recommendation (at review/merge time)

This port surfaces a **repeatable, non-obvious** distinction the extraction pass
itself got wrong: a boss-paddle **CLAMP/restrict** skill must use a
**post-movement X-clamp that preserves `boss_vel` + ball collision**, which is a
distinct class from the existing "Boss-Paddle-Scripting (drag/freeze)" and
"Boss-Paddle-Resizing (shrink/grow)" traps in CLAUDE.md. Per the CLAUDE.md
post-fix backfill policy, add a short **"Boss-Paddle-Clamp/Restrict Skill Trap"**
note to CLAUDE.md (freeze early-return vs. post-movement clamp; preserve
collision; self-heal + round-reset) when this lands. Tell the user in one line
that the rulebook was updated.

---

## 14. Open items for reviewer/user sign-off

1. `windup_seconds` = 0.4 (or 0.0 — CREATION already reads as the build).
2. Cage half-width randomized 100–150 (Python parity) vs. a fixed value.
3. Escape predicate: plain band membership vs. a small tolerance pad.
4. Card/icon art generation (deferred; fallback works).

---

## 15. VFX parity — Phase 1: body→cage sand stream (the missing signature)

**Status:** ✅ IMPLEMENTED (2026-07-02, Claude direct — pure procedural VFX, aesthetic
direction). Skill smoke (`_verify_body_stream_emission_and_direction` + finish-cleanup
asserts) + visual smoke + warning scan all GREEN. **Live F7 eye-check still decides felt
density** (rate/size/color are code-tunable constants §15.2). The current cage reads as
"a sand cage forming" but was a
simplified remake; the original's signature is sand **flowing from the caster's
body into the cage** while it builds. Adding just this stream is the single
biggest bump toward original-ness. Grain walls / corner ornaments / soft glow
are **Phase 2** (§15.3), deliberately deferred.

Owner-module: [lingpet_sand_prison_skill.gd](../godot/scripts/lingpet/lingpet_sand_prison_skill.gd).
This is a pure procedural draw addition — NO owner/schema/context changes, no
gameplay change, no new smoke traps beyond the ones below.

### 15.1 Original parameters (verbatim from `SandPrison`, cite in code)

Emission — **building phase only** (`hero_skills.py:15368-15401`):
- Source: caster center `(caster_cx, caster_cy)` + random offset `x∈[-12,12]`, `y∈[-8,8]`.
- Per-frame count (60fps): `spawn_count = max(1, int(4 * (1.0 - build_progress*0.6)))`
  → **~4/frame early → ~1/frame late** (more at the start of the build, tapering).
- Destination: **60%** → a wall (`left_wall` or `right_wall`, ±6px); **40%** →
  interior random x in `[left_wall, right_wall]`. `dest_y ∈ [prison_y_top, py_bot]`.
- `travel_time = uniform(0.5, 0.9)`; velocity = `(dest-start)/travel_time`
  (**constant-velocity straight flight, NO gravity** — it reaches the cage exactly
  at end of life). `life = max_life = travel_time`.
- `size = uniform(1.5, 4.0)`; `init_alpha = randint(160, 240)`.

Update (`15479-15496`): `pos += vel*dt`; `life -= dt`; `progress = 1 - life/max_life`;
alpha envelope = **fade-in** (`progress<0.2`: `progress/0.2`) → **hold** (`1.0`) →
**fade-out** (`progress>0.75`: `(1-progress)/0.25`); size shrinks `×0.95/frame` when
`progress>0.8`; cull when `life<=0`.

Draw (`15630-15656`): circle at pos, color **bright gold→dark** by progress
`(230,200,110) → (200,175,90)`; plus a **tail** dot (`size-1`, 1/3 alpha) placed
**behind** the grain (`pos - vel.normalized()*size*1.5`) when `size>1` and `progress<0.8`.

### 15.2 Godot adaptation (module edits)

Use a **dedicated array** `_body_particles: Array[Dictionary]` (separate from the
ambient `_sand_particles`, its own cap), so the dense stream never evicts the wall
sand. Frame-rate-independent, phase-timer driven (NOT wall-clock — keep the module's
existing discipline).

- Constants:
  ```gdscript
  const BODY_STREAM_RATE_EARLY := 180.0   # grains/sec at build start (raw original ≈240; start here, tune felt)
  const BODY_STREAM_RATE_LATE  := 60.0    # grains/sec near build end
  const BODY_PARTICLE_MAX := 200          # steady-state ≈ rate*avg_life(0.7) ≈ 126; 200 headroom
  const BODY_WALL_DEST_CHANCE := 0.6
  const BODY_TRAVEL_MIN := 0.5
  const BODY_TRAVEL_MAX := 0.9
  const BODY_COLOR_BRIGHT := Color(0.902, 0.784, 0.431, 1.0)  # (230,200,110)
  const BODY_COLOR_DARK   := Color(0.784, 0.686, 0.353, 1.0)  # (200,175,90)
  ```
- **Emit** via an accumulator, **only in `PHASE_CREATING`**:
  ```gdscript
  var create_p := clampf(_phase_timer / _get_creation_seconds(), 0.0, 1.0)
  var rate := lerpf(BODY_STREAM_RATE_EARLY, BODY_STREAM_RATE_LATE, create_p)
  _body_spawn_accum += delta * rate
  while _body_spawn_accum >= 1.0 and _body_particles.size() < BODY_PARTICLE_MAX:
      _body_spawn_accum -= 1.0
      _spawn_body_particle()
  ```
  `_spawn_body_particle()`: `start = _cast_pos + Vector2(randf_range(-12,12), randf_range(-8,8))`;
  `dest_x = (randf() < BODY_WALL_DEST_CHANCE) ? (either _cage_left/_cage_right) + randf_range(-6,6) : randf_range(_cage_left,_cage_right)`;
  `dest_y = randf_range(_get_cage_top(), _get_cage_bottom())`;
  `travel = randf_range(BODY_TRAVEL_MIN, BODY_TRAVEL_MAX)`;
  `vel = (Vector2(dest_x,dest_y) - start) / travel`; store `pos,vel,life=travel,max_life=travel,size=randf_range(1.5,4.0),init_alpha=randf_range(0.63,0.94)`.
- **Update** every active frame (NOT only CREATING — grains emitted at build's end
  keep flying into early IMPRISON): `pos += vel*delta` (no gravity); `life -= delta`;
  compute the fade-in/hold/fade-out envelope + size shrink; cull `life<=0`. Add the
  call next to `_update_particles(safe_delta)` in `update()`.
- **Draw** in `draw()` (alongside `_draw_sand_particles`), adding `shake_offset` to
  pos like the ambient path: `color = BODY_COLOR_BRIGHT.lerp(BODY_COLOR_DARK, progress)`
  with envelope alpha; then the tail dot (`size-1`, `color.a/3`) at
  `pos - vel.normalized()*size*1.5` when `size>1 and progress<0.8`.
- **Cleanup**: clear `_body_particles` + `_body_spawn_accum` in **both** `reset()`
  and `_begin_summon()` (so a retry re-summon restarts the stream cleanly). Include
  `not _body_particles.is_empty()` in `has_visible_effects()` for symmetry — but note
  the stream fully expires by early IMPRISON, so with the §Fix-① `reset()` on finish
  it never lingers.

### 15.2.1 Smoke (reverse-verifiable)
Add to `lingpet_sand_prison_skill_smoke.gd`:
- Emission is **CREATING-gated**: after launch, a few CREATING ticks → `_body_particles`
  non-empty; advance into IMPRISON and let them expire → emission stops (count drops to
  0 and does not refill during IMPRISON). Reverse: emit-in-all-phases would keep refilling.
- **Direction**: sample a spawned grain and assert its velocity points from `_cast_pos`
  toward the cage band (`vel` dotted with `(cage_center - _cast_pos)` > 0).
- **Cleanup**: after a natural finish (reuse the §Fix-① test), `_body_particles` is empty.
- Cap respected: `_body_particles.size() <= BODY_PARTICLE_MAX` across a full build.

### 15.3 Phase 2 (next step, deferred — original params for later)

**Status:** ✅ IMPLEMENTED (2026-07-02, user wiring) + Claude adversarial review
(2 workflows, 21+19 agents, pixel recapture vs original render) **APPROVE**.
Landed with original-exact params: wall alpha `cap(200/255)×eased(2.5)`, grain walls
(6px strip / 3px cadence / h 2–4 / RGB jitter), soft glow (24px, α·0.3 gradient),
grain bars (5px, +8px overhang width, bottom always / top >0.9), corner circles
(r6, α·0.7, >0.8), interior tint (22/255). Pixel recapture confirms the completed
cage now reads as the original's golden grain frame.
Review fixes/notes: (a) DISSOLVE easing had regressed to linear during the Phase-2
edit — restored to original `1 - p²` ease-in (Claude, sealed by none — cosmetic);
(b) grain shimmer re-rolls at 18Hz vs original 60Hz (undocumented divergence,
felt-QA에서 판단; lever = `_anim_time * 18.0` in `_draw_wall_grain`/`_draw_grain_bar`);
(c) sand particles draw UNDER the cage vs original ON TOP (low; reorder in `draw()`
if F7 wants wall-burst sand visible); (d) visual-smoke pixel branch is dead under
`run_smoke_tests.ps1` (always `--headless`) — it only bites when run windowed
manually; `_verify_visual_parity_tuning` guards re-tuning of constants, not wiring.
Remaining deliberate divergences: cage ~45% taller (gameplay), stream density
profile (documented tune §15.2), MISS branch / cast pose / burst accents (Godot-only
by design).

### 15.4 MISS 모래바람 세척 연출 (2026-07-02, Godot 신규 — 원본에 없음)

**Status:** ✅ IMPLEMENTED (Claude direct). 가두기 실패(도주) 시 기존 "0.15 스텁
페이드" 대신, 다 지어진 감옥이 **보스가 도망친 방향의 모래바람에 그레인 단위로
쓸려 내려가며 소멸**한다.

- 방향: `_wash_dir = +1/-1` — MISS 진입 시 보스 중심 x가 감옥 중심의 어느
  쪽인지로 결정 (`_enter_miss_or_retry(owner, ...)`).
- 감옥 세척: `PHASE_MISSING` 동안 `wash_p = timer/MISS_SECONDS(0.45)`.
  그레인별 **위치 고정 시드**(18Hz 프레임 시드 제외 — 깜빡임 방지)로 소멸
  임계값을 시차 배치: `vanish = clamp((wash_p*1.25 - hash)/0.25)`; 소멸 중
  그레인은 `wash_dir*(26~86)px` 수평 + `(12~34)px` 하강 드리프트하며 알파 페이드.
  글로우 ×(1-2·wash_p), 코너 ×(1-2.5·wash_p), 바닥 틴트 ×(1-wash_p).
- `PHASE_RETRY_WAIT`: 감옥 draw 없음(이미 쓸려나감; 재소환이 새로 지음).
- 바람 파티클: MISS 진입 시 `_spawn_wind_sweep()` — 벽 9×2 + 바닥 10 그레인,
  `vx = dir*(70~150)`, 하강 vy, **life 0.25~0.42s** (MISS_SECONDS 안에 전멸 —
  최종 MISS의 reset() 클리어에 잘리는 알갱이 없음).
- 씰: `_verify_miss_wind_sweep_direction` (좌/우 도주 각각 — 바람 그레인
  |vel.x|≥50 전부 도주 방향, wash_dir ±1; **반증검증 RED 확인**: 방향 고정
  토글 시 왼쪽 케이스 2어서션 실패) + visual smoke MISS 세척 draw 실행 커버.

Original params for reference (implemented above):
- **Grain walls**: replace the smooth wall rect with per-strip noise — 3px-tall strips,
  color jitter `r∈[185,220] g∈[155,180] b∈[80,110]` (`hero_skills.py:15571-15576`),
  instead of / on top of the solid rect + shine stripes.
- **Corner ornaments**: 4 sandy circles (`r=6`, color `(200,170,90)`, alpha `0.7`) at the
  wall/floor corners, appearing at `visible_ratio>0.8` (`15603-15612`).
- **Soft wall glow**: 24px-wide horizontal-gradient glow blob at each wall mid-height,
  `alpha*0.3` falloff (`15579-15586`) — consider replacing the diagonal shine stripes.
- Floor: drop the floor alpha toward the original's faint `≈22/255 * ratio` (currently
  darker/more opaque) and gate the top bar to `>0.9` like the original.
