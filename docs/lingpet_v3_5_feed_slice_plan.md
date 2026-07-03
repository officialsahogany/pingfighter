# V3-5 슬라이스 — 먹이 액티브 아이템 (친밀도 즉발 + 런/링코어 상한)

> **SUPERSEDED (2026-07-03 / Slice 4):** 이 문서의 “먹이 = 친밀도 SOURCE_FEED + run 3회 캡”
> 설계는 `docs/lingpet_hunger_system_plan.md` Slice 4가 대체한다. 현재 계약은
> `lingpet_feed` = **귤 / 포만도 +40 / 필드+샵**, `lingpet_special_feed` =
> **특제 사료 / 포만도 +100 / 샵+보상**, `SOURCE_FEED` 친밀도 지급 제거,
> **배틀당 완료 급식 2회 캡**, 만복(`satiety == MAX`) 사용 차단이다. 아래 본문은
> 폐기된 친밀도 먹이 설계의 역사 기록으로만 읽는다.

> 단일 소스 `docs/lingpet_affinity_system_plan.md` §13-4. 액티브 아이템 런타임은
> `docs/item_runtime_checklist.md` 경로. 배선은 사용자, Claude는 디자인+적대 리뷰.
> 줄번호는 직접 정찰(2026-06-16) 시점, 드리프트 가능 — 심볼명 우선.
>
> **2026-06-30 정정:** 2번째 슬롯 해금은 더 이상 특정 친밀도 레벨(Lv.22 등) 도달로
> 게이트되지 않는다. 현재는 1차 스킬 유효 레벨 합계 + 레벨업 확률 롤 계약이며,
> 먹이 스모크는 현재 링코어 캡 천장 / per-run 사용 카운터 / 칩 배율 면제만 봉인한다.

## §0. 확정 결정 (재론 금지, 2026-06-16 / 먹이 천장 정정 2026-07-02)

| # | 항목 | 결정 |
|---|---|---|
| 1 | 먹이 = 액티브 아이템 | `lingpet_feed`(미러=`gauge_charge` 즉발 자원, `consumable:true`) |
| 2 | 획득 경로 | field-spawn(F 게이트 기커밋) **+ 플라자 샵 골드구매**(`grant_item_to_slot`) |
| 3 | per-run 캡 | **affinity_state 사용 카운터** — 런당 먹이가 친밀도 주는 횟수 ≤3, **샵+스폰 무관하게 affinity-from-feed 캡**(어느 경로 10개 사도 3개만 효과) |
| 4 | 허용 개수 | **3/런** (run-scope, reset_for_new_run서 0). 플레이스홀더(V3-6 튜닝) |
| 5 | 현재 링코어 천장 | **block + clamp 함께** — 현재 링코어 캡 이상이면 0, 캡 직전에서 큰 먹이도 캡까지만(clamp). T3는 Lv.15, T6는 Lv.30 |
| 6 | 칩 배율 면제 | chokepoint(412) `1.0 if source==SOURCE_FEED else mult` |
| 7 | N 값 | ≈35(한 레벨), 플레이스홀더 V3-6 |

## §1. 익스플로잇 = 이 슬라이스의 존재 이유

플라자 샵이 `plaza_shop_transactions.gd:63-68 grant_item_to_slot`로 골드→슬롯 그랜트하므로
**먹이가 샵에 풀리면 골드 무한구매로 0칩 친밀도 채우기 도달 가능**(칩·랠리 경제 우회). 캡 3종이
이걸 막는다. **핵심 봉인 스모크 = "먹이만으론 current ring-core ceiling/use cap 우회 불가"**
(무한 먹이 시도 → 현재 링코어 천장 + max_feed_uses).

## §2. 먹이 아이템 등록 (active_item_catalog + item_runtime_checklist)

- `_build_lingpet_feed()` (미러 `_build_gauge_charge`):
  ```
  {name:"lingpet_feed", display_name:"<링펫 먹이>", type:"active", effect:"lingpet_feed",
   chance:<field-spawn rate ~0.01>, cooldown_msec:DEFAULT_COOLDOWN_MSEC, feed_amount:35,
   description, icon_path:LINGPET_FEED_ICON_PATH, color, consumable:true}
  ```
