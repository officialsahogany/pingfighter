# 2026-08-09 Codex 리팩터링 세션 Claude 리뷰 인계서

- 작성 시각: 2026-08-09 21:21 KST
- 브랜치: `fix/plaza-lingpet-egg-full-roster-test`
- 기준 HEAD: `cd60eee338806b60ec18be5af69161a425f80930`
- 구현 대상: `godot/` 라이브 프로젝트
- 상태: Claude 최종 재검증 완료. 리팩터링 범위 GREEN, focused 전체는 별도 WIP 13건으로 RED. 커밋/스테이징하지 않음.
- 세션 원본 로그: `C:\Users\woduq\.codex\sessions\2026\08\09\rollout-2026-08-09T12-17-41-019fe486-b4ce-7202-b85b-01ddd7e34f05.jsonl`

## 1. Claude에게 요청하는 리뷰 범위

이번 세션은 새 기능 추가보다 기존 대형 facade의 책임을 작은 owner 모듈로 옮기고, 공개 API와 실제 런타임 동작을 유지하는 데 집중했다. 다음 관점으로 반대검증을 요청한다.

1. 새 owner가 실제 정책과 수명주기를 소유하고 있는가, 아니면 facade의 private field를 과도하게 들여다보는 우회 계층인가.
2. facade가 호환 wrapper와 live state 조정자로 남았는가.
3. `Callable`이나 강한 상호 참조가 새 순환 참조/ObjectDB leak을 만들지 않는가.
4. source-contract smoke가 유효한 회귀 방지선인가, 구현 세부에 지나치게 결합됐는가.
5. 각 역변이(reverse mutation)가 실제로 의도한 계약을 깨서 RED가 되었는가.
6. 공개 snapshot schema, 입력/오디오/설정 저장, RNG 순서, Lingpet 수명주기 순서가 기존 소비자와 호환되는가.
7. 현재 남은 대형 facade에서 다음으로 옮길 책임이 명확하고 독립적인가.

중요: 저장소 전체 작업 트리는 이번 세션 전부터 매우 더럽다. 세션 시작 감사에서 약 4,765개 변경이 관찰됐다. 저장소 전체 `git diff`를 이번 세션 결과로 간주하면 안 된다. 아래에 열거한 경로와 세션 로그를 기준으로 리뷰해야 하며, `git reset`, `git checkout`, `git stash`, `git clean`으로 다른 WIP를 건드리면 안 된다.

## 2. 요약 판단과 현재 수치

초기 판단은 구조 8.5/10, 통합 안정성 5/10, 문서/작업 트리 관리 4~5/10 정도였다. 모듈 구조 자체는 양호했지만, 매우 큰 dirty worktree와 초기 파서 오류, 누락된 ownership ledger, 전체 스모크 대비 작은 집중 검증 범위가 주요 위험이었다.

첫 Claude 리뷰 전 체크포인트에서는 네 개 facade에서 총 1,936줄을 줄였다. 리뷰 후 Plaza reflection 안전성 교정으로 facade 60줄을 되돌려 현재 순감소는 1,876줄이며, 옮긴 책임마다 owner smoke와 역변이 증거를 추가했다. 다만 전체 1,537개 스모크를 모두 실행하지 않았으므로 “리팩터링 완전 종료”가 아니라 “검토 가능한 ownership 체크포인트”로 보는 것이 정확하다.

| 지표 | 세션 시작 | 현재 | 변화 |
|---|---:|---:|---:|
| `godot/scripts/**/*.gd` | 1,796 | 1,816 | +20 |
| `godot/tests/**/*.gd` | 1,582 | 1,604 | +22 |
| `*_smoke.gd` | 1,515 | 1,537 | +22 |
| `pause_menu_overlay.gd` | 2,593줄 | 1,738줄 | -855, -33.0% |
| `runtime_perk_state.gd` | 2,189줄 | 2,022줄 | -167, -7.6% |
| `plaza_scene.gd` | 1,707줄 | 1,695줄 | -12, -0.7% |
| `lingpet_egg_runtime.gd` | 4,141줄 | 3,299줄 | -842, -20.3% |

현재 `godot/scripts/lingpet`에는 164개 GDScript 모듈이 있다. 줄 수 감소만으로 품질을 판단하지 말고, 아래 책임 이동과 런타임 계약을 중심으로 리뷰해야 한다.

## 3. 세션 시작 감사와 기준선 안정화

### 3.1 초기 감사 결과

- `scenes/main.gd`는 한 줄 수준의 shell이며 battle shell 위임 구조는 유지되고 있었다.
- catalog 11개와 다수 domain module로 분산된 구조는 확인됐다.
- 당시 스크립트 총 455,256줄, 중앙값 144줄, 90퍼센타일 573줄이었다.
- ownership ledger에 Lingpet 모듈 18개가 누락돼 있었다.
- warning scan은 3,449개 중 2,700개 지점에서 테스트 파서 오류 두 건 때문에 중단됐다.
- 전체 스모크 1,515개 중 집중 CI 목록은 152개 수준이라, 이를 전체 회귀 통과로 해석할 수 없었다.
- 전역 `git diff --check`는 이번 세션과 무관한 문서 공백 WIP 때문에 처음 실패했다.

### 3.2 파서 오류와 ownership 기준선 복구

수정한 테스트:

- `godot/tests/guardian_spirit_rebrand_smoke.gd`
- `godot/tests/perk_conversion_values_smoke.gd`

처리 내용:

- 두 테스트의 파서 오류를 복구해 warning scan이 끝까지 진행되게 했다.
- 누락된 Lingpet owner 18개를 `docs/godot_module_ownership_ledger.md`에 등록했다.
- 당시 상태 문서 수치를 scripts 1,796 / tests 1,584 / smokes 1,517로 갱신했다.
- 기준선 집중 스모크 11개, warning scan 3,451개 무경고, headless load, 세션 대상 diff-check를 통과했다.

## 4. Pause Menu 책임 분리

`godot/scripts/hud/pause_menu_overlay.gd`는 외부 호출과 live state를 유지하고, 렌더링·입력·설정·오디오·콘텐츠 정책을 아래 owner로 이동했다. 최종 2,593줄에서 1,738줄로 줄었다.

