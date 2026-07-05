# UI 메뉴 타격감 + 회전 링코어 — 레퍼런스 적용 슬라이스 설계

단일 소스. 레퍼런스(YouTube JjbRQhdUCQk, 애니풍 JRPG 커맨드 메뉴)에서 차용할 3요소를
링피아 메뉴에 입힌다. 방향 결정 완료:
① 메뉴 이동 타격감(셀렉션 피드백) ② 왼쪽 천천히 회전하는 **링코어 크리스탈** ③ 깔끔함.

분담: Claude = 디자인 + 신호계약 + 트랩 브리프 + 적대적 리뷰 + felt-QA 디렉션. 배선
(GDScript) = 사용자/Codex. 아트(UI SFX, 크리스탈 회전 시트) = Claude 디렉션 + 생산.

레퍼런스 정밀 매칭 한계: 타임스탬프 Q&A(`gemini-youtube`)가 현재 MCP 모델 핀(retired
`gemini-3-pro-preview`) 404로 막힘. 요약만 가능. 미세 프레임 매칭이 필요하면 런처
`.claude/gemini_mcp_launcher.mjs` 모델 핀부터 갱신.

---

## 0. 현재 상태 (실측)

- **메뉴 이동 피드백 0.** `pause_menu_overlay._move_selection`(:613)은 인덱스만
  `(idx+delta)%count`로 변경 — 사운드·모션·팝 전무. 하이라이트가 순간이동.
- **UI 네비게이션 효과음 자체가 없음** (`game_audio.gd`에 menu/cursor/select/confirm
  사운드 없음). 포지셔널 패닝 시스템은 게임플레이 타격음 전용(별개).
- `_focus_pulse_alpha`(:1676) = 전역 호흡 펄스(`0.55+0.45*sin`)지 이동 순간 타격 아님.
- `animation_time`(:75)은 fade-in(`/0.12`)+펄스 공용 단일 타이머. 오버레이 자체 delta로
  진행(:143) → 게임 일시정지 중에도 돈다(셀렉션/크리스탈 타이머도 여기 태운다).
- 회전하는 메뉴 오브젝트 없음.

파일럿 = **일시정지 메뉴**(계속/캐릭터정보/옵션, 인덱스 nav 보유). 검증 후 옵션 메뉴
(`options_focus`)·타이틀로 전파.

---

## 1. ① 메뉴 이동 타격감 = 인덱스 변경 순간 3겹 피드백

체감 큰 순서.

### 1a. UI 효과음 (가장 큼)
- `game_audio.gd`에 신설: `play_ui_move()`(이동), `play_ui_confirm()`(확정),
  선택적 `play_ui_back()`(취소/뒤로). **중앙 패닝**(포지셔널 패닝 시스템과 무관).
- 사운드: 짧은 "틱"(40~80ms). 매 이동마다 **피치 ±소량 지터**로 로봇틱 방지.
- 발사: `_move_selection`/`_move_options_focus`에서 **실제 변경 시에만**, `_activate_*`에서
  confirm. 입력 리피트로 자연 레이트리밋되지만, 같은 인덱스 no-op은 발사 금지.

### 1b. 하이라이트 오버슈트 슬라이드 (시각 핵심)
- 선택 바/하이라이트가 순간이동 대신 이전→현재로 **~90ms 이즈 + 살짝 오버슈트**
  (back-out). `ease_out_back` 류.
- 상태: `_select_from_index`(이동 시 이전값 저장) + `_select_anim_t`(이동 시 0 리셋,
  매 틱 `+= delta`). 드로우에서 하이라이트 Y = `lerp(from_rect, to_rect, ease(t/DUR))`.
- **전역 `animation_time`에 얹지 말 것** — 전용 타이머.

### 1c. 선택 아이템 팝/플래시
- 새로 선택된 항목이 ~120ms 동안 **3~6% 스케일업 + 테두리 순간 밝아짐**(decay).
- premium 프레임 위에 짧은 글로우/밝은 보더로 얹음(`PremiumPanelFrame` + 펄스 알파).
- 엔벨로프: 빠른 상승-하강(sin 또는 `1-(1-t)^2` 류), `_select_anim_t` 기반.

**의도적 제외**: 화면 흔들림/카메라 셰이크. 레퍼런스의 "깔끔함"을 깨므로 넣지 않는다.

---

## 2. ② 왼쪽 천천히 회전하는 링코어 크리스탈 — ⚠️ 트랩 헤드라인

### 구현 경로 (텀블 트랩 회피)
pause 오버레이는 즉시모드 `_draw`(CanvasItem). **즉시모드 `draw_set_transform` 연속
회전 금지** — 비-1:1 쿼드를 ~10초면 대각선/수직으로 세운다(텀블 트랩; warning_scan·
헤드리스·t≈0 캡처 다 통과하고 늦게 깨짐).

권장 = **(나) 사전 베이크 회전 스프라이트 시트 루프**:
- 링코어 크리스탈을 360° 회전 베이크한 **24~36프레임 시트**(느린 회전 = 부드러움 위해
  16보다 많게). 런타임은 타이머로 현재 프레임 인덱스만 골라 `draw_texture_rect`.
  **변형 회전 없음 → 텀블 없음.** 즉시모드와 100% 호환.
