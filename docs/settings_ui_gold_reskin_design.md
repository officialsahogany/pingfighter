# Settings UI — 링피아 VR/Cyberpunk Holo Reskin (Design Note)

작성 2026-06-07. 목적: 첨부 레퍼런스의 **레이아웃 구조**(아이콘 탭 / 포커스
프레임 / 화살표 선택자 / leader 라인 / 스크롤바 / 하단 설명바 / Restore)는
가져오되, 스킨을 **골드 판타지 → 링피아 가상현실·사이버펑크 홀로그램** 톤으로
변형하기 위한 디자인 스펙 + 코드 매핑.

> 이전 골드 판타지 버전은 본 문서로 **대체(supersede)**. 레퍼런스는 이제
> "레이아웃 차용"용이고, 룩은 링피아 메인메뉴 비주얼을 따른다.

소유 모듈: `godot/scripts/hud/pause_menu_overlay.gd` (RefCounted, 전부
`_draw()` 절차적). 진입점 2개(메인메뉴 설정 / 일시정지 옵션)가 **같은
스크립트** 공유 → 한 번 고치면 양쪽 적용, QA는 양쪽.

세계관 앵커: 링피아 = AI 생태계 / 코드·데이터 / **공명(resonance)** / 링코드
(소환 키) / 링페어(동기화). 메뉴 확립 톤 = 다크 네이비 + 네온 시안 +
공명 마젠타, "잔잔하지만 살아있는" 홀로그램. (참고 FX: `main_menu_ambient.gd`)

---

## 0. 결론 한 줄

레이아웃 골격(탭·행·체크박스·선택자·하단 헬프)은 **이미 구현돼 있음**.
이 리스킨 = **컴포넌트 헬퍼 6개를 네온 홀로그램으로 스킨 + 사이버펑크
디테일(앵글 코너 노치 / 데이터 leader / 공명 포커스 펄스 / 스캔라인 /
화살표 cycler / 하단 HUD 리드아웃) 추가.** 패널 좌표(900x500)와 행 배치 유지.
지금이 이미 다크블루+시안이라 골드보다 **출발점이 훨씬 가깝다.**

---

## 1. 레퍼런스 → 링피아 변환표 (무엇을, 어떻게 바꾸나)

| # | 레퍼런스(골드) | 링피아 변환(네온 홀로그램) |
|---|---|---|
| A | small-caps serif 타이틀 + 골드 마름모 | `설정 // SETTINGS` 식 + 양옆 네온 시안 헤어라인 + **앵글 틱**(45° 컷). 옆에 작은 데이터 스트링 `SYS::CFG` (NeoDunggeunmoPro) |
| B | 골드 그라데 아이콘 탭 | 다크 글래스 탭 + active만 **시안 하단 글로우 + 마젠타 상단 엣지**(홀로 탭). 아이콘 네온 실루엣 |
| C | 골드 4코너 오너먼트 프레임 | **앵글 코너 브래킷(ㄱ자 노치) + 시안 더블 라인**, 포커스 행은 **공명 마젠타로 알파 펄스**(animation_time) |
| D | 골드 화살표 `◄ value ►` | 네온 시안 앵글 셰브론 `‹ value ›`, 호버 시 발광. 값은 웜화이트 |
| E | 점선 leader + 체크박스 | **데이터 leader**(가는 시안 점선/도트) + 네온 토글(켜짐=시안 글로우 채움) |
| F | 골드 스크롤바 | 가는 다크 트랙 + 시안 thumb(미세 글로우) |
| G | 회색 small-caps 설명 1줄 | **HUD 리드아웃 바**: 좌측 작은 `▸` + 시안-틴트 모노톤 1줄, 포커스 옵션 설명 |
| H | Restore Defaults + 마우스 | `RESET ⟳` 우하단, 시안 아웃라인 버튼 |
| I | 가장자리 캐릭터 아트 번짐 | 콘텐츠 패널 반투명 → **뒤 사이버펑크 배경 비침** + 약한 스캔라인 + (선택)먼지 모트 재사용 |

핵심 톤 규칙(메뉴와 동일): **네온은 아껴 쓰고 항상 글로우와 함께.**
웜 베이지/크림(=리빌·로딩 전용)과 무채색 그레이(=너무 평평)는 금지.

---

## 2. 디자인 토큰 (링피아 메뉴 팔레트 정렬)

현재 const(다크블루/시안)는 방향이 맞음 → **값만 메뉴 팔레트로 통일**.

