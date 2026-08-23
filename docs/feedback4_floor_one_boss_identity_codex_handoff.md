# 지시문 I2 — 1층 보스 정체성 단일화: 스킨/중복/아이콘 (피드백4 1·5·6항)

- **발행**: 관제탑 2026-08-24. 기준 HEAD `bc5890dd1`. CI/pre-push 락스텝 227.
- **격리 워크트리**: `D:\codex_tmp\bosspong_fb4_bossid_bc58` (브랜치
  `codex/fb4-floor1-boss-identity-20260824`). 주 파일 core 셀렉션/전환·
  `battle_resources`·tower_ascent — 지시문 H와 파일 교집합 없음. K와
  `tower_ascent_flow_renderer.gd`를 공유하나 구간이 다름(NODE_ART :110~130·
  :970 vs 게이지 :3880~4260) — 병렬 가능, 통합 충돌은 관제탑 해소.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 원인 (실측 확정 + 교차검증 — 권위 2분열 한 뿌리)

1층 보스 정체성의 권위가 둘로 갈라져 무대조:

- **(A) 실제 첫 전투 보스** = 런/맵 시드와 무관한 `randomize()` 롤
  (전투씬 셀렉션 스타트업). 시드 연동 경로는 `tower_audition` 익스포트
  피처에 게이트되어 일반 빌드에서 죽어 있음
  (`battle_scene_selection_startup_lifecycle.gd:129~143`,
  `tower_audition_build_config.gd:22`). 비오디션 분기는
  `tower_map_seed=0` 강제(`game_selection_state.gd:154`).
- **(B) 지도 장식·아이콘** = 파생 시드로 독립 배정
  (`tower_ascent_flow_map_progress.gd:81` → `_derive_map_seed`;
  게이트 슬롯 배정 `tower_ascent_boss_registry.gd:560`). 노드 아이콘은
  **이미 노드별 해석 구현 완료**(양 드로우 사이트가
  `build_map_icon_presentation` → `resolve_boss_id_for_node` 경유,
  커밋 ac7b8e810/f10de9fb4) — 아이콘은 (B)를 정확히 따른다.
  ⚠kind 하드코딩 달지 테이블(NODE_ART_PATHS/:114·NODE_ART_TEXTURES)은
  드로우 소비자 0의 **잔재**(히트테스트 치수·QA 메타 전용,
  `tower_map_scroll_wiring_contract_smoke.gd:554`가 미사용을 명시 봉인)
  — **아이콘 재구현 금지**.

증상별:
- **⑥ 아이콘 불일치**: 원인은 하드코딩이 아니라 **A≠B** — 게이트 노드
  아이콘은 장식기 슬롯(B)을 보여주는데 실제 오프닝 전투는 (A)의 롤.
- **⑤ 중복 조우**: 조우 키 소비는 지도 장식 시점뿐 — 오프닝 롤(A)은
  키를 소비/대조하지 않고, S8이 1층 전 로스터를 지도에 보장하므로 롤이
  게이트 슬롯과 다르면(~2/3 확률) 같은 보스를 선택 노드에서 또 만남.
- **① 스킨 파손**: 전환 텍스처 리로드 컨텍스트가 `stage1_boss_variant`
  누락(`battle_scene_match_event_driver.gd:533`) →
  `battle_resources.gd:1384`가 'dalji' 폴백 → 달지 시트가 제네릭 키
  (boss_walk/idle/attack_sheet)에 실려 각시탈/포도대장 전투에 달지
  비주얼. 부트 프리웜은 variant 포함이라 첫 전투만 정상(GRT-053 동형).
  전환 프리웜 키도 'smasher:1:dalji:true'로 고정(GRT-020) + 라운드 뎁
  스크립트 프리웜 variant 미전달(:573/:597, GRT-003/042).
  ※필러 초상 스마일리는 비달지 정체성의 **기록된 Step-1 폴백 설계**
  (`stage1_pillar_hud_scene_drawer.gd:818`) — 이번 범위에서 제외.

## 작업 (게이트 슬롯 = 단일 정본, 소비자 전원 노드 파생)

