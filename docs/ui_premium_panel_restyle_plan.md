# UI 패널/테두리 프리미엄 리스타일 — 정제된 네온 HUD

단일 소스 설계서. 방향 결정: **정제된 네온 HUD** (지금 시안 SF 톤 유지 +
라운드 모서리 + 부드러운 그림자 + 레이어 글로우 + 코너 브래킷).

분담: Claude = 디자인 + 신호계약 + 트랩 브리프 + 적대적 리뷰. 배선(GDScript) =
사용자 직접(기본). 원하면 슬라이스 A 코어만 Claude 배선 가능.

---

## 0. 진단 (왜 "투박/네모"한가)

지금 모든 패널/슬롯은 **단색 1줄 외곽선 + 직각 모서리**뿐이라 "그냥 네모 칸"으로
읽힌다. 깊이(그림자)·둥글림·글로우가 전부 없다.

- **캐릭터 정보 패널이 가장 투박.** `character_info_overlay_texture_drawer.gd:11`
  `draw_panel`이 `draw_rect(fill)` + `draw_rect(border, false, w)` 두 줄뿐.
  메인 패널(3px)·섹션 7개(2px)·전 슬롯/셀이 전부 이걸 쓴다 → 90° 직각, 평면 단색.
- **일시정지 메뉴는 이미 한 단계 위.** `pause_menu_overlay.gd:1612` `_draw_panel`에
  글로우(3x/2x 헤일로)·이중선·코너 브래킷(`_draw_holo_focus_frame`)·스캔라인이 있다.
  그래도 **모서리가 직각**이라 여전히 각져 보인다.
- **둥근 모서리 선례가 이미 리포에 존재.** `stage_clear_result_shape_helper.gd:130`
  `draw_panel`이 `StyleBoxFlat`(corner_radius + border)를 쓴다. 기술적 길은 이미 있고,
  문제는 오버레이마다 손으로 `draw_rect`를 그려 통일이 안 된 것.

핵심 한 방: `StyleBoxFlat`는 `draw_style_box` **한 번**으로 라운드 모서리 + 테두리 +
부드러운 드롭섀도(`shadow_size`/`shadow_color`/`shadow_offset`)를 다 처리한다. 거기에
코너 브래킷/네온 액센트만 위에 얹으면 끝.

---

## 1. 공용 헬퍼 (신호계약)

신규: `godot/scripts/hud/premium_panel_frame.gd`
(`class_name PremiumPanelFrame extends RefCounted`, 전부 static).

### 1.1 지오메트리 종류 (geometry kind)

| kind      | radius | border_w | shadow | 글로우 헤일로 | 대상 |
|-----------|:------:|:--------:|:------:|:------------:|------|
| `MAIN`    | 12     | 3        | O (size 10, a 0.38, off (0,5)) | O (라운드 1패스) | 메인 패널 |
| `SECTION` | 8      | 2        | O (size 6, a 0.30, off (0,3))  | X | 섹션 박스 7개 |
| `SLOT`    | 6      | 가변(1.4~2.0) | X | X | 장비/스킬/액티브 슬롯 |
| `CELL`    | 4      | 가변(1~2)     | X | X | 퍽/패시브 그리드 셀 |

이유: **컨테이너(MAIN/SECTION)만 풀 트리트먼트**, 슬롯/셀은 라운드만(+기존 hover 브래킷).
셀은 수십 개라 그림자/글로우/브래킷을 다 넣으면 draw-call 폭발 + 시각 노이즈.

### 1.2 API

```gdscript
# 컨테이너/슬롯/셀 패널. 색은 호출마다 바뀔 수 있으니 인자로 받음.
static func draw_panel(canvas: CanvasItem, rect: Rect2, kind: int,
        fill: Color, border: Color, border_width: float = -1.0) -> void

# hover/selected 코너 브래킷(일시정지 _draw_holo_focus_frame 일반화).
static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2,
        color: Color, pulse_alpha: float = 1.0) -> void
```

### 1.3 제로 할당 캐시 (가장 중요한 구현 규칙)

`StyleBoxFlat`는 **rect를 굽지 않고** `draw_style_box(box, rect)` 호출 시점에 즉시
그린다. 따라서 **지오메트리별 단 1개의 mutable StyleBoxFlat 인스턴스를 1회 생성·재사용**
하고, draw 전에 `.bg_color`/`.border_color`만 갈아끼우면 임의 색을 0 할당으로 처리한다.