```gdscript
# 패널/배경 — 메인메뉴와 동일 계열
PANEL_COLOR   = Color(0.04, 0.06, 0.10, 0.92)   # 다크 네이비, 살짝 비침
PANEL_BORDER  = Color(0.36, 0.78, 0.98, 0.90)   # 네온 시안 (링피아 브랜드)
HEADER_COLOR  = Color(0.06, 0.10, 0.16, 0.94)
SECTION_COLOR = Color(0.02, 0.04, 0.08, 0.42)   # 거의 투명 → 배경 비침(I)
BUTTON_COLOR  = Color(0.06, 0.10, 0.16, 0.90)
BUTTON_HOVER  = Color(0.10, 0.18, 0.28, 0.96)
BUTTON_SELECTED = Color(0.14, 0.24, 0.36, 1.0)
BUTTON_BORDER = Color(0.36, 0.78, 0.98, 0.55)

# 네온 액센트 (메뉴에서 가져옴)
NEON_CYAN     = Color(0.36, 0.78, 0.98)   # 기본 라인/테두리
NEON_CYAN_HOT = Color(0.66, 0.92, 1.00)   # 호버/하이라이트
RESONANCE_MAG = Color(0.72, 0.50, 1.00)   # 포커스/공명 = 마젠타·퍼플
NEON_GREEN    = Color(0.00, 1.00, 0.47)   # 확정/ON 보조 (체크 등)
WARM_GOLD     = Color(1.00, 0.80, 0.20)   # 세컨더리 액션(아껴서)
TEXT_WARM     = Color(0.94, 0.99, 1.00)   # 본문 = 쿨 화이트
TEXT_DIM      = Color(0.62, 0.72, 0.84)   # 설명/서브 = 쿨 그레이블루
```

기존 `ACCENT_BLUE`≈`NEON_CYAN`, `ACCENT_GREEN`≈`NEON_GREEN` 재활용.
**포커스 색을 시안이 아니라 마젠타(`RESONANCE_MAG`)로** 두는 게 공명
모티프 + 메뉴 포커스 톤(`0.72,0.50,1.0`)과 일치 — 시안(상시 라인)과
마젠타(현재 포커스)의 역할을 분리하면 화면이 정리된다.

---

## 3. 네온 글로우 / 스캔라인 / 폰트

### 글로우 (draw_rect는 글로우 불가)
값싼 가짜 블룸: 같은 라인/사각을 **폭↑·알파↓로 2~3패스** 겹쳐 그림.
- 신규 헬퍼 `_draw_neon_line(canvas, a, b, color, core_w)`:
  바깥 패스 `width=core_w*3, alpha=0.18` → 중간 `*2, 0.35` → 코어
  `core_w, 1.0`. 모든 네온 라인/코너/셰브론이 이걸 통과.
- 포커스 펄스: `pulse = 0.6 + 0.4*sin(animation_time*TAU/2.0)` 를 포커스
  프레임 알파에 곱해 **공명 호흡**(메뉴 오브 2.85s와 비슷한 주기).

### 스캔라인 / 홀로그램(선택, I)
콘텐츠 패널 위에 2px 간격 가로 라인을 매우 낮은 알파(0.04)로. VR
홀로 투사 느낌. **비용 주의**: 풀패널 라인 스팸은 오버드로 →
1px 스캔라인 텍스처 1장을 `draw_texture_rect`로 타일링 권장(절차 라인 X).
글리치는 **아껴서** — 탭 전환/포커스 이동 순간에만 1~2프레임 미세
오프셋/색수차, 상시 글리치 금지("잔잔" 톤 유지).

### 폰트 (메뉴와 동일 → 사실상 확정)
- 본문/라벨/값: **`NanumSquareB`** (메뉴 메인 UI 폰트) + 검정 아웃라인
  4~6px(`Color(0.01,0.03,0.08,0.72)`)로 네온 위 가독성.
- **테크 액센트 스트링**(타이틀 옆 `SYS::CFG`, 탭 코드 `0x..`, 하단
  `▸`)만 **`NeoDunggeunmoPro`**(동네게임즈 픽셀톤) → "디지털/코드" 느낌
  부여. 한글 본문엔 쓰지 않음.
- 헬퍼는 **슬라이스 1에서 `_get_ui_font(tech := false)` (분기만)** 으로 충분.
  size별 캐시는 불필요(절차 draw_string은 매번 size 인자로 호출). `size`
  파라미터·`FontVariation.spacing_glyph` 자간 보정은 **후속 슬라이스로
  미룸** — 작은 px(11~13) 한글 겹침이 실제로 보일 때만 해당 사이즈 전용
  변형 폰트로 적용([[reference_godot_ui_font_glyph_spacing]]). 즉
  `ThemeDB.fallback_font` → 명시 `NanumSquareB` preload 교체만 슬라이스 1.

---

## 4. 레이아웃 (900x500 패널 — 좌표 유지)

ASCII 목업 (디스플레이/언어 탭 예시, 패널 내부 좌표):

```
+⌐——————————————— 설정 // SETTINGS ———————————————¬+   헤더62px, 앵글 코너
|  SYS::CFG                                          |   우측 데이터 스트링
|  [⚙] [⌨] [🎮] [🖥] [🔊] [🗄] [📊] [🎁]            |   탭 y=14 h=36, active만 홀로글로우
+———————————————(네온 시안 헤어라인)———————————————+
| ┌Section(반투명+스캔라인, 배경 비침)──────────┐ ▲|
| | ⌐═══════════════════════════════════════¬  | ║|  ← 포커스 행: 앵글 코너 노치
| | | Language Selection      ‹  English  ›  |  | ║|     + 공명 마젠타 펄스 + 셰브론
| | L═══════════════════════════════════════⌡  | ║|
| |  Screen Shake ·············· data ··· (◉)  | ║|  ← 데이터 leader + 네온 토글(ON=시안)
| |  Display Damage Numbers ···· data ··· (◉)  | ║|
| |  Compendium Windows ········ data ··· ( )  | ▓|  ← 시안 thumb 스크롤바
| |  Automatic Boss Camera ····· data ··· ( )  | ║|
| |  Multithreading ············ data ··· (◉)  | ▼|
| └────────────────────────────────────────────┘  |
|  ▸ Select the game language                        |  ← HUD 리드아웃 바
|                                      [ RESET ⟳ ]   |  ← 우하단
+———————————————————————————————————————————————————+
```

