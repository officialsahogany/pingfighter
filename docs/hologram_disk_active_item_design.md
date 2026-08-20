# 홀로그램 디스크 (hologram_disk) — 신규 액티브 아이템 설계

> 상태: 2026-07-29 폐기. 액티브 아이템 구현은 제거되었고, 기만 메커니즘은
> 한미량 초식 `void_phantom`으로 이관되었다. 아래 내용은 설계 이력이다.

작성: 2026-07-07 (Claude 설계 → Codex 배선 핸드오프)
런타임 통합 규정: `docs/item_runtime_checklist.md` §0.1, §0.2, §1.7, §5, §8 준수 필수.

## 1. 컨셉

사용 시 일정 시간 동안, 플레이어가 공을 칠 때마다 공에서 **홀로그램 분신
디스크 2개**가 갈라져 나와 진짜 공과 함께 보스 쪽으로 날아간다. 보스
이동 AI는 상승 비행마다 확률적으로 분신을 진짜 공으로 착각해 그쪽으로
움직인다. 분신은 보스 골라인 근처에서 글리치 팝으로 소멸하고, 그 순간
보스는 뒤늦게 진짜 공을 다시 추적한다.

- 기존 CC 7종(스턴/혼란/둔화/미끄럼)과 다른 **"판단 교란"** 계열.
- 플레이어는 분신을 구분할 수 있다(시안 글리치 틴트) — 혼란은 보스만.

## 2. 카탈로그 스펙 (v1 수치)

| 필드 | 값 | 비고 |
|---|---|---|
| `name` | `"hologram_disk"` | snake_case |
| `display_name` | `"홀로그램 디스크"` | |
| `type` / `effect` | `"active"` / `"hologram_disk"` | |
| `chance` | `0.008` | holy_barrier(0.006)~vitamin(0.012) 사이. 기만은 강력하므로 희귀 측 |
| `duration` | `300` | 프레임(5초). 2026-07-07 유저 튜닝: 10초→5초 (기만이 강해 짧은 윈도우로) |
| `cooldown_msec` | `DEFAULT_COOLDOWN_MSEC` | |
| `consumable` | `true` | |
| `no_recycle` | 설정하지 않음 | 2회째 사용이 구조적으로 유효한 일반 버프 (§1.7 lingpet_egg 반대 사례) |
| `icon_path` | `res://assets/sprites/items/hologram_disk.png` | §8 참조 — 파일이 먼저 존재해야 함 |
| `color` | `Color(0.35, 0.9, 1.0)` 계열 시안 | |
| `description` | `"일정 시간 공이 홀로그램 분신을 만들어 보스의 예측을 교란합니다."` | |

- 재사용(효과 중 재활성화) = 타이머 리프레시. vitamin_pill 형제 동작을 따른다.
- 게이지/골드 상호작용 없음. 리그 게이트 없음(전 리그 스폰).

## 3. 핵심 안전 원칙 — 물리 완전 비개입

이 아이템의 구현 가치는 **owned-ball 트랩군 전체를 우회하는 설계**에 있다.
아래는 하드 인바리언트다:

1. 분신은 `ball_pos` / `ball_vel` / `skip_ball_motion_step`을 **절대 읽기
   외로 만지지 않는다**. 쓰기 0회.
2. 분신은 패들/스킬/아이템/바닥과 **일절 충돌하지 않는다**. 순수 고스트.
3. 기만은 오직 **보스 이동 AI 컨텍스트의 인풋 치환**으로만 작동한다.
   보스 *스킬* 조준·스테이지 스킬 상태는 진짜 공을 계속 본다(의도된
   non-goal, §12).

## 4. 런타임 아키텍처 (앵커 확정)

### 4.1 상태 소유 + 활성화

- `active_item_effect_controller.gd`에 vitamin_pill 형제 패턴 그대로:
  `hologram_disk_active`, `hologram_disk_timer_frames`,
  `hologram_disk_initial_timer_frames`, 분신 배열
  `hologram_decoys: Array[Dictionary]` (`pos`, `vel`, `alive`,
  `flicker_seed`), 기만 락 상태(§5).