| owner | 이동한 책임 | 주요 계약/검증 |
|---|---|---|
| 기존 `pause_menu_overlay_layout.gd` | 중복 geometry 계산 | overlay가 기존 layout owner를 실제 호출하도록 변경. `pause_menu_overlay_layout_owner_smoke.gd`에서 위임 제거 역변이 RED 확인 |
| `pause_menu_options_renderer.gd` | palette/frame/slider/button/toggle과 options 창/탭 합성 | renderer는 해석된 snapshot만 받고 registry/`LanguageSettings`에 직접 의존하지 않음 |
| `pause_menu_selection_feedback_renderer.gd` | 선택 강조와 animation projection | 상태 소유권은 `pause_menu_selection_feedback_state.gd`에 유지 |
| `pause_menu_display_settings_controller.gd` | `battle_view_layout` 탐색, 화면/FPS/VSync 적용·저장, refresh 권고 | display state smoke와 owner smoke로 설정 반영 경로 확인 |
| `pause_menu_input_command_router.gd` | 키보드/게임패드 입력을 semantic command로 변환 | 기존 12개 compatibility method 유지 |
| `pause_menu_pointer_command_router.gd` | 마우스/우클릭/탭/slider/settings/language 입력을 pure command로 변환 | pointer 경로가 language focus mapping을 재사용 |
| `pause_menu_audio_controller.gd` | `game_audio` 탐색, move/confirm/back cue, volume clamp/write, slider projection | 모든 입력 경로가 공유 오디오 owner를 통하도록 함 |
| `pause_menu_language_settings_controller.gd` | 저장 언어, canonical focus mapping, 순환/wrap, persistence, native name | 입력 router와 동일한 focus 의미 사용 |
| `pause_menu_controls_settings_controller.gd` | 진동 sync/save/default, 현지화 label, keyboard/gamepad row | controller가 controls 설정 투영 소유 |
| `pause_menu_content_catalog.gd` | main action ID, 현지화 메뉴 항목, back/close label, tab/device/focus 설명 | player-facing 콘텐츠를 overlay draw code에서 분리 |

추가/갱신 테스트:

- `godot/tests/pause_menu_overlay_layout_owner_smoke.gd`
- `godot/tests/pause_menu_options_renderer_owner_smoke.gd`
- `godot/tests/pause_menu_selection_feedback_renderer_owner_smoke.gd`
- `godot/tests/pause_menu_display_settings_controller_owner_smoke.gd`
- `godot/tests/pause_menu_input_command_router_smoke.gd`
- `godot/tests/pause_menu_pointer_command_router_smoke.gd`
- `godot/tests/pause_menu_audio_controller_owner_smoke.gd`
- `godot/tests/pause_menu_language_settings_controller_owner_smoke.gd`
- `godot/tests/pause_menu_controls_settings_controller_owner_smoke.gd`
- `godot/tests/pause_menu_content_catalog_owner_smoke.gd`
- 기존 `pause_menu_overlay_smoke.gd`, `pause_menu_display_settings_state_smoke.gd`도 현재 위임 구조에 맞게 갱신

각 slice에서 owner smoke를 실행하고 핵심 위임/필드를 일시적으로 깨는 역변이로 RED를 확인한 뒤 원복했다. 집중 묶음은 작업 진행에 따라 11개에서 20개까지 늘어났고, warning scan은 3,453개에서 3,469개까지 모두 무경고였다. 각 체크포인트에서 headless load와 세션 대상 diff-check도 통과했다.

## 5. 디스크 고갈 대응과 복구 가능한 정리

Pause Menu 작업 중 D: 여유 공간이 0 byte가 됐다. 사용자 WIP나 영상은 삭제하지 않고 자동화 생성 로그와 고아 Git 임시 pack만 SHA-256 확인 후 C: 백업 디렉터리로 이동했다.

백업 위치:

`C:\Users\woduq\.codex\backups\bosspong_generated_logs`

주요 이동 항목:

- `git_tmp_pack_wJGuLL.moved`
  - 크기: 3,900,702,720 bytes
  - 원본 시각: 2026-05-13의 고아 임시 pack
  - SHA-256: `21EBA425…3538B1E`
- Stage 3 계열 대형 로그 사본 두 개: 각 575,550,402 bytes
- `main_menu_flow_objectdbscan_1936.log`: 50,804,667 bytes
- 기타 자동화 로그: 2,643,235 bytes

Git pack 이동으로 D:에서 약 3.63 GiB를 회수했다. 파일은 삭제가 아니라 이름을 바꿔 백업 이동했으므로 복구 가능하다. 최신 Git 임시 pack과 사용자 WIP는 보존했다.

## 6. Lingpet snapshot, rail, profile surface 분리

### 6.1 `lingpet_overflow_guardian_snapshot_builder.gd`

이동한 책임:

- 현재 Guardian과 교체 후보 비교 snapshot
- catalog/profile 조회
- 빈 slot 표현
- pending roll 포함
- 캐시의 deep-copy 경계

결과:

- `lingpet_egg_runtime.gd` 4,141 → 3,984줄
- item-egg 테스트가 icon 존재만 보는 대신 실제 rolled loadout/catalog를 비교하도록 수정
- `pending_roll` 제거 역변이에서 RED 확인
- 집중 스모크 7개, warning scan 3,471개 무경고

### 6.2 `lingpet_rail_card_surface_builder.gd`

이동한 책임:

- frame/static cache와 두 slot 구성
- dynamic skill/runtime merge
- 빈 slot 기본값
- 공유 interaction permit
- static cache key에 `activation_model`, `available`, `active` 포함

추가 수정:

- debug 강제 전환은 ID만 바꾸지 않고 실제 one-Guardian slot을 교체하도록 변경
- `interaction_active` key 제거 역변이에서 RED 확인
- `lingpet_egg_runtime.gd` 3,984 → 3,821줄
- 집중 스모크 10개, warning scan 3,473개 무경고

### 6.3 `lingpet_profile_runtime_surface.gd`

이동한 책임:

- 최소값 floor를 포함한 파생 hit-gauge gain
- 이동 multiplier
- 여러 passive를 합산하는 character-info row

유지한 실제 경로:

- Maribo Lv.3 Tailwind 이동 배수 1.10
- Resonance 50 → 55 투영
- public API는 `lingpet_egg_runtime.gd` facade에 유지

단일 passive만 반영하도록 깨뜨린 역변이에서 이동 배수 1.15 → 1.05, Resonance 57 → 52로 떨어져 RED가 되는 것을 확인했다. facade는 3,821 → 3,791줄, 집중 스모크 8개와 warning scan 3,473개가 GREEN이었다.

## 7. Plaza snapshot과 테스트 teardown 복구

### 7.1 `plaza_status_snapshot_builder.gd`

공개 `get_status()` schema의 조립 책임을 새 owner로 이동했다.

- flow/menu/transition
- nested interior/character info
- transaction
- runtime perk metadata
- progression/minimap/geometry

결과:

- `plaza_scene.gd` 1,707 → 1,635줄
- `flow_gate` 누락 역변이 RED 확인
- 소비자/문서 계약 스모크 11개 GREEN
- warning scan 3,475개 무경고, headless load, 세션 대상 diff-check GREEN