- 프레임 진행: `_crystal_anim_t += delta`(오버레이 delta, 일시정지 중에도 돔),
  `frame = int(_crystal_anim_t * FPS) % FRAMES`. 느린 회전이므로 FPS 낮게(예: 12).
- **2.5D 평면 천장 트랩**: 평면 크리스탈 텍스처에 림/셰이더 얹어서는 "회전하는 3D"가
  안 됨(메모리 3차 검증). 시트는 **실제 3D-ish 렌더에서 베이크**해야 진짜 회전감.
- 대안 (나중에): 작은 3D SubViewport 오브젝트(`MeshInstance3D.rotation`) 또는 회전
  프로퍼티 Node2D 자식. 단 오버레이가 RefCounted 즉시드로우라 노드 호스팅은 더 침습적
  → 1차는 베이크 시트가 최단·최安.

### 레이아웃
- 레퍼런스는 "좌측 오브젝트 + 우측 메뉴" 분할. pause는 현재 중앙 버튼 스택.
- 1차: pause 패널을 **가로로 넓혀** 좌측에 크리스탈, 우측에 버튼 열 배치(커맨드 허브 느낌
  + 깔끔한 분할). 버튼 rect 계산(`_get_button_rect`)과 패널 폭 상수 동반 조정.
- 드로우 순서: 패널 fill → 크리스탈 → 버튼/텍스트(즉시모드 호출 순서로 z 결정). 크리스탈이
  버튼 텍스트를 가리지 않게 좌측 컬럼에 격리.

---

## 3. ③ 깔끔함
A+B premium 패널로 절반 완료. 추가 = 위 레이아웃 분할의 여백/정렬 일관성 + ①의 셰이크
배제(절제). 레퍼런스 톤(고대비 네온 최소, 넓은 여백) 유지.

---

## 4. 트랩 브리프 (배선 전 필독)
1. **회전 텀블** (헤드라인) — 베이크 시트(또는 노드/3D rotation), 즉시모드 연속
   `draw_set_transform` 금지. felt-QA는 **10초+** 지켜봐야 함(늦게 깨짐).
2. **2.5D 평면 천장** — 크리스탈 회전감은 실제 3D-ish 렌더 베이크에서만. 평면+셰이더 불가.
3. **전용 타이머** — `_select_anim_t`/`_crystal_anim_t`를 전역 `animation_time`에 얹지 말 것.
4. **변경 감지** — 실제 변경(랩 포함)에만 발사, no-op/`count<=0` 가드. `_move_selection`과
   `_move_options_focus` 양쪽.
5. **UI SFX 케이던스** — 중앙 패닝, 피치 지터, 포지셔널 패닝 시스템과 분리, move/confirm
   중복 발사 금지.
6. **절제** — 화면 셰이크 없음(깔끔함 보존).
7. **felt-QA 우선** — 오버슈트/팝/회전속도는 인게임 체감으로 튠(숫자로 확정 말 것).
8. **일시정지 중 진행** — 오버레이는 게임 멈춰도 자체 delta로 갱신(:143). 셀렉션·크리스탈
   타이머가 거기서 도는지 확인.

---

## 5. 봉인 (스모크) + 사인오프
체감은 단위테스트 불가. 테스트 가능한 것:
- `_move_selection` 실제 변경 시 `_select_anim_t==0` 리셋 + `_select_from_index` 기록
  (반증검증: 변경인데 리셋 안 하면 FAIL).
- UI move SFX는 변경 1회당 1회, no-op 시 0회(가짜 audio로 호출 카운트).
- 크리스탈 프레임 인덱스가 타이머로 진행 + 범위 내 랩(out-of-range 없음).
- 회전 경로에 즉시모드 연속 `draw_set_transform`이 **없음**(소스 가드 어서션).
**진짜 사인오프 = felt-QA**: 인게임에서 이동 타격감 체감 + 크리스탈 10초+ 회전 무결.

---

## 6. 터치 파일 (배선 체크리스트)
- `godot/scripts/hud/pause_menu_overlay.gd` — 셀렉션 상태/타이머, `_move_*` SFX+리셋,
  드로우(오버슈트 슬라이드 + 팝), 레이아웃 분할, 크리스탈 드로우.
- `godot/scripts/audio/game_audio.gd` — `play_ui_move`/`play_ui_confirm`(+back) 신설.
- 신규 아트: UI move/confirm SFX(짧은 틱), 링코어 크리스탈 회전 시트(24~36프레임,
  3D-ish 베이크). 경로/네이밍은 아트 단계에서.
- 신규 스모크 `pause_menu_juice_smoke.gd`(§5).
- 전파(후속): 옵션 메뉴(`options_focus`)·타이틀로 SFX+셀렉션 피드백.

## 7. 튜닝 레버
- SFX 피치 지터 폭, 슬라이드 DUR(~90ms)+오버슈트 강도, 팝 진폭(3~6%)/지속(~120ms),
  크리스탈 회전 FPS(~12)/프레임수, 패널 분할 폭.

