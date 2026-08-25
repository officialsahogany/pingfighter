# 지시문 Q4-수정3 — 입력 독점이 볼-패스·신화 소비자에 도달하지 않는다

- **발행**: 관제탑 2026-08-25. 대상: 브랜치
  `codex/fb5-gaksital-fan-vision-20260825`(워크트리
  `D:\codex_tmp\bosspong_fanvision_4755`)의 `94b7b29ad` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: 부채던지기 본체(획득·정의·투사체·스턴+넉백)와 프록시 설치
  자체는 잘 만들어졌다. 신규 씰 2종과 수정된 CI 씰 모두 GREEN이고
  경고 0, diff --check 0이다. **그러나 승인된 계약의 핵심인 "전투 입력
  독점"이 두 부류의 소비자에 도달하지 않는다.** 그것과 통합 충돌 2건을
  닫으면 통합한다.

## [P1] F1 — 볼-패스(패들 접촉) 입력 소비자에 프록시가 도달하지 않는다

- 프록시는 `battle_scene_actor_update_driver.gd:94`에서
  `player_control_deps["input_reader"]`에만 설치된다.
- 볼-패스 deps는 `_append_smasher_update_deps`가 레지스트리의 **raw
  `smasher_input_reader`**를 그대로 넣고
  (`ball_dependency_context.gd:373`), `paddle_bounce_skill_router.gd:42`가
  그대로 넘긴다.
- 관측 가능한 실패:
  - 각시탈 비전 장착 + Shift 홀드 + Space/좌클릭 유지로 공을 받아치면
    `smasher_power_smash_activation_controller.gd:19~21`이 raw
    `action_pressed`를 읽어 **파워스매싱/천뢰격이 발동하고 기력이
    차감된다.**
  - 같은 상태 + S + 좌클릭 유지 시 `smasher_void_phantom_state.gd:743~752`가
    같은 경로로 샌다.
- ⚠**씰 1번이 이름 붙인 벽력유성이 정확히 이 경로로 샌다.** 즉 현재
  `CONSUMERS=GREEN smasher=0` 종단선은 이 경로를 검사하지 않은 결과다.
- 수리: 볼-패스 deps에도 **같은 단일 프록시 인스턴스**를 넣어라. 새 프록시를
  만들지 말 것 — GRT-019(공유 스테이트풀 리더 에지 잠식)에 걸린다.
  씰에 **패들 접촉 시점 레그**를 추가해 각 소비자별 0회 발동을 단언하라.

## [P2] F2 — 스냅샷을 우회해 registry 리더를 직접 읽는 신화 런타임 2종

- 승인된 계약은 "스냅샷을 거치지 않고 `Input`을 직접 폴링하는 소비자"까지
  차단하도록 명시했다.
- `mythic_item_odins_eye_runtime.gd:520~530`이 registry에서 캐릭터 리더를
  직접 꺼내 `mouse_left_just_pressed`로 어둠의 늪을 시전한다.
- `mythic_item_horn_strawberry_mask_runtime.gd:395~400`이 같은 방식으로
  뿔딸기 변신 커맨드(left/right/down)를 읽는다.
- 둘 다 `update_mythic_items`에서 `update_player_control`보다 **먼저** 돌아
  프록시를 통과하지 않는다.
- 관측 가능한 실패: 오딘의 눈 페널티 활성 상태에서 Shift + 좌클릭 →
  어둠의 늪 시전. 뿔딸기 가면 보유 시 청린귀 비전의 Shift+좌→우→좌
  커맨드가 변신 커맨드로도 읽힌다.
- 수리: 두 런타임도 프록시 경유로 전환하고 씰에 음성 레그를 추가하라.

## [P0-통합] 본 트리 미커밋 WIP와 정면 충돌 — 착지 전 반드시 해결

관제탑이 통합을 시도하면 **6개 경로에서 "Your local changes would be
overwritten by merge"로 중단**된다. 강제로 밀면 미커밋 작업이 소실된다.

충돌 경로: `godot/project.godot`, `battle_scene_input_controller.gd`,
`battle_update_match_player_skill_deps_builder.gd`,
`stage_clear_reward_resolver.gd`,
`stage1_gaksital_fan_throw_skill_state.gd`,
`tests/stage1_gaksital_fan_throw_smoke.gd`.

