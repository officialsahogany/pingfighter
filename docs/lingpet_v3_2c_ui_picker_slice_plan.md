# V3-2c-UI 슬라이스 — 비모달 TAB 2-of-1 unlock picker

> 단일 소스는 `docs/lingpet_affinity_system_plan.md` (§13). 이 문서는 V3-2c-UI
> 슬라이스의 시그널 계약 + 백본 + 트랩 브리프 + 스모크다. 배선(GDScript)은 사용자가
> 직접, Claude는 적대적 리뷰. 줄번호는 현재 트리(HEAD=08ef4095d 직후) 기준이며 드리프트
> 가능 — 심볼명을 우선 신뢰.

## §0. 확정 결정 (재론 금지)

| 항목 | 결정 | 근거 |
|---|---|---|
| Surface | **비모달 TAB 패널 픽** | 문서 "비모달 rail/TAB" 의도. 사용자 확정 2026-06-15 |
| 재선택 | **1회 확정(잠금)** | 명시 픽은 영구. store 존재 = 잠금 |
| auto-resolve | **비영속 failsafe 유지** | V3-3b: auto는 store 미기록 → 명시 픽 전까지 매 매치 재제안 |
| 전투 정지 | **TAB가 이미 정지 (무료 상속)** | `is_character_info_active` 모달게이트 + 쿨타임 일시정지 |
| 데이터 경로 | **frame-level 라이브 read, owner 미경유** | frame_presenter가 이미 registry+runtime 보유 |

## §1. 시그널 계약 (surface 무관, 확정)

### 1.1 열거 (후보 그리기)
- 키 4종 `active`/`passive`/`second_active`/`second_passive`. **2+ 후보일 때만 선택 존재**
  (단일 후보 = `resolve_single_unlock`, 선택 없음).
- 후보 id → 표시:
  - active 계열 = `LingpetCatalog.get_active_skill_entry(id)` → `name`/`icon_texture_path`/
    `card_texture_path`/`description`.
  - passive 계열 = `LingpetCatalog.get_passive_skill_entry(id)` + 아이콘은
    `LingpetCatalog.get_passive_icon_path(pet_id, id)` (펫별 오버라이드 존중).
  - 헤더 라벨 = `LingpetAffinityState.LABEL_BY_REWARD_TYPE[reward_type]`.

### 1.2 커밋 (3-스텝, 순서 고정)
1. `affinity_state.choose_skill_unlock(pet_id, reward_type, selected_id)` —
   ⚠ 2번째 인자는 `choice["type"]`(reward_type, 예 `"active_unlock"`), **choice_key 아님**.
2. `store.set_resolved_unlock_choice(pet_id, choice_key, selected_id)` — ⚠ 이쪽은 **choice_key**.
   내부 `save()`로 영속.
3. 라이브 재적용 — `_invalidate_current_loadout_cache()` + `_apply_current_loadout(owner, true, false, registry)`.

> **두 키 컨벤션 footgun**: choose=reward_type, store=choice_key. pending/option 엔트리가 둘 다
> (`type`/`choice_key`) 들고 있으니 거기서 뽑아 쓸 것. reward_type↔choice_key 역변환은
> `_unlock_choice_key_for_reward_type` (egg_runtime ~1752).

## §2. 하중 트랩 — Lazy Applied-Key Re-Apply (TRAP2)

`set_resolved_unlock_choice`는 **로드아웃 캐시를 무효화하지 않는다.** `_apply_current_loadout`은
`_applied_loadout_key != ""`이면 **재계산 전에 early-return**(~1510). 즉 **store write 단독 =
라이브 전투 silent no-op** (펫은 계속 candidates[0]). 추가로 `_skip_unlock_reconcile`이 true면
reconcile 자체 skip(~1508).

→ picker는 store write 후 반드시 `_skip_unlock_reconcile==false` 보장 → invalidate(~1805) →
`_apply_current_loadout(...,registry)`. **registry 필수** (없으면 reconcile이 store를 못 봄).
이를 §3의 public `commit_unlock_pick`이 원자적으로 캡슐화한다(`debug_grant_and_activate_pet`이
invalidate→apply를 감싸는 선례 그대로).

## §3. 백본 — 신규 public API (egg_runtime 2개) + 보조 배선

