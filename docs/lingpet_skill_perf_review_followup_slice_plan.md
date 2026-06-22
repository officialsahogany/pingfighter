# Lingpet Skill Perf Review — Follow-up Slice Plan

단일 소스. 2026-06-22 적대적 검증(반증 우선)으로 확정한 3건의 후속 작업을
슬라이스로 정리한다. 디자인/신호 계약/봉인 스모크/트랩 브리프는 이 문서가 진실원,
GDScript 배선은 사용자/Codex, Claude는 적대적 리뷰.

원 리뷰 우선순위는 A(HIGH) → B → C 였으나, 검증 후 **재조정**한다:
- A(Bone Barrier 캡)는 **HIGH 아님 → MEDIUM** (21s 쿨다운 + 접촉당 1개 파괴 +
  펫교체 full reset 로 이미 유계). 방어용 캡은 값싼 보험.
- C 의 진짜 라이브 결과는 "빈 아이콘"이 아니라 **per-frame load + dedup 없는
  push_warning 스팸**. 가장 값싸고 일반적이라 **제일 먼저** 친다.

작업 순서(아래 §순서): **C1 → B → A → C2**.

---

## 0. 검증 요약 (file:line 근거)

| # | 주장 | 판정 | 실재? | 심각도(재조정) |
|---|------|------|-------|---------------|
| A | Bone Barrier 누적 상한 없음 + 라운드 보존 | partially_confirmed | 예, 단 유계 | MEDIUM (리뷰 HIGH ✗) |
| B | Milk Shot / Star Coil BattlePerf 라벨 부재 | confirmed | 예 (20개 중 2개만 계측) | MEDIUM~LOW |
| C | Orosha Star Coil 카드/아이콘 PNG 누락 | confirmed | 예 (debug-only) | LOW + net-new 스팸 |

반증으로 **무효화된** 리뷰의 암묵 전제:
- Star Coil 은 투사체/체인이 **없다** (`is_projectile_active()` 항상 false,
  `lingpet_star_coil_skill.gd:181-182`; sparks `SPARK_MAX=42`/trail
  `TRAIL_MAX_POINTS=14` 하드캡, `:29-30`). Bone Barrier 식 증식 위험 없음.
- Milk Shot / Star Coil 투사체는 라운드/배틀/펫교체 **누수 없음**
  (`reset_round` 미구현 → host `_reset_skill_round` 폴백이 `cancel()→reset()`
  로 매 라운드 전부 비움, `lingpet_skill_runtime_host.gd:1055-1060`).
- Star Coil owner-slow 키 2개는 `DEFAULT_VALUES` 에 **선언돼 있음**
  (owner-field schema 트랩 미해당) + self-healing deferred sync 존재.
- Bone Barrier 스파이크 fill 은 3-point 폴리곤 → triangulation 트랩 미해당.

---

## Slice A — Bone Barrier 방어 캡 (oldest-eviction)

### A.1 진단 (확정)
`lingpet_bone_barrier_skill.gd`
- `launch()` 가 캐스트당 1~2개를 **무조건** append (`:106-126`, append at `:124`);
  install 수는 `_get_install_count_for_launch` 가 1 또는 2 (`:545-551`).
- `_barriers` 에 **개수 캡 없음**. `_choose_barrier_x` 의 `MIN_SPACING=110`
  은 배치 재시도일 뿐 캡이 아님 (실패 시 random 폴백, `:477-482`).
- `reset_round()` 는 `_barriers` 를 **의도적으로 보존** (원작 Necro 패리티,
  `:82-90`) — 이 동작은 **유지**한다.
- 유계 장치(리뷰가 놓친 부분): 접촉당 `_break_barrier_at_index` 가
  `_barriers.remove_at(index)` 로 1개 파괴 (`:252-262`), 21s 쿨다운
  (`lingpet_catalog.gd:798`), full `reset()` 가 전체 비움 (`:57-73`).
- 공간 현실: bottom 한 줄(760px, MIN_SPACING 110)에 **약 6~7개**가
  실질 한계(그 이상은 random 폴백으로 겹침).

→ 무제한 폭발 아님. 하지만 "공이 밴드를 거의 안 치는 매우 긴 매치"에서 low-tens
까지 선형 증가 가능. 캡은 그 꼬리를 명시적으로 막는 공짜 보험.

### A.2 백본 (배선 가이드)
`_limit_particles()` 패턴(`:472-475`)을 그대로 미러한다.