### 7.2 fixture 순환 참조 정리

두 smoke 종료 시 77-resource leak이 발생한 원인은 production code가 아니라 테스트 `FakeRegistry ↔ RuntimePerkState` fixture 순환 참조였다.

수정:

- `godot/tests/plaza_academy_menu_smoke.gd`: teardown에서 `registry.clear_all()` 호출
- `godot/tests/plaza_lingpet_store_menu_smoke.gd`: 같은 정리와 `expect-zero-object-leaks` marker 추가
- 각각 3회 연속, 결합 집중 11개 GREEN
- teardown 규칙을 `docs/godot_runtime_traps.md`와 `docs/godot_port_architecture.md`에 기록

## 8. Runtime Perk owner 분리

### 8.1 `runtime_perk_physique_training_runtime_state.gd`

이동한 책임:

- catalog/run-state/planner 수명
- 최종 consumer saturation
- owner/mythic sync
- 60% replacement offer와 RNG 순서

실제 consumer probe:

- active item cooldown composer
- Smasher dash
- cooldown floor
- mythic runtime

중간 getter를 읽도록 깨뜨린 역변이는 7개 RED를 만들었다. fusion seed의 비결정적 fixture를 고친 뒤 동일 경로 3회 연속 GREEN을 확인했다. facade는 2,189 → 2,080줄이었다.

### 8.2 `runtime_perk_hyeonmun_charyeok_runtime_state.gd`

이동한 책임:

- activation/refresh/expiry/round reset
- Transcendent Crown 반영
- effective-level publication과 cache refresh

보존한 계약:

- `sage_ring`
- 5% proc
- +1/+2/+3 단계
- 6~10초 지속
- 재발동 시 stack이 아닌 refresh
- 자기 자신 제외

activation refresh와 expiry refresh를 각각 깨뜨린 역변이에서 RED를 확인했다. facade는 2,080 → 2,059줄, 집중 스모크 11개와 warning scan 3,479개가 GREEN이었다.

### 8.3 `runtime_perk_fusion_runtime_state.gd`

이동한 책임:

- fusion core/byproduct/offer planner
- RNG 호출 전에 eligibility 판정
- 테스트 주입 seam
- replacement writeback
- modal flow/input/catalog
- S0~S4 transaction
- frozen catalog
- commit/common finish/cache boundary
- cold-boot shutdown

eligibility 판정을 RNG 뒤로 옮긴 역변이에서 RED를 확인했다. 중간 단계에서 `runtime_perk_fusion_modal_integration_smoke.gd`의 오래된 7-argument 호출 불일치가 발견됐으나, 최종 modal/injection transaction 통합에서 해소했다. facade는 최종 2,022줄, fusion 집중 묶음 8개와 warning scan 3,479개가 GREEN이었다.

관련 핵심 테스트:

- `runtime_perk_physique_training_runtime_state_refactor_smoke.gd`
- `runtime_perk_hyeonmun_charyeok_runtime_state_refactor_smoke.gd`
- `runtime_perk_fusion_runtime_state_refactor_smoke.gd`
- 기존 fusion integration/offer/modal smokes

## 9. Lingpet motion 및 Guardian 수명주기 분리

### 9.1 초기 `lingpet_companion_motion_coordinator.gd`

동작 우선순위를 다음 순서로 한 owner에 모았다.

1. mount
2. active skill
3. Ring Dash
4. Starlight
5. normal companion motion

position/facing의 canonical 갱신도 coordinator가 맡았다. mount 중 click reaction cleanup을 제거한 역변이에서 RED를 확인했다. 이 단계에서 facade는 3,791 → 3,699줄, 집중 스모크 11개와 warning scan 3,481개가 GREEN이었다.

### 9.2 13 Guardian egg art 계약과 Nekuring 해상도 복구

- `lingpet_egg_runtime_smoke.gd`를 현재 13 Guardian art 계약에 맞게 갱신했다.
- Nekuring dismiss 이미지가 4,096px 원본을 잘못 downscale하는 회귀를 발견했다.
- no-downscale 계약을 복구했고, 다시 4,096 경로로 깨뜨린 역변이에서 RED를 확인했다.
- 관련 집중 스모크 10개, warning scan 3,481개 무경고였다.

### 9.3 `lingpet_guardian_enhance_presentation_coordinator.gd`

이동한 책임:

- reel icon과 trigger label
- reservation과 result retention
- 5-phase prewarm/start/advance/cancel
- modal pause/resume
- loop audio cleanup

Baekrin은 의도된 static model로 취급하며 fallback/procedural icon 기대값을 유지했다. 위임 제거 역변이 RED, facade 3,699 → 3,574줄, 집중 스모크 14개와 warning scan 3,483개 GREEN이었다.

### 9.4 `lingpet_guardian_duration_lifecycle_coordinator.gd`

이동한 책임:

- 6초 manual stow
- recovery resummon
- transition
- duration drain과 warning
- refill/overfill
- forced expiry
- 순서가 있는 teardown

중요 계약: Nekuring deployment 보존은 일반 cancel이 아니라 duration expiry에서만 적용한다. facade는 `WeakRef`로 연결했다. 위임 제거 역변이에서 4개 RED, facade 3,574 → 3,537줄, 집중 스모크 16개와 warning scan 3,485개 GREEN이었다.

### 9.5 `lingpet_guardian_enhance_flow_coordinator.gd`

이동한 책임:

- pet/context 해석
- offer/live candidate
- weighted roll/revalidation
- run-state apply
- unlock loadout refresh
- detail/fallback
- snapshot/owner sync
- presentation 호출

`WeakRef` facade를 사용했다. 위임 제거 역변이는 enhancement 미적용, duration 누락, cut-in 누락 RED를 만들었다. facade는 3,537 → 3,379줄, 집중 스모크 18개와 warning scan 3,487개 GREEN이었다.

### 9.6 `lingpet_acquisition_lifecycle_coordinator.gd`

이동한 책임:

- shell-break pending branch
- staged break
- flash/burst hold
- deferred commit
- cut-in prewarm/readiness/reveal/dismiss
- audio
- close 뒤 overflow 처리

`WeakRef` facade를 사용했다. 위임 제거 역변이에서 hatch/cut-in RED, facade 3,379 → 3,319줄, 집중 스모크 19개와 warning scan 3,489개 GREEN이었다. CI와 pre-push 등록 목록은 이 시점에 156/156으로 일치시켰다.

### 9.7 motion 순환 참조 제거와 cached-only player resolver

초기 motion coordinator가 facade-bound `Callable` 네 개를 보유해 강한 참조 순환을 만들 수 있음을 발견했다.

제거한 callback:

- invalidate snapshot
- right-click claimed
- resolve dash state
- player guard available

대체:

- `lingpet_companion_player_runtime_resolver.gd`가 cached-only Smasher/Viper arbitration 소유
- motion coordinator는 facade로의 단일 `WeakRef`만 보유
- physics tick에서 `get_instance()`를 호출하지 않음
- facade public wrapper는 유지
- body-hit guard도 resolver 경로 사용

새 테스트:

- `lingpet_companion_player_runtime_resolver_smoke.gd`
- `lingpet_companion_motion_coordinator_refactor_smoke.gd`

첫 owner smoke에서 `WeakRef` 주변 Variant inference warning을 발견해 명시 타입으로 수정했다. resolver fake fixture의 registry↔Viper 순환도 teardown에서 끊고 zero-leak marker를 추가했다. 강한 facade reference로 되돌린 역변이는 정확히 RED와 ObjectDB leak을 만들었다. 복구 뒤 facade는 3,319 → 3,299줄이다.

최종 Lingpet 집중 묶음 21개, warning scan 3,491개 무경고, 공식 1,200-frame headless graceful shutdown이 GREEN이었다. CI/pre-push 등록 목록도 158/158로 일치한다.

## 10. 반드시 유지해야 할 호환 계약

Claude 리뷰에서 아래 항목이 깨졌다면 blocker로 취급해야 한다.

### Pause Menu

- `pause_menu_overlay.gd`의 기존 외부 method 이름과 호출 경로 유지
- renderer는 registry와 `LanguageSettings`를 직접 조회하지 않고 resolved snapshot 사용
- mouse, keyboard, gamepad가 동일한 semantic action과 공유 audio owner로 수렴
- language focus mapping을 pointer/router/controller가 서로 다르게 재정의하지 않음
- FPS/VSync/screen mode/volume/vibration 설정의 apply와 persistence 유지

### Runtime Perk

- physique replacement offer eligibility를 RNG 소비 전에 판정
- final consumer saturation을 중간 getter로 대체하지 않음
- Hyeonmun Charyeok의 5%/+1~+3/6~10초/refresh/self-exclusion 유지
- fusion의 S0~S4 transaction, frozen catalog, commit/cache/cold-boot 순서 유지
- facade public wrapper와 기존 callback 이름 유지

### Plaza

- `get_status()`의 공개 schema key와 nested shape 유지
- `flow_gate`, transaction, runtime perk metadata, minimap/geometry 누락 금지
- 테스트 registry가 runtime state와 순환하지 않도록 teardown에서 `clear_all()` 수행

### Lingpet

- overflow snapshot cache는 deep-copy 경계를 유지하고 `pending_roll`을 포함
- rail static cache key는 `activation_model`, `available`, `active`를 포함
- profile surface는 여러 passive를 합산하고 실제 effective value/floor 사용
- motion 우선순위 mount → active skill → Ring Dash → Starlight → normal 유지
- physics tick에서 cold `get_instance()` 금지
- facade 역참조는 `WeakRef`; 강한 `Callable` 보관 금지
- Nekuring 4,096px dismiss asset을 임의 downscale하지 않음
- Nekuring deployment 보존은 duration expiry 전용
- Guardian enhance/acquisition의 prewarm, modal pause, audio cleanup, deferred commit, overflow 순서 유지
- Baekrin static presentation fallback 계약 유지

## 11. 테스트와 검증 증거

이번 세션의 표준은 단순 GREEN 한 번이 아니었다.

- 각 production slice에 집중 behavioral smoke와 owner/source-contract smoke를 추가 또는 갱신했다.
- 핵심 위임, key, 순서, 참조 형태를 임시로 깨서 RED를 확인한 뒤 안전하게 원복했다.
- 역변이는 작업 파일의 해당 줄만 in-place로 바꿨으며 `git reset`, `checkout`, `stash`를 사용하지 않았다.
- `.gd` 변경 뒤 warning scan을 별도 실행했다.
- headless load를 별도 실행했다.
- 세션 대상 `git diff --check`/trailing whitespace를 확인했다.
- 최종 Lingpet 경로는 1,200-frame graceful shutdown까지 확인했다.

아래 결과는 Claude 1차 리뷰 조치 **이전** 세션 체크포인트에서 관찰한 값이다. 1차 리뷰 후 수정한 blocker/owner 경계는 라이브 플레이 PID 27108 때문에 아직 Godot로 재실행하지 않았으며, 그 상태는 §17에 별도로 기록한다.

최신 관찰 결과:

| 검증면 | 결과 |
|---|---|
| 최종 Lingpet 집중 묶음 | 21개 GREEN |
| 최종 warning scan | 3,491 scripts, GDScript warning 0 |
| 최종 headless | 1,200-frame graceful shutdown GREEN |
| CI/pre-push 목록 동기화 | 158/158 일치 |
| 세션 대상 diff/whitespace | GREEN |
| 전체 smoke suite | 미실행: 1,537개 전체 통과를 주장하지 않음 |

`CI/pre-push 158/158`은 두 등록 목록의 일치를 뜻한다. 1,537개 전체 스모크가 모두 통과했다는 뜻이 아니다.

## 12. 현재 남은 한계와 별도 WIP gate

### 리뷰 blocker가 될 수 있는 공백

- 전체 1,537개 smoke suite는 실행하지 않았다.
- 저장소 전체가 매우 큰 dirty worktree이므로 session-scoped GREEN이 전역 GREEN을 뜻하지 않는다.
- 새 owner와 owner smoke 다수가 untracked 상태다. 일반 `git diff`만 보면 내용이 보이지 않으므로 `git status --short`와 파일 직접 읽기가 필요하다.
- Godot가 생성한 대응 `.uid`도 일부 untracked다. `.gd`만 리뷰하고 `.uid`를 누락하지 말아야 한다.

### 이번 세션에서 관찰했지만 이 리팩터링 소유가 아니었던 gate

- `character_info_live_stats_smoke.gd`: 당시 현재 roster/second active slot schema와 맞지 않는 별도 WIP RED가 있었다. Lingpet profile/enhance owner 회귀로 판정하지 않았고 이 세션에서 닫지 않았다.
- `soul_summon_art_skill_contract_smoke.gd`: duration slice 중 별도 art/metadata WIP gate가 관찰됐다. 이번 owner slice 완료 조건으로 사용하지 않았다.
- `wall_leap_floor_save_scope_smoke.gd`, `lingpet_debug_picker_smoke.gd`: 최종 묶음 밖의 기존 비-gated shutdown/ObjectDB 경고가 관찰됐다.
- 중간 `lingpet_mount_runtime_gate_smoke.gd`에서도 ObjectDB 관련 경고가 있었으나, 새 resolver zero-leak smoke와 최종 공식 headless에서는 leak이 없었다.

