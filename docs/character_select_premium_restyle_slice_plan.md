# 캐릭터 선택 프리미엄 리스타일 — Slice Plan

**Status:** DESIGN — D1~D6 전부 locked, 코덱스 문서리뷰 6건 반영(2026-07-03).
배선 착수 가능 (Slice A부터).
Owner split: **Claude 배선 → Codex 적대리뷰** (2026-07-03 확정 — 승인 게이트가
픽셀 QA/미감이라 그리기-조정 루프를 Claude가 잡고, 셀프리뷰 맹점은 Codex
리뷰로 역전). 배경/무드 에셋은 Claude 디렉션 + Gemini 스틸 생성(비-시트 =
Gemini, FLUX 금지). This doc is the SSOT.

**Reference:** 사용자 제공 AI 목업 (2026-07-03, 레드/블랙 사이버펑크 캐릭터
선택 화면). **목업은 구조·밀도·프레이밍 레퍼런스일 뿐, 리터럴 복사 금지** —
AI 생성물이라 로고(M1)/코드(GCS-2048)류 텍스트가 서로 모순됨. 텍스트·데이터는
전부 실제 게임 데이터로 채운다.

**핵심 판정:** 현재 화면(`character_select_screen.gd`)은 이미 목업과 동일한
3컬럼 구조(좌 카드열 / 중앙 프리뷰 / 우 인포패널 / 하단 액션바 / 상단 헤더)이고,
데이터도 거의 1:1로 존재한다(`character_name: "미카"`, 태그라인,
`difficulty_stars`, 대표 스킬 3종, 잠금 플래그, 링코어 슬롯, 리그 3탭, 언어
버튼, 클릭/확정 보이스 플레이어, 풀바디 Live2D 패널까지). 따라서 이 작업은
**신규 화면 설계가 아니라 리스킨 + 소량 데이터 확장**이다.

---

## 0. Decisions

| # | Question | Decision |
|---|---|---|
| D1 | 악센트 팔레트 | **Locked (2026-07-03, 사용자).** 크롬(프레임/브래킷/마이크로텍스트)은 중립 다크 고정 + 상태 악센트(선택 카드 외곽선, 확정 버튼, 클래스 칩, 소속 엠블럼 틴트)만 캐릭터별 `card_color`/`glow_color` 틴트. 레드 단일 통일은 기각 |
| D2 | 중앙 배경 | **Locked (2026-07-03, 사용자).** 시티스케이프 야경 스틸(Gemini) 1장이 기존 챔버 백플레이트를 **대체.** 캐릭터별 색변형은 기존 백로그([[project_char_select_backdrop_vfx]] 5캐릭 색변형)와 통합 처리 |
| D3 | 로어 메타데이터 | **Locked (2026-07-03, 사용자).** 체격/소속 = §1-b 초안 채택. **CV 행은 생략** — 전시 크레딧 오표기 리스크로 기각, `lore_cv` 필드 자체를 만들지 않는다. 빈 값 = 행 미표시 규칙 유지 |
| D4 | "학생 정보" 버튼 | **v1 제외 (locked).** 대상 화면이 없다. 프레임만 잡아두는 죽은 버튼 금지 — 후속 기획 확정 시 별도 슬라이스 |
| D5 | 중앙 히어로 아트 | **애니메이션 유지 (locked).** 목업의 정지 일러스트로 교체하지 않는다. 기존 49프레임 아이들 루프 프리뷰를 새 대각컷 프레임 안에 그대로 호스팅 |
| D6 | 음성 버튼 | **제거 (2026-07-03 개정, 사용자).** 캐릭터 클릭 시 재생되는 기존 클릭 모션 보이스가 이미 이 기능을 대체하므로 별도 음성 버튼을 만들지 않는다. 목업의 "음성" 버튼은 채택하지 않음 |

---

## 1. Target layout spec (목업 → 현재 코드 매핑)

| 목업 요소 | 현재 owner | 작업 종류 |
|---|---|---|
| 상단 "캐릭터 선택 / SELECT YOUR CHARACTER" + 코드 마이크로텍스트 | `_draw_header` | 리스킨 (한/영 병기 + 에디토리얼 라벨) |
| 좌측 캐릭터 카드 리스트 (초상+이름+역할칩, 선택 악센트 외곽선) | `_draw_card_column` / `_draw_character_card` | 리스킨 |
| 잠금 카드 ("잠금 필요") | `_draw_locked_card_overlay` | 리스킨 |
| 중앙 히어로 (대각컷 프레임 + 배경 도시 야경) | `_draw_preview_frame` + `character_select_preview_vfx_host.gd` | 프레임 리스킨 + 배경 에셋 |
| 중앙 하단 타이틀 블록 (미카 / MIKA / STRIKER 칩) | `_draw_preview_frame` 내 신규 블록 | 신규 드로우 (데이터는 기존 `character_name`/`class_name`/`role`; CV 라인 없음 — §1-b) |
| 음성 버튼 | — | **v1 제외 (D6 개정)** — 캐릭터 클릭 모션 보이스가 기능 대체 |
| 우측 인포패널 (역할 라벨 / 이름+클래스칩 / 태그라인 / 설명 / 난이도★ / 대표 스킬 / 링코어) | `_draw_info_panel` / `_draw_difficulty` / `_draw_skill_icons` / `_draw_lingpet_ring_core_slot` | 리스킨 + 재배치 |
| FULL BODY VIEW 서브패널 + HEIGHT/WEIGHT/AFFILIATION | `_draw_full_body_live2d_panel` + 신규 마이크로스탯 행 | 리스킨 + 신규 데이터 (D3) |
| 하단 리그 3탭 (주니어/챔피언/신화) | `_draw_league_button` / `_draw_action_bar` | 리스킨 |
| 우하단 대형 확정 버튼 ("미카 선택") | `_draw_button`(confirm) | 리스킨 |
| 언어/설정 버튼 | `_draw_language_button` | 리스킨 |
| 상단 우측 아이콘 행 (프로필/기록/홈) | 없음 | **v1 제외** — 매핑되는 기능 없음. 죽은 아이콘 금지 |

기존 스탯 3종(속도/파워/방어, `_draw_stats`)은 목업에 없지만 **유지** — 인포패널
안에서 위치만 재조정. 정보 삭제는 이 플랜의 스코프가 아니다.

---

## 1-b. D3 로어 메타데이터 (2026-07-03 확정)

**세계관 앵커:** 플라자에 정식 아카데미가 이미 존재한다(교관 서율,
`docs/plaza_6building_interior_recipes.md`). 목업의 "학생 정보" 프레임과도
일치하므로, **5캐릭 전원 = 링피아 아카데미 소속 학생, 소속(AFFILIATION) =
아카데미 + 전공 분과**로 통일한다. 신규 고유명사 부채를 최소화하는 구성 —
새로 발명하는 것은 분과명 5개뿐이다.

**엠블럼 규칙 (D1 시너지):** 소속 엠블럼은 아카데미 단일 엠블럼 1종을
캐릭터 악센트 컬러로 틴트해 재사용한다. 분과별 엠블럼 5종 제작 금지(에셋
부채). 엠블럼 에셋은 Slice D와 같은 규칙(에셋+배선 동일 슬라이스)을 따른다.