```gdscript
# lingpet_bone_barrier_skill.gd
const MAX_ACTIVE_BARRIERS := 8   # ← 디자인 결정, §A.5

# launch() 의 install 루프 직후, `return true` 앞에 1줄:
    _limit_barriers()
    return true

func _limit_barriers() -> void:
    # 방어용 상한. oldest-first 제거(_limit_particles 미러). 방금 설치한
    # 가장 새 장벽은 항상 생존. silent 제거(파편/오디오 없음) — 이건
    # 게임 이벤트가 아니라 안전 바운드이고, 정상 플레이(21s 쿨다운 +
    # 접촉당 파괴)에서는 도달하지 않을 만큼 캡을 높게 잡는다.
    while _barriers.size() > MAX_ACTIVE_BARRIERS:
        _barriers.remove_at(0)
```

루프 안이 아니라 **루프 직후 1회** 호출(2개 동시 설치라도 transient 초과는
한 문장이면 정리). id 기반 충돌조회(`_find_barrier_index`)는 evict된 id에
대해 -1 반환 → `notify_ball_collision` 이 graceful false (`:180-182`). 안전.

### A.3 봉인 스모크 (`lingpet_bone_barrier_skill_smoke.gd` 에 케이스 추가)
- `_verify_barrier_count_is_capped`: level 1(install 항상 1,
  `BONUS_BARRIER_CHANCE_BY_LEVEL[0]=0.0`)로 `MAX_ACTIVE_BARRIERS + 12` 회
  **공 접촉 없이** `launch(Vector2.ZERO, null, {"active_skill_level": 1})` 호출 →
  `get_barrier_count_for_tests() <= MAX_ACTIVE_BARRIERS` 단언.
- **newest 생존** 단언: 마지막 캐스트가 살아있는지 — `get_snapshot()` 의
  `bone_barrier_barrier_positions` 크기 == 캡, 그리고 evict는 oldest부터이므로
  남은 최소 barrier id == `total_cast - MAX + 1` (id 노출이 필요하면 테스트용
  getter 추가는 선택; 최소한 count 캡 + 보존/리셋은 단언).
- **보존 회귀**: 캡까지 채운 뒤 `reset_round()` → count 불변(>0) 단언
  (의도적 라운드 보존이 캡 때문에 깨지지 않음 확인).
- **full reset**: `reset()` → count == 0.

**반증검증(필수)**: `MAX_ACTIVE_BARRIERS` 를 in-place Edit 으로 매우 크게(또는
`_limit_barriers()` 호출을 임시 주석) 한 뒤 위 스모크가 **FAIL**(count = MAX+12)
하는지 확인하고 원복. `git reset/checkout/stash` 금지(WIP 파괴).

### A.4 트랩 브리프
- evict는 반드시 append **이후** front(oldest)부터 — 방금 캐스트가 살아남아야
  한다. append 전 evict하면 새 장벽이 즉시 잘릴 수 있음.
- `reset_round()` 는 건드리지 않는다(라운드 보존은 의도 설계).
- silent 제거가 거슬리면 "evict 시 `_dying_barriers` 로 1프레임 페이드" 변형도
  가능하나 권장 안 함(캡이 충분히 높아 거의 안 터짐 + 복잡도↑). §A.5 결정 사항.

### A.5 디자인 결정 (✅ 확정 2026-06-22)
1. **`MAX_ACTIVE_BARRIERS = 8`** — 확정. (공간 현실 6~7 + 헤드룸.)
2. **evict 스타일 = silent `remove_at(0)`** — 확정 (안전 바운드, 페이드 안 함).

위 백본(§A.2)의 `const MAX_ACTIVE_BARRIERS := 8` 및 silent 제거가 그대로 최종.

---

## Slice B — Milk Shot / Star Coil BattlePerf 라벨

### B.1 진단 (확정)
`lingpet_skill_runtime_host.gd`
- `draw()` 디스패치에서 milk_shot(`:156`)·star_coil(`:171`)은 bare
  `_draw_skill()`(`:1063-1066`, perf_logger 없음) 경유.
- skeleton_archer(`:164`)·bone_barrier(`:165`)만 전용 헬퍼
  (`_draw_skeleton_archer_skill :1068`, `_draw_bone_barrier_skill :1080`)로
  `_perf_begin`/`_perf_end`(라벨 `draw.lingpet.*`) + `record_counter_sample`.
