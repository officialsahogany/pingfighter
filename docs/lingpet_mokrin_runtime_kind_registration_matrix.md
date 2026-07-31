# 묵린변신 `runtime_kind` 등재 전수표 + WIP 중첩 지도 (S1 착수 전 검토용)

작성 2026-07-29. 정본 = `docs/lingpet_baekrin_mokrin_slice_plan.md`
(D14 원복·쿨다운 계약 / D15 player-control 브리지 / §신규 runtime_kind 등재 전수표).
코덱스 리뷰(a9cb9e815 승인) 권고 반영: **S1 전체 구현 전에 이 전수표를 먼저
검토받는다.** 이 문서는 **분류만** 하며 코드는 건드리지 않는다.

분류 기준 — 각 행은 셋 중 하나다:

- **필수** = 묵린 전용 분기를 직접 추가해야 한다(누락 시 조용한 무동작).
- **자동** = 다른 등재(주로 `_get_skill_for_kind` / `_peek_skill_for_kind` /
  필드 선언)로 자동 충족된다. **중복 배선 금지.**
- **N/A** = 묵린변신 사양상 해당 없음(근거 필수).

묵린변신 사양(D5~D15 확정): 5초 지속 / 쿨 40초 / **공속 보너스 없음** /
**연출 전용**(변신 프레임·잔상·오라) / 실제 이동 적용은
`smasher_player_controller`가 소유(D15) / 투사체·소환체·보스 CC 없음.

## A. 디스패처 (`lingpet_skill_dispatcher.gd`)

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
| A1 | `SKILL_KIND_MOKRIN_TRANSFORM` 상수 신설 | **필수** | 모든 match의 키 |
| A2 | `SUPPORTED_SKILL_KINDS`에 `true` 등재 | **필수** | 누락 시 `get_skill_kind`가 카탈로그 kind를 받고도 **`SKILL_KIND_NONE`으로 강등**(:88 `is_supported_kind` 게이트) → 전 경로 조용한 무동작 |
| A3 | `get_skill_kind()` 하드코딩 match 폴백 | **자동** | 카탈로그 `get_active_skill_runtime_kind()`가 우선(:86). 카탈로그에 `runtime_kind`를 넣으면 폴백 불요 — **단 A2가 있어야 유효** |
| A4 | `would_share_module`(:238~242) | **자동** *(확정 2026-07-31)* | 본문이 `first_kind == get_skill_kind(second)` **순수 kind 비교**다. 별도 선언 지점이 없고 **A1/A2에 고유 kind를 등재하면 다른 kind와 자동으로 false**가 된다. ⚠️ 다만 안장(permit)과 kind가 겹치면 슬롯이 조용히 2→1 붕괴하므로 **고유 kind 유지가 전제** |
| A6 | `get_exclusive_resource_classes`(:245~257) | **N/A 확정** *(2026-07-31)* | 클래스가 `BALL_OWNER` / `POS_OVERRIDE` 둘뿐이고 **링펫 kind끼리만** 매칭한다. 묵린은 둘 다 안 쓴다. ⚠️ **§5-8 해결 수단이 아니다** — 이 게이트는 **외부 신령환도, host 밖 permit 안장도 볼 수 없다.** `player_control` 클래스를 새로 추가해도 마찬가지다. §5-8(안장+묵린변신 중첩)과 신령환 동시 낭비는 **서로 다른 항목**이며 둘 다 여기서 해결되지 않는다 |
| A5 | 카탈로그 스킬 정의에 `runtime_kind` 필드 | **필수** | `lingpet_catalog.gd`. ⚠️ WIP 중첩 있음(§F) |

