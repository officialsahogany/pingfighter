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
**묵린도 이 패턴을 따른다 — 즉 host가 몸체를 직접 그리지 않는다(D1~D4·D6 = N/A).**
⚠️ *(rev4 정정)* 다만 **"D 블록 전부 N/A"는 틀렸다.** 몸체를 그리는 주체는 렌더러여도,
**어느 시각 키를 어떤 그리드로 그릴지 지시하는 표면(D5·D7)은 필수**다.

| D1 | `draw(:228)` fanout | **N/A** | 변신 몸체는 컴패니언 렌더러가 텍스처 교체로 그린다(위 선례) |
| D2 | `has_visible_effects(:255)` or-fanout | **N/A** | D1과 동반 |
| D3 | `has_visible_effects_for_skill(:284)` match | **N/A** | D1과 동반 |
| D4 | `suppresses_companion_body_draw(:572)` | **N/A 확정 — `false` 유지** *(2026-07-31)* | **같은 렌더러 안에서 텍스처를 교체**하므로 원본과 중복 자체가 없다. ⚠️ host가 변신체를 직접 그리고 기본 몸체를 억제하면 **z-order가 틀어진다** — host `draw()`는 전면 VFX 패스인데 컴패니언 몸체는 `lingpet_egg_runtime:1039`의 **플레이어 뒤 패스**다(주석에 "intended to run BEHIND the player actor" 명시) |
| D5 | `get_companion_cast_pose_progress(:588)` | **필수** *(rev4 정정)* | 변신 시트를 그릴 **가장 좁은 경로**. ⚠️ **rev3의 "`companion_cast`에 연결"은 오슬라이스를 낳는다 — 철회.** `skill_cast_pose_active`가 켜지면 draw context가 **`companion_puppet_control`을 먼저 선택**하고(`draw_context_builder:22~24`), 텍스처만 `companion_cast`로 폴백돼도 렌더러는 **`companion_puppet_control_{cols,rows,frame_count}`**(:100~102)를 조회한다. 메타가 없으면 애니메이터 기본값 **`SHEET_COLS 5 / SHEET_ROWS 5 / SHEET_FRAME_COUNT 25`**(`sprite_animator:7~9`)로 **6×2·12f 시트를 5×5·25f로 잘못 자른다** |
| D5a | 시각 키 = **`companion_puppet_control`** + `companion_puppet_control_cols=6` / `_rows=2` / `_frame_count=12` / `_draw_size=92` | **필수** *(rev4 신설)* | 위 오슬라이스를 막는 실제 계약. 네 값을 **함께** 지정해야 한다 |
| D5b | `should_show_cast_windup(:584)` | **자동** *(rev4 정정)* | A2 등재로 라우터가 자동 처리. **실제 필수 분기는 D5(`get_companion_cast_pose_progress`) 쪽**이다 |
| D5c | **모드 전환 Y 오프셋 계약** — per-profile **`companion_puppet_control_y_offset_delta = +6.0`** | **필수** *(rev7 정정)* | ⚠️ **정상 몸체 ↔ 변신 시트 경계에 6px 수직 팝.** 정상 몸체 `MODE_WALK` → `WALK_Y_OFFSET := -6.0`, D5a 변신 `MODE_CAST` → `CAST_Y_OFFSET := -12.0`. **둘 다 92px·동일 앵커여도 발동 순간 6px 위로 뜬다.**<br>⚠️ **rev5의 절대 오프셋 계약은 작동 불가 — 철회.** ① 실제 −12px는 **`animator:149` 내부에서 이미 적용**된다(`build_draw_rects`의 `dest`가 `get_y_offset(mode)`를 직접 가산) ② draw-context layout getter가 **음수를 0으로 절단**한다(`draw_context_builder:172` `maxf(0.0, …)`) → `-6`은 **전달조차 안 된다**.<br>**계약 = delta(양수라 절단 통과)**: draw-context가 delta를 config로 전달 → **`companion_renderer:186`의 `build_draw_rects()` 직후, `visual_key == "companion_puppet_control"`일 때만** `dest_rect.position.y += delta` → **키 없음 = 0**이라 기존 펫 완전 보존 → **animator 수정 불필요**.<br>⚠️ **아트 내부 위치로 보상 금지**(재생성마다 계약이 숨는다).<br>**씰 3레그**: ① 키 없음 = 기존 −12 유지 ② delta +6 = −6 ③ 실제 `normal→f1` / `f12→normal` 무팝 |
| D7 | `lingpet_skill_companion_surface_router.gd` 등재 | **필수** *(신설 2026-07-31)* | D5를 실제로 태우는 라우터. host의 `_companion_surface_router`가 kind→모듈 표면을 중계하므로 **여기 미등재면 D5가 조용히 빈값**이 된다. ⚠️ WIP 지도(§F)에도 추가됨 |
| D6 | `get_companion_bind_sheet_state(:1148)` | **N/A — 재사용 금지** *(rev4 재기술)* | ⚠️ 이 훅은 **Star Coil 전용**(:1145)이고 **몸체를 보스 앞 front-pass로 옮기는 의미까지 결합**돼 있다. ⚠️ **rev3의 "별도 body override/snapshot 표면을 둔다"는 철회** — D5a의 `companion_puppet_control` 경로로 해결되므로 **신규 override가 불필요**하다. 잔상·오라만 gameplay state가 직접 그리지 말고 전용 presentation renderer 또는 companion renderer 하위 레이어가 snapshot을 소비하는 구조로 |

## E. 호스트 — 부가 표면