- perf_logger 는 라이브 plumb (`lingpet_egg_runtime.gd:317`). → 갭은 관측 가능.
- Milk Shot 부하: Lv.5 메가 50발(`lingpet_milk_shot_skill.gd:29`,
  하드캡 80 `:276`), 발당 2 line+2 circle(`:409-420`), 파티클
  `PARTICLE_MAX=128`(`:18`) — 전부 미귀속 버킷.

= 20개 스킬 중 **2개만 계측**. gameplay 버그 아닌 **관측성 갭**. 72fps 예산
triage 가 진행 중이라 MEDIUM.

### B.2 백본 (권장: 일반화) — 신호 계약
bespoke 헬퍼 2개 + recorder 2개를 **제네릭 1쌍**으로 접고, milk_shot/star_coil
포함 4개를 통과시킨다(16개 저부하 스킬은 bare `_draw_skill` 유지).

```gdscript
# lingpet_skill_runtime_host.gd
func _draw_skill_instrumented(
    skill: Object, canvas: CanvasItem, shake_offset: Vector2,
    label: String, perf_logger: Object, counter_specs: Array = []
) -> void:
    if skill == null or not skill.has_method("draw"):
        return
    if not _skill_has_visible_effects(skill):
        return                     # 비가시 → draw도 sample도 skip (비용=0)
    _record_draw_counters(skill, perf_logger, counter_specs)
    var s: int = _perf_begin(perf_logger)
    skill.draw(canvas, shake_offset)
    _perf_end(perf_logger, label, s)

func _record_draw_counters(skill: Object, perf_logger: Object, counter_specs: Array) -> void:
    if perf_logger == null or not perf_logger.has_method("record_counter_sample"):
        return
    if counter_specs.is_empty() or skill == null or not skill.has_method("get_snapshot"):
        return
    var raw: Variant = skill.get_snapshot()
    if not (raw is Dictionary):
        return
    var snap: Dictionary = raw as Dictionary
    for spec in counter_specs:      # spec = [counter_name, snapshot_key]
        perf_logger.record_counter_sample(String(spec[0]), float(snap.get(spec[1], 0)))
```

`draw()` 내부 호출(기존 라벨/키는 그대로, 신규 2개 추가):
```gdscript
_draw_skill_instrumented(_skeleton_archer_skill, canvas, shake_offset,
    "draw.lingpet.skeleton_archer", perf_logger, [
        ["lingpet.skeleton_archer.archers",  "skeleton_archer_archer_count"],
        ["lingpet.skeleton_archer.arrows",   "skeleton_archer_arrow_count"],
        ["lingpet.skeleton_archer.dying",    "skeleton_archer_dying_count"],
        ["lingpet.skeleton_archer.particles","skeleton_archer_particle_count"]])
_draw_skill_instrumented(_bone_barrier_skill, canvas, shake_offset,
    "draw.lingpet.bone_barrier", perf_logger, [
        ["lingpet.bone_barrier.barriers",  "bone_barrier_barrier_count"],
        ["lingpet.bone_barrier.dying",     "bone_barrier_dying_count"],
        ["lingpet.bone_barrier.particles", "bone_barrier_particle_count"]])
_draw_skill_instrumented(_milk_shot_skill, canvas, shake_offset,
    "draw.lingpet.milk_shot", perf_logger, [
        ["lingpet.milk_shot.projectiles", "milk_shot_projectile_count"],
        ["lingpet.milk_shot.particles",   "milk_shot_particle_count"]])
_draw_skill_instrumented(_star_coil_skill, canvas, shake_offset,
    "draw.lingpet.star_coil", perf_logger, [
        ["lingpet.star_coil.trail",  "star_coil_trail_count"],
        ["lingpet.star_coil.sparks", "star_coil_spark_count"]])
```
그 후 `_draw_skeleton_archer_skill`/`_draw_bone_barrier_skill`/
`_record_skeleton_archer_draw_counters`/`_record_bone_barrier_draw_counters`
삭제(데드코드 남기지 말 것).

스냅샷 키는 실재 확인됨: milk_shot `milk_shot_projectile_count`(`:153`)
/ `milk_shot_particle_count`(`:164`); star_coil `star_coil_trail_count`
/ `star_coil_spark_count`(`:221-222`).

**최소 diff 대안**(배선 재량): 일반화 없이 기존 2개 bespoke 헬퍼를 복붙해
`_draw_milk_shot_skill`/`_draw_star_coil_skill` 만 추가. 권장은 일반화(데드코드
감소 + 16개도 나중에 싸게 편입 가능).

