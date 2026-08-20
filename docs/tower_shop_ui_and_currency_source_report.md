# 상점 UI와 재화 출처 수행 보고

- 요청 기준 HEAD: `e279f258abcecd4e066c2f02a972899667b6418b`
- 격리 워크트리: `C:\Users\woduq\.codex\tmp\bosspong_tower_start_card_amend2_0c60`
- 작업 브랜치: `codex/tower-training-node-card-ui-40375`
- 상태: **수련장 6카드 리베이스 및 상점 S2~S5 완료**
- 본 트리 통합: 하지 않음
- 원격 푸시: 하지 않음
- blocked: 0건

## 선행 리베이스

수련장 6카드 시리즈를 요청 기준 `e279f258a` 위로 리베이스했다. 이번 리베이스는 충돌 없이 끝났고, 새 기준의 시작 카드 타임아웃과 물리 게이트 씰을 그대로 보존했다.

리베이스된 수련장 커밋:

- `e95f20c4f` `docs(tower): report training card S1 maximum blocker`
- `ceecc5e1b` `feat(tower): render training nodes as card grid`
- `fb925213a` `feat(tower): allow repeat training investments`
- `5ff60346b` `test(tower): seal training card UI evidence`
- `c70986530` `docs(tower): decide run-owned shop currency source`

`tower_start_card_smoke.gd`의 `_leg_count` 단언은 12이고 실제 증가문도 12개다. `battle_scene_frame_controller.gd`, `battle_physics_gate_coordinator.gd` 및 물리 게이트 경로는 변경하지 않았다.

보고 시점 본 트리 HEAD는 요청 기준 위의 문서 커밋 `993d505bd`로 전진했지만, 이 브랜치는 사용자가 지정한 `e279f258a`를 merge-base로 유지한다. 추가 리베이스나 통합은 하지 않았다.

## S1 확정 반영

사용자 확정대로 **탑 런은 자기 경제만 쓴다**. 내부 호환 ID `gold`, 상점 결제 경로, `TowerAscentRunState`, `PlazaSaveStore`는 바꾸지 않았다.

## S2 상점 카드 그리드

상점·수련장·파계승을 `tower_ascent_node_modal_state.gd:13`의 동일한 6카드 노드군으로 묶었다. 세 화면은 모두 `tower_ascent_flow_renderer.gd:1674-1681`에서 `runtime_perk_overlay_renderer.gd:629`의 `draw_tower_node_card()`를 호출한다. 상점 전용 카드 드로어는 만들지 않았다.

- 일반 진열 3장과 고급 진열 1장은 실제 액티브 아이템 아이콘·이름·설명을 사용한다.
- 액티브 캡슐과 기회의 보석도 고정 재고 선택이므로 같은 3x2 카드에 두되, 무공 아이콘을 빌리지 않고 공급품 전용 벡터 심볼과 설명을 사용한다.
- 카드에 가격과 재화 종류를 표시하고, 잔액 부족 사유도 카드 안에서 읽힌다.
- GRT-022: `tower_node_modal_pointer_smoke.gd:275-315`가 shop/training/fallen_monk의 6개 카드 rect와 히트테스트 rect를 대조하고 카드 상단 모서리를 실제 선택한다.
- GRT-021: 같은 씰 `334-339`가 최장 문구에서 실제 append된 설명 행이 정확히 3개이며 마지막 행에 말줄임 근거가 남는지 단언한다.

커밋: `93f9a0650 feat(tower): render shop stock with shared card grid`

## S3 재화 표시 정합

`stage1_pillar_hud_scene_drawer.gd:588-618`에서 금화와 무혼이 같은 `_get_tower_run_economy()` 경계를 사용한다.

- 활성 탑 런: 필러 금화와 상점 모달 모두 캐시된 `tower_ascent_flow_owner`의 런 스냅샷을 읽는다.
- 일반 경로: 탑 런 ID가 없으면 기존 광장 골드 + 일반 런타임 골드 합산을 유지한다.
- GRT-042: `stage1_pillar_hud_scene_drawer.gd:608-618`은 `_get_cached_module()`만 사용한다. 드로우 중 오너를 콜드 생성하지 않는다.
- 정방향 씰: `tower_battle_muhon_hud_smoke.gd`가 한 fixture에서 필러와 모달의 금화 4를 함께 단언하고, 런 골드 갱신도 함께 따라가는지 확인한다.
- 부정 레그: `ingame_gold_hud_smoke.gd`가 비활성 탑 오너에 가짜 런 골드 9999를 넣고도 기존 광장 200 + 런타임 25 = 225가 유지되는지 확인한다.
- 두 재화 씰 모두 콜드 lookup 호출 수 0을 단언한다.

커밋: `1ea5bb68c fix(tower): align pillar gold with run economy`

## S4 비전투 아레나 내부

### 기존 플레이필드 소유자 판정