## B. 호스트 — 생명주기 (`lingpet_skill_runtime_host.gd`)

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
| B1 | `_mokrin_transform_skill` 필드 선언 | **필수** | 나머지 fanout의 대상 |
| B2 | `reset(:80)` fanout | **필수** | 누락 시 상태 영구 잔존. **D14 경계 4종 중 "수호령 강제수납"이 `end_for_stow`→`reset` 경유**라 이 한 줄이 그 계약을 담당 |
| B3 | `end_for_stow(:111)` | **자동** | `reset()` 위임(본문 1줄) |
| B4 | `clear_for_tests(:115)` null 대입 | **필수** | 씰 간 상태 오염 방지 |
| B5 | `reset_round(:146)` fanout | **필수** | **D14 "라운드 리셋" 경계 담당.** 누락 시 라운드 경계 영구 누출 |
| B6 | `update(:173)` match fanout | **필수** | 누락 시 **타이머가 아예 안 돌아감**(조용한 무동작) |
| B7 | `_get_skill_for_kind(:873)` match | **필수** | get 진입점. B8·C4·C5·E2가 여기에 의존 |
| B8 | `_peek_skill_for_kind(:927)` match | **필수** | 비생성 peek. `needs_runtime_update_for_skill`이 사용(핫패스 lazy-init 트랩) |
| B9 | `_get_mokrin_transform_skill()` 개별 게터 | **필수** | B7 match가 호출하는 지연 생성자 |

## C. 호스트 — 판정·게이트

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
| C1 | `launch(:472)` match | **필수** | 발동 진입점 |
| C2 | `is_launch_blocked(:394)` | **필수** | 재시전 정책. 묵린은 **활성 중 재발동 차단**이 자연 사양(5초 지속 + 쿨 40초). ⚠️ 이걸 C3·liveness와 혼동 금지 |
| C3 | `can_arm(:448)` | **N/A** | 기본 분기 `_: return true`(:469~470)로 자동 처리. 묵린은 **조건부 무장 사양이 없다**(쿨다운은 상위 `companion_skill_persistence` 소관). 분기 추가 시 중복 |
| C4 | `needs_runtime_update_for_skill(:338)` | **자동** *(정정 2026-07-29)* | 본문이 **범용 검사 우선**이다: peek(B8) → `_skill_has_visible_effects` → **`has_method("is_active") and is_active()`** → 그 뒤에야 match(is_active 없는 소수 스킬용). **묵린 모듈이 `is_active()`를 구현하면 kind 분기 불요.** ⚠️ 단 **씰은 그대로 필수** — "시각 효과 0인 프레임에도 타이머 tick 지속" 반증. `is_launch_blocked` 재사용 금지 트랩은 유효 |
| C5 | `prewarm(:370)` | **자동** | `_get_skill_for_kind` 경유(B7). **자체 분기 추가 금지** — 단 스킬 모듈이 `prewarm()`을 구현해야 실효 |
| C6 | `prewarm_many(:376)` | **자동** | `prewarm()` 위임 |

## D. 호스트 — 렌더·표시

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
**소유권 확정 (2026-07-29, 코드 선례 조사 결과)**: 이 리포의 일관된 패턴은
**"상태 모듈이 상태를 소유하고, 렌더러가 몸체를 그린다"**이다 —
온이마루 `lingpet_mount_state:42`는 탑승 상태·위치만 소유하고
`lingpet_companion_draw_context_builder:159`가 몸체 텍스처를
`companion_carry`로 교체하며 `lingpet_companion_renderer:21`이 그린다.
뿔딸기·오딘도 상태 런타임이 몸을 직접 그리지 않고
`stage1_player_actor_renderer:581`의 전용 presentation renderer가 교체한다.
**묵린도 이 패턴을 따르므로 D 블록 전부 N/A.**

