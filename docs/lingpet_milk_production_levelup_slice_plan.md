# Lingpet 우유생산(milk_production) 레벨 스케일링 + 치즈 슬라이스 설계서

Status: IMPLEMENTED (2026-06-20), AMENDED (2026-07-08). 단일 소스. 배선/리뷰는 이 문서를 체크리스트로 사용.
관련 메모리: 링펫 debug/정식 구분 폐지, [feedback_godot_localization_copy_sync],
[feedback_skill_cooldown_scope], Godot Per-Frame Probability Roll Trap(CLAUDE.md).

> **개정 (2026-07-08, 사용자 지시) — 이 개정이 아래 원본 계약을 override 함:**
> 치즈(체다/까망베르/에멘탈)는 이제 게이지 회복 **AND 밀크병 크기 버프**를 함께 준다(전엔 게이지 전용).
> 치즈 3종↔레벨 1:1이라 크기는 고정: 체다 +16%·까망베르 +18%·에멘탈 +20%(그 레벨 밀크병 배율).
> 밀크병과 **동일 `milk_bottle_scale` 풀 + `MILK_BOTTLE_SCALE_MAX`(+60%) 캡 공유**. 구현:
> `_build_cheese(name, display, gauge_gain, paddle_scale_multiplier, icon, color)`가
> `paddle_scale_multiplier`/`paddle_scale_percent`/`stage_persistent`/결합설명을 실음 →
> facade 공용헬퍼 `_apply_milk_bottle_scale`를 `activate_milk_bottle`·`activate_cheese`가 공유
> (activate_cheese = 크기 헬퍼 + `apply_gauge_charge` 둘 다, controller가 `_paddle_sync` 전달).
> 다국어: 아이템설명 정적맵 7블록 + 스킬설명/effect_text(한국어 그대로) 동기화.
> 씰: active_item_milk_bottle_runtime_smoke `_verify_cheese_applies_size_buff`(반증검증 완료).
> **아래 "치즈는 사이즈 효과 없음 / paddle_scale_multiplier 없음 / apply_gauge_charge만" 문구는 폐기.**

## 0. 확정 설계 결정 (재론 금지)

- **게이지 = `special_gauge`(왼쪽 파란 "게이지구슬", max 500)**. 5개 "스킬구슬"과 별개.
  링펫이 공 받아칠 때 +40 채우는 그 미터. 치즈는 이 게이지를 즉시 회복.
- **치즈는 밀크병 "대신"** 나옴 — Lv.3+ 생산당 1개, 30% 치즈 / 70% 밀크병 (런치당 1회 롤).
- ~~치즈는 사이즈 효과 없음(게이지 회복 전용). 사이즈는 밀크병만.~~ **[2026-07-08 개정]** 치즈는
  게이지 회복 **AND** 그 레벨 밀크병 크기 버프를 함께 준다(밀크병과 동일 scale 풀+캡 공유). 상단 개정 참조.
- 쿨다운은 사용자 지정 정확값을 **권위화**(전역 레벨세금 미적용).
- **밀크병 패들 버프는 사용당 캡 스택**(2026-06-21 결정). 비스택 set이 아니라 사용 시
  증분(배율−1.0)을 `milk_bottle_scale`에 누적, 상한 +60%(`MILK_BOTTLE_SCALE_MAX = 1.60`)까지.
  Lv.5 기준 첫 사용 1.20 → 1.40 → 1.60(캡). 스테이지 종료까지 지속, 스테이지 전환 시 리셋.
  **이유**: 밀쿠가 매 쿨마다 우유를 생산하는데 레거시 단발 milk_bottle의 활성-중복
  `can_store_item` 게이트가 첫 **사용** 후 모든 우유 픽업을 막아 "두번째부터 획득 안 됨" 버그
  발생 → 게이트 제거 + 누적 보상으로 전환.

## 1. 레벨별 수치

| Lv | 밀크병 사이즈 배율 | 쿨다운(초) | Lv.3+ 치즈(30%) |
|----|------------------|-----------|-----------------|
| 1  | 1.12 (+12%)      | 50        | — |
| 2  | 1.14 (+14%)      | 47        | — |
| 3  | 1.16 (+16%)      | 44        | 체다치즈 → 게이지 +300 **+ 크기 +16%** |
| 4  | 1.18 (+18%)      | 41        | 까망베르치즈 → 게이지 +400 **+ 크기 +18%** |
| 5  | 1.20 (+20%)      | 37        | 에멘탈치즈 → 게이지 +500 (풀충전) **+ 크기 +20%** |