위 항목들은 “통과”로 표시하지 않는다. Claude가 관련 경로를 건드릴 경우 현재 트리에서 별도 재현해야 한다.

작성 시점에는 이전에 사용자가 실행했던 play PID 24716이 더 이상 활성 상태가 아니었다. 이번 문서 작성 과정에서 Godot/editor 프로세스를 종료하지 않았다.

## 13. 세션 소유 파일 지도

### Pause Menu

- facade: `godot/scripts/hud/pause_menu_overlay.gd`
- owners:
  - `pause_menu_options_renderer.gd`
  - `pause_menu_selection_feedback_renderer.gd`
  - `pause_menu_display_settings_controller.gd`
  - `pause_menu_input_command_router.gd`
  - `pause_menu_pointer_command_router.gd`
  - `pause_menu_audio_controller.gd`
  - `pause_menu_language_settings_controller.gd`
  - `pause_menu_controls_settings_controller.gd`
  - `pause_menu_content_catalog.gd`
- reused owner: `pause_menu_overlay_layout.gd`
- tests: `godot/tests/pause_menu_*_smoke.gd`, 특히 10개 `*_owner_smoke.gd`/router smoke

### Runtime Perk

- facade: `godot/scripts/characters/runtime_perk_state.gd`
- owners:
  - `runtime_perk_physique_training_runtime_state.gd`
  - `runtime_perk_hyeonmun_charyeok_runtime_state.gd`
  - `runtime_perk_fusion_runtime_state.gd`
- tests: 대응 `*_runtime_state_refactor_smoke.gd`와 fusion integration/offer/modal smokes

### Plaza

- facade: `godot/scripts/plaza/plaza_scene.gd`
- owner: `godot/scripts/plaza/plaza_status_snapshot_builder.gd`
- tests:
  - `plaza_status_snapshot_builder_owner_smoke.gd`
  - `plaza_academy_menu_smoke.gd`
  - `plaza_lingpet_store_menu_smoke.gd`

### Lingpet

- facade: `godot/scripts/lingpet/lingpet_egg_runtime.gd`
- modified surface: `lingpet_profile_runtime_surface.gd`
- new owners:
  - `lingpet_overflow_guardian_snapshot_builder.gd`
  - `lingpet_rail_card_surface_builder.gd`
  - `lingpet_companion_motion_coordinator.gd`
  - `lingpet_companion_player_runtime_resolver.gd`
  - `lingpet_guardian_enhance_presentation_coordinator.gd`
  - `lingpet_guardian_duration_lifecycle_coordinator.gd`
  - `lingpet_guardian_enhance_flow_coordinator.gd`
  - `lingpet_acquisition_lifecycle_coordinator.gd`
- owner tests: 같은 stem의 `*_owner_smoke.gd`, resolver/motion refactor smokes
- 갱신된 소비자 테스트: `lingpet_egg_runtime_smoke.gd`, one-Guardian/rail/profile/duration/acquisition 관련 smokes

### 문서와 자동화

- `.github/workflows/godot-ci.yml`
- `godot/tools/run_pre_push_checks.ps1`
- `docs/godot_port_architecture.md`
- `docs/godot_module_ownership_ledger.md`
- `docs/refactor_status_brief.md`
- `docs/current_development_boundary.md`
- `docs/godot_runtime_traps.md`

### 세션 로그상 기타 편집

Claude 리뷰가 세션 로그와 mtime을 교차검사해 아래 두 파일도 이번 세션 중 편집됐음을 확인했다. 리팩터링 owner 변경과는 별도 범위이며, 다른 WIP일 수 있으므로 내용 원복이나 추가 수정은 하지 않았다.

- `LEGENDARY_ITEM_TEMPLATE.md`: 대규모 줄바꿈 churn 포함
- `godot/tests/settings_ui_neon_skin_smoke.gd`: 소규모 변경

## 14. Claude 우선 리뷰 체크리스트

### P0: 즉시 확인

- [ ] `lingpet_companion_motion_coordinator.gd`가 facade를 강하게 잡거나 bound `Callable`을 저장하지 않는지
- [ ] `lingpet_companion_player_runtime_resolver.gd`가 physics tick에서 cold instance lookup을 하지 않는지
- [ ] Guardian enhance/duration/acquisition 세 coordinator의 cancel/expiry/commit/audio cleanup 순서가 서로 충돌하지 않는지
- [ ] fusion eligibility가 RNG보다 먼저이며 transaction commit이 중복되지 않는지
- [ ] Plaza `get_status()` schema가 기존 consumer key를 빠뜨리지 않았는지
- [ ] Pause Menu 세 입력 장치가 동일한 command/오디오/설정 경로로 수렴하는지

### P1: 결합도와 테스트 품질

- [ ] 새 owner가 facade private field를 무제한 조회하지 않는지
- [ ] source 문자열 검사만 있고 실제 behavior probe가 없는 책임이 남아 있지 않은지
- [ ] 테스트 fixture teardown이 registry/state 순환을 모두 끊는지
- [ ] 새 `.gd`에 대응하는 `.uid`, ownership ledger, CI/pre-push 항목이 빠지지 않았는지
- [ ] snapshot/static cache가 mutable dictionary를 외부에 공유하지 않는지

### P2: 다음 slice 제안

다음 리팩터링은 파일 줄 수만 보고 고르지 말고, facade 안에 남은 하나의 독립적인 수명주기 또는 정책 묶음을 골라야 한다. 공개 wrapper를 유지하고, 새 owner 하나 + 행동 smoke 하나 + 역변이 하나로 닫을 수 있는 크기를 권장한다.

## 15. 권장 리뷰 명령

저장소 루트에서 범위를 먼저 확인한다.

```powershell
git status --short -- `
  godot/scripts/hud/pause_menu* `
  godot/scripts/characters/runtime_perk_state.gd `
  godot/scripts/characters/runtime_perk_*_runtime_state.gd `
  godot/scripts/plaza/plaza_scene.gd `
  godot/scripts/plaza/plaza_status_snapshot_builder.gd `
  godot/scripts/lingpet/lingpet_egg_runtime.gd `
  godot/scripts/lingpet/lingpet_*coordinator.gd `
  godot/scripts/lingpet/lingpet_*builder.gd `
  godot/scripts/lingpet/lingpet_profile_runtime_surface.gd `
  godot/tests/pause_menu* `
  godot/tests/runtime_perk* `
  godot/tests/plaza* `
  godot/tests/lingpet* `
  docs/godot_port_architecture.md `
  docs/godot_module_ownership_ledger.md `
  docs/godot_runtime_traps.md `
  docs/refactor_status_brief.md `
  docs/current_development_boundary.md `
  .github/workflows/godot-ci.yml `
  godot/tools/run_pre_push_checks.ps1
```