---

## S1.5 — 마우스/키보드 입력 패리티 (호버 + 클릭/뒤로)

상태(2026-06-25, 실측): S1은 키보드/패드(`_move_selection`/`_move_options_focus`)에만
피드백. 마우스 경로엔 타격감 0 — `_handle_mouse_motion`(:484)은 슬라이더 드래그만,
`_handle_mouse_button`(:461)의 메인 클릭은 `_activate_entry` 직접 호출(confirm 무음),
우클릭 닫기·옵션 탭/뒤로 클릭도 무음. 목표 = **마우스 입력이 키보드와 동일 타격감**.
범위 결정 = **풀 패리티**(호버 + 클릭 + 뒤로).

### S1.5-A 호버 진입 피드백
키보드 이동과 **동일 경로 공유**: 호버 진입 = selected 갱신 + `_begin_selection_feedback`
+ `play_ui_move`. 슬라이드/팝은 기존 `_draw_selection_feedback`가 그대로 렌더.

신규 상태: `var _last_hover_scope := ""`, `var _last_hover_index := -1`.
open()/close()/open_options()/탭전환에서 `_last_hover_index=-1, _last_hover_scope=""` 리셋.

신규 헬퍼 `_hovered_index_at(panel_rect, scope, pos) -> int`:
- 호버 대상 rect는 **피드백이 그리는 rect와 동일**해야 함 — `_get_selection_feedback_rect(
  panel_rect, scope, i)`를 i에 대해 순회하며 `has_point(pos)` → 인덱스, 없으면 -1.
- 메인은 `SELECTION_SCOPE_MAIN`+entries 수, 옵션은 `_get_options_feedback_scope()`+탭별 focus 수.
- **panel_rect는 해당 `_draw_*`가 쓰는 getter와 동일**(메인=`_get_active_panel_rect`,
  옵션=`_get_options_panel_rect`).

`_handle_mouse_motion`에 호버 처리 추가(드래그 분기 이후):
```gdscript
func _update_hover_feedback(pos, registry, view_size) -> void:
    var scope := SELECTION_SCOPE_MAIN if not options_open else _get_options_feedback_scope()
    var panel_rect := (_get_options_panel_rect(view_size) if options_open else _get_active_panel_rect(view_size))
    var hovered := _hovered_index_at(panel_rect, scope, pos)
    if scope == _last_hover_scope and hovered == _last_hover_index:
        return                       # Gate1: 마우스가 새 칸으로 "건너갔을" 때만
    _last_hover_scope = scope
    _last_hover_index = hovered
    if hovered < 0:
        return                       # 빈 영역 = 무발동(_last_hover=-1, 재진입 시 발동)
    var current := selected_index if scope == SELECTION_SCOPE_MAIN else options_focus
    if hovered == current:
        return                       # Gate2: 이미 선택된 칸이면 재팝 안 함
    if scope == SELECTION_SCOPE_MAIN: selected_index = hovered
    else: options_focus = hovered
    _begin_selection_feedback(scope, current, hovered)
    _play_ui_move(registry)
```

### S1.5-B 클릭/뒤로 패리티
- 메인 좌클릭(`_handle_mouse_button` :476~480): `selected_index=index` 후
  `_activate_selected(owner, registry)` 경유(= `play_ui_confirm` + 활성화). 현재 직접
  `_activate_entry` 호출을 교체.
- 우클릭 닫기(:465~469): `close()`/`_close_options_page()` 직전 `_play_ui_back(registry)`.
- 옵션 클릭(`_handle_options_click` + 하위): 탭 전환·값 설정(디스플레이 모드/토글/리셋) →
  `_play_ui_confirm`, 뒤로/닫기 → `_play_ui_back`. 슬라이더 grab은 move 1회(드래그 틱마다
  발사 금지).

### S1.5 트랩
1. **`_last_hover_index`를 selected와 분리(엣지=마우스 건너감)** — selected와 직접 비교하면
   item2 정지 마우스가 키보드 item3 이동 후 미세 지터로 호버를 재발동해 **키보드를 잡아먹음**.
   모션-추적 `_last_hover`면 정지 지터는 `hovered==_last_hover`라 무발동. (per-frame 엣지 트랩.)
2. **`_draw` 부작용 금지** — 호버 발동은 `_handle_mouse_motion`에서만(드로우 순수).
3. **오픈/탭전환 `_last_hover` 리셋** — 오픈 순간 스푸리어스 발동 방지.
4. **히트테스트 rect == 피드백/드로우 rect** — 같은 panel-rect getter + 같은 `_get_*_rect`.
5. **클릭 패리티 중복 발사 금지** — 모션과 클릭은 별 이벤트(클릭이 move도 같이 쏘지 않게).
6. **슬라이더 드래그** — 틱마다 move 금지.

