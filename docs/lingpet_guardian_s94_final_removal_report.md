# 수호령 §9-4 최종 삭제 실행 보고

작성: 2026-07-29
실행 기준: `docs/lingpet_guardian_s94_final_removal_handoff.md` (`0c49fedcf`)

## 1. 커밋별 결과

| 순서 | 커밋 | 결과 |
|---|---|---|
| ① | `adc0fe507` | 부화 개성 롤을 `lingpet_hatch_stat_roll_state` 단독 owner로 이전. 1회성, 신규 저장 왕복, 구 per-pet 키 흡수를 같은 커밋에 봉인했다. |
| ② | `d889309a6` | E/RT 교감 상수·래치·라우터 처리·컨트롤러 재노출·런타임 래퍼를 제거했다. |
| ③ | `4d81e3505` | 포만도/피딩 코드·정의·번역·일반 아이콘을 제거하고 지속시간 owner/표면으로 전환했다. |
| ④ | `f65a85578` | 하트 공명 결정 게이트 권고안을 적용해 수집 정체성은 남기고 성장/최종 보상 의미를 제거했다. |
| ⑤ | 이 보고서를 포함하는 최종 커밋 | 구 owner/씰 명칭과 meta-only store를 제거하고, 저장 채널·대조군 씰·잔존 스윕을 봉인한다. |

푸시와 PR 생성은 하지 않았다.

## 2. §0 전수 조사와 dirty 경계

### 삭제·이전 대상 및 소비자

- 부화 롤: `lingpet_hatch_stat_roll_state`, guardian run owner, current profile,
  loadout/context coordinator, egg runtime save/export/import, hatch randomization 씰.
- E/RT: `battle_lingpet_interaction_input_router`,
  `battle_scene_input_controller`, egg runtime의 구 반응 래퍼, router/egg 씰.
- 포만도·피딩: duration state/runtime, egg runtime, companion draw/motion/reset,
  TAB presenter/projection, active-item catalog, plaza stock/pricing/gacha,
  7언어 exact text, 피딩 코드·아이콘·씰.
- 영구 표면: language exact text, 영구 보유 수호령 목록, TAB/수집 표시,
  `lingpet_permanent_collection_surface_smoke`.
- 최종 owner 명칭: 구 affinity state/context/hit-tag/feedback owner와 그 preload
  소비자, save snapshot builder/applier, 강화·지속시간·프로필 씰.

### 외래 dirty와 분리

- `battle_scene_input_controller.gd`: 외래 라우터 분해 WIP와 겹쳤으나 E/RT
  삭제 헝크만 ②에 포함했다.
- `active_item_catalog.gd`: 외래 `strange_vial` 델타를 남기고 피딩 정의 제거
  헝크만 ③에 포함했다.
- `language_settings_data.gd`: 외래 다국어 WIP를 남기고 포만도·피딩 및 영구
  보상 문구 삭제만 분리했다.
- `localization_coverage_smoke.gd`, `language_settings_smoke.gd`,
  `character_info_overlay_support.gd`: 외래 리브랜드/난이도/아이템 델타는
  스테이지하지 않고 수호령 최종 삭제 헝크만 분리한다.
- `lingpet_bomb_surprise_skill.gd`, `lingpet_collection_state.gd`,
  untracked `guardian_spirit_rebrand_smoke.gd`,
  `game_audio_lingpet_combat_audio_owner_smoke.gd`는 불가침으로 남겼다.

## 3. 구현 결과

### 저장·owner

- 새 스냅샷은 `guardian_run_state`만 쓴다.
- 구 `affinity_run_state`는 `lingpet_save_restore_applier`의 read-only
  관용 파서와 그 회귀 씰에서만 허용한다. 구 키로 읽은 다음 새 저장에 다시
  쓰지 않음을 검증했다.
- 재사용된 런 owner는 `lingpet_guardian_run_state.gd`, context는
  `lingpet_guardian_run_context_coordinator.gd`, 방어 태그는
  `lingpet_guard_hit_tag_resolver.gd`, 가드 라벨은
  `lingpet_guard_feedback_state.gd`로 정리했다.
- 소비자가 없던 `lingpet_affinity_store.gd`와 실행 불가능한 구
  ring-core/chip retirement 씰은 삭제했다.
- 조사 중 `lingpet_hatch_stat_roll_state`가
  `get_guardian_motion_style()`을 호출하면서
  `get_affinity_motion_style` 존재 여부를 검사하던 계약 불일치를 발견했다.
  순찰형 방어 헤드스타트가 항상 0이 될 수 있는 실결함이므로 새 메서드명으로
  통일하고 source-contract 씰을 추가했다.

### 피딩·지속시간

- `lingpet_satiety_runtime_state`, feed controller/bowl, 포만도/탈진 표면,
  피딩 4종 획득 정의와 일반 피딩 아이콘 3종을 제거했다.
- `lingpet_light_eater`는 삭제하지 않았다. 표시명은
  `오래 머무는 숨결`, 설명은 지속시간 소모 감소 어휘이며 기존 수치는
  라이브 튜닝 미결로 유지했다.
- `lingpet_special_feed_icon.png`과 import는 심령수 공식 placeholder라
  보존했다. 현재 소비자는 active-item catalog의 심령수 경로 1곳이다.

## 4. 하트 공명 결정 게이트

권고안 적용 상태이며 사용자 최종 승인을 기다린다.

