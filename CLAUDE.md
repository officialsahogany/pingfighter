# CLAUDE.md

This file is the standing rulebook for Claude working on PingFighter. It
captures invariants and hidden-knowledge bug patterns that cannot be safely
re-derived from the code. Procedural setup (how to run, how to build, how to
test) is intentionally NOT listed here -- read the repo state, `AGENTS.md`,
or `README.md` when needed.

## 0. Implementation Boundary with `AGENTS.md`

- `CLAUDE.md` (this file) = Claude-side project standing rules and asset-prep
  routing.
- `AGENTS.md` = runtime integration, performance, and implementation source
  of truth for Codex/agent work.
- `.claude/skills/sprite-generation/` = the full sprite-sheet pipeline
  playbook (prompts, nukki, QA).

If the documents conflict:
- Runtime / performance -> `AGENTS.md` wins.
- Sprite-sheet generation details -> the `sprite-generation` skill wins.
- Everything else (hidden-knowledge rules, coordinate standards, stage
  mapping) -> this file wins.

## Boss Sprite Work

Any work involving boss/character sprite sheets -- creation, regeneration,
walk / attack / dash / turn (facing transition) sheets, background removal
(nukki), or Gemini MCP image generation -- must be handled via the
**`sprite-generation` skill** at `.claude/skills/sprite-generation/`. That
skill owns the full pipeline: prompt templates, identity and scale lock
rules, content-filter bypass vocabulary, the nukki algorithm, and the
reject/regenerate QA checklists.

**If the skill is not auto-triggered, explicitly invoke
`/sprite-generation` before proceeding.** Do not recreate sprite rules
from memory -- always route through the skill so identity and scale lock
stay consistent across bosses.

### Invariants that remain here (do not re-derive from the skill)

- **Canonical reference = walking sheet.** `items/[name]_boss_sheet.png`
  is the identity anchor for every subsequent sheet of the same boss.
  Attack, dash, and turn sheets must read as the same character.
- **Same boss, same identity across all sheets.** Hair color, hairstyle,
  face, eyes, skin tone, proportions, outfit, and signature accessories
  must not drift between walk / attack / dash / turn.
- **Body scale lock (+/-5%).** Head, torso, and pelvis must stay within
  +/-5% of the walking sheet. Express speed with pose, lean, effects, and
  motion lines -- never by resizing the body.
- **File path convention:**
  - Walk:   `items/[name]_boss_sheet.{jpeg,png}`
  - Attack: `items/[name]_boss_attack.{jpeg,png}`
  - Dash:   `items/[name]_boss_dash.{jpeg,png}`
  - Turn:   `items/[name]_boss_turn.{jpeg,png}` (optional aux sheet)
  - Class:  `entities/[name]_boss_sprite.py`
- **Offline nukki is a runnable CLI.** The algorithm lives in
  `.claude/skills/sprite-generation/remove_bg.py` and runs as
  `py .claude/skills/sprite-generation/remove_bg.py <src.jpeg> <dst.png>`.
  The in-class JPEG cleanup inside sprite classes is a runtime safety
  net only; the offline PNG is the source of truth.

### Role split with `AGENTS.md`

- **Claude + this skill:** sheet generation, prompt design, nukki,
  offline PNG preparation, standalone sprite class scaffold.
- **Codex + `AGENTS.md`:** `pingfighter.py` import/init/reset wiring,
  stage render branch, loader caching, runtime scaling, per-frame
  performance. Runtime integration is `AGENTS.md`'s source of truth
  and is not duplicated into the skill.

---

## CRITICAL: Stage Order Reference (code stage != real stage)

Stage 5 and Stage 6 were swapped in code variable names. The code name and
the user-facing stage number do not agree. This is the single biggest
source of "wrong stage edited" bugs.