좌표 앵커(현행 그대로):
- 헤더 상단 62px, 구분선 `y+62`. 타이틀 현재 `(28,40) size24` → 중앙 또는
  좌측 유지(취향). 우측 끝에 작은 데이터 스트링.
- 탭 `y+14` h=36. 현행 4탭. 아이콘화 시 정사각(예 56px gap8) 좌측 정렬.
- `content_rect` `pos+(28,84)` size `(844,334)` → `SECTION_COLOR` 투명화
  + 스캔라인.
- 행 라벨 시작 `panel.pos+(54,137)`.
- 하단 리드아웃: `_draw_recommendation_block` 변형(테두리 제거, 폭 전체).

---

## 5. 컴포넌트별 스펙 + 코드 매핑 (사용자 배선용)

함수 위치는 현재 줄번호 기준(드리프트 가능, 함수명으로 앵커).

### B. 아이콘 탭 — `_draw_tab` (L1089) + `_draw_options_window`(L1067~70)
- inactive: `BUTTON_COLOR` 글래스 + `NEON_CYAN` 25% 얇은 하단 라인,
  아이콘 dim.
- active: 하단에 `NEON_CYAN` 글로우 라인(`_draw_neon_line`) + 상단 엣지
  `RESONANCE_MAG` 1px + rect 1~2px 솟음 + 아이콘 진하게.
- 라벨 텍스트 → **아이콘 텍스처**(네온 실루엣). 없으면 라벨 폴백(점진).
- 탭 rect 함수 `_get_sound_tab_rect` 등 4개(L1447~): 정사각 통일 시 수정.

### C. 포커스 행 = 공명 앵글 프레임 (신규 헬퍼)
- **현재 포커스 행 1개에만.** 신규 `_draw_holo_focus_frame(canvas, rect)`:
  - 4코너 **ㄱ자 앵글 브래킷**(`_draw_neon_line` 2선/코너) — 골드 곡선
    오너먼트 아님, 직선 노치.
  - 테두리 = `RESONANCE_MAG`에 공명 펄스 알파, 안쪽 `NEON_CYAN` 더블라인.
  - (선택) 좌측 4px 마젠타 캡 막대(현 `_draw_button` selected 패턴 차용).
- 적용: `_draw_setting_select_row`(L1340)/`_draw_toggle_setting_row`(L1361)
  에서 `focused`일 때 일반 테두리 대신 호출. focus 인덱스는 `options_focus`.

### D. 네온 셰브론 cycler `‹ value ›` — `_draw_setting_select_row`(L1340)
- 좌/우 앵글 셰브론(`draw_colored_polygon` 삼각형, **폰트 글리프 금지**)
  + 중앙 값. 호버/포커스 시 셰브론 `NEON_CYAN_HOT` 발광.
- 클릭 히트영역 = 좌/우 셰브론 rect → 값 cycle. 키보드 좌/우도 cycle.
- **언어/디스플레이모드 pill도 이 cycler로 통일하면 레퍼런스 근접**
  (`_draw_mode_pill` 3~7개 병렬 → 1 cycler). 입력 핸들러 추가 필요.
  점진: fps/vsync/vibration(select_row)부터, mode/language는 2단계.

### E. 데이터 leader + 네온 토글 — `_draw_toggle_setting_row`(L1361)
- 라벨끝~체크박스 사이 `draw_dashed_line`(시안 30%) + (선택) 중간에
  작은 `data` 모노 라벨로 "코드/데이터" 느낌.
- 토글: ON = `NEON_GREEN`/`NEON_CYAN` 글로우 채움 + 안쪽 체크(라인),
  OFF = 빈 시안 테두리. (레퍼런스 사각 체크박스 형태 유지하되 네온화.)
- 서브타이틀(11px)은 **하단 리드아웃(G)로 이동** 권장 → 행 1줄로 깔끔.

### F. 스크롤바 (신규, 조건부) — 디스플레이 탭(9포커스)부터
- 행 초과 시만. 트랙 6px `NEON_CYAN` 18% / thumb `NEON_CYAN` + 미세
  글로우. `options_scroll` var + 휠/드래그. **클립 필수**(아래 트랩 5).

### G. HUD 리드아웃 바 — `_draw_recommendation_block`(L1401) 변형
- 테두리 제거, 패널 하단 폭 전체. 좌측 `▸`(NeoDunggeunmo) + `TEXT_DIM`
  틴트 1줄, **포커스 옵션 설명**.
- 옵션마다 desc 필요 → `_text("settings.desc.<key>")` i18n 키 추가.
  포커스→설명 매핑 `_get_focused_option_description(tab, focus)` 신규.

