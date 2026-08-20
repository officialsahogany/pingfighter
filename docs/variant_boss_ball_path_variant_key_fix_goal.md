# 변형 보스 공-경로 variant 키 누락 /goal 지시문 (2026-08-20)

- **출처**: 사용자 라이브 제보.
  > 2층(아라크네·두더지왕), 3층(엘리스·테디베어) 보스 스킬이 작동을 안 하거나
  > 엉망이다. **두더지왕과 엘리스는 모든 스킬이 발동되지 않는다.**
- **성격**: P0. 포팅된 변형 보스 4종 전부가 영향을 받는다.
- **기준 HEAD**: 최신. ⚠ 본 트리에 미커밋 WIP이 3600건 있다. 격리 워크트리에서
  작업하고 `stash`·`checkout`·`reset`·통짜 `git add` 없이 통합 대기하라.
- ★**새 워크트리를 콜드로 만들지 마라.** 워크트리 하나가 약 10GB다.
- **완료 보고**: `docs/variant_boss_ball_path_variant_key_fix_report.md`. 푸시 금지.
  **통합하지 말고 보고 후 대기하라.**

## 0. Fable이 확정한 원인 `[확인]`

### 진범

`godot/scripts/ball/ball_update_owner_snapshot.gd:54-55`

```gdscript
"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
"stage1_boss_variant": str(_get_owner_value(owner, "stage1_boss_variant", "dalji")),
```

**`stage1_boss_variant` 은 있는데 `stage_boss_variant` 이 없다.**

스테이지 1 은 전용 키를 쓰고, 2·3층 변형 보스는 `stage_boss_variant` 를 쓴다.
**공 경로 스냅샷에 후자만 빠졌다.**

### 전파 경로

`paddle_bounce_boss_post_hit_handler.gd:65-72` 가 공 경로 컨텍스트로
`register_boss_hit(next_ball_vel, context, deps)` 를 부른다. 그 컨텍스트에
`stage_boss_variant` 이 없으니 `""` 다.

`stage3_boss_variant_skill_state.gd:39` (2층은 `stage2_...:39`)

```gdscript
active_variant = StageBossVariantCatalog.normalize_variant(3, context.get("stage_boss_variant", ""))
```

`""` 는 카탈로그에 없으므로 `normalize_variant` 가 **기본값으로 정규화**한다
(`stage_boss_variant_catalog.gd:53-58`). 3층은 `yeonmyo`, 2층은 `cheongringwi`.

따라서 보스를 때릴 때마다 `super.register_boss_hit()`, 즉 **기본 보스의 스킬
로직**이 돈다. 화면의 변형 보스와 무관하다.

### 증상이 보스마다 다른 이유

| 보스 | 스킬 발동 위치 | 결과 |
|---|---|---|
| **두더지왕** | 회전발톱=hit / 땅굴습격=update(게이지 500 필요) | ★**전멸** |
| **엘리스** | 거울세계·크기변화·토끼 셋 다 hit | ★**전멸** |
| 테디베어 | 넷 다 hit | 연묘 스킬이 대신 발동 = 엉망 |
| 아라크네 | 거미줄덫=hit / 구조=update | 청린귀 스킬이 대신 발동 = 엉망 |

★**게이지는 `register_boss_hit` 에서만 오른다.** 그래서 두더지왕은 update
경로의 땅굴습격까지 같이 죽는다. 사용자가 "모든 스킬"이라고 한 것이 정확하다.

### 부수 결함 — `active_variant` 뒤집힘

`active_variant` 는 변형 skill state 의 **공유 멤버 변수**다.

- `update()` 는 효과 경로 컨텍스트를 받아 **올바른 변형**을 넣는다.
- `register_boss_hit()` 는 공 경로 컨텍스트로 **기본값으로 덮어쓴다.**

**히트가 날 때마다 값이 뒤집힌다.** 그 사이에 `get_snapshot()`,
`get_hud_context()`, `get_actor_draw_context()`, `get_boss_gauge_progress()`,
`is_deadly_hug_dash_blocked()` 가 호출되면 엉뚱한 보스 데이터를 반환한다.
이것들도 전부 `active_variant` 로 분기한다.

