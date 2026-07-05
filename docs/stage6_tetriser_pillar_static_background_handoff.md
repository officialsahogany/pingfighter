# Stage 6 Tetriser — Pillar Background Static-Redesign Handoff (Codex)

작성: 2026-06-26 (Claude 미술 방향 + 코드 seam 매핑). 실행(imagegen +
런타임 와이어링)은 Codex.

## 0. 목표 (한 줄)

현재 Stage 6 Tetriser 좌/우 필러의 **셀프 플레이 테트리스 게임 연출**을
없애고, **Stage 3처럼 정적 분위기 배경(imagegen PNG)** 으로 교체한다.
이유: 테트리스 well이 "또 하나의 게임 화면"을 통째로 그려서, 그 위에 얹힌
스킬카드·대쉬구슬·게이지(공용 HUD)와 정보가 충돌해 산만하게 읽힌다.
HUD가 주인공이 되고 배경은 차분히 물러나야 한다.

## 1. 현재 필러 3레이어 구조 (draw 순서)

`stage6_tetriser_pillar_scene_drawer.gd` `draw()`:

1. **backdrop** — `stage6_tetriser_pillar_background.gd` (state `stage_background`),
   line 84 `_draw_stage_background(...)`. 절차적: VOID 채움 + 스캔그리드 +
   playfield backplate + 좌우 돌기둥/하단 plinth + 중앙 "TETRISER" 아치 +
   링피아 궤도.
2. **테트리스 well (제거 대상)** — `stage6_tetriser_pillar_tetris.gd`,
   scene_drawer line 93–95. 좌/우 레터박스에 셀프 플레이 테트리스 2판
   (낙하 블록 / NEXT 프리뷰 / STATS / SCORE·LINES plinth / 라인클리어 플래시).
3. **공용 HUD (유지)** — `hud_scene_drawer` (`Stage1PillarHudSceneDrawer`),
   line 98. 스킬카드·대쉬구슬·게이지·스코어보드. 이건 기능 HUD이므로 그대로 둔다.

> 화면에서 "테트리스 게임처럼 보이는" 것의 정체 = **레이어 ②**.
> 스킬카드/대쉬구슬은 ③(공용 HUD)이며 손대지 않는다.

## 2. Stage 3 참조 패턴 (그대로 미러)

`stage3_pillar_background.gd`:
- 정적 PNG 텍스처를 on-demand 로드 (`_ensure_textures()`), `draw()`에서
  `_draw_cover_texture()` 로 cover-fit 블릿. 추가로 ambient sprite(둥둥 떠다니는
  하트)와 center frame을 시간 기반(게임상태 무관)으로 애니메이트.
- 에셋 경로 예:
  - base: `res://assets/sprites/hud/stage3_layered_cyber_menhera_base_imagegen_v4.png`
  - ambient: `res://assets/sprites/hud/stage3_menhera_ambient_sprites_imagegen_v3.png`
  - center frame: `res://assets/sprites/hud/stage3_center_frame_imagegen_v2.png`
- `update()`는 `ambient_time`만 증가. **게임 상태/타이머 구동 없음.**

Stage 6도 동일하게: 정적 base PNG cover-fit + (선택) 약한 시간기반 ambient.

## 3. 코드 seam (정확히 무엇을 바꾸나)

### 3-A. 레이어 ② 제거
`stage6_tetriser_pillar_scene_drawer.gd`
- line 11 `const Stage6PillarTetris := preload(...)` 제거
- line 16 `var pillar_tetris ...` 제거
- line 91–95 의 `pillar_tetris.draw(...)` 블록(perf label `"stage6.pillar.tetris"`
  포함) 제거
- `stage6_tetriser_pillar_tetris.gd` 자체는 삭제하거나 미사용으로 남긴다
  (다른 참조 없음 확인 후 삭제 권장 — dead per-frame Tetris 루프 제거).

### 3-B. 레이어 ① 를 정적 배경으로 재작성
`stage6_tetriser_pillar_background.gd`:
- 절차적 연출 중 **테트리스/아케이드 캐비닛 성격**(중앙 "TETRISER" 마키,
  돌기둥 cabinet, score plinth 흉내, 낙하블록 그리드 backplate)을 정적
  imagegen PNG로 대체.