### H. RESET 버튼 (신규) — `_draw_button`(L1390) 재사용
- 우하단, 시안 아웃라인. 동작은 탭별 점진(디스플레이 탭 "Apply
  Recommended" 패턴 참고). 시각만 먼저 배치 가능.

### 공통: `_draw_panel`(L1408) / `_draw_button`(L1390)
- `_draw_panel`에 네온 더블라인 옵션 인자 추가(바깥 `NEON_CYAN` + 안쪽
  딤). **기본 인자로 기존 동작 보존**(회귀 주의 — 컨트롤매핑행/추천블록도
  이 헬퍼 사용).
- `_draw_button` selected: 배경 `BUTTON_SELECTED` + `NEON_CYAN_HOT`
  테두리, 좌측 캡 막대는 `RESONANCE_MAG`로.

---

## 6. 배경 / 분위기 (I) — `draw()` (L149)
- 현재 검정 오버레이(0.58) + 패널. 사이버펑크 배경 비침은:
  - 메인메뉴 진입: 뒤에 메뉴 사이버펑크 배경 있음 → 오버레이 알파↓ +
    `SECTION_COLOR` 투명화로 자연 비침.
  - 일시정지 진입: 게임 스냅샷이 뒤. 동일.
- (선택) `main_menu_ambient.gd`의 먼지 모트/컬러 드리프트를 약하게 재사용
  → "살아있는" 느낌. 신규 배경 PNG 불필요. 전용 자산은 추후 ui-hud-generation.

---

## 7. 에셋 매니페스트 (추후 — ui-hud-generation 경로)

절차적으로 시작, 격조용 추후 자산:
| 자산 | 용도 | 비고 |
|---|---|---|
| 탭 아이콘 4~8종 | B | 네온 시안 실루엣, 투명 PNG |
| 스캔라인 1px 텍스처 | I | 타일링용, 절차 라인 대체 |
| (선택) 코너 노치 글로우 | C | 절차로 충분, 격조용 |
| (선택) 마우스/⟳ 아이콘 | H | RESET 옆 |

> 전부 prewarm/cache. 메뉴라 hot path 아니지만 첫 오픈 히치 방지.

---

## 8. 트랩 브리프 (리뷰 체크리스트)

1. **두 진입점 동시 검증**: 메인메뉴 설정 + 일시정지 옵션 같은 스크립트.
   둘 다 스크린샷, 특히 일시정지는 게임 스냅샷 위라 비침/대비 다름.
2. **포커스 프레임 1개만**: `options_focus` 1개에만 공명 마젠타 프레임.
   전 행에 그리면 시끄럽고 레퍼런스와 다름.
3. **화살표 cycler 입력까지**: pill→셰브론 전환 시 클릭 히트영역(좌/우
   셰브론 rect) + 키보드 좌/우 cycle 함께 배선. 시각만 바꾸면 값 안 바뀜.
4. **글리프 의존 금지**: `‹ ›`·체크마크·`▸`·`⟳`는 폰트 글리프 말고
   폴리곤/라인/아이콘텍스처로. CLAUDE.md unicode tofu 트랩 + 작은 px
   한글 겹침과 동류.
5. **스크롤 = 클립 필수**: 행 rect를 scroll 이동 시 콘텐츠 영역 밖
   그리기/클릭 clip. 안 하면 헤더·하단 리드아웃 위로 행이 샌다.
6. **i18n desc 키 7개 언어 전부**: 하단 리드아웃(G)이 핵심 디테일.
   키 없으면 빈 바. ko/en/zh/ja/es/pt_br/ru 모두 채울 것.
7. **네온 글로우 = 멀티패스, 스캔라인 = 텍스처**: 글로우는 2~3패스로
   충분(과패스 금지), 스캔라인은 절차 라인 스팸 말고 텍스처 타일. 풀패널
   `draw_rect` 오버드로 주의.
8. **글리치는 이벤트 한정**: 상시 글리치/색수차 금지. 탭 전환·포커스
   이동 1~2프레임만. "잔잔하지만 살아있는" 톤 유지.
9. **공명 펄스 ≠ 깜빡임**: 포커스 마젠타 펄스는 알파 사인 호흡(부드럽게),
   on/off 토글이 아님. 주기는 메뉴 오브(2.85s)와 비슷하게.
10. **`_draw_panel` 더블라인 옵션 회귀**: 기본 인자로 기존 호출부
    (컨트롤 매핑행/추천블록 등) 동작 보존 확인.

---

## 9. 구현 슬라이스 순서 (가벼운→무거운)

1. **토큰 교체** + `_get_ui_font` + `_draw_neon_line` 헬퍼 → 즉시 네온 톤.
2. **컴포넌트 네온 스킨**: 탭/버튼/토글/체크박스 + `_draw_panel` 더블라인.
   입력 변화 없음.
3. **공명 포커스 프레임**(C): `_draw_holo_focus_frame` + 펄스, focused 적용.
4. **데이터 leader**(E) + **하단 리드아웃**(G, desc 키 채우기).
5. **네온 셰브론 cycler**(D): select_row부터, 입력 핸들러 포함.
6. **탭 아이콘화**(B) + 스캔라인 텍스처(I): 에셋 생성 슬라이스.
7. **스크롤바**(F) + **RESET**(H) + 이벤트 글리치: 가장 무거움, 마지막.

각 슬라이스 = 메인메뉴+일시정지 양쪽 스크린샷 sign-off.
```

---

## 부록 A — 슬라이스 1 배선 브리프 (사용자 배선 → Claude 리뷰)

범위: **색 토큰 교체 + 폰트 헬퍼 + 네온 라인 헬퍼만.** 컴포넌트 구조·입력
변화 없음. 결과 = 팔레트가 다크블루/시안 → 링피아 네이비/네온으로 정돈 +
헤더 구분선 1개가 네온 글로우로(헬퍼 검증용). 위험 낮음.

배선은 사용자가 직접, 본 브리프는 신호 계약 + 참고 레시피 + smoke + 트랩.
아래 코드 블록은 **참고 구현**이며 직접 붙여넣되 인게임 검증/리뷰는 함께.

### A-1. 색 const 교체 (L48~60) — 기존 이름 유지 = 호출부 자동 반영

기존 13개 const는 **이름 그대로 값만** 교체. 전 컴포넌트가 이 const를
읽으므로 함수 본문을 안 건드려도 팔레트가 통째로 시프트됨.

| const | 기존 값 | 슬라이스 1 값 |
|---|---|---|
| `PANEL_COLOR`   | `Color(16/255,20/255,32/255,0.96)`   | `Color(0.04, 0.06, 0.10, 0.92)` |
| `PANEL_BORDER`  | `Color(82/255,165/255,220/255,0.86)` | `Color(0.36, 0.78, 0.98, 0.90)` |
| `HEADER_COLOR`  | `Color(35/255,48/255,70/255,0.96)`   | `Color(0.06, 0.10, 0.16, 0.94)` |
| `SECTION_COLOR` | `Color(23/255,29/255,44/255,0.94)`   | `Color(0.02, 0.04, 0.08, 0.55)` ※ |
| `BUTTON_COLOR`  | `Color(36/255,48/255,70/255,0.96)`   | `Color(0.06, 0.10, 0.16, 0.90)` |
| `BUTTON_HOVER`  | `Color(54/255,82/255,112/255,0.98)`  | `Color(0.10, 0.18, 0.28, 0.96)` |
| `BUTTON_SELECTED`| `Color(62/255,96/255,132/255,1.0)`  | `Color(0.14, 0.24, 0.36, 1.0)` |
| `BUTTON_BORDER` | `Color(112/255,190/255,255/255,0.78)`| `Color(0.36, 0.78, 0.98, 0.55)` |
| `SLIDER_BACK`   | `Color(64/255,68/255,82/255,1.0)`    | `Color(0.06, 0.10, 0.16, 1.0)` |
| `TEXT_DIM`      | `Color(178/255,188/255,210/255)`     | `Color(0.62, 0.72, 0.84)` |
| `ACCENT_BLUE`   | `Color(0,200/255,1.0)`               | `Color(0.36, 0.78, 0.98)` |
| `ACCENT_GREEN`  | `Color(0,1.0,120/255)`               | `Color(0.0, 1.0, 0.47)` |
| `ACCENT_GOLD`   | `Color(1.0,215/255,90/255)`          | `Color(1.0, 0.80, 0.20)` |

※ `SECTION_COLOR` 알파: 슬라이스 1은 가독성 안전하게 **0.55**. 스캔라인
도입(슬라이스 6) 후 0.42까지 낮춰 배경 비침 강화.

신규 토큰 추가(슬라이스 2+가 사용, 지금 정의만):

```gdscript
const NEON_CYAN     := Color(0.36, 0.78, 0.98)
const NEON_CYAN_HOT := Color(0.66, 0.92, 1.00)
const RESONANCE_MAG := Color(0.72, 0.50, 1.00)
const NEON_GREEN    := Color(0.00, 1.00, 0.47)
const WARM_GOLD     := Color(1.00, 0.80, 0.20)
const TEXT_WARM     := Color(0.94, 0.99, 1.00)
```

> 주의: 이 슬라이스에서 컴포넌트 함수의 하드코딩 색(예 `_draw_setting_select_row`
> L1351 `Color(25/255,...)`)은 **건드리지 않음** — 슬라이스 2 작업. 지금은
> const-기반 색만 시프트.

### A-2. 폰트 헬퍼

상단 const 추가(확립 패턴 = 직접 preload):

```gdscript
const FONT_BODY: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const FONT_TECH: Font = preload("res://assets/fonts/NeoDunggeunmoPro.ttf")
```

헬퍼 추가(`tech=true`면 코드/액센트 스트링용):

```gdscript
func _get_ui_font(tech: bool = false) -> Font:
    return FONT_TECH if tech else FONT_BODY
```

호출부 1곳만 교체 — `draw()` L152:
```gdscript
# before: var font: Font = ThemeDB.fallback_font
var font: Font = _get_ui_font()
```
`draw()`가 `font`을 모든 `_draw_*`에 파라미터로 내려주므로 **이 한 줄이
전 텍스트에 전파**됨. FONT_TECH는 슬라이스 2+에서 별도 인입.

> 글리프 자간 보정(FontVariation.spacing_glyph)은 **이번엔 보류**. 큰 px엔
> 오히려 해롭고, 현재 11~13px 한글 겹침이 실제로 보일 때만 작은 사이즈
> 전용 변형 폰트로 적용([[reference_godot_ui_font_glyph_spacing]]). 보이면
> 그때 슬라이스에 추가.

### A-3. 네온 라인 헬퍼 (멀티패스 가짜 블룸)

`_draw_panel`(L1408) 근처에 추가. `draw_set_transform` 금지(트랩
[[feedback_godot_draw_set_transform_trap]]) — 단순 다중 `draw_line`:

```gdscript
func _draw_neon_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, core_w: float = 1.0) -> void:
    var halo := Color(color.r, color.g, color.b, color.a * 0.18)
    var mid := Color(color.r, color.g, color.b, color.a * 0.35)
    canvas.draw_line(from, to, halo, core_w * 3.0)
    canvas.draw_line(from, to, mid, core_w * 2.0)
    canvas.draw_line(from, to, color, core_w)
