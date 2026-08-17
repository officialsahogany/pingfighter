# ROUTE_AIM owner 메타 프로퍼티 게이트 수정 /goal 지시문 (2026-08-18)

- **증상**: 07f3ed2ae 랜딩 후에도 라이브(run_tower_mode.ps1)에서 ROUTE_AIM
  플레이어 이동 불가·서브 발사 불가가 그대로 재현된다.
- **확정 원인 (Claude 사전 진단, 코드 대조 완료)**:
  1. 라이브 owner는 `battle_scene_shell.gd`이고, `player_pos`·`ball_active` 등
     전투 키를 **`_get`/`_set` 메타 메서드**(129·136행, scene_state 위임)로만
     노출한다. `_get_property_list()`는 구현되어 있지 않다.
  2. `tower_ascent_route_serve_runtime.gd`의 owner 접근자는
     `_owner_properties`(= `get_property_list()` 수집)를 게이트로 쓴다.
     메타 노출 키는 property list에 없으므로 **라이브에서 모든 읽기가
     fallback, 모든 쓰기가 무음 no-op**이 된다 (GRT-017 변종).
  3. 그래서 이동 쓰기가 죽고, `ball_active`가 항상 false로 읽혀 서브 직후
     즉시 MISS→재서브 루프가 돈다. 사용자 라이브 로그의
     `physics.serve_ball n=3` + `process.reset_ball n=3`(보이지 않는
     서브/리셋 순환)이 그 증거다.
  4. 스모크는 fixture owner가 **실제 var 선언**이라 property list에 키가
     있어 GREEN이었다. 전형적 GRT-053(스모크 GREEN ≠ 라이브 경로).
- **완료 보고**: `docs/tower_route_serve_owner_meta_fix_report.md`. 푸시 금지.

## 1. 작업 항목 (독립 커밋)

1. **owner 접근자 교정**: `tower_ascent_route_serve_runtime.gd`의
   `_owner_value`/`_owner_vector2`/`_set_owner_value`에서 property-list 게이트를
   제거하고 프로덕션 표준(`BattleSceneOwnerReader` 패턴: bare `owner.get(key)` +
   fallback, 쓰기는 `owner.set(key, value)`)으로 교체한다. 사용 키 전부가
   `BattleSceneState.DEFAULT_VALUES`에 등재되어 있는지 대조한다(GRT-017 —
   미등재 키는 무음 no-op이므로 등재 또는 제거).
   `_collect_property_names` 잔재가 다른 소비자에 남아 있으면 함께 감사한다.
2. **씰 개정 (락스텝)**: 기존 route serve 스모크 fixture owner를 **라이브 셸
   모양(메타 `_get`/`_set`, property list 미노출)** 으로 재현하는 레그를
   추가한다. 구(var 선언) fixture만으로는 이 결함이 GREEN이었음을 RED
   반증으로 남긴다. 가능하면 실제 `battle_scene_shell` 관통 레그를 우선한다.
3. **ROUTE_AIM 플레이어 표시 위치 확인**: 라이브 캡처에서 플레이어 캐릭터가
   플레이필드 상단 중앙(표적 사이)에 렌더되었다. 수정 후 서브 자세가 하단
   패들 위치에서 나오는지 확인하고, 상단 렌더가 별도 결함이면 원인을 보고
   (즉수정 가능하면 독립 커밋).
4. **별건 수정**: `application_quit_coordinator.gd:141` `_stop_audio_players`가
   종료 중 null에 `get_children` 호출로 매 프레임 SCRIPT ERROR 스팸을 낸다
   (사용자 라이브 로그 재현). null 가드 + 종료 경로 씰.

## 2. 규율

- 로그 백업 선행(logs 통째 복사) 후 검증. 표준 래퍼 `-AllowDuringPlay` 계약.
- 검증: route serve 스모크(신규 메타-owner 레그 포함), 타워 회귀 세트,
  `-Paths` 경고, 헤드리스, Vulkan 캡처 1장 이상(ROUTE_AIM에서 이동한
  플레이어 + 비행 중인 서브 공). `run_tower_mode.ps1` 실플레이 재현 가능해야.
- 신규 수치 금지(기존 TEMP_* 유지). 커밋 분리·푸시 금지·판정 불가 시 중단 보고.

**완료 선언 조건**: §1의 4항목 구현·검증 + 게이트 blocked/unverified 0건 +
보고서 완성.
