# V3-2c — 부화-제로 + 2-of-1 unlock choice → 로드아웃 점유 reconcile

친밀도 v3 (§13, `docs/lingpet_affinity_system_plan.md`)의 V3-2c 슬라이스.
**범위 = "두 번째 슬롯이 실제로 돌아갈 수 있는 엔진(V3-2b)" 위에 "그 슬롯에 무엇이
들어가는가"를 채우는 것.** 부화 시 스킬 0 → 친밀도 unlock으로만 획득, unlock choice가
로드아웃 슬롯(slot-0/slot-1)에 reconcile.

분담: **디자인 노트/신호 계약/트랩/smoke = Claude (이 문서). GDScript 배선 = 사용자.
적대적 리뷰 = Claude.** 코드 자동 작성 금지(`feedback-design-slice-review-division`).

근거: 14-에이전트 워크플로(부화/reconcile/unlock-choice/후보풀/choice-surface 매핑 +
5 설계 차원 + 16 트랩) + Claude 직접 코드 확정, 2026-06-14. 라인 번호는 배선 전 grep 재확인.

> ⚠ **워크플로 환각 경고 (적대 검증으로 제거됨):** 워크플로 여러 에이전트가 존재하지
> 않는 "Spec §0 D9"를 지어내며 *"second_active를 loadout에 쓰면 2nd unlock 전 무가드 발동→
> softlock, 절대 안 씀"*이라 주장했다. 이는 **V3-2b 미완 전제의 환각**이다. V3-2b(i/ii/iii)는
> 봉인 완료(충돌 중재 arm-edge 게이트 + would_share_module + draw visual-slot)라 second-slot
> 점유가 **안전**하고, 그게 V3-2c의 목표다. `second_slot_reconcile` 에이전트만 정확히 반박했고
> 그게 옳다. 이 문서는 환각을 제거한 결론만 담는다.

---

## 0. 확정된 게임 설계 결정 (2026-06-14, 사용자)

| 결정 | 선택 | 함의 |
|---|---|---|
| **Second 슬롯 점유** | **포함** | reconcile 4-key 확장 → second_active를 loadout에 write → slot-1 라이브. V3-2b 봉인으로 안전. 안 하면 2b 런타임이 dead code. |
| **후보 풀 부족** | **단일 auto-resolve 임시 수용** | active 1개인 5펫(milkring/nekuring/lunabi/draft_bat/orbi) + 대부분 second 슬롯은 `resolve_single_unlock`(선택 없음). 2nd 스킬 authoring은 나중 슬라이스. |
| **튜토리얼 마리보** | **hatch-zero + Lv.1 headstart starter** | 마리보도 hatch-zero. starter는 affinity Lv.1 headstart unlock으로(단일 경로). build_default 특수케이스 금지. |
| **Player picker UI** | **구현 대상 아님(2026-06-30 superseded)** | V3-2c = reconcile 4-key + hatch-zero + **auto-resolve/run-state 백본**. 과거 비모달 2-of-1 picker 후속안은 `docs/lingpet_v3_2c_ui_picker_slice_plan.md`에 보존 기록만 남김. |

---

## 1. 직접 확정한 코드 사실 (환각 vs 사실 분리)

- **hatch-zero는 이미 동작.** `pick_skill_loadout`(catalog:1163)이 이미 `build_empty_loadout`
  (active_slot_count=0) 반환, `_normalize_loadout` fill_missing(loadout_state:290-294)은
  `active_slot_count > 0`일 때만 default를 채우므로 empty(slot_count=0)는 스킵 →
  306-308에서 `build_empty_loadout` 그대로 반환. **워크플로 A안(allow_empty_loadout threading)은
  불필요.** trap #906("fallback 안 fire")이 맞음. ⇒ V3-2c hatch-zero 잔여 = **검증 smoke + trap #870 가드**.
- **affinity state 레이어는 이미 4-key complete.** `_unlock_choice_key`가 second_active/second_passive
  매핑, `choose_skill_unlock`/`get_resolved_unlock_choices`/`resolve_single_unlock`/
  `_record_pending_unlock_choice` 전부 key-agnostic. ⇒ **affinity_state.gd 변경 불필요**, V3-2c는
  순수 egg_runtime reconcile 확장.
