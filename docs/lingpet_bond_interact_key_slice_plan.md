# 링펫 비마우스 교감 (bond interact key) 슬라이스 계획

> 단일 소스(single source). 이 문서가 비마우스 교감 설계·배선·검증의 진실 원본입니다.
> 디자인/리뷰 = Claude. GDScript 배선 = 사용자/Codex.

## 0. 배경 / 한 줄 요약

- **문제**: 링펫 클릭 교감(클릭 반응 + `SOURCE_CLICK` 교감치)은 마우스 좌클릭
  단일 진입점(`battle_scene_input_controller._handle_lingpet_companion_click`,
  147~170행)이다. 파지법 「스페이스+방향키」와 「Xbox 패드」 유저는 마우스로
  손을 옮기지 않으면 교감을 못 한다.
- **결정된 방향(2026-07-04)**: 파지법 카드는 3종 모두 유지한다. 대신 교감에
  **비마우스 진입점**(키보드 키, 이후 패드 버튼)을 추가한다.
- **핵심 설계**: 키 입력 시 좌표 인자를 **컴패니언 현재 위치(`_companion_pos`)로
  자기-타게팅**해서 기존 `try_begin_companion_click_reaction` 본체를 100% 재사용.
  존 판정·텍스처 준비 게이트·탈진/신체존재 게이트·`SOURCE_CLICK` 캡·오디오가
  전부 그대로 굴러간다. **새 밸런스 레버 없음.**

## 1. 확정/권장 결정

| 항목 | 값 | 근거 |
|---|---|---|
| 파지법 카드 3종 | **전부 유지** | 파지법은 바인딩이 아니라 힌트 분기(스매셔 리더는 방향키+A/D+패드 상시 수용). 카드 삭제는 문제를 해결 못 함 |
| 키보드 키 | **`KEY_E` (D1 확정, 2026-07-04)** | PC 게임 상호작용 국룰. 전투 사용 키 감사 결과 미사용(§4). 오발동해도 무해(연출+캡 있는 교감치) |
| 발동 의미 | **위치 무관, 현재 컴패니언에게 즉시 교감** | 키에는 커서가 없으므로 "가까이 가서" 조건은 불필요한 마찰. 클릭과 동일 결과 |
| 교감치 소스 | 기존 `SOURCE_CLICK` 재사용 | round_cap / battle_cap(`lingpet_affinity_state.gd` 1167~1178행) 자동 상속. 새 소스 추가 금지 |
| 패드 버튼 | **RT 트리거 (D2 확정, 2026-07-04)** | RT는 기존 주 액션/확인 축이므로, 교감 성공 풀에 한해 RT primary-action 폴링을 완전 해제(`<=0.35`) 전까지 마스킹. 래치 엣지(눌림 0.60 / 해제 0.35) |
| 클릭 경로 | **변경 없음** | 마우스 클릭은 지금 그대로. 키는 추가 진입점 |

## 2. Slice 1 — 키보드 교감 키 (핵심)

### 2.1 `lingpet_egg_runtime.gd` — 자기-타게팅 래퍼 (신규 메서드 1개)

`try_begin_companion_click_reaction`(2754행) 바로 아래에:

```gdscript
func try_begin_companion_interact_reaction(registry: Object = null) -> bool:
	# Non-mouse bond entry (keyboard/gamepad): self-target the companion's own
	# position so the click body (zone check, texture gate, exhaustion/body-presence
	# affinity gate, SOURCE_CLICK caps, audio) is reused verbatim.
	if _state != STATE_COMPANION:
		return false
	return try_begin_companion_click_reaction(_companion_pos, registry)
```

- `_companion_pos == Vector2.ZERO`(미배치) 가드는 클릭 본체 2757행이 그대로 처리.
- `can_start_at(_companion_pos, _companion_pos)`는 존 판정(|Δ|≤70/60,
  `lingpet_companion_click_reaction_state.gd` 81~87행)을 자명하게 통과.
- 재발동(이미 재생 중) 시 오디오만 재생하는 클릭 스팸 동작도 그대로 상속.

### 2.2 `battle_scene_input_controller.gd` — 키 핸들러 (슬롯 순환 패턴 복제)

