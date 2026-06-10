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

---

## 부록 C — 슬라이스 3 배선 브리프 (공명 포커스 프레임)

범위: **포커스된 1개 행에만** 시안 더블라인 + 마젠타 코너 브래킷(알파
펄스). 핵심 체감 = **"한 행만 살아서 반응한다."** 시각 임팩트는 크지만
회귀 지점은 좁음(헬퍼 1개 + 두 row 함수에 overlay 한 줄씩). 입력·레이아웃
불변. 줄 앵커는 슬라이스 2 반영 후 기준.

### C-1. 펄스는 **인자로** (helper는 순수) — 테스트 결정성

`_draw_holo_focus_frame`은 `animation_time`을 **직접 읽지 않음**. 펄스 알파를
인자로 받음 → smoke가 `1.0`을 넘겨 결정적으로 테스트 가능. 라이브 펄스는
**호출하는 row 함수**가 멤버 `animation_time`을 읽어 계산해 넘김.

```gdscript
func _focus_pulse_alpha() -> float:
    return 0.55 + 0.45 * sin(animation_time * TAU / 2.85)   # 범위 ~[0.1, 1.0], 메뉴 오브 주기
```

### C-2. `_draw_holo_focus_frame` 헬퍼 (계약) — `_draw_panel` 근처 추가

**기본 패널을 대체하지 않고 위에 얹는 overlay.** 시안 더블라인 = 주 구조,
**마젠타는 4코너 브래킷에만**(펄스 포인트). 전체 row 테두리를 마젠타로
칠하지 말 것(슬라이스 2 버튼 캡·탭 엣지와 충돌).

```gdscript
func _draw_holo_focus_frame(canvas: CanvasItem, rect: Rect2, pulse_alpha: float = 1.0) -> void:
    if rect.size.x <= 8.0 or rect.size.y <= 8.0:
        return
    # 시안 inner 라인 → 기본 패널 테두리(바깥)와 합쳐져 더블라인을 이룸 (주 구조, 펄스 X)
    canvas.draw_rect(rect.grow(-3.0), Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.5), false, 1.0)
    # 마젠타 ㄱ자 코너 브래킷 = 펄스 포인트 (코너에만)
    var mag := Color(RESONANCE_MAG.r, RESONANCE_MAG.g, RESONANCE_MAG.b, clampf(pulse_alpha, 0.0, 1.0))
    var arm := minf(14.0, rect.size.x * 0.25)
    var w := 2.0
    var tl := rect.position
    var tr := Vector2(rect.end.x, rect.position.y)
    var bl := Vector2(rect.position.x, rect.end.y)
    var br := rect.end
    canvas.draw_line(tl, tl + Vector2(arm, 0.0), mag, w); canvas.draw_line(tl, tl + Vector2(0.0, arm), mag, w)
    canvas.draw_line(tr, tr + Vector2(-arm, 0.0), mag, w); canvas.draw_line(tr, tr + Vector2(0.0, arm), mag, w)
    canvas.draw_line(bl, bl + Vector2(arm, 0.0), mag, w); canvas.draw_line(bl, bl + Vector2(0.0, -arm), mag, w)
    canvas.draw_line(br, br + Vector2(-arm, 0.0), mag, w); canvas.draw_line(br, br + Vector2(0.0, -arm), mag, w)
```

> 바깥 시안 엣지는 기본 패널의 `focused` 테두리(이미 슬라이스 1/2에서
> 시안/시안-hot)가 공급 → 프레임은 inner 라인 + 코너만 얹는 **가산
> overlay**. 코너에서 마젠타가 기본 시안 위에 올라가 펄스 포인트가 됨.

### C-3. 적용 = focused 행 1개에만 (기본 패널 유지 + overlay)

대상은 **`_draw_setting_select_row`(L1355)** 와 **`_draw_toggle_setting_row`
(L1376)** 둘뿐. 각 함수에서 기존 `_draw_panel(canvas, row_rect, ...)`는
**그대로 두고**, 그 아래 한 줄 추가:

```gdscript
# _draw_setting_select_row: 기존 _draw_panel(row_rect...) 다음, value_rect 그리기 전/후 무관
if focused:
    _draw_holo_focus_frame(canvas, row_rect, _focus_pulse_alpha())

# _draw_toggle_setting_row: 기존 _draw_panel(row_rect...) 다음
if focused:
    _draw_holo_focus_frame(canvas, row_rect, _focus_pulse_alpha())
```

> **이번 슬라이스 적용 범위는 이 두 row 타입뿐.** 모드/언어 pill,
> 버튼, 슬라이더의 포커스 프레임은 **의도적으로 미적용**(범위 밖). 리뷰어가
> "왜 pill엔 프레임 없냐"로 오해하지 않도록 명시. 후속에서 필요하면 같은
> overlay 패턴으로 확장.

### C-4. Smoke 보강 — 기존 `settings_ui_neon_skin_smoke.gd`

probe `_draw()`에 (픽셀 단언 없이, 무오류 + 결정적 펄스):
```gdscript
overlay._draw_holo_focus_frame(self, Rect2(8.0, 150.0, 150.0, 26.0), 1.0)   # 결정적 펄스=1.0
overlay._draw_setting_select_row(self, Overlay.FONT_BODY, Rect2(8.0, 18.0, 120.0, 24.0), Rect2(120.0, 18.0, 40.0, 24.0), "라벨", "값", true, Vector2(-99.0, -99.0))   # focused=true → 라이브 프레임 경로
overlay._draw_setting_select_row(self, Overlay.FONT_BODY, Rect2(8.0, 18.0, 120.0, 24.0), Rect2(120.0, 18.0, 40.0, 24.0), "라벨", "값", false, Vector2(-99.0, -99.0))  # focused=false → 프레임 없이 기존 row만
```
(toggle는 슬라이스 2에서 이미 focused=false 경로 있음; 원하면 focused=true도 한 줄.)
- (선택) `_verify_contract`에 `_focus_pulse_alpha()` 결과가 `[0,1]` 안인지
  단언(animation_time=0이라 결정적으로 0.55).

