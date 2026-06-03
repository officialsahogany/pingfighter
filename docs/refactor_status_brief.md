# Refactoring Status Brief

> Last updated: 2026-05-28

One-page current state of the Godot port. For operational rules and
module routing, see `AGENTS.md`. For the full module ledger, see
`docs/godot_module_ownership_ledger.md`.

## Snapshot Delta

| Metric | 2026-05-11 snapshot | Current (2026-05-28) | Delta |
|---|---|---|---|
| `godot/scripts/` .gd files | 582 | 839 | +257 (+44%) |
| `godot/tests/` .gd files | 299 | 510 | +211 (+71%) |

Notable changes since the snapshot:

- Stage 5 moved from the old `Stage 5+ / Not yet ported` bucket to an
  active Hongryun slice with 12 `stage5_hongryun_*` modules.
- Stage 2 Monkey is now the largest stage module cluster at 67 `.gd` files.
- The snapshot in `AGENTS.md` remains useful as provenance, but this file is
  the live progress brief.

## Script Distribution

| Folder | Files | Notes |
|---|---|---|
| `scripts/core/` | 139 | Match flow, scene orchestration, context builders |
| `scripts/characters/` | 161 | Smasher 65, Commando 58, Viper 24, Optimus 2 |
| `scripts/items/` | 201 | Active/passive/legendary/mythic item runtimes |
| `scripts/stages/` | 140 | Common (3), Stage 1 (33), Stage 2 (67), Stage 3 (9), Stage 4 (15), Stage 5 (12), root (1) |
| `scripts/hud/` | 70 | Pillar HUD, gauge orbs, scoreboard, tooltips |
| `scripts/ball/` | 68 | Ball physics, speed policy, VFX, collision |
| `scripts/ui/` | 21 | UI utilities |
| `scripts/resources/` | 15 | Texture/resource loader, module registry |
| `scripts/effects/` | 14 | Particles, screen shake, impact VFX |
| `scripts/audio/` | 4 | Sound loading, loop cleanup |
| `scripts/ai/` | 3 | Boss AI |
| `scripts/status/` | 3 | Slow/stun/confusion/reverse/burn states |

## Stage Porting Status

| Stage | Boss | Status | Module count |
|---|---|---|---|
| Stage 1 | 달지 (Dalji) | ✅ Substantially complete | 33 .gd |
| Stage 2 | 몽키 (Monkey) | ✅ Substantially complete; largest stage cluster | 67 .gd |
| Stage 3 | 멘헤라 (Menhera) | ✅ Basic complete | 9 .gd |
| Stage 4 | 퐁크 (Ponk) | ✅ Basic complete | 15 .gd |
| Stage 5 | 홍련 (Hongryun) | 🔧 In progress; no longer in the old unported bucket | 12 .gd (inferno FX, pillar, state, fire machine) |
| Stage 6 | 테트리서 (Tetriser) | 📋 Planning started | Port of Python Stage 7; plan: docs/stage6_tetriser_port_plan.md |
| Stage 7+ | — | ⬜ Not started | Roadmap backlog (8 아카무 리고 / 9~12) |

## Character Status

| Character | Status | Prefixed files | Key systems |
|---|---|---|---|
| Smasher | ✅ Core complete | 65 | Dash, Drive, Power Smash, Ghost Shot, Wheel, Plasma, Warp Gate, Shield Kiting, Magnum Grip, Combo |
| Commando | ✅ Basic complete | 58 | Firearm runtime, support aircraft, suicide drone, supply drop, weapon controller |
| Viper | ✅ Basic complete | 24 | Skill runtime, Jetpack, EMP, Chaos Spear, Shadow Step |
| Optimus | 🔧 Early | 2 | Minimal presence |
| Baltor/Blacksmith | ⬜ Not started | 0 | — |

## Remaining Risks

- **Stage 5 홍련** is in progress but not complete — inferno burst/trail/charge
  FX hosts exist, fire machine event exists, but boss AI, full skill set, and
  integration QA are still ahead.
- **Stage 2 몽키** has the largest stage module footprint. Treat future edits
  there as broad-stage work, not a small isolated patch.
- **Optimus and Baltor/Blacksmith** have minimal or no Godot presence.
- **Stage 3/4 module counts are low** (9 and 15) compared to Stage 1/2
  (33 and 67), suggesting lighter integration or potential gaps.

## Verification Baseline

- Headless load check: `tools/run_headless_load_check.ps1`
- Smoke tests: `tools/run_smoke_tests.ps1` (510 tests)
- Warning scan: `tools/run_warning_scan.ps1`
- Windows build: `tools/build_windows.ps1`
