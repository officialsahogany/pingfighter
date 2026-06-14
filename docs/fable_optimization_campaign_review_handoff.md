# fable 최적화 캠페인 + 문서 큐레이션 — Codex 리뷰 핸드오프

작성 2026-06-14. fable-5가 2026-06-10~14에 수행한 **프레임 예산 최적화 캠페인
전체(24커밋)**와, 그 노하우를 추출/정리한 **문서 큐레이션 작업**을 Codex가
리뷰할 수 있게 묶은 패킷. 세션 단위 핸드오프(이번 세션 4커밋 범위)는 별도
`docs/frame_budget_optimization_session_handoff.md`.

## 0. 브랜치/HEAD 상태 (먼저)

- 브랜치 `feature/plaza-hub-s4-s6b5`, HEAD `3833d8ad5`. 아래 24개 최적화 커밋 +
  큐레이션 커밋(3833d8ad5)은 **전부 HEAD 조상으로 도달 가능**(검증됨). 그 위에
  plaza/lingpet/lumion 신규 커밋이 쌓여 `git log -5` 상단엔 안 보일 수 있다 —
  `git show <hash>`로 직접 리뷰.
- **checkpoint 브랜치 HEAD 유동 + 메모리 동시편집 주의**: 이 repo는 외부 세션이
  브랜치 HEAD와 일부 진행 메모를 세션 중 전진/수정한다. 리뷰/체리픽 전
  `git branch --contains <hash>`로 위치 재확인.
- 정리 방법론(이 캠페인이 도출한 것): **수정 기법 카탈로그**
  `docs/godot_perf_optimization_playbook.md`, **진단 순서**는 메모리
  `feedback_pingfighter_fps_audit_order`(0단계 유병률 triage), **자세**는
  `docs/agent_operating_posture.md`.

## 1. 최적화 캠페인 — 6기법별 커밋 (전부 `git show`로 리뷰 가능)

각 기법의 상세 메커니즘/안티패턴은 `docs/godot_perf_optimization_playbook.md`.
아래는 커밋→기법 매핑으로, Codex가 diff를 의미 단위로 묶어 보게 한 것.

### 기법1 — Decompose-before-optimize (계측 먼저, measurement-only)
손대기 전에 opaque 라벨을 gap-free 서브라벨/마이크로벤치로 분해. **전부
non-behavioral**(optional perf_logger, arg-count reflection 백호환).
- `8d6f534ed` match-reset 서브스텝 계측 (370ms reset 귀속)
- `c028741b2` lingpet update 페이즈 계측 (1.0ms leaf 분해)
- `11f0a86bc` mythic per-tick family 계측 → **81%가 sync_after로 판명**(직관과 반대)
- `1364d821f` mythic transient sync 마이크로벤치 (`godot/tools/mythic_sync_microbench.gd`)
- `4129bc21e` lingpet update-vs-save 분리 (acquire-resume 50ms 스파이크)
- `38b980583` round-restart/reset-ball 계측 (round-resume 3.5ms 귀속)
- **리뷰 포커스**: 계측이 동작을 바꾸지 않는지(early-return 헬퍼 추출로 gap-free,
  result를 로컬로 캡처). perf_logger 누락 시 null-safe.

### 기법2 — Last-pushed-cache write gating (idempotent owner sync diffing)
매 틱 owner re-push를 로컬 last-pushed 캐시와 diff. **owner가 아니라 캐시와 비교**
(owner 읽기 자체가 read+deepcopy). + 스키마 선언 따름정리.
- `41949554c` lingpet snapshot owner sync 게이팅 (owner.set 10100→166/100틱, −98%)
- `d923fe1ff` mythic transient를 owner 아닌 last-pushed와 비교
- `b9ff8c38f` pushed state dict 유지 → dirty 틱도 owner read 스킵
- `798754ba1` mythic 라운드시작 풀싱크(254키×2) → change-gated transient (3.5→0.4ms)
- `fffdaa886` lingpet 17키 `DEFAULT_VALUES` 선언 (게이트된 write가 안 죽게)
- **리뷰 포커스**: invalidate가 boundary 훅에만 걸리는지(누락 시 stale), 컨테이너
  양측 detach(alias 방지), gated 키가 전부 스키마 선언됐는지. 봉인 스모크가
  owner read/write를 카운트하고 pre-fix에서 FAIL하는지.

### 기법3 — Peek vs discrete-moment prewarm (lazy-init 핫패스 분리)
reset/"활성?" 소비자는 `get_cached_instance()` peek, 진짜 첫 생성은 이산 시점으로.
- `19de08968` match-reset deps를 get_instance→get_cached_instance peek (370ms/574ms stall)
- `f8ce7a2fb` lingpet 스킬 모듈+512px 시트를 loadout-apply에서 prewarm
- `952ca026b` 획득 시네마틱 호스트+아이콘 시트를 ball-spawn intro에서 (52ms)
- `0c1d0c778` CLAUDE.md Hot-Path Lazy Init Trap에 lingpet 사례 백필
- **리뷰 포커스**: peek가 정말 비생성인지(안 만들어진 모듈=리셋할 state 없음 논리),
  prewarm이 idempotent하고 rally 밖인지. 봉인 스모크가 cold-create 0건을 단언.

### 기법4 — Decouple trigger cadence (coalesce / offload)
- `ec8803573` physics-tick redraw를 프레임당 1회로 coalesce (**진단 시그니처
  `draw==proc+phys`**; 622 gap윈도우 중 증폭 0)
- `cce62b3ee` 스크린샷 PNG 인코드를 워커 오프로드 + cooldown (450ms→0-40ms)
- **리뷰 포커스**: legacy owner(테스트 fake) 폴백 경로 유지, 워커 완료가
  call_deferred로 메인스레드에만 노드 상태 쓰는지, _exit_tree에서 pending await.

