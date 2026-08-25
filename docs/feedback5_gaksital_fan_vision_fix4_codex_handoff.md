# 지시문 Q4-수정4 — 현행 HEAD로 재정렬 + 프레임 샘플링 P2 2건

- **발행**: 관제탑 2026-08-25. 대상: 브랜치
  `codex/fb5-gaksital-fan-vision-20260825`(워크트리
  `D:\codex_tmp\bosspong_fanvision_4755`)의 `9e316ed5c` 위 **추가 작업**.
  본 트리 편집·푸시·통합 금지.
- **판정**: 지시문 Q4-수정3의 두 P1(볼-패스·신화 런타임)과 F10은
  **실제로 닫혔다.** 씰이 스텁이 아니라 진짜 프로덕션 라우터
  (`PaddleBounceSkillRouter` → `SmasherPowerSmashActivationController`,
  `SmasherVoidPhantomState._has_command_input`)를 관통하고, SHARED_PROXY
  반증에서 파워스매싱이 `begin_calls=1`로 실제 발동해 레그가 살아있음을
  증명했다. 부채 투사체 상수 15종도 1:1 확인됐다. **아래 재정렬과 P2 2건만
  닫으면 통합한다.**

## [P0-재정렬] 본 트리가 크게 움직였다 — 브랜치를 현행 HEAD로 다시 맞춰라

`9e316ed5c`는 `284bafd5e`를 흡수한 머지였다. 그 뒤 관제탑이 **그 머지가
품고 있던 본 트리 미커밋 WIP를 5개 클러스터로 분리 착지**시켰고, V1
브랜치도 착지했다.

현행 HEAD = `79c152cca`, 락스텝 **241/241**.

새로 들어온 커밋(전부 `9e316ed5c`에 없음):
- `9e86636d9` vision_modifier 액션 등재 + 짝 씰 2종
- `95a6ee56f` 입력 컨트롤러 리드로우 API
- `b6396d396` 부동갑주 넉백 커버리지 + 각시탈 부채 히트 게이트
  (미추적이던 `tests/stage4_moon_celestial_armor_gauge_smoke.gd` 포함)
- `132a7f4b9` 매치플로 deps 비전초식 3종 + 공허환영 키
- `7555de8a5` 보상 경제 3기능 + 짝 씰 2종
- `ff77cad91`·`33cdbea2f`·`79c152cca` V1 수련 파리티 3커밋

⚠**`git diff HEAD 9e316ed5c`로 통합하면 위 커밋들이 역행한다.** 실측:
그 diff는 `tests/stage4_moon_celestial_armor_gauge_smoke.gd`를 195줄
삭제하고 `tests/guardian_toggle_input_smoke.gd`에서 11줄을 지운다.

1. 브랜치를 **현행 HEAD 위로 재정렬**하라(HEAD를 다시 머지하거나
   Q4 고유 변경만 새 브랜치에 다시 얹는 방식 중 택일).
2. 재정렬 후 **Q4 고유 변경만 남는지** 확인하라. WIP 5클러스터는 이미
   착지했으므로 그 부분은 no-op이어야 한다. 남아야 하는 것:
   비전 프록시·볼패스/신화 배선·부채 투사체 계약 추출·신규 씰 2종·
   QA 툴·CI 등재 2줄.
3. 착지 후 예상 락스텝 = **241 → 243**.

## [P2] Q4F3-1 — 프레임 캐시가 리더 인스턴스 ID로 키잉돼 샘플이 3~4회다

- `battle_scene_actor_update_driver.gd:137`의 `prepare_vision_input_frame`
  캐시 키에 `input_reader.get_instance_id()`가 들어간다. 그런데 프로덕션은
  **서로 다른 객체**를 넘긴다:
  - player control = `battle_update_player_control_deps_builder.gd:65`의
    `Stage3CurseControlInputProxy`(`status_effect_state`가 등록 코어
    모듈이라 전투 중 **항상** 생성됨)
  - ball = `ball_dependency_context.gd:373`의 raw `smasher_input_reader`
  - 신화 2종 = raw