### 왜 기존 스모크가 못 잡았나

`stage2_molewang_boss_port_smoke`, `stage2_arachne_boss_port_smoke`,
`stage3_alice_boss_port_smoke`, `stage3_teddy_bear_boss_port_smoke`
**넷 다 GREEN 이다.** Fable 이 직접 돌려 확인했다.

**컨텍스트를 손으로 만들어 넣기 때문**이다. 실제
`ball_update_owner_snapshot.build()` 를 거치지 않으니 키 누락이 안 잡힌다.

⚠ **GRT-018 그대로다.** 효과 경로 컨텍스트의 값을 공 경로에서 읽는 트랩.

## 1. 슬라이스

| 순서 | 슬라이스 | 내용 |
|---|---|---|
| S1 | 키 복원 | 공 경로 스냅샷에 `stage_boss_variant` |
| S2 | 폴백 방향 | 기본 보스로 떨어지지 않게 |
| S3 | 형제 전수 조사 | 같은 누락이 또 있는지 |
| S4 | 씰 | 실 스냅샷 관통 ★핵심 |

## 2. 계약

### S1. 키 복원

- `ball_update_owner_snapshot.gd` 가 `stage_boss_variant` 를 싣게 하라.
- ★**기본값은 `""` 로 두라.** `"dalji"` 처럼 특정 변형을 기본값으로 넣지 마라.
  빈 값이어야 S2 의 fail-closed 가 성립한다.
- ★**이 스냅샷은 프레임마다 만들어진다.** 문자열 읽기 한 번은 싸지만
  무거운 조회를 추가하지 마라. `_get_owner_value` 한 번으로 끝내라.
- ★`stage_boss_variant` 는 `battle_scene_state.gd:98` `DEFAULT_VALUES` 에
  이미 선언돼 있다. 확인하고 재선언하지 마라(GRT-017).

### S2. 폴백 방향 ★설계 판정

지금은 값이 없으면 **기본 보스의 스킬 로직**으로 떨어진다. 이것이 "엉망"의
정체다. **아무 일도 안 하는 것보다 나쁘다.** 플레이어는 엉뚱한 보스의 스킬을
맞는다.

- 공 경로에서 변형을 **재정규화하지 말고**, `update()` 가 확정한
  `active_variant` 를 쓰는 방안을 검토하라. 다만 ★**호출 순서에 의존하게
  되므로** 그 순서가 보장되는지 증명해야 한다. 못 하면 이 안을 버려라.
- 또는 공 경로 컨텍스트에 변형 키가 **없을 때** 기본값으로 정규화하지 말고
  **직전 값을 유지**하거나 **아무 분기도 타지 않게** 하라.
- ★**어느 쪽이든 근거를 보고서에 적어라.** 판정이 갈리면 중단하고 물어라.
- ★**기본 보스(연묘·청린귀) 자신은 깨지면 안 된다.** 변형이 아닌 정상
  플레이에서 기본 보스 스킬은 그대로 돌아야 한다. 부정 레그를 둬라.

### S3. 형제 전수 조사 ★

**같은 사고가 다른 키에도 있을 수 있다.**

- `battle_scene_state.gd` `DEFAULT_VALUES` 의 키 중 **공 경로 스냅샷에
  실리지 않은 것**을 목록화하라. 전부가 실려야 하는 것은 아니다.
  **공 경로 소비자가 읽는데 안 실린 것**만 결함이다.
- 판정 방법: `scripts/ball/` 과 그 호출 대상에서 `context.get("<key>"` 를
  수집하고, 스냅샷이 싣는 키 집합과 조인하라.
- ⚠ **단일 검색어로 판정하지 마라.** `context.get`, `ctx.get`,
  `_context.get` 형태가 섞여 있을 수 있다.
- ⚠ **grep 0건을 도달 불가의 증거로 쓰지 마라.** 동적 호출과 duck typing 이
  많은 저장소다.
- 결과를 표로 남겨라. 이번에 고칠 것과 무해한 것을 갈라라.

### S4. 씰 ★이 목표의 핵심

