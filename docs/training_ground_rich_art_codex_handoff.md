# 수련장 리치 아트 2단계 지시문 (피드백2 10항 후속)

- **발행**: 관제탑 2026-08-23. 정본은 이 파일 한 곳.
- **기준 HEAD**: `f83d231b8` (피드백2 8항 초크포인트까지 랜딩된 상태).
  CI/pre-push 락스텝 226 유지 중. ⚠ 본 트리에 미커밋 WIP 3천+건 —
  `git reset`·`checkout`·`stash`·통짜 `git add` 절대 금지.
- **격리 워크트리**: `D:\codex_tmp\bosspong_training_richart_f83d`
  (브랜치 `codex/training-richart-f83d-20260823`). ⚠ 워크트리 1개 ≈ 10GB.
  ⚠ 미추적 자산은 워크트리에 없다 — 이 지시문과 아트 소스는 **커밋으로만**
  이동한다. 후보 이미지·프롬프트·스크립트는 삭제 전 반드시 커밋(8/23
  허수아비 A단계 유실 사고 재발 금지).
- **배경**: 피드백2.hwpx 10항의 레퍼런스 목업(어두운 목조 도장 + 현판 +
  마당)이 목표. 1차 착지(`d44a99f56`)는 정보창 계열 한지+족자 9패치로
  통일만 한 상태다. 이번 2단계는 목업 수준의 전용 아트다.

## 현재 런타임 사실 (실측 기준)

- 수련장 전체 배경: `godot/assets/sprites/tower/noncombat/training_arena_background_imagegen_v1.png`
  — viewport cover, `tower_noncombat_node_background_catalog.gd:12` 소유.
- 모달 크롬: `tower_ascent_flow_renderer.gd`의 `_draw_node_modal` —
  `training_hanji_chrome` 분기(수련장 전용)가 한지 표면+`scroll_frame_9p`
  9패치를 그림. 텍스처는 `prewarm_training_hanji_chrome_assets()`에서
  static setter 주입. 이 분기를 새 목조 액자 자산으로 교체하는 것이 2단계.
- 레이아웃 정본: `tower_ascent_node_modal_state.gd` — MODAL_RECT(24,28,712,694),
  좌 카드레일 TRAINING_CARD_GRID_RECT(52,150,245,476), 우상 무대
  TRAINING_STAGE_RECT(312,150,405,210), 우하 능력치 TRAINING_STATS_RECT
  (312,372,405,254), 업무 종료(246,638,268,40). 기준 뷰 760x750.
  **rect는 이번 슬라이스에서 불변** — 렌더·히트테스트가 GRT-028 캐시
  하나를 공유하므로(GRT-022) 액자 안쪽 여백 조정이 필요하면 별도 협의.

## 1단계 — 아트 생성 (`.claude/skills/ui-hud-generation/SKILL.md` 경유)

생성 3피스. 전부 실제 비트맵(절차 기하 대체 금지). 후보 → **사용자 승인
전 런타임 배선 금지**(GRT-004: 미생성 경로를 per-frame 드로우에 미리 배선
금지).

1. **마당 배경 (풀블리드)** — 기존 training_arena_background 교체 후보.
   돌바닥 마당·낮은 계단·목책·수목 실루엣, 한낮 먹채색. 모달 뒤에 깔리는
   면이므로 중앙부는 명도·디테일을 눌러 모달 가독을 해치지 않게.
   소스 2020x1246 이상, viewport cover 크롭 안전영역 고려.
2. **목조 액자 크롬 (투명 PNG)** — 모달 둘레(712x694 비율)의 어두운 목조
   기둥 2본 + 상인방 + 하단 문지방, 상인방 중앙에 현판 소켓. 9패치 슬라이스
   가능 구조(코너 넉넉히). 진사·먹·황동 팔레트, 정보창 족자 계열과 톤 통일.
   투명 여백 정확히(누끼 규칙은 스킬 문서), ⚠ GRT-057: 투명 여백 뒤에
   평면 rect 헤일로를 깔면 상자가 드러난다 — 채움은 실루엣 안쪽 전용.
3. **무대 실내 배경 (405x210 비율)** — 우상 무대 rect 전용. 어두운 목조
   도장 내부, 중앙 상단 현판, 좌우 세로 주련 걸개. ⚠ 현판·주련의 **문구는
   사용자 확정 대상**(목업의 "환격전" 현판, "무혼 단련" 류) — 1차 후보는
   글자 없는 무지 현판/주련로 뽑고 문구는 승인 후 별도 레이어로.
   허수아비(피벗 613,347)·플레이어 슬롯과 겹치는 하단부는 바닥판만.

프롬프트 방향(관제탑 미감 지침): 환격전 신화무협 먹채색, 한지 질감 위
어두운 목재+진사 포인트, 금박 최소. 캐릭터 정보창·족자 크롬과 형제 톤.
과포화 금지, 목업(피드백2 img7)의 명암 구조를 앵커로.

## 2단계 — 런타임 배선 (아트 승인 후)

1. 자산 배치: 배경은 `tower/noncombat/` 계열, 크롬은
   `godot/assets/ui/tower_training_chrome/` 신설. 임포트는 에디터 포커스
   자동 재임포트 경로(★에디터 닫기 요구 금지, headless `--import` 금지).
2. `_draw_node_modal`의 training 분기 교체: 한지 표면 → 마당/실내 배경
   + 목조 9패치. 프리웜은 기존 `prewarm_training_hanji_chrome_assets()`
   패턴 확장(GRT-042: 무거운 모듈 콜드 생성 금지, ProjectResourceLoader
   직로드·GRT-028: draw 프레임 준비 금지). 타 모달 4종(상점·파계승·샘터·
   휴식)은 기존 크롬 폴백 불변.
3. 씰 개정(락스텝): `tower_training_screen_layout_smoke.gd`의
   `_verify_training_hanji_chrome_assets_and_gate` — hanji 라우트 단언을
   새 크롬 라우트로 개정 + 자산 미로드 폴백 레그 유지 + RED 반증 1회.
   레이아웃 rect 씰들은 불변이어야 한다(변하면 스코프 위반 신호).
4. 검증 게이트: 수련장 씰 6종 + `run_warning_scan.ps1 -Paths` 터치 파일 +
   `run_headless_load_check.ps1` + `run_tower_training_timing_visual_qa.ps1
   -BeforeCardPath .godot/codex_captures/tower_training_timing/training_card_overlap_before.png`
   재캡처. 캡처는 보고에 경로 명시(관제탑이 육안 판정).
5. 커밋: 아트 소스/후보 커밋 → 배선 커밋 헝크 분리. **푸시 금지·본 트리
   통합 금지 — 보고 후 대기**(통합은 관제탑이 merge-base 기준으로 수행).

## 보고 형식

기준 HEAD/워크트리 경로, 커밋 해시 목록, 씰 실행 종단선(`All Godot smoke
tests passed.` 원문), 캡처 파일 경로, 미해결·보류 명시. 문구(현판·주련)
후보가 생기면 별도 목록으로.