- `paddle_scale_multiplier_by_level = [1.12, 1.14, 1.16, 1.18, 1.20]`
- `cooldown_by_level = [50, 47, 44, 41, 37]`  (authoritative)
- `cheese_chance_by_level = [0.0, 0.0, 0.30, 0.30, 0.30]`
- 치즈 변종은 레벨로 결정: Lv.3=cheddar, Lv.4=camembert, Lv.5=emmental (한 레벨당 1종만 생산)

## 2. 카탈로그 (lingpet_catalog.gd) — milkring milk_production

`active_skill` + `active_skill_pool[0]`(milkring_milk_production) 둘 다에 추가:
```
"paddle_scale_multiplier_by_level": [1.12, 1.14, 1.16, 1.18, 1.20],
"cooldown_by_level": [50.0, 47.0, 44.0, 41.0, 37.0],
"cheese_chance_by_level": [0.0, 0.0, 0.30, 0.30, 0.30],
```
description도 레벨 거동 반영(사이즈 12~20%, Lv.3+ 30% 치즈 = 게이지회복+크기증가 [2026-07-08 개정]) — §6 다국어 동기화 동반. 스킬설명/effect_text도 동기(한국어 그대로, 정적맵 없음).

### 2.1 쿨다운 권위화 규칙 (핵심)
- `_apply_skill_level_values`(catalog ~1711)는 `cooldown_by_level[level-1]` → `result["cooldown"]`로 덮음.
- 그 다음 `_apply_active_skill_level`(catalog ~1693)가 전역 `ACTIVE_COOLDOWN_REDUCTION_PCT_BY_LEVEL`
  [0,3,6,9,12]%를 곱함 → **중복 적용**(Lv.5: 37×0.88=32.6 ❌).
- **수정**: `_apply_active_skill_level`에서 `skill_data.has("cooldown_by_level")`면 전역 쿨 감소를
  **skip**(이미 레벨 스케일이 explicit). 윈드업 감소도 동일 판단(우유생산은 윈드업도 explicit 안 함 →
  윈드업 3.0은 그대로 두고 전역 윈드업세금만 적용해도 무방, 단 일관성 위해 쿨만 권위화/윈드업 유지 권장).
- 패시브/아이템 쿨감(lingpet_current_profile ~112)은 별도 버프이므로 그대로 위에 적용 OK
  (milkring엔 해당 패시브 없음 → 표시값 정확히 [50,47,44,41,37]).
- HUD/툴팁은 최종 cooldown을 읽음(lingpet_companion_skill_state.cooldown via complete_launch) → 자동 반영.

## 3. 런타임 (lingpet_milk_production_skill.gd)

- `launch(origin, owner, launch_context)`에서 `active_skill_level = int(launch_context.get("active_skill_level", 1))` 추출
  (banana_slice/skeleton_archer 패턴). 현재는 launch_context 무시 중.
- **치즈 롤(런치당 1회)**: `level >= 3`이면 1회 `randf()` < `cheese_chance(=0.30)` → 치즈, 아니면 밀크병.
  per-frame 금지(launch는 one-shot이라 안전하지만 update()에 롤 넣지 말 것). 테스트용 `_forced_roll` 주입 훅.
- **밀크병 스폰**: 레벨별 `paddle_scale_multiplier` override 주입 필요 → `spawn_field_item(name,pos)`는 override 미지원,
  `spawn_field_item_data(item_data, pos)` 사용(active_item_runtime ~395). milk_bottle item_data 복제 후 scale 덮어 스폰.
- **치즈 스폰**: 레벨 변종 아이템명(`cheddar_cheese`/`camembert_cheese`/`emmental_cheese`)을 그대로 `spawn_field_item`로 스폰
  (회복량은 아이템에 baked, override 불필요).
- 치즈도 stationary_field_item + dash_destroy + lingpet_generated_only(밀크병과 동일 픽업/파괴 거동).

## 4. 신규 액티브 아이템 3종 (docs/item_runtime_checklist.md 기준 전 경로)

아이템: `cheddar_cheese`(체다치즈, +300), `camembert_cheese`(까망베르치즈, +400), `emmental_cheese`(에멘탈치즈, +500).
각 게이지 회복 **+ 밀크병 크기 버프**(체다 1.16 / 까망베르 1.18 / 에멘탈 1.20). [2026-07-08 개정]