| Stage | Boss           | Theme                   | Pillar               | Code name (mismatch alert)   |
|-------|----------------|-------------------------|----------------------|------------------------------|
| 1     | Pungakboi      | Korean traditional      | pillar_stadium       | stage1                       |
| 2     | Akeojanggun    | Jungle / swamp          | pillar_jungle        | stage2                       |
| 3     | Menheragirl    | Menhera / doll          | pillar_menhera       | stage3                       |
| 4     | Pongk          | Temple                  | pillar_temple        | stage4                       |
| **5** | **Nemesis**    | **Ocean / Battleship**  | pillar_nemesis_ocean | **animated_bg_stage6** !!    |
| **6** | **Honglyeon**  | **Chinese fire**        | (TBD)                | **animated_bg_stage5** !!    |
| 7     | Tetriser       | Tetris arena            | -                    | stage7 / `game_logic/stage7_tetriser.py`, `stages/stage7_boss.py` |
| 8     | Akamu Rigo     | Shadow dojo (reuses stage7_field) | -          | stage8 / `entities/stage8_boss_sprite.py` |

### Code names vs real stage mapping

- Code `stage5`, `animated_bg_stage5`, `Stage5ChineseMarket` = **real Stage 6 Honglyeon (fire)**
- Code `stage6`, `animated_bg_stage6`, `AnimatedBackgroundStage6` = **real Stage 5 Nemesis (ocean)**

When the user says "work on stage 5" they mean Nemesis (ocean). When they
say "work on stage 6" they mean Honglyeon (fire). Do not trust the
variable name -- always confirm by theme.

---

## CRITICAL: Screen Coordinate Standards

All items, skills, projectiles, and effects must follow this coordinate
contract. Key point: the game physics area is the **full screen 0 to WIDTH**.
Pillars are only UI overlays, not physical boundaries.

```
+------------------------ 760px (WIDTH) ------------------------+
|         Physics area: 0 - 760 (ball, paddle, projectiles)    |
|                                                              |
|   +- pillar -+                             +- pillar -+      |
|   | 0 - 79   |    UI overlay drawn on top  | 680-759  |      |
|   | 80px     |    item spawn center: 380px | 80px     |      |
|   +----------+                             +----------+      |
|                                                              |
|  Ball bounces at: BALL.left <= 0 and BALL.right >= WIDTH     |
+--------------------------------------------------------------+
```

### Screen size constants (see `config/constants.py`)

| Constant                     | Value | Meaning |
|------------------------------|-------|---------|
| `WIDTH` / `INTERNAL_WIDTH`   | 760px | Physics area width (ball, paddle, effects all in this range) |
| `HEIGHT` / `INTERNAL_HEIGHT` | 750px | Screen height |
| `PILLAR_UI_WIDTH`            | 80px  | Each pillar UI overlay width (NOT a physics boundary) |
| `GAME_AREA_OFFSET_X`         | 80px  | Pillar offset (for UI placement only) |
| `GAME_PLAY_WIDTH`            | 600px | Pillar-excluded center width (for UI placement / item spawn) |

### Which width to use

| Work type                      | Width to use         | Range     | Why |
|--------------------------------|----------------------|-----------|-----|
| Effects / barriers / walls     | `WIDTH` (760)        | 0 - 760   | Ball travels full width |
| Ball bounce / paddle motion    | `WIDTH` (760)        | 0 - 760   | Physics boundary = full screen |
| Item spawn                     | `GAME_PLAY_WIDTH` (600) | 80 - 680 | Do not spawn behind pillars |
| UI element placement           | `GAME_PLAY_WIDTH` (600) | 80 - 680 | Avoid pillar overlap |
| Boss / paddle center X         | `WIDTH // 2` (380)   | -         | Center relative to full screen |

```python
# Wrong: barrier / effect uses GAME_PLAY_WIDTH -> leaves 80px gap on left
barrier_left = GAME_AREA_OFFSET_X
barrier_width = GAME_PLAY_WIDTH

# Right: barrier / effect uses full screen width
barrier_left = 0
barrier_width = WIDTH

# Right: item spawn stays within pillar-excluded area
spawn_x = GAME_AREA_OFFSET_X + random(0, GAME_PLAY_WIDTH)  # 80 - 680
```

### Y coordinate reference

