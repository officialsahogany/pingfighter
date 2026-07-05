# 액티브 아이템 HUD 주목도 폴리시 — 슬라이스 플랜 (SSOT)

## 0. 배경 / 결정

- **관찰**: 2026-07-04 서울게임타운2 전시에서 대부분의 관람객이 액티브
  아이템을 사용하지 않음.
- **진단 (코드 근거)**:
  - 슬롯 HUD가 화면 **하단 레터박스 밴드**에 `42px` 저대비(어두운 배경
    위 `Color(15,15,25,α180/255)` 박스)로 그려져 시선 밖.
    → `active_item_hud_layout.gd`, `active_item_hud_renderer.gd:34-39`
  - "사용법" 튜토리얼 힌트는 **주니어 리그 + 스타터 캐릭 + 중간튜토
    완료 + 20초 지연** 조건에서만 1회 발동 → 일반 매치/전시 세션에선
    대부분 미노출. → `active_item_use_tutorial_hint.gd:181-227`
  - 픽업 순간 `"%d번 키로 사용"` 힌트는 잠깐만 뜨고 사라짐; **사용
    가능 상태를 상시로 알리는 신호 없음**.
    → `active_item_pickup_feedback.gd:74`
  - 기존 `cooldown_flash_pulse`는 **쿨다운 종료 시에만** 반짝임; 첫
    획득·유휴 "준비됨" 상태엔 신호 없음.
    → `active_item_hud_slot_status_renderer.gd:20-24`,
      `active_item_hud_state.gd:54-61`
- **선택된 스코프 (사용자 결정)**: **슬롯 주목도 폴리시**.
  위치는 유지하되 슬롯 자체가 시선을 끌게 만드는 저위험 작업.
- **범위 밖 (이번 슬라이스 아님, 백로그)**:
  - "상시 사용법 신호" (튜토리얼 게이트 해제) — 별도 슬라이스.
  - "입력 접근성" (숫자열 → 이동손 근접키 바인딩) — 별도 슬라이스.

## 1. 목표 (수용 기준)

일반 매치(주니어 아님)에서, 아이템을 하나라도 보유하고 그 아이템이 지금
사용 가능하면, 플레이어가 공/패들에 시선을 둔 상태에서도 하단 슬롯이
"나 지금 누를 수 있어" 하고 **주변시로 인지**된다.

구체 딜리버러블:
- **A. 준비됨(ready) 유휴 글로우**: 아이템 보유 + 사용 가능 슬롯에
  은은한 맥동 링/헤일로. 가장 큰 주목도 획득 수단.
- **B. 획득 팝(pickup pop)**: 슬롯에 새 아이템이 처음 들어온 순간
  1회성 확대/플래시(약 0.35s). "방금 뭔가 생겼다" 신호.
- **C. 키 어포던스 강화**: 번호 배지(1/2/3)를 슬롯 인덱스가 아니라
  **입력 프롬프트(키캡)** 로 읽히게 대비/스타일 강화.
- **D. 패널 대비 상향**: 하단 패널 배경/테두리를 저대비 어두운
  박스에서 살짝 밝은 액센트 테두리로. (배경은 반투명 유지 — 플레이필드
  안 가림.)
- **E. (선택·게이트) 슬롯 크기 소폭 상향**: 레터박스 밴드 여유가
  확인될 때만. 미확인 시 42px 유지하고 A~D로 주목도 확보.

## 2. 데이터 모델 — "준비됨" 판정 (단일 진실)

슬롯 렌더러가 이미 받는 값으로 파생 가능. **새 상태 배관 불필요**:

```
has_item      := not item_data.is_empty()
on_cooldown   := float(slot_status.get("cooldown_remaining_ratio", 0.0)) > 0.0
throw_locked  := int(slot_status.get("throw_lock_remaining_seconds", 0)) > 0
ready         := has_item and not on_cooldown and not throw_locked
```

- 순수 함수로 추출: `ActiveItemHudSlotRenderer.is_slot_ready(item_data, slot_status) -> bool`
  (스모크가 이걸 직접 검증. 렌더 draw-call 검증은 헤드리스에서 불가하므로
  판정을 함수로 분리하는 게 봉인의 핵심.)
- `alchemy_notice_ratio`는 "준비됨"과 별개(긍정 이벤트 표시). ready
  글로우와 **동시 표출 금지** — alchemy 표시 중이면 ready 글로우
  suppress (겹치면 보라+시안 링이 뭉개짐, T5 참조).

## 3. 백본 — 파일별 변경 (전부 공용 → 6개 스테이지 자동 반영)

렌더 경로: 스테이지별 `stageN_active_item_hud_scene_drawer` /
`stageN_pillar_scene_drawer` → 공용 `active_item_hud_renderer.draw_slots`
→ `active_item_hud_slot_renderer.draw_slot` →
`active_item_hud_slot_status_renderer`. **아래 공용 4파일만 편집.**