후보 도출 4헬퍼(`_get_active_unlock_candidate_ids` ~1657 / `_get_first_passive_unlock_candidate_ids`
~1663 / `_get_second_active_unlock_candidate_ids` ~1670 / `_get_second_passive_unlock_candidate_ids`
~1680)와 reconcile/auto는 전부 private. UI가 닿을 public 2개를 추가한다.

### 3.1 READ — `get_unlock_choice_options(pet_id := "", registry := null) -> Array`
각 엔트리:
```
{
  "choice_key": "active"|"passive"|"second_active"|"second_passive",
  "reward_type": String,        # choose_skill_unlock에 넘길 값
  "candidates": Array[String],  # 결정적, candidates[0] == auto 기본값
  "selected": String,           # locked면 store값, 아니면 candidates[0]
  "locked": bool,               # store에 이 choice_key 존재 == 명시 픽 완료
}
```
- 포함 조건: 해당 reward가 **unlocked** (cumulative `*_unlocked` 플래그) **AND 후보 ≥2**.
  (단일 후보 키는 선택이 없으므로 제외.)
- `locked` = `_get_affinity_store(registry).get_resolved_unlock_choices(pet_id)`(flat dict)에
  choice_key 존재. (STORE가 잠금 권위 — STATE 아님. §4.2.)
- 후보 순서는 반드시 위 private 헬퍼에서 — 시드 셔플(salt 17/31/43)이 candidates[0]=auto 기본값을
  만든다. 순서 바꾸면 "현재 보이는 기본값"과 어긋남.

### 3.2 WRITE — `commit_unlock_pick(pet_id, choice_key, candidate_id, owner := null, registry := null) -> bool`
내부 순서:
1. `candidate_id`가 choice_key의 라이브 후보 풀에 있는지 검증(`_choice_candidates_include` ~1647 재사용). 아니면 false.
2. **이미 잠김이면 false** — `store.get_resolved_unlock_choices(pet_id)`에 choice_key 존재 시 거부(1회 확정).
3. `store.set_resolved_unlock_choice(pet_id, choice_key, candidate_id)` — **유일한 프로덕션 잠금 write.**
4. `_invalidate_current_loadout_cache()` (~1805) + `_apply_current_loadout(owner, true, false, registry)`.
   → reconcile → `_apply_persisted_unlock_choices`가 방금 쓴 store를 읽어 적용(persisted>auto) +
   `_affinity_state.choose_skill_unlock` 내부 호출로 state까지 즉시 일관. **별도 step으로 choose를 또
   부를 필요 없음** (V3-3b 경로가 이미 state+loadout+owner 동기화).

> 잠금 보장: 명시 픽만 store에 영속 → re-hatch/펫스위치/재시작에도 유지(`_apply_persisted_unlock_choices`).
> auto는 `_pets`(state)만 쓰고 reconcile마다 재구성 → 절대 store 미도달. 그래서 unlocked-but-store-absent는
> 매 매치 플레이어에게 재제안.

### 3.3 보조 배선 (egg_runtime 외)
| 파일 | 변경 |
|---|---|
| `character_info_overlay_state.gd` | `var _last_lingpet_unlock_card_rects`(skill_icon_rects ~116 병렬), 각 원소 `{rect, choice_key, candidate_id}` |
| `character_info_overlay_frame_presenter.gd` | ~70의 `lingpet_runtime`로 `get_unlock_choice_options(pet_id, registry)` 호출, 결과를 `draw_panel`에 thread (~117) |
| `character_info_overlay_lingpet_presenter.gd` | `draw_companion_panel`에 `unlock_options` 파라미터 추가, open 키마다 후보 2장 카드 draw + rect를 `_last_lingpet_unlock_card_rects`에 append. 부착 밴드 = 친밀도 밴드(~207)와 스킬아이콘 행(~215) 사이, open일 때만 |
| `character_info_overlay_input_handler.gd` | `_handle_mouse_button`(owner/registry 스코프, ~34)에 좌클릭 분기 신설 — passive-inventory/equipment 패턴 미러(perk-grid는 scroll-only라 owner/registry 안 받음 → 피기백 금지) |
| `character_info_overlay_core.gd` | `_try_handle_lingpet_unlock_pick_click(pos, owner, registry)` — rect 히트테스트 → `runtime.commit_unlock_pick(...)` → 성공 시 redraw |