### C-5. 시각 QA — 디스플레이 탭에서 포커스 2장

`_draw_panel` 공통 변경이 아니므로 슬라이스 2의 3장 회귀는 가벼움. 대신
**"한 행만 반응"** 을 증명할 2장 추가:
- `options_focus`를 **select row**(예 FPS Cap, focus 1)로 잡은 디스플레이 탭.
- `options_focus`를 **checkbox row**(remember/auto, focus 3/4)로 잡은 디스플레이 탭.
- 각 캡처에서 **그 행만** 코너 브래킷이 있고 나머지 행은 평범한지 확인
  (펄스는 정지 캡처라 한 위상으로 박힘 — 알파 차이만 확인).

### C-6. 편집 후 검증 (동일 3종)
- `.\tools\run_headless_load_check.ps1`
- `.\tools\run_warning_scan.ps1`
- `.\tools\run_smoke_tests.ps1 -Tests res://tests/settings_ui_neon_skin_smoke.gd`

### C-7. 트랩 (슬라이스 3 한정)
1. **대체 금지, overlay만**: 기존 `_draw_panel(row_rect, ...)`를 지우지 말
   것. 프레임은 그 위에 얹는 가산 레이어.
2. **포커스 1개 불변식**: `options_focus`가 한 번에 한 인덱스만 true →
   프레임도 한 행만. 두 행이 동시에 frame 받으면 게이팅 버그.
3. **마젠타는 코너만**: 전체 row border 마젠타화 금지(슬라이스 2 충돌).
   시안=구조, 마젠타=펄스 포인트.
4. **펄스는 인자**: 헬퍼가 `animation_time`을 직접 읽지 않게(smoke 결정성).
   라이브 위상은 row 함수가 `_focus_pulse_alpha()`로 계산해 주입.
5. **범위 = 두 row 타입뿐**: pill/버튼/슬라이더 미적용은 의도.
6. **입력·레이아웃 불변**: 셰브론/스크롤/RESET 여전히 금지.

---

## 부록 D — 슬라이스 4a 배선 브리프 (데이터 leader + 하단 리드아웃 골격)

슬라이스 4를 둘로 분할. **4a = 시각 골격(코드)**, **4b = i18n 7개 언어 +
포커스 매핑 완성(Codex 분배)**. 4a는 desc를 `_text(key, "한국어 fallback")`
임시로만 채워 시각을 빠르게 확인하고, 전체 번역은 범위 밖.

회귀 핵심 = **`_draw_recommendation_block`을 절대 건드리지 않음.** 하단
리드아웃은 신규 `_draw_hud_readout_bar`로 **완전 분리**(아래 D-3).

### D-1. 점선 leader — Godot 내장 사용

Godot 4엔 `CanvasItem.draw_dashed_line(from, to, color, width, dash, ...)`
내장. **별도 `_draw_dashed_line` 헬퍼는 선택**(고정 dash 파라미터를 프로젝트
전역으로 통일하고 싶을 때만 얇은 래퍼). 4a는 내장 직접 호출 권장 — 데드코드
회피. (Godot 버전이 4.x인지만 확인; 내장은 4.0+.)

### D-2. `_draw_toggle_setting_row`에 라벨↔체크박스 leader — L1378

기존 본문 유지, **타이틀 텍스트 뒤 ~ 체크박스 앞** 구간에만 점선 1줄 추가.
모든 토글 행에 적용(포커스 행은 위에 슬라이스 3 프레임이 같이 얹힘 — 공존 OK).

```gdscript
# title 그린 직후(L1404 근처). 서브타이틀(y+42) 아님 — 타이틀 라인(y+~20)에.
var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
var leader_y := row_rect.position.y + 20.0
var leader_x0 := row_rect.position.x + 58.0 + title_w + 10.0
var leader_x1 := checkbox_rect.position.x - 10.0
if leader_x1 > leader_x0 + 6.0:
    canvas.draw_dashed_line(Vector2(leader_x0, leader_y), Vector2(leader_x1, leader_y), Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.30), 1.0, 4.0)
```
> 가드(`leader_x1 > leader_x0 + 6`)로 긴 라벨이 체크박스와 겹칠 때 leader
> 생략. 슬라이스 3 포커스 프레임과 그리는 순서는 무관(둘 다 가산).

### D-3. 하단 리드아웃 — **신규** `_draw_hud_readout_bar` (회귀 핵심)

**`_draw_recommendation_block`은 동결.** 새 헬퍼를 `_draw_recommendation_block`
근처에 추가. 테두리/박스 없음(추천 박스와 다름) — 하단 폭 전체 딤 1줄 +
좌측 시안 ▸ 폴리곤(글리프 금지).

```gdscript
func _draw_hud_readout_bar(canvas: CanvasItem, font: Font, panel_rect: Rect2, text: String) -> void:
    if text == "":
        return
    var bar := Rect2(panel_rect.position + Vector2(28.0, panel_rect.size.y - 26.0), Vector2(panel_rect.size.x - 56.0, 20.0))
    var m := Vector2(bar.position.x, bar.get_center().y)
    canvas.draw_colored_polygon(PackedVector2Array([m + Vector2(0.0, -3.0), m + Vector2(5.0, 0.0), m + Vector2(0.0, 3.0)]), NEON_CYAN)  # ▸ (폴리곤)
    _draw_text(canvas, font, text, Vector2(bar.position.x + 12.0, bar.get_center().y + 5.0), 13, TEXT_DIM)
```

