# V3-4 슬라이스 v2 — 강화칩 + 링코어 퍽 획득 + 표시 슬롯 (TAB/캐릭선택) + 링펫 게이트

> 단일 소스 `docs/lingpet_affinity_system_plan.md` §13-4. 배선은 사용자, Claude는 디자인+적대 리뷰.
> 줄번호는 정찰(wu276d35a/wh2fks16v) 시점, 드리프트 가능 — 심볼명 우선. v2 = 사용자 지시 4건 +
> 포크 3건 반영(2026-06-15).

## §0. 확정 결정 (재론 금지)

| # | 항목 | 결정 |
|---|---|---|
| 1 | 강화칩 획득 | 기존 플레이어 퍽 풀에 칩 카드 주입 (트레이드오프=퍽슬롯 포기) |
| 2 | 칩 게이팅 | **링펫 보유 후에만** 등장 (지시 #3) |
| 3 | 칩 카운트 저장 | **LingpetAffinityState** (income·reset 경계 동일, 단일 카운터) |
| 4 | 링코어 퍽 획득 | **퍽으로도** 다음 티어 획득 (지시 #1). **정식 동등 경로**(퍽슬롯=비용, 매 런 재오퍼, 제니스 소진, 골드샵 공존) |
| 5 | 링펫 게이트 | 링코어/칩/먹이 퍽·아이템은 **`owner.lingpet_owned_pet_ids` non-empty** 후에만 (지시 #3) |
| 6 | 캐릭선택 표시 | **링코어 티어 슬롯만**(계정 store 읽기). **칩 5칸은 인배틀 TAB 전용**(런스코프라 메뉴서 항상 0/5) (지시 #4 + 포크 B) |
| 7 | 아트 | **6 링코어 1패밀리 아이콘**(퍽카드·캐릭선택·TAB 3곳 공유) + **칩 1개** = 7개 (포크 C) |

**6 서브슬라이스**: A(칩 메커닉)·B(링코어 퍽)·C(링코어 표시 TAB+캐릭선택)·D(칩 5칸 TAB)·G(링펫 게이트 키스톤)·F(먹이 게이트 훅, V3-5 연계). + 아트 7종.

## §1. 게이트 키스톤 (§G — 공유 인프라, 먼저 깔아야 함)

지시 #3의 "링펫 보유 후" 게이트는 링코어 퍽·칩 퍽·먹이 전부의 전제.
- **predicate**: `LingpetCollectionState.get_owned_pet_ids_from_owner(owner)` non-empty (== 링펫 1+ 획득).
  `lingpet_egg_runtime._is_tutorial_first_lingpet_egg`(~970-976)가 이미 이 owned-empty 체크 사용 — **동일 predicate 재사용**, 공용 헬퍼로 추출.
- **get_choices 시그니처 변경**: `runtime_perk_catalog.get_choices(character_type, runtime_levels, exclude_instant, count)`에 **owner(+registry) 추가**. 호출처 2곳:
  - 런 모달 `runtime_perk_state.open_next_choice`(~220) — owner/registry 이미 스코프(mythic용 registry 이미 사용).
  - 플라자 아카데미 `plaza_academy_transactions._get_lesson_choices`(~104) — **동일 게이트 적용**(아카데미도 링펫 전 링코어/칩 레슨 노출 금지).
  - ⚠ smoke stub 동반: stage_clear_result_screen_smoke / runtime_perk_active_unlock_flight_smoke / runtime_perk_skill_cooldown_pause_smoke / commando_perk_catalog_smoke 등 get_choices 호출 stub 갱신.
- owned-empty면 링코어/칩/(미래)먹이 카드를 **shuffle/truncate 전에 suppress**.

## §2. §A — 강화칩 메커닉 (런타임)

### 2.1 저장 (LingpetAffinityState, 결정 3)
- `var _enhancement_chips: int = 0` + `set/add_enhancement_chip()`(clamp 0..5) / `get_enhancement_chips()` /
  `get_enhancement_chip_multiplier()` → `1.0 + 0.20 * clampi(_enhancement_chips, 0, 5)`.
- `reset_all()`(~137)에 `_enhancement_chips = 0`. `reset_for_new_battle` 금지(런 내 생존). store/snapshot 미영속.

### 2.2 수입 주입 (단일 chokepoint, §12-6 #1)
- `add_points()` ~388 `granted_points` 직후 `*= get_enhancement_chip_multiplier()`. float 유지(반올림 금지),
  bonus 자동 포함, 만렙 0-리턴이 위라 자동 안전.
- **미래 먹이(V3-5) 면제**: 칩 곱은 GAIN_TABLE 소스 한정. 먹이 소스 추가 시 그 소스만 면제.

### 2.3 칩 퍽 카드 (결정 1·3 정합 — **특수 카드**)
- ⚠ 결정 3이 카운트를 affinity_state에 두므로, 칩 카드는 일반 레벨 퍽이 아니라 **특수 카드**(convert_to_gold 형):
  id `"lingpet_affinity_chip"`, apply_choice 특수 분기 → **신규 public `lingpet_egg_runtime.add_enhancement_chip(owner, registry)`**(commit_unlock_pick 패턴) → affinity_state 증가. **runtime_skill_levels에 별도 tally 금지**(이중 카운터=desync, 결정 3).
- **5-cap 소진 + 링펫 게이트**: get_choices가 affinity_state 칩 카운트를 읽어(owner/registry 스레드, §1) `== 5`면 suppress, owned-empty면 suppress. (레벨 퍽의 자동 max_level 소진을 못 쓰므로 명시 suppress.)
- 카드 표시 "1/5"~"5/5" = affinity_state 칩 카운트 기반. 아이콘 1개(PERK_ICON_PATHS).
- 대안 노트: 더 단순한 "일반 레벨 퍽(runtime_skill_levels, 자동 max5 소진)" + income이 cross-module read도 가능하나, 결정 3(단일 카운터·동일 reset 경계)을 위해 특수 카드 채택. 리뷰서 재론 가능.

### 2.4 §A 스모크
1. `round_commit 5.0 × 5칩 = 10.0`, `× 0칩 = 5.0`. 반증: 배율 빼면 10.0 아님.
2. `reset_for_new_run` 후 칩 0, `reset_for_new_battle` 후 생존.
3. store/snapshot 칩 키 부재(영속 격리, source-scan).
4. 만렙 펫 gain 0(칩 무관).
5. 칩 카드 pick → affinity_state 카운트 +1, 5 클램프, **단일 카운터**(runtime_skill_levels에 tally 없음 source-scan).
6. owned-empty owner엔 칩 카드 후보 부재(게이트), 칩==5면 후보 부재(소진).

## §3. §B — 링코어 퍽 획득 (런타임, 계정 영구)

### 3.1 동적 다음티어 카드 1장 (결정 4)
- id sentinel `"lingpet_ring_core_upgrade"`. 표시 티어/이름/설명 = get_choices 시점에
  `store.get_ring_core_tier()` → `next = current+1`, 이름 `PlazaLingpetStoreTransactions` `RING_CORE_TIER_NAMES[next]`(스탠다드~제니스).
- **suppress**: `current >= MAX_RING_CORE_TIER(6)`(제니스 소진) OR owned-empty(게이트, §1).
- **pick**: apply_choice 특수 분기(convert_to_gold 형) → registry로 affinity_store resolve →
  `upgrade_ring_core_tier(current+1)`. ⚠ **계정 영구 write를 런 퍽이 무료로** — 런 퍽 전례 없음.
  비용 = 퍽슬롯 포기(결정 4). 골드샵 공존: 둘 다 `upgrade_ring_core_tier`(monotonic only-if-higher)라
  **순서 무관·안전**. 매 런 다음 티어 재오퍼.
- runtime_skill_levels 엔트리 없음(레벨 퍽 아님). ⚠ `debug_set_perk_level`/`get_perk_data`가 이 비레벨 id를 인식하게(아니면 all_data lookup 실패).

### 3.2 6 티어 아이콘 (포크 C — 공유 패밀리)
- `runtime_perk_icon_renderer.PERK_ICON_PATHS`(flat id→path)에 **티어별 PNG 선택** 필요. 단일 동적 카드라
  draw_icon(single id)가 6 중 1을 못 고름 → **티어-aware 아이콘 resolution**: get_choices가 카드에 `ring_core_tier:next` 필드 부여 + 렌더러가 per-tier 맵(6 entry)으로 next 티어 PNG 선택. `covered_ids()`에 6 id 등록(coverage smoke 봉인).

### 3.3 §B 스모크
1. tier 2 store → 카드 next=3(하이퍼) 표시, pick → store tier 3, 카드 다음 next=4.
2. tier 6 → 카드 suppress. owned-empty → suppress.
3. 골드샵 후 퍽 or 퍽 후 골드샵 = monotonic(하향 없음, 순서 무관).
4. 6 티어 아이콘 PERK_ICON_PATHS + covered_ids 커버(아이콘 coverage smoke).

## §4. §C — 링코어 표시 슬롯 (TAB + 캐릭선택)

### 4.1 캐릭터 선택 화면 (결정 6 — 링코어 슬롯만)
- char-select는 **owner/registry 없는 독립 메뉴 씬**. `lingpet_affinity_store`를 **`_ready`서 독립 인스턴스로
  load()→`get_ring_core_tier()` 1회 캐시**(계정 영구). ⚠ **매 _process queue_redraw → _draw서 ConfigFile 로드 금지**(hot-path lazy-init 트랩).
- 부착 = 우측 INFO 패널 대표스킬 행 아래, `_build_info_panel_layout`서 공간 예약 + `_draw_info_panel`서 draw(50px 박스 미러). 티어 이름(RING_CORE_TIER_NAMES) + 티어 아이콘(공유 6패밀리). **tier 0 = 무코어 빈/잠금 슬롯**(항상 표시, 계정 플래그 불필요).
- ⚠ **칩 5칸 없음**(결정 6): 칩은 런스코프라 메뉴서 0/5 무의미.

### 4.2 인배틀 TAB (링코어 슬롯 + 우측 칩 5칸)
- ring_core tier를 account-store → owner-key 페어(`lingpet_ring_core_tier`/`ringpet_`) DEFAULT_VALUES 선언
  (Owner-Field Schema Trap) → `set_owner_pair_gated`(egg_runtime ~1075-1081 affinity 블록 옆) → snapshot → presenter 전용 링코어 슬롯(공유 6아이콘).
- **칩 5칸은 TAB만**(§D).

## §5. §D — 강화칩 5칸 인디케이터 (TAB 전용)

- TAB 링코어 슬롯 **우측 세로 5칸**(0~5) hand-draw(세로 눈금 위젯 없음 → 신규).
- 데이터: affinity_state 칩 카운트 → owner-key 페어 `lingpet_affinity_chip_count`/`ringpet_`(DEFAULT_VALUES 선언) → `set_owner_pair_gated` → snapshot `affinity_chip_count` → presenter. run-scoped, account 미영속.

## §6. §F — 먹이 게이트 훅 (V3-5 연계, 게이팅만)

- 먹이 액티브 아이템 자체는 **V3-5(미구현)**. 여기선 게이트 스캐폴드만:
  `active_item_field_spawn_pool.build_spawn_candidates(registry, owner)`(owner 이미 받음)에 owner-lingpet skip
  (먹이 후보는 owned non-empty일 때만), `_should_skip_passive_spawn_candidate` 캐릭터-게이트 패턴을 액티브 측에 미러.
- 먹이 아이템 build_feed() + FIELD_SPAWN_ORDER 추가는 V3-5.

## §7. 아트 deliverable — 7 아이콘 (별도 imagegen)

- **6 링코어 1패밀리**(스탠다드/부스트/하이퍼/오버드라이브/얼티밋/제니스) — 퍽카드·캐릭선택 슬롯·TAB 슬롯 **3곳 공유**.
  티어별 위계: 스탠다드(기본)→제니스(최상위) 광휘/복잡도 점증. 링코어 = 플레이어-링펫 연결 영구 파츠.
- **칩 1개** — 강화칩 퍽 아이콘.
- 그리기 = imagegen(절차/SVG 대체 금지). 스킬 라우팅: 퍽/슬롯 아이콘급이면 `item-generation`, 큰 프레임이면 `ui-hud-generation` — 컨셉 확정 시 결정. PNG-first + 무아트 절차 폴백(런타임 선행 가능).

### §7.1 완료된 아이콘 파일 (2026-06-16)

- `res://assets/sprites/perks/lingpet_ring_core_standard_perk_icon.png`
- `res://assets/sprites/perks/lingpet_ring_core_boost_perk_icon.png`
- `res://assets/sprites/perks/lingpet_ring_core_hyper_perk_icon.png`
- `res://assets/sprites/perks/lingpet_ring_core_overdrive_perk_icon.png`
- `res://assets/sprites/perks/lingpet_ring_core_ultimate_perk_icon.png`
- `res://assets/sprites/perks/lingpet_ring_core_zenith_perk_icon.png`
- `res://assets/sprites/perks/lingpet_affinity_chip_perk_icon.png`

위 7개는 승인된 Gemini 컨셉에서 크롭+알파 처리한 투명 PNG이며, Godot importer로 `.png.import` 생성 완료. QA 체크보드는 `tmp/v3_4_ring_core_icons/ring_core_chip_icons_qa.png`(커밋 대상 아님).

## §8. 트랩 브리프 (슬라이스가 봉인)

1. **Owner-Field Schema (×2)**: `ring_core_tier`(§4.2) + `affinity_chip_count`(§5) 페어 DEFAULT_VALUES 선언. 스키마-게이트 owner 스모크.
2. **단일 배율 §12-6 #1**: 칩 곱은 add_points 한 곳, 소스별 재타이핑 금지.
3. **run-reset 경계**: 칩은 `reset_for_new_run`만, `reset_for_new_battle` 금지. 미영속.
4. **이중 카운터 금지(결정 3)**: 칩 단일 소스=affinity_state. 퍽 픽은 egg_runtime public increment, runtime_skill_levels tally 금지.
5. **게이트 단일 predicate(§1)**: owned non-empty 공용 헬퍼. get_choices 2 호출자 + 아카데미 + smoke stub 전수.
6. **계정 영구 write from 런 퍽(§3.1)**: 골드샵과 monotonic 공존(순서 무관). debug_set_perk_level/get_perk_data가 비레벨 id 인식.
7. **티어-aware 아이콘(§3.2)**: 단일 동적 카드라 6 PNG 중 티어별 선택 — get_choices가 tier 필드 + 렌더러 per-tier 맵. covered_ids 봉인.
8. **char-select hot-path(§4.1)**: store load는 `_ready` 1회 캐시, _draw/_process 금지(queue_redraw 매 프레임).
9. **TAB 공간/row-budget**: 링코어 슬롯+5칸 전용 밴드(V3-2c-UI 패턴, row-budget 회피). 즉시모드, 음수-z/draw_set_transform 금지.
10. **아트 PNG-first**: 절차 폴백이 PNG 우회 안 함, 6패밀리 정합.
11. **다국어**: 칩/링코어 퍽 카드명·설명·티어명 노출 한글 전부 language_settings 4언어 + localization_coverage_smoke (exact 키 — loose grep false-positive 금지, [[godot-localization-copy-sync]]).

## §9. 스모크 (서브슬라이스별, 반증 필수)

§A 6(2.4) + §B 4(3.3) + 게이트: owned-empty면 링코어/칩 카드 둘 다 부재·owned 후 등장. + 캐릭선택: 독립 store
인스턴스가 tier 읽고 슬롯에 반영(tier 0 빈슬롯)·_ready 캐시(매프레임 로드 부재 source-scan). + TAB: ring_core_tier/
affinity_chip_count owner 페어 schema-gated 도달(divergent 값). + 다국어 exact 키.

## §10. 시퀀싱 (권장)

- **G(게이트 키스톤) 먼저** — get_choices owner 스레드 + 공용 owned 헬퍼(링코어/칩/먹이 전제).
- **A(칩 메커닉)** — affinity_state 칩 + 수입 배율 + 칩 특수 카드.
- **B(링코어 퍽)** — 동적 카드 + upgrade_ring_core_tier + 6 아이콘(아트 후행 가능, 폴백).
- **C/D(표시)** — TAB 링코어 슬롯+5칸 + 캐릭선택 링코어 슬롯.
- **F(먹이 게이트 훅)** — V3-5 대비 스캐폴드(먹이 아이템은 V3-5).
- **아트 7종** — 병렬 imagegen.
- ⚠ **V3-4 배선 착수 전 V3-2c-UI 먼저 커밋**(affinity_state/egg_runtime 엉킴 방지; 플라자 staged 임시 unstage→커밋→재stage).
- 수치(+20%/×2, 티어 cap)는 플레이스홀더 — V3-6(스테이지+income QA) 재튜닝.
