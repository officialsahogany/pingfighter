# 테스트 난이도 스킬 언락 쇼케이스(커맨드 각인 연출) 슬라이스 계획

> 단일 소스(single source). 이 문서가 스킬 언락 쇼케이스 설계·배선·검증의 진실 원본입니다.
> 디자인/리뷰 = Claude. GDScript 배선 = 사용자/Codex.

## 0. 배경 / 한 줄 요약

- **문제**: 링피아 스킬은 커맨드 입력(홀드/더블탭/연계) 발동이 많아, 신규
  플레이어가 퍽으로 스킬을 얻어도 **발동법을 모른 채 런이 끝난다**. 퍽 카드가
  이미 "무엇을 얻었는지"는 알려주므로, 부족한 것은 획득 순간의 **입력 각인**이다.
- **결정된 방향(2026-07-05)**: 테스트 난이도(내부 id `junior`)에서 액티브 스킬
  언락 퍽을 획득하면, 기존 카드→오브 플라이트가 끝난 직후 화면 중앙에
  **프리즈 + 입력 티칭 패널**(스킬명 + 키캡 커맨드 줄 + 모션 힌트)을 띄운다.
- **핵심 설계**: 새 pause 분기 0개. `_finish_successful_choice` 실행을 쇼케이스
  해제 시점까지 **지연**시켜 `choice_active`가 계속 true → 기존 모달 게이트
  (`battle_scene_modal_gate_controller._should_block_battle_physics` 111행의
  `runtime_perk_state.is_choice_active` 술어)가 그대로 물리를 막는다.
  카오스 스피어 블랙홀 소프트락 클래스(owned-ball × update_effects-only pause
  창 신설)를 구조적으로 회피한다.

## 1. 확정/권장 결정

| # | 항목 | 값 | 근거 |
|---|---|---|---|
| D1 | 발동 스코프 | `choice.get("unlocks_skill", "") != ""` 초이스만 | 플라이트와 동일 판별 키. 패시브/레벨업 퍽 제외 — 매 획득 프리즈는 소음 |
| D2 | 난이도 스코프 | `owner.get("ai_mode")` → `BattleSceneConfig.normalize_league_mode()` == `"junior"` (표시명 "테스트") | v1은 테스트 난이도 전용. 상위 난이도 "계정 기준 첫 1회" 노출은 세이브 스키마가 필요하므로 백로그 |
| D3 | 발동 시점 | apply 성공 후 `_finish_successful_choice` 호출 3곳(553 직접 / 628 플라이트 / 1712 스왑확정)을 지연 헬퍼로 치환 | 세 획득 경로 전부 한 헬퍼로 수렴. 쿨다운 재개·resume safety·별포인트 흡수·다음 초이스 오픈이 전부 "진짜 모달 종료" 시점에 실행됨(기존 종료 의미론 무손상) |
| D4 | 입력줄 소스 | 로컬라이즈된 skill data의 `how_to_use` 재사용(`language_settings.gd` 406~414행 경로) + 렌더 측 토큰 정규화 | 7언어 번역이 이미 존재. 신규 번역 테이블 없음 |
| D5 | 해제 | 아무 키/클릭/패드 확인(개시 후 0.3s 가드) + **자동 해제 6.0s(필수)** | 자동 해제 없으면 소프트락 클래스. 0.3s 가드는 카드 선택 입력 누출 방지 |
| D6 | 아트 | v1 프로시저럴 패널(신규 텍스처 0) + 스킬 오브 아이콘 재사용은 SHOULD | 텍스처 0 = 짧은 모달 리빌 폴백아트 트랩(스트리밍 미완 노출) 원천 회피 |
| D7 | 신규 정적 문구 | 헤더("새 스킬 획득!")·프롬프트("아무 키나 눌러 계속") 2개 × 7언어 동기화 | 문구 수정=다국어 동기화 표준 규칙 |

## 2. Slice 1 — `runtime_perk_state.gd` 쇼케이스 상태기계

### 2.1 상태 + 오픈/지연 헬퍼

- 상태: `var unlock_showcase: Dictionary = {}` — `active`, `age`, `choice_id`,
  `choice`(duplicate), `skill_id`, `character_type`, 지연된 finish 인자
  (`perf_logger`는 저장하지 말고 dismiss 시 null 전달).