### S1.5 봉인 (pause_menu_overlay_smoke 확장; 가짜 마우스 모션/버튼 이벤트)
- 비선택 메인 칸으로 모션 → selected 갱신 + 타이머 리셋 + `ui_move`+1.
- 같은 칸 내 모션(같은 hovered) → `ui_move`+0.
- **anti-fight**: 키보드로 selected 이동(마우스 정지) 후 같은-위치 모션 → `ui_move`+0
  (반증검증: `_last_hover`를 selected와 합치면 FAIL).
- 이미 선택된 칸으로 모션 → `ui_move`+0(Gate2).
- 좌클릭 → `ui_confirm`+1 + handled, 우클릭 → `ui_back`+1 + 닫힘.
- 옵션 행 모션 → scope=options `ui_move`+1, 탭 클릭 → confirm, 뒤로 클릭 → back.

### S1.5 터치 파일
- `pause_menu_overlay.gd`(상태 2종 + `_update_hover_feedback` + `_hovered_index_at` +
  `_handle_mouse_motion`/`_handle_mouse_button`/`_handle_options_click` SFX).
- `pause_menu_overlay_smoke.gd`(마우스 호버/클릭 어서션 + 모션 헬퍼).

---

## Slice D — 밝은 에디토리얼 재스킨 (레퍼런스 충실)

상태(2026-06-27): S1/S1.5/S2/S3 커밋 완료(다크 네온 HUD). 사용자가 실제 레퍼런스
스크린샷(YouTube JjbRQhdUCQk "SYSTEM" 메뉴)을 제시 → ③ "깔끔함"의 의도가 **다크 글로우
HUD가 아니라 밝은 에디토리얼 레이아웃**임이 확인됨. 방향 결정 = **레퍼런스 충실(밝은
에디토리얼)**. 인터랙션 로직(슬라이드·팝·SFX·마우스 패리티)은 스킨 무관하게 그대로
재사용; 바뀌는 것은 **스킨(다크→밝음) + 레이아웃(중앙 버튼 카드→좌측 큰 바 + ✦ 스파인)
+ 구성(에디토리얼)**.

### D-목표 비주얼 (레퍼런스 실측)
- **밝은 테마**: near-white 종이 배경, **검은 텍스트**, 소프트 코른플라워 블루 선택 바.
- **좌측 정렬 리스트**(중앙 아님). **선택 = 화면 왼쪽 끝까지 빠지는 큰 블루 바**(우측 라운드
  캡) + 거대 EN 라벨 + KR 듀얼 라벨. **비선택 = ✦ 다이아 + 중간 EN 텍스트**, 세로 스파인 연결.
- 좌상단 **블랙 그래픽 웨지 + 흰 라인아트**, 우상단 **얇은 원형 다이얼(천천히 회전)**,
  큰 스위핑 커브, ✦ 코너 액센트.

### D-범위 (스코프)
- **이 슬라이스 = 일시정지 MAIN 메뉴 루트만**(레퍼런스 스크린샷에 해당하는 히어로 화면).
- 옵션 하위 페이지(sound/display/controls/language)는 밀집 폼이라 **별도 후속 D-options**.
  밝은 메인 → 다크 옵션 = 톤 휘플래시이므로 **머지 전 D-options를 fast-follow**로 처리 권장.
- **인배틀 다크 HUD·캐릭터정보 오버레이는 재스킨 안 함**(다크 프리미엄 패널 A+B 유지) →
  밝은 토큰은 **신규 상수로 분리**, 기존 다크 토큰 mutate 금지(스킨 격리).
- 레이아웃이 **풀-뷰 에디토리얼**로 바뀜 → `_get_main_panel_rect`가 중앙 580×320 카드가
  아니라 거의 풀 view rect를 반환. 종이 배경이 배틀을 덮음(시스템 레이어; 배틀은 그 아래로
  거의 안 보이게 — 모달/일시정지 로직은 불변, 비주얼만).

### D-신규 토큰 (밝은; 값은 픽셀 QA로 튠)
```gdscript
const PAPER_BG       := Color(0.93, 0.94, 0.96)   # near-white 종이
const INK            := Color(0.10, 0.12, 0.16)   # 본문 검은 텍스트
const INK_DIM        := Color(0.42, 0.45, 0.52)   # 하위 행 그레이
const SELECT_BLUE    := Color(0.49, 0.71, 0.90)   # 선택 바(코른플라워)
const SELECT_SUBINK  := Color(0.10, 0.16, 0.24)   # 바 위 KR 듀얼 라벨(다크-온-블루)
const GRAPHIC_INK    := Color(0.07, 0.08, 0.10)   # 좌상단 웨지 블랙
const DIAMOND_GRAY   := Color(0.55, 0.60, 0.68)   # ✦ 불릿
const SPINE_LINE     := Color(0.0, 0.0, 0.0, 0.12)# 세로 스파인
```

### D-레이아웃 + 선택 바
- 풀-뷰. 좌측 마진 `LM`(~90px). 리스트 시작 `start_y`(~view*0.40), 행 피치 `ROW_PITCH`(~96px).
- **행 밴드 rect** `_get_main_row_band_rect(view, i)` = `Rect2(0, start_y+i*ROW_PITCH, view.x*0.62, ROW_PITCH)`
  (x=0 → 왼쪽 끝까지). **이 밴드가 곧 `_get_selection_feedback_rect(MAIN, i)`**(→ S1.5 호버/클릭
  히트존 그대로 재사용, 변경 0).
