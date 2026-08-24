# 지시문 Q3 — 도착 노드 보스 일치 강제 (피드백5 7항)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `475523dec`. CI/pre-push 락스텝 236.
- **격리 워크트리**: `D:\codex_tmp\bosspong_arrival_4755` (브랜치
  `codex/fb5-arrived-boss-identity-20260825`).
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 증상·조사 결과 (관제탑 프로브 실측)

도착한 1층 선택 노드 아이콘=각시탈인데 실전투=포도대장. 정적 분기
(아이콘 vs 슬롯)는 400시드×1200노드 프로브에서 0건 — **런타임 경로의
구조 결함 3중**이 용의자다:

1. **침묵 폴백이 '직전 보스 재전투'를 연다**(유력):
   `battle_scene_match_flow_driver.gd:434` encounter 빈 dict →
   reset_game 콜백, `:444` `begin_tower_boss_transition` false(전환
   로딩 플래그 잔류·owner null 등, event_driver:263) → 경고 1줄 후
   reset — 현재 owner의 stage1_boss_variant(직전 전투)로 재개시.
   각시탈 노드 도착+포도대장전의 유일한 재현 경로.
2. **이중 권위 + 경고-만-하는 가드**: 아이콘=standin 우선
   (`map_iconography:59`), 전투=slot_id 단독 재조회(`ending_progress:
   371~373`). I2의 `_warn_boss_identity_mismatch`는 불일치를 감지해도
   push_warning만 하고 slot 권위로 진행(fail-closed 없음).
3. 보조: 스냅샷 복원이 stale standin을 통째 복원(레지스트리 내용
   버전 게이트 부재), `map_seed==0` 진입 루트 랜덤 롤 잔존, 정규화
   사본 5곳 중 2곳 'talchum' 별칭 누락.

## 작업

1. **침묵 폴백 제거**: `_finish_tower_boss_route`에서 빈 encounter·
   전환 실패 시 직전 변형 재전투를 열지 말 것 — 도착 슬롯 기준
   재구성 재시도, 불가하면 지도 재개방(fail-closed). 최소 불변식:
   "owner.stage1_boss_variant ≠ 도착 노드 정체성" 상태로 전투 개시
   금지.
2. **도착 해석 단일 권위**: `_complete_map_transition`에서
   `resolve_battle_encounter` 결과의 canonical key를 노드
   standin/boss_encounter_key와 대조 — 불일치 시 **플레이어가 본
   아이콘(standin) 정체성으로 교정** 후 진행(교정 불가면 차단).
   아이콘·전투가 같은 매핑 헬퍼를 소비하도록 정리.
3. 스냅샷 복원 직후 전 전투 노드에 `analyze_boss_node_identity`
   재검증 — stale standin을 라이브 `get_standin(slot_id)`으로 재기록.
4. 정규화 사본 5곳을 `StageBossVariantCatalog.VARIANT_ALIASES` 위임
   으로 통일('talchum' 누락 2곳 해소).
5. `map_seed==0` 진입 루트(스타트 카드 미경유)는 이번 스코프에서
   경고 승격만(교정은 별도 판단) — 발생 시 로그 1줄.

## 씰

- **도착 레그(핵심 신설)**: 실 프로덕션 경로 관통 — seeded prepare →
  1층 각 선택 노드 강제 도착 → 실 `begin_tower_boss_transition` →
  `owner.stage1_boss_variant`의 아이콘 id == `resolve_boss_id_for_node`
  (도착 노드) == route_aim 아이콘 표시, 3변형(달지/각시/포도) 전부.
  (기존 씰은 개막=게이트와 합성 encounter 파리티만 — 이 레그가 공백.)
- **RED 반증**: 도착 노드 standin을 형제 보스로 오염한 픽스처 —
  수리 전=경고만 내고 slot 정체성 진행(RED), 수리 후=아이콘 정체성
  교정 or fail-closed 단언.
- **폴백 레그**: `_stage_transition_loading_active` 강제·빈 encounter
  픽스처에서 직전 변형 침묵 재전투 미개시 단언.
- **스냅샷 레그**: standin 스테일 변조 → restore → 도착 시
  icon==battle 재수렴.
- 기존 락스텝: floor_one_boss_identity·boss_routing·vertical_slice·
  iconography 씰 GREEN 유지. 신규 씰 CI/pre-push 양 목록 등재.
- 게이트: 포커스드 스모크 → `-Paths` 경고 → 헤드리스 로드 → diff →
  각시탈 노드 도착→각시탈전 개시 라이브 캡처 1장.

## 보고

워크트리·커밋 해시·씰 종단선 원문·캡처 경로·seed==0 루트 판단 메모·
미해결.