호출 = `_draw_options_window` 끝(탭 콘텐츠·back 버튼 그린 뒤, L1092 이후):
```gdscript
_draw_hud_readout_bar(canvas, font, panel_rect, _get_focused_option_description(options_tab, options_focus))
```

### D-4. `_get_focused_option_description` 최소 골격 (4b가 완성)

```gdscript
func _get_focused_option_description(tab: String, focus: int) -> String:
    if tab == OPTIONS_TAB_SOUND:
        match focus:
            0: return _text("settings.desc.bgm", "배경음 음량을 조절합니다.")
            1: return _text("settings.desc.sfx", "효과음 음량을 조절합니다.")
    elif tab == OPTIONS_TAB_DISPLAY:
        match focus:
            0: return _text("settings.desc.display_mode", "화면 표시 방식을 선택합니다.")
            1: return _text("settings.desc.render_fps", "렌더링 최대 프레임을 설정합니다.")
            2: return _text("settings.desc.vsync", "수직 동기화 방식을 설정합니다.")
            3: return _text("settings.desc.remember_display", "표시 모드를 다음 실행에도 유지합니다.")
            4: return _text("settings.desc.auto_refresh", "60Hz를 자동으로 적용합니다.")
    elif tab == OPTIONS_TAB_LANGUAGE:
        return _text("settings.desc.language", "게임 언어를 선택합니다.")
    return ""
```
> controls 탭 / display 버튼 포커스(5~8) 등은 4a에선 `""` → 리드아웃 생략
> (정상). 4b에서 매핑 완성 + `settings.desc.*` 7개 언어 키 추가.

### D-5. Smoke 보강

probe `_draw()`에:
```gdscript
overlay._draw_hud_readout_bar(self, Overlay.FONT_BODY, Rect2(0.0, 0.0, 180.0, 180.0), "설명 텍스트")  # 무오류
overlay._draw_hud_readout_bar(self, Overlay.FONT_BODY, Rect2(0.0, 0.0, 180.0, 180.0), "")              # 빈 텍스트 early-return
```
`_verify_contract`에:
```gdscript
_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_DISPLAY, 1) != "", "display fps focus should yield a readout description")
_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_CONTROLS, 99) == "", "out-of-range focus should yield empty readout")
```
(toggle 행 leader는 기존 toggle smoke 호출이 이미 경로를 탐 — `draw_dashed_line`
무오류만 확인되면 충분, 픽셀 단언 X.)

### D-6. 편집 후 검증 (동일 3종) + 시각 QA
- `run_headless_load_check.ps1` / `run_warning_scan.ps1` /
  `run_smoke_tests.ps1 -Tests res://tests/settings_ui_neon_skin_smoke.gd`
- **스샷**: ① 토글 행 leader 보이는 디스플레이 탭, ② 하단 리드아웃이
  포커스 따라 바뀌는 것(사운드 BGM/SFX, 디스플레이 select 행) 1~2장.
- **회귀 확인 필수**: display 탭 **페이싱 추천 골드 박스**와 language 탭
  **subtitle 노트 박스**가 슬라이스 3과 동일하게 보이는지(=
  `_draw_recommendation_block` 무변경 증명).

### D-7. 트랩 (슬라이스 4a 한정)
1. **`_draw_recommendation_block` 동결**: 함수 본문·callsite(L1199/L1318)·
   rect getter(`_get_display_pacing_recommendation_rect`/`_get_language_note_rect`)
   모두 손대지 말 것. 하단 리드아웃은 완전 별도 `_draw_hud_readout_bar`.
2. **하단 바 ↔ back/액션 버튼 충돌**: 권장 rect는 `panel.end.y - 26`.
   사운드 back은 `end.y - 70`~`end.y - 25`라 그 아래로 안 겹침. **디스플레이
   탭은 버튼이 많으니** 캡처로 겹침 확인, 겹치면 y를 더 내리거나 탭별 조정.
3. **▸ 마커는 폴리곤**: `draw_colored_polygon`, 유니코드 글리프 금지.
4. **leader는 타이틀 라인에**: 서브타이틀(y+42) 위 타이틀(y+~20) 구간.
   긴 라벨 겹침 가드 필수.
5. **i18n 전체 번역 범위 밖**: 4a는 ko fallback만. `settings.desc.*` 7개
   언어 키 + controls 매핑은 4b(Codex).
6. **입력 변화 없음**: 셰브론/스크롤/RESET 여전히 금지.

### D-8. 배선 실측 메모 (4a 완료 후 기록)

- **현재 토글 레이아웃은 체크박스가 왼쪽**(title은 `row.x+58`부터, 체크박스는
  그 왼쪽). 본 문서 §4 ASCII 목업의 우측 `(◉)`는 레퍼런스 기준 희망안일 뿐
  현행과 다름. leader는 별도 `_draw_toggle_leader`로 분리되어, `checkbox.x <=
  title_end_x`면 **오른쪽 여백**으로, 아니면 **체크박스 앞**으로 흐르는 유연
  가드를 둠 → 좌/우 체크박스 양 레이아웃 모두 대응. 후속 슬라이스(셰브론 등)
  는 "체크박스 우측" 가정을 다시 깔지 말 것.
- 하단 리드아웃 바 최종 위치 = `panel.end.y - 22`(높이 16). 사운드 back
  버튼(`end.y-70`~`end.y-25`) 아래라 비충돌 확인됨.
- leader는 별도 헬퍼(`_draw_toggle_leader`), 하단 바도 별도 헬퍼
  (`_draw_hud_readout_bar`) — `_draw_recommendation_block`는 동결 유지.

---

## 부록 E — 슬라이스 4b 핸드오프 스펙 (i18n 완성 + 매핑 — Codex)