1. **시드 단일화**: `request_tower_start_card_entry`에서 탑 버티컬
   슬라이스 활성 시 실제 `tower_map_seed` 롤(비오디션 seed=0 분기 제거;
   버티컬 슬라이스 플래그는 프로덕션 기본 ON이라 안전하고, 레거시
   캠페인 env-OFF QA 루트(시드0+랜덤 롤)는 불변 유지).
   `resolve_stage1_boss_variant`의 시드 경로 게이트를
   `TowerAuditionBuildConfig.is_enabled()` →
   `TowerAscentFeatureFlags.is_vertical_slice_enabled() && seed!=0`으로.
   오프닝 = `get_seeded_floor_slots(1, seed)[0]` = 장식기 게이트 슬롯.
   ⚠주의: `resolve_stage1_boss_variant`는 slots[0]을 무조건 취하고
   장식기 게이트는 "첫 **미사용** 슬롯"을 취한다 — 현재는 터미널
   스탠딘이 8층 미노타우로스라 우연히 일치할 뿐이므로, **구조 동일성을
   씰로 증명**하고 미래에 1층 키 슬롯이 먼저 소비되면 깨지는 경우를
   4번 방어선이 잡게 하라. 이로써 오프닝==게이트 슬롯==지도 정체성,
   선택 노드 2개=나머지 2보스 → **중복은 구조적으로 불가능**(⑤·⑥).
2. **전환 컨텍스트 패리티**(①): `_reload_battle_textures` 컨텍스트에
   `stage1_boss_variant`(owner 값, `_apply_tower_encounter_identity`가
   이미 정확히 설정) 추가. `get_stage_round_dep_keys` 두 호출부(:573/:597)
   에 variant 전달. 전환 프리웜 키가 1층 variant 간 달라져 실제 스펙
   재순회가 일어나는지 확인(GRT-020).
3. **아이콘 재구현 금지**(교차검증 확정: 이미 구현됨): 선택 정리만 —
   NODE_ART_PATHS/NODE_ART_TEXTURES의 잔재 달지 전투 항목은 히트테스트
   치수·QA 메타 소비자를 확인한 뒤에만 정리하고, 애매하면 그대로 두고
   보고.
4. 방어선: `_complete_map_transition`에서
   `canonical_encounter_key(node.standin) != node.boss_encounter_key`면
   경고. 오프닝 slots[0] vs 게이트 "첫 미사용" 불일치(1층 키 슬롯 선소비
   시나리오)도 같은 경고 범위에 포함. `standin_duplicate_gate`
   의미론(4~8층 셸 전용)은 불변.
5. 진단 레그: 런 시작 시 tower_map_seed·오프닝 variant·게이트 슬롯
   로그 1줄(회귀 시 관측용). 동일 세션 2런째에 스테일 시드 재사용이
   없는지 확인(재롤 → 새 맵 시드).

## 씰

- **중복 음성 레그**(⑤): 고정 시드로 셀렉션→오프닝→1층 선택 조우까지
  실 경로 관통, 1층 실전투 canonical 키 집합(오프닝 포함)에 중복 0 +
  3보스 전원 커버 단언. 오프닝≠게이트 슬롯 강제 픽스처가 RED임을 반증.
- **아이콘 패리티 레그**(⑥): 실제 드로우 경로인
  `build_map_icon_presentation`→`resolve_boss_id_for_node` 기준으로,
  같은 시드에서 게이트 노드 아이콘 보스 id == 오프닝 전투 variant 단언
  + 1층 전투 노드 3개의 아이콘 id 상호 상이(기존 iconography 계약
  스모크 확장). art_path 메타는 드로우 소비자가 아니므로 판정 기준 금지.
- **전환 텍스처 패리티 레그**(①): 실 전환 시퀀스로 달지 게이트→각시탈
  선택 노드 전환 후 제네릭 키(boss_walk_right/idle/attack_sheet)가
  각시탈 경로 해석 + 각시탈 전용 키 존재 단언. 포도대장 형제 레그.
  전환 프리웜 키 variant별 상이 단언.
- **라운드 뎁 커버리지 레그**: variant=gaksi/podo 전환에서 variant 전용
  모듈 키 요청 단언.
- **시드 단일화 레그**: 버티컬 슬라이스 활성 시 tower_map_seed!=0,
  flow 전달, `prepare_vertical_slice_combat`의 _map_seed==셀렉션 시드
  (파생 폴백 미사용) 단언.
- 기존 락스텝 유지: floor_one_expansion_contract·boss_routing·
  map_iconography_contract·boss_registry 스모크 GREEN. 신규 씰 CI·
  pre-push 양 목록 등재(227 → 갱신 수 보고).
- 픽셀 레그: 2번째 1층 조우 vs 각시탈 캡처(비달지 실루엣) + 지도에서
  1층 노드 아이콘 3종 상이 캡처.

## 게이트·보고

포커스드 스모크(+RED 반증 2종) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처 2장. 보고=워크트리·커밋 해시·씰 종단선 원문·
캡처 경로·아이콘 PNG 존재 감사 결과·2런째 시드 판정·미해결.