| # | 지점 | 분류 | 근거 / 주의 |
|---|---|---|---|
| E1 | `trigger_launch_feedback(:594)` | **필수 유지** *(rev6 사용자 확정 · rev7 소유권 분리)* | 발동 SFX·플래시 채택은 **확정값 그대로 유지**한다(rev7의 "무음" 제안은 철회). ⚠️ **rev6은 SFX와 플래시 소유권을 섞었다 — 라우터 등재만으로는 "먹빛 플래시"가 구현되지 않는다.** `lingpet_skill_launch_feedback_router.gd:8` docstring이 **"launch cue selection and fallback priority only"** 이고 `trigger()`는 `_play_first(registry, &"play_*")` **오디오만** 호출한다. 반면 발동 플래시는 `lingpet_companion_skill_controller:227` `skill_state.complete_launch(origin, cooldown_seconds, flash_seconds)` **공용 경로**가 타이머를 시작하고, `companion_renderer:53~57`이 **청록**(`Color(0.24, 0.92, 1.0, …)`)으로 그린다.<br>**⇒ 3분리:**<br>**① 단발 SFX** — launch feedback router 소유. **E1 필수**<br>**② 플래시 타이머** — **기존 성공-launch 공용 경로 재사용**(신규 배선 없음)<br>**③ 먹빛 팔레트** — **renderer / config 소유**로 명시하고 **별도 씰** 추가(현재 하드코딩 청록을 스킬별로 바꾸는 작업)<br>공통 계약: 실제 발동 성공 edge에만 1회 / 차단·실패 launch에는 재생 안 함(C2) / 루프형 SFX 미생성 / 이미 재생된 단발음은 취소 안 함(D14-2). ⚠️ **가드 단계 SFX는 §E' X4대로 모듈 소유** |
| E2 | `get_snapshot(:607)` `_merge_skill_snapshot` | **필수 (재확정 2026-07-31)** | ⚠️ **초판 오분류 정정.** 필드 순회가 아니라 **`_merge_skill_snapshot`을 24회 명시 나열**한 수동 fanout이다(:609~632 실측). B1 필드 선언만으로는 **포함되지 않는다** — 한 줄 추가 필수. **"production 소비자 없음 → N/A" 제안은 철회됨**: 살아있는 사슬 = `egg_runtime.get_snapshot()` → `_build_runtime_snapshot_uncached()` → `lingpet_runtime_snapshot_builder:189` → `skill_runtime_host.get_snapshot()`. 추가로 `character_info_overlay_frame_presenter:154`가 집계본을 직접 읽어 패널에 병합한다. **레일 주 경로(per-skill `get_snapshot_for_skill_id`)와 대체 관계가 아니라 공존**이며, 집계본은 레일 fallback + 다른 HUD 소비자용이다 |
| E3 | `get_snapshot_for_skill_id(:636)` / `get_snapshot_for_kind(:640)` | **자동** | B7/B8 경유 |
| E4 | `get_launch_origin(:532)` | **N/A** | 투사체 없음 |
| E5 | `has_companion_position_override(:536)` / `get_companion_position_override(:542)` / `get_active_position_override_owner(:548)` | **N/A** | 묵린은 **플레이어 패들**을 자동조작하지 펫 위치를 스크립팅하지 않는다(D15) |
| E6 | `suppresses_companion_body_hit(:566)` | **N/A 확정 — `false` 유지** *(rev6 사용자 확정 2026-07-31)* | 묵린변신은 **무력화 창이 아니다.** 확정 계약: **기존 몸체 피격·방어 인터셉트 모두 유지 / 무적·비피격·추가 회피 효과 없음 / 변신 시트 크기와 무관하게 기존 충돌체 크기 유지 / `suppresses_companion_body_hit()`에 묵린 미등재.** 근거: 자동조작에 비피격까지 붙으면 **별도 생존 보너스가 생겨 P0 예산을 벗어난다**(D6 "추가 전투 보너스 없음"과 일치). D4와 동일 판정 |
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

*(rev7 갱신)* ⚠️ **고정 개수 표현을 쓰지 않는다** — 항목이 계속 늘어 "8파일"이 표(11행)와
어긋났다. **1차 registration 착수면(host · dispatcher · surface router · event router)은
전부 클린**이고, 브리지·카탈로그·통지·렌더 경로는 아래 목록을 개별 확인한다:

| 파일 | dirty 규모 | 성격 / 주의 |
|---|---|---|
| `battle_scene_frame_controller.gd` | **+184/−764** | ⚠️ **대형 외래 리팩터**(프레임 컨트롤러 모듈 분해 캠페인, 정산 보류 13건 목록에 등재). 여기에 묵린 브리지 헝크를 얹으면 헝크 분리가 사실상 불가능 |
| `smasher_player_controller.gd` | **+9/−6** | 소규모. 헝크 분리 가능 |
| `battle_update_player_control_deps_builder.gd` | **+1/−0** | 거의 클린 |
| `lingpet_catalog.gd` | **+1/−1** | 소규모 |
| `lingpet_skill_companion_surface_router.gd` | **클린** | D7 대상 |
| `paddle_bounce_event_router.gd` | **클린** | §E' X1~X3 대상 |
| `lingpet_skill_runtime_host.gd` | **클린** | *(rev5 추가)* B·C·D·E 대부분 |
| `lingpet_skill_dispatcher.gd` | **클린** | *(rev5 추가)* A 전체 |
| `lingpet_egg_runtime.gd` | **클린** | *(rev5 추가 — 누락이었다)* **D15 predicate** 노출 + **§E' X1 통지 전달** |
| `lingpet_skill_launch_feedback_router.gd` | **클린 (확정 대상)** | *(rev6)* E1 발동음 **채택 확정**으로 조건부 → **확정 대상** |
| `character_info_overlay_lingpet_texture_loader.gd` | **클린** | *(rev9 추가 — Y1 필수)* `PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID`에 백린 미등재 → 패널이 정적 아트로 폴백 |
| `lingpet_acquire_cutin_overlay_host.gd` | **클린** | *(rev9 추가 — Y2 조건부)* cutin/dismiss가 기본 규격과 다를 때만 override 등재 |
| `lingpet_companion_draw_context_builder.gd` | **클린** | *(rev7 추가 — D5c 소유자)* **delta를 config로 전달**하는 지점. `_get_visual_layout_value:172`가 음수를 절단하므로 **양수 delta로 실어야** 한다 |
| `lingpet_companion_renderer.gd` | **클린** | *(rev7 추가 — D5c 소유자)* **`:186` `build_draw_rects()` 직후** `visual_key == "companion_puppet_control"`일 때만 `dest_rect.position.y += delta`. ⚠️ E1-③ **먹빛 팔레트**(현재 `:53~57` 청록 하드코딩)도 이 파일 소유 |
| `game_audio.gd` | ⚠️ **+1807/−2055** | *(rev5)* **신규 전용 SFX를 고르면 여기까지 범위가 확대**된다. 대형 외래 WIP라 헝크 분리가 어렵다 — **기존 SFX 재사용이면 접촉 0건**(E1-① 권고) |

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

나머지 3파일(*(rev5 실측 갱신)* `smasher_player_controller` **+9/−6** /
`deps_builder` **+1/−0** / `lingpet_catalog` **+1/−1**)은 헝크 분리로 진행 가능.

