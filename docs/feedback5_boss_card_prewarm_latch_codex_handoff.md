# 지시문 R2 — [P0] 1층 재조우 시 보스 스킬카드 전멸 (프리웜 래치 키 결함)

- **발행**: 관제탑 2026-08-25(2차 프로브 실측 반영 개정). 기준 HEAD
  `d06513d5e`. CI/pre-push 락스텝 237.
- **격리 워크트리**: `D:\codex_tmp\bosspong_bosscard_d065` (브랜치
  `codex/boss-card-prewarm-latch-20260825`). Q3/Q4/Q6·R1 트랙과 파일
  무겹침 — 병렬 가능.
- **금지**: 본 트리 직접 편집·푸시·통합. 보고 후 대기.

## 증상·원인 (관제탑 프로브 실측 확정, HIGH)

라이브 탑 런 1층 전투 중 **좌측 필러의 보스 스킬카드가 통째로 부재**
(금화·무혼·M·콤보·대시·게이지·초상은 정상 렌더).

- **진범**: 스테이지 런타임 프리웜 래치가 **스테이지 id로만** 키잉됨.
  `battle_boot_resource_prewarm_controller.gd:343`
  `if stage_runtime_resources_prewarmed_for_stage == current_stage:
  return true` — `:370`이 유일한 쓰기이고 **생산 경로에 리셋이 없다**
  (리셋은 테스트에만 존재).
- 탑 1층 재조우는 `_apply_tower_encounter_identity`
  (`battle_scene_match_event_driver.gd:494`)가
  `stage1_boss_variant`만 바꾸고 `current_stage`는 1로 유지 →
  전환 work step 5가 즉시 단락 → **변형별 렌더러를 만드는 유일한
  생산 경로**(stage-1 프리웜 step 2·4, `:605`/`:625`)가 실행되지 않음.
- 드로어는 `get_cached_instance`(비생성 peek)로 조회 →
  `stage1_pillar_hud_scene_drawer.gd:392~393`에서 **무음 조기 반환**.
- 1층 선택 조우는 게이트 보스와 **반드시 다른 변형**이므로
  (`boss_registry:886` 중복 키 소비) **첫 전투 이후 1층 재조우마다
  결정론적으로 재현**. 캐시 정리는 씬 종료 시뿐이라 자가 치유 없음.
- ⚠계열: I2가 수리한 "전환 텍스처 컨텍스트 variant 누락"과 동일
  가문(GRT-020 적용키 재적용 트랩 / GRT-053).

## 작업

1. **래치 키 복합화**: `stage_runtime_resources_prewarmed_for_stage`
   (int)를 `(stage, stage1_boss_variant)` 복합 키로 교체하고,
   `stage_runtime_prewarm_step_stage`/`step_index` 리셋(:345~348)도
   같은 키로 정렬. 비-1스테이지는 상수 variant로 접혀 동작 불변.
   - ★**정본 선례를 그대로 따를 것**:
     `stage1_pillar_hud_scene_drawer.gd:75~87`이 이미
     `prewarm_key := "%s:%s" % [character_type, variant]`로 래치하고
     **키가 바뀌면 `_prewarm_step_index = 0`으로 되감는다.** 새 패턴을
     발명하지 말고 이 모양을 바깥 컨트롤러에 이식하라.
   - ★**내부 드로어는 이미 옳다** — 이번 결함은 **바깥 게이트 단독**
     이다(:343이 내부 스텝 호출 자체를 못 가게 막는다). 내부 드로어의
     프리웜 로직을 손대는 수정은 스코프 밖이며 회귀 위험만 만든다.
2. **호출부 명시 무효화**: `begin_tower_boss_transition`
   (`battle_scene_match_event_driver.gd:262~273`)에서
   `_apply_tower_encounter_identity` 직후 프리웜 래치를 명시적으로
   무효화하는 API 추가 호출 — 미래에 정체성 차원(캐릭터 등)이 늘어도
   키 재유도 없이 커버.
   - ⚠단, `stage1_pillar_scene_drawer.reset_prewarm_cache()`(:48 →
     `hud_scene_drawer.gd:154`, **생산·테스트 호출자 0개인 죽은 API**)를
     이 자리에 끌어다 쓰지 말 것. 그것은 캐릭터 자산까지 포함해 내부
     캐시를 통째로 비워 **변형과 무관한 재프리웜을 강제**한다. 1번의
     키 복합화만으로 내부 드로어가 스스로 재진입하므로 충분하다.
     (죽은 API는 이번 스코프에서 그대로 두고, 별건으로 보고만 하라.)
3. **무음 제거**: `_draw_stage1_boss_skill_hud`에서 변형별 렌더러 또는
   쿨다운 상태 peek이 실패하면 **모듈 키별 1회 push_warning** —
   프리웜 공백이 다시는 "이 보스는 스킬이 없다"로 위장되지 않게.
   ⚠같은 무음 조기반환 모양이 `:392~397` 외에 **`:430`·`:464`에도**
   있다. 세 지점을 같은 계약으로 처리할 것.