- **reconcile는 현재 4-key 중 2-key(primary)만.** `_seed_unlock_choice_candidates`(1531)/
  `_auto_resolve_primary_unlock_choices`(1554) 루프가 `["active","passive"]` 하드코딩,
  read(1510-1511)도 primary만, write(1522-1523)는 second에 `""` 강제, `_loadout_matches_unlock_reconcile`(1615)는
  line 1634에서 second가 비어야 한다고 **hard-gate**.
- **runtime arm gate는 이미 3-way AND**(`_get_active_slot_count`/`_is_second_active_slot_enabled`):
  `second_active_unlocked`(affinity) AND `get_skill_id(1) != ""`(loadout) AND NOT
  `would_share_module`. 친밀도 플래그는 독립 set되므로, **loadout id를 쓰는 것 자체가 slot-1을
  arm하는 행위** — 별도 deploy 단계 없음.

---

## 2. 핵심 작업 — reconcile 4-key 확장

`_reconcile_unlock_choices`를 active/passive/second_active/second_passive 4-key로:

1. **SEED** — `_seed_unlock_choice_candidates` 루프를 4-key로. second 후보 =
   **first-pool에서 resolved primary id 제외 필터** (플레이어가 이미 가진 slot-0 스킬을
   second로 다시 못 받게), **distinct seed salt**로 slot-0와 다른 2-of-1 draw. 1개면
   `resolve_single_unlock`, ≥2개면 `set_unlock_choice_candidates` (기존 `_seed_unlock_candidates_for_type` 재사용).
2. **AUTO-RESOLVE** — `_auto_resolve_primary_unlock_choices` 루프 `["active","passive","second_active","second_passive"]`.
   **primary를 먼저 resolve**(순서 의존 — second 후보 필터가 resolved primary id를 읽음).
   auto-pick은 candidates[0] 유지(현행 per-run 계약; `_skip_unlock_reconcile` QA 오버라이드 유효; 과거 V3-2c-UI picker안은 superseded).
3. **READ** — `second_active_id := _get_resolved_unlock_id(resolved, "second_active")` + passive 형제.
4. **SUPPRESS (write-time would_share_module)** —
   `write_second_active := second_active_id if (active_id != "" and second_active_id != "" and not would_share_module(active_id, second_active_id)) else ""`.
   억제 시 resolved **choice는 affinity에 남고** loadout slot-1 id만 `""` → `_is_second_active_slot_enabled` false → 슬롯 비활성.
   **passive는 module-sharing 위험 없음**(value-additive)이라 would_share_module 불필요, first-slot 제외만.
   ⚠ **반드시 `would_share_module`(skill_kind), `skills_share_exclusive_resource` 아님** — 후자는
   fire-time 동시성(ball-owner/pos-override)이고 host는 **skill_kind별 모듈 1개 캐시**라
   같은 kind가 stateful 인스턴스 공유 손상(ghost_summon `reset()`). exclusive_resource로 억제하면
   다른 kind 동시 ball-owner(hydro+solar)를 잘못 차단.
5. **WRITE** — `set_pet_loadout(..., write_second_active, write_second_passive, <levels>)`.
   second level은 `current_loadout.second_*_skill_level`(신규는 DEFAULT_SKILL_LEVEL, id ""면 0).