- **선택 행** → 밴드 안쪽에 **블루 바**(높이 ~BAR_H 110, 우측 라운드 캡) 그림 + EN 라벨
  (FONT_TECH ~60px, 흰색, LM 좌패딩) + KR 듀얼 라벨(FONT_BODY ~26px, `SELECT_SUBINK`,
  바 우측 정렬 우패딩).
- **비선택 행** → `✦`(draw_colored_polygon 다이아) `DIAMOND_GRAY` + EN 모티프 텍스트
  (FONT_TECH ~30px, `INK`/하단으로 갈수록 `INK_DIM` 미세 페이드). 다이아들 관통 세로 스파인.

### D-EN/KR 듀얼 라벨 (entries 확장)
`_get_main_entries()` 각 항목에 `"en"` 모티프 추가, 기존 `"label"`은 로컬라이즈 유지:
| action | en (대형, 고정 모티프) | label (소형, 로컬라이즈) |
|---|---|---|
| continue | `RESUME` | `_text("pause.continue")` |
| character_info | `STATUS` | `_text("pause.character_info")` |
| options | `SETTINGS` | `_text("pause.options")` |
- 비선택 행은 **EN 모티프만**(레퍼런스의 SAVE/TUTORIALS… 처럼). 선택 바만 EN 대형 + 로컬 소형.
- EN 로케일에선 대형 EN과 소형 로컬이 중복 → **소형 숨김 또는 짧은 디스크립터**(아래 D-오픈결정).

### D-배경 액센트 (D1 = 절차적, 신규 비트맵 0)
- 풀-뷰 `PAPER_BG` fill(배틀 덮음).
- 좌상단 **블랙 웨지**: `draw_colored_polygon`(단순 볼록 → triangulable) + 흰 라인아트 곡선
  (`draw_polyline`/`draw_arc`).
- 큰 **스위핑 커브**: `draw_arc` 라이트 그레이(폴리곤 fill 아님 → degenerate 회피).
- 우상단 **얇은 원형 다이얼**: 원 outline(`draw_arc`) + **니들 라인** — 각도를 매 프레임
  진행시키되 **엔드포인트를 각도로 재계산해 `draw_line`**(텍스처 쿼드 회전 아님 → 텀블 면역).
  이게 레퍼런스의 "천천히 회전" 비트를 충족.
- ✦ 코너 스파클(`draw_colored_polygon` 다이아).
- (D2 옵션·후속·내 영역) 맵 일러스트 등 **bespoke 에디토리얼 배경**은 imagegen으로 나중에.

### D-크리스탈 처리 (권장)
레퍼런스 SYSTEM 화면 좌측 = 타이틀 + 블랙 웨지, **크리스탈 없음**. 커밋된 다크 faceted
크리스탈은 밝은 에디토리얼과 충돌. **권장 = 일시정지 메인에서 크리스탈 제거**(다크-모드
전용이던 `_uses_main_split_layout` 크리스탈 분기 은퇴), 자산은 **향후 캐릭터정보 화면**
(영상의 "좌측 회전 오브젝트"는 캐릭터 화면이었음)용으로 보존. 밝은 레이아웃의 "회전" 비트는
**우상단 절차적 다이얼**이 담당. (사용자 veto 가능 — D-오픈결정.)

### D-선택 타격감 재사용 (핵심)
- 슬라이드/팝 수식을 `_draw_selection_feedback`에서 **`_get_animated_selection_rect(scope,
  panel_rect) -> Rect2`** 헬퍼로 추출 → 밝은 바가 이 rect를 그대로 사용(이전→현재 밴드
  사이 `ease_out_back` 슬라이드 + 팝).
- 밝은 모드에선 **옛 시안 오버레이 프레임(`_draw_selection_feedback`)을 그리지 않음** — 바
  자체가 인디케이터. `_draw_main_menu`가 애니메이트된 밴드에 바+듀얼라벨 + 나머지 ✦행을 그림.
- `_selection_slide_time`/`_pop_time`/`_play_ui_move`/S1.5 호버·클릭 = 변경 없이 동작
  (히트존=밴드=피드백 rect 동일성 유지).

### D-트랩 (배선 전 필독)
1. **텀블 트랩** — 회전 다이얼은 니들 엔드포인트 각도 재계산 `draw_line`, `draw_set_transform`
   연속회전 금지. S3 소스-스캔 스모크(`draw_set_transform` 부재)가 계속 가드.
2. **degenerate polygon** — 웨지/스파클 등 폴리곤 fill은 볼록·nonzero area(triangulable);
   곡선은 `draw_arc`(폴리곤 fill 아님)로.
3. **로컬라이즈 + CJK** — 소형 라벨은 `_text()` 경유, 日/中은 fallback_font 경로 필요
   (명시 Nanum=CJK 드롭 트랩). 대형 EN은 FONT_TECH(라틴 보유). 한글 하드코딩 금지.