- 활성화: `active_item_effect_router.gd` 디스패치 →
  `active_item_effect_action_facade.activate_hologram_disk(...)` →
  컨트롤러. `activate_vitamin_pill`(effect_controller L249) /
  `activate_magnet_field`(L326) 경로를 미러링.
- 4-링크 규칙(§1.7): reset이 지우고, update가 변형하고, getter가 노출하고,
  렌더러가 메인 드로우 시퀀스에서 그린다. `active_item_effect_reset.gd`에
  리셋 포함(라운드 리셋 + 매치 리셋 + 결과 화면 경로 전부).

### 4.2 분신 tick — 반드시 공 업데이트 경로

- **`ball_update_controller.gd`의 `step_motion()` 직후(스테이지 충돌
  블록 앞)에 훅 `apply_active_item_hologram_decoys(scene, fps_scale,
  frame_context, frame_deps)`를 배치** (`ball_frame_motion_controller.gd`
  구현, deps 배관은 magnet_field 미러). 2026-07-16 개정: 구판의
  "magnet_field 옆(pre-motion)" 배치는 패들 반사보다 스폰이 한 물리 틱
  늦어 보스 AI가 진짜 공을 1틱 먼저 보는 결함이라 폐기 — post-motion
  배치가 패들 반사와 같은 프레임에 스폰·롤을 끝낸다.
- 이 위치는 구조적 면역 패턴이다: L72/L99의 `skip_ball_motion_step` 게이트
  안쪽이므로 공이 홀드/포즈되면 분신도 같이 멈춘다. 모달 포즈(effects-only
  분기)에서 effects 경로가 계속 돌아도 분신은 전진하지 않는다.
- 추가 가드: 훅 안에서 `ball_vel.length() < 0.01`(프리즈 액터가 공을
  0으로 만든 상태)이면 분신 전진·락 갱신 모두 스킵.
- 지속시간 카운트다운은 effects 경로(형제와 동일). 실제 frame-flow는
  모달 포즈 중 active item update driver를 돌리지 않으므로 **타이머는
  모달 동안 정지하고 만료는 재개 후에 일어난다**(2026-07-16 정책 확정 —
  구판의 "모달 중 만료" 서술은 실 동작과 달라 폐기). 공 소유가 없으므로
  stuck 플래그는 원리적으로 불가능하다. 만료 클리어가 락과 분신을 **한
  헬퍼에서 원자적으로** 지우는 계약은 동일하게 유지하라.

### 4.3 기만 주입 — 단일 초크포인트

- **`battle_update_boss_ai_context_builder.gd` `build_context()`의
  `"ball_pos"` / `"ball_vel"` 채움 지점(L113-114)**에서, 홀로그램 락이
  살아 있으면 두 키를 락된 분신의 pos/vel로 치환한다.
- 이 한 곳으로 하류 전부(`boss_ai_state.update`의
  `prediction_state.predict_future_x`, 보스 대쉬 타겟팅
  `_try_start_boss_dash`, turn inertia)가 균일하게 속는다. 위치·속도
  치환은 소비자별 수정 금지. 단 2026-07-16 개정: 예측 '모델' 일치를
  위해 boss_ai_state의 예측 호출 3곳은 컨텍스트의
  `prediction_play_left/right`(분신 시각 여백 벽)를 소비하고, 기만
  프레임 컨텍스트는 부스트 무력화+`prediction_reflect_velocity`(반사
  vx 유지) 계약을 싣는다 — 보스 '목표 중심' 클램프는 전역 play 경계
  유지(predictor 내부 분리).
- 컨트롤러 접근은 **cache-only peek**(`registry.get_cached_instance`) —
  보스 AI 컨텍스트는 매 물리 프레임 빌드되므로 lazy 인스턴스화 금지
  (Hot-Path Lazy Init Trap). peek 실패 시 기만 없음(진짜 공 사용) 폴백.
- 치환 시 디버깅용으로 `"hologram_deception_active": true` 키를 컨텍스트에
  같이 실어라(스모크 관측용).

### 4.4 owner 스키마

- owner에 동기화 키를 쓴다면(`owner.set(...)`) 전부
  `BattleSceneState.DEFAULT_VALUES`에 선언(Owner-Field Schema Trap).
  registry peek 설계로 owner 키가 불필요하면 그쪽을 선호.

## 5. 기만 로직 상세

