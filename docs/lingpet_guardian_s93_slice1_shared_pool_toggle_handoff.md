# §9-3 슬라이스 1 핸드오프 (Codex 실행용) — 런 공유 지속시간 풀 + 부화 롤 + 스테이지 리필 + Ctrl/R3 토글

작성 2026-07-28. 기획 정본 = `docs/lingpet_guardian_duration_redesign_plan.md`
(§3·§4·§7 필독), §9-2 산물 = `lingpet_duration_state.gd`(2f1df620a) ·
`lingpet_enhancement_buff_store.gd`(fd1e7e4a1). 이 문서 전체를 붙여넣으면
자기완결로 착수 가능하다.

## 0. 공통 가드레일 (전 슬라이스 동일)

- git reset / checkout / stash 절대 금지. `git add -A` 금지 — 명시 경로만.
- 로컬 커밋만, 푸시 금지. 커밋 전 `git diff --check`, 커밋 후 목록 대조.
- **불가침**: 정산 보류 13건 + 외래 캠페인 dirty(부동갑주·플라자 분해·퍽
  파이프라인·프레임 컨트롤러·로딩팁·game_audio·활주방울/기력구슬 HUD).
  읽기만 허용, 수정·스테이징 금지.
- focused/CI 등재·ownership ledger 갱신은 외래 dirty 정산 후 별도 자기완결
  커밋 — 이번 슬라이스에서 `.github/workflows/godot-ci.yml`·
  `godot/tools/run_pre_push_checks.ps1` 접촉 금지.
- 씰 판정은 표준 러너 관통: `godot/tools/run_smoke_tests.ps1 -Tests @(...)`.
  각 신규 씰마다 반증검증 1회(상수/분기 in-place 토글 → RED 확인 → 원복).

## Gate 0 (슬라이스 1 착수 전 선행, 독립 커밋) — card_specs 기존 RED 복구

`character_info_lingpet_card_specs_smoke`가 4단언 RED다 (WIP 소실 사건에서
프레젠터 퍼사드 위임 배선만 소실된 고아쌍). **씰이 곧 실행 가능한 스펙이다 —
씰을 수정하지 말고** `character_info_overlay_lingpet_presenter.gd`가
`character_info_overlay_lingpet_card_specs.gd`로 위임하도록 배선을 복원하라:

1. presenter skill-spec 퍼사드 → card_specs 위임
2. presenter unlock-candidate 퍼사드 → card_specs 위임
3. presenter first-open 퍼사드 → card_specs 위임
4. skill-spec 퍼사드가 second-skill 카드 조합 세부를 보유하지 않을 것

완료 조건: 해당 씰 4단언 GREEN + 기존 presenter 계열 씰 회귀 GREEN.
독립 커밋(메시지에 "WIP 소실 고아쌍 복원" 맥락 명기) 후 슬라이스 1 착수.

## 1. 슬라이스 1 범위

런 공유 단일 지속시간 풀 전환 + 첫 부화 60~80초 롤 + 스테이지 클리어 전량
리필 + Ctrl/R3 소환·수납 토글. **여기 없는 것은 하지 않는다**: 영혼소환술
초식·알 스폰 게이트(슬라이스 2), 수호령강화 퍽(슬라이스 3), 심령수(슬라이스
4), affinity 트리거·교감 삭제(§9-4), HUD 리스타일(최소 재지향만 허용, 아래
§1-6).

### 1-1. 런 공유 풀 전환

- `lingpet_duration_state.gd`를 per-pet satiety dict에서 **런 공유 단일 풀**
  (`pool_current` / `pool_max`, 초 단위)로 전환한다. 펫 교체(L사이클)는 같은
  배터리를 공유 — 교체로 시간이 늘지 않는다.
- 첫 부화 시 **60~80초 랜덤 롤 1회** → `pool_max = pool_current = roll`.
  이후 펫 부화는 재롤 없음. 롤은 **부화 커밋 경로 2곳 모두** 커버:
  `lingpet_egg_runtime._finish_regular_hatch` + item-egg/overflow 경로
  (`lingpet_hatch_stat_roll_state.ensure_roll`의 once-guard 패턴 재사용,
  결정론 RNG 주입 가능하게). 부화 연출/피드백에서 롤 결과 노출은 §9-3 HUD
  슬라이스로 미룸 — 값 저장만.
