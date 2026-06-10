# 오딘의 눈 — 죽음 시네마틱 디자인 노트 (Phase 2)

> 상태: 디자인 슬라이스 (2026-06-09). 상위 기획서: `docs/odins_eye_port_plan.md`.
> 분담([[feedback_design_slice_review_division]]): 이 노트 = 신호 계약 + VFX 레시피
> + 트랩 브리프(Claude). **GDScript 배선은 사용자**, Claude는 적대적 리뷰.
> 자산은 거의 절차적이라 imagegen은 폭발 백플레이트 1장 정도만(선택, §6).

## 0. 확정된 결정

- **범위 = 죽음 시네마틱만.** 부활 시네마틱(어둠 구체→폭발→솟아오르기)은 형제
  슬라이스로 후속. 본 노트는 페널티-중-실점 → 진짜 패배 직전 연출에 집중.
- **타이밍 = ~2.5s, Python 3페이즈 압축** (Python 4.5s → 2.5s).
- **형식 = 모듈러 + 절차적 분해** (정적 텍스처 + 셰이더/파티클/트윈 +
  실루엣-게이팅 분해 파편). 16프레임 시트 아님.
- **finalize 계약 불변.** 죽음 타이머 종료 시점의 `death_finalize_ready` 엣지는
  그대로다 — Phase 1의 `clear_after_death()` + 정상 score flow 재진입 배선
  (`battle_scene_item_update_driver`)이 이미 이 엣지를 소비한다. 본 슬라이스는
  타이머를 2.5s로 늘리고 **그 사이에 페이즈/진행도를 노출**할 뿐, 종료 계약은
  안 건드린다.

## 1. 타이밍 모델 (~2.5s, 3페이즈)

| 페이즈 | Godot 길이 | 전체 비율 | Python 원본 | 비트 |
|---|---|---|---|---|
| `PRE_EXPLOSION` (축적) | ~1.00s | 0.00–0.40 | 2.0s | 에너지 축적 + 균열 + 누출 파티클 + 눈광 ramp + 떨림 가속 |
| `EXPLOSION` (폭발) | ~0.70s | 0.40–0.68 | 1.0s | 대폭발 1프레임 트리거 → 화이트아웃 플래시 spike→decay + 충격파 링 + 떨림 피크 |
| `DISINTEGRATE` (분해) | ~0.80s | 0.68–1.00 | 1.5s | 실루엣이 파편으로 분해·비산(회전+페이드), 실루엣 alpha→0, 떨림 감쇠 |

- 압축 원칙: Python의 축적(2s)은 길어서 절반으로, 폭발/분해는 비율 유지.
- `energy_buildup`은 Python처럼 **progress^1.5**(가속) 권장.
- 종료(=`death_finalize_ready`)는 비율 1.00 도달 시. 이때 페널티 해제 +
  `clear_after_death()` + 실제 boss score 디스패치(이미 배선됨).

## 2. 상태머신 신호 계약 (백본 — 답변과 무관하게 먼저 필요)

현재 `odins_eye_state.gd`는 죽음을 **단일 `death_timer_sec`** 로만 노출한다.
다단계 VFX 훅을 위해 아래를 추가/변경한다. (순수 상태, 렌더 없음.)

- `const DEATH_EVENT_SEC := 2.5` (1.2 → 2.5).
- 페이즈 경계 상수: `DEATH_PRE_FRAC := 0.40`, `DEATH_EXPLODE_FRAC := 0.68`
  (둘 다 전체 진행도 기준; 분해는 0.68~1.0).
- 신규 getter (DEATH_EVENT 상태에서만 의미, 그 외 기본값):
  - `get_death_phase() -> String` → `"pre_explosion" | "explosion" | "disintegrate"`
    (`""` when not dying).
  - `get_death_overall_progress() -> float` → `1.0 - death_timer_sec/DEATH_EVENT_SEC` (0~1).
  - `get_death_phase_progress() -> float` → 현재 페이즈 내부 0~1 (경계 재정규화).
  - `get_death_energy_buildup() -> float` → PRE 페이즈 `phase_progress^1.5`, 그 외 1.0.
  - `get_death_disintegrate_progress() -> float` → DISINTEGRATE 페이즈 0~1, 그 외 0.
  - `get_death_shake_intensity() -> float` → 페이즈별 권장 곡선(PRE: 0→8 ramp,
    EXPLODE: 10 피크→감쇠, DISINTEGRATE: 5→0). **렌더가 아니라 상태가 권장값을
    노출**하면 셰이크 라우팅이 한 곳에서 일관됨.
  - (선택) `should_hide_player_paddle() -> bool` → DISINTEGRATE 후반(예: phase
    progress > 0.6)부터 true, finalize 후 라운드 리셋까지 유지. Python의
    `hide_paddle_after_death` 등가.