| # | 위치 | 작업 |
|---|------|------|
| 1 | active_item_catalog.gd:36 | 3× ICON_PATH(+FIELD_ICON_PATH) const |
| 2 | active_item_catalog.gd:~125 build_item_by_name | 3× case |
| 3 | active_item_catalog.gd:~617 (_build_milk_bottle 참조) | `_build_cheese(name, display, gauge_gain, paddle_scale_multiplier, icon, color)` ×3. 플래그: type active, effect "cheese", consumable, stationary_field_item, dash_destroy_on_player_contact, lingpet_generated_only, `gauge_gain: N`, `gauge_max: 500`, color, icon_path, field_icon_path, description. **[2026-07-08 개정] `paddle_scale_multiplier`(체다 1.16/까망베르 1.18/에멘탈 1.20)+`paddle_scale_percent`+`stage_persistent` 실음** |
| 4 | active_item_effect_router.gd:~53 | `cheese` effect → activate_cheese |
| 5 | active_item_effect_action_facade.gd:~179 | `activate_cheese`: **[2026-07-08 개정] 공용 `_apply_milk_bottle_scale`(크기 풀 누적+캡)** AND `apply_gauge_charge(...)`로 gauge_gain 적용(500캡/gold_digger 상속). `paddle_sync` 인자 필요, feedback는 gauge 경로가 소유 |
| 6 | active_item_effect_controller.gd:~275 | `activate_cheese` 위임 — **[2026-07-08] `_paddle_sync` 전달** |
| 7 | active_item_effect_status.gd:~11 | 즉발 소비형이라 active_flag 불필요할 수 있음 — milk_bottle은 지속버프라 flag 있음. 치즈는 즉발이므로 store-gate 불필요(확인) |
| 8 | active_item_effect_reset.gd | 즉발이라 reset 상태 없음(사이즈 scale 없음) — 추가 불필요(확인) |
| 9 | active_item_field_item_motion / pickup_flow | stationary/dash_destroy 플래그 소비 — 기존 milk_bottle 경로 재사용(코드 변경 없을 가능성) |
| 10 | active_item_debug_spawn_menu.gd | lingpet_generated_only → DEBUG_ENTRY_ORDER 추가 **안 함** |
| 11 | 경제(sell_price/shop) | lingpet_generated_only → 상점/필드드랍 제외. sell_price는 합리값 1개 |
| 12 | Pandora 제외 리스트 | 신규 액티브면 제외셋 동기화(레거시 경로 확인) |

함정: 치즈 게이지 회복은 life_elixir의 apply_life_elixir(전용 파티클) 재사용 금지 — `apply_gauge_charge`만. **[2026-07-08 개정]** 크기 버프는 milk_bottle의 long_boost/timed-paddle 지속-scale 패턴 복제 금지 — 공용 `_apply_milk_bottle_scale`(즉발 누적, 스테이지 종료까지 지속)를 공유한다.

## 5. 다국어 (language_settings_data.gd) — 3종 × 이름+설명, 누락 0

- 이름: ITEM_DISPLAY_{EN,ZH,JA,ES,PT_BR,RU} 6개 맵 각각 3키 추가(알파벳 위치).
  한국어 이름/설명은 `active_item_catalog.gd`의 카탈로그 원문이 canonical이며,
  `LanguageSettings.localize_item_data()`는 한국어에서 카탈로그 데이터를 그대로 반환한다.
- 설명: MYTHIC_DESCRIPTION_{EN,ZH,JA,ES,PT_BR,RU} 7맵(+EN ACTIVE_ITEM_DESCRIPTION 여부 확인) 3키씩.
- 키 이름: `cheddar_cheese`/`camembert_cheese`/`emmental_cheese` (코드 아이템명과 동일).
- 봉인: localization_coverage_smoke.gd가 EN 기준 키 일치 검사 → 한 언어라도 빠지면 실패.
- 숫자(300/400/500)·"게이지"의 각 언어 표기까지 동기화([feedback_godot_localization_copy_sync]).

## 6. HUD / 툴팁

- 쿨다운: 이미 최종 cooldown 읽음 → §2.1 권위화로 [50,47,44,41,37] 자동 표시(별도 작업 없음, 확인만).
- 스킬 설명: LingpetCatalog active_skill `description` → snapshot `companion_skill_description` → rail_card/character_info.
  레벨 거동(사이즈%/쿨/치즈) 반영하되 perk-affected 수치는 추상화 가능. Lv별 정확 수치는 catalog by_level이 진실.
- 치즈/밀크병 아이템 설명: active_item_catalog `description`(샵/툴팁용) + 다국어.

## 7. 아이콘 (imagegen) — 3 치즈 × (slot 256² + field 256²)

