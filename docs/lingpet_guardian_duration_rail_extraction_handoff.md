# §9-2 레일 추출 구현 핸드오프 (Codex 실행용)

작성 2026-07-28. 수호령 지속시간 대개편의 **§9-2 (레일 추출)** 구현 지시서.
기획 정본 = `docs/lingpet_guardian_duration_redesign_plan.md` (§5·§8·§9 필독),
정산표 = `docs/lingpet_guardian_wip_settlement.md`. 이 문서 전체를 Codex에
붙여넣으면 자기완결로 착수 가능하다.

## 0. 범위 계약 (초과 금지)

§9-2는 **동작 보존 추출**이다. 아래 두 레일을 새 owner 모듈로 추출·리네임하고
씰을 동반 이식하는 것까지가 전부다.

- **하지 않는 것**: 성장 트리거 교체(교감 레벨업→수호령강화 퍽 = §9-3),
  Ctrl/R3 소환 토글(§9-3), 런 공유 단일 풀 전환(§9-3), 드레인/회복 수치 변경,
  affinity god-module 삭제(§9-4), HUD 재라벨(§9-3).
- §9-2 완료 시점의 게임 동작은 **추출 전과 완전히 동일**해야 한다
  (satiety·교감 보상 모두 기존대로 작동).

## 1. 착수 기준 (고정)

- 기준 HEAD: `897da5df7` (정산 커밋 7건 완료 상태). 이후 올라간 커밋
  (활주방울 HUD 등)은 무관한 병렬 트랙 — 충돌 시 현재 HEAD 위에서 작업.
- `430a3a539`가 이미 satiety 로직을 `LingpetSatietyRuntimeState`로 위임
  추출해 뒀다 — **이 구조를 출발점으로 사용, 재추출 금지.**
- **불가침**: 정산 보류 13건(`docs/lingpet_guardian_wip_settlement.md` 실행
  로그 참조 — bomb_surprise, game_audio owner 씰 3쌍, feed/plaza 씰,
  runtime_perk_state, battle_scene_frame_controller, rebrand 씰 쌍) +
  외래 캠페인 dirty 파일(부동갑주·플라자 분해·퍽 파이프라인·프레임 컨트롤러·
  로딩팁·game_audio·활주방울 HUD). 이 파일들은 읽기만 하고 수정·스테이징 금지.
- `character_info_lingpet_card_specs_smoke` = **기존 RED 기준선** (WIP 소실
  고아쌍, 이번 작업과 무관). 악화 금지, 복구 시도도 §9-2에서는 금지(§9-3 전
  복구 게이트로 별도 처리 예정).
- **git reset / checkout / stash 절대 금지** (미커밋 외래 WIP 다수).
  회귀 반증은 in-place Edit 토글/임시 패치로만.
- 로컬 커밋만, 푸시 금지. `git add -A` 금지 — 명시 경로 스테이징만.
- 커밋은 아래 ①/②/③ 기능 묶음별 원자 커밋 (필요 시 더 세분화 가능,
  병합 금지). 각 커밋 전 `git diff --check`, 커밋 후 스테이징 목록 대조.

## 2. 작업 ① — 지속시간 레일 owner 추출

`lingpet_affinity_state.gd`(1997줄) 내부의 satiety 레일을 새 owner 모듈
**`godot/scripts/lingpet/lingpet_duration_state.gd`** 로 추출한다.

이동 대상 (affinity_state 내 현재 위치 앵커):

- `SATIETY_*` 상수군 (~39-55행: 드레인 0.52/s, 휴식회복 비율 1/3,
  슬로우 커브 50→10, 각성 임계 10, `SATIETY_VALUE_SNAP_EPSILON 0.001`)
- `get/set/add/advance_satiety` (활동 드레인 + 슬롯 휴식 회복 분기 포함)
- `advance_satiety_exhaustion` (탈진 텔레그래프 1.75s)
- `_sanitize_satiety_value` / `_sanitize_satiety_exhaustion_timer`
  (~1824-1848행 — **Per-Tick Float Drain Rail-Residue 트랩의 봉인된 수정본.
  ε-밴드 스냅을 한 글자도 훼손하지 말 것**, `docs/godot_runtime_traps.md` 참조)
- per-pet satiety 저장 dict + `export_run_state`/`import_run_state`의
  satiety 필드 직렬화

구조 계약:

- `lingpet_duration_state.gd`가 위 레일의 신규 소유자가 되고,
  `lingpet_affinity_state.gd`는 **기존 공개 API 시그니처를 유지한 채 내부
  위임**으로 전환한다 (콜사이트 ~14곳 무수정이 이상적 — 콜사이트를 고쳐야
  한다면 `LingpetSatietyRuntimeState`와 `lingpet_egg_runtime` 경유 지점만).
- `LingpetSatietyRuntimeState`(→affinity_state 위임 중)는 시그니처 유지,
  위임 종착지만 duration_state로 바뀌는 것을 허용.