```

**검증용 첫 인입** — 헤더 구분선 L1065 1곳만 교체:
```gdscript
# before: canvas.draw_line(panel_rect.position + Vector2(14.0, 62.0), Vector2(panel_rect.end.x - 14.0, panel_rect.position.y + 62.0), PANEL_BORDER, 2.0)
_draw_neon_line(canvas, panel_rect.position + Vector2(14.0, 62.0), Vector2(panel_rect.end.x - 14.0, panel_rect.position.y + 62.0), NEON_CYAN, 1.5)
```
나머지 라인의 네온화는 슬라이스 2.

### A-4. Smoke (슬라이스 1 봉인)

신규 `godot/tests/settings_ui_neon_skin_smoke.gd`. 구조는
`scoreboard_led_digits_visual_smoke.gd`를 그대로 미러 — `extends SceneTree`
+ 내부 `class NeonProbe extends Node2D`의 `_draw()` 안에서 헬퍼를 호출:
- `FONT_BODY != null` 및 `FONT_TECH != null` (자산 경로 살아있음).
- `_get_ui_font()` == FONT_BODY, `_get_ui_font(true)` == FONT_TECH.
- 팔레트 회귀 락: `PANEL_BORDER.is_equal_approx(Color(0.36,0.78,0.98,0.90))`
  등 핵심 2~3개 const 값 고정(누가 실수로 골드로 되돌리는 것 방지).
- **`_draw_neon_line`은 반드시 probe의 `_draw()` 안에서 호출.**
  `CanvasItem.draw_line()` 계열은 `_draw()` 밖에서 부르면 안전하지 않음.
  `_init()`에서 probe를 root에 add + `queue_redraw()`, `_process`로 2~3
  프레임 대기 후 `probe.draw_count > 0` 확인 (헬퍼가 죽지 않고 콜백을
  받았는지). 헤드리스면 픽셀 검증 생략하고 `draw_count`/const 계약만 검사
  (scoreboard 스모크의 `_is_headless_run()` 분기 패턴 동일). 픽셀 단언 불필요.

```gdscript
# 참고 골격 (scoreboard_led_digits_visual_smoke.gd 미러)
extends SceneTree
const Overlay := preload("res://scripts/hud/pause_menu_overlay.gd")
class NeonProbe:
    extends Node2D
    var overlay: Object = Overlay.new()
    var draw_count := 0
    func _draw() -> void:
        draw_count += 1
        overlay._draw_neon_line(self, Vector2(8, 8), Vector2(160, 8), Overlay.NEON_CYAN, 1.5)
