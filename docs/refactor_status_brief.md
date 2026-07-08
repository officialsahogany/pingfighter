# Refactoring Status Brief

> Last updated: 2026-07-09

현재 Godot 포트 리팩터링 상태를 한 장으로 요약한다. 운영 규칙은
`AGENTS.md`, 현재 경계는 `docs/current_development_boundary.md`, 모듈별
소유권 근거는 `docs/godot_module_ownership_ledger.md`를 따른다.

## Snapshot Delta

| Metric | 2026-05-11 snapshot | Current (2026-07-09) | Delta |
|---|---:|---:|---:|
| `godot/scripts/` `.gd` files | 582 | 1349 | +767 (+132%) |
| `godot/tests/` `.gd` files | 299 | 922 | +623 (+208%) |
| `godot/tests/*_smoke.gd` files | n/a | 920 | n/a |

Key movement since the old brief:

- `godot/scenes/main.gd` remains the intended one-line shell extending
  `res://scripts/core/battle_scene_shell.gd`.
- Stage 5 is no longer an unported bucket: Hongryun has routed actor, boss
  actor, pillar/background, playfield, state, fire-machine, and boss skill-card
  HUD owners, and the stage-clear result screen now routes the existing
  Hongryun victory sheet as a fallback actor with a short click pulse.
- Stage 6 is runtime-present: Tetriser has routed runtime, playfield, boss
  sprite, static pillar background, Crystal Shield, and boss skill-card HUD
  owners. Loading and stage-clear result backgrounds now route through existing
  Tetriser art, and the stage-clear boss-defeat slot now uses the existing
  Tetriser defeat sheet with a short click pulse reaction. A dedicated
  high-polish result Live2D sheet remains a visual gap.
- Ringpet / Lingpet is a major split surface with 127 modules. Every current
  `godot/scripts/lingpet/*.gd` file has a ledger entry as of this snapshot.
- Stage 2 boss rendering is now sprite-backed; procedural alligator rendering
  is a missing-asset fallback, not the primary implementation.

## Script Distribution

| Folder | Files | Notes |
|---|---:|---|
| `scripts/items/` | 210 | Active/passive/legendary/mythic item runtimes and field effects |
| `scripts/stages/` | 199 | Stage routing, boss states, backgrounds, playfields, skill HUDs |
| `scripts/characters/` | 243 | Smasher, Commando, Viper, Optimus, Blacksmith, shared player state |
| `scripts/core/` | 201 | Match flow, scene shell, context builders, debug pickers |
| `scripts/lingpet/` | 127 | Affinity, hatch/loadout, language, active/passive skills, feed/item-egg flows |
| `scripts/hud/` | 130 | Pillar HUD, gauge orbs, scoreboards, tooltips, overlays |
| `scripts/ball/` | 69 | Ball physics, speed policy, collision, VFX helpers |
| `scripts/ui/` | 95 | UI components and menu helpers |
| `scripts/resources/` | 25 | Module catalogs, loaders, sprite/resource paths |
| `scripts/effects/` | 22 | Reusable VFX hosts, particles, screen shake, impact helpers |
| `scripts/plaza/` | 16 | Plaza shell, save/economy, shop/bank/gacha/academy/tavern flows |
| `scripts/status/` | 5 | Shared status state, boss slow tiers, status overlays |
| `scripts/audio/` | 4 | Audio loading/routing and loop cleanup |
| `scripts/ai/` | 3 | Boss AI and prediction state |

## Stage Status

| Stage | Boss / route | Status | Module count |
|---|---|---|---:|
| Stage 1 | Dalji / Gaksital / Pododaejang slices | Substantially ported and sprite-backed | 48 |
| Stage 2 | Monkey / alligator boss route | Substantially ported; largest stage cluster | 68 |
| Stage 3 | Menhera | Basic route and boss-skill HUD present | 13 |
| Stage 4 | Ponk | Route, idle-sheet actor, skill-card HUD, magnetic/meditation FX, and result background/fallback actor click pulse present; full dedicated action/result sheet set incomplete | 27 |
| Stage 5 | Hongryun | Active Godot Stage 5 route with routed state, actor, playfield, pillar/background, fire-machine, boss skill-card HUD, and result background/fallback actor click pulse | 15 |
| Stage 6 | Tetriser | Runtime route present with boss sprite, playfield, static pillar background, Crystal Shield, and boss skill-card HUD; loading/result backgrounds and result boss-defeat slot/click pulse routed from existing Tetriser art, dedicated result Live2D polish pending | 9 |
| `common` | Shared stage helpers | Boss skill-card sizing, rail helpers, shared stage utilities | 18 |
| `root` | Stage router | `stage_runtime_router.gd` role-to-module routing | 1 |