- Stage 3 `_ensure_textures()` / `_draw_cover_texture()` 패턴을 그대로 가져와
  base PNG를 cover-fit 블릿. `draw()` 시그니처
  `(canvas, view_size, game_offset, game_size, _field_width, _perf_logger,
  quality_scale) -> bool` 는 **유지**(scene_drawer가 arg count로 분기함, line
  220–225).
- 중앙 playfield 영역(`game_offset..game_offset+game_size`)은 게임 큐브가
  올라가는 자리 → 배경은 어둡고 비워둔다(가독성). 좌/우 레터박스에만 분위기
  연출이 들어가도록 이미지를 구성하거나, full-canvas 이미지를 쓰되 중앙은
  저대비로.
- prewarm: scene_drawer line 37–42가 `stage6_tetriser_pillar_background` 의
  `prewarm_assets_step()` / `prewarm_assets()` 를 호출하므로, 텍스처 로드를
  prewarm 단계에서 끝내 hot-path lazy load 트랩을 피한다 (CLAUDE.md
  "Hot-Path Lazy Init Trap").

## 4. 좌표·클립 계약 (반드시 지킬 것)

- 이 프로젝트는 **full 760x750 게임 캔버스가 playfield**이고 필러는 그 바깥
  레터박스 여백 chrome다. 배경을 game x=80..680 으로 클립하지 말 것 (AGENTS.md
  "Godot Playfield / Pillar / Overlay Clip Reality", CLAUDE.md 좌표 표준).
- 좌/우 레터박스 폭은 `game_offset.x` 와 `view_size.x - game_offset.x -
  game_size.x` 로 계산 (scene_drawer 기존 분기 참조).
- quality_scale LOD 게이트 유지: 저품질에서 ambient/스윕 등 비용 큰 부분은
  스킵 (기존 코드의 `quality_scale > 0.45 / 0.52 / 0.55` 분기처럼).

## 5. 미술 방향 (imagegen) — ui-hud-generation 스킬로 라우팅

대형 필러 backplate 아트이므로 **`.claude/skills/ui-hud-generation/SKILL.md`** 의
프롬프트/스타일/투명 prep/소스 앵커 규칙을 따른다.

- 톤: 차분하게 물러나는 분위기 배경. 정보량 낮게. HUD(스킬카드·대쉬구슬·게이지·
  스코어보드)가 위에서 또렷이 읽혀야 함 → 배경은 저대비·저채도, 중앙 playfield는
  특히 어둡게.
- 아이덴티티: Stage 6 테트리서/링피아 정체성은 유지하되 **"테트리스 게임 화면"이
  아니라 "분위기 공간"**. 은은한 블록/그리드 모티프를 텍스처처럼 깔되, 살아 움직이는
  낙하 블록·NEXT·SCORE 카운터는 절대 넣지 않는다.
- 좌우 대칭으로 정돈 (현재는 좌측만 카드 스택이 차서 비대칭으로 더 산만).
- 알파/코너 투명, 알파 bbox 비-엣지터치, 다크/라이트 프리뷰에서 프린지 없음 등
  ui-hud-generation 체크리스트 통과.
- 에셋 네이밍: `godot/assets/sprites/hud/stage6_tetriser_pillar_bg_imagegen_v1.png`
  (Stage 3 네이밍 관습 미러).

## 6. QA 사인오프

- **픽셀 레벨 확인 필수**: 실제 Stage 6 씬을 윈도우로 띄워 스크린샷. 상태 스모크
  (visible/texture)만으로 끝내지 말 것 (CLAUDE.md 네거티브-Z / backdrop burial
  교훈).
- playfield 중앙 큐브가 배경에 묻히지 않는지, 스킬카드/대쉬구슬/게이지가 배경과
  충돌 없이 또렷한지 확인.
- 좌/우 대칭과 차분함이 "산만함 해소" 목표를 실제로 달성했는지 비포/애프터 비교.
- 테트리스 well 제거 후 per-frame Tetris 루프(낙하/라인클리어 타이머)가 완전히
  사라졌는지 (dead code/모듈 잔존 여부) 확인.

## 7. 참고 문서

- `docs/stage6_tetriser_port_plan.md` §3 — 필러 배경 모듈 소유권
- `docs/stage6_tetriser_port_gap_fix_slice_plan.md` §1 — 슬라이스/와이어링 경로
- `.claude/skills/ui-hud-generation/SKILL.md` — 필러 backplate imagegen 파이프라인
- `AGENTS.md` — 런타임 로더/prewarm/클립 reality