# _init(): probe = NeonProbe.new(); get_root().add_child(probe); probe.queue_redraw()
# _process(): 2~3프레임 후 probe.draw_count > 0 + const 락 단언 → quit(0/1)
```

### A-4b. 편집 후 repo 필수 검증 (smoke만으로 부족)

`.gd` 편집 후 `godot/`에서 **세 개 모두** 통과해야 슬라이스 1 완료:
- `.\tools\run_headless_load_check.ps1` — 파서/로드 무오류.
- `.\tools\run_warning_scan.ps1` — Control 프로퍼티 shadowing 등 경고 0.
- `.\tools\run_smoke_tests.ps1 -Tests res://tests/settings_ui_neon_skin_smoke.gd`
  — 위 focused 스모크.

### A-5. 트랩 (슬라이스 1 한정)

1. **이름 보존**: const 이름을 바꾸지 말 것(`PANEL_COLOR`→`NEON_PANEL`
   같은 리네임 금지). 호출부 수십 곳이 기존 이름을 참조 → 리네임하면
   슬라이스 1이 컴포넌트 작업으로 번짐. 값만 교체.
2. **변경 범위 = 옵션창이 아니라 overlay 전체**: `PANEL_COLOR`/`PANEL_BORDER`
   는 옵션창뿐 아니라 `draw()`의 공통 패널(L160)과 메인메뉴/일시정지 **기본
   메뉴**에도 들어가고, 버튼은 공통 `_draw_button`(L1390)을 탄다. 그래서
   스샷 QA는 **3장**: ① 메인메뉴 설정(옵션 열림) ② 일시정지 옵션(옵션 열림)
   ③ **옵션 닫힌 일시정지 기본 메뉴**. 일시정지는 게임 스냅샷 위라
   `SECTION_COLOR` 비침이 다르게 읽힘 — 0.55가 너무 투명하면 0.65로 미세조정.
