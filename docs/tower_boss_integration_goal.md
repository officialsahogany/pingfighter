# 보스 4종 통합 /goal 지시문 — 병합 + 대역 교체 (2026-08-17)

- **목적**: 승인 완료된 보스 포팅 브랜치 `codex/tower-unported-boss-port-4164`
  (HEAD `50de6ab0e`, Claude 승인 리뷰 GREEN)를 메인 브랜치에 병합하고, 탑
  2·3층의 대역 4슬롯을 실제 보스 변형으로 교체한다.
- **완료 보고**: `docs/tower_boss_integration_report.md`. 푸시 금지.

## 1. 병합 (커밋 1)

- 사전 백업: 변경·미추적 파일 전수 백업(기존 관례). **어떤 워크트리 WIP도
  잃지 않는다.**
- 실측 참고 (수리 착지 전 기준이므로 **재측정 필수**):
  - 양측 변경 충돌 후보 6파일: `battle_draw_playfield_scene_context.gd`,
    `battle_scene_drawer.gd`, `battle_scene_state.gd`,
    `battle_update_player_control_deps_builder.gd`,
    `match_score_event_controller.gd`, `battle_effects_update_controller.gd`
  - 워크트리 더티 겹침 3파일: `docs/godot_module_ownership_ledger.md`,
    `battle_draw_actor_context.gd`, `gameplay_stage_module_catalog.gd`
- 절차는 확립된 격리 방식을 쓴다: 깨끗한 격리 워크트리에서 병합 커밋
  (부모 = 메인 HEAD + `50de6ab0e`)을 만들고 거기서 검증한 뒤 메인에 채택한다.
  더티 겹침 파일은 exact-blob/헝크 기법으로 사용자 WIP를 보존하며 반영한다.
- 충돌 해소 원칙: 양쪽 의도를 모두 보존(스냅샷의 퍽·타워 훅 + 보스 변형 훅).
  판단 불가 충돌이 나오면 중단·보고.
- 병합 후 게이트: 보스 4종 포커스 스모크 + `stage2_router_smoke`(⚠ Claude
  재실행에서 보스 워크트리의 에셋 미물질화로 RED였던 항목 — 메인에서 GREEN
  재확인 필수) + Stage 3 회귀 3종 + 타워 23종 + exact 124종 + 변경 파일 경고
  + 헤드리스 + diff check.

## 2. 대역 교체 (커밋 2)

- 탑 레지스트리의 4슬롯 stand-in을 실변형으로 교체한다 (포팅 보고서 §5 인계):
  - `floor_02_molewang` → 변형 `molewang`
  - `floor_02_arachne` → 변형 `arachne`
  - `floor_03_teddy_bear` → 변형 `teddy_bear`
  - `floor_03_alice` → 변형 `alice`
- 슬롯 id·스냅샷 호환성 보존 (기존 런 스냅샷의 슬롯 참조가 깨지지 않아야
  한다 — 교체는 대역 매핑 값만).
- **씰 락스텝 갱신**: `tower_ascent_boss_registry_smoke`의 "모든 비이식 슬롯
  stand-in" 단언은 이 4슬롯의 ported 전환을 반영해 개정하고, 구 기대 주입
  RED 반증을 남긴다.
- 교체 후 게이트: 보스 레지스트리·12층 지도·보스 회피·광폭화 마킹 스모크 +
  탑 플래그 ON에서 2·3층 전투 진입이 신규 변형으로 라우팅됨을 단언하는
  레그(또는 기존 스모크 확장) + Vulkan 캡처 1장(탑 경로에서 신규 보스 1종
  실전투 진입 장면).

## 3. 규율

- 커밋 2개 분리(병합/교체), 한국어 커밋 제목. 신규 `.gd`는 `.gd.uid` 동반.
- 발명 금지: 보스 킷·수치 변경 없음. 통합·교체·씰 락스텝만.
- 플레이 중 검증 신정책 준수, 검증 전 로그 백업, baseline RED(홀로그램 디스크
  WIP 등)는 분리 보고.
- 판정 불가 충돌·신규 RED 발생 시 완료 처리하지 말고 중단·보고.

**완료 선언 조건**: 병합·교체 커밋 착지 + §1·§2 게이트 전부 GREEN(등록된
baseline 제외 blocked/unverified 0건) + 보고서 완성. 이후 Claude(Fable)가
검증한다.