## §4. 트랩 브리프 (슬라이스가 봉인)

1. **TRAP2 재적용 (하중)** — §2/§3.2. **스모크: invalidate 없이 store write만 → stale 잔존 확인, commit → 새 스킬 landing.**
2. **TRAP1 owner-schema — 사이드스텝.** 후보를 owner에 싣지 말 것. frame-level 라이브 read(§3.3)로 우회.
   (만약 후일 owner sync가 필요해지면 `lingpet_*`+`ringpet_*` 페어를 `BattleSceneState.DEFAULT_VALUES`에 선언.)
3. **TRAP5 modal-pause 쿨타임 — N/A(상속).** TAB가 `is_character_info_active`로 물리+액티브아이템 월클럭
   쿨타임+스킬 쿨타임 전부 정지(frame_controller ~217/723, lifecycle ~16). picker 자체 clock/자체 정지 금지.
4. **TRAP4 hot-path lazy init** — 카드/아이콘 텍스처는 TAB open 엣지에서 프리웜, draw 콜드로드 금지.
   (`lingpet_debug_picker` 프리웜 패턴 참조.)
5. **TRAP3 row-budget — 조건부.** 후보 카드를 TAB **스탯 행**으로 넣을 때만 `_lingpet_row_budget_can_fit`
   게이트. 부착을 art-아래 전용 밴드로 하면 N/A(스탯 행 미증가). 부착 밴드 선택 시 명시.
6. **TRAP6 다국어** — 플레이어 노출 한글(헤더/버튼/안내) 전부 `language_settings_data.gd` en+zh,
   `translate_text` 경유, `localization_coverage_smoke` 봉인. 스킬명은 카탈로그 번역 사용.
7. **TRAP7 draw-safety** — passed canvas z=0 즉시모드, 음수-z 호스트/`draw_set_transform` 금지. open picker 픽셀-QA 1회.

### 4.1 잠금 권위 (재확인)
- STORE `lingpet_affinity_store.get_resolved_unlock_choices` = flat `{choice_key: id}`, 영속 → **잠금 권위**.
- STATE `lingpet_affinity_state.get_resolved_unlock_choices` = nested, reconcile마다 재구성 → 잠금에 쓰지 말 것.
- 엣지: `_apply_persisted_unlock_choices`(~1621)가 stale store(후보에 없는 id)를 clear+재오픈. 그래서
  `locked` 계산은 "store 존재 AND 여전히 유효 후보"로 — reconcile이 보는 것과 동일하게.

## §5. 후보 현실 (구현자 주의)

| choice_key | 후보 수 (현 펫) | picker 렌더? |
|---|---|---|
| `passive` (1st) | 항상 ≥2 (공용 5패시브 풀) | **항상** |
| `second_passive` | 항상 ≥2 (남은 4 중 2) | **항상** |
| `active` (1st) | 2-액티브 펫만 2, 단일 액티브 펫(lunabi/draft_bat/milkring/orbi)=1 | 2-액티브 펫만 |
| `second_active` | **현 전 펫 단일** (풀−primary=1, 3+ 액티브 풀 없음) | **현재 데드** (4키 경로는 유지) |

2-액티브 펫: maribo/volty/lumion/red_dragon/koyora/nekuring/monkeyring/rabi. 단일 액티브 펫의
active 카드 부재는 버그 아님 — `resolve_single_unlock` 자동 처리.

## §6. 스모크 (반증검증 필수)

배선은 사용자가, 아래는 봉인 계약. egg_runtime 스모크 + (가능하면) panel rect 단위.

