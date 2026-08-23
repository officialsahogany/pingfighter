---
paths:
  - "godot/**"
---

# Godot Runtime Trap Essence Rules

This path-scoped file owns the actionable 3–8 line essence for each stable
`GRT-NNN` entry. Root `CLAUDE.md` is discovery-only; full evidence and seals
live in `docs/godot_runtime_traps.md`. IDs are append-only.

## GRT-001 — Godot ConfigFile UTF-8 BOM Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-001)

`ConfigFile.load()` silently skips the FIRST section when the file starts
with a UTF-8 BOM (PowerShell `Out-File` / Notepad add it invisibly). If logs
say `load OK` but first-section keys fall back to defaults, suspect BOM
first: read raw bytes, strip the BOM, rewrite without it; keep a `last_good`
recovery path for player-facing settings. Full rule:
`docs/godot_runtime_traps.md`.

## GRT-002 — Godot High-Refresh Pacing Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-002)

The 144Hz divisor-lock display hypothesis is tested and REJECTED -- do not
re-run display-setting matrices. Known-good = 60Hz + 60 FPS + VSync On;
shipped default = Stable Monitor (144Hz -> render 72 / physics 72, single
lever `RENDER_FPS_CAP_STABLE_PREFERRED_MAX := 72`), bootstrap safety cap 48
in `project.godot`. Changing the shipped default requires moving ~7 places
together -- full list + tick-sync / tunneling notes:
`docs/godot_runtime_traps.md`.

## GRT-003 — Godot Hot-Path Lazy Init Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-003)

- 증상: `_physics_process` / `_process` / `_draw`의 첫 lazy 생성은 100ms+ hitch를 만든다.
- 필수: boot·loading·loadout 시점에 prewarm하고 상태 조회는 non-instantiating cached peek만 쓴다.
- 필수: dependency 생성은 소비 단계보다 먼저 두고, 새 stage는 controller 등록과 child delegation을 함께 한다.
- 검증: cold first-entry·transition 시간을 재고 실제 staged-prewarm 경로가 작업을 수행했는지 단언한다.

## GRT-004 — Godot Missing Reserved-Asset Per-Frame Re-Stat Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-004)

The resource loader caches SUCCESSES only: a reserved-but-absent asset path
in a per-frame draw path re-stats the filesystem EVERY frame, and the
once-only warning dedup makes it silent. Never wire a not-yet-generated path
into per-frame draw; point it at a placeholder or land the art + a
`file_exists` assert in the same slice. Full rule:
`docs/godot_runtime_traps.md`.

## GRT-005 — Godot Threaded Texture Cross-Path Timeout Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-005)

`ProjectResourceLoader.prewarm_texture_threaded_step()` has one shared texture
slot. Foreign waiters use their OWN timeout and never drain the current owner.
The current owner bypasses both project `_texture_cache` and engine
`ResourceLoader.has_cached()` shortcuts, then closes only through terminal
`load_threaded_get()`; otherwise cleanup can detach a logically completed
request and leak ObjectDB state. Readiness gates wait or degrade, never
sync-load. The focused prologue smoke seals foreign expiry and same-owner cache
exposure; its windowed preflight seals all eight terminal collections.

## GRT-006 — Godot Animated Polygon Triangulation Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-006)

Any `draw_colored_polygon()` point set built from animated offsets must be
provably triangulable -- guard fills with `Geometry2D.triangulate_polygon`,
keep outlines / safe fallbacks visible, and treat repeated `Invalid polygon
data` spam as a frame-budget regression. Runtime rule owner: `AGENTS.md`
("Godot Degenerate `draw_colored_polygon` Trap"); details:
`docs/godot_runtime_traps.md`.

## GRT-007 — Godot Effect Drawer Static-Frame Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-007)

- 증상: resolver·tick·drawer가 다른 timer key를 쓰면 효과가 frame 0에서 멈춘다.
- 필수: effect family마다 `timer_frames` 또는 `duration_frames` 하나만 끝까지 사용한다.
- 필수: terminal reason별 visible impact를 whitelist하고 expire/out-of-bounds fizzle은 만들지 않는다.
- 검증: 여러 프레임의 progress 변화와 terminal negative reasons를 함께 단언한다.

## GRT-008 — Godot Negative-Z Backdrop Host vs Ancestor Opaque Fill Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-008)

- 증상: global canvas z 때문에 negative host는 ancestor fill 아래, fixed positive host는 높은 ancestor 아래 묻힌다.
- 필수: detached host는 draw 진입 시 먼저 숨기고, 성공한 sync 말미에만 다시 켜며 reset/clear에서도 직접 내린다.
- 금지: 단일 Node2D로 actor 사이 z를 흉내 내지 말고 producer 전체가 공유하는 exclusion predicate를 사용한다.
- 필수: authored-facing flag·UV mirror·손 위치 projectile origin·letterbox cull 계약을 함께 유지한다.
- 검증: 투명 실루엣의 실제 Vulkan pixel capture와 생산 분기 관통 smoke로 가시성·숨김을 모두 봉인한다.

## GRT-009 — Godot 보스 예측 모델 트랩 ("불규칙하게 흔들면 막기 어렵다"는 거짓)