4. **스킨 격리** — 밝은 토큰은 신규 상수. 다크 토큰·프리미엄 패널은 인배틀 HUD/캐릭터정보가
   계속 쓰므로 mutate/제거 금지. 밝음은 pause 메인(+후속 옵션)에만.
5. **히트존=밴드=피드백 rect** — `_get_selection_feedback_rect(MAIN,i)`=밴드 반환, 바는 그
   안쪽 inset로만 그림(선택행만). 그래야 S1.5 호버/클릭이 그대로 동작.
6. **풀-뷰 종이가 배틀을 덮음** — 가장자리 배틀 누출 없게 풀 view fill. `_get_main_panel_rect`
   풀-뷰화에 따른 옵션 패널·모든 히트 rect 재검(중앙 카드 가정 잔재 제거).
7. **옵션 휘플래시** — 밝은 메인↔다크 옵션 톤 충돌 → D-options를 머지 전 처리(또는 명시 인지).
8. **대비** — `INK`-on-`PAPER_BG`(다크-온-라이트) OK; KR 소형 라벨 다크-온-`SELECT_BLUE` 대비
   픽셀 확인.

### D-봉인 (pause_menu_overlay_smoke 확장 + 반증검증)
- 밝은 토큰 존재·다크와 구분(`PAPER_BG.r > 0.8`, `INK.r < 0.2`).
- **선택 행만 바**: 선택 행 바 rect 폭 ≥ 0.5*view.x & x≈0(좌측 끝); 비선택 행엔 바 없음
  (바는 화면당 1개). **반증검증: 모든 행에 바 그리면 FAIL**.
- entries에 `"en"` 키 존재 + 선택 바가 EN 대형 + 로컬 소형 둘 다 그림.
- 선택 슬라이드가 **행 밴드 사이** 이동(S1.5 슬라이드 어서션이 밴드로 동작).
- S1.5 호버/클릭이 새 밴드 rect로 그대로 통과(회귀 없음).
- 다이얼: `draw_set_transform` 부재(S3 소스스캔 유지) + 다이얼 각도 update서 진행(옵션).
- **크리스탈 미표시**: 밝은 메인에서 크리스탈 분기 은퇴(또는 게이트 off) 어서션.

### D-터치 파일
- `pause_menu_overlay.gd` — 밝은 토큰, 풀-뷰 레이아웃 getter(`_get_main_panel_rect` 풀뷰·
  `_get_main_row_band_rect`), `_draw_main_menu` 재작성(바+듀얼라벨+✦행), `_get_animated_
  selection_rect` 추출, entries `"en"`, 다이얼/웨지/스파인 절차 드로우, 크리스탈 분기 은퇴.
- `pause_menu_overlay_smoke.gd` — 밝은 어서션 + 반증검증.
- (후속) D-options: 옵션 하위 페이지 밝은 재스킨. (옵션) D2: bespoke 에디토리얼 배경 art(imagegen, 내 영역).

### D-튜닝 레버
바 높이/폭%(0.62), `SELECT_BLUE` 색조, `ROW_PITCH`/`start_y`/`LM`, EN/KR 폰트 크기,
다이얼 회전 속도, 종이 불투명도(배틀 위), ✦ 크기.

### D-오픈 결정 (사용자 확인; 기본값 적용해 진행 가능)
1. **크리스탈** — 권장: 밝은 메인서 제거 + 향후 캐릭터정보 화면 보존, 회전 비트는 다이얼. (기본)
2. **EN 모티프 우선** — 권장: EN 대형 + 로컬 소형(레퍼런스 충실). EN 로케일 소형=숨김/디스크립터. (확인)
3. **배경 art** — D1 절차적 액센트로 먼저, bespoke 일러스트는 D2 후속. (기본 위상화)
4. **옵션 페이지** — D-options를 머지 전 fast-follow. (시퀀싱)

### D-레퍼런스 영상 실측 보정 (2026-06-27, 프레임 추출 분석)
실제 영상(`...JjbRQhdUCQk_001_1080p.mp4`, 1920×1080@60, 19.4s)을 ffmpeg로 프레임 추출해
직접 분석 → 위 설계의 기본 골격은 맞았으나 아래 디테일을 **보정**한다(프레임: `d:/tmp/ref_video_frames/`).
영상 화면 흐름: 타이틀(벚꽃 건물) → COMMAND(캐릭터 메뉴) → SYSTEM → SETTINGS(슬라이드) →
SETTINGS 하위(우측정렬·검은 바) → 복귀.

1. **선택 바 = 비스듬한 평행사변형(slanted parallelogram), NOT 라운드 사각형.** 좌/우 모서리가
   구성의 대각선을 따라 기울어진다(완만, ~10–15°). 좌측 화면 끝까지 블리드 + 우측에 가는 슬랜트
   "tail" 세그먼트. COMMAND 화면에선 바가 더 가파른 대각선. → 바를 `draw_colored_polygon`
   평행사변형(좌하/좌상/우상/우하 4점 + slant offset)으로 그리고, 우측 라운드 캡 대신 슬랜트 컷.
   slant 각도는 단일 상수 레버.