- **폭발 1프레임 엣지**: `update()`가 PRE→EXPLODE 전이 프레임에 `true`를 한 번만
  반환하는 `consume_death_explosion_edge()`를 두면, 렌더가 충격파/플래시/사운드/
  히트스톱을 **정확히 한 번** 트리거할 수 있다(매 프레임 재생성 금지). 분해 시작도
  동일 패턴(`consume_disintegration_edge()`).
- `get_context()`에 위 값들 추가(owner 동기화/디버그). **새 키는
  `BattleSceneState.DEFAULT_VALUES`에 선언**(Owner-Field 스키마 트랩) — owner로
  내보낼 경우에 한해.

> 신호만 노출하고 **수치 곡선은 상태가 소유**한다. 렌더는 "지금 어느 페이즈,
> 얼마나"만 읽어 그린다. 이렇게 하면 타이밍 재튜닝이 상태 1곳에서 끝난다.

## 3. VFX 레시피 (모듈러 + 절차적 분해)

캐릭터는 immediate-draw 플레이어 스프라이트다(노드 fx_host 못 끼움 →
**in-place 텍스처 합성**, 링펫 컷인 패턴 [[project_lingpet_acquire_portal_modular_vfx]]).

### 페이즈 0 — PRE_EXPLOSION (축적)
- **실루엣 오버레이(게이팅 필수)**: 플레이어 스프라이트 위에 어둠/보라 에너지
  글로우 + 눈광 ramp. **베이크 알파 점유 마스크로 셀 게이팅** — 빈 셀에 글로우/
  플래시가 새면 사각 박스 잔상([[feedback_godot_materialize_silhouette_gate]],
  [[feedback_godot_25d_flat_sprite_ceiling]] 회피). 반투명 캔버스 박스 트랩 동일.
- **균열 라인**: 실루엣 위에 절차적 crack(각도/길이/수명), 가속 생성. 직접 draw.
- **누출 파티클**: dark/purple/red, 몸에서 새어나옴. 희소 효과이므로 **stride
  LOD 면제**(개수 유지) — 인덱스 stride 데시메이션은 희소 파티클을 깜빡이게 함
  ([[feedback_godot_stride_lod_sparse_flicker]]).
- **떨림**: `get_death_shake_intensity()` 곡선을 기존 화면 셰이크 채널로 라우팅.

### 페이즈 1 — EXPLOSION (폭발)
- **모듈러 폭발(셰이더 패밀리 재사용)**: 어둠 폭발 백플레이트 + 충격파 링 +
  화이트아웃 플래시 spike→decay + 색수차. 기존 **신화 획득 펀치/ writhe-ember
  셰이더 패밀리** 프리셋 재사용([[feedback_modular_vfx_3piece_methodology]],
  [[project_godot_mythic_acquire_punch]]). uniform만 갈아 오딘 팔레트로.
- `consume_death_explosion_edge()`에서 **단 1회** 트리거(충격파/플래시/사운드/
  짧은 히트스톱). 히트스톱은 **비주얼 엔벨로프로만**, phase_timer를 얼리지 말 것
  (스모크가 coarse step으로 고정 → [[project_godot_mythic_acquire_punch]] 트랩).
- **정적-프레임 타이머-키 트랩**: 폭발 zone drawer가 elapsed를 별도 키에서 읽고
  tick은 다른 키만 줄이면 frame-0 정지 → 팝인/팝아웃. 타이머 키 1개로 통일
  (CLAUDE.md "Effect Drawer Static-Frame Trap").

### 페이즈 2 — DISINTEGRATE (분해)
- **절차적 분해 파편 = 재조립 VFX의 역방향**. 실루엣을 셀/조각으로 샘플링해
  바깥으로 비산(속도+회전+페이드). **베이크 알파 점유 마스크로 셀 게이팅**해서
  빈 셀 조각/플래시 skip — 재조립 노트의 게이팅을 dissolve 방향으로 재사용
  ([[feedback_godot_materialize_silhouette_gate]]).
- 실루엣 본체 alpha→0 (scale 1.3→1.8 확대되며 소멸).
- 파편 타입(body/dark/purple/eye)별 색/크기. 떨림 5→0 감쇠.
- (선택) `should_hide_player_paddle()` true 구간부터 본 패들 렌더 숨김 →
  finalize 후 정상 라운드 리셋에서 복귀.

## 4. 좌표/드로 계약 (트랩 브리프)