### 5.1 기회(opportunity) 정의와 단발 롤 — Per-Frame Probability Roll Trap 준수

- **기회 = 진짜 공의 상승 비행 1회** (플레이어 패들 히트로 `ball_vel.y < 0`
  전환 ~ 다시 `ball_vel.y >= 0` 될 때까지).
- 상승 시작 프레임에 **딱 1회** 롤: `DECEPTION_CHANCE := 0.65`.
  - 성공 → 살아있는 분신 중 1개 랜덤 락 (`locked_decoy_index`).
  - 실패 → 이번 비행은 진짜 공 추적.
- 락은 비행이 끝날 때까지 유지. 벽 반사·중간 프레임에서 **재롤 절대 금지**.
- 락 해제 조건: (a) 공이 하강 전환, (b) 락된 분신 사망(→ 같은 프레임에
  진짜 공으로 폴백 = "뒤늦은 깨달음" 연출), (c) 효과 만료, (d) 라운드 리셋.
- 하강 비행(`ball_vel.y > 0`) 중에는 기만 없음(항상 진짜 공).
- 서브 대기(`waiting_for_serve`) 중에는 분신 스폰·기만 모두 없음.

### 5.2 분신 스폰

- 트리거: 효과 활성 중 플레이어 패들 히트(공이 상승 전환하는 그 이벤트).
  기존 paddle-bounce 후처리에서 컨트롤러에 통지하거나, 공-경로 훅에서
  "하강→상승 전환 + 플레이어 y-밴드" 에지 검출로 자체 판정해도 된다
  (후자가 배선이 적어 권장. 단 보스 히트로 인한 전환과 구분: 전환 프레임의
  공 y가 플레이필드 하단 절반일 때만 스폰).
- 스폰 시 기존 분신은 즉시 소멸(글리치 팝) 후 새 2개 생성.
- 초기 상태: `pos = ball_pos`, `vel = 진짜 공 vel을 ±(10°~22°) 랜덤 회전`
  (부호 반대 방향 각 1개), 속력 동일. 회전 후 `vel.y > -1.0`이면 상승
  성분을 -1.0으로 보정(수평 누움 방지).
- 단위는 **px/frame** (`ball_vel` 규약 — px/sec로 쓰지 말 것).

### 5.3 분신 kinematics

- `pos += vel * fps_scale` (공-경로 훅에서만).
- 좌우 벽 반사는 '중심' 좌표 + '시각 최대 반경' 여백(x:
  DECOY_WALL_MARGIN ~ WIDTH-DECOY_WALL_MARGIN, 스폰 프레임 포함).
  위쪽으로만 비행. 기만 프레임의 보스 AI 예측도 같은 경계·raw velocity
  계약을 컨텍스트로 전달받아 동일 모델로 계산한다(2026-07-16 개정 —
  구판의 0 ~ WIDTH-BALL_SIZE 좌상단 규약은 폐기).
- 사망: `pos.y <= BOSS_Y + 40` 밴드 도달 시 글리치 팝 소멸.
- 진짜 공의 속도 변화(임팩트 감쇠/스핀)는 미러링하지 않음 — 스폰 시점
  속력으로 직진. 의도된 단순화.

## 6. 렌더 / VFX (Claude 아트 디렉션)

- 드로우: `active_item_runtime.gd` 드로우 팬아웃 →
  `active_item_effect_renderer.gd`.
- **분신 비주얼 = 진짜 에너지볼 미러 (2026-07-07 유저 디렉션 개정)**:
  `EnergyBallRendererScript`의 공유 상수(`BALL_RENDER_RADIUS`,
  `BALL_OUTER_COLOR`/`BALL_INNER_COLOR`, `BALL_SOLID_CORE_SCALE`)와 공유
  텍스처 캐시(`ImpactFlareTextureCache.draw_glow`,
  `EnergyBallTextureCache.draw_core/draw_highlight`)로 실제 공의 레이어
  스택(외곽 글로우→내부 글로우→솔리드 코어→하이라이트)을 그대로 그리되,
  단일 레버 `HOLOGRAM_DECOY_ALPHA := 0.6`으로 전 레이어 알파를 60%로
  낮춘다. 절차적 시안 디스크(구버전)는 공 판독이 안 돼 기각됨.
  홀로그램 텔은 은은한 시안 림 아크 1개 + 미세 알파 플리커(±0.06)만.
  플리커 시드는 분신별 `flicker_seed`(스폰 시 고정) — 흔들리는 pos로
  시딩 금지(VFX 시드 규칙). 텍스처 캐시는 공 렌더러 부트 프리웜이 이미
  데워 놓으므로 신규 lazy-init 없음.