핵심 결합과 금지 경로를 검색한다.

```powershell
rg -n "Callable|WeakRef|get_instance|build_from_runtime_state|pending_roll|interaction_active|flow_gate|eligib|rng|clear_all" `
  godot/scripts/hud `
  godot/scripts/characters/runtime_perk_* `
  godot/scripts/plaza `
  godot/scripts/lingpet `
  godot/tests
```

Godot 검증은 `godot/`에서 실행한다.

```powershell
cd godot

$pauseTests = Get-ChildItem tests -Filter 'pause_menu_*_smoke.gd' |
  Sort-Object Name |
  ForEach-Object { 'res://tests/' + $_.Name }
.\tools\run_smoke_tests.ps1 -Tests $pauseTests

.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/runtime_perk_physique_training_runtime_state_refactor_smoke.gd',
  'res://tests/runtime_perk_hyeonmun_charyeok_runtime_state_refactor_smoke.gd',
  'res://tests/runtime_perk_fusion_runtime_state_refactor_smoke.gd',
  'res://tests/runtime_perk_fusion_integration_smoke.gd',
  'res://tests/runtime_perk_fusion_offer_integration_smoke.gd',
  'res://tests/runtime_perk_fusion_modal_integration_smoke.gd',
  'res://tests/plaza_status_snapshot_builder_owner_smoke.gd',
  'res://tests/plaza_academy_menu_smoke.gd',
  'res://tests/plaza_lingpet_store_menu_smoke.gd'
)

.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/lingpet_overflow_guardian_snapshot_builder_owner_smoke.gd',
  'res://tests/lingpet_rail_card_surface_builder_owner_smoke.gd',
  'res://tests/lingpet_profile_runtime_surface_smoke.gd',
  'res://tests/lingpet_guardian_enhance_presentation_coordinator_owner_smoke.gd',
  'res://tests/lingpet_guardian_duration_lifecycle_coordinator_owner_smoke.gd',
  'res://tests/lingpet_guardian_enhance_flow_coordinator_owner_smoke.gd',
  'res://tests/lingpet_acquisition_lifecycle_coordinator_owner_smoke.gd',
  'res://tests/lingpet_companion_player_runtime_resolver_smoke.gd',
  'res://tests/lingpet_companion_motion_coordinator_refactor_smoke.gd',
  'res://tests/lingpet_egg_runtime_smoke.gd'
)

.\tools\run_headless_load_check.ps1
.\tools\run_warning_scan.ps1
```

마지막으로 전체 suite를 실제로 실행했다면 runner 완료 marker, exit code, error, ObjectDB leak을 함께 보고해야 한다. 일부 집중 묶음만 실행한 경우에는 전체 GREEN이라고 표현하지 않는다.

## 16. Claude 리뷰 결과 형식 제안

리뷰 결과는 아래 형식을 권장한다.

- Blocker: 실제 동작 회귀, 수명주기 순서 오류, 강한 참조 cycle, 공개 schema/API 파손
- High/Medium risk: 숨은 결합, 캐시 mutable alias, RNG/설정 저장/오디오 경로 불일치
- Test gap: 현재 owner smoke가 포착하지 못하는 production 경로
- Keep as-is: 의도적으로 남긴 facade wrapper와 compatibility seam
- Next slice: 다음에 분리할 하나의 작은 ownership 경계
- Verification scope: 실제 실행한 smoke 수, warning/headless 여부, 전체 suite 실행 여부

이 문서는 커밋 목록이 아니라 현재 dirty tree 위의 세션 소유 변경을 검토하기 위한 인계서다. Claude는 수정에 들어가기 전에 먼저 발견 사항과 권고를 보고하고, 별도 구현 요청이 없으면 리뷰 범위에 머물러야 한다.

## 17. Claude 1차 리뷰 조치 결과

첨부 리뷰를 현재 트리와 대조한 뒤 다음을 반영했다.

### 17.1 Blocker 해결

`guardian_enhance_cutin_visual_contract_smoke.gd`가 삭제된 facade 멤버 두 개를 참조하던 문제를 수정했다.

- 제거: `LingpetEggRuntime._guardian_enhance_cutin_host_resolver`
- 제거: `LingpetEggRuntime._build_guardian_enhance_display_candidate_icons()`
- 대체: `LingpetGuardianEnhancePresentationCoordinator._host_resolver`
- 대체: `LingpetGuardianEnhancePresentationCoordinator.build_display_candidate_icons()`

이제 reel projection 계약은 실제 owner를 직접 검증한다. 같은 회귀가 focused gate 밖에서 다시 생기지 않도록 이 visual-contract smoke도 CI/pre-push 목록에 추가했다.

### 17.2 focused gate 보강

리뷰에서 누락으로 확인한 owner/router smoke 16개와 위 blocker 계약 1개, 총 17개를 아래 두 목록에 같은 순서로 추가했다.

- `.github/workflows/godot-ci.yml`
- `godot/tools/run_pre_push_checks.ps1`

정적 비교 결과 두 목록은 각각 176개, 중복 없이 176/176으로 일치한다. 새로 추가한 17개 파일은 모두 존재한다.

추가 검사 중 세션 이전부터 목록에 있던 다음 두 경로가 현재 파일 시스템과 Git index에 모두 없음을 별도로 발견했다.

- `runtime_perk_lingpet_ring_core_upgrade_smoke.gd`
- `runtime_perk_lingpet_affinity_chip_smoke.gd`

두 항목은 HEAD의 CI/pre-push 목록에도 이미 존재하던 선재 문제이며, 현재 runtime은 해당 Ring Core/Affinity Chip 선택지를 retired 처리한다. 빈 테스트를 만들거나 회귀면을 없애지 않고 다음 활성 retirement 계약으로 1:1 교체했다.

- `runtime_perk_choice_dispatch_smoke.gd`
- `runtime_perk_choice_apply_flow_smoke.gd`

교체 후 focused 목록 176개는 모두 실제 파일로 해석된다. 실행 GREEN은 아직 주장하지 않는다.

### 17.3 고아 headless 프로세스 종료

명령행을 재확인한 뒤 삭제된 `codex_guardian_enhance_second_slot_probe.gd`를 실행하던 세션 소유 headless 부모·자식만 종료했다.

- PID 44288: console parent, 종료 확인
- PID 23408: headless child, 종료 확인
- PID 27108: 사용자의 라이브 플레이, 유지
- PID 33728: Godot editor, 유지

### 17.4 Plaza reflection owner 경계 교정

`plaza_status_snapshot_builder.gd`의 `scene.get("...")`, `has_method()`, `callv()` 기반 private reflection을 제거했다.

- `plaza_scene.gd::_build_status_snapshot_context()`가 자기 필드와 메서드를 직접 참조해 57개 필수 context key를 구성한다.
- builder는 `REQUIRED_CONTEXT_KEYS`를 검증한 뒤 공개 status schema 76개를 투영한다.
- private field/method rename은 이제 facade의 직접 참조에서 드러나며, builder가 null/0/`<null>`로 조용히 대체하지 않는다.
- transaction/interior/character-info/minimap dictionary는 반환 경계에서 방어 복사한다.
- owner smoke는 explicit context 수, reflection 금지, required-key seal을 검사하도록 갱신했다.

이 교정으로 `plaza_scene.gd`는 1,635줄에서 1,695줄로 늘었다. 줄 수 감소보다 올바른 live-state ownership과 실패 가시성을 우선한 의도적 증가다.

### 17.5 Guardian presentation 순환과 reset cleanup

`lingpet_guardian_enhance_presentation_coordinator.gd`의 `_modal_owner`, `_modal_registry` 강참조를 각각 `WeakRef`로 바꿨다.

- cancel/reset 시 저장된 weak registry를 해석해 loop audio를 중지한다.
- cooldown pause를 resume하고 resume safety를 arm한다.
- `_clear_lingpet_field_state() -> reset_presentation_state()` 경로도 active cut-in을 완전히 정리한다.
- presentation owner smoke에 field-reset 행동 probe와 강참조 재도입 금지 source seal을 추가했다.
- presentation/duration/enhance-flow/acquisition coordinator smoke에 `expect-zero-object-leaks` marker를 추가했다.

### 17.6 Acquisition deferred commit 방어

`lingpet_acquisition_lifecycle_coordinator.gd::_commit_pending_hatch()`를 다음처럼 보강했다.

- facade WeakRef가 죽었거나 commit method가 없으면 pending kind를 먼저 소모하지 않는다.
- `_begin_overflow_hatch`/`_finish_regular_hatch` 존재를 확인한 뒤에만 commit한다.
- `_sync_owner` compatibility callback도 `has_method()`로 방어한다.
- owner smoke에 두 guard의 source seal을 추가했다.

### 17.7 의도적으로 보류한 Low 항목

- `lingpet_rail_card_surface_builder.gd::get_surface()`의 원본 cache 반환은 현재 유일 consumer가 읽기 전용이고, 매 프레임 deep-copy를 추가하면 cache 목적과 성능 수명주기에 영향을 준다. 별도 perf/consumer mutation probe 없이 즉시 복사를 넣지 않았다.
- fusion/motion source-contract smoke의 문자열 결합도 완화는 행동 probe를 먼저 설계해야 하므로 이번 blocker 조치와 섞지 않았다.
- 다음 대형 slice인 overflow/item-egg ownership 이동도 이번 리뷰 수정 범위에 포함하지 않았다.

### 17.8 이번 조치의 검증 상태

정적 검증:

- 수정 경로 `git diff --check`: GREEN
- Plaza context key: 57개/57개, 중복·누락 없음
- Plaza 공개 status key: 76개, 중복 없음
- CI/pre-push 목록: 176/176 동일, 중복 없음
- focused smoke 176개 경로: 모두 존재
- 제거된 Guardian facade 멤버 참조: 대상 visual-contract smoke에서 제거 확인

Godot 실행 검증:

- smoke: 미실행
- warning scan: 미실행
- headless load: 미실행
- 전체 suite: 미실행

사유: 조치 시점에도 PID 27108이 editor PID 33728 아래에서 `res://scenes/boot_flow.tscn`을 라이브 실행 중이었다. `Assert-NoInteractiveGodotGame` 가드를 우회하지 않았다. 플레이 종료 후에는 blocker 단독 smoke → 변경 owner 집중 묶음 → warning scan → headless load 순서로 다시 검증해야 한다.