소유: Codex. 4a와 **한 커밋으로 묶음**(리드아웃 골격+번역/매핑 = 한 단위).
4a가 깐 `settings.desc.*`는 **현재 코드 fallback(ko)만** 있고
`language_settings_data.gd`엔 키가 **하나도 없음** → 4b가 7개 언어에 전부
추가 + `_get_focused_option_description` 매핑을 완성한다.

### E-1. 추가할 키 = 17개 × 7개 언어 (119 문자열)

대상 dict 블록(각 언어): ko(L3973~) / en(L4080~) / zh(L4187~) / ja(L4294~)
/ es(L4401~) / **pt-BR(L4508~, 코드값 `"pt-BR"` ← `pt_br` 아님)** / ru(L4615~).
배치는 기존 `display.desc.*`/`language.subtitle` 근처에 같은 스타일로.

| key | 포커스 매핑 | ko 원문(소스) |
|---|---|---|
| `settings.desc.bgm` | sound 0 | 배경음 음량을 조절합니다. |
| `settings.desc.sfx` | sound 1 | 효과음 음량을 조절합니다. |
| `settings.desc.sound_back` | sound 2(back) | 이전 화면으로 돌아갑니다. |
| `settings.desc.display_mode` | display 0 | 화면 표시 방식을 선택합니다. |
| `settings.desc.render_fps` | display 1 | 렌더링 최대 프레임을 설정합니다. |
| `settings.desc.vsync` | display 2 | 수직 동기화 방식을 설정합니다. |
| `settings.desc.remember_display` | display 3 | 표시 모드를 다음 실행에도 유지합니다. |
| `settings.desc.auto_refresh` | display 4 | 60Hz를 자동으로 적용합니다. |
| `settings.desc.recommend_apply` | display 5 | 권장 설정을 한 번에 적용합니다. |
| `settings.desc.apply_60hz` | display 6 | 지금 60Hz 설정을 적용합니다. |
| `settings.desc.save` | display 7 | 현재 디스플레이 설정을 저장합니다. |
| `settings.desc.display_back` | display 8(back) | 이전 화면으로 돌아갑니다. |
| `settings.desc.controls_device` | controls 0 | 입력 장치를 선택합니다. |
| `settings.desc.controls_vibration` | controls 1(조이패드) | 조이패드 진동 세기를 조절합니다. |
| `settings.desc.controls_back` | controls back | 이전 화면으로 돌아갑니다. |
| `settings.desc.language` | language 0~6 | 게임 언어를 선택합니다. |
| `settings.desc.language_back` | language 7(back) | 이전 화면으로 돌아갑니다. |

> ko가 소스. Codex가 en/zh/ja/es/pt-BR/ru를 각 블록 기존 톤에 맞춰 번역.
> "이전 화면으로 돌아갑니다" 계열은 동일 문장 반복이라 언어별로도 한 문장
> 재사용 OK. `settings.desc.*`는 **코드 fallback도 이 ko 원문으로 동기화**
> (4a 골격의 fallback 문자열과 표를 일치시킬 것).

### E-2. `_get_focused_option_description` 매핑 완성 (L1518)

현재 sound 0/1, display 0~4, language(전체→language) 만 채워짐. 완성:
- **sound**: 2 → `sound_back`.
- **display**: 5→`recommend_apply`, 6→`apply_60hz`, 7→`save`, 8→`display_back`.
- **language**: 0~6 → `language`, **7 → `language_back`** (현재는 7도 language로
  잘못 감 — 분기 추가).
- **controls (device-view 의존, 멤버 `controls_device_view` 읽어야 함)**:
  ```gdscript
  elif tab == OPTIONS_TAB_CONTROLS:
      if focus == 0:
          return _text("settings.desc.controls_device", "입력 장치를 선택합니다.")
      if controls_device_view == CONTROL_DEVICE_JOYPAD and focus == 1:
          return _text("settings.desc.controls_vibration", "조이패드 진동 세기를 조절합니다.")
      if focus == _get_controls_back_focus_index():
          return _text("settings.desc.controls_back", "이전 화면으로 돌아갑니다.")
  ```
  > **함정**: 키보드 모드에서 focus 1 = back(진동 행 없음). focus 1 = 진동을
  > 하드코딩하면 키보드에서 오설명. 반드시 `controls_device_view` +
  > `_get_controls_back_focus_index()`로 분기.

### E-3. 긴 번역 1줄 오버플로우 방침

리드아웃 바 1줄, 폭 = `panel.size.x - 56`. **최소 패널 폭 560**(`_get_options_panel_rect`
하한)에서 usable ≈ **504px @ 12px**. 두 겹 방어:
1. **저작 규칙(주 통제)**: desc는 1 짧은 문장. 가장 긴 언어(ru/pt-BR 경향)
   기준으로도 504px/12px에서 1줄에 들어가게(대략 라틴 ~55자 / 한글 ~28자
   이내). 넘으면 문장을 줄임 — 폰트 축소로 때우지 말 것.