- 스폰 = 패들 임팩트 지점에서 짧은 분열 플래시. 사망 = 8~12조각 글리치
  디졸브 팝. 신규 셰이더 패밀리 불필요 — modulate/직접 드로우로 충분.
- 신규 텍스처 없음(공 비주얼 재사용 또는 절차 디스크). 예약-부재 에셋
  경로를 퍼프레임 드로우에 배선하는 것 금지(Re-Stat Trap).
- 타이머 게이지: vitamin_pill과 같은 우하단 공유 duration-bar 스택 합류
  (`active_item_timer_gauge_renderer.gd`, `get_vitamin_pill_timer_context`
  형제 미러).

## 7. 오디오

- 활성화 1샷(글리치/디지털 차임), 분신 사망 소프트 팝. **루프 SFX 금지**
  (modal-block loop-audio 트랩 자체 회피). `game_audio.gd` 큐 추가.

## 8. 아이콘 에셋 계획

- 최종 경로: `godot/assets/sprites/items/hologram_disk.png` (실물 아트는
  Claude가 item-generation 스킬로 후속 생성).
- **Codex는 배선 시점에 기존 아이콘 하나를 해당 경로로 복사해 placeholder
  바이트를 먼저 존재시켜라** (예: `magnet_field.png` 복사). 경로 부재 상태로
  카탈로그에 배선하면 HUD 퍼프레임 re-stat 트랩에 걸린다.
- 스모크에 `FileAccess.file_exists(아이콘 경로)` assert 포함.

## 9. 통합 체크리스트 매핑 (`docs/item_runtime_checklist.md` §1.7)

- [x] `active_item_catalog.gd`: `_build_hologram_disk()` + `build_item_by_name`
      match + `FIELD_SPAWN_ORDER` 추가.
- [x] `active_item_effect_router.gd` 디스패치 + facade + controller activate.
- [x] `active_item_debug_spawn_menu.gd::DEBUG_ENTRY_ORDER`에 수동 추가
      (카탈로그 멤버십으로 자동 노출 안 됨) + 스모크 assert.
- [x] 다국어: `language_settings_data.gd`의 `ITEM_DISPLAY_EN/ZH/JA/ES/PT_BR/RU`
      전부 + `ACTIVE_ITEM_DESCRIPTION_EN`. 누락 시
      `localization_coverage_smoke._verify_active_item_catalog` RED.
- [x] 분신 리스트 4-링크(reset/update/getter/renderer) 완비.
- [x] `active_item_field_spawn_pool.gd`: 특수 게이트 불필요(일반 스폰).
      스폰 경로에 lazy 인스턴스화 없음 확인.
- [x] 리셋 라이프사이클(§5): 라운드 리셋 / 결과(게임 종료) / 메인 메뉴 복귀
      / 스테이지 전환 전부에서 분신+락 클리어. 게임-종료 경로 누락이 대표
      leak 클래스임을 유념.
- [x] 활성화 성공 시에만 소모 — 씰 범위는 라우터 활성화 성공·재사용
      리프레시까지(전용 스모크 02 레그). 실제 슬롯 차감은 아이템 공통
      소비 계약(라우터 수락 시에만 소모)을 따르며 이 아이템 전용
      특례가 없다.
- [x] 세이브/로드: 슬롯 인벤토리 직렬화가 이름 기반이면 추가 작업 없음 —
      확인만.

## 10. 관련 트랩 (배선 전 `docs/godot_runtime_traps.md` 해당 절 필독)