- 상수: `UNLOCK_SHOWCASE_MAX_AGE := 6.0`, `UNLOCK_SHOWCASE_MIN_DISMISS_AGE := 0.3`.
- 헬퍼(치환 대상 3곳이 전부 이걸 호출):

```gdscript
func _finish_or_open_unlock_showcase(choice_id, owner, registry, perf_logger, choice) -> void:
	if _should_open_unlock_showcase(choice, owner):
		unlock_showcase = { "active": true, "age": 0.0, "choice_id": choice_id,
			"choice": choice.duplicate(true),
			"skill_id": str(choice.get("unlocks_skill", "")),
			"character_type": _get_character_type(owner) }
		return
	_finish_successful_choice(choice_id, owner, registry, perf_logger, choice)
```

- `_should_open_unlock_showcase`: `unlocks_skill != ""` AND
  `BattleSceneConfig.normalize_league_mode(str(_get_owner_value(owner, "ai_mode", "champion"))) == "junior"`.
  (owner 키 규약은 `ball_speed_debug_overlay.gd` 98~99행과 동일.)
- `is_unlock_showcase_active() -> bool` 추가. **`is_choice_active()`는 변경하지
  않는다** — 쇼케이스 동안 `choice_active`가 어차피 true로 유지되므로(지연
  덕분에 829행 `choice_active = false`가 아직 안 돎), 모달 게이트/루프 오디오/
  `owner.set("runtime_perk_choice_active", ...)` 2143행 싱크가 전부 자동 상속.

### 2.2 dismiss / 틱 / 리셋

- `handle_input`(325행) 최상단: 쇼케이스 활성이면 키다운(에코 제외)·마우스
  버튼다운·패드 확인만 소비, `age >= 0.3`일 때 `_dismiss_unlock_showcase(owner,
  registry)` 호출 후 true. 모션/휠은 통과시키지 말고 소비하되 dismiss 트리거로
  쓰지 않는다(호버로 넘어가는 사고 방지). **per-frame 폴링 소비자 금지**
  (공유 입력리더 엣지-이터 트랩) — 이벤트 체인 방식 유지.
- `_dismiss_unlock_showcase`: stash를 지역으로 빼고 `unlock_showcase.clear()`
  **먼저**, 그다음 `_finish_successful_choice(stash...)`. (finish가
  `open_next_choice`로 재진입해도 쇼케이스 잔상 없음.)
- `_update_internal`(291행): 쇼케이스 활성이면 `age += delta`, `age >=
  UNLOCK_SHOWCASE_MAX_AGE`면 자동 dismiss. 이 틱은 초이스 모달 애니메이션과
  같은 드라이버라 물리 블록 중에도 돈다(플라이트가 이미 같은 방식).
- `reset()`(134행): `unlock_showcase.clear()` 추가. **지연된 finish는 버린다**
  — reset은 라운드/매치 경계이므로 finish의 부수효과(흡수 연출, 다음 초이스)를
  실행하면 안 되고, `pending_skill_choices` 등은 reset 본체가 이미 청소한다.
  (카오스 스피어 pending-token wipe 패밀리 = "지연 토큰이 리셋에서 샌다"의
  역방향 누수까지 스모크로 봉인, §4 leg 6.)

### 2.3 함정 봉인 (기존 표준 규칙 매핑)

| 함정 | 왜 안전한가 / 무엇을 해야 하나 |
|---|---|
| owned-ball × pause 창 신설 (카오스 스피어 클래스) | pause 창을 **신설하지 않음** — 기존 perk-choice 블록 창을 늘일 뿐. `battle_frame_flow_controller` 분기 추가 금지. update_ball/update_effects 비대칭 신설 금지 |
| 모달-블록 루프 오디오 | `is_choice_active` true 유지로 기존 `_stop_modal_blocked_gameplay_loop_audio` 경로 자동 상속. 신규 배선 없음 |
| 지연 finish 누수 | reset() 클리어 + dismiss에서 clear-먼저-finish-나중 순서. 스모크 leg 6 |
| owner-field 스키마 | 신규 `owner.set` 키 없음(기존 `runtime_perk_choice_active`만 유지). 새 키를 추가하게 되면 `BattleSceneState.DEFAULT_VALUES` 선언 필수 |
| 월클럭 쿨다운 | 쇼케이스는 이미 감사된 perk 모달 창의 연장이므로 새 노출 클래스 없음. `_resume_skill_cooldowns_for_choice`가 지연 finish 안에 있어 스킬 쿨다운도 쇼케이스 동안 계속 정지(의도) |
| 스왑 취소 no-op | 쇼케이스는 **apply 성공 후에만** 열림(1712행은 confirm 성공 경로). cancel 경로는 건드리지 않는다 |

