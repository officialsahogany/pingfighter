# 승천탑 보스 4종 통합 보고서

- 지시문: `docs/tower_boss_integration_goal.md` (`a0e9a056d`)
- 포팅 원본: `codex/tower-unported-boss-port-4164` (`50de6ab0e`)
- 메인 기준: `a0e9a056d167eabb8bc4729104d20f9e35177cae`
- 푸시: 하지 않음
- 판정: **완료 — 병합·대역 교체·필수 게이트 GREEN**

## 1. 커밋과 격리 채택

| 구분 | 커밋 | 상태 | 내용 |
|---|---|---|---|
| 병합 | `1c358c84b71bdcfc390662b65dde0e05c37176f6` | fixed | 포팅 HEAD를 두 번째 부모로 가진 실제 병합 커밋. 보스 4종의 상태·렌더·선택 경로·검증 도구를 통합했다. |
| 대역 교체 | 이 보고서를 포함한 `교체(탑): 2·3층 보스 4종 실변형 연결` 커밋 | fixed | 기존 슬롯 ID를 보존한 채 네 슬롯의 상태·stage·호환 boss ID·variant만 교체하고 씰과 실전투 Vulkan QA를 락스텝 갱신했다. |

병합 커밋의 부모는 순서대로 메인 기준 `a0e9a056d...`와 포팅 HEAD
`50de6ab0e...`이며, 병합 tree는 `1761e44735fb057ac63d87f0b149d0c338de97bd`다.

최초 후보 `19587b288...` / `47ce3845a...`는
`battle_update_player_control_deps_builder.gd` 충돌 해소 중 메인에서 이미 제거된
Mokrin D15 상태 브리지를 공통 조상에서 되살린 잘못된 후보였다. 실제 메인에서
`lingpet_baekrin_static_activation_smoke`와
`lingpet_mokrin_transform_registration_smoke`가 이를 신규 RED로 검출했다. 두 후보는
채택 대상에서 폐기했고, 메인의 D15 삭제와 포팅 브랜치의 dash-lock 입력 proxy를
함께 보존한 새 병합 커밋으로 재작성했다.

원본 워크트리는 수정·미추적 5,054항목을 먼저
`D:\codex_tmp\tower_boss_integration_backup_20260817_201542`에 전수 보존했다.

- 복사·해시 검증: 5,036파일, 11,841,248,997바이트
- 삭제 상태 별도 기록: 18항목
- 상태 SHA-256: `6151089156BF89D9E7355DED9E6C95587336F80AA72A6A5BE1144BD836FF0E3B`
- 백업 매니페스트 SHA-256: `29622E05D077383C62EDD893A9ADBDA3B225F587F9B7EF367B819313B1A3BE0A`

병합은 `D:\codex_tmp\tower_boss_integration_merge_20260817` 격리 워크트리에서
수행했다. 실제 텍스트 충돌은 아래 2파일뿐이었다.

- `battle_scene_drawer.gd`: 승리 강조 기둥 추적과 신규 보스 actor context를 모두 보존했다.
- `battle_update_player_control_deps_builder.gd`: 기존 퍽·수호령 skill-lock 체인과
  테디베어·엘리스의 dash-lock proxy를 보존하되, 메인에서 제거된 Mokrin D15 상태
  브리지는 되살리지 않았다.

사전 예측 6파일 중 나머지는 Git이 자동 병합했고, 더티 겹침 3파일은 격리
커밋에서 검증한 뒤 메인 채택 시 기존 WIP 위에 변경분만 합성하도록 분리했다.

## 2. 대역 교체 계약

| 보존 슬롯 ID | status | stage | 호환 boss ID | 실제 variant |
|---|---|---:|---|---|
| `floor_02_molewang` | `ported` | 2 | `cheongringwi` | `molewang` |
| `floor_02_arachne` | `ported` | 2 | `cheongringwi` | `arachne` |
| `floor_03_teddy_bear` | `ported` | 3 | `yeonmyo` | `teddy_bear` |
| `floor_03_alice` | `ported` | 3 | `yeonmyo` | `alice` |

슬롯 ID와 지도·스냅샷의 참조 키는 변경하지 않았다. `boss_id`는 기존 Stage
2/3 호환 오너를 유지하고, `variant`만 포팅 카탈로그의 실제 보스 구현을 고른다.
보스 킷·확률·수치·지도 RNG는 수정하지 않았다.

`tower_ascent_boss_registry_smoke`는 네 슬롯을 `ported`로 단언하고, 플래그 ON에서
각 레지스트리 route를 `GameSelectionState.set_stage()`와
`BattleSceneSelectionStartupLifecycle`까지 통과시켜 실제 stage/variant 소비를
검증한다. 검증 프로젝트에 구 기대인 `floor_02_molewang == unported`를 임시
주입했을 때 `PASS=0 FAIL=1 TOTAL=1`과
`old expectation: Molewang must still be unported` RED가 발생했고, 최종 씰 복원
후 GREEN을 재확인했다.

## 3. 병합 게이트

격리 병합 tree와 실제 자산을 물질화한 검증 프로젝트에서 다음을 확인했다.

- 보스 포팅 4종: `stage2_molewang_boss_port_smoke`,
  `stage2_arachne_boss_port_smoke`, `stage3_teddy_bear_boss_port_smoke`,
  `stage3_alice_boss_port_smoke` 전부 GREEN.
- Stage 3 회귀 3종: `stage3_psychoball_parity_smoke`,
  `stage3_curse_control_reverse_smoke`, `stage3_map_port_smoke` 전부 GREEN.
- 충돌 집중 회귀: `player_control_deps_builder_smoke`,
  `victory_highlight_replay_smoke` GREEN.