1. `_verify_commit_unlock_pick_persists_locks_and_reapplies` — open 후보에서 **candidate[1]**
   (auto 기본값 candidate[0] 아님) 커밋 → (a) store에 픽 존재, (b) `owner.lingpet_*_skill_id ==
   candidate[1]` 라이브(재적용 성공), (c) `get_unlock_choice_options`가 locked=true, selected=candidate[1].
   **반증(정정 2026-06-15): "store-write 단독 = live stale(candidate[0] 잔존)" + "commit_unlock_pick =
   live landing(candidate[1])"으로 OUTCOME 봉인.** ⚠ 옛 브리프의 "invalidate 한 줄 제거 시 즉시 FAIL"은
   **부정확** — `_apply_current_loadout`이 early-return **전에** reconcile을 돌려서 invalidate 없이도
   commit의 직접 `_apply_current_loadout` 호출이 landing시킨다(reconcile-true 경로). invalidate는 방어적
   (owner re-sync `_synced_owner_loadout_key` 클리어 커버)으로 유지하되, 진짜 seal은 reapply 호출 자체:
   commit에서 `_apply_current_loadout` 호출을 빼야 (b)가 stale로 FAIL.
2. `_verify_commit_unlock_pick_rejects_relock` — 잠긴 choice_key에 재커밋 → false, store 불변 (1회 확정).
3. `_verify_get_unlock_choice_options_open_vs_locked` — passive unlocked + store 부재 → option present,
   locked=false, candidates≥2, selected==candidates[0](auto 기본값). 커밋 후 → locked=true, selected=픽.
4. `_verify_unlock_options_single_candidate_filtered` — 단일 액티브 펫(예 lunabi)은 active option 부재;
   `second_active`는 전 펫 부재. passive/second_passive는 present.
5. `_verify_unlock_candidate_rederivation_is_deterministic` — `get_unlock_choice_options` candidates[0] ==
   auto-resolve가 고를 값(동일 펫 반복 호출 동일 순서). **반증: 시드가 RNG면 candidates[0] 흔들림.**
6. `_verify_commit_rejects_invalid_or_unopened` — 후보 외 id → false; not-yet-unlocked choice_key → false.
7. `localization_coverage_smoke` 확장 — 신규 picker 한글 키 en+zh 커버.
8. (선택) panel rect 단위 — `_last_lingpet_unlock_card_rects` 부착 시 카드 rect가 content_rect 안이고
   히트테스트가 올바른 choice_key/candidate_id를 반환. 부착 밴드 픽셀-QA 1회(open picker 윈도우드 캡처).

## §7. 열린 노트 (구현 중 확정)

- **failsafe 재제안**: auto 비영속이라 명시 픽 전까지 매 매치 재제안 — §0 확정. 추가 grace/타임아웃 없음.
- **second_active 데드**: 현재 카드 안 뜸. 향후 3+ 액티브 풀 펫 추가 시 자동 활성(4키 경로 유지). 스모크 4가 회귀 가드.
- **부착 밴드 vs 스탯 행**: 권장 = art-아래 전용 밴드(TRAP3 회피). 스탯 행 선택 시 row-budget 게이트 의무.
- **잠금 후 표시**: locked choice_key는 카드 대신 픽된 스킬을 기존 스킬아이콘 행에 표시(현행 그대로). 카드는 open일 때만.

## §8. 적대 리뷰 결정/픽스 (2026-06-15, 배선 후 리뷰)

배선(11파일 +503/-15) 리뷰 결과: **코어 PASS**(TRAP2 재적용·잠금=STORE·두 키·override 경로·단일후보
필터 정확·봉인). click-route/frame-read 클린(owner-schema 사이드스텝 확정). 후속 픽스 3건(사용자 결정):

### #3 active 후보수 비대칭 → **지금 캡+스모크** (확정)
- 버그: `_get_active_unlock_candidate_ids`(egg_runtime ~1792)는 `_skill_ids_from_pool(...)` 풀 전체 미캡,
  형제 passive/second_*는 `_first_seeded_candidates(...,2)` 2캡. apply/seed의 `_normalize_choice_candidates`
  (affinity_state 1058, `if result.size()>=2: break`)는 2캡. → 3+ 액티브 풀이면 picker가 3번째 표시·commit이
  store에 기록하지만 reconcile의 `_apply_persisted_unlock_choices`가 2캡 후보로 `_choice_candidates_include`
  실패 → **store entry clear(픽 wipe)**. 현재 전 풀 ≤2라 휴면, **unsealed**.