```gdscript
static var _box_main: StyleBoxFlat
static var _box_section: StyleBoxFlat
static var _box_slot: StyleBoxFlat
static var _box_cell: StyleBoxFlat

static func _ensure() -> void:
    if _box_main != null:
        return
    _box_main = _make(12, 3, true, 10.0, Color(0,0,0,0.38), Vector2(0,5))
    _box_section = _make(8, 2, true, 6.0, Color(0,0,0,0.30), Vector2(0,3))
    _box_slot = _make(6, 2, false, 0.0, Color.TRANSPARENT, Vector2.ZERO)
    _box_cell = _make(4, 1, false, 0.0, Color.TRANSPARENT, Vector2.ZERO)

static func _make(radius:int, bw:int, shadow:bool, ssize:float, scol:Color, soff:Vector2) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.anti_aliasing = true          # ← 없으면 라운드가 들쭉날쭉해서 더 싸 보임 (필수)
    s.corner_detail = 6
    s.corner_radius_top_left = radius; s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius; s.corner_radius_bottom_right = radius
    s.border_width_left = bw; s.border_width_top = bw
    s.border_width_right = bw; s.border_width_bottom = bw
    if shadow:
        s.shadow_size = int(ssize); s.shadow_color = scol; s.shadow_offset = soff
    return s
```

`draw_panel`은 `_ensure()` → kind로 박스 선택 → `box.bg_color = fill` /
`box.border_color = border` (필요시 `border_width_* = int(round(border_width))`) →
`canvas.draw_style_box(box, rect)`. MAIN은 그 직전에 라운드 헤일로 1패스(테두리 전용
StyleBox를 `rect.grow(+w)`에 저알파로) 먼저 그려 글로우를 뒤에 깐다.

draw는 단일 스레드·순차이므로 인스턴스 재사용 + 즉시 mutate에 재진입 위험 없음.

---

## 2. 슬라이스 (배선 백본)

### 슬라이스 A — 코어 헬퍼 + 캐릭터 정보 (위험 최저, 효과 최대)
1. `premium_panel_frame.gd` 추가 (§1).
2. `character_info_overlay_texture_drawer.gd:11` `draw_panel`을 헬퍼 경유로:
   - 메인 패널 호출(`frame_presenter.gd:58`, `draw_panel(..., 3.0)`) → `kind=MAIN`.
   - 섹션 박스 7개(`character_info_overlay_core.gd:206/261/310/356/422/484`) → `kind=SECTION`.
   - ⚠ `draw_panel`의 시그니처는 유지하고 내부만 헬퍼로 라우팅하거나, 호출부에 kind를
     넘기도록 1인자 추가. 호출부가 메인/섹션 구분이 명확하므로 인자 추가가 깔끔.
3. 슬롯/셀 라운드:
   - `equipment_drawer.gd:325-326` `draw_slot_frame` fill+border 2줄 → `kind=SLOT`
     (border 색은 가변; 단일 박스 색 mutate로 처리). hover 코너 브래킷(327-339)은 유지.
   - `skill_slot_presenter.gd:89-90`, `active_item_presenter.gd:97-98` → `kind=SLOT`.
   - `perk_presenter.gd:301-302`, `passive_inventory_drawer.gd:65-66` → `kind=CELL`.

### 슬라이스 B — 일시정지 메뉴 패리티
1. `pause_menu_overlay.gd:1612` `_draw_panel`을 헬퍼 경유로 라운드화.
   - 메인 패널: `kind=MAIN`(글로우 옵션 유지 — 헬퍼 헤일로로 대체).
   - 버튼/탭: `kind=SLOT`(6px 라운드). 선택 강조선/마젠타 액센트(`_draw_button:1556`,
     `_draw_tab`) 유지.
   - `double_line`(1619-1620)은 라운드 inner border 1패스로 보존.
2. `_draw_holo_focus_frame`(1631)는 `draw_corner_brackets`로 일반화해 공유(선택).

### 슬라이스 C — 팔레트 통일 (선택, 취향)
- 두 시안이 다름: 캐릭터정보 `PANEL_BORDER (100,150,255)` vs 일시정지
  `NEON_CYAN (92,199,250)`. 하나를 정준 액센트로. (미관 통일용, 게임플레이 무관.)

---

## 3. 트랩 브리프 (배선 전 필독)

1. **per-frame StyleBoxFlat 할당 금지** (CLAUDE.md Hot-Path Lazy Init + perf 플레이북).
   캐릭터정보/일시정지는 열려 있는 동안 redraw된다(링펫 live2d 매프레임, 마우스 모션
   redraw, fade-in). `stage_clear_result_shape_helper`처럼 draw 안에서
   `StyleBoxFlat.new()` 하면 안 됨(그건 1회성 결과화면이라 허용). §1.3대로 1회 생성·재사용·
   색만 mutate. **봉인**: N회 draw 후 캐시 인스턴스 동일성 단언(반증검증: per-call `.new()`로
   되돌리면 실패).
