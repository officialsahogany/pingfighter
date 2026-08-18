# 탑 슬라이스 미활성 회귀 수정 보고서

작성일: 2026-08-18
기준 통합 HEAD: `6376b4e6e8f685629b3489a8a1b89dbb5d7bf846`

## 결론

`41667ab59` 계열에서 재발한 탑 슬라이스 무음 비활성 회귀를 수정했다. 실물
`BattleSceneShell`을 사용하는 회귀 레그에서 같은 런의 첫 번째 승리와 두 번째 승리가
모두 `begin_vertical_slice() == true` 및 `ROUTE_AIM` 진입을 통과한다. 실제
`run_tower_mode.ps1` 세션에서도 첫 승리 뒤 경로 조준 화면이 나타났고, 선택 뒤 2스테이지
전투로 전환됐다.

blocked 0건, unverified 0건이다.

## 원인과 수정

부팅 프리웜은 지도 생성 전에 탑 경제 런을 먼저 시작한다. 기존
`tower_ascent_flow_map_progress.gd`는 `run_started == true`만 보고 이를 재진입으로
판정했고, 아직 `current_node_id`와 저장 그래프가 없는 정상적인 첫 진입을
`reentry_progress_invalid`로 거부했다. 따라서 라이브 `BattleSceneShell`에서는
`begin_vertical_slice()`가 무음으로 `false`를 반환했지만, 자체 상태를 가진
`FakeOwner` 스모크는 통과했다.

수정 내용은 다음과 같다.

- 시작된 런이면서 현재 노드와 저장 그래프가 모두 존재할 때만 재진입 복원을 수행한다.
- 경제 프리웜만 끝난 첫 진입은 기존 런과 경제를 보존한 채 새 지도를 생성한다.
- `begin_vertical_slice()`와 준비 단계의 모든 거부 경로에 `[TowerAscent] ... rejected`
  경고를 추가해 이후 무음 실패를 금지했다.
- GRT-048의 메서드명 문자열 분기를 제거하고 `Callable.get_argument_count()`로 완료
  콜백의 인자 수를 판정한다.
- `tower_ascent_vertical_slice_smoke.gd`의 핵심 레그를 실제 `BattleSceneShell`
  기반으로 바꿨다. 부팅 프리웜 뒤 첫 승리와, 경로 완료 뒤 같은 런의 두 번째 승리를
  각각 검증한다.

수정 커밋: `31bffad8d fix(tower): restore real-shell slice activation`

## RED/GREEN 반증

- RED: 수정 전 실물 셸 레그는 `prepare rejected: reentry_progress_invalid`로 실패했다.
  - 로그: `D:\main\bosspong_tower_reward_pick_41667ab59\godot\.godot\tower_slice_activation_regression_red.log`
  - SHA-256: `B2A3497B3020FEDE8F68355E400802B4E70F5C95A7D1725D0BCDA7C72A875511`
- GREEN: 같은 레그가 수정 후 첫 승리와 두 번째 승리 모두 `ROUTE_AIM`을 단언하며
  통과했다.
  - 로그: `D:\main\bosspong_tower_reward_pick_41667ab59\godot\.godot\tower_slice_activation_regression_green.log`
  - SHA-256: `9202E14D276C8418B6699027F5513635A3811B9D5C0F76D062A52D6549BD8B50`

## 라이브 재현

메인 통합 트리에서 `run_tower_mode.ps1`로 별도 Vulkan 세션을 띄웠다. 사용자 소유
편집기 PID 18096과 게임 PID 38784는 종료하거나 변경하지 않았다. QA 프로세스 PID
22752는 wrapper가 시작 시 `BelowNormal`을 검증했다. 실행 중 한 차례 우선순위가
`AboveNormal`로 변한 것을 발견해 첫 승리 QA 전에 즉시 `BelowNormal`로 복원했고,
이후 유지 여부를 반복 확인한 뒤 해당 QA 프로세스만 정상 종료했다.

- 첫 승리 전 비활성 대표 표본:
  `physics.frame.gate.tower_ascent_flow avg=8.5us max=26us n=144`
- 첫 승리 뒤 활성 대표 표본:
  `avg=388.0us max=692us n=144`, `avg=351.6us max=604us n=144`,
  `avg=364.8us max=726us n=144`
- 전체 로그에서 250us 초과 활성 표본은 124개이며, 최고 평균은 568.8us였다.
- `[TowerAscent] ... rejected` 경고는 0건이었다.
- 경로 조준 화면에는 아라크네와 두더지왕 표적이 함께 표시됐고, 실제 선택 뒤
  스테이지 2로 전환됐다.

증거:

- 로그: `godot/.godot/codex_logs/tower_mode_live_28996_20260818092107596.log`
  (`SHA-256 52870E73152EFEA0A4E6EF6C92D160C2514819665D6D382FC1AB503BCBFBE917`)
- 캡처: `godot/.godot/codex_captures/tower_live/first_victory_route_aim.png`
  (`SHA-256 3698804998475D780D3058015E1427D017C8A0DBA97F4D3491E50793AC696586`)

현재 HEAD의 지도 렌더도 `run_tower_ascent_map_overlay_visual_qa.ps1`로 인간계와
신선계 양쪽을 다시 생성해 각각 `ok`와 wrapper PASS를 확인했다.

- `godot/.godot/codex_captures/tower_map_overlay/map_overlay_human_realm.png`
- `godot/.godot/codex_captures/tower_map_overlay/map_overlay_immortal_realm.png`

## 게이트

- 실물 `BattleSceneShell` 첫 승리/두 번째 승리 회귀 레그: PASS
- 탑 전체 스모크: `PASS=39 FAIL=0 TOTAL=39`
- 변경 GDScript 42개 경고 스캔: 경고 0
- headless load: PASS
- 인간계/신선계 지도 Vulkan QA: PASS / PASS
- 라이브 첫 승리 경로 조준 및 다음 전투 전환: PASS