- 상수: `LINGPET_CYCLE_KEY := KEY_L`(12행) 옆에
  `const LINGPET_INTERACT_KEY := KEY_E` 추가.
- 핸들러: `_handle_lingpet_slot_switch`(129행)를 그대로 본뜬
  `_handle_lingpet_companion_interact_key(event, owner, registry, module_getter)`:
  - `InputEventKey` + `pressed` + `not echo` + `keycode == LINGPET_INTERACT_KEY
    or physical_keycode == LINGPET_INTERACT_KEY` (물리키 병행 매칭 — 그립
    오버레이 `_is_key` 435행과 같은 규약).
  - 런타임 획득도 슬롯 순환과 동일: `module_getter` → 폴백 `registry.get_instance`.
  - `try_begin_companion_interact_reaction`이 `false`면 **핸들러도 false 반환**
    (입력을 삼키지 않고 체인 통과 — 링펫 없는 캐릭터/상태에서 E키를 죽은 키로
    만들지 않음).
  - 성공 시 `_queue_redraw(owner)` + `_mark_handled(owner)` + true.
- **체인 삽입 위치 = 65~66행 클릭 핸들러 바로 아래, 슬롯 순환(67행) 위.**
  overlay_input(61~64행, TAB/일시정지 모달)이 먼저 소비하므로 모달 노출이
  클릭과 정확히 동일해진다(패리티 요구사항 — 클릭보다 넓지도 좁지도 않게).
  획득 컷인 스왈로(46행)도 자동 상속.

### 2.3 함정 봉인 (기존 표준 규칙 매핑)

| 함정 | 왜 안전한가 / 무엇을 해야 하나 |
|---|---|
| 공유 입력리더 엣지-이터 트랩 | 이 설계는 **이벤트 체인**(`handle_input`) 방식이라 `get_snapshot()` 엣지 소비가 아예 없음. 절대 per-frame 폴링 소비자로 구현하지 말 것 |
| 모달-블록 게이트 | 핸들러를 overlay_input **아래**에 두는 것으로 상속. 스모크에서 클릭-패리티 단언 |
| 캡 우회 | `SOURCE_CLICK` round/battle 캡은 `_add_affinity_points` 내부에 있어 자동 상속. 스모크에서 캡 도달 후 키 연타 → 포인트 불증 단언 |
| 탈진/신체존재 게이트 | 클릭 본체 2767~2770행이 그대로 실행 — 연출은 재생, 교감치만 차단. 키 쪽에 별도 분기 금지 |
| 키 충돌 | §4.1 감사표 참조. E는 전투 내 미사용. 스모크에서 L(슬롯 순환) 비간섭 단언 |

## 3. 스모크 (✅ 배선·봉인 완료 2026-07-04) — 2계층 분리

**의미론 계층** — `lingpet_egg_runtime_smoke._verify_companion_interact_key_reaction`
(클릭 의미론의 기존 오너 스모크에 동거):
- 자기-타게팅 발동 + 반응 활성 + `SOURCE_CLICK` +20 적립.
- 재생 중 재발동 = 오디오 리플레이 분기, 교감치 불증.
- 라운드 캡 패리티(2×20 후 3번째 = `blocked_reason == "round_cap"`).
- 비컴패니언 상태 거부(입력 폴스루 전제).
- 히든 소티 = 연출은 소비, 교감치 0 (body-presence 게이트 상속).
- 구조 씰: 래퍼가 `try_begin_companion_click_reaction(_companion_pos`를 경유
  (제2 지급경로 포크 금지) + 입력 소스에 `LINGPET_INTERACT_KEY := KEY_E` +
  `try_begin_companion_interact_reaction(registry)` 존재.

**라우팅 계층** — `lingpet_companion_interact_key_smoke.gd` (신규, 페이크 런타임):
- E(keycode/physical 각각) → 래퍼 도달 + registry 전달 + redraw.
- module_getter 경로와 registry 폴백 경로 모두 커버.
- 거부 시 입력 미소비(redraw 0 — E가 다운스트림에 살아있음).
- echo / release / 타키(F) / L 순환 / 마우스 이벤트는 래퍼 미도달.