| 캐릭터 | 클래스 | HEIGHT | WEIGHT | AFFILIATION(소속) |
|---|---|---|---|---|
| 미카 | 스매셔 (핵심 스트라이커) | 158cm | 46kg | 링피아 아카데미 · 타격전과 |
| 레나 | 코만도 (전술 통제) | 167cm | 53kg | 링피아 아카데미 · 전술화기과 |
| 코하쿠 | 발토르 (단조 수호자) | 149cm | 41kg | 링피아 아카데미 · 단조공학과 |
| 이오 | 옵티머스 (카드 사이클러) | 162cm | 49kg (증강 유닛 제외) | 링피아 아카데미 · 증강기공과 |
| 세린 | 바이퍼 (사이버 어쌔신) | 170cm | 55kg | 링피아 아카데미 · 화랑무예과 |

값 설계 근거:
- **체격**: 비주얼 정체성 기준. 코하쿠(소형 단조공 + 대형 해머 대비),
  세린(장신 무술가 — 화랑킥/마샬킥 실루엣), 미카(소~중형 스트라이커),
  레나(군인 체격), 이오(중형 + 기계 증강).
- **이오 몸무게의 "(증강 유닛 제외)"**: "기계 강화 역전 돌파" 정체성을
  마이크로스탯 한 줄로 노출하는 로어 장치. 다국어 번역 대상 문자열.
- **분과명**: 각 클래스의 실제 게임플레이에서 역산 — 타격전과(파워스매시),
  전술화기과(화기 전환/무전 지원), 단조공학과(단조 수호), 증강기공과(기계
  강화), 화랑무예과(화랑킥 — 세린의 실제 스킬명 유래).

**CV 행: 생략 확정 (2026-07-03, 사용자).** 보이스 파일은 존재하지만 실제
성우 계약 크레딧이 아니므로, 전시 빌드(게임아이콘 서울 2026)에 가공 성우명을
표기하는 크레딧 오표기 리스크를 피해 CV 행을 만들지 않는다. `lore_cv` 필드
추가 금지, 중앙 타이틀 블록에도 CV 라인 없음. 초안 단계에서 제안됐던 가공
성우명들은 기각 — 히스토리로만 유효.

---

## 2. Slices

착수 순서: **A → B → C → E** (D는 A 완료 후 병행 가능, F는 전부 뒤 선택).
슬라이스마다: 배선 → 씰 스모크 GREEN → 반증검증(in-place 토글) → 픽셀 QA →
다음 슬라이스. **픽셀 QA는 전 슬라이스 공통 필수** — 이 화면은 negative-z
백드롭 호스트가 있어 상태 스모크만으로 사인오프 불가(§3-1).

### Slice A — 에디토리얼 크롬 백본 (절차 드로우, 에셋 0)

- `_draw_background` 리스킨: 딥 다크 베이스 + 미세 그리드/헤어라인 +
  코너 코드 마이크로텍스트. **`backdrop_hole` 구멍 뚫기 로직(378~388행)
  보존 필수** — 불투명 리스킨이 이 구멍을 덮으면 프리뷰 백드롭이 침몰한다.
- `_draw_header`: 한글 대제목 + 영문 소제목 병기, 에디토리얼 코드 라벨.
- 공용 **대각컷 패널 헬퍼** 신설(직사각 + 모서리 사선 컷 폴리곤).
  `draw_colored_polygon` 고정 포인트(애니메이션 오프셋 없음)라 삼각분할 트랩
  비대상이지만, 포인트 배열은 rect 키로 캐시하고 매 프레임 재생성 금지.
- 코너 브래킷은 공용 `PremiumPanelFrame.draw_corner_brackets` 재사용, 패널
  본체는 화면 자체 `_draw_diag_panel()`(대각컷) 사용 — `draw_panel`(라운드
  StyleBox 계열)은 이 화면의 에디토리얼 실루엣과 안 맞아 **미사용**. 기존
  `_draw_corner_ticks`는 브래킷으로 통일 후 제거.
- 카드열/리그탭/확정 버튼/언어 버튼 크롬 교체 (`_draw_character_card`,
  `_draw_league_button`, `_draw_button`, `_draw_language_button`).
- **Seal:** 기존 6종 스모크 GREEN 유지(`character_select_gamepad_navigation` /
  `skill_hover_tooltip` / `language_button` / `confirm_flash_split` /
  `preview_vfx_host_clip` / `preview_vfx_host_lifecycle`) + hole-punch 보존을
  기존 clip/lifecycle 스모크가 커버하는지 확인, 미커버 시 backdrop-hole 회귀
  케이스 추가. + 픽셀 QA(백드롭 활성 상태 필수 포함).
- **✅ 배선 완료 (2026-07-03, Claude).** 기존 clip/lifecycle 스모크는 VFX
  호스트만 커버 → 신규 `character_select_backdrop_hole_smoke.gd` 추가:
  hole 리졸버를 `_resolve_backdrop_hole()`로 추출해 활성/비활성/프리뷰 부재
  3상 + diag 지오메트리(캐시 동일성, 폐루프, 삼각분할, 뷰사이즈 리셋) 봉인.
  반증검증 = 리졸버 in-place 무력화 → 스모크 RED(정확히 hole 어서션) →
  원복 GREEN, 토글 잔존 0건. 셀렉트 스모크 8종(viper_start 포함) GREEN +
  headless load + warning scan 통과. 픽셀 QA = `tools/
  character_select_slice_a_capture.gd`(실씬+백드롭, 1920×1080 / 900×700 /
  900×1200): 데스크톱 정상(hole-punch로 챔버 백드롭 노출 확인).
  `_draw_corner_ticks`는 브래킷으로 통일 후 삭제, `_draw_language_button`
  시그니처는 `(rect)`(중립 크롬)로 변경.

### Slice B — 인포패널 재구성 + 로어 마이크로스탯

- **<980 기존 결함 인계 (Slice A 픽셀 QA 발견, rect 무변경으로 크롬만 교체한
  상태에서 관측):** 모바일 스택 레이아웃에서 (a) `_build_info_panel_layout`의
  `full_body_rect`가 인포 rect 바닥을 넘어 카드열 위로 탈출 — 높이식
  `max(180, rect.end.y - full_body_top - 20)`이 음수 여유를 180px로 승격,
  (b) 액션바(y-98)와 하단 카드열(y-248..y-76)이 세로 겹침, (c) 확정 버튼이
  카드열 위에 얹힘. 전부 기존 결함이며 Slice B 레이아웃 재구성에서 함께
  해소한다(모바일에서 full-body 패널은 여유 부족 시 행 양보 규칙에 따라
  드랍이 기본).

- `_draw_info_panel` 재배치: 역할 라벨(소) → 이름(KO 大) + 클래스 칩 →
  태그라인 → 설명 → 난이도★ → 대표 스킬 행 + 링코어 슬롯 → 기존 스탯 3종.
- `_draw_full_body_live2d_panel`에 "FULL BODY VIEW" 섹션 라벨 +
  HEIGHT/WEIGHT/AFFILIATION 마이크로스탯 열 추가.
  데이터 필드는 `character_select_data.gd`에 `lore_height` / `lore_weight` /
  `lore_affiliation` 으로 추가, 값은 §1-b 확정 테이블(빈 값 = 행 미표시).
  `lore_cv`는 만들지 않는다(§1-b CV 생략 확정).
- **Draw-order 제약 (코덱스 리뷰 P2):** 현재 함수는 시트/스틸 텍스처가 있으면
  중간에서 `return`한다(1611~1617행). 섹션 라벨과 마이크로스탯은 이 early
  return **앞에서** (또는 return 구조를 해체하고 텍스처 분기와 무관한 공통
  경로에서) 그려야 한다 — 뒤에 붙이면 아트가 있는 캐릭터 전원에서 죽은
  코드가 된다. 마이크로스탯 행 높이만큼 `inner_rect`를 줄여 아트와 라벨이
  겹치지 않게 예약할 것.
