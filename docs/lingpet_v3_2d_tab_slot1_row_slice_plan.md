# V3-2d — TAB 캐릭터-info 패널 slot-1 스킬 행 draw

친밀도 v3 (§13, `docs/lingpet_affinity_system_plan.md`)의 V3-2d 슬라이스.
**범위 = 2b-iii가 노출하고 2c가 실제로 점유한 slot-1(second active/passive) 스킬을 TAB
캐릭터-info 패널에 행으로 그리는 것.** 순수 reader/draw 작업 — 키는 이미 라이브.

분담: **디자인 노트/신호 계약/트랩/smoke = Claude (이 문서). GDScript 배선 = 사용자.
적대적 리뷰 = Claude.** 코드 자동 작성 금지(`feedback-design-slice-review-division`).

근거: 10-에이전트 워크플로(환각 방지 지침 적용 — 코드 사실만) + Claude 직접 확정,
2026-06-14. 라인 번호는 배선 전 grep 재확인.

확정 결정(사용자): **slot-1 active + passive 행 둘 다 그림** (passive도 점유되므로 일관).

---

## 0. 코드 사실 (직접 확정)

- **slot-1 owner 키는 전부 라이브** — 2b-iii `_sync_second_skill_owner`가 active runtime
  trio(`lingpet_second_skill_id/_name/_cooldown_duration/_max_level/...`)를, V3-2a
  `loadout_state.sync_owner`(243-254)가 static loadout 키(`lingpet_second_active_skill_level`,
  **`lingpet_second_passive_skill_id`/`_level`**)를 write. 전부 DEFAULT_VALUES 선언됨(248-271).
- **워크플로 "slot-1 passive dead UI"는 오판** — `_sync_second_passive_owner`(runtime trio)는
  없지만 passive는 cooldown/windup이 없어 불필요. `lingpet_second_passive_skill_id`/`_level`이
  loadout_state로 write되므로 **static id/level + catalog로 행을 그릴 수 있음**. V3-2c reconcile가
  second_passive(Lv.25) 점유 시 표시됨.
- **slot-1 level Lv.1 fallback 트랩 해소** — `lingpet_second_active_skill_level`도 loadout_state가
  write하므로 실제 레벨 표시.
- **패널 snapshot builder는 `_current_profile` 접근 없음** (`build_panel_snapshot(owner,
  safe_owner_get, hatch_required_hits)`, gd:35) → 게이트는 owner-key 읽기여야 함(프로파일 읽기 불가).
- **slot-0 description/card/icon은 owner 키 없음** — catalog(`LingpetCatalog.get_active_skill`)에서.
  slot-1도 동일하게 catalog에서 가져와야(owner 키 없음).
- **cooldown_duration / winding_up 비대칭은 정리 불필요로 확정** — 패널은 cooldown_duration을
  label(`format_seconds_text`)로만 쓰고 denominator로 안 씀(div-by-zero 없음), windup은 아예 안 읽음.
  slot-1 cooldown_duration 0.0 기본을 40.0으로 올릴 필요 없음(id-gated라 표시될 땐 live 값). 단
  미래 rail-card slot-1 progress bar는 `maxf(1.0, duration)` 가드 필요(rail은 이미 그럼).

---

## 1. 핵심 작업

### 1.1 snapshot_builder (`character_info_overlay_lingpet_snapshot_builder.gd`, build_panel_snapshot ~114)
slot-0 active/passive 읽기 패턴(65-120)을 slot-1로 미러:
- **active 게이트 = raw owner read** `lingpet_second_skill_id`(ringpet_ fallback, **catalog fallback 없이**).
  catalog fallback이면 locked 시 non-empty가 되어 행이 안 숨음(HIGH 트랩).
- active runtime 값: name/cooldown_duration/max_level은 owner `lingpet_second_skill_*`(ringpet_ fallback)
  → catalog fallback. level = owner `lingpet_second_active_skill_level`(loadout 키, slot-0이
  `lingpet_active_skill_level` 읽는 것 미러). description/card/icon = catalog만.