2. **그림자 클립 트랩.** StyleBoxFlat 그림자는 rect **밖**에 렌더된다. 캔버스/부모에
   `clip_contents`가 있거나 rect가 패널 끝에 붙으면 잘린다. 섹션 그림자는 메인 패널 안쪽
   여백(섹션은 inset이라 OK), 메인 패널 그림자는 dim 배경 위에 떨어진다(`frame_presenter.gd:56`
   배경이 먼저 그려짐 → OK). CanvasItem clip 여부만 확인.
3. **라운드 모서리는 코너에서 게임 배경이 비친다.** 메인 패널 fill 0.96 + 코너 컷아웃 =
   바깥 모서리에서 스테이지가 보인다(의도된 프리미엄). 단 **밝은 스테이지/어두운 스테이지
   양쪽에서 픽셀 QA** 필요. 섹션/슬롯 코너는 패널 fill 위라 무관.
4. **글로우 헤일로 순서.** 수동 헤일로(저알파 라운드 테두리, grow(+w))는 메인 fill+border
   **앞에** 그려 뒤에 깔리게. (`draw_style_box`의 그림자는 자동 뒤, 헤일로는 수동 순서.)
5. **anti_aliasing 필수.** `anti_aliasing = true` 없으면 라운드가 계단져서 직각보다 더
   싸 보인다. `corner_detail >= 5`.
6. **border_width 정수화.** StyleBoxFlat 테두리는 int(`stage_clear` 헬퍼도 round). 1.5 →
   2로 반올림되는 미세 두께 변화 수용, 또는 명시 int 지정.
7. **셀 과장식 금지.** 퍽/패시브 그리드는 수십 셀. 셀엔 라운드만(+기존 hover 브래킷).
   컨테이너만 그림자/글로우.
8. **장비 슬롯 가변 테두리색.** 슬롯 색은 부위별(empty_colors) + filled 그린 + disabled
   회색으로 가변. 색마다 stylebox 만들지 말고 단일 SLOT 박스 `.border_color` mutate로 처리(§1.3).
9. **픽셀 사인오프 필수** (CLAUDE.md 백드롭 트랩 규칙). 상태 스모크는 미관을 증명 못 함.
   윈도우드로 실행 → 실제 스테이지 위에서 일시정지 + TAB 캐릭터정보 열고 스크린샷 →
   라운드/그림자/글로우가 화면에 읽히는지, 트랩 #3의 밝/어두운 배경 양쪽 확인.

---

## 4. 봉인 (스모크) + 사인오프

신규 `premium_panel_frame_smoke.gd` (헤드리스):
- `_verify_no_per_frame_allocation`: 표준 kind들로 draw 50회 → 캐시 인스턴스 동일 식별성
  (또는 `.new()` 카운트 == kind 수, ≠ 50). 반증검증: per-call `.new()`로 실패.
- `_verify_geometry_params`: MAIN/SECTION corner_radius>0 && anti_aliasing==true &&
  shadow_size>0; CELL shadow_size==0.
- `_verify_color_mutation_isolation`: kind X를 색 A→B로 그리면 box.border_color==B이고
  radius/width(지오메트리)는 불변.

실행은 `run_smoke_tests.ps1 -Tests`(SceneTree, `_console.exe` 경로 — raw exe 위치인자는
timeout/segfault, 메모리 참조). **진짜 사인오프 = 트랩 #9 픽셀 QA.**

---

## 5. 터치 파일 (배선 체크리스트)

- 신규 `godot/scripts/hud/premium_panel_frame.gd`
- `godot/scripts/hud/character_info_overlay_texture_drawer.gd` (draw_panel → 헬퍼)
- `godot/scripts/hud/character_info_overlay_frame_presenter.gd` (메인 패널 호출 kind)
- `godot/scripts/hud/character_info_overlay_core.gd` (섹션 6~7 호출 kind)
- `godot/scripts/hud/character_info_overlay_equipment_drawer.gd` (SLOT)
- `godot/scripts/hud/character_info_overlay_skill_slot_presenter.gd` (SLOT)
- `godot/scripts/hud/character_info_overlay_active_item_presenter.gd` (SLOT)
- `godot/scripts/hud/character_info_overlay_perk_presenter.gd` (CELL)
- `godot/scripts/hud/character_info_overlay_passive_inventory_drawer.gd` (CELL)
- `godot/scripts/hud/pause_menu_overlay.gd` (_draw_panel → 헬퍼, 버튼/탭 라운드) [슬라이스 B]
- 신규 스모크 `premium_panel_frame_smoke.gd`
- (선택) `character_info_overlay_state.gd` + `pause_menu_overlay.gd` 색 상수 [슬라이스 C]

## 6. 튜닝 레버 (취향)
- radius: MAIN 12 / SECTION 8 / SLOT 6 / CELL 4 (전부 단일 상수).
- shadow: size·alpha·offset.
- 글로우 헤일로 알파/두께.
- 팔레트 통일 여부(슬라이스 C).
