# 각시탈·포도대장 미등장 /goal 지시문 (2026-08-21)

- **출처**: 사용자 제보.
  > 각시탈과 포도대장이 **게임에서 등장하지 않는다.** 등장시켜야 한다.
- **기준 HEAD**: 최신. ⚠ 미커밋 WIP 다수. 격리 워크트리에서 작업하고
  `stash`·`checkout`·`reset`·통짜 `git add` 없이 통합 대기하라.
- **완료 보고**: `docs/stage1_variant_boss_routing_report.md`. 푸시 금지.
  **통합하지 말고 보고 후 대기하라.**

## 0. Fable이 확인한 현행 `[확인]`

**런타임은 이미 셋을 전부 지원한다.**

- `stage1_boss_actor_renderer.gd`, `stage1_pillar_scene_drawer.gd`,
  `stage1_pillar_hud_scene_drawer.gd` 가 `gaksi` 분기를 갖는다.
- `stage1_gaksital_fan_throw_skill_state.gd` 등 각시탈 전용 스킬 상태가 있다.
- `tower_ascent_boss_registry.gd:18-19` 에 `floor_01_gaksital`,
  `floor_01_podo` 슬롯이 `STATUS_PORTED` 로 등재돼 있다.

★**그런데 `set_stage1_boss_variant()` 를 부르는 곳이 없다.**
`game_selection_state.gd:114` 에 setter 가 있지만 호출자가 0 이다.
일반 캠페인은 항상 `STAGE1_BOSS_VARIANT_DALJI` 로 고정된다.

## 1. ★먼저 판정하라

- **탑 모드에서는 나오는가?** `_apply_tower_encounter_identity()` 가
  encounter 의 `variant` 를 owner 에 넣는다. 1층 슬롯 셋이 실제로
  무작위 선택되는지 확인하라. 나온다면 결함은 **일반 캠페인 경로에만** 있다.
- **의도된 사양이 무엇인가?** 1층 보스를 무작위로 고르는 것이 설계인지,
  캐릭터·난이도에 따라 정해지는지 확인하라. 관련 기록을 찾아 인용하라.
- 판정 결과를 보고서 맨 앞에 적어라.

## 2. 계약

- 판정에 따라 선택 경로를 배선한다.
- ★**무작위라면 게임플레이 RNG 를 쓸지 판단하고 근거를 적어라.**
  시드 재현성에 영향이 있다.
- ★**`stage1_boss_variant` 는 `stage_boss_variant` 와 다른 키다.**
  합치지 마라. 호환 식별자다.
- ★**세 보스가 전부 실제로 플레이 가능한지 확인하라.** 렌더러가 있다고
  전투가 성립하는 것은 아니다. 스킬·오디오·HUD·전광판 이름·패배 정산까지
  전수 확인하고 표로 남겨라.
- 달지 무손상을 지켜라.

## 3. 씰

- 세 변형 각각이 **실제로 선택될 수 있는지** 단언하라.
- 각 변형에서 **스킬이 발동하는지** 단언하라. 렌더링만 보지 마라.
- ★**전광판·정산 이름**이 각각 맞는지 단언하라.
  ⚠ 그 배선이 미커밋 WIP 이다. 상태를 먼저 확인하라.
- 달지 무손상 부정 레그를 둬라.

## 4. 규율

- 헝크 분리 커밋. 단독으로 씰 GREEN.
- 신규·개정 씰은 두 리터럴 목록에 동시 등재. 현재 195개다.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 푸시 금지.

## 5. 검증

- 씰 + `-Paths` 경고 + 헤드리스 + `git diff --check`.
- **Vulkan 캡처**: 각시탈 전투, 포도대장 전투, 달지 무손상.
- **라이브 확인은 사용자가 본 트리에서 한다.** unverified 로 명시하라.

**완료 선언 조건**: §1 판정 + 구현·검증 + 전수 확인표 + 게이트 blocked 0건.