4. ⚠**드로우 시점 지연 생성 금지**(GRT-003/042): peek-only 계약은
   의도된 것이다. 첫 가시 프레임에 카드 렌더러를 콜드 생성하면
   HUD 부재를 스톨과 맞바꾸는 것 — 반드시 프리웜에서 해결.
5. **동반(잠재)**: `battle_scene_drawer.gd:542`
   `_should_suppress_tower_boss_skill_hud`가 `is_active()` 전 구간을
   억제 — `:179~188`처럼 **phase 검사(ROUTE_AIM/맵 오버레이)로 정렬**
   해 모달 게이트가 실제로 막는 구간과 락스텝. (이번 증상의 원인은
   아님 — 랠리 중엔 false로 반증됨.)

## 씰

- **재조우 레그(핵심)**: 실 전환 경로 관통 — 1층 A변형 전투 →
  `begin_tower_boss_transition`으로 B변형 조우 → 프리웜 스텝 완주 →
  `get_cached_instance("stage1_<B>_boss_skill_hud_renderer")` 비-null
  단언 + 드로어가 카드 rect ≥1 생성 단언. 3변형 전순열.
- **RED 반증**: 래치 복합화를 되돌린 픽스처에서 B변형 렌더러 null·
  카드 0 → RED(현행 코드가 RED임을 먼저 확인).
- **행동 레그(레지스트리 관통·필수)**: 드로어의 실 드로우를 기록
  CanvasItem으로 받아 **카드 rect 개수**를 센다. `get_cached_instance`가
  해당 키에 null을 주는 레지스트리 = 0장, 프리웜을 거친 레지스트리 =
  달지 2장(팽이·채찍). **직접 생성한 렌더러를 주입하지 말 것** —
  그러면 이번 결함(레지스트리 캐시 미스)을 통과시킨다. 두 레그의
  유일한 차이가 캐시 상태여야 레이아웃 기하가 원인이 아님을 증명한다.
- **경고 레그**: peek 실패 픽스처에서 push_warning 1회(중복 억제).
- **콜드 비용**: 재조우 프리웜이 전환 로딩 단계에서 끝나고 첫 전투
  프레임에 콜드 생성이 없음(측정치 보고).
- 기존 락스텝: stage1 필러/보스카드 계열·전환 프리웜 씰 GREEN 유지.
- ★⚠**결함을 잠그고 있는 기존 씰**:
  `tests/stage1_pillar_scene_prewarm_smoke.gd:150~153`이 "포도대장
  프리웜은 달지/각시탈 모듈을 건드리지 않는다"를 단언한다. 이는
  **1회 통과 기준으로는 옳으므로 삭제·완화 금지**. 대신 **변형 전환
  레그를 추가**해, 변형이 바뀐 뒤에는 새로 필요한 모듈이 실제로
  프리웜된다를 단언하라. (이 씰을 지우는 수정은 반려된다.)
- **픽셀 QA**: 1층 2번째 조우(다른 변형) 라이브 캡처 1장 — 좌측
  필러에 보스 카드가 실제로 보일 것.

## 이미 반증된 가설 (수리 노력 금지)

관제탑 프로브 2종이 독립 실측으로 기각했다. 다시 파지 말 것.

- **`22180dc8f`(F 카드 스무딩)**: 달지 헝크 정상 — prune은 기존 반환
  지점이고 `_draw_card` 호출 arity 단일·정상, 신규 static 전부 존재.
- **`af122f7d7`(쿨다운 회수)**: stage-1 파일 접촉 0건. 오히려 쿨다운
  0초화를 **제거**해 카드가 더 잘 보이는 방향. ⚠2차 프로브가 이
  커밋의 ponk `reset()`에서 초기 쿨다운 재장전이 빠졌다고 보고했으나
  **관제탑 재검증 결과 오독**이다 — 삭제된 줄은 `reset_round()`의
  것이고 `reset()`은 `:31`에서 `COOLDOWN_SEC`를 그대로 재장전한다
  (GRT-060 계약 충족). 별건 티켓 불필요.
- **`c61060c13`(트리거 클래스) `trigger_type`**: 런타임 fail-soft —
  표식/라벨에만 쓰이고 카드나 레일을 건너뛸 수 없다.
- **렌더러 `reset()` 중간 초기화**: `match_reset_controller`의 리셋
  목록에 stage-1 렌더러는 없다(ponk·홍련만). 무관.
- **`suppress_boss_skill_hud`**: 랠리 중 false로 실측 반증(작업 5번은
  예방적 정렬일 뿐 이번 증상의 원인 아님).

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처. 보고=워크트리·커밋 해시·씰 종단선 원문·
캡처 경로·전환 프리웜 실측 시간·미해결.