[Full ledger](../../docs/godot_runtime_traps.md#grt-009)

- 증상: smooth curve·대칭 흔들기·넓은 횡궤도는 매 프레임 재예측하는 보스를 속이지 못하거나 더 쉽게 만든다.
- 필수: prediction break는 마지막 8~16프레임의 단발 미래가속으로 두고 timing은 `remaining_y / (abs(vy) * boost)`로 구한다.
- 필수: turn resolver에는 정착 deadzone을 두고 miss 오차폭은 실제 paddle miss 임계보다 커야 한다.
- 필수: 연계 타격은 되감지 않는 hit serial+만료 pending으로 발행하고 이미 이긴 latch는 매 프레임 재검증한다.
- 검증: 실제 resolver·이동 후처리·충돌 왕복을 관통해 변위 px, 속도, 감속축, 최종 miss를 단언한다.

## GRT-010 — Godot 회복 램프 플레이어 재개입 트랩 (해제는 구조적으로 한 프레임 늦다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-010)

- 증상: update보다 먼저 속도 크기를 덮는 ramp는 player hit 해제가 한 프레임 늦어 입력속도로 skill을 시딩한다.
- 필수: player `bounce()` 정본에서 방향은 보존하고 속도 크기만 원래 max 의미론으로 복원한다.
- 필수: freeze 중 관련 cooldown도 감소하지 않게 한다.
- 검증: RNG·실 activation을 고정하고 cap 비포화 구간의 속도와 타이밍을 단언한다.

## GRT-011 — Godot Per-Frame Probability Roll Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-011)

- 증상: multi-frame window에서 매 프레임 chance를 굴리면 누적확률이 거의 100%가 된다.
- 필수: opportunity당 한 번만 roll하고 opportunity 종료 때만 lock을 해제한다.
- 필수: 체감 차이를 power로 보정하기 전에 표시 확률의 의도된 scope를 확인한다.
- 검증: 실제 outcome과 `ball_vel * delta * 60` 경로, 반복-frame 부정 leg를 단언한다.

## GRT-012 — Godot Companion Walk/Idle Ratio Trap (treadmill in place)

[Full ledger](../../docs/godot_runtime_traps.md#grt-012)

A companion "marching in place" is usually a POSITION bug, not an animation
bug -- first prove `_companion_pos` advances (reference: `patrol_dir` parked
at 0 by the defense intercept and never re-seeded). The walk/idle gate must
be driven by ACTUAL drawn movement (never intent constants / hardcoded 1.0),
the walk clock must freeze when `update_lingpet` is skipped, and renderer /
animator thresholds must match (0.01). Three mechanisms + seals:
`docs/godot_runtime_traps.md`.

## GRT-013 — Godot Companion Teleport/Reposition Locomotion Trap (ground pet keeps Y)

[Full ledger](../../docs/godot_runtime_traps.md#grt-013)

Position-scripting skills (teleport / blink / dash / recall) must pick the
target Y by locomotion style: ground (`patrol`) pets keep their lane Y
(X changes only), flight pets may dive freely. The divergence is ~0 at base
paddle height, so regression smokes MUST use a non-base paddle height.
Full rules: `docs/godot_runtime_traps.md`.

## GRT-014 — Godot Emergency-Assist Static-Paddle Gate Trap (committed player dash reads as "can't block")

[Full ledger](../../docs/godot_runtime_traps.md#grt-014)

"플레이어가 막을 수 있나?"를 패들의 **현재 정지 스팬**으로만 판정하는 비상지원
게이트는 대쉬 비행 중 프레임마다 "못 막음"으로 오판해 이중수비를 만든다(링크포트
사례). 대쉬는 방향·지속 확정된 스크립트 이동이니 접촉 시점 위치를 투영하라 —
잔여 이동은 shipped 감속 커브(`compute_total_dash_distance` 차분)를
`frames_to_contact`로 캡. ⚠️"대쉬 중이면 무조건 보류"는 금지(반대방향·짧은 타이머는
실제로 못 막음), 보류가 per-opportunity 굴림 락을 소모해선 안 되고, 스냅샷 읽기는
핫패스라 peek 전용. 씰=4레그+대조군 필수. Full rule: `docs/godot_runtime_traps.md`.

## GRT-015 — Godot Lingpet Companion Incapacitation Body-Hit Trap (parked ≠ disabled)

[Full ledger](../../docs/godot_runtime_traps.md#grt-015)

- 증상: 위치만 고정된 companion은 self-stun·freeze 중에도 body hit와 선제타격이 살아 있다.
- 필수: 단일 suppression predicate로 body hit와 anticipatory strike를 함께 막되 charge/active phase는 유지한다.
- 필수: satiety exhaustion도 passive position override와 무관하게 `companion_active`에 반영한다.
- 검증: incapacitation·exhaustion 강제 후 억제와 정상 active 대조군을 모두 단언한다.

## GRT-016 — Godot 링펫 스킬 idle-업데이트 게이트 "보이는 것 ≠ 살아있는 것" 트랩 (VISIBLE vs LIVE)

[Full ledger](../../docs/godot_runtime_traps.md#grt-016)

- 증상: visible effect가 없다는 이유로 update를 끊으면 비시각 live timer·예약발사·owner flag가 영구 동결된다.
- 필수: idle skip gate에 `needs_runtime_update_for_skill(skill_id)`를 포함하고 새 skill을 그 registry에 등록한다.
- 금지: 재시전 정책인 `is_launch_blocked()`를 생존 술어로 재사용하지 않는다.
- 검증: 직접 update가 아니라 실제 idle gate를 관통해 live state가 계속 전진함을 단언한다.

## GRT-017 — Godot Owner-Field Schema Trap (runtime stat → character-info panel)

[Full ledger](../../docs/godot_runtime_traps.md#grt-017)

`owner.set(key, ...)` is a SILENT no-op for keys not declared in
`BattleSceneState.DEFAULT_VALUES`, and readers fall back to catalog / base
values that mask the drop. Declare every synced key, test the DIVERGENT
(boosted != base) case through a schema-gated owner, and diff primary vs
second / duplicate sync helpers (a sibling omitting one key pins the panel
at base). Structural seal + slot-sentinel rules:
`docs/godot_runtime_traps.md`.

## GRT-018 — Godot Two-Update-Path Context-Flag Trap (effects-path flag read on the ball path)

[Full ledger](../../docs/godot_runtime_traps.md#grt-018)

- 증상: effects context의 flag를 ball path에서 읽으면 영원히 false이고 양쪽 tick은 타이머를 2배속으로 만든다.
- 필수: 경로 전용 flag는 activation 때 state에 캡처하고 timer는 정확히 한 update path에서만 감소시킨다.
- 필수: victory-loot처럼 player-control만 도는 phase는 공 스킬 activation을 닫고 막힌 프레임에 자기해제시킨다.
- 검증: 서로 다른 두 context, dual-path 한 프레임, 실제 victory-loot gate를 각각 관통한다.

## GRT-019 — Godot Shared Stateful Input-Reader Edge-Eating Trap (extra get_snapshot() consumer)

[Full ledger](../../docs/godot_runtime_traps.md#grt-019)

- 증상: controller 밖의 추가 `get_snapshot()` 소비자가 same-frame just-pressed/released edge를 먹는다.
- 필수: stateful reader snapshot은 physics frame당 idempotent해야 한다.
- 금지: guard 없이 off-path edge reader나 per-frame sampler를 추가하지 않는다.
- 검증: 동일 프레임의 두 소비자가 같은 edge를 보는 production-path smoke를 유지한다.

## GRT-020 — Godot Lazy Applied-Key Re-Apply Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-020)

An "already applied" early-return that sits BEFORE the key recompute makes
key-CONTENT changes invisible -- "include the new input in the key" alone is
a silent no-op; the only levers are explicit invalidation plus folding the
input into downstream value caches. Smokes must drive the REAL apply path
(stale persists -> invalidate -> new value lands). Full rule:
`docs/godot_runtime_traps.md`.

## GRT-021 — Godot Stats-Panel Row Budget Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-021)

`draw_lingpet_stat_rows` silently DROPS rows that overflow the section rect
(sibling of the tooltip shared-line-budget clip trap). When adding a panel
row, assert draw-time capacity via `lingpet_stat_rows_visible_capacity` at
the stacked-layout (<620px) rect, or define which row yields. 드로어를 다른
화면에서 재사용하면 최소 높이에 **크롬 안쪽 여백까지** 더하고(퍽 선택 능력치
띠: 11*2+49+19*10+8=269), 판정은 **실제 append된 행 rect 개수** + 최소 미만
음성 대조로. 예산 부족 시 잘라 그리지 말고 통째로 끌 것. Full rule:
`docs/godot_runtime_traps.md`.

## GRT-022 — Godot 공유 레이아웃 빌더 요소-추가 트랩 (그린 자리와 클릭 자리가 갈라진다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-022)

세로 중앙 정렬 모달의 `build_layout`은 그리기와 **히트테스트 양쪽**을 먹인다 —
`group_h`에 요소를 더했으면 `get_card_rects` / `get_card_index_at`에도 같은
플래그를 흘려라(정본 한 곳, 갱신은 draw가 아니라 **update 초입**).
⚠️반증을 **카드 중심점**으로 하면 밀림 < 카드높이/2라 통과한다 — **상단
모서리**로 재라. 동반: 줄인 치수에서 파생된 폰트 배율(카드 폭 → 이름/성급/설명,
원장 높이 → `status_scale`)이 같이 내려오니 기준값을 함께 옮기고, 텍스트
누출은 캡처 말고 실 wrap 캐시로 headless 판정. Full rule:
`docs/godot_runtime_traps.md`.

## GRT-023 — Godot Boss Skill Card Rail Commando-Avoidance Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-023)

`resolve_stack_start_y`'s `avoid_rect` arg is OPTIONAL -- a stage card-rail
renderer that omits `commando_firearm_panel_rect` silently disables Commando
firearm-HUD avoidance and buries that UI under its card stack. Every new
stage renderer must read + forward the rect AND be added to the coverage
smoke's hardcoded path list (prefer the behavioral seal). Full rule:
`docs/godot_runtime_traps.md`.

## GRT-024 — Godot Lingpet Second-Active-Slot HUD Parity Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-024)

- 필수: 모든 HUD·debug·localization 소비자는 `companion_skill_*`와 `*_1`을 모두 읽는다.
- 금지: casting을 전역 OR로 합치지 말고 각 slot의 실제 skill kind로 계산한다.
- 필수: 교체 비교는 resolved skill dict의 effective `level`을 쓰며 roll 0은 빈 slot으로 유지한다.
- 필수: 이름과 설명을 모두 번역하고 빈 slot을 기본 loadout으로 채우지 않는다.
- 검증: dual-active, slot별 casting, 두 번째 passive, effective level, empty-roll을 한 snapshot에서 단언한다.

## GRT-025 — Godot Boss-Paddle-Scripting Skill Trap (drag / grab / displace the boss)

[Full ledger](../../docs/godot_runtime_traps.md#grt-025)

Skills that SCRIPT the boss paddle position (puppet-grab class) must keep
six invariants together: boss-AI freeze flag, ball collision preserved with
LIVE-anchor post-hit snap + `boss_collision_cooldown` re-arm,
`DEFAULT_VALUES` declaration, self-healing release that survives an
owner-less `cancel(null)`, round-reset `boss_y` normalization, and home-band
anchors for "below the boss" guards. Reference: Koyora puppet grab + its
smoke. Full invariants: `docs/godot_runtime_traps.md`.

## GRT-026 — Godot Boss-Paddle-Range-Restriction Skill Trap (clamp / cage the boss)

[Full ledger](../../docs/godot_runtime_traps.md#grt-026)

Cage / lane / wall skills are NOT the freeze pattern: clamp the final
`boss_pos.x` AFTER normal boss AI output while preserving `boss_vel` (the
boss keeps playing inside the cage). Schema keys, puppet-grab precedence,
owner-less self-heal, and outcome smokes as listed. Full checklist:
`docs/godot_runtime_traps.md`.

## GRT-027 — Godot Boss-Paddle-Resizing Skill Trap (shrink / grow the boss paddle)

[Full ledger](../../docs/godot_runtime_traps.md#grt-027)

Never resize `boss_paddle_size` directly -- the render center is
width-coupled, so the boss visibly slides sideways while shrinking. Keep
shared contexts full-size and inject a separate CENTERED scale for collision
(`boss_collision_shrink_scale`) and render (`boss_paddle_shrink_scale`)
reading the same owner flags; smokes must assert geometry OUTCOMES (hit vs
miss), not just flags. Full rules: `docs/godot_runtime_traps.md`.

## GRT-028 — Godot Shared HUD Wrapper Prep-Before-Gate Trap (build-then-discard per frame)

[Full ledger](../../docs/godot_runtime_traps.md#grt-028)

A shared per-frame HUD / rail wrapper serving multiple stages must hoist its
cheapest discriminating gate (stage id / active flag) ABOVE the caller-side
prep. A gate living only inside the callee renderer turns `context.duplicate()`
+ `LingpetRailCard.append_entry()` -> lingpet `get_snapshot()` into invisible
build-then-discard cost every frame (0.6~1.3ms/frame, grows with companion
activation; each `append_entry` = one full snapshot build). Seal with a
non-owning-stage call-count smoke. Full rule: `docs/godot_runtime_traps.md`.

## GRT-029 — Godot 공유 파티클 배열 꼬리-윈도우 렌더 컷 × 스폰 순서 트랩

[Full ledger](../../docs/godot_runtime_traps.md#grt-029)

임팩트 파티클 드로어는 배열 **뒤에서** `render_limit` 개만 그리고
(`particle_start = size - render_limit`), 캡 초과분도 `pop_front` 로 버린다 →
**먼저 append 한 것이 먼저 죽는다.** 한 효과의 레이어를 쌓을 땐 스폰 순서 =
생존 우선순위(잔량 스파크 먼저, 정체성 번개/플래시 나중). 씰은 **severe LOD
예산**으로 — 풀 예산은 효과 한 벌과 크기가 같아 변별력 0이다. 동반: 공유
`update()` 이동 분기는 `vel` 을 직접 인덱싱하므로 **정지형 신규 타입은 그 조건에
등재**해야 하고(누락 시 `Invalid access ... 'vel'`), 씰은 실 update 틱 관통.
Full rule: `docs/godot_runtime_traps.md`.

## GRT-030 — Godot Slot-Indexed HUD State Array-Shift Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-030)

Array-backed HUD slots compact / reorder, so `slot_index` is not stable item
identity. Acquisition-style effects must distinguish empty -> item from
non-empty -> different-key shifts: the former may pop, the latter should update
the tracked key while suppressing acquisition UI unless an explicit pickup
event says otherwise. Seal replacement + `remove_at` compaction cases. Full
rule: `docs/godot_runtime_traps.md`.

## GRT-031 — Godot 반쪽-랜딩 슬라이스 트랩 (표시가 없는 브리지를 근거로 댄다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-031)

- 증상: producer/bridge 없이 표시 절반만 랜딩하면 UI가 존재하지 않는 소비 계약을 주장한다.
- 필수: 표시 문구·수량마다 실제 producer와 counter 경로를 추적하고 non-consuming 항목은 free cell로 분리한다.
- 검증: 예산을 가득 채운 fixture로 overflow를 만들고 producer-zero 문구도 확인한다.
- 변종: feature flag 감사는 flag 이름이 아니라 제거되는 group key로 검색하고 flag-ON leg를 둔다.

## GRT-032 — Godot Per-Frame Catalog Lookup Trap (miss-case full scan + deep copies)

[Full ledger](../../docs/godot_runtime_traps.md#grt-032)

A catalog / registry helper on a per-frame draw or physics path must be O(1):
the lingpet rail's `is_lingpet_skill()` full-scanned all 14 pets with
`duplicate(true)` per call, and boss cards (guaranteed misses) paid it twice
per card per frame (~0.29ms/card = ~95% of the "draw" cost). Build a one-time
static id index; deep-copy only on hit; attribute cost with per-layer
sub-labels BEFORE designing render-side caches. Full rule:
`docs/godot_runtime_traps.md`.

## GRT-033 — Godot draw_polygon Un-Normalized UV Invisible-Quad Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-033)

- 증상: `draw_polygon`에 atlas pixel rect를 UV로 넘기면 edge texel에 clamp되어 quad가 무오류로 사라진다.
- 필수: texture size로 UV를 `[0,1]`에 정규화하고 point/UV corner 순서를 일치시킨다.
- 구분: `draw_texture_rect_region()`의 source rect는 pixel 단위가 맞으므로 혼동하지 않는다.
- 검증: 실제 textured pixels가 나타나는 pixel capture와 transparent-edge 대조군을 둔다.

## GRT-034 — Godot Modal-Block Gate Skips Loop-Audio Maintenance Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-034)

- 증상: physics-blocking modal의 조기 return이 `sync_*`를 건너뛰어 loop SFX가 modal 내내 반복된다.
- 필수: 공유 modal-block gate에서 모든 gameplay loop를 정지한다.
- 필수: 새 loop의 stop method를 `GameplayLoopAudioCleanup.STOP_METHODS`에 등록한다.
- 검증: 실제 frame controller로 modal을 열어 stop·비재무장·닫은 뒤 정상 복귀를 단언한다.

## GRT-035 — Godot 공유 큐 목록 삽입 × 형제 씰 절대-인덱스 트랩 (배치가 첫 실패에서 끊긴다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-035)

- 증상: 공유 목록 삽입은 형제 smoke의 절대 인덱스를 깨고 첫 실패 뒤 테스트를 전부 미실행시킬 수 있다.
- 필수: anchor는 실제 목록 크기·ID에서 파생하고 순서를 뒤집은 RED 반증검증을 남긴다.
- 검증: 출력의 필수 종단선 `All Godot smoke tests passed.` 없이는 batch 통과로 세지 않는다.
- 필수: overlay open 부수효과는 `open()`이, 입력별 close/cancel만 input handler가 소유하며 부정 leg를 둔다.

## GRT-036 — Godot 벤더 WAV 컨테이너 결함 트랩 (임포트는 되는데 매 로드마다 경고 → 러너 RED)

[Full ledger](../../docs/godot_runtime_traps.md#grt-036)

상용 라이브러리 WAV 는 RIFF 총크기 과대 선언·1MB급 트레일링 ID3 청크를 흔히
품는다. Godot 은 로드해 주지만 매 스트림 로드마다 WARNING 을 뿜고 표준 러너가
이를 실패로 승격해 스모크 배치가 RED 가 된다. 조치=러너 억제가 아니라 인테이크
시 청크 파싱 → data 끝에서 절단 + RIFF 크기 재기록(무손실). Full rule:
`docs/godot_runtime_traps.md`.

## GRT-037 — Godot Per-Tick Float Drain Rail-Residue Trap (is_equal_approx write-gating)

[Full ledger](../../docs/godot_runtime_traps.md#grt-037)

A real-tick float drain can strand the stored value on a sub-epsilon
positive residue that `is_equal_approx` write-gating freezes forever —
strict rail comparisons (`> 0`) then misjudge it every tick, so
rail-triggered states (포만도 탈진 KO) silently never fire while display /
slow-curve output still looks correct. Snap an ε-band onto BOTH rails in
the single sanitize helper; seals need residue-injection + real-tick
sequence legs (synthetic exact-0 cases prove nothing). Full rule:
`docs/godot_runtime_traps.md`.

## GRT-038 — Godot TextureRect Min-Size Clamp Renders At Native Texture Size Trap (use Sprite2D for scaled/rotated shader sprites)

[Full ledger](../../docs/godot_runtime_traps.md#grt-038)

- 증상: 기본 min-size가 texture 원본 크기로 `.size`를 되키워 작은 TextureRect가 native px로 렌더된다.
- 필수: 필요하면 `EXPAND_IGNORE_SIZE`를 texture/size보다 먼저 설정하고 회전 VFX는 `Sprite2D`를 우선한다.
- 검증: native width를 배제하는 실제 on-screen span assertion과 pixel capture를 사용한다.
- 필수: piecewise envelope·rotation은 phase 경계에서 C0 연속을 유지한다.

## GRT-039 — Godot 전역 물리 보간 오버레이 스폰-글라이드 트랩 (spawn-frame reposition glide)

[Full ledger](../../docs/godot_runtime_traps.md#grt-039)

전역 `physics_interpolation=true` 환경에서 노드를 (0,0)에 만들고 같은
프레임에 최종 위치로 옮기면 물리 틱이 따라잡을 때까지 이동 경로 중간
(화면 중앙 부근)에 렌더된다 — 로딩 카메오처럼 첫 프레임이 정체되는
구간에선 ~0.5초 유령으로 보인다. 이산 재배치형 정지 오버레이 호스트는
생성 시 `physics_interpolation_mode = OFF` 명시. 씰:
`battle_loading_screen_renderer_smoke`. Full rule:
`docs/godot_runtime_traps.md`.

## GRT-040 — Godot 스모크 임의 프로퍼티 대입 조용한 레그-abort 공허 GREEN 트랩

[Full ledger](../../docs/godot_runtime_traps.md#grt-040)

- 증상: 미선언 property/함수 오류는 해당 leg만 중단해 assertion 0건인데도 마지막 `ok`가 출력될 수 있다.
- 필수: `_failed`가 final ok/exit를 gate하고 SceneTree `_init()`은 deferred runner만 예약한다.
- 필수: fixture property 존재를 확인하고 표준 `run_smoke_tests.ps1`을 통과시킨다.
- 검증: 필수 종단선과 함께 `SCRIPT ERROR`, `^ERROR`가 0건인지 확인하고 고장 fixture를 RED로 본다.

## GRT-041 — Godot 퍽 표시 Projection-분기 후처리 탈락 트랩 (라이브=항상 projection)

[Full ledger](../../docs/godot_runtime_traps.md#grt-041)

라이브 스냅샷은 보유 퍽이 있으면 항상 융합 display projection을 실어
오므로 TAB/전투 퍽 표시의 실전 경로는 100% projection 분기다. 일반
분기에만 넣은 표시 후처리(슬롯 셀 확장, 런타임 상태 라인)는 스모크에서만
GREEN이고 실전에서 죽는다 — 공용 헬퍼 관통 + 실 `get_snapshot()` 레그 +
projection 비어있으면 fail-closed 가드 + 씰 CI 락스텝 등재까지가 한 단위.
Full rule: `docs/godot_runtime_traps.md`.

## GRT-042 — Godot 프리웜 경량-값-위해 무거운-모듈 콜드생성 트랩 (전환 프레임 1초+ 스톨)

[Full ledger](../../docs/godot_runtime_traps.md#grt-042)

프리웜/워밍이 값 하나 때문에 그 값을 소유한 무거운 모듈을 강제 인스턴스화하면
전환 프레임에 그 모듈 콜드 로드가 통째로 얹힌다(stage_clear_result_screen
골드 위해 1237ms/fps=2 사례). 그 값이 경량 리더로도 동일하게 얻어지고 무거운
모듈이 거기에 위임만 하는 중간자면 특히 낭비 — 경량 소스 직접 읽기로 워밍하고,
무거운 모듈은 자연 필요 시점에 생성, draw/consume은 non-instantiating peek 유지.
스텝형 프리웜 단일 프레임 1초+ 스톨=한 모듈 콜드생성 → 로더 헬퍼에 임계-게이트
경고(모듈키+ms) 심어 라이브 1판으로 범인 특정(존치=회귀 트립와이어).
Full rule: `docs/godot_runtime_traps.md`.

## GRT-043 — Godot HUD 상시-가시성 승격 × 프리미엄 절차 드로우 트랩 (봉인 예산 락스텝)

[Full ledger](../../docs/godot_runtime_traps.md#grt-043)

비용 = 단가 × 유병률: 프리미엄 절차 리드로우(단가↑)와 가시성 게이트 확장
(장착→퍽 보유 등, 유병률↑)이 각각 무해해 보여도 곱이 상시 회귀를 만든다
(센서 오브 0.26ms/frame 사례). 게이트를 넓히면 per-frame 비용 재평가 +
~10드로 사이트 초과 정적 스택은 bake-once; 리스타일이 세그먼트/레이어
상수를 올리면 봉인 budget smoke를 같이 돌려 락스텝 갱신(센서 아크 예산
씰 HEAD RED 사례). 정상 상태 픽셀 불변 HUD 박스는 리테인드 자식
CanvasItem + 상태 키 게이팅. Full rule: `docs/godot_runtime_traps.md`.

## GRT-044 — Godot Fullscreen Screen-Read Overlay Context-Fallback Sizing Trap

[Full ledger](../../docs/godot_runtime_traps.md#grt-044)

- 증상: context의 game size로 fallback한 screen-read overlay는 실제 viewport의 일부만 덮는다.
- 필수: tree 안에서는 `canvas.get_viewport_rect().size`를 primary로, context 값은 fallback으로 쓴다.
- 필수: tree 밖 호출은 `is_inside_tree()`로 지키고 builder의 canvas 인자는 optional trailing 값으로 둔다.
- 검증: view_size 없는 live형 context와 작은 game_size로 viewport 크기와 불일치를 단언한다.

## GRT-045 — Godot 스크린-공간 FX 호스트 플레이필드 클립 트랩 (구조 GREEN ≠ 픽셀 클립)

[Full ledger](../../docs/godot_runtime_traps.md#grt-045)

- 증상: detached node children은 playfield transform을 상속하지 않아 letterbox로 픽셀이 샌다.
- 필수: full 760x750 `Control(clip_contents=true)`을 두고 host-local origin/scale로 자식 좌표를 보정한다.
- 금지: ADD child에는 `CLIP_CHILDREN_ONLY` 마스크를 clipping 대용으로 쓰지 않는다.
- 검증: 비헤드리스 black-clear 픽셀 씰에서 clip ON leak=0, OFF leak>0을 단언한다.

## GRT-046 — Godot Fragment-Clip 캔버스-단위 vs 프레임버퍼-픽셀 트랩

[Full ledger](../../docs/godot_runtime_traps.md#grt-046)

- 증상: canvas 단위 rect를 framebuffer `SCREEN_UV`와 비교하면 scale≠1에서 하단·우측이 잘린다.
- 필수: final+canvas transform으로 clip rect와 feather·wave·ramp·span uniform 전부를 framebuffer px로 변환한다.
- 금지: 전체화면 여부 기반 보정을 쓰지 말고 hard discard 안쪽에는 feather band를 둔다.
- 검증: scale≠1에서 inside lit>0·outside lit=0 양방향 픽셀 씰을 돌리고 `content_scale_size`로 배율을 만든다.

## GRT-047 — Godot VFX 리브랜드 발광 예산 트랩 (ADD × 어두운 아트 = 더할 빛이 없다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-047)

레이어/블렌드/알파를 그대로 둬도 아트가 밝은 것→어두운 먹선으로 바뀌면 결과가
뒤집힌다: ADD는 어두운 텍스처에서 더할 빛이 없고(writhe 셰이더도 brightness
게이트로 같이 죽음), MIX 저알파는 어두운 배경을 "더 어둡게"만 하며, 속 빈 원환은
중심 발광이 0%다. **발광 정체성을 가운데가 찬 밝은 레이어로 재공급**하고 어두운
아트는 실루엣/질감만 맡겨라. 차징류는 `intensity` 시각 하한 필수(반경은 raw 유지).
`centered=true`+캔버스 맞춤은 새 텍스처의 fill 비율/무게중심 실측 후 재사용.
판정은 **강한 임계** 픽셀 카운트로(약한 임계는 버그·정상이 같은 값). Full rule:
`docs/godot_runtime_traps.md`.

## GRT-048 — Godot Duck-Typed `has_method`-Gated Dynamic-Call Arity Trap (caller-path seal, not direct-runtime seal)

[Full ledger](../../docs/godot_runtime_traps.md#grt-048)

`Object`로 보관된 덕타이핑 런타임을 `has_method` 게이트로 부르는 동적 호출
(`rt.notify_*(...)`)은 대상이 named class가 아니라 **인자수를 파서가 검증 못
한다** — 잉여/부족 인자가 파스를 통과하고 그 분기가 실제 발동하는 프레임에만
`Invalid call ... Expected N argument(s)`로 크래시. 형제 처리기에서 호출문을
복붙할 때 대상마다 `built`/`registry` 유무가 갈리니 인자 목록을 그대로 옮기지
말 것(역경의갑주 배리어 4인자 사례). 봉인은 런타임 함수 직접호출 레그로는
부족 — 실제 caller 경로를 관통하는 씰 필요. 표준 러너가 `Invalid call`을 실패
승격(공허-GREEN 방지). Full rule: `docs/godot_runtime_traps.md`.

## GRT-049 — Godot Ball-Path Owner-Snapshot Stat-Refund Trap (owner.set mid-collision → refunded at frame end)

[Full ledger](../../docs/godot_runtime_traps.md#grt-049)

- 증상: ball-path에서 owner stat만 차감하면 프레임 끝 `scene` snapshot 적용이 이전 값을 되써 환불한다.
- 필수: snapshot 대상 stat 변경은 ball-path의 `scene` dict에도 반영한다.
- 금지: `scene` 없이 context가 sync source인 effects/void 경로까지 같은 수정으로 건드리지 않는다.
- 검증: 직접 함수 단언이 아니라 실제 `scene -> collision -> apply_snapshot -> owner` 왕복을 봉인한다.

## GRT-050 — Godot 커맨드-버퍼 스킬 활성화 게이트 트랩 (막힌 게이트는 입력을 버리지 않고 미룬다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-050)

- 증상: gate보다 먼저 갱신한 command buffer는 닫힌 동안 입력을 보존해 해제 프레임에 지연 발동한다.
- 필수: gate마다 입력을 버릴지 미룰지 선언하고 combo opener를 후속기 activation gate에 넣지 않는다.
- 필수: 중첩 skill은 canonical handoff에서 pending speed cap을 consume한 뒤 deactivate한다.
- 검증: flag가 아니라 최종 ball speed를 단언하고 handoff 제거·순서 반전 대조군을 RED로 확인한다.

## GRT-051 — Typed 배열에 조건식 리터럴을 대입하는 draw-time 런타임 트랩

[Full ledger](../../docs/godot_runtime_traps.md#grt-051)

`var xs: Array[float] = [...] if cond else [...]`는 리터럴을 untyped `Array`로
추론해 파서/경고를 통과한 뒤 draw 실행 중 타입 오류로 함수를 중단시킬 수 있다.
명시적 typed 배열을 만들고 `append()`하라(양쪽 피연산자가 이미 typed면 안전).
봉인은 헬퍼 반환값이 아니라 트리-attached `CanvasItem._draw()`의 공개 renderer와
문제 phase를 관통하고, 표준 smoke runner의 엔진 오류 승격까지 확인해야 한다.
Full rule: `docs/godot_runtime_traps.md`.

## GRT-052 — Godot 패들-상대 오프셋 상수 1:1 포팅 트랩 (원본 패들은 바닥에서 24px 떠 있다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-052)

원본 패들 바닥선은 `HEIGHT(750) − PLAYER_FLOOR_OFFSET(40) + 리그보너스(챔피언
16) = 726`이라 **바닥에서 24px 떠 있고**, Godot 패들은 `height − paddle_height`로
바닥(750)에 **딱 붙는다**(floor offset 미포팅). `PLAYER.centery` 기준 오프셋을
리터럴로 옮기면 그 이펙트만 24px 내려가 바닥선 아래로 깔린다(잔영호법 731→755).
⚠️**중심 기준으로 24px 흡수하면 2차 회귀** — 원본은 확대 시 오버행(25)만큼 바닥선도
내려 centery가 701로 고정되지만 Godot은 하단만 재앵커한다(주니어 1.5배 -14px).
**패들 하단 기준으로 앵커**하고(`player_pos.y + size.y − 19`) 씰에 확대 패들 레그를
넣어라. Full rule: `docs/godot_runtime_traps.md`.

## GRT-053 — Godot 포팅 파리티 판정 트랩 (수식이 같아도 "그 경로에서 호출되는가"가 다르다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-053)

- 증상: 공식이 같아도 trigger/call site가 다르면 원본에 없던 경로가 활성화되어 parity가 깨진다.
- 필수: 원본 호출부 전체, 정수화 시점, payload 총량과 render cap을 함께 대조한다.
- 금지: 항등원 상수를 결함으로 복원하기 전에 recorded design decision을 확인한다.
- 검증: 미발동 경로와 실제 buff/active 경로를 분리하고 최종 렌더 수량까지 단언한다.

## GRT-054 — Godot 룰 상수 파생-임계값 리터럴 트랩 (승리 점수를 올리면 보상이 조용히 전멸한다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-054)

- 증상: 승리점수 파생 임계가 literal이면 룰 변경 뒤 정상 승리·보상 판정이 조용히 전부 뒤집힌다.
- 필수: 파생값은 canonical score constants/static resolver를 쓰고 독립 튜닝 임계는 이유와 비율을 명시한다.
- 감사: source-text assertion, fallback renderer, debug cheat, 죽은 duplicate constant까지 검색한다.
- 검증: fixture 한 개 이상은 현재 룰 상수로 전 구간 불변식을 만들고 batch 필수 종단선도 확인한다.

## GRT-055 — Godot `draw_line`에는 라인 캡이 없다 — pygame `draw.ellipse` 실루엣 포팅 트랩

[Full ledger](../../docs/godot_runtime_traps.md#grt-055)

- 증상: Godot line은 항상 butt cap이며 pygame ellipse 실루엣과 source-over alpha도 동일하지 않다.
- 필수: round body는 cached filled-ellipse polygon으로 만들고 원본이 계산만 한 필드는 렌더하지 않는다.
- 필수: 겹친 alpha band는 필요하면 단일 pre-baked texture로 고정한다.
- 검증: 원본 literal 기반 layer contract, alpha profile, cache 소비, pixel capture를 함께 확인한다.

## GRT-056 — Godot 바닥밀착 패들 지면 VFX 트랩 (회전한 쿼드는 클램프를 뚫는다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-056)

- 증상: floor에 붙은 paddle 아래 VFX와 rotated quad는 axis-aligned clamp를 뚫고 화면 밖으로 샌다.
- 필수: rotated AABB 높이로 중심을 올리고 ground sigil은 geometry가 아니라 UV를 회전한다.
- 금지: immediate `_draw()`의 `canvas.material` swap을 blend 전환으로 믿지 말고 별도 CanvasItem을 쓴다.
- 검증: 최하단 lit=0, 재질별 색 픽셀, ADD/MIX 실제 차이를 비헤드리스 capture로 단언한다.

## GRT-057 — Godot 페인티드 크롬 뒤 평면 헤일로 rect 트랩 (그림틀 투명 여백이 상자를 드러낸다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-057)

- 증상: 투명 여백의 painted 9-patch 뒤 flat glow rect가 하드엣지 상자로 노출된다.
- 필수: flat halo는 texture 없는 fallback 안으로 옮기고 상태는 texture silhouette 내부 효과로 표현한다.
- 감사: 같은 chrome을 그리는 sibling callsite를 전수 조사한다.
- 검증: 비헤드리스 capture에서 frame margin과 바깥 대조 픽셀의 delta를 단언한다.

## GRT-058 — Godot 물리차단 모달 개폐 계약 트랩 (새 진입점은 형제 모달의 훅을 상속하지 않는다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-058)

- 증상: modal flag OR만으로는 cooldown·발동창·입력창·resume-safety 부수효과가 상속되지 않는다.
- 필수: 실제 open/close 진입점에서 cooldown과 runtime-window 시간을 중앙 pause/resume fanout으로 처리한다.
- 필수: resume 시 ball freeze·실점차단을 적용하고 dynamic-call 인자수와 registry dependency를 대조한다.
- 금지: 길이를 늘리지 말고 timestamp/anchor만 이동하며 command-buffer 이동 여부는 기록된 결정을 따른다.
- 검증: leaf 직접호출이 아니라 실 진입점과 실 registry 경로에서 안전장치 결과를 단언한다.

## GRT-059 — Godot 스프라이트 셀 여백 × 패들 배율 트랩 (캐릭터가 벽에 못 닿는다)

[Full ledger](../../docs/godot_runtime_traps.md#grt-059)

- 증상: cell의 투명 여백도 paddle scale과 함께 커져 캐릭터만 벽에서 멀어져 보인다.
- 필수: physics/hitbox는 유지하고 alpha>0 실측 anchor 기반 visual wall slide만 적용한다.
- 필수: per-frame anchor는 이동량≤6px sheet에만 쓰고 missing entry와 유효한 zero inset을 구분한다.
- 필수: 회전은 AABB로 clamp하고 sample time을 frame당 고정하며 새 sheet마다 표를 재생성한다.
- 검증: 최종 draw rect·독립 픽셀 재측정·명시적 SKIPPED allowlist를 함께 봉인한다.

## GRT-060 — Godot 보스 스킬카드 0-초기화 즉시-ready 트랩

[Full ledger](../../docs/godot_runtime_traps.md#grt-060)

- 증상: reset cooldown 0은 `progress = 1 - remaining/total`을 첫 프레임부터 1로 고정한다.
- 필수: 스킬별 양수 initial 상수, 양수 total, 명시적 cooldown contract를 함께 게시한다.
- 필수: 감소 owner는 정확히 하나이고, 성공한 시전은 양수 cooldown을 다시 적재해야 한다.
- 필수: 전 보스 카드가 공용 `instant`/`on_boss_hit` 표시 metadata를 선언하고 실동작 owner와 일치해야 한다. 발동 분기를 metadata로 옮기지 않는다.
- 표시: `on_boss_hit` 카드만 열린 황동·먹 타격 표식을 쓰고 `instant` 카드는 무표식으로 둔다.
- 예외: 즉시 ready 디자인은 `initial_ready_allowed=true`로 선언하고 문서와 전수 씰에 등재한다.
- 검증: 1~8층 런타임 HUD producer 자동 발견으로 전 보스·전 스킬 reset/진행/시전/재충전, 선언 존재·실동작 일치, 0-초기화 및 자동발동 차단 RED 픽스처를 봉인한다.