- **passive 게이트 = raw owner read** `lingpet_second_passive_skill_id`(ringpet_ fallback).
  level = `lingpet_second_passive_skill_level`. name/description/icon = catalog.
- snapshot 키: `companion_skill_id_1`/`_name_1`/`_description_1`/`_card_path_1`/`_icon_path_1`/
  `_cooldown_duration_1`/`_level_1`/`_max_level_1` + passive `companion_passive_skill_*_1`.

### 1.2 presenter `get_skill_specs` (~464) — icon (vertical budget 없음)
- slot-0 active append 블록 뒤에 slot-1 active 블록(badge "A", 게이트 `companion_skill_id_1 != ""`).
- slot-0 passive append 블록 뒤에 slot-1 passive 블록(badge "P", 게이트 `companion_passive_skill_id_1 != ""`).
- 단일 horizontal icon row가 auto-shrink(icon_size clamp 38~58, presenter:207). 2→최대 4 icon. **구조 변경 없음.**

### 1.3 presenter `build_stats` (~551/601) — stat row (+1, budget)
- slot-0 "액티브 쿨타임" insert(3, ...) (601-602) 뒤에 slot-1 cooltime row 추가, 게이트
  `companion_skill_id_1 != ""`, `companion_skill_cooldown_duration_1` + `companion_skill_name_1` 읽음.
- **passive는 cooltime stat 없음**(상시 효과) — icon만. 그래서 **stat budget은 +1(active cooltime)뿐**.
- **row budget 클램프 (1.4) 필수.**

### 1.4 row budget 클램프 (Stats-Panel Row Budget Trap — #1 위험)
- companion 현재 max 6 stat rows(이동/몸집/게이지/방어율or출현율/액티브쿨타임/교감). slot-1 cooltime
  +1 = **7행**. 560x360 stacked(<620px)에서 baseline 340 == threshold 340, strict `>` 라 7행이 정확한
  cliff에서 survive. **더 좁은/짧은 패널이면 silent drop**(`stats_presenter.gd:174` 루프 break).
- **append 전 `lingpet_stat_rows_visible_capacity(stacked_rect, projected_count)` 호출**, 초과 시
  **slot-1 cooltime stat row를 yield**(panel icon이 이미 slot-1 표시 = vertical budget 0). **교감 절대
  drop 금지**(가장 최근 append라 index 7에 걸리기 쉬움). line-174 strict-`>` 우연에 의존 금지.

### 1.5 `get_stats_cache_hash` (~628) — slot-1 키 추가
- 현재 slot-0 필드만 hash. slot-1 `companion_skill_id_1`/`_cooldown_duration_1`(+passive id) 추가.
  안 하면 slot-1 equip/unequip 시 캐시된 stat rows가 stale freeze(MEDIUM).

---

## 2. 신호 계약

| 심볼 | 종류 | 계약 |
|---|---|---|
| `companion_skill_id_1` | snapshot_key (신규) | active 게이트. **raw owner `lingpet_second_skill_id`/`ringpet_` (default ""), catalog fallback 금지.** non-empty일 때만 slot-1 active icon/stat row. 이미 "Lv.22 unlocked AND 점유 AND not module-shared" 인코딩(runtime이 그때만 non-empty write). |
| `companion_skill_name_1`/`_cooldown_duration_1`/`_max_level_1` | snapshot_key (신규) | owner `lingpet_second_skill_*`(ringpet_ fallback) → catalog. _sync_second_skill_owner가 runtime sync. |
| `companion_skill_description_1`/`_card_path_1`/`_icon_path_1` | snapshot_key (신규) | owner 키 없음 → catalog `get_active_skill` 추출만(slot-0과 동일). |
| `companion_skill_level_1` | snapshot_key (신규) | owner `lingpet_second_active_skill_level`(loadout 키, ringpet_ fallback). slot-0이 `lingpet_active_skill_level` 읽는 것 미러. runtime-synced `_second_skill_level` 키는 없음. |
| `companion_passive_skill_id_1`/`_name_1`/`_description_1`/`_icon_path_1`/`_level_1`/`_max_level_1` | snapshot_key (신규) | passive 게이트 = owner `lingpet_second_passive_skill_id`(static, loadout_state write). level = `lingpet_second_passive_skill_level`. name/desc/icon = catalog. **runtime trio 없음(passive 불필요).** |
| `get_skill_specs` (presenter:464) | function (수정) | slot-1 active(badge A)/passive(badge P) spec append, 각 `_1` id 게이트. 최대 4 entry가 단일 horizontal auto-shrink row로. vertical budget 없음. |
| `build_stats` (presenter:551) | function (수정) | slot-1 active 쿨타임 row append, `companion_skill_id_1` 게이트. **append 전 row budget 클램프**(1.4). |
| `get_stats_cache_hash` (presenter:628) | function (수정) | slot-1 id/cooldown_duration(+passive id) hash 추가 → equip/unequip 시 재렌더. |
| `lingpet_stat_rows_visible_capacity` (stats_presenter) | function (불변, 오라클) | draw-time fit 오라클. 클램프·smoke가 이것 호출(rows.size() 아님). |
| `lingpet_second_skill_cooldown_duration` | schema_default (불변) | 0.0 유지(40.0 금지). 패널은 label만, id-gated라 표시 시 live 값. |