⚠️ *(rev5 정정)* **"S1 전체 착수면이 클린"이 아니다.** 정확히는
**1차 registration 착수면 4파일(host · dispatcher · surface router · event router)이
클린**이고, 브리지·카탈로그·통지 배선은 소규모 dirty 파일과 공유하며,
*(rev8 갱신)* ⚠️ **`game_audio.gd` 범위 경보는 해제됐다** — ㉯가 **발동·단계 진입 모두
기존 `play_active_item()` 재사용**으로 닫혔으므로 **신규 음원 0 · `game_audio.gd` 접촉 0**이다.

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
- **E1 발동 피드백 씰** *(rev6 신설, 사용자 지정)*: **성공 발동 1회 / 차단된
  발동 0회.** `is_launch_blocked` true 경로와 실패 launch에서 라우터 호출이
  0인지 단언하고, 반증 1회(차단 경로에서도 호출되게 임시 변경 → RED).
- **E6 피격 유지 씰** *(rev6 신설, 사용자 지정)*: **변신 전후 동일 궤적에서
  피격·방어 결과 동일.** 같은 공 궤적을 변신 전/중에 각각 흘려 몸체 피격과
  방어 인터셉트 결과가 일치하는지 단언(충돌체 크기 불변 포함).
- **바이퍼 조기 반환 픽스처**: `viper_player_controller:30`이 공용 컨트롤러
  진입 전에 조기 반환할 수 있으므로, 묵린 자동조작이 5캐릭 전부에서 우선하는지
  바이퍼 케이스로 단언(위 §F 감사점).
- 나머지 씰: D14 경계 4종(자연 만료·라운드 리셋·강제수납·펫 교체) 각각 +
  쿨다운 비환불·수납 중 동결·펫별 보존 + 위 전수표의 **필수 행마다** 최소
  1단언. ⚠️ **C4는 분류가 "자동"으로 바뀌었어도 씰은 필수** — "시각 효과 0인
  프레임에도 타이머 tick 지속"을 반증과 함께 단언(모듈이 `is_active()`를
  구현하지 않으면 조용히 동결되므로).

## H. 검토 상태

*(rev4 재편 — 범위를 둘로 분리한다. 섞여 있어서 "④만 차단"처럼 잘못 요약됐다.)*

### H-1. runtime_kind 전수표 범위 — ✅ **종결** *(rev9 정정 — rev7 잔재 제거)*