**기존 스모크 4개가 전부 GREEN 인 채로 이 결함이 라이브에 나갔다.**
씰을 고치지 않으면 다음에 또 나간다.

- ★**실제 `ball_update_owner_snapshot.build(owner)` 를 관통하라.**
  손으로 만든 컨텍스트로 단언하지 마라. 그것이 이 결함을 놓친 이유다.
- 네 변형 각각에 대해, **owner 에 변형을 세팅하고 → 실 스냅샷을 만들고 →
  실 `register_boss_hit` 을 태워 → 그 변형의 스킬이 실제로 발동하는지**
  단언하라. 플래그가 아니라 **결과**를 봐라.
- ★**두더지왕 회전발톱을 대표 레그로 삼아라.** 코스트 60, 히트당 획득 60,
  확률 롤 없음이다. **첫 보스 히트에 반드시 발동해야 한다.** 확률이 없으니
  판정이 결정론적이다.
- **게이지가 실제로 오르는지** 단언하라. 게이지가 0에 머무는 것이 두더지왕
  전멸의 직접 원인이다.
- ★**`active_variant` 가 히트 후에도 유지되는지** 단언하라.
  update → hit → `get_snapshot()` 순서로 태우고 변형이 안 뒤집히는지 본다.
- ★**스냅샷에서 키를 빼면 RED 가 나는** 반증 레그를 남겨라.
  이것이 회귀 차단의 본체다.
- 기본 보스 무손상 부정 레그를 둬라.
- 가능하면 **네 변형 공통 씰 하나**로 만들어라. 보스마다 따로 만들면
  다음 변형에서 또 빠진다.

## 3. 범위 밖

- 각 보스의 **개별 파리티 결함**은 별개 작업이다. 원본 Python 과 수치가
  다르다거나 연출이 빠진 것은 여기서 고치지 마라. **이 지시문은 "발동 자체가
  안 되는" 구조 결함만 다룬다.**
- 스테이지3 좌상단 창 문제는 `docs/stage3_variant_transform_reset_fix_goal.md`
  가 소유한다. 건드리지 마라.
- 스킬카드 아트 결손은 `docs/stage3_variant_skillcard_art_goal.md` 소유다.

## 4. 규율

- 슬라이스마다 헝크 분리 커밋 1개. 각 슬라이스는 **단독으로 씰 GREEN**이어야 한다.
- 신규·개정 씰은 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1` **두 리터럴 목록에 동시 등재**한다.
  ⚠ **실패하는 씰을 넣지 마라.**
- ⚠ 씰 레그를 추가하면 그 파일의 `_leg_count` 류 단언 상수를 **함께 갱신**하라.
- ⚠ `ball_update_owner_snapshot.gd` 는 **전 스테이지 공 경로의 정본**이다.
  여기를 건드리면 모든 스테이지가 영향을 받는다. 키 추가 외의 개조를 하지 마라.
- 내부 식별자와 스킬 id 는 호환 식별자다. 바꾸지 마라.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 푸시 금지.

## 5. 검증

- 슬라이스별 씰 + `-Paths` 경고 + 헤드리스 + `git diff --check`.
- ★**기존 보스 포팅 스모크 4개를 반드시 재실행하라.** 지금 GREEN 이며
  수정 후에도 GREEN 이어야 한다.
- ★**공 경로를 쓰는 다른 스테이지 스모크도 돌려라.** 스냅샷은 공용이다.
- **Vulkan 캡처**, 실 해상도(2020x1246).
  - 두더지왕 전투에서 회전발톱이 발동한 프레임
  - 엘리스 전투에서 스킬이 발동한 프레임
  - 테디베어에서 연묘 스킬이 아닌 자기 스킬이 나오는 프레임
  - 기본 보스(연묘 또는 청린귀) 무손상
- **라이브 확인은 사용자가 본 트리에서 한다.** 구조 게이트까지 하고
  라이브 항목은 unverified 로 명시해 보고하라.
- 판정 불가 지점이 나오면 중단·보고.

**완료 선언 조건**: S1·S2·S4 구현·검증 + S3 조사표 + 반증 RED 증거 +
기존 스모크 4개 GREEN 유지 + 게이트 blocked 0건 + 보고서 완성.