- **다국어 동슬라이스 랜딩 (코덱스 리뷰 P1):** `localize_character_data`는
  언어별 `CHARACTER_*` 맵에 **있는 필드만** 덮어쓰는 화이트리스트 구조라
  (`language_settings.gd` 339~341행), 한국어 `lore_affiliation` / 이오의
  "(증강 유닛 제외)"가 비한국어 화면에 그대로 샌다. 언어맵은 EN/ZH/JA에
  ES/PT-BR/RU까지 **총 6종** — `lore_*` 필드를 6곳 모두 **같은 슬라이스에서**
  추가한다. 섹션 라벨(FULL BODY VIEW / HEIGHT / WEIGHT / AFFILIATION)은
  에디토리얼 영문 마이크로텍스트로 고정해 i18n 대상에서 제외.
- **행 예산 규칙:** 인포패널은 고정 rect다. 최대 케이스(가장 긴 설명 +
  마이크로스탯 전부 + 스탯 3종)가 1080p와 **<980 스택 레이아웃 양쪽**에서
  잘리지 않음을 draw-time capacity로 검증 — 넘치면 어느 행이 양보하는지 명시
  (권장: 마이크로스탯 행부터 드랍). 스탯패널 행 예산 트랩(§3-8)과 동형.
- **Seal:** 신규 스모크 `character_select_info_panel_layout_smoke.gd` —
  전 캐릭터 × 양 레이아웃에서 섹션 rect가 패널 경계 내인지 + 로어 필드
  누락 시 행이 생략되는지(placeholder 미출력) 어서션. +
  `localization_coverage_smoke` GREEN(en/ja/zh에서 lore 한글 노출 0건).
  + 픽셀 QA — 풀바디 아트가 **있는** 캐릭터에서 마이크로스탯이 실제로
  그려지는지 반드시 확인(early-return 제약의 가시 검증).
- **✅ 배선 완료 (2026-07-03, Claude).** 로어 데이터 = §1-b 값으로
  `character_select_data.gd` 5캐릭 + 6개 언어맵 전부 동시 랜딩(이오
  `lore_weight` 각주 포함). 풀바디 패널 = FULL BODY VIEW 라벨 + 스택형
  마이크로스탯 3행을 텍스처 분기 **앞에서** 드로우, 아트 rect가 라벨/행
  밴드만큼 축소. `_build_info_panel_layout`의 풀바디 탈출 수정(여유<120px
  → 빈 rect로 양보). <980 스택 재구성 = `_mobile_action_bar_bottom_y` +
  `_action_bar_layout` 순수 헬퍼 추출, 모바일은 한 줄 액션 행(뒤로/리그3탭/
  확정)이 카드열 위에 배치되어 겹침 3건 전부 해소. 추가 발견 = 인포패널
  콘텐츠 rect 넘침(700px 높이) → `_info_panel_visible_blocks` 행 예산
  게이팅(위→아래 우선, 넘치는 블록 드랍) 도입. 씰 =
  `character_select_info_panel_layout_smoke.gd`(풀바디 봉쇄/행 예산/모바일
  비겹침/6언어 로어 한글누수 0건), 반증검증 2건(탈출 원복 토글 + EN 로어
  제거 토글 → 각각 정확한 어서션 RED → 원복 GREEN, 잔존 0건). 셀렉트
  스모크 8종 + `localization_coverage_smoke` + headless load + warning
  scan 전부 GREEN. 픽셀 QA 3사이즈 — 데스크톱 마이크로스탯 렌더 확인,
  모바일 겹침 0. 참고: `_draw_stats`(속도/파워/방어)는 호출처 0의 기존
  죽은 코드라 재배치 대상 아님(§1 "유지"는 삭제 금지 의미로 충족).
- **코덱스 Slice B 리뷰 P3 반영 (2026-07-03).** (1) <980 모바일 액션바가
  ~566px 미만에서 확정↔신화 탭 겹침 → **640px 미만 2행 폴백**(확정 CTA
  전용 행이 탭 행 위) 도입, `_mobile_action_band_top()`으로 인포/프리뷰
  예산 연동. 씰 = layout 스모크 모바일 루프에 560×900/420×800 추가 +
  confirm∩junior/뷰 경계 어서션, 반증(폴백 무력화 → 두 좁은 폭 정확 RED).
  실질 하한 ≈360px(액션 행 최소 합계) — 그 미만 폭은 미지원. (2) diag 캐시
  캡 off-by-one `>` → `>=`. 픽셀 QA `narrow_560` 샷 추가로 2행 폴백 육안
  확인.
- **부수 발견/수정 (2026-07-03, 스코프 외 1건):** 엔트리 배경 프리웜이
  스테이지1 결과 에셋 dict의 `dalji_click_voice`(mp3)를 텍스처로 로드
  시도(매 세션 디코드 ERROR). `TEXTURE_PATH_EXTENSIONS` 화이트리스트
  가드 + `battle_entry_background_prewarm_smoke` 씰 + 반증 완료. 트랩
  백필: `docs/godot_runtime_traps.md` Threaded Texture 섹션.

### Slice C — 중앙 히어로 프레이밍 + 타이틀 타이포

- `_draw_preview_frame`: 대각컷 히어로 프레임(Slice A 헬퍼 재사용) +
  프레임 내 하단 타이틀 블록(캐릭터명 KO 大 / EN 소 / 클래스 칩 — CV 라인 없음).
  애니메이션 프리뷰(`LivePreview`)는 그대로 유지(D5) — 프레임과 타이틀이
  프리뷰 위에 얹히므로 캐릭터 발/이펙트와 겹침 여부 픽셀 QA.
- ~~음성 버튼~~ — **D6 개정으로 제거 (2026-07-03).** 캐릭터 클릭 시 재생되는
  기존 클릭 모션 보이스가 이 기능을 이미 수행한다. 초판에 있던 마우스 전용
  입력 모델 결정과 보이스 위임 씰 요구는 폐기(히스토리로만 유효).
- **Seal:** 기존 셀렉트 스모크 GREEN 유지 + 픽셀 QA(타이틀 블록과 프리뷰
  캐릭터 발/이펙트 겹침 확인).
- **코덱스 Slice C 리뷰 P2 반영 (2026-07-03).** narrow+short 창(420×700 등)
  에서 preview 최소 180px / info 최소 80px 고정 승격이 예산을 초과해 액션
  밴드를 침범 → **예산 연동형**으로 교체: 총 예산에서 info 예약(96+16)은
  담길 때만(≥176px), preview 플로어는 64px, info는 부족 시 **완전 빈
  Rect2()로 양보**(0높이 rect는 position이 살아 있어 `intersects()`가
  true를 반환하는 퇴화 트랩 — 빈 rect 반환이 정답). `_draw_info_panel`에
  높이<48px 스킵 가드(+skill_icon_rects 클리어). 씰 = 모바일 루프에
  560×700/420×700/420×600 추가 + preview∩confirm/탭 어서션, 반증(구 로직
  복원 → 코덱스 지적 케이스 3개 전부 정확 RED). 물리적 하한 ≈480px 높이
  (카드열 248 + 액션밴드 104 + 헤더 108 + 최소 프리뷰) — 그 미만 미지원.
  픽셀 QA `narrow_short_420` 샷 추가.