- `FIELD_SPAWN_ORDER`에 `"lingpet_feed"` 추가 + `build_item_by_name` match arm.
- ⚠ **item_runtime_checklist 전 위치 감사**(액티브 아이템 add): 아이콘, 이름/설명 다국어 맵, sell_price /
  샵 base_price, 개발자모드 all_items 리스트, FIELD_SPAWN_ORDER, 효과 디스패치, Pandora 제외 목록(해당 시),
  online passive 분류(액티브라 무관). **CLAUDE.md 기본 가정: end-to-end + 아이콘 같이.**

## §3. 사용 → 효과 (apply_lingpet_feed → egg_runtime → affinity)

- `active_item_effect_controller.apply_lingpet_feed(item_data, owner, registry)` (미러 `apply_gauge_charge` line 195):
  registry로 `lingpet_egg_runtime` resolve → `runtime.feed_lingpet(owner, registry)` 호출 → 결과로 feedback.
  효과 디스패치(effect 문자열→apply 메서드)에 `"lingpet_feed"` 등록.
- **신규 public `lingpet_egg_runtime.feed_lingpet(owner, registry) -> Dictionary`** (add_enhancement_chip 패턴):
  `_affinity_state.add_points("feed", ...)` 호출, `{accepted, gained, chip_count무관, blocked_reason}` 반환.
- ⚠ 효과는 **owned 펫 있을 때만 유효**(F 게이트는 획득만 막음; 샵 구매분은 게이트 우회하니 use 시 owned 재확인 — companion 없으면 no-op/blocked).

## §4. affinity 통합 — SOURCE_FEED + 상한 3종 (affinity_state 집약)

### 4.1 소스
- `const SOURCE_FEED := "feed"` + `GAIN_TABLE["feed"] = {...points: 35}`(or feed_amount). `add_points`의
  `GAIN_TABLE.has(source)` 게이트(396) 통과용.

### 4.2 칩 배율 면제 (결정 6 — line 412)
- `var enhancement_multiplier := 1.0 if source == SOURCE_FEED else get_enhancement_chip_multiplier()`.
  먹이는 chip 곱 안 받음(다른 소스 불변).

### 4.3 사용 카운터 (결정 3·4)
- `var _feed_uses_this_run := 0` + `const MAX_FEED_USES_PER_RUN := 3`. **`reset_all()`(run)서 0**,
  `reset_for_new_battle` 금지(런 내 누적), store/snapshot 미영속(chip과 동일 run-scope).
- `add_points`서 `source==SOURCE_FEED and _feed_uses_this_run >= MAX_FEED_USES_PER_RUN` → blocked "max_feed_uses"(0 gain).
  성공 gain(>0) 시 `_feed_uses_this_run += 1`. **샵 10개 사도 4번째부터 친밀도 0.**

### 4.4 현재 링코어 천장 + clamp (결정 5, 2026-07-02 정정)
- 먹이 전용 고정 `Lv.15` 상수는 제거. `source==SOURCE_FEED`는 펫의 현재 `ring_core_cap`을 천장으로 쓴다.
- **clamp**: 캡 직전에서 큰 N이 다음 잠긴 레벨로 안 건너게 — feed granted_points를
  `min(granted, points_remaining_until_current_ring_core_cap)`로.
  예: T3(cap15)는 Lv.15까지만, T6(cap30)는 Lv.30까지.
- (30 MAX_LEVEL 캡은 절대 상한; 먹이는 그 아래 현재 링코어 캡을 따른다.)

### 4.5 삽입 위치 (add_points ~392-426)
- 403(30캡) 다음: feed current-ring-core-cap 게이트 + use-counter 게이트(blocked early-return).
- 408 _resolve_gain 후 / 412 면제 / 415 0-gate 위: current-ring-core-cap feed clamp.
- 419 누적 성공 후: feed 카운터 증가.
- (권장: `_resolve_gain`에 per-source `_resolve_feed_gain`을 두어 use-counter+clamp 집약, 면제는 412 source-check.)