### B.3 봉인 스모크 (신규 `lingpet_skill_draw_perf_label_smoke.gd`, SceneTree)
- `FakePerfLogger` 더블: `begin_sample()→int`, `finish_sample(label, start)`
  으로 label 수집, `record_counter_sample(name, val)` 로 (name→val) 수집.
- milk_shot 을 가시 활성(투사체 ≥1)으로 만들고 throwaway `Node2D` 캔버스로
  `host.draw(canvas, Vector2.ZERO, fake)` 호출 → `"draw.lingpet.milk_shot"`
  label AND `"lingpet.milk_shot.projectiles"` counter 존재 단언.
- star_coil: `force_phase_for_tests(...)` 로 비-idle 활성화 후 동일 단언
  (`draw.lingpet.star_coil` + `lingpet.star_coil.sparks`).
- 캔버스 패턴은 `lingpet_bone_barrier_visual_render_smoke.gd` 미러.

**반증검증(필수)**: bare `_draw_skill(_milk_shot_skill...)` 상태(현행)에서 위
스모크가 **FAIL**(label 부재)함을 in-place 로 확인 후 원복.

### B.4 트랩 브리프
- `has_visible_effects` 게이트 유지(비가시면 sample도 skip — 0비용 구간에
  빈 sample을 만들지 말 것).
- 16개 bare `_draw_skill` 경로는 이번에 건드리지 않음(저부하, 의도적 무라벨).
  프레이밍은 "2-of-20 갭"으로(이 2개 고유 문제 아님).

---

## Slice C — Orosha Star Coil 누락 자산

### C.1 진단 (확정 + net-new)
- 카탈로그가 `orosha_star_coil_skillcard_imagegen_v1.png` /
  `orosha_star_coil_skill_icon_imagegen_v1.png` 참조
  (`lingpet_catalog.gd:1201-1202`, dup `:1218-1219`). 두 파일 **디스크에 없음**
  (`orosha_star_coil_bind_autosprite_16f.png` 만 존재).
- 스모크는 경로 **문자열 동등성만** 단언(`lingpet_star_coil_skill_smoke.gd:126-127`),
  파일 존재 미검사 (같은 파일 `:109` 는 .gd 에 `FileAccess.file_exists` 사용).
- Orosha 는 `enabled:false`/`debug_enabled:true` 게이트(카탈로그 note) — 일반
  플레이어 미도달.
- **net-new 라이브 결과**: orosha 레일카드가 보이는 매 프레임
  `_draw_gauge → texture() → _load_texture`(`lingpet_rail_card.gd:363,128`)가
  null 을 캐시 안 함(`:139-140` 성공만 캐시) → 매 프레임
  `ProjectResourceLoader.load_texture` 재호출. 그 함수도 음수결과 미캐시
  → 매 프레임 `FileAccess.file_exists` + `_can_load_imported_resource`
  (`.import` stat + 가능시 `ConfigFile.load`) + `ResourceLoader.exists`
  재실행 후 `_push_path_warning(non-empty, path)` → **dedup 없이 매 프레임
  `push_warning`** (`project_resource_loader.gd:103-104, 392-394`;
  rail_card 가 non-empty 템플릿 전달 `:136`). 시각적으론 graceful(폴백 rect,
  crash 없음)이나 QA/플레이테스트 경로에서 syscall + 로그 스팸.

### C.2 백본 — C1 (warning dedup, 지금 친다)
`project_resource_loader.gd` 의 `_push_path_warning` 에 dedup. 일반적·저위험.

```gdscript
static var _warned_paths: Dictionary = {}

static func _push_path_warning(template: String, path: String) -> void:
    if template == "":
        return
    var key := "%s|%s" % [template, path]
    if _warned_paths.has(key):
        return
    _warned_paths[key] = true
    push_warning(template % path)
```
- key 에 template 포함 → missing vs failed 는 따로 dedup(서로 안 가림).
- 경고는 진단용(1회면 충분). 자산이 나중에 생기면 `load_texture` 의 성공캐시
  (`_texture_cache`)가 받아 경고 경로 자체를 안 탐 → 음수캐시 staleness 위험 없음.