---

## 3. 트랩 브리프

각 smoke는 버그 코드에서 FAIL(반증검증, in-place 토글).

### HIGH
1. **row budget cliff** *(certain)*. slot-1 cooltime이 7번째 행 → 560x360에서 정확한 픽셀 cliff, 더
   좁은 패널이면 silent drop(line-174 break). 교감 또는 slot-1 row가 조용히 사라짐(rows.size()는 7,
   state smoke 통과, 픽셀만 손실). **Guard**: `lingpet_stat_rows_visible_capacity` 클램프, slot-1 stat
   yield(교감 보호). **Smoke**: slot-1 equip + stacked rect(`lingpet_stat_rect_for_sections(Rect2(0,0,560,360))`)
   → `visible_capacity >= rows.size()`; 클램프 제거 시 FAIL(in-place 토글).
2. **gate key catalog fallback** *(certain)*. active/passive 게이트를 catalog-fallback 값으로 하면
   locked slot-1도 non-empty → 행이 안 숨음. **Guard**: 게이트는 raw owner read만. **Smoke**: locked 펫
   (second_*_skill_id="") → slot-1 행 미표시(snapshot `companion_skill_id_1`==""), 점유 시 표시.

### MEDIUM
3. **get_stats_cache_hash slot-1 누락** *(certain)*. slot-1 equip/unequip 시 캐시 stat rows stale
   freeze. **Guard**: hash에 slot-1 키. **Smoke**: slot-1 id 변경 → 캐시 무효화 → stat rows 재빌드.
4. **schema-gated owner divergent value** *(likely)*. slot-1 키가 DEFAULT_VALUES 미선언이면 silent
   no-op → catalog base fallback이 가림(이미 선언됨, 회귀 가드). **Smoke**: schema-gated owner(plain
   dict FakeOwner 아님)로 slot-1 cooldown_duration divergent → 패널이 live 값 읽음.

### LOW
5. **cooldown_duration 0.0 vs 40.0** — 패널 label만이라 안전. 미래 rail-card slot-1 progress bar는
   `maxf(1.0, duration)` 가드 필요(rail:178 이미 그럼). V3-2d 패널 경로는 무관.
6. **pair fallback single-key omission** — lingpet_ 읽고 ringpet_ fallback이라, ringpet_ 단일 누락을
   value 테스트가 가림. slot-1 키는 둘 다 선언됨(248-271). 회귀 가드.

---

## 4. 백본 (사용자 배선, 단일 sub-step)

### 2d-1 — slot-1 active+passive 행 draw ✅ 봉인 완료 (2026-06-14)
snapshot_builder slot-1 active/passive 읽기(raw owner 게이트 + catalog fallback) · presenter
get_skill_specs slot-1 icon(A/P) · build_stats slot-1 active cooltime row(+1) + **row budget 클램프** ·
get_stats_cache_hash slot-1 키.
→ **봉인 목표**: slot-1 점유 펫(red_dragon Lv.25 등) TAB 패널에 second active+passive icon + active
쿨타임 stat row 표시, locked/sub-Lv.22 펫은 숨김, row budget 초과 안 함(교감 보호), equip/unequip 시
재렌더. (트랩 1,2,3,4)