## 3. Slice 2 — `runtime_perk_overlay_renderer.gd` 쇼케이스 draw

- draw 진입(90~94행 게이트 통과 후) 최우선 분기: `is_unlock_showcase_active()`
  면 **초이스 카드 대신** 쇼케이스만 그린다 — 딤 백드롭(기존 모달 딤 재사용)
  + 중앙 패널: ①헤더 ②스킬명(로컬라이즈 `korean` 필드) ③키캡 입력줄
  ④`motion_hint`(딤 컬러) ⑤하단 프롬프트(페이드 블링크).
- 키캡 입력줄 = `tutorial_hint_keycap_renderer.draw_centered_line()` 재사용.
  **exact-match 토큰 트랩**: `how_to_use`의 `"W/↑"`, `"←/→ + 좌클릭"`,
  `"A-W-D"`는 공백 분리 exact-match에 안 걸린다. 렌더러-로컬 정규화 헬퍼
  `_normalize_keycap_message(text)`: `/`·`-`·`+`로 이어진 조각을 쪼갰을 때
  **모든 조각이 `KEYCAP_TOKENS` 멤버일 때만** 공백 삽입(`"W/↑"`→`"W / ↑"`,
  `"A-W-D"`→`"A - W - D"`). `"0.6초"` 같은 비토큰 합성어는 불변. 마우스
  프로즈("좌클릭")는 텍스트로 남긴다(언어별 프로즈→`[LMB]` 매핑은 백로그).
- 스킬 데이터는 캐릭터 skill config(`_get_skill_config_key` 경유)와
  `language_settings.gd` 406~414행 로컬라이즈 병합 경로에서 읽는다. 신규
  카탈로그 스캔 금지 — per-frame draw에서 딕셔너리 풀스캔/duplicate(true)
  금지(카탈로그 룩업 트랩), 쇼케이스 오픈 시 1회 스냅샷해서 dict에 동봉해도 됨.
- 아이콘(SHOULD): 플라이트가 쓰는 오브 아이콘 경로 재사용 가능하면 패널
  좌측에 소형 오브. 복잡해지면 v1 생략 — 티칭 페이로드는 키캡 줄이다.
- 신규 PNG를 도입하지 않는다. 도입하게 되면 리빌 전 프리웜 완료 규칙
  (짧은 모달 리빌 폴백아트 트랩) 적용.

## 4. Slice 3 — 다국어 + 스모크

### 4.1 다국어

- 신규 정적 문구 2개(헤더/프롬프트)를 기존 UI 문구 테이블 규약에 따라
  ko/en/zh/ja/es/pt_br/ru 7언어 추가. grep 0건 단정 금지 — 숫자 변형 포함
  coverage 스모크에 편입(문구 동기화 표준).
- CJK 렌더: 명시 Nanum 강제 금지, 기존 `_get_ui_font`/fallback 경로 사용
  (일/중 화면 QA 항목에 포함).

### 4.2 스모크 — `godot/tests/runtime_perk_unlock_showcase_smoke.gd` (✅ 배선·봉인 완료 2026-07-05)