### 3.1 `active_item_hud_slot_renderer.gd` (핵심)
- `is_slot_ready(item_data, slot_status) -> bool` 순수 함수 추가 (§2).
- `draw_slot()`에서 draw 순서:
  1. `_draw_ready_glow()` (ready일 때, 슬롯 **배후** 헤일로 — bg 그리기
     전에 그려 아이콘을 덮지 않게)
  2. 기존 `_draw_slot_background` → `icon_renderer.draw_icon`
     → `status_renderer.draw_status_overlays`
  3. `_draw_pickup_pop()` (pop_pulse > 0일 때, 밝은 확대 링/플래시)
  4. 기존 `_draw_slot_border` → `_draw_slot_number`(키캡화, §3.4)
- `_draw_ready_glow(canvas, slot_rect)`:
  - 맥동 `pulse = 0.5 + 0.5*sin(Time.get_ticks_msec()*0.006)`
    (~1.05s 주기; 느리고 부드럽게, 어지럽지 않게)
  - 외곽 확대 링 2겹: 소프트 시안 `Color(0.30,0.85,1.0, 0.10~0.22)`
    채움 + 밝은 링 테두리 `false, 2px`. `slot_rect.grow(3 + pulse*3)`.
  - **draw-call 예산**: 슬롯당 ≤3 (T2). 서페이스 할당·rotate 금지.

### 3.2 `active_item_hud_state.gd` (획득 팝 상태)
- 기존 `cooldown_complete_flash` 패턴을 그대로 복제한 pickup pop 추적:
  - `var pickup_pop: Dictionary = {}`  # slot_index -> {start_msec, item_key}
  - `PICKUP_POP_DURATION_MS := 350`
  - `get_slot_status()`에서: 이 슬롯의 아이템 식별자(`item_data.name` +
    필요시 `uid`)가 pop 기록과 다르면(=새로 들어옴) `start_msec` 갱신;
    경과 < 350ms면 `status["pickup_pop_pulse"] = <envelope>` 반환
    (0→peak→0 엔벌롭, cooldown_flash와 동일 곡선 재사용).
  - `reset()`에 `pickup_pop.clear()` 추가 (라운드/매치 리셋 누수 방지, T6).
- **트랩 T6**: pop 키는 **아이템 식별자 기반**. 슬롯 인덱스만으로 키를
  잡으면 스왑/재배치 시 오탐 pop. 빈→아이템 전이에서만 pop, 아이템→빈
  전이는 pop 아님.

### 3.3 `active_item_hud_renderer.gd` (패널 대비)
- `panel_renderer.draw_slot_panel(...)` 색 상향 (line 34-39):
  - 배경: 반투명 유지하되 약간 상향 e.g. `Color(18/255,20/255,32/255, 200/255)`
    (플레이필드 안 가리게 α는 과하지 않게).
  - 테두리: 저대비 `Color(70,70,90)` → 밝은 액센트
    e.g. `Color(120/255,150/255,190/255)` 또는 시안 틴트.
- ready 글로우가 슬롯 단위라 패널은 "그릇"만 살짝 밝히는 역할.

### 3.4 키 어포던스 (번호 배지)
- `active_item_hud_slot_renderer._draw_slot_number()`:
  - 배지 배경 대비 상향 (`α0.58` → 더 solid + 밝은 외곽선).
  - 글자색/외곽선 유지하되 배지를 키캡처럼(살짝 둥근/밝은 상단 엣지)
    읽히게. **아이콘/쿨다운 숫자 오버레이를 가리지 않게** slot_rect 내
    클램프 유지 (T7).

### 3.5 `active_item_hud_layout.gd` (E — 선택·게이트)
- `ACTIVE_ITEM_SLOT_BASE_SIZE = 42.0` 상향은 **레터박스 밴드 여유 확인
  후에만**. `bottom_pillar_h`(= `view_size.y - (game_offset.y+game_size.y)`)가
  `box_height = slot*scale + padding*2`보다 충분히 커야 함. 안 그러면
  `bottom_pillar_h < 18` 가드나 clamp에 걸려 **HUD가 통째로 사라지거나
  플레이필드로 침범**(T1).
- **권장: 이번 슬라이스는 42 유지, 크기 대신 A~D로 주목도 확보.**
  크기 상향은 여유 실측 후 별도로.

## 4. 트랩 (반드시 회피/QA)

- **T1 레터박스 클램프**: 슬롯 크기 상향은 `bottom_pillar_h`를 넘으면
  `visible=false`(HUD 소멸) 또는 플레이필드 침범. 최소 지원 창높이 +
  풀스크린 레터박스에서 실측 전엔 42 유지.
- **T2 매프레임 draw 비용**: ready 글로우/pop은 **매 프레임 전 스테이지**
  에서 최대 (슬롯수)개 그려짐. 슬롯당 draw-call ≤3, `Surface`/`rotate`/
  할당 금지. (CLAUDE.md "Per-Frame ..." + godot perf 플레이북 준수.)