1. ★**부동갑주 게이트 보존**: 본 트리
   `stage1_gaksital_fan_throw_skill_state.gd:233`(`is_cleanse_immune`)과
   `:238`(`try_block_player_stun`)에 **미커밋 부동갑주 커버리지 복원**이
   들어가 있는데, 하필 Q4가 통째로 리팩터하는 `_check_player_collision`
   **바로 그 함수 안**이다. 이 두 줄이 사라지면 부동갑주가 각시탈 부채
   스턴을 못 막는다. **리팩터 결과에 이 게이트를 반드시 포함**시켜라.
2. ★**`project.godot` 중복 방지**: 본 트리 `:49`에 이미
   `vision_modifier=` 인풋 액션이 손으로 들어가 있다(`guardian_toggle` 뒤).
   Q4는 같은 액션을 `guardian_toggle` **앞**에 넣는다. 합쳐지면 `[input]`
   섹션에 같은 키가 2개가 되고, Godot ConfigFile은 뒤 정의만 남기므로
   에디터가 한 번이라도 저장하면 한 항목이 조용히 사라진다.
   **본 트리의 기존 위치(`:49`)를 정본으로 삼고 브랜치 쪽 추가를 제거**하라.
3. 나머지 4경로도 본 트리 WIP를 읽고 **양쪽을 합친 결과**를 브랜치에
   반영하라. 관제탑이 통합 시 split-apply할 수 있도록, 보고에
   **경로별로 어느 쪽을 채택했는지** 명시하라.

## [P2] F3 — 워크트리 증거의 신뢰도 공백

- 이 격리 워크트리는 머지베이스(`475523dec`) 시점에 미추적이던 스크립트
  **7종이 통째로 없다**: `smasher_void_phantom_state.gd`,
  `battle_physics_gate_coordinator.gd`, `battle_debug_menu_shortcut_router.gd`,
  `battle_debug_menu_switcher.gd`, `paddle_hit_audio_layers.gd`,
  `smasher_cleanse_renderer.gd`, `smasher_recovery_renderer.gd`.
  본 트리는 `f6fe329ad`·`ea172afdd`·`bec5d78c6`로 전부 착지시켰지만
  브랜치는 그 27커밋을 갖고 있지 않다.
- `.godot/imported`도 10개뿐이다(본 트리 8035개).
- 결과: 워크트리에서만 달지 스모크에 벽 반동 6건 RED가 더 나오고,
  CI 등재 씰 2종(`perk_slot_limit_smoke`, `mystic_dice_offer_rotation_smoke`)은
  `.ctex` 부재로 **컴파일조차 못 해 한 번도 실행된 적이 없다.**
  하필 Q4는 `runtime_perk_catalog.gd:1691`에 각시탈 비전 해금 퍽 항목을
  삽입하는데(GRT-035 공유 목록 삽입), 그 두 씰이 정확히
  `get_debug_perk_entries()`를 순회한다.
- 수리: **브랜치를 현행 HEAD 기준으로 재정렬**하거나(권장), 그것이
  불가하면 최소한 두 씰이 실행 가능한 환경에서 돌린 종단선을 확보하라.
  현재 "CI GREEN" 주장은 이 두 항목에 대해 근거가 없다.

## [P3] F10 — GRT-050 RED 반증이 항상 RED라 반증이 아니다

- `gaksital_vision_input_exclusivity_smoke.gd:395`
  `_verify_release_leak_negative_fixture`가 프록시를 거치지 않은
  `_combat_snapshot()`을 직접 먹인다. raw 스냅샷은
  `down_pressed`+`secondary_action_just_pressed`가 모두 참이라
  **래치를 통째로 삭제하든 두든 언제나 실패**한다.
- 실제 래치 커버리지는 같은 파일 `:380`·`:381`이 담당한다(그 둘은 래치
  제거 시 진짜 RED). `:395` 레그를 프로덕션 래치를 실제로 토글하는
  형태로 바꾸거나 제거하라.

## 확인된 무결 (재작업 금지)

- 비전 미장착 시 완전 무변화(passthrough), UI/시스템 입력 보존,
  단일 스냅샷(`raw_reader_calls=1`), 코만도 홀드 오발동 없음은 실측 확인됐다.
- 백린 탑승 차단이 평시 탑승을 막지 않는다.
- CI·pre-push 등재 2줄(`gaksital_vision_fan_throw_smoke`,
  `gaksital_vision_input_exclusivity_smoke`)은 정상이다. ⚠통합 후 락스텝은
  **240 → 242**가 된다(현재 본 트리 240/240).

## 게이트·보고

포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처. 보고=추가 커밋 해시·씰 종단선 원문·
**볼-패스 레그 결과**·**충돌 6경로 각각의 채택 결정**·미해결.