**반증검증 완료 (in-place 토글, git 명령 미사용)**:
- 토글 A: 래퍼 인자 `_companion_pos` → `Vector2.ZERO` → 런타임 스모크
  12개 단언 FAIL 확인 (자기-타게팅 인자가 하중을 받음). 복원 후 GREEN.
- 토글 B: `LINGPET_INTERACT_KEY` E → F → 라우팅 스모크 양방향 FAIL 확인
  (E 미라우팅 + F 오도달 모두 검출). 복원 후 GREEN.
- 전체 게이트: headless load check GREEN, warning scan GREEN(0건).

## 4. 입력 예산 감사 (2026-07-04 기준)

### 4.1 키보드 (전투 중 사용 중)

`A/D/S/W/Space/X`(캐릭터 리더들), `B`(BGM), `L`(링펫 슬롯), `Shift`(스킬 툴팁,
space_arrows 그립), `Tab/Esc`(캐릭터 정보/일시정지), `F1~F11`(디버그/창).
→ **E, K 라이브 전투 미사용. E 확정.**
단, `lingpet_debug_picker`(디버그 모달)가 내부에서 E/Q/Z/X/F/R을 스킬 순환에
쓴다 — 그 모달은 overlay_input(체인 상류)에서 입력을 먼저 소비하므로 충돌
없음: 피커 열림 = E는 피커가 소유, 닫힘 = 피커는 통과하고 교감 키가 동작.

### 4.2 패드 (전투 중 사용 중 — 감사 갱신 2026-07-04)

`A/X`=주 액션, `B`=취소/하강, `Y`=아이템 사용, `LB/RB`=슬롯/탭, `Start`=일시정지,
`Back`=툴팁 순환, 우스틱(축+클릭)=의도적 서프레스(`RIGHT_STICK_AXES`=RIGHT_X/Y만,
트리거 무관), 좌스틱 클릭=코만도 화기 전환, D패드=이동.
**RT(`JOY_AXIS_TRIGGER_RIGHT`)는 이미 `GamepadInput.is_primary_action_pressed`
및 `is_confirm_event`의 주 액션/확인 축이다.** D2는 이 기존 계약을 없애지 않고,
링펫 교감이 실제로 성공한 RT 풀에 한해 `GamepadInput`의 RT primary-action 폴링을
RT 완전 해제 전까지 마스킹한다. **LT(`JOY_AXIS_TRIGGER_LEFT`)는 코만도 보급 홀드
경로(`is_supply_hold_pressed`)이므로 교감 후보가 아니다.**

## 5. Slice 2 — 패드 RT 트리거 (✅ 배선·봉인 완료 2026-07-04)

- RT는 버튼이 아니라 축이므로 래치로 눌림 엣지를 합성:
  `_consume_lingpet_interact_trigger_edge` — 눌림 `>= 0.60`에서 1회 발동,
  해제 `<= 0.35` 아래로 내려와야 재장전. 중간 밴드(0.35~0.60) 지터는 불활성.
  임계값 상수 2개가 튜닝 레버(`LINGPET_INTERACT_TRIGGER_*_THRESHOLD`).
- 핸들러는 Slice 1과 동일 진입점(`_handle_lingpet_companion_interact_key`)에
  OR 결합 — 런타임 래퍼·거부 폴스루·모달 패리티 전부 공유.
- **주 액션 충돌 방지 보강(2026-07-04 재감사)**: RT는 기존 주 액션/확인 축이므로
  교감이 성공한 RT 엣지에서 `GamepadInput.suppress_primary_action_trigger_until_release()`
  를 호출한다. 이후 `GamepadInput.is_primary_action_pressed()`는 RT가 `<= 0.35`로
  완전히 해제될 때까지 RT 축을 무시하고, A/X 버튼 주 액션은 계속 허용한다.
- 라우팅 스모크에 추가 봉인: 1풀 1발동 / 홀드 재발사 금지 / 중간밴드 재장전
  금지 / 완전 해제 후 재발동 / LT·스틱축 미도달 / 성공한 RT 교감 후 주 액션
  폴링 마스크 유지 및 완전해제 복구.