- 명명: 모듈/내부는 duration 어휘로 리네임하되, **세이브 스냅샷 키와 owner
  스키마 키는 이번 단계에서 바꾸지 않는다** (스키마 스왑은 §9-3 — 바꾸면
  `_is_volatile_run_snapshot` 휴리스틱과 owner-field schema 트랩을 건드림).
  새 owner 키를 추가해야만 한다면 `BattleSceneState.DEFAULT_VALUES`에
  lingpet_/ringpet_ 쌍으로 선언할 것.

## 3. 작업 ② — 수호령강화 버프 저장소 owner 추출

교감 보상카드의 **저장·적용 레일**을 새 owner 모듈
**`godot/scripts/lingpet/lingpet_enhancement_buff_store.gd`** 로 추출한다.
(트리거는 여전히 교감 레벨업 — 트리거 교체는 §9-3.)

이동 대상:

- per-pet `reward_counts` 스택 저장 (REWARD_TYPE_ACTIVE_SKILL/PASSIVE_SKILL/
  MOBILITY(캡6)/DEFENSE(캡2)/GAUGE(캡4)/SECOND_*_UNLOCK) + 스택 캡 상수
- `_can_apply_reward_card` 적용가능성 검사 (affinity_state ~1357행) +
  `_resolve_effective_reward_card` 대체/NO_REWARD 폴백
- `_apply_reward_to_pet_counts` 류 적용 경로
- run_state 직렬화의 reward_counts 필드

구조 계약:

- `lingpet_current_profile.gd`의 `get_stat()` 합성층(73-110행, `AFFINITY_*`
  상수 8-15행)과 `_get_effective_active/passive_skill_level`(base+bonus)은
  **읽기 소스만 buff store로 재지향**하고 수치·캡·합성 순서는 그대로 —
  이 채널이 끊기면 전 펫이 조용히 base Lv로 고정된다 (실효 스킬레벨 채널
  회귀 — 정산표 리스크 항목).
- 보상 덱 생성(`_build_reward_deck` 시드 결정론)과 레벨업 트리거는
  affinity_state에 남긴다 (§9-4에서 함께 삭제될 부분).
- 참고(구현 금지, 주석만): §9-3에서 "지속시간 증가" 버프는 per-pet
  reward_counts가 아니라 런 공유 duration owner에 저장된다 (정본 §5 계약).
  buff store 주석에 이 예약을 남겨 둘 것.

## 4. 작업 ③ — 씰 동반 이식

- 신규 씰 2종 작성 (템플릿 = `godot/tests/lingpet_satiety_runtime_state_owner_smoke.gd`):
  - `lingpet_duration_state_owner_smoke.gd`: 드레인/휴식회복 비율, ε-스냅
    잔차 주입 레그(합성 exact-0 금지 — 실틱 시퀀스 포함), 탈진 텔레그래프,
    리그 면제 래치 관통.
  - `lingpet_enhancement_buff_store_owner_smoke.gd`: 스택 캡 포화, 적용
    불가 카드 대체→NO_REWARD 폴백, effective 스킬레벨 base+bonus 합성
    (divergent 케이스 — boosted != base).
- 기존 관련 씰(satiety_runtime_state_owner, egg_runtime, affinity 계열)은
  **수정 없이 GREEN 유지**되어야 한다 — 이것이 동작 보존의 증명.
- 반증검증 1회 이상: 새 씰이 실제로 변별력이 있는지, 레일 상수 하나를
  in-place로 토글해 RED가 뜨는 것을 확인 후 원복 (git 조작 금지).
- 실행: `godot/tools/run_smoke_tests.ps1 -Tests @('res://tests/<이름>.gd', ...)`.
  판정은 표준 러너 관통 (공허-GREEN 트랩: `_expect` quit 덮어쓰기·미선언
  프로퍼티 대입 조용한 abort — `docs/godot_runtime_traps.md` 참조).
- 신규 씰의 CI/focused 러너 등재 여부를 확인하고 등재하거나, 불가하면
  보고서에 명시 (WIP 소실 사건의 "focused 미등재 → 조용한 RED" 재발 방지).

## 5. 완료 조건 + 보고 형식

- [ ] 신규 owner 2종이 실제 참조되고 (죽은 코드 방치 금지), affinity_state는
      위임 래퍼로 축소
- [ ] 기존 씰 전부 GREEN (card_specs 기존 RED 제외) + 신규 씰 2종 GREEN
      + 반증 RED 확인 기록
- [ ] 커밋: ①(duration 레일+씰) / ②(buff store+씰) 원자 분리, 메시지에
      "§9-2 추출 원본 — §9-4에서 구 트리거와 함께 삭제 예정" 맥락 명기
- [ ] 잔여 dirty 대조: 자기 작업 외 파일(불가침 목록)을 건드리지 않았는지
      `git status`로 확인
- 보고: 커밋 해시별 요약, 씰 실행 결과 원문, 등재 여부, 미결/발견 사항.