- `battle_scene_drawer.gd:44`가 비전투 노드 배경을 먼저 그리고, `:50`이 그 위에 공통 전투 플레이필드를 다시 그렸다.
- `battle_playfield_scene_drawer.gd:104`가 현재 스테이지 액터군을, `:143`이 공을, `:168-170`이 스테이지 오버레이·조명을, `:263`이 탑 흐름을 그린다.
- `battle_playfield_effects_drawer.gd:19-42`가 현재 스테이지의 `actor_renderer`를 선택해 호출한다.
- 예를 들어 Stage 4 액터 소유자는 `stage4_actor_renderer.gd:97` 아레나, `:103` 플레이어, `:109` 보스, `:115` 보스 상태 오버레이를 한 패스에서 그린다.

### 적용 범위

보스만 숨기면 이전 스테이지 아레나·플레이어·공·조명이 남는다. 따라서 **비전투 배경이 실제 렌더 가능한 경우에는 공통 전투 플레이필드 조합 전체를 숨기고, 탑 경로 선택기만 남기는 범위**로 정했다.

- `tower_ascent_flow_state.gd:301-312`가 준비 완료된 bitmap/procedural 배경만 렌더 가능하다고 판정한다. fallback이면 전투 플레이필드를 유지한다.
- `battle_scene_drawer.gd:148-176`이 그 판정으로 전투 플레이필드를 차단하고, `:179-190`의 탑 경로 전용 드로우만 호출한다.
- 기존 전투 선택 해제 경로 `tower_ascent_flow_map_progress.gd:466`을 그대로 재사용한다. 전투 노드로 이동하면 retained 배경이 transition 첫 프레임 전에 사라지고 원래 플레이필드가 복귀한다.
- `tower_noncombat_node_background_retention_smoke.gd`는 fallback 정방향, 비전투 차단, ROUTE_AIM 유지, 콜드 lookup 0, 전투 복귀를 함께 단언한다.

커밋: `23d581cef fix(tower): hide stale battle arena in noncombat nodes`

## S5 씰과 캡처

커밋: `702213911 test(tower): seal shop currency and arena visuals`

두 리터럴 목록에 `ingame_gold_hud_smoke.gd`와 `tower_ascent_shop_node_smoke.gd`를 함께 등재했다. 비교 결과는 `CI_COUNT=188 PRE_COUNT=188 DIFF=0`이다.

최종 검증 결과:

- 집중 스모크 10개: `Smoke summary: PASS=10 FAIL=0 TOTAL=10`
- 배치 종단: `All Godot smoke tests passed.`
- 변경 GDScript 20개 경고 검사: `Godot warning scan passed with no GDScript warnings.`
- 헤드리스 로드: `Godot headless load check passed.`
- `git diff --check e279f258a..HEAD`: GREEN
- 시작 카드 씰: `_leg_count=12`, 실제 증가 12회, `tower_start_card_smoke: ok`
- 물리 게이트 관련 변경 경로: 0개
- Vulkan 2020x1246 캡처: `captures=12`, `live_runs=1`, `ok`

주요 캡처:

- `shop.png`: 같은 공용 드로어의 3x2 상점 카드
- `shop_currency_alignment.png`: 한 프레임에서 필러 금화 120·무혼 8과 모달 금화 120·무혼 8
- `noncombat_arena_clean.png`: 비전투 배경에서 전투 플레이필드 sentinel 미호출
- `combat_arena_restored.png`: 전투 복귀에서 전투 플레이필드 sentinel 호출

아레나 두 캡처는 실제 `BattleSceneDrawer` 조합 경계를 통과하는 격리 fixture이며, 전투 복귀 화면은 특정 본 트리 스테이지 보스 대신 sentinel로 경계를 판정한다.

## 증거 보관

- 경로: `C:\Users\woduq\.codex\backups\tower_shop_s2_s5_20260820_083345`
- 파일: 16개, 22,068,659바이트
- 구성: 집중 스모크·경고·헤드리스·Vulkan transcript 4개, 2020x1246 PNG 12개
- 상대 경로와 개별 SHA-256을 정렬한 집계 SHA-256: `94C671328D41A7D88E6C825894D967A72A828B9CE2772ABCC13C24569D49247C`

## 판정 상태와 대기

- **verified**: S2~S5 구조 씰, 격리 런타임 씰, 격리 Vulkan 12장, 리터럴 목록 lockstep, 시작 카드 회귀, 경고·로드·diff 검사.
- **unverified**: 본 트리의 실제 진행 중 탑 런에서 이전 스테이지 보스가 사라지고 실제 필러·모달 픽셀이 일치하는지에 대한 사용자 라이브 판정. 사용자가 본 트리에서 확인한다.
- **blocked**: 없음.

본 트리에 통합하지 않았고 푸시하지 않았다. 이 보고 커밋 후 대기한다.