- ~~D1/D4/D6 렌더 소유권~~ → ✅ §D 코드 선례 조사(D1~D4·D6 N/A, D5·D5a·D7 필수).
- ~~F 브리지 경로~~ → ✅ §F, `battle_scene_frame_controller` 접촉 0건 확정.
- ~~E1 발동 피드백~~ → ✅ **필수 확정** *(사용자 확정 2026-07-31)*: 발동
  SFX·플래시 **채택**. 성공 edge 1회 / 차단·실패 0회 / 루프 없음 / 이미 재생된
  단발음 취소 없음 / 공용 라우터 관통. 소유권 분리 유지(발동 단발음=라우터 /
  가드 단계 SFX=모듈, §E' X4). ⇒ **`lingpet_skill_launch_feedback_router.gd`가
  WIP 지도의 확정 대상**이 된다(§F "조건부 대상" → 대상).
  ⚠️ **㉯에 남는 것은 "가드 단계 임계값"뿐** — 발동음 유무는 여기서 닫혔다.
- ~~E6 변신 중 펫 피격~~ → ✅ **N/A 확정, `false` 유지** *(사용자 확정
  2026-07-31)*: 피격·방어 인터셉트 유지 / 무적·비피격·회피 없음 / 충돌체 크기
  불변 / 미등재. 근거 = 자동조작에 비피격까지 붙으면 **P0 예산 초과**
  (D6 "추가 전투 보너스 없음"과 일치). D4와 같은 판정이며 둘 다 `false`.

⇒ ✅ *(rev8)* **H-1 종결.** E1-③ 먹빛 팔레트를 아래 실행 가능 계약으로 닫았다.

### E1-③ 먹빛 플래시 팔레트 계약 (rev8 확정)

1. 묵린변신 **active-skill 데이터**에 `companion_skill_flash_style: "mokrin_ink"` 추가
2. `visual_surface["active_skill"]` → **egg runtime** → **draw-context config**로
   **문자열** 전달
3. `companion_renderer`는 **`"mokrin_ink"`일 때만** 먹빛 팔레트, **키 없음이면 기존
   청록 유지**(`:53~57` `Color(0.24, 0.92, 1.0, …)`)

> ⚠️ **`visual_layout` 경로에 넣지 말 것.**
> `lingpet_catalog.get_visual_layout_value(...) -> float`는 **float 전용**이다
> (`:1281`). 팔레트 **문자열**을 그 경로로 보내면 조용히 0.0이 된다.
> ⇒ D5a/D5c의 숫자 메타(`_cols` / `_rows` / `_frame_count` / `_draw_size` /
> `_y_offset_delta`)와 **다른 채널**을 써야 한다.

**씰 3레그**: ① 기본 펫 청록 불변 ② 묵린 **성공 발동** 먹빛 ③ **차단된 발동은
플래시 없음**(C2 `is_launch_blocked` true 경로)

### H-2. 에셋 · 연출 결정 범위 — **㉱ 1건만 미결** *(rev8 정정)*

㉮㉯㉰는 확정됐다. **실제로 열린 것은 ㉱(정상 백린 몸체) 하나**다.

| # | 결정 | 비고 |
|---|---|---|
| ~~㉮~~ | ✅ **확정 (rev7)** — **변신 재생** | **0.60초 동안 progress를 0→1로 진행**하고 **이후 f12를 유지**한다. 만료 시 **역재생 없이** 정상 몸체로 복귀. **자동 가드는 발동 즉시 시작**하며 연출 완료를 기다리지 않는다.<br>⚠️ **"나머지 정확히 4.40초"라고 쓰지 말 것** — 프레임 식이 `clampi(int(progress * frame_count), 0, max_frame)`(`sprite_animator:91`)이라 f12(index 11)는 progress ≥ 11/12 = 0.9167, 즉 **약 0.55초부터** 시작한다. 실제 동작과 어긋난다 |
| ~~㉯~~ | ✅ **확정 (rev8 — 음원까지 닫힘)** — **가드 단계** | `stage = min(guard_count, 3)`, 임계값 **1 / 2 / 3회**, 비율 `stage / 3.0`. **각 단계 최초 진입에만 SFX 1회**, **같은 카운트에서 재발동 금지**.<br>**⇒ 음원 확정: 발동음·단계 진입음 모두 기존 `play_active_item()` 재사용.** **신규 음원 0 · `game_audio.gd` 접촉 0**(§F 범위 경보 해제). ⚠️ rev7이 발생 규칙만 정하고 **실제 SFX 메서드를 안 정해** 미완이었던 부분을 여기서 닫는다.<br>⚠️ rev7 초안의 "발동음 무음 → E1 N/A"는 **철회** — E1은 rev6 사용자 확정값 **필수** 유지 |
| ~~㉰~~ | ✅ **확정 (rev7)** — **카드 범위** | **묵린변신 카드 1장만** S1 runtime에 제작·배선. **안장 카드는 S7까지 제작·프리웜·획득 노출 모두 보류** |
| ㉱ | **정상 백린 몸체용 runtime 시트** | ⚠️ **변신 해제 후 돌아갈 승인된 기본 몸체가 없다.** 현재 승격된 백린 자산은 변신 PNG·manifest·import뿐이고 walk/idle 계열이 전무하다 |

### ㉱ 생산 배치 계약 (rev8 신설) — **앵커를 두 계열로 분리한다**

⚠️ **"승인 f1 하나를 공통 앵커로 전 자산 일괄 생성"은 금지.** 후면 f1을 정면 Live2D의
단독 앵커로 쓰면 **카메라 회전 + 몸체 재설계**가 다시 발생한다(v1 폐기 사유와 동일).

| 계열 | 앵커 | 산출물 |
|---|---|---|
| **후면 runtime 몸체** | **팔레트 = 업로드 원화**(AutoSprite pose `Original`) / **형상·실루엣 = 변신 시트 f1** | **S1 산출물은 `companion_idle` PNG 1종뿐**이고 `move_left` / `move_right` / `walk` / `strike` / `cast`는 **전부 그 idle에 별칭**(각 1×1·1f 메타) |
| **정면 획득·클릭** | **원본 `백린_변신전` 정면 3/4**(별도 베이스 포즈) | `cutin_art` · `cutin_anim` · `cutin_dismiss_anim` · `click_reaction_anim` · **`companion_click_reaction_anim`** — 애니 계열은 **같은 AutoSprite `first_frame_pose_id` 공유** |

### 생성 전 확정 필수 — 규격표 (rev9)

⚠️ **아래가 확정되기 전에는 AutoSprite 크레딧을 쓰지 않는다.** 그리드/프레임 수를
모른 채 뽑으면 무효 산출이 된다(변신 시트에서 이미 겪었다).

**후면 계열**

✅ **S1 확정 (rev12). 실제 후면 산출물은 `idle` PNG 단 1종이다.**
`move_left` / `move_right` / `walk` / `strike` / `cast`는 **전부 그 idle PNG에 별칭**하고
각 키마다 **1×1·1f 메타**를 명시한다 — 즉 S1 후면 계열은 **정적 폴백**이다.

⚠️ 이전 rev10의 "`idle` + `L` + `R` + `strike` 4종"은 **폐기**한다. 이동 시트 생성이
3회 연속 실패했고(아래 실패 기록), strike는 25프레임이라 QA 면적이 더 커서 같은
위험에 노출된다. **실제 locomotion 시트와 5×5·25f strike는 후속 슬라이스로 이월**한다.

### 후면 계열 생성 규율 (rev11 신설)

⚠️ **"같은 prompt family면 정합이 보장된다"는 과한 표현이다 — 낮춘다.** 독립 생성
사이에는 **앵커·크기 드리프트가 여전히 가능**하다. 따라서:

1. **승인된 idle 프레임을 후면 계열의 canonical pose로 고정**하고
   **source job / pose ID · 원본 프레임 번호 · SHA**를 manifest에 기록한다.
2. 가능하면 **같은 rear character ID와 idle pose ID를 L/R/strike에 재사용**한다.
3. **프레임별·시트별 재중앙 금지.** idle에서 확정한 **scale / baseline을 가족 전체에
   동일 적용**한다.
4. **순차 승인 + 생성 순서**: idle 승인 전에 이동 시트를 생성하지 않는다. 이동은
   **`_move_right`만 네이티브 생성**하고 **`_move_left`는 승인된 right의 per-cell
   수평 반전으로 파생**한다(2026-08-01 확정). ⚠️ rev11까지 적혀 있던 "L 생성 → L
   승인 후 R 생성"은 **폐기** — 방향이 반대이고, L을 따로 생성하면 결정적 미러가
   막아주는 장식 오염 위험에 다시 노출된다.
5. **프롬프트는 동작만 지정한다.** 장식·보석·색을 **어떤 형태로도** 언급하지 않는다
   — 색 명시(v2 353px) · **부정문**(v5 384~406px) · **닫힌 열거**(v6 2016px) 세 전략이
   전부 없던 대형 청록 장식을 키웠다. 형상 서술(꼬리 구조 등)은 유효하다.

> idle 산출 경로는 **(a) 짧은 AutoSprite 시트에서 1프레임을 결정론적으로 추출**이다.
> AutoSprite-derived 시트의 결정론적 축소는 허용된 후처리다.

### ⚠️ strike 프레임 예산 계약 (rev11 — **크레딧 사용 전 필독**)

런타임에서 **실제 보이는 범위는 index 18~24(f19~f25)뿐**이고 **index 22(f23)가
impact**다(`sprite_animator:67~70` `begin_strike`가 `clampi(start_frame,
STRIKE_START_FRAME=18, SHEET_FRAME_COUNT-1=24)`, 재생은 `strike_start_frame` →
`last_frame`). **25프레임 전체에 동작을 균등 배분하면 안 된다.**

| 프레임 | 역할 |
|---|---|
| f1~f18 | **사용되지 않는** 안전한 중립 / 선행 프레임 |
| f19~f22 | 준비 → 접촉 직전 |
| **f23** | **명확한 충돌 정점(impact)** |
| f24~f25 | 후속 · 정착 |

| 키 | 그리드·프레임 | 계약 |
|---|---|---|
| `companion_idle` | **1×1 · 1f (정적)** | S1에서는 정적 1장. ⚠️ **새 AutoSprite rear-idle 포즈에서 만든 production export여야 하며 변신 f1 크롭 재사용은 금지.** 실제 idle 순환과 renderer 확장은 **후속 슬라이스로 분리**(현재 `IDLE_FRAME := 12` 고정이라 저프레임 idle은 루프가 아니라 마지막 프레임 정지가 된다 — `sprite_animator:10,106~110`) |
| `companion_move_left` / `_move_right` / `companion_walk` | **S1 한정: 각각 1×1 · 1f** (`cols=1` / `rows=1` / `frame_count=1`), draw **92** | ⚠️**S1 한정 정적 활주 폴백이며 "이동 애니메이션 완성"이 아니다.** 세 키 모두 **승인된 `companion_idle` PNG에 별칭**하고 **각 키마다 1×1·1f 메타를 명시**한다(경로 별칭만 하고 메타를 빠뜨리면 25f 기본값으로 슬라이스돼 깨진다). 실제 locomotion은 **후속 슬라이스**로 남긴다.<br>런타임 안전성 확인: `_resolve_frame_count`가 `clampi(raw, 1, cols*rows)`이라 1×1이면 frame_count가 1로 클램프(`sprite_animator:185~190`); 걷기 프레임 3경로 전부 0으로 수렴(`clampi(IDLE_FRAME,0,0)=0`, `int(walk_phase)%1=0`, `int(elapsed*fps)%1=0` — `:110~116`); 텍스처 캐시가 **경로 키**라 세 별칭이 중복 로드되지 않음(`lingpet_visual_texture_cache:54`). 선례: 루나비 `companion_cast` → `lunabi_companion_strike.png`.<br>**후속 locomotion 슬라이스가 지켜야 할 계약**(2026-08-01 확정, 폐기 아님): `_move_right`만 **네이티브 생성**하고 `_move_left`는 **승인된 right의 per-cell 수평 반전**으로 파생한다. 근거 ① 백린 꼬리는 중앙에서 나온 유연한 동작 부속이라 해부학적 고정 좌우 소품이 아니다 ② 코요라·빠나몽·오니마루 현행 3쌍 전부 per-cell 미러 RGBA 완전 일치 ③ **결정적 미러는 장식을 추가할 수 없다**. ⚠️**전체 시트 flip 금지** — 다행 시트는 행 내 열 순서가 뒤집혀 걸음이 `3,2,1,0,7,6,5,4`로 깨지며 알파·임포트·헤드리스 검사를 전부 조용히 통과한다(`sprite-generation` §13.1.1). 검증 = `left[i] == hflip(right[i])` RGBA 동일 **AND** 전체-flip 가설 불일치, 둘 다 단언.<br>**이동 시트 생성 실패 기록**(재시도 전 필독): `iso_walk_northeast` R1 = 얼굴 8/8 노출·사족보행체·가슴 보석 471~740px / `iso_walk_up` R2 = 가슴 보석 1011~1153px 전 프레임 / `iso_walk_up` + `first_frame_pose_id` ④ = 가슴 보석은 제거됐으나(1011~1153px → 대부분 0) **팔레트 8/8 초과**(body ΔE 6.60~8.45 · gate 1.5, gold 3.37~6.55 · gate 2.5) + **f3~f6 strict-rear 회전**(rearLock 진단 86/146/49/57, f4가 최악) + **f4 꼬리고리 폭 게이트 실패** + **f6 신규 비부착 장식 + 토크 높이 실패** + **f3·f6 세 번째 뿔캡**(추가 금색 블롭 421px·490px, 정상 2개). 포즈 고정 유무가 **펜던트 ↔ 그레이딩** 교환으로 관측되나 kind·프롬프트가 함께 달라 **동일 조건 대조가 아니므로 기전 미확정** — ④가 통과하지 못했으므로 "시작 프레임 재해석이 원인"이라는 해석도 성립하지 않는다.<br>⚠️**rearLock 수치는 진단 전용**이다. 깨끗한 이동 **양성** 대조군이 없어 임계값을 세울 수 없다(음성 모집단만으로 임계를 정하면 순환 검증). 기록: v1 idle 9~20 / 변신 f1~f7 18~32 / R1 93~498 / R2 23~130 / ④ 34~146. 후속 슬라이스에서 깨끗한 이동 시트가 나오면 **그 시트를 양성 대조군으로 삼아 사전에** 임계를 고정하고, 그 임계로 같은 시트를 소급 승인하지 않는다 |
| `companion_strike` | **S1 한정: 1×1 · 1f** (`companion_strike_cols/rows/frame_count = 1/1/1`, `companion_strike_draw_size = 92`) | ⚠️**S1 한정 정적 타격 폴백.** 승인된 `companion_idle` PNG에 별칭한다. **1f에서는 안전하다** — `get_strike_frame()`이 18~24를 반환해도 `get_source_rect()`의 `safe_frame = clampi(frame, 0, frame_count-1)`이 **전부 0으로 클램프**하고 `col=0 % 1=0` / `row=floori(0/1)=0`이 되어 전체 텍스처를 가리킨다(`sprite_animator:169~174`). 즉 rev11의 "별칭 불가 / 8f면 상시 마지막 프레임 클램프"는 **1×1·1f에는 해당하지 않는다**(8f 별칭에서만 성립).<br>**타격 신호**: `WALK_Y_OFFSET=-6.0` → `STRIKE_Y_OFFSET=-12.0`(`:14,23`) 차이로 타격 중 **6px 위로 뜨는 홉**이 생긴다. 지속은 `play_frames × STRIKE_FRAME_TIME(0.036) + STRIKE_FOLLOW_HOLD(0.12)`, `play_frames = max(0, 24 − start)`이고 실전 start 18~22이므로 **0.192~0.336초**. 이 홉을 **S1의 의도된 최소 타격 신호로 승인**한다 — 신규 렌더 코드도 추가 크레딧도 필요 없다.<br>**후속 슬라이스**: 실제 5×5·25f strike는 locomotion과 함께 이월한다. 그때는 오니마루·라호세트 선례대로 **AutoSprite 25f 원본에서 동작 프레임을 골라 runtime 18~24에 재배치**하고 **impact를 22에 정렬**한다(위 프레임 예산 계약 표 참조) |
| `companion_cast` | **`companion_idle` 별칭** + 1×1·1f 메타 | 묵린변신 중에는 `companion_puppet_control`이 **먼저 선택**되므로 충돌하지 않는다(`draw_context_builder:21~24`) |

**정면 계열**

| 키 | 그리드·프레임 | 비고 |
|---|---|---|
| `cutin_art` | 정지 1장 | `REQUIRED_VISUAL_KEYS` 필수 |
| `cutin_anim` | **8×4 · 32f** | 획득 오버레이 기본값(`acquire_cutin_overlay_host:29~32`). 다르면 **펫별 override 등재 필수** |
| `cutin_dismiss_anim` | **권고: `click_reaction_anim` 98f 재사용 + Y2 override** | *(rev10)* 별도 25f 생성을 줄이고 **긴 dismiss에서 저프레임 재생을 피한다**. ⚠️ **별도 5×5·25f를 유지한다면 dismiss 지속시간과 유효 FPS를 함께 확정**해야 한다 |
| `click_reaction_anim` | **14×7 · 98f** (풀사이즈) | *(rev10 명시)* 패널 / 획득용. 이 시트가 `companion_click_reaction_anim` 축소본의 원본이다 |
| **`companion_click_reaction_anim`** | **14×7 · 128px 셀 · 98f** | ⚠️ **별도 키다.** 전투 중 교감은 이 축소본을 요구하고, **텍스처가 없으면 `try_begin_companion_click_reaction`이 조용히 false**를 반환한다(`click_reaction_state:9~12`, `egg_runtime:3262` 부근). 풀 시트에서 **결정론적으로 축소**해 만든다 |
| **묵린변신 스킬카드 ×1** | — | ㉰. **없으면 프리웜 계약이 닫히지 않는다** |

**정면 canonical 확정 (2026-08-04)**: 원화 = `백린_변신전_magenta.png`(a07, 1323×1189,
SHA `9E8F6BA2AB7FBF3421CE6ED68194FCE9896FEDD19EAC4279E05437ECE6E62BB6`). AutoSprite
정면 캐릭터 = `cmsdkmnpe002rwf12lzzjd0js`(Baekrin Front Cutin Anchor 20260804 v1,
업로드 소스는 후면과 동일 규격 512×512 마젠타·최대변 384px 중앙 배치), 공유
`first_frame_pose_id` = **`cmsdkmnqc002twf12klkrd56r`**(`Original`, sourceType upload).
`cutin_art`는 초기 평가본 ck_a07이 **하드알파(semi 0%)+마젠타 프린지 371px**로 출하
관례(마리보·루미온 소프트매트 ~7%)에 미달 — a07에서 소프트매트 재누끼 필요(승격 시점 작업).

**정면 cutin_anim 32f probe 실패 기록 (2026-08-04, R1 — 재시도 전 필독)**:
32f·512셀·custom kind·pro 티어·removeBg ultra·포즈락 첫/끝=`Original`·모션 전용
프롬프트("고정" 명시 포함)로 1회 생성(`cmsdkqxok001s1xudosof9r80`). 기계 레그는 전부
통과(가장자리 접촉 0/32 · 첫/끝 심 중심 Δ0.33/0.16px · 셀 내 프레이밍 유지)했으나
**콘텐츠 3중 실패**: ① **f15~f27 몸체 완전 회전**(측면→후면→복귀 턴테이블 — 포즈락은
첫/끝만 구속하고 중간 방향은 자유) ② 팔레트 그레이딩 드리프트(512 소스 기준 body dE00
f1부터 9.70·전 구간 3.3~9.9 / gold 최대 8.2·게이트 1.5/2.5 — 후면 ④와 동일 기전:
body가 녹황 틴트 a +1.7→−4.8, b +3.9→+10.4) ③ 질감 단순화(비늘·필리그리 → 양털형 컬,
꼬리 사슬이 분홍 구슬로 변형). ⚠️jade 블롭 카운트는 청록 눈이 지배해 눈감김 프레임에서
0이 된다 — 펜던트 검사로 쓰지 말 것. 교훈: **후면과 동일하게 idle-kind만 깨끗했던 패턴**
(v1 iso_idle_up 유일 청정 vs custom 계열 전멸)이 정면에서도 재현될 가능성 — 다음 시도
후보는 ① kind=`idle`(+포즈락) ② 모션 축소("호흡만") ③ 실패 시 팔레트만 결정적 colormatch
복원(76c3f3c12 선례, 단 회전은 색보정으로 못 고침). 크레딧: 10 소모, 350 잔여.

**정면 cutin_anim 32f R2 기록 (2026-08-04, kind=idle 단일 변수 재시도 — 사용자 사전
고정 게이트로 판정)**: R1에서 kind만 `custom`→`idle`로 변경(캐릭터·pose락·32f·512·pro·
loop·removeBg ultra·프롬프트 동일), 시트 `cmsdltx9300a4wf12poimqrbi`. **회전 축은 완전
해소**: 32/32 정면 3/4 유지·측면/후면 0프레임(f4·f27은 눈감김), 사족 유지, 얼굴 신호
붕괴 창 없음, 인접 중심 드리프트 최대 2.3px(R1 8.9), 심 Δ0.12/0.07px, 가장자리 0/32 —
**후면 트랙의 "idle-kind만 깨끗" 패턴이 정면에서 인과로 확정**(단일 변수 대조). 잔여
실패 2축: ① 팔레트 전역 그레이딩(512 소스 기준 body dE00 최악 7.64 / gold 7.42 —
게이트 1.5/2.5) ② **국소 장식 드리프트**: 꼬리 사슬의 금 링크 3개가 분홍 구슬 2개로
변형(전 프레임, jade 종단 구슬은 유지·금 베젤 소실) + 귀 확대·분홍 내이 강조. 비늘·
필리그리·뿔캡2·목걸이+jade 펜던트·다리 커프·꼬리 고리는 형태 유지. 사전 고정 판정
규칙("방향·자세·형상·질감 전부 통과 + 팔레트만 실패일 때만 전역 colormatch 허용,
국소 마스크 금지")에 따르면 사슬 변형은 colormatch로 복구 불가한 형상 결함 → **R2
기각, 추가 생성 없이 중단·보고**(조기 기각 원칙). ⚠️얼굴 신호 검출기(teal+pink)는
R1 회전 창에서 teal 45~244로 붕괴함을 교정 확인 — 단 눈감김과 겹쳐 진단 전용.
크레딧 10 소모, 328 잔여.

**정정 (2026-08-04, R2 기록의 "인과 확정" 표현)**: R2는 명시 파라미터로는 kind 하나만
바꿨으나 생성 난수/latent seed가 고정되지 않았으므로 엄밀한 단일변수 인과 실험이 아니다.
정확한 표현 = "idle kind가 방향 고정에 효과적이라는 **강한 재현 증거**를 얻었으나, 독립
확률 생성 1회씩의 비교이므로 **인과 확정은 아니다**." (2447d370e 본문은 amend하지 않고
이 정정이 우선한다.)

**정면 cutin_anim 32f R3 기록 (2026-08-04, 앵커 v2 + idle 재실행 → 경로 중단)**:
앵커 약신호 가설 검증을 위해 업로드 앵커를 결정적으로 재구축(a07 네이티브 해상도 키 제거
— 순수 마젠타 색거리<120 강화 키로 스펙클 원천 제거(전경 성분 정확히 1) — 경계 밴드 2px
마젠타 시그니처 한정 despill 6,356px — premultiplied-alpha Lanczos 축소 — 최종 #FF00FF
재합성, 콘텐츠 폭 384→448·여백 32/54px, SHA `FE3DE49F…`). 업로드 전 1:1 검사에서 금 링크
3개·금 베젤 분리 판독 합격. 새 캐릭터 `cmsdmbvkj00dtwf1201msizn6`(v2) / pose
`cmsdmbvld00dvwf122dcal39c`로 R2 동일 조건 idle 32f 1회(`cmsdmebih00fdwf12xcm4t2kp`).
결과: 방향 32/32 정면 3/4·사족 유지·가장자리 0/32·심 Δ0.98/1.20px·얼굴 신호 붕괴 없음,
정체성 인상도 R2보다 개선 — 그러나 **꼬리 사슬이 또 변형**: 포즈락된 f1조차 분홍 구슬
2개+무베젤 jade, f16 분홍, f24만 금 링크 근사(프레임 간 분홍↔금 요동 = 루프 깜빡임 결함
추가). 팔레트도 잔존(body 최악 6.91/gold 7.17). **판정 = 사전 고정 규칙("새 앵커에서도
사슬이 구슬로 바뀌면 추가 룰렛 없이 중단")에 따라 이 생성 경로 중단.** 교훈: 입력 신호
강화로도 재현됐으므로 약신호 단독 원인 가설은 기각 — 512셀에서 사슬 획폭 ~3px급 미세
장식은 이 비디오 생성 경로가 구조적으로 재해석한다(포즈락 프레임도 재렌더라 예외 아님).
크레딧 10 소모, 318 잔여. 다음 결정(사용자 몫): 국소 결정 보정 예외 승인 / 사슬 없는
canonical 재정의 / 대체 생성 경로 — 어느 것도 자동 진행하지 않는다.

**정면 cutin_anim 자산 경로 probe 기록 (2026-08-04, create_asset→animate_asset→raw
video 직접 추출 — 사용자 계약 이행)**: 앵커 v2를 고정 자산 `cmse1chdh00af5etbdm1ep97e`
로 업로드, pro·4s·loop·removeBg ultra(반환 시트 미승격)·지정 프롬프트(장식 미열거)로
1회 생성(job `wf_888e7630`, video 640×640·24fps·97f). **raw videoUrl에서 고정 변환
추출**: 결정적 픽 `floor(i·97/32)`, 전 프레임 동일 640→512 Lanczos 1회, 전역 배경
추정 1벌(전 프레임 코너 합동 median = (219,29,203) — 비디오가 마젠타까지 그레이딩한
증거), 단일 알파 램프(D0=60/D1=170)+unmix, 프레임별 재중심·재스케일 0. 시트 SHA
`1FC15467…`. **구조 게이트 전 항목 통과**: 정면 3/4 32/32·사족 32/32·가장자리 0/32·
중심 스팬 5.5/6.9px(전 라운드 최소)·인접 최대 2.0px·심 Δ0.09px·**사슬 = 전 32프레임
금 링크(분홍 치환 0·분홍↔금 깜빡임 0)·금 베젤+jade 32/32·신규 비부착 장식 0**.
주의점 2건: ① 링크 계수가 대부분 3이나 일부 프레임에서 최상단 링크가 고리 매듭에
융합돼 2로 판독(획폭 한계의 해상 요동, 구슬 치환 아님 — 최종 판단 사용자) ② 눈감김
2회(f4, f22~25 — 프롬프트는 1회). **팔레트**: 원시 body 최악 8.80/gold 8.51. 전역
colormatch 시도 3종 — ⑴ 대각 Lab affine(IRLS, 76c3f3c12 방법) → body 3.63/gold 5.40
⑵ Lab 3×3 교차행렬 → 앵커 과적합·jade 9.51 폭주로 폐기 ⑶ f1↔앵커 분포대응 단조
LUT → f1 0.94~2.43이나 f4+ 5.1~6.5. ⭐**핵심 발견: 드리프트가 시간적 비정상** —
비디오 모델이 시드 프레임(충실)에서 멀어지며 2차 그레이드로 이탈(f1~f3 충실, f4+
안정 이탈). 즉 "전역 계수 한 벌" 제약 하에서는 게이트(1.5/2.5) 수렴이 구조적으로
불가; 최선 절충 = ⑴(SHA `5E77F9FC…`). 육안: 절충판은 원화 근접, 루프 랩 심(f32→f1,
~4dE)은 몽타주 스케일 식별 불가. 크레딧 10 소모, 308 잔여. 판정 대기(사용자):
ⓐ 수치 게이트 고수 → 팔레트 기각(단 "사슬 변형 시 종료" 조건과는 다른 실패 축)
ⓑ 육안 승인으로 절충판 수용 → 8×4 재패킹·승격 절차 진행 ⓒ **프레임별 균일(공간
전역·국소 마스크 없음·알파 불변) 시간 보정 예외 승인** — 비정상 드리프트의 기술적
정답이나 "프레임별 계수 금지" 조항이라 명시 예외 필요.

**ⓒ 조건부 승인 이행 기록 (2026-08-04, 2상태 저차원 모델 — 에스컬레이션 조항 발동)**:
P1 재키잉 완료 = keyed_v2(SHA `BC6C36F1…`), 계약 그대로 프레임별 물리 키잉(dom=min(R,B)−G,
프레임별 dom_bg·bg_med full unmix, 픽·640→512 변환은 전 프레임 동일). dom_bg 궤적
203→(f8) 169~170 안정→(f30~32) 171→176 복귀 — 사용자 독립 계산과 일치, 루프 폐합이
시드 그레이드로 되돌아가는 형태라 2상태+궤적 보간 모델이 데이터와 정합. 2상태 대각
Lab affine(보간 가중 = 궤적만) 구현: IRLS 미니맥스 적합은 소수 앵커 퇴화(a-gain 2.14)로
폐기, 순수 가중 LSQ(steady 50앵커)+시드는 gain 고정·오프셋만 재적합으로 정상화.
**결과**: ⑴ 고정-마스크 계측(보정 전 픽셀 집합 유지) gold 32/32 PASS(최악 2.01) ·
body 30/32(f6 1.65 / f32 1.63만 게이트 1.5 초과) ⑵ 재분류-마스크 계측은 gold 22프레임
FAIL(최악 5.20) — a-gain 1.89가 HSV 마스크 소속을 이동시키는 계측 정의 문제
⑶ **jade 홀드아웃 ~24 폭주 — 눈이 과채도 청록으로 팝(육안 확정)** ⑷ 펌핑 진폭
2.68→3.63·인접 델타 소폭 악화 ⑸ 엣지 핑크 프린지 증폭. **구조 진단**: 비디오 그레이드는
재질별 채도 압축(body Δa −3~−6 vs gold Δa −8~−12)이라 두 앵커를 만족하는 대각 affine은
a-gain ≈1.9가 강제되고, 고채도 색(jade·핑크 프린지)에 과확장이 전가된다 — 승인된 모델
클래스의 구조적 한계이며 적합 기술 문제가 아님. 계약 조항("저차원 모델로 게이트 미달 시
자유도 증설 금지·재판정")에 따라 32벌 독립 affine으로 가지 않고 중단·보고. 판정 대기:
계측 정의 확정(고정-마스크 채택 시 gold 전 통과·body 2프레임 0.13~0.15 마진 초과) /
채도 의존 보정(새 모델 클래스 = 별도 예외 사안) / 이 축 기각. 산출물 SHA: colormatch
v2b `C550BEDC…`.

**정면 팔레트 축 최종 기각 (2026-08-04, 사용자 3분 판정 이행)**: ① 계측 정의 = 고정
마스크 정식 채택(재분류는 순환 계측 — 진단 전용) ② v2b 기각 확정 ③ 채도 의존 제한
모델(q(C*) 단일 램프·knot≤2·전 프레임 동일) 1회 승인 + **C* 구간 사전 계측에서 겹치면
적합 시도 없이 즉시 축 기각** 조건. **이행 결과**: 재현성 P1 해소 — 최종 절차를
`color_match_asset32_final.py` 한 스크립트로 통합, keyed_v2 입력 SHA 단언 + v2b 출력
`C550BEDC…` **byte-identical 재현 확인**(폐기된 IRLS 경로가 담긴 구 스크립트 대체).
사전 계측(keyed_v2, 32프레임 풀링, p5~p95): body C* 5.2~16.0 / **jade 17.1~32.9** /
**gold 23.3~63.0** / 마젠타 에지 잔여 = **0px**(물리 unmix가 완전 제거, 풀 자체 공집합).
→ **gold와 jade가 23.3~32.9에서 겹치고, jade 중앙값(24.6)이 gold 중앙값(41.7) 아래** —
감쇠 램프로 jade를 보호하면 gold 하위 사분위가 미보정되고, body(≤16)까지 보정하려면
비단조 3굴절이 필요해 승인 모델(단일 램프) 밖. 사전 계측 조건 발동 → **적합 시도 없이
정면 팔레트 축 기각·종결**(affine→램프→LUT 자유도 증설 금지 확약 준수). 보존되는 구조
성과 = 자산 경로 keyed_v2(강체 계약 전 통과: 사슬 금 32/32·치환 0·마젠타 에지 0·중심
스팬 5.5px). 정면 cutin의 팔레트 해법은 생성-후-보정이 아닌 다른 축(canonical 단순화 /
별도 강체 레이어 예외 / 대체 생성원)에서 사용자 기획 결정으로 재개한다.

**추가 fanout (rev9 신설)**

| # | 지점 | 분류 | 비고 |
|---|---|---|---|
| Y1 | `character_info_overlay_lingpet_texture_loader.gd:6` `PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID` | **필수** | 현재 6펫만 등재돼 있고 **백린이 없다** → 그대로면 패널이 `click_reaction_anim` 대신 **정적 아트로 폴백**한다 |
| Y2 | `lingpet_acquire_cutin_overlay_host.gd` `CUTIN_ANIM_*_OVERRIDES` | **조건부** | cutin/dismiss가 기본 규격(8×4·32f / 5×5·25f)과 다르면 등재 |

렌더러는 **전용 idle / L / R 시트를 이미 지원**한다(`companion_renderer:259`
`_get_movement_texture_state(config, facing_left)`), 즉 후면 3종은 신규 렌더 분기 없이 얹힌다.

**카드**: 묵린변신 카드 1장(㉰)도 **이 생산 묶음에 포함**하거나 **즉시 후속 자산으로
명시**한다. ⚠️ **카드가 없으면 S1 프리웜 계약이 닫히지 않는다.**

### ㉱ QA 3단계 — 순서를 지킬 것 (rev8)

1. **자산 자체** — 고정 앵커 · 92×92 합성 QA
2. **배선** — D5a(그리드 메타) · D5c(delta) 카탈로그 + renderer 구현
3. **운영 draw 경로** — `normal→f1` / `f12→normal` **픽셀 QA**

> ⚠️ **1단계 합성을 운영 증거로 승격 금지.** D5c는 **아직 문서 계약일 뿐 런타임 코드가
> 없다** — 2단계를 건너뛰면 3단계는 성립하지 않는다.

**㉱ 수락 기준 (rev5 추가 — D13 QA가 못 잡은 경계)**

D13 QA는 **변신 시트 내부 인접 프레임만** 검증했다. 다음 두 경계는 봉인되지 않았다:

- **normal → f1** 운영 렌더 무팝
- **f12 → normal** 운영 렌더 무팝

⚠️ 여기에 **D5c의 6px 모드 오프셋 차이**(WALK −6 vs CAST −12)가 그대로 실린다.
**아트로 보상하지 말고 D5c 오프셋 계약으로 흡수**한 뒤, **실제 운영 렌더로** 두 경계를
검증한다.

> ⚠️ **㉱ 하나만 풀면 끝나는 범위가 아니다.** enabled 카탈로그 엔트리까지 S1 범위라면
> 정상 몸체 외에 `cutin_anim` / `cutin_dismiss_anim` / `click_reaction_anim`도
> 필요하다(`REQUIRED_VISUAL_KEYS`).
>
> ⚠️ **f1 정적 크롭을 최종 몸체로 쓰지 말 것.** 승인된 f1은 **정체성 앵커**로 삼고
> 정상 백린 **rear idle / walk 시트**를 만드는 것이 생산용 S1의 품질선이다.
> f1 1×1 파생본은 **debug-only 임시 몸체**로만 허용.

## 개정 이력

- 2026-07-31 **rev6 — 사용자 판단 2건 확정 (H-1 완전 종결)**:
  - **E1 조건부 → 필수 확정.** 발동 SFX·플래시 채택(성공 edge 1회 / 차단·실패
    0회 / 루프 없음 / 재생분 취소 없음 / 공용 라우터 관통).
    → §F 라우터가 조건부 → **확정 대상**, ㉯는 "가드 단계 임계값"만 남음.
  - **E6 N/A 확정.** 피격·방어 유지, 무적·비피격·회피 없음, 충돌체 크기 불변,
    미등재. 근거 = 자동조작+비피격이면 P0 예산 초과.
  - §G에 씰 2종 신설: "성공 발동 1회 / 차단 0회", "변신 전후 동일 궤적에서
    피격·방어 결과 동일".
  - ⇒ **H-1 전수표 범위 전부 닫힘. 잔여 차단은 H-2 에셋·연출 결정뿐.**
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