- **남는 비용**: per-frame re-stat(FileAccess/ConfigFile)는 그대로. 이는 자산이
  생기면(C2) 사라지므로 debug-only 구간에서 수용. (loader 음수캐시는 "자산이
  나중에 prewarm 으로 등장" staleness 위험이 있어 **권장 안 함**.)

#### C1 봉인 스모크 (`project_resource_loader` 관련 스모크에 케이스 추가)
- 존재하지 않는 경로 + non-empty 템플릿으로 `load_texture` 를 N회 호출하고
  `push_warning` 이 1회만 나가는지 — 직접 카운트가 어려우면 `_warned_paths` 가
  N회 호출 후에도 해당 key 1개만 갖는지 단언(테스트 훅 또는 정적 접근).
- **반증검증**: dedup 제거 상태(in-place)에서 "key 1개" 단언이 의미 없어지는
  것을 확인 — 더 견고하게는 `push_warning` 횟수를 셀 수 있는 경로가 없으면
  `_warned_paths` 멤버십으로 회귀 봉인.

### C.3 백본 — C2 (자산 생성 + 스모크 강화, 스테이지 이후)
1. 스킬 **카드** + **아이콘** 생성: 링펫 스킬 카드/아이콘 컨벤션(Gemini,
   불투명 풀씬; 스킬 아이콘은 불투명 검정-bg 컨벤션 — [[lingpet_solar_bolt_port]]
   / [[lingpet_milk_shot]] 선례). FLUX 금지. 누끼 불필요(불투명).
2. 두 예약 경로(`res://assets/sprites/lingpet/orosha_star_coil_skillcard_imagegen_v1.png`,
   `..._skill_icon_imagegen_v1.png`)에 복사 + import.
3. `lingpet_star_coil_skill_smoke.gd:126-127` 에 **`FileAccess.file_exists`
   단언 추가**(기존 문자열 동등성 단언은 유지 — 둘 다). 자산 삭제/리네임 시
   라우드 FAIL.

**interim 대안**(선택): 자산 전까지 카드/아이콘 경로를 기존 placeholder
(unknown/placeholder 자산)로 지정 → 스팸·re-stat 제거. 단 카탈로그 데이터 +
스모크 문자열 단언을 같이 바꿔야 함. orosha 가 debug-only 라 **권장은 C1만
지금 + C2 는 아트와 함께** 나중에.

### C.4 트랩 브리프
- C2 의 `file_exists` 단언을 **아트보다 먼저** 넣으면 스모크가 즉시 RED
  → pre-push 게이트 깨짐. 반드시 아트 생성과 **같은 슬라이스**로.
- dedup 의 `_warned_paths` 는 프로세스 수명 static — 경고엔 무해. reset 불필요.

---

## 순서 / 분담

| 순서 | 슬라이스 | 비행동? | 디자인 결정 | 비고 |
|------|---------|---------|------------|------|
| 1 | C1 warning dedup | 예 | 없음 | 가장 값싸고 일반적, 지금 |
| 2 | B perf 라벨 | 예 | 없음(일반화 vs 최소diff는 배선 재량) | 72fps 작업 직접 기여 |
| 3 | A bone barrier 캡 | 거의(데이터 캡) | **있음**(캡 값/스타일, §A.5) | 확인 후 |
| 4 | C2 아트 생성 + file_exists 스모크 | 아니오(자산) | 아트 방향 | 스테이지 이후 |

- 배선(GDScript): 사용자/Codex. 리뷰: Claude(적대적).
- 아트(C2): 링펫 스킬 카드/아이콘 컨벤션, Gemini.

## 공통 봉인 규율
- 모든 스모크는 **반증검증** 의무: 수정 전(버그) 코드에서 **in-place Edit
  토글/임시 패치/픽스처**로 FAIL 을 먼저 증명한 뒤 원복. `git
  reset/checkout/stash` 절대 금지(이 리포 WIP 파괴).
- 데드코드(삭제된 bespoke 헬퍼/recorder) 잔존 금지.
- 커밋에 봉인 스모크 **반드시 포함**.

## 랜딩 후 백필 메모 (지금 백필 금지 — 픽스 랜딩 후)
C1 이 랜딩되면 **반복 가능 트랩**(debug-gated 스킬의 예약-but-부재 아트가 레일
카드/아이콘으로 매 프레임 draw-time load → 성공만 캐시하는 loader 에서 per-frame
re-stat + dedup 없는 `push_warning` 스팸)을 한 줄로 백필 후보. 라우팅: `AGENTS.md`
(런타임 리소스-로딩 invariant) 또는 `CLAUDE.md`(Hot-Path Lazy Init / export-audit
인접). A/B 는 특정성 높아 백필 대상 아님(perf 플레이북의 "gap-free 서브라벨"이 이미 커버).