| 트랩 | 이 설계에서의 적용 |
|---|---|
| Per-Frame Probability Roll | 기만 롤은 상승 비행당 1회 락 (§5.1) |
| Hot-Path Lazy Init | 컨텍스트 빌더/스폰 풀에서 cache-only peek |
| Owner-Field Schema | owner 키 쓰면 DEFAULT_VALUES 선언 |
| Two-Update-Path Context-Flag | 기만은 보스 AI 컨텍스트 전용. 스모크는 실제 빌더로 검증 |
| Missing Reserved-Asset Re-Stat | 아이콘 placeholder 선복사 (§8) |
| Effect Drawer Static-Frame | 타이머 키 하나만(`timer_frames`) 사용 |
| Modal-Block Loop-Audio | 루프 SFX 자체 금지 (§7) |
| skip_ball_motion_step 계열 전부 | 공 소유 0 설계로 원천 회피 (§3) — 리뷰에서 쓰기 0회 재확인 |

## 11. 스모크 씰 + 반증검증

신규 `godot/tests/.../active_item_hologram_disk_smoke.gd` (기존 스모크
디렉토리 규약 따름):

1. **카탈로그/메뉴/아이콘**: 카탈로그 빌드 성공, `DEBUG_ENTRY_ORDER.has()`,
   `file_exists(icon)`.
2. **스폰 레그**: 활성화 → 플레이어 히트 전환 → 분신 2개, 둘 다 상승 성분,
   각도 발산.
3. **락 레그**: 기만 확률 1.0 강제 → 상승 비행 내내 보스 AI 컨텍스트의
   `ball_pos/ball_vel`이 락된 분신 값과 일치(공은 `ball_vel * delta * 60`으로
   실제 스텝), 롤 횟수 == 1 (벽 반사 후에도 재롤 없음).
4. **아웃컴 레그** (플래그 검사 금지, 기하 결과): 분신과 진짜 공의 도착 x를
   크게 벌린 시나리오에서 보스가 분신 도착 x 근처로 이동해 진짜 공을 놓침
   (보스 센터와 진짜 공 x의 거리 assert).
5. **폴백 레그**: 락 분신 사망 프레임에 컨텍스트가 진짜 공으로 복귀.
6. **하강/서브 레그**: 하강 중, 서브 대기 중 기만 없음.
7. **프리즈 레그**: `skip_ball_motion_step=true` 또는 `ball_vel≈0` 프레임에
   분신 pos 불변.
8. **리셋 레그**: 라운드 리셋 + 결과 화면 경로 후 분신/락/타이머 전부
   초기값.
9. **만료 원자성 레그**: effects 경로에서 타이머 만료가 일어난 그 틱에
   락·분신·파티클 원자 클리어, stuck 상태 없음. (실 frame-flow는 모달
   중 타이머가 정지하므로 §4.2의 pause 정책과 함께 읽을 것 — 구판의
   "모달 중 만료" 서술은 폐기.)

**반증검증(필수, SAFE 방식만)**: in-place Edit 토글로만 수행 — (a) 락을
퍼프레임 재롤로 임시 변조 → 레그 3 FAIL 확인, (b) 컨텍스트 치환 비활성 →
레그 4 FAIL 확인. 확인 후 원복. **`git reset`/`checkout`/`stash` 절대 금지**
(이 리포는 미커밋 WIP 상시 보유).

## 12. Non-goals (v1 의도적 제외 — 버그 아님)

- 보스 **스킬** 조준/스테이지 스킬 상태는 진짜 공을 본다 (이동만 기만).
- 분신은 진짜 공의 중간 속도 변화(스핀/감쇠/파워스매시)를 미러링하지 않는다.
- 플레이어 쪽 하강 분신 없음. 분신의 아이템/필드 오브젝트 상호작용 없음.
- 스테이지5 홍련 인페르노 등 owned-ball 구간에는 분신이 정지하는 것이 정답
  (공-경로 훅 게이트의 자연 결과).

## 13. Deliverables / 게이트

1. 상기 배선 전부 + 신규 스모크 GREEN + 기존 스모크 회귀 0
   (`localization_coverage_smoke`, item 계열 스모크 포함).
2. 반증검증 (a)(b) 수행 로그(무엇을 토글했고 어떤 레그가 FAIL했는지).
3. 완료 보고에: 변경 파일 목록, 스모크 결과, 반증검증 결과, §12 non-goal
   준수 확인 한 줄.
4. 이후 Claude 적대 리뷰 → 라이브 QA → 커밋(헌크 분리 규약)은 별도 단계.