| D1 | `draw(:228)` fanout | **N/A** | 변신 몸체는 컴패니언 렌더러가 텍스처 교체로 그린다(위 선례) |
| D2 | `has_visible_effects(:255)` or-fanout | **N/A** | D1과 동반 |
| D3 | `has_visible_effects_for_skill(:284)` match | **N/A** | D1과 동반 |
| D4 | `suppresses_companion_body_draw(:572)` | **N/A 확정 — `false` 유지** *(2026-07-31)* | **같은 렌더러 안에서 텍스처를 교체**하므로 원본과 중복 자체가 없다. ⚠️ host가 변신체를 직접 그리고 기본 몸체를 억제하면 **z-order가 틀어진다** — host `draw()`는 전면 VFX 패스인데 컴패니언 몸체는 `lingpet_egg_runtime:1039`의 **플레이어 뒤 패스**다(주석에 "intended to run BEHIND the player actor" 명시) |
| D5 | `should_show_cast_windup(:584)` / `get_companion_cast_pose_progress(:588)` | **필수** *(확정 2026-07-31)* | ⚠️ **N/A(잠정)에서 승격.** 변신 시트를 그릴 **가장 좁은 경로가 기존 `companion_cast` 경로**다 — 6×2·12f 시트를 그 키에 연결하고 `get_companion_cast_pose_progress()`로 **재생 진행도와 f12 hold를 투영**한다. 신규 렌더 분기·신규 body override가 불필요해진다 |
| D7 | `lingpet_skill_companion_surface_router.gd` 등재 | **필수** *(신설 2026-07-31)* | D5를 실제로 태우는 라우터. host의 `_companion_surface_router`가 kind→모듈 표면을 중계하므로 **여기 미등재면 D5가 조용히 빈값**이 된다. ⚠️ WIP 지도(§F)에도 추가됨 |
| D6 | `get_companion_bind_sheet_state(:1148)` | **N/A — 재사용 금지** | ⚠️ 이 훅은 **Star Coil 전용**(:1145)이고 **몸체를 보스 앞 front-pass로 옮기는 의미까지 결합**돼 있다. 묵린 6×2 변신 시트는 **별도의 companion body override / snapshot 표면**을 둔다. 잔상·오라도 gameplay state가 직접 그리지 말고 전용 presentation renderer 또는 companion renderer 하위 레이어가 snapshot을 소비하는 구조로 |

## E. 호스트 — 부가 표면

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
| E1 | `trigger_launch_feedback(:594)` | **필수 — 단 범위 분리** *(2026-07-31)* | `_launch_feedback_router.trigger()` 위임 → **라우터 쪽 등재**가 실제 작업. ⚠️ **발동 단발음만 여기 소유**한다. **가드 단계 SFX는 §E' X4대로 모듈 소유** — 섞으면 D14-2("단발 발동음은 되감지 않음")와 "가드마다 단계 상승"이 한 채널에 엉킨다 |
| E2 | `get_snapshot(:607)` `_merge_skill_snapshot` | **필수 (재확정 2026-07-31)** | ⚠️ **초판 오분류 정정.** 필드 순회가 아니라 **`_merge_skill_snapshot`을 24회 명시 나열**한 수동 fanout이다(:609~632 실측). B1 필드 선언만으로는 **포함되지 않는다** — 한 줄 추가 필수. **"production 소비자 없음 → N/A" 제안은 철회됨**: 살아있는 사슬 = `egg_runtime.get_snapshot()` → `_build_runtime_snapshot_uncached()` → `lingpet_runtime_snapshot_builder:189` → `skill_runtime_host.get_snapshot()`. 추가로 `character_info_overlay_frame_presenter:154`가 집계본을 직접 읽어 패널에 병합한다. **레일 주 경로(per-skill `get_snapshot_for_skill_id`)와 대체 관계가 아니라 공존**이며, 집계본은 레일 fallback + 다른 HUD 소비자용이다 |
| E3 | `get_snapshot_for_skill_id(:636)` / `get_snapshot_for_kind(:640)` | **자동** | B7/B8 경유 |
| E4 | `get_launch_origin(:532)` | **N/A** | 투사체 없음 |
| E5 | `has_companion_position_override(:536)` / `get_companion_position_override(:542)` / `get_active_position_override_owner(:548)` | **N/A** | 묵린은 **플레이어 패들**을 자동조작하지 펫 위치를 스크립팅하지 않는다(D15) |
| E6 | `suppresses_companion_body_hit(:566)` | **N/A(잠정)** | 무력화 창이 아님. 변신 중 펫이 무적/비피격이 되는 사양이면 재분류 |
| E7 | `consume_companion_strike_request(:578)` | **N/A** | 스트라이크 요청 없음 |
| E8 | `get_boss_ai_context(:598)` | **N/A** | banana_slice 전용 하드코딩. 묵린은 보스 AI 컨텍스트를 발행하지 않음 |
| E9 | `get_ball_collision_context(:802)` / `notify_*_hit` | **N/A** | 공 충돌 계약 없음 |
| E10 | `*_for_tests()` 계열 | **선택** | 씰이 내부 카운터를 필요로 할 때만 |