- milk_bottle 컨벤션: slot 256² + field 256²(`milk_bottle_icon_imagegen_v1.png`, `milk_bottle_field_imagegen_v1.png`).
- 치즈 디자인: 체다=주황 단단한 쐐기, 까망베르=흰 껍질 원형 소프트, 에멘탈=옅은 노랑 큰 구멍(스위스). 게임 큐트 아이템 스타일(milk_bottle 매치).
- slot/field 동일 디자인 재사용 가능(milk_bottle은 분리지만 치즈는 1디자인 2용도 허용). Claude 생성+QA.

## 8. 스모크 의무

- active_item_milk_bottle_runtime_smoke 확장: (a) Lv.3 launch_context로 치즈 30% 스폰(force_roll), (b) 밀크병 레벨별 paddle_scale override 검증.
- 신규 cheese item 스모크: 3종 catalog 빌드 + activate_cheese가 special_gauge를 정확히 +300/400/500(500캡) 회복하는 OUTCOME 단언. **[2026-07-08 개정]** `_verify_cheese_applies_size_buff`: 치즈가 크기(1.16/1.18/1.20)를 밀크병 공유 풀에 누적+캡(+60%)하는 OUTCOME + is_milk_bottle_active 단언(반증검증: size off → 치즈 크기레그만 FAIL).
- cooldown 권위화 스모크: get_active_skill(milkring, lvl) cooldown == [50,47,44,41,37] 정확(전역세금 미적용 반증검증).
- 치즈 롤 per-opportunity: 런치당 1회, 실패 롤이 같은 생산 내 재트리거 안 됨(force_roll false).
- localization_coverage_smoke 통과(3종×7언어).
- warning_scan + headless_load.

## 9. 슬라이스 분할

- S1 카탈로그 레벨배열 + 쿨다운 권위화 규칙 + 스모크.
- S2 milk_production 런타임(레벨/스폰 override/치즈 롤) + 스모크.
- S3 치즈 3종 아이템(catalog/effect/gauge회복/플래그) + 스모크.
- S4 다국어 7언어 + localization 스모크.
- S5 아이콘 6장 imagegen + 배선 + 인게임 확인.
- S6 HUD/툴팁 문구 + 적대리뷰 + warning/headless 최종.

## 10. 트랩(워크플로 매핑 결과)

- 쿨다운 2중 감소(전역 + 패시브). cooldown_by_level만 넣으면 전역세금 중복 → 권위화 skip 필수. HUD는 최종값 읽으니 catalog만 맞추면 됨.
- spawn_field_item(name,pos)은 override 미지원 → 밀크병 레벨 scale은 spawn_field_item_data 필요.
- 치즈 게이지는 life_elixir 전용경로 복제 금지, apply_gauge_charge만. **[2026-07-08 개정]** 크기는 timed-paddle/long_boost 복제 금지 — 공용 `_apply_milk_bottle_scale` 공유(밀크병과 동일 풀+캡).
- special_gauge는 player·lingpet 공유 단일 필드(max 500 하드코딩 ball_update_static_config 등) — 전역 max 건드리지 말 것.
- 다국어: EN에 키 추가하고 한 언어라도 빠지면 localization_coverage_smoke 실패. 한국어는 별도 ITEM_DISPLAY_KO를 만들지 말고 카탈로그 원문을 사용.
- 치즈 롤은 launch()(one-shot)에서만. update()에 넣으면 per-frame 컴파운딩.
- **레거시 단발 액티브 아이템을 "지속 생산"하는 링펫 스킬은 그 아이템의 단발용
  `can_store_item` 활성-중복 게이트를 상속한다.** milk_bottle은 `milk_bottle_active` 중
  새 milk_bottle 저장을 차단(`active_item_effect_status.gd`) → 밀쿠가 매 쿨마다 생산해도
  첫 사용 후 픽업 불가(필드에 남고 store 실패로 조용히 픽업 안 됨). 해결 = 게이트 제거 +
  버프 누적(캡). 봉인: `active_item_effect_status_smoke`(게이트 무차단) +
  `active_item_milk_bottle_runtime_smoke`(스택 1.20→1.40→1.60·캡·active 중 collectable, 반증검증).
  미래에 다른 링펫 스킬이 기존 액티브 아이템을 반복 생산하면 그 아이템의 can_store 게이트를 먼저 감사.
- 공유 트리 무빙HEAD: 배선 후 커밋 직전 git diff 재확인(이번 세션 1줄 reverted 전례).