- 프레임 순서 mythic(raw) → player control(curse proxy) → ball(raw)이라
  **3회 전부 캐시 미스** → 매 프레임 `get_snapshot()` 3회 +
  `configure_snapshot()` 3회(각각 `duplicate(true)` 2회)가 **물리
  핫패스**에서 발생한다.
- 게다가 `deps["input_reader"]`가 이제 항상 프록시라
  `smasher_player_controller.gd:354`의 `dash_input_reader == input_reader`
  항등이 영구히 깨져 **프레임당 네 번째** `get_snapshot()`이 추가된다.
- 결과: `:146~149` 주석("none may poll the raw reader a second time")과
  씰 종단선 **`SNAPSHOT=GREEN raw_reader_calls=1`이 둘 다 거짓**이다.
  씰이 세 호출부에 같은 `FakeInputReader`를 넘겨 이 갈림을 구조적으로
  관측하지 못한다.
- 수리: `prepare_vision_input_frame`이 **프레임의 정본 리더를 스스로
  결정**하게 하라 — 호출자가 넘긴 `input_reader`를 캐시 키에서 빼고
  `_get_character_input_reader(owner, registry)`로 한 번만 해석하거나,
  캐시 키를 `frame_key + owner_id`만으로 줄여라.
  씰에 **"플레이어-컨트롤 호출부는 상태 프록시, 볼/신화 호출부는 raw
  리더"** 픽스처 레그를 넣어 `raw_reader_calls == 1`을 진짜로 단언하라.

## [P2] Q4F3-2 — 공유 릴리스 래치가 프레임 중간에 지워져 입력이 샌다

- `vision_modifier_input_proxy.gd:84`의 `_build_filtered_snapshot`은
  "설정된 스냅샷의 `raw_pressed`가 false면" `_suppressed_until_release[channel]`을
  지운다.
- Q4F3-1 때문에 **같은 프레임에 프록시가 raw 스냅샷과 상태-필터 스냅샷으로
  번갈아 재설정**되므로, Shift 해제 프레임에 눌린 채인 버튼의 래치가
  프레임 중간에 지워져 **볼-패스 소비자로 샌다.**
- 수리: 래치 소거를 프레임 경계에서만 하거나, 채널별 `raw_pressed`를
  프레임 정본 스냅샷 하나에서만 판정하도록 좁혀라. Q4F3-1을 고치면
  자연히 닫힐 수 있으니 **함께 처리하고 반증 레그로 증명**하라.

## [P3] 잔여

3. `raw_reader_calls=1` 종단선 문구는 P2를 고치기 전까지 **거짓이므로
   낮춰라.**
4. 비전 미장착 시 프록시가 프레임 스냅샷을 동결하므로
   `viper_input_reader.suppress_primary_pointer_until_release()`의
   같은-프레임 재계산이 프록시 경유 소비자에게 반영되지 않는다. 살아있는
   같은-프레임 2차 소비자는 발견되지 않아 결함으로 채점하지 않았으나,
   주석으로 계약을 명시하라.

## 확인된 무결 (재작업 금지)

- 볼-패스에 **같은 단일 프록시** 주입(새 인스턴스 없음), 신화 2종 프록시
  경유, F10 프로덕션 래치 토글, 비전 미장착 passthrough, UI 입력 보존,
  부채 투사체 상수 1:1, CI 등재 2줄 정상 — 전부 실측 확인.
- 기저 RED 4종(`perk_slot_limit` / `stage_clear_reward_resolver` /
  `treasure_map_perk_port` / `match_player_skill_deps_builder`)은 본 트리와
  ERROR 집합이 바이트 동일해 기저임이 확인됐다. **재정렬 후 다시 대조**하라
  (그 사이 보상 경제가 착지했으므로 `stage_clear_reward_resolver_smoke`의
  실패 집합이 달라질 수 있다).

## 게이트·보고

재정렬 → 포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처. 보고=재정렬 방식과 결과 해시·씰 종단선 원문·
`raw_reader_calls` 실측·락스텝(241→243)·기저 RED 재대조·미해결.