## §5. 트랩 브리프 (슬라이스가 봉인)

1. **칩 배율 면제 필수(412)**: 기본은 전 소스 곱 → 먹이 안 빼면 (a)칩 곱한 먹이로 익스플로잇 가속 (b)§13-4 #4 위반. source-check 한 줄.
2. **샵 경로 방어**: per-run 캡은 field-spawn뿐 아니라 **샵 골드구매분도** 막아야 함. 사용 카운터(affinity-from-feed)가 획득 경로 무관하게 캡 → 샵 우회 차단(결정 3).
3. **cap block만으론 부족**: cap-1 + 큰 N → 잠긴 다음 레벨 교차 가능. **clamp 필수**(결정 5). N 작아도 V3-6서 커질 수 있으니 구조적 clamp.
4. **run-scope 경계**: 먹이 카운터는 `reset_for_new_run`만(런 내 battle 누적), 미영속. chip과 동일.
5. **use 시 owned 재확인**: 샵 구매분은 F 획득게이트 우회 → 효과 적용 시 companion/owned 재확인(없으면 no-op).
6. **item_runtime_checklist 전 위치**: 액티브 아이템 add 누락(아이콘 precedence·dev-mode·샵가·다국어)은 반복 트랩.

## §6. 스모크 (반증 필수)

1. **`_verify_unbounded_feed_attempts_stop_at_run_use_cap`** (핵심 봉인): 먹이만 무한 적용 →
   level ≤ current ring-core cap + 마지막 결과 `max_feed_uses`. 2번째 슬롯 해금 주장은 이 smoke 범위가 아님.
2. **use-counter**: 먹이 3회 친밀도 부여, 4회째 blocked "max_feed_uses"; `reset_for_new_run` 후 재무장.
   `reset_for_new_battle` 후 카운트 생존.
3. **현재 링코어 천장+clamp**: cap-1 + 큰 먹이 → 결과 ≤ cap(clamp); cap 이상이면 gain 0 "max_feed_level". T3 cap15와 T6 cap30을 함께 봉인.
4. **칩 면제**: 5칩 상태 먹이 gain == 0칩 먹이 gain(N, 2N 아님). 반증: 면제 빼면 2N.
5. **먹이 비영속**: store/snapshot에 feed 카운터 키 부재(source-scan).
6. **등록**: catalog build + FIELD_SPAWN_ORDER + effect 디스패치 + 아이콘 covered. (+ F 게이트 기커밋: pre-lingpet 미스폰 — 기존 smoke.)

## §7. 아트 deliverable — 먹이 아이콘 (item-generation 스킬)

- 먹이 = 링펫 트릿/푸드(작은 간식·캡슐·열매). 링피아 시안/웜 팔레트. **item-generation 스킬**(아이템 아이콘 파이프라인) 경로.
- PNG-first + 무아트 폴백. 런타임 선행 가능(아이콘 후행). 아이콘 precedence(items.py류 특별케이스 없음 — Godot loader 확인).

## §8. 시퀀싱 (권장)

- **affinity 4종(SOURCE_FEED + 면제 + use-counter + current-ring-core clamp) 먼저** — 캡 코어, egg_runtime `feed_lingpet`까지.
  스모크 1~5(핵심 봉인 포함)로 잠금. 아이템 아직 없어도 `feed_lingpet` 직접 호출로 캡 검증 가능.
- **아이템 등록(catalog + 효과 디스패치 + item_runtime_checklist)** — apply_lingpet_feed → feed_lingpet.
- **아이콘** — item-generation 병렬.
- 수치(N=35·3개/런·현재 링코어 캡)는 플레이스홀더 — V3-6(income QA) 재튜닝.
- ⚠ 배선 시 워킹트리 외부 dirty와 hunk 선별(V3-4와 동일 패턴).