- 픽스: `_get_active_unlock_candidate_ids`를 **raw first-2로 캡**(`.slice(0,2)` 등). ⚠ `_first_seeded_candidates`
  (셔플)로 캡하면 candidates[0]가 바뀌어 auto 기본값(normalize의 first-2)과 어긋남 — **반드시 raw first-2**
  (normalize와 동일 순서)로 candidates[0]=pool[0]=auto 보존.
- 스모크(반증 필수): **3-candidate 액티브 시나리오를 실제로 구동**. 3-액티브 펫이 없으니 (a) 테스트용
  3-액티브 풀 주입 또는 (b) 캡 헬퍼에 명시적 3원소 풀 단위 테스트. 2-풀 success-only 테스트는 봉인 못 함
  (어느 코드든 통과). 단언: get_unlock_choice_options active 후보 ≤2 AND 3번째-id 픽이 commit→reconcile/
  pet-switch 후에도 살아남거나 애초에 노출 안 됨(VALID 픽 wipe 금지).

### #1 single-band → **순차 + 대기 큐 표시** (확정, §3.3 개정)
- §3.3 "open 키마다 후보 2장 카드 draw"를 **순차(첫 open 1개만) 공개**로 개정. `_first_open_unlock_option`
  현행 유지가 곧 순차.
- 추가: open(non-locked ≥2) 옵션이 >1이면 **"+N 대기" 인디케이터**(밴드 타이틀/패널에 작게). 신규 문구는
  language_settings 4언어. presenter는 open 개수 필요(`_count_open_unlock_options` 헬퍼).
- 스모크: active+passive 동시 open 시 (a) `_first_open_unlock_option`이 순서상 첫(active) 반환,
  (b) open 개수 == 2(대기 큐 신호). presenter draw는 헤드리스 곤란 → 로직 레벨로 봉인.

### #2 localization → **picker 노출분만 지금 번역** (확정)
- picker가 inline으로 그리는 후보 스킬 **이름**(카탈로그 `name`, 예 "하이드로 스피어" 번역 0건 → 비한국어 한글)을
  language_settings 4언어 추가. 범위 = get_unlock_choice_options가 후보로 낼 수 있는 active 풀 이름 + 공용 5패시브
  이름 + second-slot 이름(유한 집합). **후보 description(hover)** leak은 후속(범위 외).
- 스모크: localization_coverage_smoke가 **후보 스킬명 집합**(전 펫 후보 이름)을 스캔해 en/zh/ja/es 커버 단언.

### LOW (기본 defer/후속)
- #4 `_unlock_candidate_spec` 매프레임 카탈로그 deepcopy(get_active/passive_skill_entry `.duplicate(true)`):
  paused TAB이라 게임플레이 프레임드랍 없음. polish = spec를 (pet,choice_key,candidate,lang) 키로 캐시 또는
  TAB-open 엣지 prewarm. 참조: catalog-const-deepcopy-hotpath 트랩.
- #5 후보 description hover KR-only: #2 후속에 흡수.
- #6 commit이 1st-before-2nd 순서 미강제: single-band UI가 차단(현행 안전). 멀티밴드/직접 API 시 잠복 — slice 제약 명시.
- #7 candidate id 대소문자 비대칭(`_choice_candidates_include` 소문자화 vs `_skill_ids_from_pool` 미소문자화):
  전 id 소문자라 휴면. `_skill_ids_from_pool`에 `to_lower()` 또는 apply 비교 대소문자무시로 잠복 제거.

### 프로세스
- 반증검증 **완료(정정)**: invalidate 한 줄 제거로는 smoke가 안 깨짐을 확인 — `_apply_current_loadout`이
  early-return 전 reconcile을 돌려 invalidate 없이도 landing(reconcile-true 경로). 그래서 smoke를
  "store-write 단독=stale / commit=land" OUTCOME 계약으로 재구성(§6 #1 참조). **하이든 노릇지**: 이
  unlock-reapply 클래스에선 invalidate가 reapply의 load-bearing 레버가 아니다 — reapply 호출(`_apply_current_loadout`)
  자체가 레버. invalidate는 owner re-sync 방어용.
- 커밋: index 무관 61파일 + egg_runtime 워킹트리의 audio/companion/archer 혼입 → V3-2c-UI도 hunk 선별
  (V3-3b와 동일 `d:/tmp/hunkfilter.mjs` 패턴).