| Object                   | Y       | Notes |
|--------------------------|---------|-------|
| Boss paddle              | 25      | Top 25px of screen |
| Boss hitbox bottom       | ~65     | BOSS_Y(25) + BOSS_HEIGHT(40) |
| Boss side region         | 0 - 120 | Top area where the boss acts |
| Center line              | 375     | HEIGHT / 2 |
| Player paddle            | 710     | HEIGHT(750) - 40 |
| Player side region       | 630 - 750 | Bottom area where the player acts |

### Side classification (projectiles, items)

| Side         | Y range       |
|--------------|---------------|
| Boss side    | Y < 120       |
| Neutral      | 120 <= Y < 630 |
| Player side  | Y >= 630      |

---

## Resource Loading and Korean Text

- **Always** load assets via `resource_path(relative)`. Never hardcode
  absolute paths. Use `os.path.join` for path construction. This is what
  makes PyInstaller builds work on both Windows and macOS.
- Render Korean text with `pygame.freetype` + `fonts/NanumSquareB.ttf`.
  The default pygame font does not cover Hangul.
- Open text files with `encoding="utf-8"`.

---

## CRITICAL: Passive Item Registration Checklist

Bug pattern: a new passive item drops on the field but never lands in the
inventory, or drops infinitely, or gets routed to an active slot. Prevent
by touching ALL ten locations below. Missing any one of them causes a
silent failure mode.

| # | File | Location | Action |
|---|------|----------|--------|
| 1 | `items.py` | `ITEM_TYPES` array | Add item definition (`chance`, `body_part`, etc.) |
| 2 | `items.py` | `unlocked_items` dict | `"[item_name]": True` (required) |
| 3 | `items.py` | `[item_name]_obtained` var | Module-level flag (e.g. `gold_digger_obtained = False`) |
| 4 | `items.py` | `update_items()` passive list | Add name (required; otherwise treated as active) |
| 5 | `items.py` | `spawn_random_item()` `passive_names` | Add name (drop-weight calculation) |
| 6 | `items.py` | `spawn_random_item()` dedup | `if item["name"] == "[item_name]" and [item_name]_obtained: ...` |
| 7 | `items.py` | `PASSIVE_DUPLICATE_ALLOWED` set | Add when duplicate farming is allowed |
| 8 | `pingfighter.py` | `store_active_item()` passive filter | Add name (prevents active-slot misroute) |
| 9 | `pingfighter.py` | `store_passive_item()` | `elif item_data["name"] == "[item_name]":` branch |
| 10 | `pingfighter.py` | `store_passive_item()` duplicate-allowed branch | **Never use `skip_append = True`** -- see next section |

### Duplicate-allowed passive: `skip_append` is forbidden

For items in `PASSIVE_DUPLICATE_ALLOWED` (e.g. `gold_digger`):

```python
# WRONG: duplicate acquire silently skips inventory append
elif item_data["name"] == "gold_digger":
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        # activate/equip ...
    else:
        print("already owned")
        skip_append = True   # <-- BUG: second acquire never appears in inventory

# RIGHT: first-acquire activates, every acquire runs rolls and falls through to append
elif item_data["name"] == "gold_digger":
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        from item_effects.gold_digger import activate_gold_digger, equip_gold_digger
        activate_gold_digger()
        equip_gold_digger()
    item_data["type"] = "passive"
    ensure_passive_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
    # no skip_append; function-end handles inventory append
```

Rules:
1. `PASSIVE_DUPLICATE_ALLOWED` items never set `skip_append = True`.
2. Only first acquire sets `obtained` and activates/equips.
3. `ensure_passive_rolls` + `apply_roll_bonuses_from_item` run **every** acquire.
4. Inventory append is automatic at function end when `skip_append` is False.

---

## CRITICAL: Legendary Item Registration Checklist

Legendary items need everything in the passive checklist plus:

| # | File | Location | Action |
|---|------|----------|--------|
| 1 | `legendary_items.py` | class definition | `class [ItemName](LegendaryItem):` |
| 2 | `legendary_items.py` | `LEGENDARY_ROLL_OPTIONS` | Add roll-option definitions |
| 3 | `legendary_items.py` | `LegendaryItemManager._init_legendary_items()` | Create instance |
| 4 | `pingfighter.py` | `get_item_icon()` legendary name list | Add name (required; otherwise icon shows `?`) |
| 5 | `pingfighter.py` | Legendary obtained-flag sync | Add `sync_bool()` call |
| 6 | `items.py` | `spawn_random_item()` `legendary_names` | Add name (spawn rate) |
| 7 | `downtown/constants.py` | `LEGENDARY_ITEM_NAMES` | Add name |
| 8 | `downtown/building_interior.py` | Shop legendary list | Add for shop sale |

### Legendary is always passive -- never goes to an active slot

Filter all legendary names in `store_active_item()`:

```python
if item_data["name"] in [..., "ragnarok_hammer", "hermes_shoes", "poseidon_trident"]:
    return
```

### Legendary always allows duplicates (`skip_append` forbidden)

Same rule as duplicate passives -- legendary duplicates are needed for
roll-option farming. First acquire runs unlock + legendary-manager
registration + acquisition animation. Every acquire (first and later)
runs `item_data["type"] = "legendary"`, `ensure_passive_rolls`,
`apply_roll_bonuses_from_item`, and lets function-end append to the
inventory. No `skip_append = True`.

### Legendary polish perk + enhancement integration

Every legendary roll-option property must apply both polish perks and the
enhancement buff.

```python
class NewLegendaryItem(LegendaryItem):
    def __init__(self):
        super().__init__(...)
        self.enhancement_bonus_pct = 0  # synced on equip

    @property
    def some_stat(self) -> float:
        return get_legendary_roll_value(
            "new_legendary_item",
            "stat_key",
            apply_polish=True,                            # polish perk
            enhancement_bonus_pct=self.enhancement_bonus_pct,  # enhancement buff
        )
```

Sync hook in `sync_equipped_passive_effects()`:

```python
# on equip
if legend_name == "new_legendary_item":
    item = next((i for i in equipped_items if i.get("name") == "new_legendary_item"), None)
    if item:
        legendary = legendary_manager.get_item("new_legendary_item")
        if legendary:
            legendary.enhancement_bonus_pct = item.get("enhancement_bonus_pct", 0)

# on unequip
elif legend_name == "new_legendary_item":
    legendary = legendary_manager.get_item("new_legendary_item")
    if legendary:
        legendary.enhancement_bonus_pct = 0
```

Already-integrated legendary items (polish + enhancement both applied):
`odin_eye`, `poseidon_trident`, `hermes_shoes`, `ragnarok_hammer`,
`sacred_laurel`, `angel_blessing`, `transcendent_crown`.

---

## CRITICAL: Perk Icon Rendering (hidden elif chains)

### The elif-chain trap

`draw_skill_icon_mini()` in `pingfighter.py` is a multi-thousand-line
hardcoded elif chain on `skill_id`. **New perks do not auto-render.** A
perk without an elif branch falls through to `else` and shows only the
first letter of the skill name -- which reads as a broken icon in QA.

This applies to both:
- General perks (entries in `VIPER_EXCLUSIVE_SKILLS`, e.g. `jetpack_enhance`).
- **Skill-unlock perks** with `unlock_*` prefix (e.g. `unlock_magnum_grip`,
  `unlock_plasma`, `unlock_recovery_skill`, `unlock_cleanse`,
  `unlock_ghost_shot`, `unlock_nerve_strike`, `unlock_dive_strike`). These
  live in a separate dict and are easy to forget.

Fix: always add the elif branch immediately above the final `else:` in
`draw_skill_icon_mini()`.

```python
elif skill_id == "new_perk_id":
    ...  # pygame.draw a polished icon
elif skill_id == "unlock_new_skill":
    ...  # pygame.draw + a "+" unlock badge
else:
    symbol = skill.get("name", "?")[0]  # fallback -- means the branch is missing
```

### New-perk registration checklist