## E'. 외부 — 운영 가드 접촉 통지 (신설 2026-07-31)

D10(가드 카운트 기반 잔상·오라·SFX 단계)을 올리려면 **운영 플레이어 패들 접촉에서
런타임에 통지**해야 한다. 현재본에 이 경로가 통째로 빠져 있었다.

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
| X1 | `paddle_bounce_event_router.register_player_hit(:29)` → egg runtime → host/module 통지 | **필수** | 이게 없으면 가드 횟수·연출 단계가 **영원히 0**이다 |
| X2 | **신령환 조기 반환 앞에 배치** | **필수** | ⚠️ `register_player_hit`의 신령환 분기가 `apply_aipill_guard_drain` + `_trigger_player_hit_anim` 후 **`return updated_gauge`로 조기 반환**한다(:46 부근, 확인). 동시 활성에서도 묵린 가드를 셀 정책이라면 **통지는 반드시 그 반환 앞**이어야 한다 |
| X3 | 오검출 필터 | **필수** | 방패 · 대체 인터셉트 · 컴패니언 몸통 가드를 **일반 패들 가드로 잘못 세면 안 된다.** 무엇을 "묵린 가드 1회"로 셀지 술어를 명시 |
| X4 | 가드 단계 SFX 소유 | **모듈 소유** | E1(launch feedback router)은 **발동 단발음**만. **가드 단계 SFX는 X1 통지를 받은 모듈이 소유**한다 — 두 개를 한 라우터에 섞지 말 것 |

## F. WIP 중첩 지도 (2026-07-29 실측)

S1 구현 대상 4파일이 **전부 dirty**다. 구현 전 소유권 판단 필요:

| 파일 | dirty 규모 | 성격 / 주의 |
|---|---|---|
| `battle_scene_frame_controller.gd` | **+195/−771 (948줄)** | ⚠️ **대형 외래 리팩터**(프레임 컨트롤러 모듈 분해 캠페인, 정산 보류 13건 목록에 등재). 여기에 묵린 브리지 헝크를 얹으면 헝크 분리가 사실상 불가능 |
| `smasher_player_controller.gd` | 15줄 | 소규모. 성격 확인 후 헝크 분리 가능성 높음 |
| `battle_update_player_control_deps_builder.gd` | **1줄** | 거의 클린 |
| `lingpet_catalog.gd` | 2줄 | 소규모 |
| `lingpet_skill_companion_surface_router.gd` | **0 (클린)** | *(추가 2026-07-31)* D7 대상. 선행 WIP 없음 |
| `paddle_bounce_event_router.gd` | **0 (클린)** | *(추가 2026-07-31)* §E' X1~X3 대상. 선행 WIP 없음 |

### ✅ 브리지 경로 확정 (2026-07-29, 코드 조사 완료)

**`battle_scene_frame_controller.gd` 접촉 0건으로 S1 브리지 구성 가능.**
실제 호출 경로: `update_player_control`(`battle_frame_flow_controller:102`) →
`battle_scene_actor_update_driver:28`이 **매 틱 deps를 새로 생성** →
캐릭터 컨트롤러. `update_lingpet`은 같은 flow의 `:123`이므로 **D15의 "launch
결과가 다음 player-control부터 보인다"는 경계도 자연 성립**한다.

확정 구성 (4요소 — ⚠️ "deps_builder 파일 하나만 고치면 끝"이 아니다):

1. `lingpet_egg_runtime`에 좁은 전달 메서드 (`is_mokrin_transform_active()`)
2. `battle_update_player_control_deps_builder:34`가 **그 메서드만 가리키는
   fail-closed Callable** 전달 (**egg_runtime 객체 자체 노출 금지**)
3. `smasher_player_controller:53`(공용 진입점)이 predicate를 읽고 **기존
   AIPill 자동 이동 계산을 재사용**
4. `battle_scene_frame_controller` 접촉 0건 → 대형 외래 WIP 충돌 소멸

