# Godot 성능 최적화 플레이북 (링피아)

fable-5가 링피아 프레임 예산 최적화 24개 커밋에서 균일하게 적용한 6개 수정
기법 + 그 모두를 관통하는 봉인 규율. **비용을 찾은 뒤(진단) 실제로 줄이는 방법
(수정)의 카탈로그.** Claude/Codex/다른 환경 공용. git history 전수분석
(2026-06-14)에서 도출.

- **진단(비용 찾기)**: 별도 — BattlePerf 0단계 유병률 집계 triage(라벨
  present-in-X/N, 비용×유병률 정렬, peak max 아님) + 아티팩트 분류표(디버그피커/
  모달/이벤트일회성/배치윈도우갭) + attribution 재검증. 상세는
  `docs/frame_budget_72fps_optimization_design.md` 및 에이전트 운영 자세 문서.
- **자세(일반 엄밀성)**: `docs/agent_operating_posture.md`.
- **개별 런타임 트랩**: `CLAUDE.md`(Hot-Path Lazy Init Trap, Owner-Field Schema
  Trap, Lazy Applied-Key Re-Apply Trap 등), `AGENTS.md`(redraw coalescing,
  const-catalog deepcopy, event-boundary full-sync 등). 이 문서는 그 개별
  트랩들을 "언제 어떤 기법" 결정 카탈로그로 묶는다.

---

## 모든 기법 관통 봉인 규율 (fable 시그니처의 본체)

기법 자체보다 **모든 기법에 빠짐없이 적용되는 이 규율**이 핵심이다.

1. **계측은 non-behavioral + gap-free + 플러밍 자체가 핫패스 비용이면 안 됨.**
   `perf_logger`는 optional/null-default, deps dict로 스레드하거나 arg-count
   reflection으로 caller 백호환. early-return 분기는 헬퍼로 추출해 무계측 틈이
   안 생기게(`_update_none_state` 패턴). **단 그 back-compat 리플렉션(arg-count
   체크)이 매 틱 `get_method_list()`를 스캔하면 계측 플러밍이 곧 핫패스 오버헤드가
   된다** — instance_id:method로 캐시(`_get_method_argument_count`). 회귀
   `24de004fa`: 계측 커밋 `11f0a86bc`의 uncached arg-count 스캔이 mythic 업데이트를
   0.67→3.04ms로 부풀려 "계측 먼저"가 역설적으로 회귀를 주입(첫 lookup 2389us→캐시
   22.2us). "non-behavioral"은 동작뿐 아니라 *비용*도 중립이어야 한다.
2. **데이터가 타겟을 재지정하게 둔다 — 직관의 반대인 경우가 흔하다.** mythic
   per-tick 1.1ms의 81%는 18개 family 업데이트가 아니라 post-update owner sync
   였고, sync 바닥은 owner write가 아니라 value-getter/context-build fan-out
   이었다. 추측한 leaf를 고치지 말 것.
3. **owner가 아니라 last-pushed 로컬 캐시와 diff.** owner를 읽어서 비교하면
   매 틱 owner read + deepcopy를 여전히 낸다.
4. **최적화가 데워지는 동안 correctness-identical 폴백 유지.** 캐시 텍스처 준비
   전엔 즉시 벡터 드로, 메뉴 프리웜 캐시 전엔 즉시 threaded 로드.
5. **모든 수정을 반증검증 스모크로 봉인.** 무언가를 카운트(owner read/write,
   cold-create 키, dispatch, 픽셀 패리티)하고 **pre-fix 코드에서 실패**하는지
   in-place 토글로 확인(`git reset` 아님 — 더러운 워크트리 보호).
6. **co-dependent 상수/경로는 move-together.** 스키마 bump + 마이그레이션 + 미러
   상수 + 전 언어 권장문구 + 스모크를 한 커밋에.

---

## 6개 수정 기법 (증상 → 기법)