6. **VALIDATION (co-load-bearing)** — `_loadout_matches_unlock_reconcile` 시그니처에
   second_active_id/second_passive_id(**post-suppression write 값**) 추가, **line 1634 hard-gate
   (second must be "")를 primary와 동일한 expected-vs-actual 매칭으로 교체**. 안 하면 second 쓸 때마다
   매칭 실패 → 매 프레임 rewrite → cache invalidation + re-prewarm hitch (trap #996/#1041).

**signal contract:**

| 심볼 | 종류 | 계약 |
|---|---|---|
| `_reconcile_unlock_choices` | method (수정) | 4-key reconcile. primary 먼저 resolve→read→would_share_module 억제→set_pet_loadout(second ids)→loadout 변경 시 true. |
| `_seed_unlock_choice_candidates` | method (수정) | 루프 4-key. second 후보 = first-pool − resolved primary, distinct salt. |
| `_get_second_active_unlock_candidate_ids` | method (신규) | active-pool − resolved primary active, seed-shuffle 2. 형제 `_get_second_passive_*`. |
| `_auto_resolve_primary_unlock_choices` | method (수정) | 루프 4-key, candidates[0] 유지. primary 먼저. |
| `_loadout_matches_unlock_reconcile` | method (수정) | second_active_id/second_passive_id 인자 추가, line 1634 hard-gate → 매칭 교체. **write 변경과 동시 필수.** |
| `would_share_module` | static (기존, write-time 재사용) | `would_share_module(active_id, second_active_id)` true면 second loadout id="" (choice는 유지). passive 미적용. |
| `set_pet_loadout` | consumer (기존, 풀 호출) | 하드코딩 ""/""/0/0 → 실제 second ids/levels. |
| `_is_second_active_slot_enabled` / `_get_active_slot_count` | runtime gate (하류, 불변) | non-empty·non-same-kind second_active_skill_id가 써지는 순간 slot-1 라이브. write-time 억제가 same-kind를 런타임 gate 전에 차단(defense in depth). |
| affinity_state.gd | (불변) | 4-key complete. 변경 없음. |

---

## 3. hatch-zero (거의 done — 검증 + trap #870 가드)

- 코드는 이미 hatch-zero(§1). **A안 threading 불필요.**
- 마리보 starter = Lv.1 affinity headstart unlock(`_apply_affinity_headstart_from_store` 경로, hatch에서 이미 실행).
  build_default 특수케이스 금지(단일 hatch-zero 경로 유지).
- **trap #870 가드**: reconcile/임의 경로가 **빈 primary id로 set_pet_loadout 호출 시**
  fill_missing(slot_count=1 default)이 default 스킬 재주입. 실경로에선 primary가 Lv.1에 먼저
  unlock되니 드물지만, malformed/migrated loadout이 트리거. set_pet_loadout이 빈 primary +
  slot_count≥1을 받을 때 default 재주입 안 되게(빈 primary면 slot_count 0 처리 or 명시 빈).

---

## 4. 트랩 브리프 (유효, 환각 제외)

각 smoke는 버그 코드에서 FAIL해야 함(반증검증, in-place 토글).

### HIGH
1. **second choice never resolved → pending 영구 차단** *(trap #951)*. reconcile가 second를
   seed/resolve 안 하면 pending 엔트리가 같은 key의 future unlock을 영영 막음. **Guard**: 4-key
   auto-resolve. **Smoke**: second_active_unlocked 플래그가 true가 된 뒤 pending이 resolve되고 loadout slot-1에 반영.
2. **빈 primary write → fill_missing default 재주입** *(trap #870/#915)*. set_pet_loadout이
   active_id="" + slot_count≥1 받으면 `_normalize_loadout` fill_missing이 default 재주입.
   `_slot_count_for_pair('','')==0`가 load-bearing 가드. **Guard**: 빈 primary write 시 slot_count 0.
   **Smoke**: 빈 primary로 set_pet_loadout → active_skill_ids 빈 채 유지(default 재주입 안 됨).
3. **_loadout_matches hard-gate thrash** *(trap #996/#1041)*. line 1634가 second 비어야 한다고
   하드게이트 → second 쓰면 매 프레임 rewrite. **Guard**: 매칭 교체(§2.6). **Smoke**: second 쓴 뒤
   reconcile가 다음 프레임 false 반환(수렴), 매 프레임 set_pet_loadout 안 함.

### MEDIUM
4. **same skill primary+second** *(trap #978)*. 후보 생성에 first-slot 제외 없으면 같은 스킬을
   primary와 second 둘 다. **Guard**: second 후보 = first-pool − resolved primary. **Smoke**:
   resolved primary가 second 후보에서 제외.
5. **resolve_single_unlock double-count** *(trap #888)*. resolve가 reward_counts를 2번 bump.
   **Guard/Smoke**: 단일 후보 resolve 후 reward_counts 정확(중복 카운트 없음).
6. **placeholder candidate 잔존** *(trap #987)*. seeding 순서 역전 시 placeholder가 살아남아
   존재하지 않는 스킬 lock. **Guard**: primary 먼저 seed/resolve 순서 고정. **Smoke**: 순서 의존성 단언.

### LOW / latent (과거 V3-2c-UI 전제는 superseded, V3-3 persistence 전제만 유효)
7. **player pick persist 안 됨** *(trap #1005)*. resolved choice가 in-memory만(affinity_store는
   best_level+bond만). auto-resolve/run-state는 매 부팅 candidates[0] 재유도라 무관. 과거 player
   picker를 재개해 non-default pick을 허용할 때만 reload에서 candidates[0] divergence가 유효하므로
   V3-3 persistence를 선행.
8. **second_active_unlocked가 ring-core cap downgrade 후 survive** *(trap #1014)*. reward_counts
   append-only, never cleared. cap 하향 기능 생기면 slot-1이 cap 아래에서도 라이브. 지금 downgrade trigger 없음(latent).
9. **auto-resolve가 picker와 double-resolve** *(trap #969, 과거 picker안 전용)*. auto-resolve가 매
   reconcile unconditional → picker modal 열린 동안 가로챔. 현행 picker 없음. picker를 명시 재개하면
   auto를 failsafe로 게이트(modal 후/N pass).
10. **catalog에서 제거된 resolved id** *(trap #1023)*. 세션 간 카탈로그 변경 시 resolved id가 ""로
    drop, 슬롯 빈 채. 개발 중 흔함. **Smoke**: 존재하지 않는 resolved id graceful drop.
11. **FakeOwner plain dict가 owner schema 트랩 가림** *(trap #933)*. picker를 재개해 chosen skill을
    owner sync 시작하면 schema-gated owner 필요. 지금 hatch-zero 빈 상태는 무관(latent, picker 시).

---

## 5. 백본 (사용자 배선 순서)

각 단계 smoke 봉인. 단계 끝 `run_smoke_tests` + `run_warning_scan` + `run_headless_load_check`.

### 2c-1 — reconcile 4-key (second 점유) ✅ 봉인 완료 (2026-06-14)
`_seed_unlock_choice_candidates`/`_auto_resolve_primary_unlock_choices` 4-key · 
`_get_second_active_unlock_candidate_ids`(first-pool − primary) · read second ids · 
write-time `would_share_module` 억제 · `_loadout_matches_unlock_reconcile` 매칭 교체 · 
set_pet_loadout second ids.
→ **봉인 목표**: second_active_unlocked true → second_active resolve → loadout slot-1 write → `_is_second_active_slot_enabled`
true → slot-1 발동. same-kind면 억제(slot-1 비활성). reconcile 수렴(thrash 없음). (트랩 1,3,4,5,6)

**봉인 상태 (적대 리뷰 직접 확인 합격):** reconcile 4-key 구조 정확 — primary 먼저 resolve
(`_auto_resolve(["active","passive"])`) → second 후보가 resolved primary 제외(`ids.erase`,
distinct salt 17/31/43) → would_share_module 억제(1663-1665, same-kind 다른 id→"") →
`_loadout_matches` line 1634 hard-gate 제거 + expected-size/정확일치 매칭(thrash 방지) →
set_pet_loadout second ids. single-active 5펫은 second pool 빈→slot-1 빈. **반증검증 smoke**:
`_verify_second_unlock_flags_fill_slot_one`이 explicit second unlock flags fixture→`_get_active_slot_count()==2`·
`_get_skill_id_for_slot(1)==second_active_id`(slot-1 실제 발동)·second≠primary, same-kind suppress
(second=""), second-passive write, settled reconcile false(thrash 없음).
**부수 재판단 — reconcile-skip을 2b-iii one-shot → sticky로 되돌림(의도 확정):** line 462
`_skip_unlock_reconcile=false` 제거→sticky 주석. reconcile 4-key가 활발해져 F7/debug 강제
loadout이 친밀도 reconcile(candidates[0])에 덮이는 것 방지. `_skip_unlock_reconcile` 유일 true
경로 = debug_grant active/passive id 지정(460), 실플레이 부화는 빈 id→false→reconcile 정상(second
포함), pet-change clear. 실플레이 회귀 없음. smoke `_verify_debug_forced_skill_reconcile_stays_sticky`
+ `_verify_..._skip_is_sticky_until_pet_change`로 봉인.

### 2c-2 — hatch-zero 검증 + trap #870 가드 ✅ 봉인 완료 (2026-06-14)
hatch-zero는 이미 동작 → **검증 smoke**(fresh hatch = 빈 active_skill_ids/passive_skill_ids,
저장된 pre-V3-2c loadout은 스킬 유지) + **빈 primary write 가드**(set_pet_loadout active_id="" →
fill_missing default 재주입 안 됨) + 마리보 Lv.1 headstart starter 경로.
→ **봉인 목표**: 부화 직후 펫 스킬 0, unlock 시 reconcile가 채움, 빈 primary가 default로 안 덮임. (트랩 2)

**봉인 상태 (적대 리뷰 직접 확인 합격, smoke만 +96 보강):** 런타임 코드는 이미 계약 충족.
**trap #870 가드 고리 확정** — `set_pet_loadout`이 `active_slot_count: _slot_count_for_pair(id, second)`
(loadout_state:137/143)로 명시, `_slot_count_for_pair("","")==0`(394-399)이라 빈 primary면 slot_count 0
→ `_normalize` fill_missing(`active_slot_count > 0`만 채움) 스킵 → default 재주입 0. 가드 제거(slot_count
1) 시 fill_missing 재주입→FAIL=반증검증. **fresh hatch smoke는 진짜 ball-hit 부화 경로**(`_register_hit`
egg spawn→충돌→hatch)로 0슬롯 검증(debug_grant 우회 아님, 워크플로 trap #924 해소). 4 smoke:
`_verify_fresh_hatch_keeps_zero_skill_loadout`·`_verify_empty_primary_set_does_not_reinject_defaults`·
`_verify_legacy_one_slot_loadout_survives_v3_2c_normalization`·`_verify_maribo_headstart_rederives_starter_unlock`.

---

## ✅ V3-2c 전체 종료 (2026-06-14): 2c-1(reconcile 4-key 점유) + 2c-2(hatch-zero). slot-1이
실제로 점유·발동하고, 부화는 스킬 0에서 unlock reconcile로 채워짐. V3-2d(TAB slot-1 행 draw)는
완료. V3-2c-UI(player 2-of-1 picker)는 2026-06-30 per-run 개정으로 폐기된 보존 문서이며,
현재 남은 축은 V3-3(링코어 영구 스토어+광장 골드샵)이다.

---

## 6. 미해결 (배선 중 확인, blocker 아님)
- **would_share_module 억제 시 UX**: same-kind second 억제는 **silent**(V3-2c 단순, 권장). picker를
  별도로 재개해 candidate 생성이 kind-exclude하면 would_share_module은 순수 defense-in-depth.
  지금은 single-active-kind 펫/migrated loadout에서만 도달.
- **second_passive first-slot 제외** = yes (중복 passive 무의미, module 위험 없음).
- **run-boundary persistence**(trap #1005·#7)는 picker를 재개할 때 V3-3 선행 처리. 현행 V3-2c
  auto-resolve/run-state는 무관.

## 7. 단일 소스 / 링크
- 친밀도 v3: `docs/lingpet_affinity_system_plan.md` §13-9 (V3-2 sub-slice).
- 선행 봉인: `docs/lingpet_second_active_slot_v3_2b_slice_plan.md` (V3-2b 런타임 i/ii/iii).
- 트랩 (CLAUDE.md): Lazy Applied-Key Re-Apply / Hot-Path Lazy Init / Owner-Field Schema / would_share_module.