**봉인 상태 (적대 리뷰 직접 확인 합격, 모든 축 반증검증):** gate=raw owner read
(`owner_second_active_id := safe_owner_get("lingpet_second_skill_id", ...)`, snapshot_builder:87;
catalog는 `owner_second_active_id != ""` 게이트 뒤 enabled 검증+메타데이터 소스). row budget
클램프 = `_lingpet_row_budget_can_fit`(727-733, `lingpet_stat_rows_visible_capacity` 오라클),
projected=rows.size()+2(slot-1+교감) fit이면 slot-1 insert·아니면 yield, **교감은 항상 append(658)**.
cache hash에 slot-1 키+rect(674-678,711-715). **반증검증 smoke**(character_info_live_stats_smoke
`_verify_second_slot_rows_reach_lingpet_tab` 489-581): occupied red_dragon Lv.25 → companion_skill_id_1
="red_dragon_dragon_wing"(raw owner key)·passive id(loadout sync 경유)·badge A/P; **locked 펫**
(second_skill_id 미set) → `companion_skill_id_1==""` "catalog-falling back 방지"(574, gate 반증검증);
**tight(560x340) cliff** → "2nd" 행 yield+교감 보호+`visible_capacity >= rows.size()`(554-556, 클램프
반증검증); cache rect 참여(562)+lock/unlock hash 차이(578-580).

> **미세 노트 (봉인 blocker 아님)**: ① gate가 `catalog_second_skill_id` 값을 쓰지만
> `owner_second_active_id != ""` 게이트라 동등(574 봉인); occupied 시 catalog가 owner id를 그대로
> 반환하는 계약 의존(V3-2c-2 smoke가 "빈 id→빈" 봉인). ② **active gate=runtime key**
> (`lingpet_second_skill_id`, `_sync_second_skill_owner`의 companion_active 게이트)라 **전투 외
> TAB**에선 slot-1 active가 안 뜰 수 있고 passive는 static(loadout_state)라 뜸 — 비대칭. TAB이
> 전투 중 위주면 무관, 전투 외 도감 표시 원하면 active gate를 static key로 통일 필요.

---

## ✅ V3-2 전체 종료 (2026-06-14): 런타임(2b i/ii/iii) + 점유 reconcile(2c-1/2) + TAB draw(2d-1).
링펫 2번째 액티브/패시브 슬롯이 친밀도 Lv.22/25 unlock → 2-of-1 reconcile 점유 → 런타임 발동 →
TAB 표시까지 전 경로 닫힘. 남은 후속 = V3-2c-UI(player picker, V3-3 persistence 선행)/V3-3(링코어
영구 스토어+광장 골드샵, cap 해금 + persistence).

---

## 5. 미해결 (배선 중 확인, blocker 아님)
- **slot-1 passive name** — runtime owner 키 없으니 catalog `get_passive_skill(pet, second_passive_id,
  level)`에서. owner `lingpet_second_passive_skill_id`/`_level`은 catalog 조회 입력.
- **row budget yield 우선순위** — slot-1 cooltime stat이 첫 yield 대상(icon이 대체 표시). 교감 >
  slot-1 stat 우선순위 명시.
- **rail-card slot-1 카드** — V3-2d 범위 밖(deferred). 패널만.

## 6. 단일 소스 / 링크
- 친밀도 v3: `docs/lingpet_affinity_system_plan.md` §13-9.
- 선행 봉인: V3-2b(`lingpet_second_active_slot_v3_2b_slice_plan.md`) owner 노출 · V3-2c
  (`lingpet_v3_2c_reconcile_hatch_slice_plan.md`) 점유 reconcile.
- 트랩 (CLAUDE.md): Stats-Panel Row Budget Trap · Owner-Field Schema Trap.