2. **KR 듀얼 라벨 = 번역 아니라 "설명문".** 게임 저장/튜토리얼 확인/진행된 이야기 열람/게임 설정 및
   변경/전투원 목록 확인. 우리 매핑: RESUME/`게임으로 돌아가기`, STATUS/`캐릭터 정보 확인`,
   SETTINGS/`게임 설정 및 변경`. 바 우측 정렬, `SELECT_SUBINK` 다크.
3. **선택 바 색이 메뉴 깊이별로 다름**: 최상위(LOAD/SETTINGS/SUBORDINATES)=`SELECT_BLUE`,
   깊은 하위(GRAPHIC SETTINGS)=검정 바 + 흰 텍스트. → 바 색을 메뉴 레벨 파라미터로(D-options 때 적용).
4. **정렬이 화면별로 뒤집힘**: 상위 메뉴=좌측 정렬(✦ 왼쪽), SETTINGS 하위=우측 정렬(✦ 오른쪽,
   바도 우측 블리드). pause 메인은 좌측, D-options는 우측 미러 고려.
5. **항목이 완만한 아크를 따라 배치될 수 있음**(COMMAND 화면). pause 메인은 단순 수직으로 시작,
   아크는 D2/후속 선택 사항.
6. **회전 오브젝트 = 우상단 솔리드 블랙 각진 컴퍼스-별**(원 outline + 별/화살 + 작은 dot),
   ~3초에 확연히 회전. **솔리드 도형이므로 `draw_line` 니들로는 부족** — 폴리곤 정점을 각도로
   **코드 재계산**해 `draw_colored_polygon`(별은 non-convex → `Geometry2D.triangulate_polygon`
   또는 중심-부채꼴 삼각형 분해), `draw_set_transform` 연속회전 금지(텀블). 또는 작은 회전 시트
   베이크. **"왼쪽 회전 오브젝트"는 오해** — 영상 좌측은 COMMAND 화면의 정적 캐릭터 실루엣(Lv/돈),
   회전체는 우상단. → 크리스탈을 캐릭터정보 화면에 두자는 권장과 정합(거긴 캐릭터 실루엣 자리).
7. **전체 대각선 주도 구성**: 큰 스위핑 대각선 디바이더가 화면을 가르고, 바·타이포(이탤릭 느낌)·
   웨지가 모두 그 대각선에 정렬. 단순 수평 레이아웃이면 레퍼런스 느낌이 안 남 → 디바이더 각도를
   단일 상수로 두고 바 slant·타이포 이탤릭을 거기 맞춤.
8. **전환 속도**: 8fps 추출에 중간 슬라이드 프레임이 거의 안 잡힘 = 슬라이드 <125ms(빠름/스내피).
   우리 `SELECTION_SLIDE_DURATION=0.09`(90ms)와 동급 → 그대로 둠.
9. **선택 행만 바, ✦ 사라짐**: 선택된 행은 ✦ 없이 바, 비선택은 ✦+EN텍스트. 바는 선택 행 위치로
   슬라이드(리스트 고정, 바가 이동) — 우리 "피드백 rect=행 밴드, 바 슬라이드" 모델과 일치.

### D2 — 배경 아트 배선 핸드오프 (자산 준비 완료, 2026-06-27)
자산(Claude, Gemini gemini-generate-image, 사용자 v1 미감 합격) 준비 끝, **배선=Codex**:
- **자산**: `godot/assets/ui/pause_menu/pause_system_editorial_map_bg_gemini_v1.png`
  (2048×1143, 희미한 모노크롬 에디토리얼 도시지도, off-white=PAPER_BG) + export-safe `.import`(생성됨)
  + `..._manifest.json`(프로비넌스). 미리보기/합성=`d:/tmp/bosspong_ui_panel_capture/pause_slice_d/`.
- **로드**: 모든 활성화 진입점에서 prewarm(텍스처 1회 로드+캐시, 핫패스 lazy init 금지) —
  `open()`뿐 아니라 **메인메뉴 설정 직행 `open_options()`도 별도 진입점**이다(2026-07-02 코덱스
  리뷰: open_options가 prewarm을 빼먹어 첫 draw 프레임에 2.4MB PNG 로드 → 수정+스모크 봉인
  "open_options direct entry should prewarm"). 오버레이에 새 활성화 진입점을 추가하면 prewarm
  호출을 함께 복제할 것. 크리스탈이 16962f5df에서
  쓰던 `prewarm_assets()`/`_load_*_texture()` + `ProjectResourceLoader.load_texture` 패턴 재도입
  (크리스탈 제거 때 같이 지워졌으므로 되살림). **`.import` 누락 export-무음 트랩 주의** — 이미 생성해 뒀고
  반드시 PNG와 함께 커밋.