## 18. Claude 최종 실행 검증과 종결 판정

§17의 라이브 플레이 blocker가 해소된 뒤 Claude가 배치 러너로 직접 재검증했다. 이 절이 §17.8의 미실행 상태를 대체하는 최신 결과다.

### 18.1 실행 결과

| 게이트 | 최종 결과 |
|---|---|
| headless load check | GREEN, 33초 |
| Stage 7 asset tool regression | Python 13건 GREEN |
| GDScript warning scan | GREEN, 3,494 scripts, warning 0 |
| Guardian blocker 단독 | 최초 RED → source-contract 수정 → GREEN |
| 변경 owner 집중 묶음 | 19/19 GREEN + runner 완료 marker |
| Pause Menu·Runtime Perk 묶음 | 16/16 GREEN + runner 완료 marker |
| 세션 신규 owner seal | 22/22 GREEN: Lingpet 8, Pause Menu 10, Plaza 1, Runtime Perk 3 |
| focused 176 전수 열거 | 163 PASS / 13 FAIL |
| 실제 GREEN이 확인된 고유 테스트 | 36개 |
| 전체 약 1,540개 suite | 미실행 |

세션 신규 owner seal 22개는 실패 목록에 하나도 없었다. headless, warning scan, dangling-reference sweep도 GREEN이므로 이번 리팩터링에 기인한 회귀는 0건으로 판정한다. `163/176`을 전체 suite GREEN으로 확대 해석하지 않는다.

### 18.2 최종 Guardian source-contract 수정

`guardian_enhance_cutin_visual_contract_smoke.gd`의 행동 leg는 presentation owner를 실제 실행하고 있었지만, mix/stamp source-contract leg가 계속 옛 facade 파일을 읽고 있었다. `display_candidate_icons`와 `has_cached_result_icon`의 현재 owner인 `lingpet_guardian_enhance_presentation_coordinator.gd`를 읽도록 수정한 뒤 단독 GREEN을 확인했다.

최초 실패가 source-contract 두 assertion으로만 제한된 사실은 앞선 reel projection 행동 leg가 abort되지 않고 실제 실행돼 통과했다는 반증이기도 하다.

### 18.3 focused RED 13건 분류

#### A. 은퇴·재설계된 낡은 seal: 3건

- `mythic_perk_offer_chance_smoke.gd`
  - 은퇴한 Ring Core 예약 lane을 source 문자열로 계속 단언한다.
- `perk_fusion_value_hooks_smoke.gd`
  - 실제 source가 1개인데 fixture가 `RECORD_SOURCE_COUNT := 2`를 요구해 빈 record/null로 흐른다.
  - 한 leg의 SCRIPT ERROR 뒤에도 `ok`와 exit 0이 나오는 hollow-GREEN 형태였으며, runner의 error 승격으로 적발됐다.
- `perk_fusion_cold_boot_cinematic_smoke.gd`
  - renderer `draw()`의 현재 7-argument signature에 8개를 전달한다.
  - 형제 `runtime_perk_fusion_modal_integration_smoke.gd`의 같은 문제는 세션 중 고쳤지만 이 파일까지 전수하지 못한 일반화 누락이다.