- **✅ 배선 완료 (2026-07-03, Claude).** 타이틀 블록 오너는 스크린이 아니라
  프리뷰 자식 `character_live_preview.gd`의 `_draw_nameplate`(기존 클래스
  라벨+이름 센터 배치를 그대로 진화) — 클래스 칩(악센트 보더 박스) + 이름
  KO 大(30px) + 라틴 병기 소(11px, 악센트). 라틴 표기는
  `character_select_data.gd` 신규 `name_latin`(MIKA/RENA/KOHAKU/IO/SERIN,
  ASCII = i18n 면제). **라틴 로케일 중복 가드**: `name_latin`이 표시명과
  대소문자 무시 동일하면(EN/ES/PT/RU) 병기 라인 생략 — "Mika/MIKA" 중복
  방지. 저높이(<240px) 프리뷰에서도 병기 라인 생략. 씰 = layout 스모크에
  `name_latin` ASCII 어서션 추가, 프리뷰 계열 스모크 6종 + repo 게이트
  GREEN, 픽셀 QA 4사이즈(칩+KO+라틴 렌더 확인).

### Slice D — 배경 시티스케이프 에셋 (A 완료 후 병행 가능)

- **생성기 = Codex imagegen (2026-07-03 사용자 결정).** Claude 디렉션(아래
  스펙) → Codex 생성 → Claude 수용 판정(무드/픽셀 QA) → Claude 통합 배선.
  Gemini는 폴백. FLUX 금지 유지. 스틸 1장이므로 AutoSprite 시트 규칙 비대상.
- **생성 스펙 (Claude 디렉션):**
  - 다크 사이버펑크 도시 야경, 페인티드 애니 배경 스타일, 16:9, 1920×1080급.
  - **중앙 밴드는 저명도·저디테일** — 캐릭터 스프라이트가 위에 서므로 중앙
    피사체/전경 오브젝트 금지, 캐릭터 실루엣 가독성이 1순위 수용 기준.
  - 상/하단 자연스러운 다크 폴오프(대각컷 프레임 크롬과 만나는 경계).
  - 악센트 라이팅은 시안/틸 계열만(D1 중립 크롬과 조화) — **레드 네온 금지**
    (레드 단일 팔레트는 D1에서 기각된 방향).
  - 불투명 풀씬(알파 불필요). 원경 네온 사인/헤이즈/빗기운 등 분위기 요소는
    자유, 단 중앙 가독성 우선.
  - 5캐릭 색변형은 **런타임 틴트 우선 검토**(에셋 1장 + modulate) — 톤이
    안 나오면 그때 변형 생성으로 승격.
- **Replace only (코덱스 리뷰 P2로 잠금):** backdrop host
  (`character_select_preview_vfx_host.gd`)의 기존 챔버 백플레이트 텍스처를
  **같은 레이어 슬롯에서 교체**한다. 레이어 추가 금지 —
  `character_select_preview_vfx_host_clip_smoke`가 `texture_layers == 2`를
  고정 어서션하고 있고(34행), 이 기대값은 유지한다. 레이어 구조 변경이
  필요해지면 스모크 기대값 변경을 포함한 별도 결정으로 승격.
- **로드 규칙:** `load_imported_texture` 경로 + size_limit 준수(raw PNG 우회
  금지 — §3-3), `character_select_prewarm` / 기존 프리웜 경유(핫패스 lazy
  instantiate 금지), **에셋 파일과 배선을 같은 슬라이스에서 함께 랜딩** +
  `file_exists` 어서션(§3-4).
- **Seal:** `large_texture_raw_decode_audit_smoke` GREEN +
  `preview_vfx_host_lifecycle` GREEN + 픽셀 QA(캐릭터별 틴트 변형 포함 시
  5캐릭 각각).
- **✅ 배선 완료 (2026-07-03).** 후보 = Codex built-in image_gen 1차 시안
  **1발 수용**(4개 기준 전부 충족 — 중앙 헤이즈 밴드/시안·틸 단일 악센트/
  다크 폴오프/불투명 풀씬). 에셋 =
  `character_select_city_backdrop_imagegen_v1.png`(1920×1080, 1672×941
  원본은 `*_source_1672.png`로 보존, 구 챔버 PNG는 롤백 참조로 유지).
  배선 = `DEEP_BACKPLATE_PATH` 상수 스왑(로더/프리웜 스펙이 같은 상수를
  참조해 spec/loader 동기화 자동 충족) + **스트레치 버그 예방**: 공유
  `STRETCH_SCALE`이 16:9를 프리뷰 비율(~1.33)로 압착하므로 백플레이트만
  `STRETCH_KEEP_ASPECT_COVERED`로 커버 크롭. 씰 = backdrop_hole 스모크에
  `FileAccess.file_exists(DEEP_BACKPLATE_PATH)` 어서션(§3-4) + clip 스모크
  `texture_layers==2` 유지 + raw decode 감사 GREEN + repo 게이트. 픽셀 QA
  5사이즈 — 도시 야경 위 캐릭터/만다라 가독성 확인. 5캐릭 색변형은 런타임
  틴트 검토로 백로그 유지(에셋 1장 체제).

### Slice E — 마이크로텍스트 타이포 패스 + 다국어

- `_get_ui_font(scale)` 헬퍼 이식(레퍼런스: `pause_menu_overlay.gd` /
  `defeat_settlement_screen.gd` — FontVariation `spacing_glyph`). 작은 한글
  라벨(마이크로텍스트/칩/코드라벨) 전부 이 경유로 전환. **FontVariation은
  scale 키로 캐시** — `_draw` 안 매 프레임 생성 금지.
- 신규 문자열 번역은 **도입 슬라이스에서 이미 랜딩**되어 있어야 한다(§4
  동슬라이스 i18n 규칙). Slice E는 번역을 새로 넣는 곳이 아니라 **최종
  커버리지 감사** — 전 슬라이스가 남긴 누락을 잡는 마지막 그물이다.
- **Seal:** `localization_coverage_smoke` GREEN + **일본어/중국어 화면 픽셀
  QA**(명시 Nanum 폰트 CJK 글리프 드롭 트랩 — §3-6) + 소형 라벨 글리프 겹침
  육안 확인.

### Slice F — 폴리시/주스 (선택, 전 슬라이스 뒤)

- 호버/선택 전환 이징 리튠, 선택 카드 펄스, 확정 버튼 프리미엄 강조,
  `confirm_flash_overlay`와 새 팔레트 톤 정합.
- **Seal:** `confirm_flash_split_smoke` GREEN + 픽셀 QA. 시간 누적형 효과가
  있으면 10초+ 방치 확인(연속회전 텀블 트랩).

---

## 3. Traps (전 슬라이스 공통 — 배선 전 필독)

1. **Negative-z 백드롭 호스트 매장 트랩.** 프리뷰 VFX 호스트는 음수 z에서
   그린다. `_draw_background`의 `backdrop_hole` 구멍이 사라지면 백드롭이
   통째로 덮이는데 **상태 스모크는 전부 GREEN**이다. 사인오프 = 픽셀 QA 필수.
   전문: `docs/godot_runtime_traps.md` (Negative-Z Backdrop Host).
2. **draw_set_transform 금지.** 대각컷/기울임은 폴리곤 포인트로 직접 계산.
   `_draw` 안 transform+IDENTITY 리셋 패턴 금지.
3. **`load_texture`는 raw PNG 우선 → size_limit 무시.** 대형 배경/시트는
   `load_imported_texture` + 스트리밍 경로. 레퍼런스:
   [[feedback_godot_load_texture_raw_bypass]].
4. **예약-부재 에셋 per-frame re-stat.** 아직 없는 에셋 경로를 draw 경로에
   먼저 배선 금지 — 에셋+배선 동일 슬라이스 + `file_exists` 어서트.