## Character Status

| Character surface | Files | Current read |
|---|---:|---|
| Smasher-prefixed | 70 | Mature core skill/runtime surface |
| Commando-prefixed | 59 | Mature firearm/supply/support runtime surface |
| Viper-prefixed | 47 | Mature skill runtime surface with several split helpers |
| Optimus-prefixed | 2 | Early runtime presence |
| Blacksmith-prefixed | 5 | Early runtime/config/shield surface |
| Baltor-prefixed | 0 | No Godot character surface yet |
| Shared/generic player/runtime-perk surface | 60 | Movement, lock proxy, customization overlay, runtime perk state/catalog |

## Ringpet / Lingpet Status

- Current module count: 127 `.gd` files under `godot/scripts/lingpet/`.
- Ownership coverage: 0 current Lingpet `.gd` files missing from
  `docs/godot_module_ownership_ledger.md`.
- Current second active/passive unlock contract: first active + passive
  effective level sum `>= 5`, then deterministic 30% roll on level-up. Fixed
  Lv.22 / Lv.25 unlock-card wording is historical only.
- Implemented ownership surfaces include affinity state/store/income, ring-core
  cap rules, hatch/loadout/current-profile projection, language catalog /
  decoder / rich text, skill dispatcher, per-skill runtime modules, passive
  state helpers, item-egg absorb, feed bowl, and visual texture cache.

## Remaining Risks

- Stage 4 Ponk now has result background and an idle-sheet fallback actor /
  click pulse, but still needs the full dedicated action/result sheet set
  before it should be described as visually complete.
- Stage 5 Hongryun is routed and visually active, including a reused-sheet
  result click pulse, but still needs continued parity / polish QA and a
  dedicated high-polish result sheet before treating the whole stage as
  complete.
- Stage 6 Tetriser runtime/result routing is present, including a reused-sheet
  result click pulse, but a dedicated high-polish result Live2D sheet remains
  pending.
- Optimus and Blacksmith are early; Baltor has no Godot character surface yet.
- The repo remains a dirty-worktree environment with many unrelated modified
  and untracked docs/assets. Do not revert unrelated files while briefing or
  refactoring.

## Verification Baseline

- Load check: from `godot/`, run `.\tools\run_headless_load_check.ps1`.
- Warning scan: from `godot/`, run `.\tools\run_warning_scan.ps1`.
- Focused smokes: from `godot/`, run `.\tools\run_smoke_tests.ps1 -Tests ...`.
- Last focused briefing verification on this branch included:
  `stage2_boss_idle_sprite_smoke`, `stage4_map_port_smoke`,
  `stage5_hongryun_visual_shell_smoke`,
  `lingpet_active_skill_slot_resolver_smoke`, and
  `lingpet_skill_runtime_surface_smoke`.
- This brief's numeric snapshot is guarded by
  `refactor_status_brief_smoke`.

## Refresh Commands

Run these from the repository root when updating this brief:

```powershell
(rg --files -g "*.gd" godot\scripts | Measure-Object).Count
(rg --files -g "*.gd" godot\tests | Measure-Object).Count
(rg --files -g "*_smoke.gd" godot\tests | Measure-Object).Count

$folders = 'items','stages','characters','core','lingpet','hud','ball','ui','resources','effects','plaza','status','audio','ai'
foreach ($f in $folders) {
  $c = (rg --files -g "*.gd" "godot\scripts\$f" | Measure-Object).Count
  "$f=$c"
}

Get-ChildItem godot\scripts\stages -Directory | Sort-Object Name | ForEach-Object {
  $c = (rg --files -g "*.gd" $_.FullName | Measure-Object).Count
  "$($_.Name)=$c"
}
(Get-ChildItem godot\scripts\stages -File -Filter *.gd | Measure-Object).Count
```

For Lingpet ownership coverage, compare the current script list against
`docs/godot_module_ownership_ledger.md`; the expected missing count for this
snapshot is `0`.