### 1. Decompose-before-optimize — 계측 먼저
**증상**: opaque 집계 라벨(370ms reset / 1.1ms mythic / 3.5ms round-resume).
**기법**: 손대기 전에 gap-free 서브라벨 또는 throwaway 비율-마이크로벤치로 쪼갠다.
절대수 아닌 **비율**로 컴포넌트 분리(clean tick 225us 중 value-build 81% /
context 52% / write +49us → 어디서 멈출지 결정).
**증거**: `8d6f534ed`, `c028741b2`, `11f0a86bc`, `1364d821f`(마이크로벤치
`godot/tools/mythic_sync_microbench.gd`), `4129bc21e`, `38b980583`.
**안티패턴**: 추측한 sub-step을 바로 깎기.

### 2. Last-pushed-cache write gating — idempotent owner sync diffing
**증상**: 매 틱 shared owner로 re-push되는 상태(정적 키 + 배열 deepcopy).
**기법**: **로컬 last-pushed 캐시와 diff**해 바뀐 키만 write. 컨테이너는 바뀔
때만 1회 복사 + 양쪽 detach(alias 방지). invalidate는 **boundary 훅에만**
(pet switch / level-up / loadout apply / match-reset wipe). dirty 틱도 캐시
dict를 shallow-dup해 바뀐 키만 적용(owner re-read 회피).
**스키마 따름정리**: gated 키는 `battle_scene_state.DEFAULT_VALUES`에 선언돼야
write가 안 죽는다(미선언 키 write = silent no-op).
**증거**: `41949554c`(owner.set 10100→166/100틱, −98%), `d923fe1ff`, `b9ff8c38f`,
`798754ba1`(라운드시작 3.5→0.4ms), `fffdaa886`(스키마 17키 선언).
**봉인**: owner read/write 카운트 스모크(pre-fix 카운트에서 FAIL).

### 3. Peek vs discrete-moment prewarm — lazy-init을 핫패스에서 분리
**증상**: 첫 발생 시 수백ms stall(미방문 스테이지 모듈 / 첫 스킬 / 시네마틱 호스트).
**기법**: reset/cleanup/"활성인가?" 소비자는 **`get_cached_instance()`(비생성
peek)** — 안 만들어진 모듈은 리셋할 state가 없음. 진짜 첫 생성은 **이산 시점**
(loadout-apply / boot prewarm / ball-spawn intro, owner 있고 rally 밖)으로 옮기고
idempotent.
**증거**: `19de08968`(match-reset 370ms/574ms stall, get_instance→
get_cached_instance peek), `f8ce7a2fb`(링펫 스킬 모듈+시트), `952ca026b`(획득
시네마틱 호스트 52ms), `0c1d0c778`(CLAUDE.md 백필).
**안티패턴**: reset-deps/per-frame에서 get_instance() 호출, 또는 guard만 걸고
여전히 lazy 생성.

### 4. Decouple trigger cadence from expensive work — coalesce / offload
**증상**: 비싼 op가 burst 가능한 트리거에 1:1로 묶임.
**기법(coalesce)**: physics-tick에서 `queue_redraw()` 직접 호출 금지 → dirty
플래그(`request_battle_redraw`) 세우고 `_process`에서 프레임당 정확히 1회 flush.
physics 캐치업 8틱/프레임 시 per-tick redraw가 자기증폭 스파이럴 — **진단
시그니처: `draw count == proc count + phys count`**.
**기법(offload)**: 무거운 동기 작업(`save_png` 450ms)은 WorkerThreadPool +
`call_deferred` 완료콜백 + cooldown 레이트리밋.
**증거**: `ec8803573`(622 gap윈도우 중 증폭 0), `cce62b3ee`(450ms→0-40ms).
**안티패턴**: op 자체를 빠르게(faster _draw/save_png)만 하거나 캐치업을
irreducible 엔진비용으로 오분류.

### 5. Bake-once-then-budget — 두 문제 클래스(둘 다 "필요한 만큼만, 미리")
이 기법은 *별개의 두 비용*을 같은 발상으로 친다. 증상이 다르니 하위로 분리한다.