- 추가 더티-WIP 합성 회귀: `lingpet_baekrin_static_activation_smoke`,
  `lingpet_mokrin_transform_registration_smoke` GREEN.
- 타워 전체: `PASS=23 FAIL=0 TOTAL=23`, `All Godot smoke tests passed.`
- 퍽 클러스터 exact 목록: 목록 124개, 목록 SHA-256
  `112D03546EAAC6A06491C7841AFE4CFEAD5CB019FB6BC955585F372771D50A8B`,
  `PASS=124 FAIL=0 TOTAL=124`, `All Godot smoke tests passed.`
- 병합 변경 GDScript 경고: `31/31`, 경고 0건.
- 헤드리스: `Godot headless load check passed.`
- 병합 diff check: PASS.

`stage2_router_smoke`는 깨끗한 격리 tree에 현재 메인의 미착지 Stage 2 상태 모듈
WIP가 없어 최초 실행이 유효하지 않았다. 같은 테스트를 원본 WIP에서 실행하자
7점제 전환 뒤 남은 GRT-054 픽스처 리터럴(광폭화 4점, 신화 고압 5점)이 RED를
재현했다. 이 테스트 WIP만 정본 상수
`Stage2BossRageCoordinator.CRISIS_PLAYER_SCORE`와
`Stage2BossSkillState.HIGH_PRESSURE_PLAYER_SCORE`에서 파생하도록 교정한 뒤
`stage2_router_smoke: ok`, `PASS=1 FAIL=0 TOTAL=1`을 확인했다. 이 선재 WIP
교정은 두 통합 커밋에 싣지 않고 원본 워크트리에 그대로 보존했다.

## 4. 교체 후 최종 게이트

현재 메인 WIP에서 정정된 병합·교체 파일을 직접 실행해 최종 검증했다. 실행 중 게임과
원본 `.godot` 캐시는 건드리지 않았다.

- 정정 집중 회귀 6종: Baekrin 정적 활성화, Mokrin 변신 등록, player-control deps,
  Stage 3 저주 역전, 엘리스·테디베어 포팅이 `PASS=6 FAIL=0 TOTAL=6`.
- 최종 충돌·보스 집중 회귀 12종: 보스 포팅 4종, Stage 2 라우터, Stage 3
  psychoball·저주·지도, player-control, 승리 강조, Baekrin·Mokrin이
  `PASS=12 FAIL=0 TOTAL=12`, `All Godot smoke tests passed.`
- 타워 전체: `PASS=23 FAIL=0 TOTAL=23`, `All Godot smoke tests passed.`
- 퍽 클러스터 exact 124종: `PASS=124 FAIL=0 TOTAL=124`,
  `All Godot smoke tests passed.`
- 정정 파일 단독 경고: `1/1`, 경고 0건.
- 최종 변경 GDScript 경고: `34/34`, 경고 0건.
- 헤드리스: `[ApplicationQuitCoordinator] graceful headless shutdown complete`,
  `Godot headless load check passed.`
- 최종 diff check: PASS.

Vulkan 실전투 게이트는 신규
`run_tower_ascent_boss_entry_visual_qa.ps1`로 실행했다. 래퍼는 플레이 중
`-AllowDuringPlay`, BelowNormal, 고유 로그, `finally` 우선순위 복구 계약을
따른다. `floor_02_molewang`을 탑 레지스트리에서 읽어 플래그 ON으로 실제
`GameSelectionState`에 넣고 `main.tscn`을 부팅한 결과:

- GPU/API: NVIDIA GeForce RTX 5070, Vulkan 1.4.325, Forward Mobile
- route: `flag=ON slot=floor_02_molewang stage=2 variant=molewang`
- 종단선: `tower_ascent_boss_entry_visual_qa: ok`
- 캡처: `.godot/codex_captures/tower_boss_integration/floor_02_molewang_battle_entry.png`
- 크기: `3840x2160`
- SHA-256: `6A8C7CE380ADB40BA94CA49872AF01C7859F9410964BA88BBDACBA91182A546C`
- 육안 판정: 실제 전투 프레임·점수판·Stage 2 배경·플레이어·두더지왕 variant
  상단 actor와 전용 스킬 HUD가 함께 렌더되어 GREEN.

## 5. RED·baseline 분리와 최종 상태

- 최초 실전투 캡처 프로젝트는 깨끗한 병합 스크립트에 현 메인의 미착지 대형
  WIP 의존 파일이 빠져 홀로그램 디스크 상수와 Stage 2 상태 접근자 파스 RED가
  발생했다. 후보 코드 결함이 아니라 불완전 물질화였으며, 현재 메인을 다시
  물질화하고 같은 통합 파일을 덮은 뒤 동일 래퍼 GREEN으로 반증했다.
- 최종 Vulkan 출력의 `Unknown gameplay module key: stage8_minotaur_actor_renderer`
  경고는 현재 메인 WIP의 등록 baseline이며 serious-error 분류 0건, 캡처·route
  종단선·exit 0을 훼손하지 않았다. 본 통합 경계에서는 수정하지 않았다.
- fixed: 잘못된 최초 충돌 후보 폐기, 보스 4종 정정 병합, 4슬롯 실변형 교체,
  슬롯·스냅샷 호환 보존, 씰·실전투 QA.
- deferred: 위 등록 baseline과 원본의 GRT-054 Stage 2 테스트 WIP 귀속만 유지.
- blocked: 0건.
- unverified: 0건.

필수 게이트에 신규·악화 RED가 없고 두 로컬 커밋만 남겼다. 푸시는 하지 않았다.