| 분류 | 처리 표면 |
|---|---|
| 유지 | 영구 보유 수호령 ID/목록, 수집·정체성용 `하트 공명` 다국어 어휘 |
| 제거 | 교감 포인트/레벨/요구치/다음 보상, 레벨업 플래시·수입 로그·보상 트리거, `최대 강화 완료` terminal copy |
| 변경 | 하트 공명은 성장 단계나 보상 완료 상태가 아니라 코스메틱 수집 정체성 어휘로만 해석 |
| 신규 저장 없음 | 현행 v5에 하트 공명 title ownership flag/소비자가 없음을 확인했다. 존재하지 않던 영구 플래그를 새로 발명하지 않았다. |

## 5. 대조군 씰과 반증

세 씰 모두 실제 `BattleSceneInputController.handle_unhandled_input()`에서
production 모듈 getter → 실제 수호령 입력 라우터 체인을 관통한다.

1. `battle_lingpet_priority_cutin_preservation_smoke.gd`
   - GREEN: hatch-break swallow, acquire overlay 1회 전달, terminal보다 우선.
   - 반증: 컨트롤러의 priority-cutin 위임 조건을 in-place로 끊자 위 세
     단언이 RED. 원복 후 GREEN.
2. `battle_lingpet_click_reaction_preservation_smoke.gd`
   - GREEN: 화면 좌표→playfield 좌표 변환, 클릭 리액션 1회, redraw 1회.
   - 반증: 라우터의 클릭 승인 분기를 in-place로 끊자 리액션/좌표와 redraw
     단언이 RED. 원복 후 GREEN.
3. `battle_lingpet_slot_cycle_preservation_smoke.gd`
   - GREEN: 실 `L` 이벤트는 +1, `Shift+L`은 -1.
   - 반증: 라우터의 cycle 승인 분기를 in-place로 끊자 `[1, -1]` 단언이
     RED. 원복 후 GREEN.

임시 토글·패치 파일은 남기지 않았고 세 씰은 최종 원복 상태에서 다시 GREEN이다.

## 6. 잔존 스윕

| 스윕 | 결과 |
|---|---|
| 구 affinity owner/store/context/hit/feedback 파일명·클래스 preload | live 0건 |
| satiety/포만도/탈진/feed controller/feed bowl/feed action | live production 0건 |
| E/RT `LINGPET_INTERACT`·구 runtime handoff·다국어 조작 힌트 | live production 0건 |
| affinity point/level/grant/battle lifecycle 성장 API | live production 0건 |
| ring-core/chip live 소비자 | 0건 |
| 구 다국어 포만도·피딩·교감 레벨·다음 보상 문구 | production localization 0건 |

허용된 비-live 일치:

- guardian run sanitizer의 `bond_points`, `bond_title`, `ring_core_cap`,
  `affinity_points`, `affinity_level`: 구 run payload를 읽고 폐기하기 위한
  read-only 키이며 새 export에는 쓰이지 않는다.
- `affinity_run_state`: 구 세이브 read-only 키 1종과 그 반증 씰.
- `lingpet_special_feed_icon.png`: 심령수 placeholder 예외.
- `perk_fusion_cold_boot_timeline_state.gd`의 “링코어 콜드부트”: 수호령
  링코어 시스템이 아닌 별도 퍽 융합 연출의 고유명.
- untracked `game_audio_lingpet_combat_audio_owner_smoke.gd`의 구 affinity
  차임 단언과 `guardian_spirit_rebrand_smoke.gd`는 외래 WIP라 수정하지 않았다.

## 7. 검증

- 수호령 owner/지속시간/강화/부화/프로필/스냅샷/심령수 및 입력 대조군
  focused smokes 25종: 최종 실행 전부 GREEN. TAB duration 씰의 기존
  ObjectDB leak 경고는 비차단으로 남았다.
- `localization_coverage_smoke`: 기존 외래 다국어 백로그 RED 유지
  (신화 아이템 무공/초식, 격령사, 현재 수호령 강화 라벨/스킬명 번역).
  삭제된 포만도·피딩·교감 레벨 표면은 더 이상 실패 목록에 없다.
- `lingpet_main_egg_overflow_smoke`: 반복 실행 중 GREEN/RED가 교차하는 기존
  부화 타이밍 플레이크를 관찰했다. 이번 owner 필드 제거와 상관없이 재현됐고
  본 슬라이스 production 변경의 결정론적 회귀 증거로 보지 않는다.
- headless load: graceful shutdown marker 포함 GREEN.
- GDScript warning scan: 전체 3,209개 중 0..2,250 구간에서 불가침 untracked
  `guardian_spirit_rebrand_smoke.gd`가 이미 은퇴한 affinity-chip 상수 2개를
  읽어 parse RED. 동일 실행은 그 파일 뒤까지 스캔했고, 별도 2,250..3,209
  tail scan은 GREEN이었다. 이번 touched production/씰의 신규 경고는 없으며
  전역 GREEN은 해당 외래 rebrand 씰 정산 후 가능하다.

## 8. 보류 연동

- focused/CI 등재와 ownership ledger
- 광장 골드+AP 대체 싱크
- 심령수 정식 아이콘 랜딩 후 `lingpet_special_feed_icon.png` 정리
- 소식가 수치, 드레인/회복, 심령수 드랍률, 강화 수치 라이브 튜닝
- 외래 다국어 백로그와 untracked audio/rebrand 씰 정산