**5a. 정적 bake — 전투 중 프레임당 ms.** frame-invariant 출력을 매 프레임 재계산.
frame-invariant vs frame-varying 분리: 불변은 **1회 bake**(지오메트리-키 ImageTexture
blit / 재사용 member dict), 가변(웨지/텍스트/리퀴드/LOD변형/진행중 애니)만 즉시드로.
bake는 prewarm 또는 shared per-frame USEC 예산(700us) 하에서, **첫 핫프레임 lazy bake
금지**(준비 전 즉시 벡터 폴백). 증거: `ec6fd5a30`(S1/S2 필러 정적레이어 + 스냅샷
재사용). 봉인: 픽셀 패리티.

**5b. 로딩 시간 단축 — 벽시계 초 (진입/전환 로딩).** 두 레버를 함께:
- **budgeted batching**: one-step-per-frame 로딩 루프를 시간예산+스텝캡으로 한 프레임에
  여러 스텝 묶되, **frame-gated 대기(공유 스레디드 슬롯 / battle_resources 자체 슬롯 /
  PSO 노드)마다 YIELD**(스핀폴 시 MAX_POLLS 조기도달→동기폴백 강등). *효과 36→26s.*
- **★ 메뉴 유휴 백그라운드 프리웜 = 유휴 UI 시간 뒤로 로딩 숨기기/앞당기기 (지배 레버).**
  캐릭선택 등 사용자가 유휴인 UI 화면에서 다음 씬 자산을 프레임당 1 threaded 로드로
  정적 캐시에 선적재 → 부팅 스텝이 캐시 히트로 폴링 없이 즉시 완료 + cross-path
  harvest로 고아 슬롯 회수. *효과 26→**9s**(전체 36→9s의 진짜 쾌거).*
- 증거: `f3627a17e`. 봉인: 예산/yield 스모크 + 하베스트/잡커버리지 스모크.
- 상세 케이스 스터디: [[stage1-entry-loading-optimization]](Claude memory).
- AGENTS.md에 standing rule 있음(bounded threaded prewarm + one-step-per-frame
  batching yield 가드) — 거긴 이미 상세하니 거기로.

### 6. Felt-verdict-gated budget + shallow-when-read-only
**증상**: 지각적 목표(부드러움)인데 지표가 오염됨 / read-only 소비자에 딥카피.
**기법(felt 게이트)**: 잔여 doubling%가 instrument-class(로깅 파이프 observer
effect + 지각 임계 아래 양자화 단발 스킵)임을 catch-22로 증명한 뒤 felt-우선으로
승급 결정.
**기법(딥카피 킬)**: 한 키만 swap/filter하려고 read-only 소비자에게 dict를
`duplicate(true)`하면 낭비 → `duplicate(false)` 얕은카피. 소비자 read-only 확인
필수.
**증거**: `6a7b1e935`(felt verdict 승급), `26776181d`→`6e96842aa`(Stable Monitor
48→72, divisor 테이블 pure함수 point-by-point 봉인), `e5e9316c6`(commando
발사프레임 VFX배열 딥카피 제거).

---

## 증상 → 기법 빠른 매핑

| 증상(진단 결과) | 기법 |
|---|---|
| opaque 집계 라벨 | #1 먼저 쪼개기 |
| 상시 per-tick owner re-push | #2 last-pushed 게이팅 |
| 첫 발생 수백ms stall | #3 peek / 이산 prewarm |
| `draw == proc + phys` 증폭 / 동기 블로킹 burst | #4 coalesce / offload |
| frame-invariant 출력 매프레임 재계산(전투 중 ms) | #5a 정적 bake |
| 긴 진입/전환 로딩(벽시계 초) | #5b budgeted batching + ★메뉴 유휴 프리웜 |
| 오염된 페이싱 지표 / read-only 딥카피 | #6 felt 게이트 / 얕은카피 |

어떤 기법이든 **봉인 규율 6개(특히 5번 반증검증 스모크)는 생략 금지.**