| leg | 단언 |
|---|---|
| 1 | junior + `unlocks_skill` 초이스 apply → 쇼케이스 active, `is_choice_active()` 여전히 true, `battle_scene_modal_gate_controller.should_block_battle_physics` == true |
| 2 | 키다운 dismiss(age≥0.3) → `_finish_successful_choice` 실행 증거: `pending_skill_choices` 감소, `last_selected_id` 세팅, (마지막 픽이면) 별포인트 흡수 시작 / (잔여 픽이면) 다음 초이스 오픈 |
| 3 | champion/mythic 동일 초이스 → 쇼케이스 미오픈, 즉시 finish (기존 플로우 회귀 0) |
| 4 | junior + 일반 패시브 퍽(`unlocks_skill` 없음) → 쇼케이스 미오픈 |
| 5 | 슬롯풀 스왑 경로: confirm 성공 → 쇼케이스 1회 오픈. cancel → 미오픈 + 상태 무변(no-op 계약) |
| 6 | 쇼케이스 활성 중 `reset()` → `unlock_showcase` 비움, 지연 finish 미실행(흡수/다음초이스 부수효과 없음), 이후 새 초이스 오픈 정상 |
| 7 | age 0.3 미만 키다운 → dismiss 안 됨(입력은 소비). age ≥ 6.0 자동 dismiss |
| 8 | `_normalize_keycap_message`: `"W/↑ 홀드 후 손을 떼면 발동"`→W·↑ 토큰 승격, `"0.6초 내 A-W-D 또는 D-W-A 입력"`→A/W/D 승격+`"0.6초"` 불변, `"←/→ + 좌클릭 동시 입력"`→←·→ 승격+`"좌클릭"` 텍스트 유지 |

### 4.3 반증검증 (SAFE — in-place 토글만, git 상태 명령 금지) — ✅ 완료 2026-07-05

- ✅ 토글 A: `_finish_or_open_unlock_showcase` 오픈 분기 `if false and ...` →
  10개 leg RED(직접/플라이트/스왑 3경로 + 모달게이트 leg 전부) 확인 후 원복.
- ✅ 토글 B: `reset()`의 `unlock_showcase.clear()` 제거 → "reset should clear
  the active showcase" leg만 정확히 RED 확인 후 원복. 원복 후 GREEN 재확인.

### 4.4 리뷰 노트 (2026-07-05 적대 리뷰 APPROVE — 결함 0, 비차단 노트 3)

1. `_update_unlock_showcase` 자동해제는 플라이트(`_update_choice_flight_effect`
   600~601행)와 달리 `owner == null or registry == null` 가드가 없다. 현재 라이브
   update 호출자 2곳(overlay_frame_controller / stage_clear starpoint handler)은
   모두 실인자 전달이라 이론적 엣지 — 나중에 이 함수를 만질 때 플라이트 규약에
   맞출 것.
2. 쉼표 시퀀스 문구(카오스 스피어 "지상에서 A, W, D 입력")는 `"A,"`가
   exact-match 실패로 키캡 승격이 안 된다(텍스트로는 정상 표시). 정규화가
   `/ - +`만 다루므로 후행 문장부호 스트립은 백로그(§6에 편입).
3. 레이아웃 엣지: `motion_hint==""` && `how_to_use!=""`일 때 패널 244px로
   줄지만 keycap_y(+210)와 프롬프트(+217)가 겹친다. 현 데이터로는 도달 불가
   (모든 오브 스킬에 motion_hint 존재, 폴백은 둘 다 빈 문자열) — 도달 가능해지는
   데이터 추가 시 keycap_y도 패널 높이 기준 상대화할 것.

## 5. 라이브 QA 체크리스트

- [ ] 테스트 난이도에서 언락 퍽 획득 → 플라이트(1.86s) → 쇼케이스 순서로 재생
- [ ] 쇼케이스 동안 공/보스/타이머 완전 정지, 루프 SFX(후딜 등) 잔류 드론 없음
- [ ] `"W/↑"` 계열이 실제 키캡으로 승격되어 보임(스매셔 플라즈마로 확인)
- [ ] 아무 키/클릭/패드로 즉시 해제, 무입력 6s 자동 해제
- [ ] 잔여 픽이 있으면 해제 직후 다음 퍽 카드가 정상 오픈
- [ ] 실전/오버클럭 난이도에서는 기존 그대로(쇼케이스 없음)
- [ ] 일본어/중국어 언어로 헤더·프롬프트·how_to_use 글리프 정상(tofu 없음)

## 6. 백로그 (v1 제외)

- 상위 난이도 "계정 기준 첫 획득 1회" 노출(세이브 스키마 + 스테이지 전환 리셋 감사 필요)
- `how_to_use` 마우스 프로즈 → `[LMB]`/`[WHEEL]` 아이콘 매핑(언어별 매핑 테이블 필요)
- 쇼케이스 패널 전용 프레임 아트(도입 시 프리웜 게이트 필수)
- 키캡 정규화 후행 문장부호 스트립(`"A,"` → `A` 승격 + `,` 텍스트 유지 — 카오스 스피어류 쉼표 시퀀스)