- 공용 매핑 스모크(`gamepad_input_mapping_smoke`)에 RT primary-action 기존 계약 유지와
  링펫 교감 마스크 해제 조건을 함께 봉인.
- 반증검증 토글 C: 래치 가드 제거 → 3단언 FAIL 확인 후 복원 GREEN.
- 알려진 무해 엣지: 모달 뒤에서 해제 이벤트가 삼켜지면 다음 1풀이 무시될 수
  있으나 그 해제로 자가 재장전(최대 1회 헛풀, 자기치유). primary-action 마스크도
  같은 `<= 0.35` 해제 기준이므로 중간 밴드 지터는 액션으로 새지 않는다.

## 6. Slice 3 — TAB 교감 툴팁 안내 (✅ 배선·봉인 완료 2026-07-04)

- `character_info_overlay_lingpet_presenter.gd` 교감 호버 툴팁 설명에 신규
  문장 연결(기존 키 불변): **"링펫을 클릭하거나 E 키(패드 RT)로 교감할 수
  있습니다."**
- 다국어 동기화 완료: ko 원문 키 + `EXACT_TEXT_EN/ZH/JA/ES` 4사전 등록.
  pt-BR/ru는 EXACT_TEXT 사전 자체가 없어 형제 문장과 동일 스코프(기존 교감
  툴팁 문장도 미등록)로 유지.
- 봉인: `language_settings_smoke`에 4언어 정확일치 스팟체크 추가.
- 반증검증 토글 D: ja 키 훼손 → "localize to ja" FAIL 확인 후 복원 GREEN
  (러너의 에러출력 게이트가 deferred-quit 함정까지 커버함을 확인).

## 7. 진행 상태

- [x] D1 키 확정 = `KEY_E` (사용자, 2026-07-04)
- [x] Slice 1 배선 (Claude 직접, 2026-07-04): 런타임 래퍼
      (`lingpet_egg_runtime.try_begin_companion_interact_reaction`) +
      입력 핸들러(`_handle_lingpet_companion_interact_key`, 클릭 핸들러 직하 삽입)
- [x] 스모크 2계층 + 반증검증 토글 A/B + 전체 게이트 GREEN (§3)
- [x] E키 전역 소비자 감사 (lingpet_debug_picker만, 모달 상류 소비로 충돌 없음)
- [x] D2 = RT 트리거 확정 (사용자, 2026-07-04) → Slice 2 배선+씰+반증(토글 C) 완료
- [x] D2 재감사 보강 (Codex, 2026-07-04): RT가 기존 primary/confirm 축임을 문서 정정,
      성공한 RT 교감 후 primary-action 폴링 마스크 + 스모크 씰 추가
- [x] D3 = TAB 교감 툴팁 한 줄 확정 (사용자, 2026-07-04) → Slice 3 배선+4언어 동기화+씰+반증(토글 D) 완료
- [x] 전체 게이트 재GREEN (스모크 3종 / headless load / warning scan 0건)
- [x] D2 보강 Claude 적대 리뷰 APPROVE (2026-07-04): 폴링 자가치유(`_refresh_primary_action_trigger_suppression`)가
      모달-스왈로 마스크 고착을 구조적으로 차단, 마스크는 trigger_edge 성공에만 설정(E키 성공은 마스크 안 함),
      해제 임계 0.35가 래치와 동일 경계. 픽스 1건: 도달 불가 이중 가드 2줄 제거(스모크 재GREEN)
- [ ] 라이브 QA: ① space_arrows 파지 실플레이 E 교감 ② 실물 패드 RT 교감 ③ TAB 툴팁 문구 노출/줄바꿈 확인
      ④ **RT 느린 풀 액션 블립**: 액션 폴링 데드존(0.45) < 교감 눌림(0.60)이라 컴패니언 동반 중 RT를 천천히
      당기면 0.45~0.60 구간에서 마스크 전 주 액션이 수 프레임 발동할 수 있음. 체감되면 레버=교감 눌림
      임계를 0.45로 내려 동시 개입(지터 마진 0.10으로 축소 트레이드오프)
- [ ] 커밋 (미커밋 — 링펫 WIP 클러스터와 함께 검토)