### 기법5 — Bake-once-then-budget (정적 캐싱 + 예산 배칭)
- `ec6fd5a30` 필러 HUD 정적 레이어 ImageTexture 캐싱 + 핫패스 스냅샷 재사용
  (가변=즉시드로, 픽셀 패리티 스모크)
- `f3627a17e` 진입 로딩 36→9s (budgeted warmup + 메뉴 유휴 프리웜, yield 가드 3종)
- **리뷰 포커스**: 첫 핫프레임 lazy bake 금지(prewarm/예산하), 캐시 준비 전
  correctness-identical 폴백, budgeted 루프가 frame-gated 대기마다 YIELD하는지
  (스핀폴 시 MAX_POLLS 조기도달→동기폴백 강등). 무효화 키에 render_scale 포함.

### 기법6 — Felt-verdict-gated budget + shallow-when-read-only
- `29755ee7a` spike 재측정 + 측정 위생(F12/F3/F7 금지) 문서화
- `6a7b1e935` clean-run felt 판정 → 잔여 doubling은 instrument-class로 증명
- `26776181d` Stable Monitor 기본화 (schema 5 마이그레이션, move-together)
- `6e96842aa` Stable Monitor 144Hz 48→72 승급 (divisor 테이블 pure함수 봉인)
- `e5e9316c6` commando 발사프레임 VFX배열 딥카피 제거 (read-only 소비자→얕은카피)
- **리뷰 포커스**: 페이싱 승급이 felt 게이트에 걸렸는지 + co-dependent 상수
  move-together(schema bump/마이그레이션/미러/전 언어 문구/스모크). 딥카피 킬이
  소비자 read-only를 코드로 확인했는지, 봉인 스모크가 mutating 변종에서 FAIL.

## 2. 문서 큐레이션 작업 (커밋 `3833d8ad5` + 메모리)

캠페인 노하우를 추출/정리한 작업. git history 전수분석(워크플로 fan-out)으로
24커밋에서 6기법을 도출했다.

- **신규 `docs/godot_perf_optimization_playbook.md`** — 6기법 + 모든 기법 관통
  봉인규율 6 + 증상→기법 매핑표 + 커밋 증거. (메모리 미러
  `feedback_godot_perf_optimization_playbook`).
- **신규 `docs/frame_budget_optimization_session_handoff.md`** — 이번 세션 4커밋
  + open 회귀 + 블로커 + Codex 체크리스트.
- **`docs/frame_budget_72fps_optimization_design.md`** — 포인터 추가로 triad 완성
  (설계=plan / 플레이북=기법 / 핸드오프=현재).
- **메모리 정리**: stale "미커밋"→커밋 해시 갱신
  (`project_stage1_entry_loading_optimization` f3627a17e 등), 플레이북 상호링크.
  진단 노트(`feedback_pingfighter_fps_audit_order`)에 0단계 유병률 triage 강화.
- **큐레이션 감사 결과(워크플로)**: perf 메모리/문서 전수감사 — **모순·삭제 대상
  0건**. trap 노트(felt-vs-metrics/phys-shell-gap/stride-lod/no-frame-pacing)는
  전부 현행이고 플레이북과 직교. `project_stage2_stutter_investigation`(41KB)은
  **병렬 세션 동시편집 중**으로 판명되어 의도적으로 trim하지 않음(현행 작업
  보호). 메모리는 Claude 환경 전용(repo 미반영) — Codex는 docs/만 봄.

## 3. open 항목 (Codex 진단 환영)

- **★ stage1 viper `mythic_items` 0.67→3.04ms 회귀** (plaza/lingpet/lumion 신규
  커밋 이후, 06-14 측정). 더블링 94%. detail 플래그 꺼져 per-item 미분해 —
  기법1(계측 먼저)로 mythic 서브라벨 분해 후 기법2(last-pushed 게이팅) 적용이
  자연스러운 다음 슬라이스. 상세: `frame_budget_optimization_session_handoff.md` §3.
- **트램펄린 묶음 미커밋** (active_item_* + 언트랙드 8파일 동반 필수 — 누락 시
  로드 실패). 이 묶음 커밋 전엔 effects 콜백 경로 엉킴.
- **stage2 spike 소스**: commando(완료) 외 fresh 측정 필요(에이전트 attribution
  모순 사례 있음 → 검증 안 된 데이터로 캐시 금지).

## 4. Codex 리뷰 체크리스트

1. 기법별 커밋 diff 정합성 — 특히 기법2 invalidate 경계 누락/스키마 미선언,
   기법3 peek 비생성 정확성, 기법4 워커 완료 메인스레드 격리.
2. 각 봉인 스모크가 **카운트 기반 + pre-fix FAIL**인지 (반증검증 실효성).
3. ★ stage1-viper mythic_items 3ms 회귀의 per-item 원인 — 신규 커밋 diff에서
   per-frame 풀싱크 재도입/신규 파티클·owner.set 의심.
4. 플레이북 과대주장 여부 — leverage 수치가 커밋 메시지 실측과 일치하는지.
5. 트램펄린 커밋 스코프(언트랙드 8파일 동반).

## 5. 측정 재현

`godot/`에 `battle_perf_log.flag`(+세부는 `battle_perf_detail.flag`,
`battle_perf_samples.flag`) 생성 후 플레이. 측정 위생: F12/F3/F7/디버그 스폰
중 금지(각각 측정 오염). 로그
`%APPDATA%\Godot\app_userdata\pingfighter\logs\godot.log`. 분석은 일회용
distiller(라벨 유병률 present-in-X/N + avg/max 집계, peak max 아님). 진단 끝나면
`.flag` 정리.