| # | Step |
|---|------|
| 1 | Add to `VIPER_EXCLUSIVE_SKILLS` (name, max_level, descriptions, detail, icon_color) |
| 2 | Handle level-up in `apply_runtime_skill_effect()` |
| 3 | **Add elif branch in `draw_skill_icon_mini()` -- required, or icon breaks** |
| 4 | Apply the actual gameplay effect via `runtime_skill_levels.get("perk_id", 0)` |
| 5 | Add `global` declarations in every function that mutates perk-related globals |

### General perk vs skill-type perk (5-orb slot)

Perks have two kinds, registered differently:

| Kind                     | Defined in                                       | HUD                              | Cooldown |
|--------------------------|--------------------------------------------------|----------------------------------|----------|
| General (passive boost)  | `VIPER_EXCLUSIVE_SKILLS`                         | `draw_viper_perk_icons()` (small icon beside orbs) | none |
| Skill-type (5-orb slot)  | `VIPER_EXCLUSIVE_SKILLS` **and** `VIPER_SKILL_ICONS_DATA` | `draw_viper_skill_icons()` (5-orb slot) | `cooldown` field |

Any perk with a cooldown or activation condition MUST be registered as
skill-type. Skill-type perks require entries in `_viper_skill_unlocked`,
`_viper_skill_cooldowns`, `_viper_skill_activation_times`,
`_viper_skill_was_active`, plus `unlock_viper_skill()` +
`equip_viper_skill()` plumbing in `apply_runtime_skill_effect()`.

```python
# apply_runtime_skill_effect() -- skill-type unlock + equip pattern
if choice_id == "new_skill_perk":
    unlock_viper_skill("new_skill_perk")
    equip_result = equip_viper_skill("new_skill_perk")
    if not equip_result:
        removed = _show_viper_skill_swap_dialog("new_skill_perk")
        swap_viper_skill(removed, "new_skill_perk")
    runtime_skill_levels["new_skill_perk"] = 1
    return True
```

For a general-perk HUD icon:

```python
_new_perk_lv = get_runtime_skill_level("new_perk_id")
if _new_perk_lv > 0:
    viper_perks.append({
        "name": "new_perk_id",
        "color": (R, G, B),
        "cost": 0,
        "symbol": "XX",
        "always_active": True,
    })
```

### HUD 5-orb rendering goes through TWO functions

```
_viper_equipped_skills
  -> match in VIPER_SKILL_ICONS_DATA
    -> _draw_skill_icon_symbol()   (HUD-only polished symbol)
      -> fallback: draw_skill_icon_mini()
```

| Function | Role |
|----------|------|
| `draw_skill_icon_mini()` | Generic icon for perk choice UI, TAB info, etc. |
| `_draw_skill_icon_symbol()` | HUD 5-orb only -- polished symbol |

Adding the elif to `draw_skill_icon_mini()` alone keeps the HUD from
breaking (there is a fallback call inside `_draw_skill_icon_symbol()`).
For a polished HUD-specific icon, add a dedicated branch in
`_draw_skill_icon_symbol()` too.

Tooltip-missing checkpoints: entry exists in `VIPER_SKILL_ICONS_DATA`
(name, korean, cost, description), `_viper_skill_icon_rects` updated every
frame, `is_viper_skill_unlocked()` returns True on hover.

---

## CRITICAL: Perk/Skill UI Text Audit -- seven render paths

When changing perk level display, name, or tooltip text, fix **all seven**
render paths below. Fixing one leaves stale text in the other six.

| # | Screen | Function |
|---|--------|----------|
| 1 | Perk choice card (in-game) | `show_runtime_skill_choices()` |
| 2 | Stage clear perk choice | `show_stage_clear_choices()` |
| 3 | Stage clear overlay | `draw_stage_choice_overlay()` |
| 4 | Perk status screen (ESC menu) | `show_perk_status()` -> `draw_level_gauge()` |
| 5 | TAB character info perk tab | `draw_character_info_panel()` perk grid |
| 6 | Perk status tooltip | `draw_tooltip()` / `draw_skill_tooltip_mini()` |
| 7 | Victory screen perk tooltip | `show_victory_screen()` `hovered_tooltip` |