- 드레인: **소환 중 실시간 1:1**. 회복: **수납 중 드레인의 1/3** (상수 단일
  소스, 라이브 튜닝 전제). 비활성 슬롯 펫의 별도 회복 개념은 폐지 — 회복은
  "수납 상태" 하나로만.
- **ε-스냅 레일을 양방향(0 하한·max 상한) 모두 유지** (Per-Tick Float Drain
  트랩 — §9-2에서 이식된 `_sanitize_*` 로직 확장).
- 만료(0 도달): **강제 수납** + 만료 후 **10초 이상 회복해야 재소환 가능**.
  잔여 ~10초부터 3단 경고(게이지 점멸 신호값 + 전용 사운드 훅 + 펫 모션
  변화 — 탈진 텔레그래프 1.75s 인프라 재사용). 사운드/모션 에셋이 없으면
  훅만 배선하고 보고서에 명시.
- 스테이지 클리어 시 `pool_current = pool_max` 전량 리필. **실제 스테이지
  전진 훅에만** 배선 (`battle_scene_match_event_driver`의 stage-transition
  경로) — `reset_round` 류 매 라운드 경로 금지 (스테이지 훅 vs reset_round
  트랩, CLAUDE.md).
- 리그 면제: 주니어/오토프레젠트 리그는 드레인 면제 (기존
  `is_auto_present_league` latch 패턴을 duration_state로 이식).

### 1-2. Ctrl/R3 토글

- `project.godot` input map에 **`guardian_toggle` 액션 신설**: 키보드
  Ctrl(`KEY_CTRL`) + 패드 R3(`JOY_BUTTON_RIGHT_STICK`). Ctrl은 코드 전체
  사용 0건 검증 완료 — 충돌 없음.
- 키보드 처리 소유자: `battle_lingpet_interaction_input_router`
  (`handle_companion_input` 계열에 토글 분기 추가 — 기존 E/RT 인터랙트
  섹션은 §9-4 트림 대상이니 **건드리지 말고** 별도 분기로).
- 패드 R3: `battle_system_shortcut_input_router`의 우스틱 일괄 억제
  (`should_suppress_right_stick_event` 소비 지점)에서 **배틀 한정 R3 버튼
  프레스만 carve-out**. 메뉴(`main_menu_scene`)·캐릭터선택의 억제는 유지.
  에지 래치 필수 (공유 입력 리더 same-frame edge 트랩 — 스냅샷 멱등 유지).
- 소환 조건: 펫 보유 + `pool_current > 재소환 문턱`. 수납→소환/소환→수납
  전환 연출은 슬롯 교체 0.62s 전환(`lingpet_companion_switch_state`) +
  `lingpet_ghost_blink_vfx` '퐁' 재사용.
- **최소 소환 유지 6초**: 소환 후 6초간 수납 입력 무시 (만료 강제 수납은
  예외 — 강제 수납이 우선).
- 부화 직후 기본 상태 = 소환.

### 1-3. 수납 상태 런타임 계약 (정본 §4 확정 계약 — 재확인 필수)

- 수납 = `companion_active` false fold. **탈진(exhaustion) fold가 걸려 있는
  전 콜사이트(~14곳)를 grep으로 재열거**해 (§9-2 이후 줄번호 이동) 같은
  목록에 수납 술어를 fold하라. 바디히트·방어 인터셉트·스킬 갱신·레일 카드·
  starlight/linkport 위치 스크립팅 전부 정지.
- 수납 중 정지 대상 **한정**: 개인/공유 스킬 쿨다운, 게이지 충전, 신규 시전
  준비. 현재 활성·보관 펫 쿨다운이 모두 감소 중인 지점
  (`lingpet_egg_runtime`의 쿨다운 감소 루프 + `lingpet_companion_skill_
  persistence`)에 수납 게이트를 넣되 —
- **이미 발사된 스킬·CC·잔류체는 동결·무료 지속 금지**: 수납 시점에 명시적
  종료·원상복구 + 루프 오디오 정리. 단순 게이트만 추가하면 잔류 효과가
  동결된다(효과 갱신이 소환 브랜치에 묶여 있음). 정지 게이트와 잔류체 종료
  스윕을 **같은 커밋**에.
- **남은 쿨다운 값과 방어 per-opportunity 롤 락은 보존** — 수납→재소환이
  `defense_decision_timer`/rolled-lock을 리셋하면 롤 파밍이 열린다.
  보존을 씰로 단언할 것.
- 비시각 라이브 상태는 idle-게이트 생존맵(`is_launch_blocked`) 규칙 준수
  (VISIBLE≠LIVE 트랩).