- **드로우**: `_draw_main_editorial_background` 맨 처음에 이 텍스처를 **풀 view rect로 그려 base로**
  (현재의 `canvas.draw_rect(panel_rect, PAPER_BG)` 단색 fill + 절차적 `_draw_main_map_texture()`를
  **대체**). 풀뷰 stretch면 16:9→16:10 ~11% 세로 늘림(faint 맵이라 비가시) 또는 cover-fit by height.
  텍스처 null이면 기존 PAPER_BG fill 폴백.
- **위에 그대로 유지(절차)**: 블랙 웨지 + 흰 라인아트, 우상단 회전 컴퍼스-별, 스큐 블루 바, ✦ 스파인,
  스파클, 타이틀. **절차적 스위핑 아크(`draw_arc` 0.075α)는 제거 또는 약화** — 이미지에 아크가 들어
  있어 중복되므로(겹치면 둘 다 보임).
- **봉인**: 스모크에 (a) 배경 텍스처 경로 상수 존재 + open() 후 로드(non-null), (b) `_draw_main_map_texture`
  절차 호출 제거(소스 스캔) 또는 텍스처-우선 그림 어서션, (c) export-safe `.import` 동반 커밋.
- **사인오프**: 배선 후 **실 인게임 재캡처**(throwaway `godot/tools/pause_menu_editorial_capture.gd`
  재실행)로 픽셀 확인 — Claude가 multiply 합성 아닌 진짜 레이어 결과를 검수.
- **커밋 위생**: D2 커밋은 pause 2파일(있으면) + bg 3자산(png/.import/manifest)만. `godot --import`가
  생성한 **타 untracked WIP .import**(Lingpet 폰트·fan/starmoving/whipcrack.wav·stage6 스프라이트)는
  Slice D 무관 → 절대 같이 담지 말 것.
  **상태: 커밋 `170ceacf9` "Restyle pause menu with editorial background" (5파일, 검증 완료).**

### D3 — 메뉴 카피/앵커 폴리시 (설계, 배선=Codex)
사용자 결정(2026-06-27): **풀 설명문**. D2가 레퍼런스 구조까지 올라왔으니 짧은 라벨이 "게임 UI스럽게"
남는 갭을 닫는다. 항목 3개라 다국어 부담 작음, 번역 품질은 **검수-필요 플래그**로 관리.

**① EN 좌앵커** (사소): `_draw_main_selected_bar`의 EN 라벨 x를 중앙(`bar.size.x*0.43/0.50`)에서
좌앵커로 — `bar.position.x + 좌패딩`(skew 고려, 예: skew+~64)에서 시작, KR 우측 라벨 시작점 전까지
클램프(겹침 방지). 신규 상수 `MAIN_BAR_EN_LEFT_PAD` 레버.

**② KR 보조 = 설명문 키**:
- entries에 `"desc": _text("pause.X.desc")` 추가, `_draw_main_selected_bar` 보조 라벨을
  `entry["label"]`(짧은) → `entry["desc"]`로 교체. 짧은 `label`은 보조에서 미사용(라우팅=`action`).
- 새 키 3종 × **7언어 모두 non-empty**(EN 로케일은 숨기지만 missing-key 방지 위해 EN도 채움).
  `_should_show_main_local_label()`로 EN 숨김 유지.
- **CJK(ZH/JA) 보조는 `_get_text_draw_font` fallback 경로로 렌더**(명시 Nanum=CJK 드롭 트랩) —
  코드는 이미 처리, ZH/JA 화면 QA 시 글리프 확인.

**설명문 카피** (KO=design-owner 확정 / EN=확신 / ZH·JA·ES·PT-BR·RU=초안, **번역 검수 필요**):

| key | KO ✓ | EN | ZH | JA | ES | PT-BR | RU |
|---|---|---|---|---|---|---|---|
| `pause.continue.desc` | 게임으로 돌아가기 | Return to game | 返回游戏 | ゲームに戻る | Volver al juego | Voltar ao jogo | Вернуться в игру |
| `pause.character_info.desc` | 캐릭터 정보 확인 | View character info | 查看角色信息 | キャラクター情報を確認 | Ver info del personaje | Ver info do personagem | Информация о персонаже |
| `pause.options.desc` | 게임 설정 변경 | Game settings | 游戏设置 | ゲーム設定 | Ajustes del juego | Configurações do jogo | Настройки игры |

**봉인** (pause_menu_overlay_smoke + 가능하면 language_settings coverage): 새 키 3종 7언어 존재·non-empty ·
KO 문구 일치 · EN 로케일 보조 숨김(`_should_show_main_local_label()`==false) · non-EN 보조 표시 + `desc` 사용 ·
EN 라벨 좌앵커(EN draw x가 바 중앙보다 왼쪽, 좌패딩 근처).

**터치 파일**: `language_settings_data.gd`(7언어 × 3키), `pause_menu_overlay.gd`(entries `desc` + 바 EN
좌앵커/보조 `desc`), `pause_menu_overlay_smoke.gd`. **커밋 위생**: D3 = 이 3파일만(D2 자산은 이미 170ceacf9).
이후 **D-options 밝은 재스킨**(밝은 메인↔다크 옵션 휘플래시 해소).
