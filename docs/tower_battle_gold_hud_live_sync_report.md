# 전투 금화 HUD 실시간 동기화 완료 보고 (2026-08-21)

## 결론

- 결함은 HUD 표시 경로가 아니라 **전투 금화 적립 경로**였다.
- 탑 필러 HUD는 이미 활성 런의 `run_state.gold`만 읽고
  (`godot/scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd:588`), 상점 모달도
  같은 런 잔액을 사용한다 (`godot/scripts/tower_ascent/tower_ascent_node_modal_state.gd:144`).
- 반면 전투 금화는 `runtime_perk_gold` 호환 누적기에만 저장되어 런 상태로 들어가지
  않았다. §3.16의 소유권 계약은 런 골드 소유자를 `run_state.gold`로 확정한다
  (`docs/tower_ascent_run_map_plan.md:608`, `docs/tower_ascent_run_map_plan.md:618`).
- 따라서 사용자 확정 "가"안을 유지하고, 활성 탑 런에서 발생한 전투 금화를 즉시
  런 경제로 적립하도록 수정했다. 광장 골드는 다시 섞지 않았다.

## 구현

- `runtime_perk_gold_award_flow.gd:158`에서 모든 표준 금화 결과를 한 곳에서 분기하고,
  `runtime_perk_gold_award_flow.gd:230`에서 registry의 캐시된
  `tower_ascent_flow_owner`만 조회한다. 활성 런이 없으면 종전 일반 캠페인 누적 경로를
  그대로 탄다.
- `tower_ascent_flow_economy_progress.gd:7`의 `collect_gold()`가 이미 시작된 런에만
  `apply_reward_bundle({"gold": amount})`를 적용한다. 캐시만 존재하는 일반 캠페인에서
  런을 새로 만들지 않는다.
- 일반 지급·랠리 지급·금화 전환뿐 아니라 별도 저장 진입점인 `황금 궤적` 벽 반사
  보상도 registry를 전달한다 (`runtime_perk_state.gd:370`). 탑에서는 광장 정산용
  `gold_from_perks`를 늘리지 않고, 비탑에서는 종전 누적 동작을 유지한다.
- 드로 경로는 수정하지 않았다. `get_cached_instance()`만 사용하는 non-instantiating
  peek 계약(GRT-042)을 유지했다 (`runtime_perk_gold_award_flow.gd:259`).

## 회귀 씰

신규 `godot/tests/tower_battle_gold_hud_live_sync_smoke.gd`는
`EXPECTED_LEG_COUNT = 4`로 다음을 고정한다.

1. 탑 일반 전투 금화와 `황금 궤적` 금화가 즉시 `run_state.gold`로 들어가고
   광장 정산용 누적기에 남지 않는다 (`:67`).
2. 필러 HUD 금액과 상점 모달 금액이 같은 런 골드를 표시한다 (`:92`).
3. 금화 지급 전후 무혼 값과 기존 `collect_muhon()` 동작이 보존된다 (`:110`).
4. 비탑 캠페인은 런을 만들지 않고 기존 `runtime_perk_gold` 합산 표시를 유지한다
   (`:126`).

신규 씰은 CI와 pre-push 두 리터럴 목록에 동시에 등재했다
(`.github/workflows/godot-ci.yml:92`, `godot/tools/run_pre_push_checks.ps1:96`).
두 목록은 각각 **194개**로 lockstep이다.

## 검증

- RED counterproof: 구현 전 신규 씰에서 전투 지급 뒤에도 런 골드·필러·상점 값이
  오르지 않고 `gold_from_perks`만 증가함을 확인했다. 표시기보다 적립 경로가 결함임을
  재현했다.
- 신규 씰 단독: `PASS=1 FAIL=0 TOTAL=1`, 종단선
  `All Godot smoke tests passed.`, `SCRIPT ERROR` 0건.
- 관련 회귀 5종: `runtime_perk_gold_award_flow`, `perk_fusion_value_hooks`,
  `ingame_gold_hud`, `tower_battle_muhon_hud`, `tower_ascent_shop_node` 모두 통과.
  `PASS=5 FAIL=0 TOTAL=5`, 종단선 `All Godot smoke tests passed.`,
  `SCRIPT ERROR` 0건. 상점 씰의 `feature_disabled` 경고는 의도한 플래그-OFF 부정 레그다.
- touched-file warning scan: 5개 GDScript, 경고 0건.
- 표준 headless load check: 통과, graceful shutdown 확인.
- `git diff --check`: 통과.
- CI/pre-push 씰 수: `194 / 194`.

추가 탐색에서 `ingame_gold_reward_parity_smoke.gd`의 피드백 기본값 관련 순수 도우미
기대 불일치 5건을 관찰했다. 실패 지점은 본 작업에서 수정하지 않은
`runtime_perk_gold_awards.gd`의 피드백 계약이며, 위 생산 경로 및 scoped gate와
분리했다.

## Vulkan 2020×1246

표준 `-AllowDuringPlay` 래퍼와 Forward Mobile Vulkan/NVIDIA GeForce RTX 5070으로
생산 필러 drawer, 생산 상점 모달, 실제 `RuntimePerkState.award_gold()` 경로를 캡처했다.

- 전투 지급 전: 필러 금화 `0`, 무혼 `17`
- 전투 지급 후: 필러 금화 `120`, 무혼 `17`
- 같은 시점 상점 모달: 금화 `120`, 무혼 `17`
- 자동 픽셀 부정 증거: 금화 숫자 영역은 변화하고 무혼 영역은 유지됨.
- 육안 확인: 세 캡처 모두 위 값과 레이아웃이 명확하며 겹침·잘림 없음.

증거 위치:
`C:\Users\woduq\.codex\backups\tower_battle_gold_hud_live_sync_20260821_105741\vulkan_2020x1246`

- `battle_gold_before_2020x1246.png` —
  `a5585b208c3f9eface0db1007ef160e03cd9f38f54fd0f59aa09cefd0865cefd`
- `battle_gold_after_2020x1246.png` —
  `4b200d25435f4c6f99b0c1122f55943745e215d38a374d73c70f746790f3d8a0`
- `shop_gold_after_2020x1246.png` —
  `6834fc81c52481de6d1ce67418a1edfcf41b59fb8e142edb21251091bbb41fcf`

작업 전 로그도 같은 증거 루트의 `prework_godot.log`로 선행 백업했다.

## 격리 상태와 인계

- worktree:
  `C:\Users\woduq\.codex\tmp\bosspong_tower_gold_sync_20260821`
- branch: `codex/tower-battle-gold-hud-live-sync-20260821`
- base: `a8a5c8d45b1a4f32b79b7c1297d9afc005356496`
- 코드 커밋: `bce399cd3` (`fix(tower): route battle gold into run economy`)
- 씰 커밋: `8bc2db501` (`test(tower): seal live battle gold sync`)
- main worktree WIP는 수정하지 않았다. 통합·푸시하지 않았다.
- 사용자가 본 main 트리의 라이브 플레이 확인은 지시대로 **unverified**다.
- blocked: **0건**.