Why the duplication: each screen composes its own `f"Lv.{level}"` instead
of sharing a renderer. Also check data-passing helpers like
`get_acquired_skills()` for the fields downstream branches expect.

Quick audit before calling the work done:

```bash
grep -n 'Lv\.' pingfighter.py | grep -i 'render\|text\|line'
grep -n 'name_line\|tooltip_name\|perk_name.*Lv' pingfighter.py
grep -n 'character_restriction' pingfighter.py | grep -v '#\|print\|CLAUDE'
```

---

## CRITICAL: Graphics & Effects Performance

Rendering pipeline today:
- **Windowed:** `pygame.SCALED` + GPU 2x upscale. No per-frame CPU scaling.
- **Fullscreen:** CPU software scaling, fast enough via DWM bypass.

### Free to do (no perf impact)

| Action | Why |
|--------|-----|
| Add more particles / effects | `gfxdraw` direct rendering has very low per-unit cost |
| Vary colors / alpha | `gfxdraw` color changes are free |
| Add background detail | Drawn on top of cached backgrounds |
| Add new effects | Safe as long as the `gfxdraw`/surface-pool patterns below are followed |
| Upgrade skill-effect fidelity | Bottleneck was scaling, not content |

### Still watch for (CPU + pygame territory)

| Pattern | Why bad | Fix |
|---------|---------|-----|
| `pygame.Surface(..., SRCALPHA)` inside a loop | Per-frame allocation -- biggest killer | Surface pool or `gfxdraw` |
| `pygame.transform.rotate/scale` per frame | CPU-heavy | Cache results, key by angle/size |
| Thousands of `pygame.draw` calls | Volume matters even when per-call is cheap | Reduce count or batch |
| Full-screen `Surface.fill()` spam | 760*750*4 = 2.3MB cleared every time | Clear only the dirty region |
| Wide SRCALPHA blending | Alpha blending is CPU-expensive | Minimize transparent surfaces |

### Effect authoring pattern

```python
# Wrong: per-frame Surface + rotate
def update_particle(self):
    surf = pygame.Surface((20, 20), pygame.SRCALPHA)
    surf = pygame.transform.rotate(surf, self.angle)
    screen.blit(surf, self.pos)

# Right: gfxdraw direct
def update_particle(self):
    pygame.gfxdraw.filled_circle(
        screen, int(self.x), int(self.y), self.radius, self.color
    )

# Right: surface pool + cached rotation
class ParticlePool:
    def __init__(self):
        self.cached = {}

    def get_rotated(self, base, angle):
        key = int(angle) % 360
        if key not in self.cached:
            self.cached[key] = pygame.transform.rotate(base, key)
        return self.cached[key]
```

One-liner: do not create a new `pygame.Surface` or call
`pygame.transform.rotate/scale` per frame per particle. Use `gfxdraw`
directly or a surface pool.

---

## CRITICAL: Safe Git Rollback

**Never run `git reset --hard` with uncommitted changes.** Work will be
lost silently.

Safe sequence:

```bash
# 1. Save current state
git stash -u -m "pre-rollback backup"
# or
git add -A && git commit -m "WIP: pre-rollback snapshot"

# 2. Roll back
git reset --hard <commit>

# 3. Restore (if stashed)
git stash pop
```

Safer alternatives:

| Scenario | Command |
|----------|---------|
| Revert one file | `git checkout <commit> -- <file>` |
| Test a revert without committing | `git checkout -b test-branch <commit>` |
| Undo a commit while keeping history | `git revert <commit>` |
| Full rollback safely | `git stash -u` -> `git reset --hard` |

Recovery:
- Stashed -> `git stash list`, then `git stash pop`
- Committed -> `git reflog`, then `git checkout <hash>`

When rolling back: `pingfighter.py` and its sibling modules (`start_menu.py`,
`items.py`, etc.) must land on the same version together. Spot-reverting one
file without the rest breaks imports and state.

---

## Repository info

- Remote: `https://github.com/officialsahogany/pingfighter.git`
- Working branch at start of this doc: `feature/refactor-ui`