5. **작은 한글 라벨 글리프 겹침.** fallback 폰트 작은 px에서 음절 겹침 →
   FontVariation `spacing_glyph`(`_get_ui_font(scale)` 패턴) 경유.
6. **명시 Nanum 폰트는 CJK 드롭.** 일/중 화면 QA 없이 폰트 명시 변경 금지.
7. **다국어 동기화.** 신규/변경 문구는 grep 0건으로 "번역 없음" 단정 금지 —
   숫자 변형까지 grep + coverage 스모크 봉인.
8. **패널 행 예산.** 고정 rect 패널의 행 오버플로는 소리 없이 드랍된다.
   최대 콘텐츠 상태(가장 긴 캐릭터 + 전 행 표시)로 검증, 양보 행 명시.
9. **마우스/게임패드/키보드 입력 경로 분기.** 신규 버튼은 클릭 핸들러와
   패드 내비 latch 양쪽 배선 — 한쪽만 고치는 게 상습 실패 패턴.
10. **Control 예약 프로퍼티 섀도잉.** `extends Control` 스크립트에 신규
    `var rotation/position/size/scale` 금지.
11. **프레젠터→base preload 상속 순환.** UI 프리미엄 리스타일 커밋에서 확인된
    함정 — 크롬 헬퍼 분리 시 preload 방향 주의. PackedArray는 const 불가.
12. **절차 크롬 프레임 비용.** StyleBox/FontVariation/폴리곤 포인트는 static
    캐시 재사용(`PremiumPanelFrame` 패턴). 메뉴 화면이지만 매 프레임
    `queue_redraw` 루프가 도는 화면이므로 per-frame 할당 금지.
13. **반증검증은 in-place 토글만.** `git reset`/`checkout`/`stash` 금지 —
    이 리포는 미커밋 WIP가 상시 존재한다.
14. **`localize_character_data` 화이트리스트 덮어쓰기.** 캐릭터 dict의
    비한국어 표시는 언어별 `CHARACTER_*` 맵에 등록된 필드만 교체된다 —
    캐릭터 dict에 새 표시용 필드를 추가하면 **6개 언어맵**(EN/ZH/JA/ES/
    PT-BR/RU)에 같은 필드를 추가하기 전까지 한국어 원문이 그대로 샌다.
    grep 0건 ≠ 번역 불필요 ([[feedback_godot_localization_copy_sync]]).

---

## 4. Verification gates

- **슬라이스 공통:** 해당 씰 스모크 GREEN → 반증검증(핵심 가드 1개 in-place
  토글로 RED 확인 후 원복) → 윈도우드 픽셀 QA(1920×1080 + <980 스택
  레이아웃 양쪽, 백드롭 활성 상태 포함).
- **`.gd` 수정 슬라이스 공통 (repo 게이트, `AGENTS.md`):** `godot/`에서
  `.\tools\run_headless_load_check.ps1` + `.\tools\run_warning_scan.ps1`
  둘 다 사인오프 조건. warning-scan의 Godot exit -1은 파서 에러가 아니라
  flaky — 재실행으로 회복 확인 후 판정.
- **신규 노출 문자열 동슬라이스 i18n 규칙:** 사용자 가시 문자열(섹션 라벨,
  버튼, 로어 값)을 도입하는 슬라이스가 ko/en/ja/zh 번역을 **같은 슬라이스에서**
  랜딩한다. Slice E로 번역 부채 이월 금지 — `localization_coverage_smoke`가
  비한국어 로케일의 한글 노출을 잡는다.
- **최종:** 전체 스모크 게이트 + 라이브 QA(5캐릭 순회 — 잠금 캐릭터 포함,
  리그 3탭 전환, 언어 4종 전환, 확정 플로우 → 전투 진입) + 커밋 전
  체크리스트 백필 판단(신규 트랩 발견 시 `docs/godot_runtime_traps.md` 경유).

## 4-b. v2 — 라운드 통일 레이아웃 개편 (2026-07-03 사용자 승인)

2차 레퍼런스(밝은 톤 서브컬처 모바일 스타일 목업) 기반 개편. **레이아웃/
형태 언어만 채택, 톤은 현행 다크 유지**(하늘색/화이트 팔레트 불채택).

| # | 결정 |
|---|---|
| D7 | 인포 패널 폐지·흡수: 난이도★/대표 스킬/링코어 = 히어로 오버레이(우상단). **개정(2026-07-03, 사용자 피드백 "전신 라투디 어디 갔음")**: 풀바디 뷰 폐지 판단은 오류 — 히어로 프리뷰는 상반신 라투디라 전신 뷰가 유일한 전신 노출 창구였음. **우측 전신 레일로 복원**(`_full_body_rail_rect` + 라운드 SECTION 컨테이너 + Slice B 드로어 재사용 = FULL BODY VIEW 라벨 + HEIGHT/WEIGHT/AFFILIATION). 소속 줄은 레일이 오너, 레일 부재 시에만 타이틀 블록 폴백(`nameplate_show_affiliation` 프로퍼티로 스크린→자식 통신). 레일은 히어로 최소 560px 보장 못 하는 좁은 데스크톱에서 양보 |
| D8 | 말풍선 캐릭터 대사 **제외** (2026-07-03 사용자) |
| D9 | 형태 토큰 = 라운드 카드 언어로 통일(`PremiumPanelFrame` 라운드 계열 재사용 — 게임 전체 프리미엄 패널 언어와 일치). 대각컷은 단계적 폐지 |
| — | D1(다크+캐릭터 악센트)/D2·Slice D(시티 백드롭)/D3(로어+CV 생략)/D4(학생정보 제외)/D5(애니메이션 유지)/D6(음성버튼 제거)/`name_latin` 전부 유지. 목업의 음성·CV·학생정보 요소는 되살리지 않음 |

**v2 슬라이스** (검증 스택은 v1과 동일 — 씰/반증/게이트/픽셀 QA):
- **G1 — 통일 토큰 + 카드열 가로형 개편**: 카드열 폭 확대 + 가로형 카드
  (초상 썸네일 좌 + 이름 + 역할 태그 + 선택 악센트 보더/화살표), 버튼/리그
  탭/언어 버튼 라운드 토큰 전환. 모바일(<980) 하단 카드 행은 세로형 유지.
  - **✅ 배선 완료 (2026-07-03).** 카드열 246~292px 확대(프리뷰/인포 rect는
    파생이라 자동 적응), `_draw_character_card`가 가로세로비>1.5에서
    `_draw_character_card_horizontal`로 분기(모바일 세로형 경로 보존).
    가로 카드 = `PremiumPanelFrame.draw_panel(KIND_SECTION)` 다크 글래스 +
    얼굴 크롭 썸네일(기존 `_character_card_face_source_rect` 재사용) + 이름
    16px + 역할 태그(악센트 다이아 글리프 + role 텍스트, 로컬라이즈 기존
    필드) + 선택 화살표 ▸ + 잠금 배지. 버튼 토큰 = CTA는 `KIND_MAIN`(할로),
    보조 버튼/리그 탭은 `KIND_SLOT` + 선택 하단 바(브래킷/대각컷 제거).
    데스크톱 카드열 컨테이너 박스 제거(카드가 배경 위에 부유). 씰 = 셀렉트
    스모크 7종 GREEN + headless load 통과 + 픽셀 QA 5사이즈. **주의:**
    warning scan은 외부 동시작업 파일
    (`tests/commando_supply_drop_aircraft_crash_smoke.gd` 파스 에러 —
    미존재 함수 2개 참조)로 RED — 본 슬라이스 파일들은 스모크 로드로 파스
    정상 입증, 해당 파일은 코만도 무전콜 WIP 소유자 몫.