3. **폰트 시각 중립 확인**: `ThemeDB.fallback_font`→`FONT_BODY` 교체는
   기대상 중립이나, 한글/영문/숫자 한 화면 스샷으로 확인. 만약 자간/굵기
   가 달라지면 fallback이 NanumSquareB가 아니었다는 뜻 → 그래도 명시
   preload가 정답이니 유지하고 변화만 기록.
4. **`_draw_panel` 미변경**: 슬라이스 1은 `_draw_panel`에 더블라인 옵션
   추가하지 않음(그건 슬라이스 2). 헤더선만 `_draw_neon_line`로.
5. **ACCENT_BLUE 전파 범위**: `ACCENT_BLUE` 값 변경은 모드 pill 테두리·
   토글 체크마크·select_row 포커스 테두리 등 여러 곳에 동시 반영됨
   (의도된 시프트). 한 곳이 어색하면 그건 슬라이스 2 컴포넌트 튜닝감,
   const 값을 되돌리지 말 것.
6. **(후속 슬라이스 메모) 타이틀 i18n**: 슬라이스 1은 타이틀 텍스트를
   건드리지 않음(`_text("settings.title")` L1066 유지). 후속에서 `설정 //
   SETTINGS` 스타일로 바꿀 때 **리터럴 혼합 문자열을 직접 박지 말 것** —
   새 i18n 키를 추가하거나 언어별 title을 유지하고 장식(앵글 틱·데이터
   스트링)만 별도 draw로 얹는다. 7개 언어 동시 확인.

---

## 부록 B — 슬라이스 2 배선 브리프 (컴포넌트 네온 스킨)

범위: **시각만.** 입력·레이아웃·구조 변화 0. 셰브론 cycler / 공명 포커스
프레임 / 스크롤 / RESET 은 **이번에도 금지**(각각 슬라이스 5/3/7).
결과 = 외곽 패널이 네온 더블라인+글로우로, 탭/버튼/체크박스가 칠해져서
**여기서부터 "눈에 보이는" 변화 시작.** 줄 앵커는 슬라이스 1 반영 후 기준.

가장 위험한 건 `_draw_panel` 하나. 여기만 계약대로 깔면 나머지는 색/라인
패스 교체라 난이도 낮음.

### B-1. `_draw_panel` 시그니처 확장 (계약 — 회귀 핵심) — L1416

**반드시 신규 파라미터를 끝에 기본 인자로** 추가. 중간 삽입 금지.

```gdscript
func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, border_width: float, double_line: bool = false, glow: bool = false) -> void:
    canvas.draw_rect(rect, fill)
    if border_width > 0.0:
        if glow:
            var halo := Color(border.r, border.g, border.b, border.a * 0.18)
            var mid := Color(border.r, border.g, border.b, border.a * 0.35)
            canvas.draw_rect(rect, halo, false, border_width * 3.0)
            canvas.draw_rect(rect, mid, false, border_width * 2.0)
        canvas.draw_rect(rect, border, false, border_width)
        if double_line:
            var inner := Color(border.r, border.g, border.b, border.a * 0.45)
            canvas.draw_rect(rect.grow(-3.0), inner, false, 1.0)
```

**회귀 불변식**: `double_line=false, glow=false`(=기존 모든 호출부)는
`draw_rect(fill)` + `draw_rect(border,false,border_width)`와 **바이트
동일**. 기존 호출부는 인자 5개라 자동으로 이 경로. 새 인자는 끝에 있으니
안전.

### B-2. 외곽 패널만 글로우+더블라인 — `draw()` L168

```gdscript
# before: _draw_panel(canvas, panel_rect, PANEL_COLOR, PANEL_BORDER, 2.0)
_draw_panel(canvas, panel_rect, PANEL_COLOR, PANEL_BORDER, 2.0, true, true)
```
(선택) 콘텐츠 패널 L1081은 **double_line만**(glow 없이) 줄 수 있음 —
`..., 1.0, true, false`. 과하면 빼기.

> **절대 모든 `_draw_panel`에 glow를 켜지 말 것.** 탭/버튼/행이 내부에서
> `_draw_panel`을 호출하므로 전역 glow는 오버드로 폭증 + 화면 소음.
> 글로우는 **외곽 1곳**(+선택 콘텐츠 더블라인)만.

### B-3. `_draw_tab` 홀로 스킨 — L1097