- **T3 ready 오버프로미스**: 실제 사용 게이트(`active_item_slot_controller`
  의 use 조건 — 라운드 시작 전/타겟 필요 아이템 등)가 §2 predicate보다
  엄격하면, 글로우가 "준비됨"이라 해도 눌러서 안 될 수 있음.
  **결정 필요**: (a) 전시 목표상 "일단 눌러보게" 유도 → 느슨한 predicate
  허용, 또는 (b) 실제 use 게이트와 일치시킴. → §6 D1.
- **T4 공용 드로어/전 스테이지**: 렌더 중앙화라 6개 스테이지 + **모바일
  사이드 레이아웃** + **오버플로 슬롯(4번째+)** 전부 영향. 메인 3슬롯만
  QA하지 말 것. 오버플로 슬롯은 dim(`α60/255`)이라 ready 글로우가
  과하게 튀지 않는지 확인.
- **T5 선택 테두리 vs ready 색 충돌**: 선택 슬롯은 이미 골드 테두리
  `Color(1,220/255,80/255)`. ready 글로우를 **시안** 계열로 분리해 골드와
  구분. alchemy(보라)와 ready(시안) 동시 표출 금지(§2).
- **T6 pop 상태 누수**: pickup pop 키는 아이템 식별자 기반, `reset()`에서
  clear. 라운드 시작 리렌더마다 재-pop 금지.
- **T7 배지 가림**: 키캡 강화가 아이템 아이콘/쿨다운 숫자/throw-lock
  숫자를 가리지 않게 slot_rect 내 클램프 유지.

## 5. 봉인 (스모크)

`godot/tests/` 신규 스모크 `active_item_hud_ready_state_smoke.gd`
(기존 hud 스모크 네이밍 관례 따름):

1. **ready 판정 순수 함수**:
   - 아이템 O + cd 0 + lock 0 → `is_slot_ready == true`
   - 빈 슬롯 → false
   - cd > 0 → false
   - throw_lock > 0 → false
2. **반증 (필수)**: predicate를 인플레이스로 항상-true 토글(Edit/픽스처)
   → "빈 슬롯도 ready" 케이스를 스모크가 **RED로 잡는지** 확인 후 원복.
   (git reset/stash 금지 — §0 SAFE 반증 규칙.)
3. **pickup pop 상태**: 빈→아이템 전이 시 pop_pulse > 0; 같은 아이템
   유지 시 지속 후 0 수렴; 아이템→빈 전이는 pop 아님; `reset()` 후 0.
4. **레이아웃 가드(E 도입 시)**: 대표 view_size에서 `build_layout` →
   `visible=true`; 레터박스 밴드가 너무 얕은 view_size에선 `visible=false`
   유지(사이즈 상향이 밴드 가드를 깨지 않음 확인).

## 6. 결정 필요 (D)

- **D1 (ready predicate 엄격도, T3)**: 전시 유도 목적상 느슨한
  predicate(아이템 있고 쿨다운 아니면 글로우) vs 실제 use 게이트 일치.
  **권장 = 느슨(A안)**: 전시에서 "일단 눌러보게" 만드는 게 목표이고,
  라운드 시작 전 등 예외는 짧음. 단, 명백히 못 쓰는 상태(throw_lock,
  cooldown)는 이미 제외됨.
- **D2 (크기 상향 E)**: 이번 슬라이스 포함 여부. **권장 = 제외**
  (레터박스 실측 후 별도). A~D만으로 주목도 확보.

## 7. 라이브 QA 체크리스트 (배선 후, 픽셀 QA)

- [ ] 일반 매치(주니어 아님)에서 아이템 획득 → 슬롯 pop → 이후 ready
      글로우가 주변시로 인지되는가 (공에 시선 둔 채).
- [ ] 사용(쿨다운 진입) → 글로우 사라지고 쿨다운 프레임만 → 쿨다운 종료
      플래시 → 다시 ready 글로우 복귀.
- [ ] 오버플로 슬롯(4번째+)·모바일 사이드 레이아웃에서 과하지 않은가.
- [ ] 선택 슬롯 골드 테두리와 ready 시안이 시각적으로 구분되는가.
- [ ] 프레임 예산: 스테이지3/4 등 무거운 씬에서 글로우 추가로 체감
      드랍 없는지 (매프레임 draw 증가 확인).
- [ ] 픽셀 QA: 어지럽지 않은 맥동 속도(≥1s 주기), 아이콘/숫자 가림 없음.

## 8. 작업 분담

- **이 문서(슬라이스 플랜/디자인노트/트랩/스모크 설계)**: Claude.
- **GDScript 배선(§3)**: 사용자.
- **적대 리뷰 + 반증 확인(§5.2) + 라이브 QA 동석 판정**: Claude.
- 배선 완료 후 이 문서 §1 수용기준·§7 체크리스트로 검수.