세 항목 모두 production owner의 세션 전 상태 또는 세션 밖 catalog 변경에 귀속되며, 리팩터링 회귀로 분류하지 않는다. 별도 후속에서는 불변식 기반 seal과 형제 호출부 전수조사로 닫는다.

#### B. 별도 설계·asset WIP: 8건

- `mythic_reveal_backdrop_smoke.gd`: prewarm 계약 5개 중 3개 불일치
- `project_resource_loader_import_preference_smoke.gd`: Stage 2 Cheongringwi PNG 두 개의 `.import` sidecar 부재
- `match_player_skill_deps_builder_smoke.gd`: Blacksmith 네 번째 config
- `stage7_akamu_result_scene_smoke.gd`: click rect
- `perk_fusion_localization_smoke.gd`: Spanish/Portuguese-Brazil Mugong 용어
- `perk_fusion_display_consumer_smoke.gd`: 재료 section header
- `player_socket_glow_smoke.gd`: socket pixel mapping
- `player_socket_part_overlay_smoke.gd`: socket pixel mapping

#### C. ObjectDB leak: 2건

- `warp_gate_afterimage_smoke.gd`: 5 resources
- `perk_fusion_cold_boot_timeline_smoke.gd`: 81 resources

두 테스트 모두 exit 0이지만 runner가 `ERROR:`를 실패로 승격해 잡았다. `warp_gate_afterimage_smoke.gd`는 최종 검증 당시 다른 병행 작업이 갱신 중이어서 이 세션에서 수정하지 않았다.

### 18.4 character-info 선행 gate 처리

처음 focused 목록을 막던 `character_info_passive_ui_retire_smoke.gd`는 이번 리팩터링과 무관한 편액/active-item strip WIP였다. 고정 PNG의 `inner=19`, `content_top=62` 같은 폐기된 픽셀값 대신 다음 authored invariant를 검증하도록 별도 수정됐다.

- 편액 rail clearance
- 좌우 content margin 대칭
- 반응형 margin/header band
- 여러 viewport 크기에서 margin/header의 단조 증가
- 복원된 active-item strip과 trash drag-source 계약

이 변경은 리팩터링 체크포인트 커밋에 섞지 않고 별도 WIP/테스트-debt 커밋으로 취급한다.

### 18.5 하네스 정정

폐기한 두 전수 결과가 있었다. PowerShell 5.1에서 native executable에 `2>&1`을 적용하면 Godot stderr 각 줄이 `NativeCommandError`로 승격돼 첫 assertion에서 loop가 중단됐다. 이후 `Start-Process -RedirectStandardOutput/-RedirectStandardError`로 분리하고, 다음 runner-equivalent 조건으로 다시 판정했다.

- exit code 0
- 각 테스트의 `ok` marker 존재
- `ERROR:`, `SCRIPT ERROR`, `Parse Error` 부재
- batch runner 완료 marker 존재

따라서 과거 `PASS=10 / FAIL=166` 및 중단된 loop 결과는 무효이며, 이 절의 `163/176`만 유효하다.

### 18.6 최종 종결선

- 리팩터링 검증: 완료
- 리팩터링 회귀: 0건
- focused 통합 gate: 별도 WIP 13건으로 RED
- 전체 suite: 미실행
- 커밋/스테이징: 아직 수행하지 않음

다음 단계는 리팩터링을 더 쪼개는 것이 아니라, 이 범위를 dirty worktree에서 격리해 체크포인트로 고정하는 것이다. A/B/C 실패는 해당 소유 트랙의 별도 후속으로 유지한다.

## 19. 2026-08-10 체크포인트 진행 상황

§18 이후 Codex가 session JSONL의 성공한 `apply_patch` 이력과 현재 HEAD diff를
대조해 commit 경계를 재구성했다. broad stage, reset, checkout, stash는 사용하지
않았다. 상세 allowlist와 근거는
`docs/refactor_checkpoint_2026_08_10_commit_manifest.md`에 있다.

### 19.1 Pause 독립 커밋 완료

- commit: `418165578b631845766d550dc6bf4f415eb23b07`
- subject: `refactor(pause): extract pause menu policy and rendering owners`
- parent: `cd60eee338806b60ec18be5af69161a425f80930`
- 범위: tracked facade/consumer 3개 + 신규 owner 9개/UID + 신규 seal 10개/UID
- 총 41 files, 3,555 insertions, 1,392 deletions
- allowlist 누락 0, 초과 0
- `git diff --cached --check`: exit 0
- commit 후 staged path 0, Pause 대상 dirty path 0

이 묶음은 먼저 alternate index에서 동일한 41경로로 `write-tree`까지 검증했고,
실제 `.git/index`가 비어 있음을 확인한 뒤 같은 path set만 커밋했다. 커밋 직후에는
기존 editor와 별도 headless load가 이미 실행 중이어서 Godot를 중복 기동하지
않았다. 실행 근거는 내용이 같은 커밋 직전 working tree의 Pause 신규 seal 10/10
및 Pause Menu·Runtime Perk 묶음 16/16 GREEN이다.

### 19.2 Runtime Perk·Plaza·Lingpet는 의도적 보류

세 facade의 세션 시작 전 blob을 성공 패치 역복원으로 만들고, HEAD에 세션 delta만
3-way 적용할 수 있는지 검사했다. 셋 모두 세션 시작 전 상태가 HEAD와 달랐고
content conflict가 발생했다.

- `runtime_perk_state.gd`: 현재 facade가 이번 owner 3개 외에도 HEAD 밖의 별도 WIP
  owner 6개를 preload한다.
- `plaza_scene.gd`: 이번 builder 외에 HEAD 밖의
  `plaza_shop_transactions.gd`에도 의존한다.
- `lingpet_egg_runtime.gd`: HEAD 밖 preload는 이번 owner 8개로 닫히지만, 같은
  facade의 선재 WIP와 세션 refactor delta가 충돌한다.

따라서 나머지 owner/seal을 파일 단위로 커밋하면 facade가 빠진 dead code가 되고,
현재 facade 전체를 커밋하면 타 WIP를 무단 편입한다. 각 기반 WIP가 먼저 commit되거나
그 범위를 체크포인트에 포함한다는 명시적 결정이 있기 전까지 working tree에
보존하는 것이 안전하다.

### 19.3 최신 상태 정정

§18.6의 “커밋/스테이징 미수행”은 당시에는 정확했지만 현재는 Pause 한 묶음만
커밋 완료로 바뀌었다. 다른 세 도메인, CI/pre-push, architecture/status 문서,
character-info 별도 WIP는 아직 스테이징하거나 커밋하지 않았다.