⚠️ **추가 감사점**: `viper_player_controller:30`은 공용 컨트롤러 진입 **전에
캐릭터 스킬 결과를 조기 반환**할 수 있다. 묵린 자동조작이 5캐릭 전부에서
항상 우선해야 한다면 **바이퍼 조기 반환 픽스처를 씰에 포함**할 것.
(이것도 frame_controller 접촉 사유는 아니다.)

나머지 3파일(smasher_player_controller 15줄 / deps_builder 1줄 /
lingpet_catalog 2줄)은 헝크 분리로 진행 가능.

## G. 씰 계획 — 활성화 경계 (코덱스 권고 반영)

기존 계획(D14 경계 4종 + 쿨다운 보존)에 **활성화 경계**를 추가한다:

> **운영 `launch`가 `update_lingpet`에서 성립한 뒤, 다음
> `update_player_control`이 묵린 자동조작을 처음 소비해야 한다.**

- 목적: 씰이 `active` 플래그를 **직접 주입**해 통과하는 **공허 GREEN 차단**.
  프레임 순서(`update_player_control` → `update_ball` → `update_lingpet`)를
  실제로 관통해야만 성립한다.
- D14의 종료 씰과 대칭: 종료는 "전이 후 다음 player-control이 자동조작을
  **보지 못한다**", 활성화는 "launch 후 다음 player-control이 **처음
  소비한다**".
- **바이퍼 조기 반환 픽스처**: `viper_player_controller:30`이 공용 컨트롤러
  진입 전에 조기 반환할 수 있으므로, 묵린 자동조작이 5캐릭 전부에서 우선하는지
  바이퍼 케이스로 단언(위 §F 감사점).
- 나머지 씰: D14 경계 4종(자연 만료·라운드 리셋·강제수납·펫 교체) 각각 +
  쿨다운 비환불·수납 중 동결·펫별 보존 + 위 전수표의 **필수 행마다** 최소
  1단언. ⚠️ **C4는 분류가 "자동"으로 바뀌었어도 씰은 필수** — "시각 효과 0인
  프레임에도 타이머 tick 지속"을 반증과 함께 단언(모듈이 `is_active()`를
  구현하지 않으면 조용히 동결되므로).

## H. 검토 상태

- ~~1. D1/D4/D6 렌더 소유권~~ → ✅ **해소**(§D 코드 선례 조사, 전부 N/A).
- ~~3. F 브리지 경로~~ → ✅ **해소**(§F, frame_controller 접촉 0건 확정).
- **남은 사용자 판단 2건 — 이 둘이 정해질 때까지 S1 구현 착수 보류:**
  1. **E1 발동 피드백** — 발동 SFX/플래시 유무(D14-2가 "이미 재생된 단발
     발동음은 취소하지 않는다"고 하여 존재를 전제하는 듯하나 명시 확인 필요).
  2. **E6** — 변신 중 펫 피격 판정 유지 여부.

## 개정 이력

- 2026-07-29 초판(Claude 작성).
- 2026-07-29 rev2 — 코덱스 교차 검토 반영:
  - **C4 필수 → 자동** (범용 `is_active()` 검사가 match보다 선행).
  - **E2 자동 → 필수** (⚠️ 초판 오분류. `get_snapshot`은 필드 순회가 아니라
    24회 명시 나열 — 실측 정정).
  - **D 블록 "판단 필요" → 전부 N/A** (코드 선례: 상태 모듈 소유 + 렌더러
    텍스처 교체). D6는 Star Coil 전용 + front-pass 결합이라 **재사용 금지**.
  - **§F 브리지 경로 확정** (frame_controller 접촉 0건, 구성 4요소,
    바이퍼 조기 반환 감사점 추가).
  - §G 씰에 바이퍼 픽스처 추가.

## 비차단 정정

계획서의 철회 주장은 **S1 선행 조건에서는 제거**됐고, 28행에 **철회 이력으로
1회 인용**만 남아 있다. 정확한 표현은 **"활성 주장 0건, 철회 인용 1건"**이며
문서 논리에는 문제가 없다(코덱스 지적 수용).