색/라인 패스만. inactive=평평, active=살짝 솟음 + 시안 하단 글로우 +
마젠타 상단 엣지. 참고:
```gdscript
var draw_rect := rect
var fill := BUTTON_COLOR
var border := Color(BUTTON_BORDER.r, BUTTON_BORDER.g, BUTTON_BORDER.b, 0.30)
if active_tab:
    draw_rect.position.y -= 2.0          # 솟음
    fill = BUTTON_SELECTED
    border = NEON_CYAN
_draw_panel(canvas, draw_rect, fill, border, 1.0)
if active_tab:
    var b := draw_rect.position.y + draw_rect.size.y
    _draw_neon_line(canvas, Vector2(draw_rect.position.x + 2.0, b), Vector2(draw_rect.end.x - 2.0, b), NEON_CYAN, 1.2)   # 시안 하단 글로우
    canvas.draw_line(Vector2(draw_rect.position.x + 2.0, draw_rect.position.y), Vector2(draw_rect.end.x - 2.0, draw_rect.position.y), RESONANCE_MAG, 1.5)  # 마젠타 상단 엣지
_draw_text_in_rect(canvas, font, label, draw_rect, 15, TEXT_WARM)
```
> 솟음(y-2)이 헤더 구분선(62px)·탭 영역과 충돌하지 않는지 확인(탭 top
> y+14 → y+12, 여유 있음).

### B-4. `_draw_button` selected 강조 — L1398
2-토큰 스왑만:
- selected/hover 테두리 → `NEON_CYAN_HOT` (기존 `BUTTON_BORDER`).
- 좌측 캡 막대 색 → `RESONANCE_MAG` (기존 `ACCENT_GOLD`).

### B-5. `_draw_toggle_setting_row` 체크박스 네온화 — L1369
- ON: 체크박스 `_draw_panel(checkbox_rect, <어두운 그린 fill>, NEON_GREEN,
  1.0, false, true)`(glow) + 체크마크 라인 `NEON_GREEN`.
- OFF: 빈 박스 + `Color(NEON_CYAN.r,.g,.b, 0.5)` 테두리.
- **점선 leader / 서브타이틀 이동은 안 함**(슬라이스 4). 행 테두리는
  기존 `ACCENT_BLUE`(=NEON_CYAN 값) 유지.

### B-6. `_draw_mode_pill`(L1330) / `_draw_setting_select_row`(L1348) — 선택 폴리시
슬라이스 1에서 `ACCENT_BLUE`가 이미 NEON_CYAN 값이라 거의 시안 상태.
원하면 hover/selected 테두리를 `NEON_CYAN_HOT`로 한 단계 밝히는 정도.
**저우선 — 생략 가능**, 셰브론화는 슬라이스 5.

### B-7. Smoke 보강 — 기존 `settings_ui_neon_skin_smoke.gd`

probe `_draw()`에 무오류 호출만 추가(픽셀 단언 X):
```gdscript
# NeonLineProbe._draw() 안에 이어서:
var r := Rect2(8.0, 16.0, 120.0, 24.0)
overlay._draw_panel(self, r, Overlay.PANEL_COLOR, Overlay.PANEL_BORDER, 2.0)              # 기본 경로(회귀)
overlay._draw_panel(self, r, Overlay.PANEL_COLOR, Overlay.PANEL_BORDER, 2.0, true, true)  # 더블라인+글로우 경로
overlay._draw_tab(self, Overlay.FONT_BODY, r, "x", true)
overlay._draw_tab(self, Overlay.FONT_BODY, r, "x", false)
overlay._draw_button(self, Overlay.FONT_BODY, r, "x", true, Vector2(-99.0, -99.0))
overlay._draw_toggle_setting_row(self, Overlay.FONT_BODY, r, Rect2(90.0, 18.0, 16.0, 16.0), "t", "s", true, false, Vector2(-99.0, -99.0))
```
- probe 캔버스 크기 살짝 키움(`get_root().size`)으로 클립 회피.
- 단언은 기존 `draw_count > 0` 그대로 = 콜백 받고 안 죽으면 통과.

### B-8. 편집 후 검증 (슬라이스 1과 동일)
- `.\tools\run_headless_load_check.ps1`
- `.\tools\run_warning_scan.ps1` (새 bool 파라미터 사용됨 — unused 경고 0 확인)
- `.\tools\run_smoke_tests.ps1 -Tests res://tests/settings_ui_neon_skin_smoke.gd`
- **스샷 3장**: main_menu_settings / pause_options / **pause_menu_closed**.
  `_draw_panel`이 공통 변경이라 **옵션 닫힌 pause 기본 메뉴가 제일 중요**
  (외곽 글로우+더블라인 + 공통 버튼 강조가 자연스러운지).

### B-9. 트랩 (슬라이스 2 한정)
1. **`_draw_panel` 파라미터 끝에만**: 중간 삽입 금지. 기존 호출부가
   6개 이상 인자를 넘기지 않는지 grep으로 확인(전부 5개여야 함).
2. **glow는 외곽 1곳만**: 전역 glow 금지(오버드로/소음).
3. **입력·레이아웃 불변**: 셰브론/포커스 프레임/스크롤/RESET 금지.
4. **마젠타 역할 분리**: 여기 RESONANCE_MAG(버튼 캡·탭 상단 엣지)는
   슬라이스 3의 "공명 포커스 프레임"과 다른 용도. 슬라이스 3에서 포커스
   행에 마젠타를 또 얹을 때 이중 적용/혼동 주의.
5. **탭 솟음 클립**: active 탭 y-2가 위 영역으로 새지 않는지.
6. **세 검증 재실행** + RefCounted라 Control shadowing 무관(rotation 등).