- **`_draw()` 안에서 `draw_set_transform()` + IDENTITY 리셋 금지.** 회전 도형
  좌상단 밀림 / 인트로 필러로 샘 / fx_host 자식 / 별도 셰이더 패스 4가지 실패
  모드. 별도 셰이더 패스는 1패스 셰이더 + `canvas.material` set/restore로
  ([[feedback_godot_draw_set_transform_trap]]).
- **플레이필드 = 풀 760px 캔버스.** 레터박스/필러로 클립하지 말 것. 폭발·파편이
  필러 영역으로 나가도 게임 캔버스 안([[feedback_godot_playfield_letterbox_reality]]).
- **FX host 자식 슬롯 world-pos**: `game_offset + (playfield_pos + shake) *
  render_scale`, 사이즈도 `* render_scale`. game_offset만 더하면 창 확대 시 어긋남
  ([[feedback_fx_host_world_pos_formula]]). (in-place 텍스처면 해당 없음.)
- **`draw_polygon` UV 정규화**: 픽셀 source_rect를 UV로 그대로 넘기면 클램프로
  자산 통째로 안 보임. `texture_size`로 나눠 정규화
  ([[feedback_godot_draw_polygon_uv_normalized]]).
- **`extends Control` 스크립트면 `var rotation`/`position`/`scale` 지역변수 금지**
  (프로퍼티 shadowing → warning_scan 실패). `angle`/`box_rotation` 사용
  ([[feedback_godot_control_rotation_shadow]]).
- **새 셰이더/머터리얼은 PSO prewarmer + 분기별 컨텍스트 dict**에 등록
  ([[reference_godot_prewarm_split]]) — 첫 폭발 프레임 히치 방지. 핫패스 lazy
  init 금지(CLAUDE.md "Hot-Path Lazy Init Trap").

## 5. 성능 / 라이프사이클

- 페이즈 0 누출 파티클 + 페이즈 2 분해 파편은 **개수×수명×레이어 동시 증가
  금지**(곱연산 폭주). 폭발 백플레이트/충격파는 캐시 텍스처 blit.
- 죽음 시퀀스가 2.5s 동안 ball 숨김 + 컨트롤 락 — 라운드/스테이지가 그 사이
  끊기면 §8 경계 정책대로 정리(finalize 안 와도 상태 일관). 파편/플래시는
  라운드 리셋에서 청소(잔상 누수 금지, CLAUDE.md show_result vs go_to_next_round
  패턴의 Godot 등가).

## 6. 자산 (거의 절차적, imagegen 최소)

- **폭발 백플레이트 1장**(선택): 어둠 폭발 코어 텍스처. 필요 시 `item-generation`
  /모듈러 VFX 경로로 생성, 투명 마진 충분, 엣지 비접촉. 그 외 충격파/플래시/균열/
  파편은 절차적 draw + 셰이더라 imagegen 불필요.
- 분해 파편은 **플레이어 스프라이트 자체를 샘플링**(별도 자산 없음).

## 7. 스모크 계약 (Phase 2)

`odins_eye_death_cinematic_smoke`(상태 레벨, 렌더 없음):
- `begin_death_sequence` 후 `update()`를 단계적으로 돌려 **페이즈 전이 진행도**
  검증: `get_death_phase()`가 0.40/0.68 경계에서 정확히 전이.
- `consume_death_explosion_edge()`가 **PRE→EXPLODE 전이 1프레임에만** true, 그 외
  false(원샷).
- `get_death_overall_progress()`가 0→1 단조 증가, 1.0에서 `death_finalize_ready`
  true(기존 finalize 계약 회귀 가드 — Phase 1 스모크와 함께 통과해야).
- `DEATH_EVENT_SEC` 변경(1.2→2.5)이 기존
  `odins_eye_revival_penalty_smoke`/`finalize_paddle_land_smoke`의 fps_scale
  스텝을 깨지 않는지 확인(2.5s = `update_runtime` fps_scale 합 ≥150 필요).
- (선택) `should_hide_player_paddle()`가 분해 후반에만 true.

## 8. 리뷰 체크포인트 (배선 후 Claude가 받을 것)

- 페이즈 전이/원샷 엣지 정확성(매 프레임 재트리거 없음).
- 실루엣 게이팅으로 빈 셀 박스 잔상 없음(약체/페이드 상태 in-game 확인).
- finalize 계약 불변(2.5s 끝에 정확히 1회, clear_after_death 경로 유지).
- 셰이더 PSO prewarm 등록(첫 폭발 히치 없음).
- 파편/플래시 라운드 리셋 청소(다음 라운드 잔상 0).
- 셰이크가 상태 곡선 단일 소스에서 라우팅(렌더 하드코딩 아님).