### 1-4. 세이브/스키마 (이번 슬라이스에서 스왑 허용 — §9-2 금지 해제)

- run_state 스냅샷: per-pet `satiety*` 필드 → 런 공유
  `duration_pool`/`duration_pool_max`(+만료 락 잔여) 필드로 스왑.
  `lingpet_save_store._is_volatile_run_snapshot` 휴리스틱 키와 정합 확인 —
  어긋나면 세이브가 조용히 초기화된다. 구 필드는 import 시 무시(관용 파서).
- owner 스키마: `BattleSceneState.DEFAULT_VALUES`의
  `lingpet_satiety_pct`/`ringpet_satiety_pct` 쌍을 duration 쌍으로 교체
  선언 (owner-field schema 트랩 — 미선언 set은 무음 no-op). 소비자
  (vitality projection 등)의 키 참조 동기.

### 1-5. 전환기(transitional) 계약

- 교감/보상 덱 트리거·클릭 교감은 **그대로 유지** (슬라이스 3까지 산다).
- 피딩 아이템 4종은 전환기 동안 **지속시간 회복제로 재매핑** (+N초, 환산
  상수 1곳 — 예: 구 40pt → +20초 초안, 튜닝 전제). 심령수 대체는 슬라이스 4.
- 탈진(satiety KO) 개념은 만료 강제 수납으로 **대체**된다 — 탈진 전용
  상태·Zzz 연출 경로가 죽은 코드가 되면 주석으로 §9-4 삭제 예정 표기만.

### 1-6. HUD 최소 재지향 (리스타일 아님)

- 기존 포만도 스트립(`character_info_overlay_lingpet_vitality_projection`)이
  공유 풀 % 값을 표시하도록 **값 재지향 + 라벨 "지속시간"** 최소 변경만.
  수납 중에도 읽혀야 한다 (블라인드 관리 금지). 본격 게이지 리스타일·전투
  HUD 상시 표시는 후속 슬라이스.

## 2. 씰 계약 (신규, 각각 반증검증 1회)

1. `lingpet_duration_pool_owner_smoke`: 첫 부화 롤 60~80 범위·1회성(재부화
   무재롤)·**이중 부화 경로 모두** 롤 발생, 소환 드레인 1:1, 수납 회복 1/3,
   ε-스냅(실틱 잔차 레그), 만료 강제 수납 + 10초 재소환 문턱, 스테이지
   리필, 리그 면제.
2. `guardian_toggle_input_smoke`: Ctrl/R3 에지 토글, 최소 유지 6초 무시,
   R3 carve-out(배틀에서 토글 발화 + 메뉴 억제 유지), same-frame edge 멱등.
3. `guardian_stow_contract_smoke`: 수납 중 쿨다운·게이지 정지 / 재소환 시
   남은 쿨다운 보존 / 방어 롤 락 보존(재소환 롤 파밍 불가) / 잔류체 종료
   (활성 스킬 이펙트 잔존 0 + 루프 오디오 stop 호출) / companion_active
   fold 전 콜사이트 술어 관통(대표 콜사이트 3곳 이상 아웃컴 단언 — 바디히트
   억제·방어 인터셉트 미발동·레일 카드 미표시).
- 기존 씰 회귀: duration/buff store owner·egg_runtime·collection·switch 계열
  GREEN 유지. `card_specs`는 Gate 0 이후 GREEN이 새 기준선.

## 3. 커밋 분할 제안 (원자, 순서)

1. Gate 0: presenter 퍼사드 위임 복원 (+씰 GREEN 전환)
2. 공유 풀 전환 + 부화 롤 + 스테이지 리필 + 리그 면제 + 세이브/스키마 스왑
   (+씰 1)
3. guardian_toggle 입력 + R3 carve-out + 전환 연출 (+씰 2)
4. 수납 상태 계약 fold + 쿨다운 정지 + 잔류체 종료 스윕 (+씰 3)
5. 피딩 재매핑 + HUD 최소 재지향 (독립 가능하면 분리, 아니면 4에 병합 허용)

## 4. 완료 보고 형식

커밋 해시별 요약 / 씰 실행 결과 원문 / 반증검증 기록(무엇을 토글해 RED를
봤는지) / 탈진 fold 콜사이트 재열거 결과(개수+대표 경로) / 미결·발견 사항
(특히 잔류체 종료 스윕에서 스킬별 예외가 있었는지).