2. **런타임 세이프넷**: `_draw_hud_readout_bar`의 텍스트 그리기를 **폭 제한**
   으로 바꿔 패널 밖으로 새지 않게:
   ```gdscript
   # 기존: _draw_text(canvas, font, text, pos, 12, TEXT_DIM)  (width -1.0)
   canvas.draw_string(font, Vector2(bar.position.x + 13.0, bar.get_center().y + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 13.0, 12, TEXT_DIM)
   ```
   폭 제한이면 클립되어 패널 경계를 넘지 않음(클립 발생 자체가 "번역이 너무
   김" 신호 → 길이 QA로 잡음). 이 변경은 `_draw_recommendation_block`과 무관.

### E-4. smoke / coverage 기준 (둘 다 신규 — 기존 localization 테스트 없음)

신규 `settings_desc_localization_smoke.gd`(또는 기존 smoke 확장):
1. **누락 키 0**: 7개 언어 dict 각각이 위 17개 `settings.desc.*` 키를 **전부
   포함**. `LanguageSettingsData`의 per-language dict를 직접 순회해
   `dict.has(key)` 단언(번역 경로 fallback에 가려지지 않게 dict 직접 검사).
2. **빈 리드아웃 0**: 모든 유효 (tab, focus)에 대해
   `_get_focused_option_description(tab, focus) != ""`.
   - sound 0~2, display 0~8, language 0~7.
   - controls는 device-view 두 경우 모두: keyboard(focus 0,1) + joypad(focus
     0,1,2). 각 모드 set 후(또는 멤버 직접 세팅) 단언.
3. **오버플로우 길이 체크**: 각 언어 각 키 텍스트가
   `font.get_string_size(text, ALIGN_LEFT, -1.0, 12).x <= 504.0` 인지 단언
   (넘으면 fail → 문장 줄이기). FONT_BODY로 측정.

### E-5. 트랩 (슬라이스 4b 한정)
1. **pt-BR 코드 = `"pt-BR"`** (하이픈), `pt_br` 아님. 기존 블록과 일치.
2. **7개 dict 전부**: 한 언어라도 누락 시 그 언어에서 ko fallback이 섞여
   나옴(혼합 언어 리드아웃) — coverage smoke가 잡음.
3. **controls device-view 의존**: focus 1을 진동으로 하드코딩 금지(E-2 함정).
4. **`display.desc.*` 기존 패밀리와 분리**: 이미 `display.desc.fullscreen/
   windowed`가 있음(모드 pill 설명용, `_get_display_mode_description` 경로).
   리드아웃용 `settings.desc.display_mode`와 **혼동/중복 금지** — 별도 유지.
   이 핑계로 `_draw_recommendation_block`/모드 설명 경로를 건드리지 말 것.
5. **language 7 = back**: 4a가 7도 language로 보내던 것 분기로 교정.
6. **코드 fallback ↔ 데이터 키 동기화**: `_get_focused_option_description`의
   ko fallback 문자열과 `settings.desc.*` ko 값이 같은 문장이어야(불일치 시
   언어=ko인데 키 누락 상황에서 다른 문구가 보일 수 있음).

---

## 부록 F — 슬라이스 5 배선 브리프 (네온 셰브론 cycler · 첫 입력 변화)

이번부터 **입력이 바뀜** → 회귀 면이 넓다. 핵심: **새 상태/새 증감 로직을
만들지 말고**, 셰브론 클릭을 **기존 cycle 함수에 방향만 넣어 합류**시킨다.
배선 시작 전 `git status` + HEAD 재스냅샷([[project-godot-wip-branch-moving-head]]).

### F-1. 범위 = select_row 계열만 (3개)
`render_fps`(display focus 1) / `vsync`(display focus 2) /
`controls_vibration`(controls 조이패드 focus 1). **display mode pill / language
pill의 cycler화는 후속 슬라이스.** 이번에 pill은 손대지 않는다.

### F-2. 단일 진실원: 셰브론 hit rect 헬퍼 (draw·click 공용)
드로잉과 히트테스트가 **같은 rect**를 써야 어긋나지 않음. value_rect를
좌/우 반으로 나눈 공용 헬퍼 하나:
```gdscript
func _get_select_chevron_rects(value_rect: Rect2) -> Dictionary:
    var half := value_rect.size.x * 0.5
    return {
        "left": Rect2(value_rect.position, Vector2(half, value_rect.size.y)),
        "right": Rect2(value_rect.position + Vector2(half, 0.0), Vector2(value_rect.size.x - half, value_rect.size.y)),
    }
```
- 히트영역 = value_rect 좌/우 반(시각 셰브론보다 넓고, **value_rect 밖으로
  안 샘**). 라벨/다른 rect 침범 없음.

### F-3. 드로잉 — `_draw_setting_select_row` (func 앵커)
기존 `_draw_panel(value_rect, ...)` + 중앙 텍스트는 두되, 값 좌/우에 네온
셰브론 폴리곤(**글리프 금지**)을 추가. hover 쪽만 `NEON_CYAN_HOT`로 발광
(mouse_pos 이미 파라미터로 있음):
```gdscript
var ch := _get_select_chevron_rects(value_rect)
var lcol := NEON_CYAN_HOT if ch.left.has_point(mouse_pos) else NEON_CYAN
var rcol := NEON_CYAN_HOT if ch.right.has_point(mouse_pos) else NEON_CYAN
# ‹ : value_rect 좌측 안쪽, › : 우측 안쪽 — draw_colored_polygon 삼각형
```
값 텍스트는 두 셰브론 사이 중앙 유지.

### F-4. 입력 배선 = 기존 cycle 함수에 방향만 (새 상태 금지)
**키보드는 이미 정상**(좌/우→cycle) → **건드리지 말 것.** 클릭만 바꾼다.

`_handle_display_click` fps 행(현재 L502 whole-row +1):
```gdscript
if _get_display_fps_cap_row_rect(panel_rect).has_point(position):
    options_focus = 1
    var ch := _get_select_chevron_rects(_get_display_fps_cap_value_rect(panel_rect))
    if ch.left.has_point(position):
        _cycle_render_fps_cap(-1, owner, registry)
    elif ch.right.has_point(position):
        _cycle_render_fps_cap(1, owner, registry)
    # else 라벨 영역: focus만, cycle 없음
    return {"handled": true}
```
vsync 행(L506)도 동일하게 `_cycle_vsync_mode(∓1, ...)`.
`_handle_controls_click` vibration 행(L546)도 동일하게
`_adjust_gamepad_vibration_level(∓1)`.
- **행 rect를 바깥 게이트로 유지** → 행 클릭은 계속 이 핸들러가 소비(=다른
  rect로 누수 없음). 방향만 value 좌/우 반으로 분기.
- 라벨 영역 클릭은 **focus만**(cycle 없음). 기존 "행 아무데나 +1"에서
  바뀌는 미세 동작이나 방향 모호성 제거 — 의도. (+1 유지를 원하면 else에
  `_cycle_*(1,...)` 넣어도 되나, 비권장.)

### F-5. 회귀 가드 (셰브론이 먹으면 안 되는 곳)
셰브론 분기는 **fps/vsync/vibration 행 rect 게이트 안에만** 존재하므로 구조적
으로 분리됨. 그래도 smoke로 증명:
- **sound slider**(다른 탭/`_handle_sound_click`) — 셰브론 무관, 슬라이더 그대로.
- **toggle checkbox**(L510/L515 `_get_display_default_row_rect` 등) — 토글 동작,
  cycle 아님.
- **back/save/recommend 버튼**(L520-532) — 버튼 동작.
- **탭 전환**(헤더 탭 rect, `_handle_options_click`에서 콘텐츠보다 먼저 검사)
  — 탭 전환.
세 select 행의 value_rect ⊆ 행 rect 이고, 위 rect들과 겹치지 않음(확인).

### F-6. Smoke 보강 (좌/우 분리 + 회귀)
`_handle_display_click`은 owner/registry null이어도 핵심 cycle은 실행됨
(`_cycle_render_fps_cap`의 `render_fps_cap = options[...]`은 view_layout null
가드 위에서 동작) → smoke가 null로 호출 가능.
- 패널: `var panel := overlay._get_options_panel_rect(Vector2(900,600))`.
- **좌 클릭 = 이전 옵션**: `render_fps_cap` 알려진 값 세팅 →
  `ch.left.get_center()`로 `_handle_display_click(pos, null, null, panel)` →
  `render_fps_cap`이 옵션 배열의 **이전** 값인지 단언.
- **우 클릭 = 다음 옵션**: `ch.right.get_center()` → **다음** 값.
- **분리 증명**: 같은 시작값에서 좌 클릭 결과 ≠ 우 클릭 결과.
- **회귀**: 토글 행 위치 클릭 → `remember_display_mode` 토글되고
  `render_fps_cap` **불변**; 버튼 위치 클릭 → 버튼 동작; (라벨영역 클릭 →
  `render_fps_cap` 불변, focus만).
- vsync/vibration도 최소 좌/우 1쌍씩.
- 픽셀 단언 없음(드로잉은 무오류 호출만).

### F-7. 트랩 (슬라이스 5 한정)
1. **draw·click 공용 rect**: 반드시 `_get_select_chevron_rects` 한 곳에서.
   드로잉만 바꾸고 히트영역을 따로 계산하면 시각/클릭 어긋남.
2. **새 상태 금지**: `_cycle_render_fps_cap`/`_cycle_vsync_mode`/
   `_adjust_gamepad_vibration_level` 재사용, 방향 인자만. 값 저장/적용/
   wrap 로직 복제 금지(이미 그 함수 안에 있음).
3. **키보드 미변경**: 좌/우→cycle 이미 정상(L267-282 / `_adjust_controls_focus`).
   중복 배선/재작성 금지.
4. **hit rect ⊆ value_rect**: 행/라벨/다른 rect로 안 새게. pill(mode/language)
   미적용.
5. **셰브론은 폴리곤**(글리프 금지), hover 쪽만 발광.
6. **행 rect 바깥 게이트 유지**: 셰브론 분기를 행 rect `has_point` 안에 둬서
   클릭이 버튼/체크박스/탭으로 누수되지 않게.
7. **owner/registry null 경로**: smoke가 null로 cycle 호출 시 죽지 않는지
   (현재 view_layout null 가드 있음 — 확인).

---

## 부록 G — 슬라이스 7 배선 브리프 (RESET 버튼 · 스크롤바 보류)

**스크롤바는 보류**(정상 900×500 패널에선 어느 탭도 오버플로우 안 함 →
기능 스크롤바는 현재 죽은 코드. 작은 뷰포트/행 증가 시 별도 도입).
슬라이스 7 = **RESET(현재 탭 기본값 복원) 버튼만.** 입력/배선 계열로 닫고,
그 다음 슬라이스 6(에셋)을 순수 미감으로 분리.

### G-1. RESET 동작 = 현재 탭만, 기존 세터/적용 재사용
신규 `_reset_current_tab_to_defaults(owner, registry)` 가 `options_tab`으로
분기. **적용 로직 복제 금지** — 기존 함수/세터 호출:
```gdscript
func _reset_current_tab_to_defaults(owner: Object, registry: Object) -> void:
    match options_tab:
        OPTIONS_TAB_SOUND:
            _set_bgm_volume(registry, DEFAULT_BGM_VOLUME)   # 0.4 (getter fallback과 동일)
            _set_sfx_volume(registry, DEFAULT_SFX_VOLUME)   # 0.7
        OPTIONS_TAB_DISPLAY:
            display_mode = DISPLAY_MODE_WINDOWED
            render_fps_cap = RENDER_FPS_CAP_DEFAULT
            vsync_mode = VSYNC_MODE_AUTO
            remember_display_mode = false
            auto_refresh_rate_60hz = false
            _display_preference_dirty = true
            _save_display_options(owner, registry)          # 적용/저장은 기존 경로
        OPTIONS_TAB_CONTROLS:
            controls_device_view = CONTROL_DEVICE_KEYBOARD_MOUSE
            gamepad_vibration_level = GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT
            GamepadVibrationSettings.set_vibration_level(gamepad_vibration_level)  # 영속화(기존 진동 경로 확인)
        OPTIONS_TAB_LANGUAGE:
            _set_language_option(LanguageSettings.DEFAULT_LANGUAGE, owner)
```
- 신규 상수 2개: `const DEFAULT_BGM_VOLUME := 0.4`, `const DEFAULT_SFX_VOLUME := 0.7`
  (`_get_bgm_volume`/`_get_sfx_volume` fallback과 동일 — smoke 단언용 이름).
  나머지 기본값은 기존 상수 그대로(WINDOWED/MONITOR/AUTO/VIBRATION_LEVEL_DEFAULT/DEFAULT_LANGUAGE).
- **"recommended"와 다름**: `_apply_recommended_display_settings`는
  EXCLUSIVE_FULLSCREEN+remember=true(권장). RESET은 **팩토리 기본값**
  (WINDOWED 등). 둘을 섞지 말 것.

### G-2. 버튼 = 마우스 전용, **포커스 사이클에 넣지 말 것** (핵심 트랩)
RESET을 focus 사이클에 추가하면 `SOUND/DISPLAY/CONTROLS/LANGUAGE_FOCUS_COUNT`
+ 모든 focus 인덱스 매핑 + **4b의 `_get_focused_option_description` 매핑**까지
연쇄 변경됨. 그래서 **마우스 전용 코너 버튼**으로(레퍼런스의 마우스 아이콘
Restore Defaults와 동일 성격). focus_count·desc 매핑 **무변경**.
- (선택) 키보드 접근이 필요하면 focus 사이클 말고 **전용 키 1개**
  (`KEY_DELETE` 등)를 `_handle_options_key_input`에 추가해 현재 탭 리셋.
  저우선, 안 해도 됨.

### G-3. 배치 = 헤더 우상단 (바텀 우측 충돌 회피)
레퍼런스는 바텀 우측이지만, **display 탭 바텀은 4버튼(권장값/60Hz/저장/
뒤로가기)으로 꽉 참** → 바텀 우측 RESET은 뒤로가기와 충돌. 모든 탭에서
비어 있는 **헤더 우상단**(타이틀/탭 오른쪽, language 탭 끝 ~x+538 이후
우측 ~360px 여백)에 배치:
```gdscript
func _get_reset_button_rect(panel_rect: Rect2) -> Rect2:
    return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 142.0, 14.0), Vector2(124.0, 34.0))
```
- `_draw_options_window`에서 헤더 그린 뒤 모든 탭 공통으로 1회 draw
  (탭 분기 전). 라벨 `_text("settings.reset", "초기화")`. ⟳ 아이콘은
  폴리곤/선(글리프 금지), 선택.
- 스타일은 기존 `_draw_button` 재사용 가능(시안 톤). selected=false 고정
  (focus 비참여).

### G-4. 클릭 라우팅 = 탭 콘텐츠보다 먼저
`_handle_options_click`에서 **탭 분기 이전에** RESET rect 검사(헤더 레벨
버튼이므로):
```gdscript
if _get_reset_button_rect(panel_rect).has_point(position):
    _reset_current_tab_to_defaults(owner, registry)
    return {"handled": true}
```
- 헤더 우상단이라 탭 rect/콘텐츠 rect와 안 겹침. 탭 전환보다 먼저/나중
  순서는 무관(영역 분리). back/save/버튼과도 분리.

### G-5. i18n (1키 — 가벼움)
`settings.reset` 1키를 7개 언어에 추가(ko "초기화" / en "Reset" / zh "重置"
/ ja "リセット" / es "Restablecer" / pt-BR "Redefinir" / ru "Сброс").
- 4b 패턴대로 `language_settings_data.gd` 7블록 + 코드 fallback "초기화"
  동기화. 1키라 부담 적음. (보류 원하면 fallback만으로도 동작하나, 7키
  추가 권장 — 반쪽 i18n 회피.)
- **주의**: 이 파일은 HEAD 유동 churn 잦음([[project-godot-wip-branch-moving-head]])
  — 커밋 직전 재스냅샷.

### G-6. Smoke 보강
overlay 변수에 저장되는 탭(display/controls/language)은 직접 단언:
```gdscript
# display: 비기본값으로 세팅 → reset → 기본값 확인
overlay.options_tab = Overlay.OPTIONS_TAB_DISPLAY
overlay.display_mode = Overlay.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
overlay.vsync_mode = Overlay.VSYNC_MODE_ENABLED
overlay.remember_display_mode = true
overlay.auto_refresh_rate_60hz = true
overlay._reset_current_tab_to_defaults(null, null)
_expect(overlay.display_mode == Overlay.DISPLAY_MODE_WINDOWED, ...)
_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_DEFAULT, ...)
_expect(overlay.vsync_mode == Overlay.VSYNC_MODE_AUTO, ...)
_expect(not overlay.remember_display_mode and not overlay.auto_refresh_rate_60hz, ...)
# controls: vibration/device 비기본 → reset → 기본
# language: language_code 비기본 → reset → DEFAULT_LANGUAGE
```
- **배치 비충돌**: `_get_reset_button_rect`가 각 탭 back/save 버튼 rect 및
  탭 rect와 **겹치지 않음** 단언(`_rect_inside` 반대로 disjoint 체크).
- **클릭 라우팅**: RESET rect 중심 클릭 → 현재 탭 리셋 발생; 헤더 빈 곳/
  콘텐츠 클릭 → 리셋 안 일어남.
- 사운드 볼륨 리셋은 registry 필요 → fake audio stub 있으면 단언, 없으면
  `_set_bgm_volume(null, 0.4)`가 죽지 않는지(반환 클램프)만 확인하고 메모.
- 픽셀 단언 없음.

### G-7. 트랩 (슬라이스 7 한정)
1. **focus 사이클 불참**: RESET을 focus에 넣으면 focus_count + 4b desc
   매핑 연쇄 변경 → 마우스 전용 코너 버튼으로.
2. **적용 로직 복제 금지**: display는 `_save_display_options`, 볼륨은
   `_set_*_volume`, 언어는 `_set_language_option` 재사용.
3. **RESET ≠ recommended**: 팩토리 기본값(WINDOWED) vs 권장(EXCLUSIVE+remember).
4. **배치 = 헤더 우상단**: display 바텀 4버튼과 충돌 회피. 바텀 우측 금지.
5. **클릭은 헤더 레벨**(`_handle_options_click` 탭 분기와 영역 분리), back/
   save/탭으로 누수 없게.
6. **owner/registry null**: smoke 직접 호출 시 죽지 않게(기존 null 가드 확인).
7. **스크롤바 미도입 명시**: 지금은 RESET만. 스크롤은 오버플로우 실제
   발생 시 별도 슬라이스.

---

## 부록 H — 슬라이스 6 배선 브리프 (절차적 아이콘+텍스트 탭 + 스캔라인)

**방식 결정: 절차적**(비트맵 자산 X). 설정 UI는 100% `_draw()`/자산 0개이고
필요한 글리프(스피커/모니터/게임패드/글로브)가 단순 표준형이라, 기존 네온
헬퍼로 그리는 게 일관·무churn·무프리웜. 더 디테일한 비트맵을 원하면 그때
`ui-hud-generation`으로 전환(현재 미선택). 브리프→배선→리뷰 흐름 유지.

### H-1. 탭 글리프 = 절차적 네온 라인아트 (active=HOT)
신규 `_draw_tab_icon(canvas, kind, icon_rect, color)` 디스패처. `kind` ∈
{sound, display, controls, language}. 전부 `draw_line`/`draw_arc`/
`draw_colored_polygon`, ~16px, **글리프/유니코드 금지**:
- **sound**: 스피커 사다리꼴 폴리곤 + 우측 1~2개 호(`draw_arc`, 음파).
- **display**: 모니터 사각 outline + 하단 받침 짧은 선.
- **controls**: 가로 캡슐(둥근 사각) + 우측 작은 원 2개 + 좌측 십자(d-pad).
- **language**: 원 + 세로 타원(경선) + 가로선 1~2(위선).
색은 active 탭이면 `NEON_CYAN_HOT`(또는 `RESONANCE_MAG` 상단 엣지와 톤 맞춤),
inactive면 `NEON_CYAN` 60%. `_draw_tab`의 hover/active 상태와 동기.

### H-2. `_draw_tab` 시그니처에 icon kind 추가
`func _draw_tab(canvas, font, rect, label, active_tab, icon_kind := "")`.
`_draw_options_window`(L1067~70 등가)에서 탭별 kind 전달
(sound/display/controls/language). 아이콘은 rect 좌측 안쪽
(`rect.position + Vector2(10, center)`), 라벨은 그 우측으로 시프트
(`_draw_text_in_rect` 대신 아이콘 폭만큼 들여쓴 좌측정렬, 또는 라벨 중앙
정렬 기준점을 아이콘 우측 영역으로).

### H-3. 탭 rect 재튜닝 (레이아웃 — 회귀 주의)
아이콘+텍스트라 각 탭이 ~20px 넓어짐. `_get_sound_tab_rect`/
`_get_display_tab_rect`/`_get_controls_tab_rect`/`_get_language_tab_rect`의
x오프셋·폭을 재배치:
- 4탭이 서로 안 겹치고, **마지막 탭 우측 끝이 RESET 버튼(x+758)과 안 겹치게**
  (현재 language 탭 끝 ~x+538 → 아이콘 추가 후 ~x+620 예상, 758 미만 OK).
- **클릭 hit-test는 같은 rect getter를 쓰므로 자동 동기** — 별도 입력 변경
  없음(드로잉/레이아웃만).
- 헤더 높이(62px)·탭 y(14)·높이(36)는 유지.

### H-4. 스캔라인 (홀로그램, §I)
`_draw_options_window` 콘텐츠 패널 그린 뒤, `content_rect` 영역에 가로선을
~3px 간격으로 `NEON_CYAN` alpha ~0.04로. 메뉴라 hot path 아님(매 프레임
~100 draw_line 무해). content_rect로 클립(밖으로 안 새게). 너무 진하면
alpha/간격 튜닝. **저강도 유지**("잔잔" 톤).

### H-5. Smoke
probe `_draw()`에 무오류 호출:
- `_draw_tab(self, FONT_BODY, rect, "탭", true, "sound")` 및 display/controls/
  language 4종 + `icon_kind=""`(폴백) 무오류.
- (있으면) 스캔라인 그리는 헬퍼 무오류.
계약 단언:
- `_get_sound_tab_rect`~`_get_language_tab_rect` 4개가 **서로 disjoint**
  (`_rects_overlap` false).
- 마지막 탭(language) rect가 `_get_reset_button_rect`와 **disjoint**.
- 픽셀 단언 없음.

### H-6. 트랩 (슬라이스 6 한정)
1. **절차적 — 자산/프리웜 도입 금지**(이 슬라이스 범위). 비트맵 원하면
   별도 ui-hud-generation 슬라이스로.
2. **글리프/유니코드 금지**: 아이콘은 폴리곤/선/호로만(tofu 트랩).
3. **탭 rect 재튜닝 = 드로잉/레이아웃만, 입력 무변경**: hit-test는 같은
   getter라 자동 동기. focus 인덱스/순서 건드리지 말 것.
4. **탭 ↔ RESET 비충돌**: 넓어진 탭이 헤더 우상단 RESET(x+758)로 안 새게.
5. **스캔라인 저강도 + 클립**: 진한 스캔라인/오버드로 금지, content_rect
   클립. 게임 hot path 아님은 맞지만 알파 과하면 가독성 해침.
6. **active/hover 색 동기**: 아이콘 색이 탭 상태(`active_tab`/hover)와 따로
   놀지 않게 — 슬라이스 2 탭 스킨과 같은 톤.