- **G2 — 히어로 확장 + 워터마크 + 타이틀 이동**: 인포 패널 자리를 히어로가
  흡수(프리뷰 우측 확장), `name_latin` 대형 워터마크(초저알파, 백드롭 위·
  캐릭터 뒤), 타이틀 블록 좌하 정렬, 히어로 프레임 라운드 전환.
- **G3 — 인포 흡수 + 정리**: D7 컴팩트 행(난이도/스킬/링코어) + 소속 1줄
  배선, 인포 패널/풀바디 패널 코드·스모크 정리(신규 레이아웃 씰로 교체),
  상단 뒤로 화살표 이동 검토.
- **✅ G2+G3 통합 배선 완료 (2026-07-03)** — G2 단독은 인포가 갈 곳을 잃는
  깨진 중간 상태라 통합 실행. (1) 히어로 확장: `_preview_rect` 데스크톱이
  인포 자리 흡수(우측 마진까지), `_info_panel_rect` 데스크톱 = 빈 Rect2
  (모바일 스택은 유지). (2) `name_latin` 워터마크 118px α0.055 — 스크린이
  자식 아래를 그리므로 백드롭 위·캐릭터 뒤에 정확히 앉음. 히어로 프레임
  라운드(KIND_SECTION 보더) + 하단 악센트 바. (3) 타이틀 블록 좌하 정렬
  (칩/KO 34px/라틴/소속 1줄, `_draw_left_text` 신설, compact<240px 가드).
  (4) 히어로 인포 오버레이 `_draw_hero_info_overlay`: 난이도★+스킬 3+링코어
  (+잠금 시 컴팩트 해금 안내) — **우상단 앵커**(픽셀 QA 발견: 자식의 하단
  에이프런/셔라우드가 하단 코너를 덮어 스크린 드로우가 묻힘. "코너=자식
  투명" 가정은 상단만 유효). (5) 역할 태그 fit 헬퍼
  `_role_tag_draw_spec`(10→9px 축소 후 말줄임) + 스모크 씰 — **RU 역할명
  2건이 실제로 예산 초과 적발**(코덱스 G1 메모 적중) → RU 번역 컴팩트화
  ("Ядро атаки"/"Контроль боя"). (6) `viper_start` 스모크의 v1 그리드 계약
  (프리뷰-인포 갭/폭 비율)을 v2 계약(인포 rect 空 + 뷰 경계)으로 갱신,
  풀바디 플로어 패리티는 합성 rect로 데이터 씰 보존. 반증검증 = 유기 완결
  (신코드×구스모크 RED → 계약 갱신 GREEN + RU 실데이터 RED → 수정 GREEN).
- **⤴ G3b 철회 (2026-07-03, D7 개정)**: 전신 레일 복원으로 풀바디 시트
  로딩/프리웜 원상복구, viper_start 부정 씰 5건 → 양성 복원. layout 스모크에
  레일 씰 추가(와이드 가시+비겹침+뷰 내부 / 좁은 데스크톱 양보). 아래 G3b
  기록은 히스토리로만 유효 — 패널을 다시 은퇴시키려면 사용자 결정 필수.
- ~~**✅ G3b 완료 (2026-07-03)**~~: 풀바디 Live2D 시트 로딩/프리웜 은퇴.
  `_load_portraits`의 시트/스틸 로드 제거(raw-first `load_texture`로 7168²
  ×5장을 올리던 경로 소멸), `character_select_prewarm`의 풀바디 잡 + 죽은
  `_primary_full_body_path` 헬퍼 제거. viper_start의 양성 어서션 5건
  (런타임 로드 2 + 프리웜 3)을 **부정 씰**("must not load/prewarm")로 전환 —
  로딩 재도입 시 즉시 RED. 데이터 필드/자산 계약 어서션(트림·스케일·시트
  치수)과 플로어 패리티 데이터 씰은 보존(패널 부활 대비). 반증 = 로드 블록
  임시 복원 → 부정 씰 2건 정확 RED → 원복 GREEN. 스모크 8종 + headless +
  warning scan(2129 스크립트, 0 워닝) GREEN, 캡처 5사이즈 시각 무회귀.
  G2+G3 픽셀 QA 보류 건도 각시탈 편집 랜딩 후 코덱스 재캡처 + Claude 수용
  판정으로 해소 완료.
- **⚠️ G2+G3 픽셀 QA 최종 재캡처 보류**: 마지막 2건 픽셀 수정(타이틀 여백
  +오버레이 우상단 이동) 후 재캡처 시점에 외부 각시탈 세션이
  `battle_resources.gd`에 `GAKSITAL_FAN_WIND_SHEET_PATH` 미선언 참조(사용처
  1254행만 저장, 상수 선언 미저장)를 남겨 컴파일 체인이 깨짐 — 셀렉트 화면
  스크립트가 이 체인에 물려 캡처 무효. 해당 편집이 랜딩되면 재캡처만 하면
  됨(로직 씰/게이트는 깨지기 전 전부 GREEN 확인).

### Slice H — 개방감 패스 (2026-07-04 사용자 승인, ✅ 배선 완료)

레퍼런스와의 잔여 인상 차이("액자 속 그림" vs "배경 위 부유") 해소.

- **① 백드롭 풀스크린**: VFX 호스트를 LivePreview 클립에서 **스크린이 입양**
  (`_adopt_backdrop_host` — reparent + z=-20 유지, `move_child 0`). LivePreview
  는 `vfx_host_external_layout=true`로 레이아웃 쓰기를 중단(캐릭터/인터랙션/
  look_offset 싱크는 유지 — 오브젝트 참조라 부모 무관). 호스트에
  `set_stage_rect()` 신설: 만다라/모트는 히어로 스테이지 기준, 백플레이트/
  배경은 풀 호스트. 스크린 배경은 백드롭 활성 시 **불투명 필 전면 금지**
  (`_backdrop_fullscreen_active()` — hole-punch 트랩의 풀스크린 변형) +
  비활성 시 불투명 폴백. `_draw_rect_excluding_hole`/`_resolve_backdrop_hole`
  은 새 모델로 대체·삭제, backdrop_hole 스모크 계약 갱신.
- **② 악센트 앰비언트 워시**: 백드롭 위 캐릭터 악센트 5% 워시 — 도시 무드가
  선택 캐릭터와 커플링(백드롭 자체 틴트 금지 규칙은 유지 — 워시는 위에 얹는
  레이어).
- **③ 정보 응집**: 난이도★/대표 스킬/링코어(+잠금 안내)를 히어로 우상단
  오버레이에서 **레일 상단 헤더**로 이사(레퍼런스 우측 컬럼 구도와 일치),
  `_draw_hero_info_overlay` 삭제.
- **프레임리스 후속 픽셀 수정 2건**: (a) 시안 카드 프레임의 실소유는
  LivePreview 자식 `_draw_preview_card_frame` — `preview_card_frame_enabled`
  플래그로 게이트(입양 시 false). (b) bottom apron 풀폭 밴드가 하드 엣지
  노출 → `_draw_hband_faded`(좌우 16% 버텍스컬러 페이드)로 교체.
- **검증**: 셀렉트 스모크 10종 + headless + warning scan GREEN, 픽셀 QA
  5사이즈 — 도시가 화면 전체, 카드/레일 부유, 프레임리스 히어로+워터마크,
  레일 헤더 응집 확인. 자식의 불투명 폴백(`_draw_preview_backdrop`)은 기존
  호스트-활성 게이트가 그대로 유효(reparent 후에도 참조 유지).
- **카드 확대 (2026-07-04 사용자 피드백 "작고 답답함")**: 카드 높이 86→126,
  초상을 8px 인셋 정사각 썸네일에서 **좌측 하프 패널**(카드 폭 44%, 풀
  하이트, 3px 인셋 엣지블리드)로 확대 — 레퍼런스의 큰 얼굴 크롭 재현(기존
  `card_face_focus` 크롭 재사용). 이름 18px. 태그 예산 102→90(화살표는 태그
  행과 세로 비겹침이라 예약 제거, 우측 마진 8만). **씰이 초과 2건 적발**
  (es/blacksmith "Guardiana de la forja", pt-BR/viper "Assassina
  cibernética") → 컴팩트 번역("Guardiana de forja"/"Ciberassassina").
  스모크 5종(다국어 커버리지 포함) + 게이트 + 픽셀 QA GREEN.
- **유기 카드 리셰이프 (2026-07-04 사용자 피드백 "사각형 틀에 딱딱 AI스러움")**:
  레퍼런스의 "굴곡" 분해 = 큰 라디우스 + **컷아웃 실루엣이 곧 경계**(사진
  박스/구분선 없음) + 그림자·간격 구분. 반영: (a) 로스터 카드 전용 라디우스
  16 StyleBox(`_get_roster_card_box`, 그림자 10px — PremiumPanelFrame 공유
  박스는 radius 8 고정이라 화면 로컬 뮤터블 1개 재구성 패턴), (b) idle 보더
  α 65% 감쇄(구분=그림자), (c) 초상 = 컷아웃 PNG(`*_cutout_clean_padded`)를
  크롭 박스·헤어라인 없이 카드 필 위에 직접 블렌드(폭 56%, 실루엣이 텍스트
  존으로 유기적으로 흐름) + 헤드 뒤 악센트 라디얼 글로우 2겹, (d) 선택 카드
  내부 코너 브래킷 + 화살표, 잠금 배지는 카드 좌상단으로. 태그 예산 재검
  (text_left=50% → 93px ≥ 90 씰 유지). 스모크 4종 + 픽셀 QA GREEN.
  잔여 마이너: 컷아웃 사각 모서리가 라디우스 16 아크를 미세 침범(주로 잠금
  이오 카드 좌하) — 라이브 QA에서 거슬리면 포트레이트 인셋 +2px 레버.
  **주의**: warning scan은 외부 동시작업 `stage4_ponk_illusion_ripple_smoke`
  파스 에러(미존재 함수 4개)로 RED — 본 슬라이스 파일은 headless+스모크로
  파스 정상 입증, 해당 파일은 폰크 WIP 소유자 몫.
- **레일 리파인 (2026-07-04 사용자 피드백 "레일이 레퍼런스보다 허접")**:
  원인 분해 = ①섹션 라벨 부재(아이콘이 부유 장식으로 읽힘) ②아트가 거대한
  플랫 다크 보이드에 떠 있음(아트 종횡비 0.59 vs 영역 0.36) ③레퍼런스는
  CTA까지 패널에 통합된 완결 컬럼. 반영: (a) 헤더에 "대표 스킬"/"링코어"
  라벨 복원(기존 translate 키), (b) 해치 보이드 → **아트 이너 서브카드**
  (radius 16 로컬 박스 재사용, 라이터 필+악센트 라디얼 글로우 2겹+절차
  다이아 데코 3개 — 유니코드 ✦ 대신 폴리곤=tofu 안전), (c) **확정 CTA를
  레일 하단에 도킹**(`_action_bar_layout`이 레일 가시 시 레일 밴드 사용,
  레일은 66px 예약) — 빈 공간이 정확히 흡수되어 아트가 서브카드를 채움.
  스모크 5종 + headless GREEN + 픽셀 QA(레퍼런스 우측 컬럼 구도 재현 확인).
  warning scan은 위 폰크 외부 파스 에러로 계속 RED(본 건 무관).
- **워터마크 오블리크 (2026-07-04)**: `name_latin` 워터마크에 시어 행렬
  기울임(y축 x성분 -0.22). draw_set_transform 트랩 준수 근거 = identity
  리셋 실패 모드는 같은 캔버스의 선행 transform이 전제인데 이 화면 `_draw`
  는 다른 transform이 전무 → identity == 이전 상태. 이 전제 자체를
  backdrop_hole 스모크에 소스 grep 씰로 봉인(`draw_set_transform_matrix(`
  정확히 2회 + 위치형 `draw_set_transform(` 0회 — 코멘트 토큰 오카운트
  1차 RED 후 호출 시그니처 기준으로 정밀화).

### Slice I — 캐릭터별 테마 백드롭 (2026-07-04 사용자 승인, 에셋 대기)

배경이 선택 캐릭터마다 테마 전환. 과거 "per-char 틴트 색충돌 → 변형 생성으로만"
교훈([[project_char_select_backdrop_vfx]])의 정석 실행. **생성 = Codex
image_gen**(Slice D 전례), Claude = 스펙/수용 판정/통합 배선.

- **미카 = 신규 생성 불필요**: 현재 시안 도시(`character_select_city_backdrop_
  imagegen_v1.png`)를 미카 전용으로 승격. 신규 4장만 생성.
- **공통 스펙 (Slice D 기준 승계)**: 다크 사이버펑크 야경, 16:9 ≥1920×1080,
  **중앙 밴드 저명도·저디테일·피사체 금지**(캐릭터 실루엣 가독성 1순위),
  상하단 다크 폴오프, 불투명 풀씬. 레드 네온 금지 유지. **주광색 = 해당
  캐릭터 `card_color` 계열**(채도 절제, 다크 톤 유지).
- **캐릭터별 테마 디렉션**:
  | 캐릭터 | 악센트 | 테마 |
  |---|---|---|
  | 레나 | 그린/올리브 | 군사 전초기지 야경 — 격납고 실루엣, 관제탑, 서치라이트 빔, 올리브·앰버 계기광 |
  | 세린 | 퍼플 | 어쌔신 루프탑 뒷골목 — 보라 네온 간판, 젖은 골목 반사광, 안개 낀 옥상 스카이라인 |
  | 코하쿠 | 앰버/골드 | 단조 공방 지구 — 용광로 글로우, 굴뚝 불꽃 입자, 따뜻한 앰버 창광 도시 |
  | 이오 | 블루 | 데이터 시티 — 홀로그램 카드 파편이 떠다니는 전자빛 시가지, 쿨블루 회로 광맥 |
- **통합 배선 (에셋 수용 후, §3-4 에셋+배선 동일 슬라이스)**:
  `DEEP_BACKPLATE_PATH` 단일 상수 → `BACKPLATE_PATHS` per-char dict
  (`MANDALA_PATHS` 패턴 복제), `set_character`에서 스왑, 누락 캐릭터는 미카
  시티 폴백. `get_vfx_texture_paths()`가 5장 전부 포함(스펙/로더 동일 함수
  = 동기화 자동). 씰 = backdrop_hole 스모크 file_exists를 5장 루프로 확장 +
  clip 스모크 `texture_layers==2` 유지. 픽셀 QA = 5캐릭 각각.
- **✅ 배선 완료 (2026-07-04).** Codex image_gen 4장 **전부 1발 수용**
  (레나=관제탑+서치라이트 올리브/세린=퍼플 루프탑 미스트/코하쿠=용광로
  앰버-골드(레드 판정: 오렌지-골드 대역으로 안전)/이오=홀로카드 데이터
  블루 — 이오는 "카드 사이클러" 정체성까지 반영). 후보 4장 개명(candidate
  마커 제거 + 고아 .import 4개 정리), 1672 원본은 Codex 폴더 보존.
  `_apply_texture_assets`가 만다라와 같은 지점에서 백플레이트 스왑,
  `_build_texture_layer` 초기 빌드도 getter 경유. 씰 = file_exists 5장
  루프 + unknown id 미카 폴백 어서션. 캡처 하네스에 데스크톱 5캐릭 순회
  샷 추가 — 세린(퍼플)/코하쿠(앰버) 인게임 확인: 화면 전체(카드/레일/CTA/
  워터마크)가 캐릭터 무드로 통합. 참고: 코하쿠 대표 스킬 아이콘이
  placeholder 도트로 보이는 건 기존 데이터(발토르 스킬 아이콘 PNG 미지정)
  — Slice I 무관, 별도 백로그.
- **코덱스 Slice I 리뷰 P1 해소 (2026-07-04)**: 신규 4장의 `.png.import`
  사이드카 부재 적발 — 캡처에서 배경이 보인 건 **raw PNG 동기 디코드
  폴백**이었음(사이드카 없으면 스레디드 프리웜 제외 + 익스포트 누락,
  `-s` 스크립트 실행은 임포트 스캔을 돌리지 않음). 처리 순서 = 씰을
  `texture_resource_exists`까지 확장 → **RED 4건 목격**(유기 반증) →
  `godot --headless --import` 패스 → 사이드카 4장 생성 → GREEN. 사이드카는
  PNG와 함께 커밋 대상(AGENTS.md 규칙). 스모크 5종 + headless 재확인.
  **P3 정정**: warning scan RED의 현재 원인은 폰크가 아니라(외부에서 해소됨)
  `lingpet_affinity_state.gd`의 `SATIETY_VALUE_SNAP_EPSILON` 미선언(포만도
  WIP) — 해당 작업 소유자 몫.
- **레일 v2 "디바이스 UI" 업그레이드 (2026-07-04 사용자 레퍼런스)**:
  드로어 재구성 — (a) ◆ 다이아 섹션 라벨 헬퍼 `_draw_section_label`
  ("LIVE 2D VIEW"/"INFORMATION", ASCII=i18n 면제), (b) 아트 카드에 홀로
  스테이지: 링 패턴 arc 2 + **발밑 페데스탈**(정점 계산 타원 3겹 + 방사 틱
  16 — `_ellipse_points` 헬퍼, draw_set_transform 금지 준수) + 코너 브래킷,
  (c) **상태 스트립**: 실제 시트 프레임 클록 기반 페이즈 도트 5 + LIVE 2D
  ON/OFF 필(시트 로드 상태 — 가짜 컨트롤 대신 진실한 텔레메트리만, 레퍼런스
  의 일시정지 버튼은 비기능 장식이라 불채택), (d) INFORMATION 2컬럼 행
  (라벨 좌/값 우, 긴 로컬라이즈 값은 measure 기반 스택 폴백 — RU 소속 등).
  스모크 3종 + headless GREEN + 픽셀 QA(레퍼런스 구도 재현 확인).
- **레일 홀로 스테이지 3-피스 전환 (2026-07-04 사용자 지시 "절차 글로우/
  타원 촌스러움 → 3-피스 모듈러 VFX")**: draw_circle 글로우 2 + arc 2 +
  정점 타원 3겹+틱 16을 **페인티드 스틸 2조각**으로 교체 — ①스테이지
  백플레이트(방사 글로우+동심 링+헥스 힌트) ②플로어 프로젝터 링(동심 링+
  방사 틱), Gemini 스틸 생성 → **휘도→알파 베이크**(포털 패턴, 라디얼
  세이프티 마스크, bbox 논-엣지터치, 스크립트 scratchpad/bake_rail_pieces.py)
  → 임포트 패스+사이드카. 중성 화이트-시안 휘도라 **캐릭터 악센트 modulate
  틴트 안전**(에셋 1세트×5캐릭). 원근은 세로 압축 dest rect(transform 불필요),
  모션 = 호흡 sin + 로스터 스위치 엔벨로프(smoothstep 0.45s,
  `_rail_stage_switch_at`). ③파티클은 기존 mote 재사용 예정(전경 클립
  이미터 — 후속). ADD 블렌드 의도는 어두운 카드 위 MIX+휘도알파로 동등
  read라 재료 스위칭 리스크 회피(트랩 §6a 검토 후 결정). 경로 상수는
  호스트 단일 소스 + `get_vfx_texture_paths` 프리웜 합류. 씰 =
  backdrop_hole 스모크에 2조각 file_exists+texture_resource_exists.
  `_ellipse_points` 헬퍼는 폐기(죽은 코드 제거). 스모크 4종 + headless +
  픽셀 QA GREEN.
  - **발광 튜닝 (레퍼런스 비교 2차)**: 카드 내부가 근흑으로 읽히는 갭 →
    ①하단 조명 수직 그라디언트 워시(버텍스컬러 폴리곤, 악센트 0.03→0.105),
    ②백플레이트 알파 0.12+0.46b→0.22+0.52b·사이즈 0.66h→0.72h, ③페데스탈
    이중 드로우(와이드 딤 0.94w + 내로 브라이트 0.55w, 위상차 호흡) — 라이트
    스필 재현. 스모크 2종 + 픽셀 QA GREEN.
  - **⤴ 정적 조각 은퇴 → 상승 랩 에너지 (2026-07-04 사용자 디렉션 "등/바닥
    원형 없애고 에너지가 아래서 위로 몸을 감아 도는 느낌")**: 스테이지
    백플레이트/플로어 링 드로우 제거(PNG 2장은 미배선 롤백 보관, 프리웜/씰
    에서 제외). 대체 = `_draw_rail_energy_pass` — 결정론적 해시 스트림 22개
    (안정 시드 규칙)가 바디 축을 나선 상승, **cos(θ) 깊이로 아트 뒤/앞 2패스
    분리**(뒤 패스 → 아트 → 앞 패스)로 평면에서 진짜 랩 착시. 바디 밀착
    반경 프로파일(sin, 발/머리 좁고 몸통 넓게) + 페이즈 페이드 + 글로우
    스파크+트레일, 스위치 엔벨로프 승계. 아트 브랜치 early-return을
    if/elif/else로 재구성(앞 패스가 항상 실행). 앰비언트 워시는 유지.
    스모크 3종 + headless + 픽셀 QA GREEN(모션은 라이브 QA에서 최종 판정).
- **만다라 확대 (2026-07-04 사용자 피드백 "캐릭터에 가려져 안 보임")**:
  스테이지 대비 `min(0.78w, 0.62h)` → `min(1.02w, 0.90h)`, y 오프셋
  0.085→0.045, 기본 알파 0.25→0.32 — 링이 상반신 아트 실루엣 밖으로 확장.
  clip/lifecycle 스모크 + 픽셀 QA 확인.

## 5. Out of scope (v1)

- 상단 우측 아이콘 행(프로필/기록/홈) — 매핑 기능 없음.
- "학생 정보" 버튼/화면 (D4).
- 캐릭터 일러스트 신규 생성 — 기존 Live2D풍 프리뷰 유지(D5).
- 목업의 레드 단일 팔레트 전면 채택 — D1에서 기각(중립 크롬 + 캐릭터 틴트 확정).
- 분과별 소속 엠블럼 5종 신규 제작 — 아카데미 단일 엠블럼 + 악센트 틴트로 대체(§1-b).
- 음성 버튼 전체 — D6 개정(2026-07-03)으로 제거. 캐릭터 클릭 모션 보이스가
  기능을 대체하며, 게임패드 버튼 포커스 모델도 함께 불필요해짐.
