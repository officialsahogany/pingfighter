# 비전투 노드 복귀 후 경로 선택 공 미표시 /goal 지시문 (2026-08-20)

- **출처**: 사용자 라이브 제보.
  > 전투 이외 노드 지역(예: 휴식처)에서 일을 본 뒤 다시 노드 경로 선택 공을
  > 발사했을 때 **공이 화면에서 안 보인다.**
- **성격**: ★**P0 회귀. 오늘 착지한 `f4adbea3b` 가 유력한 원인이다.**
- **기준 HEAD**: 최신. ⚠ 본 트리에 미커밋 WIP이 3800건 있다. 격리 워크트리에서
  작업하고 `stash`·`checkout`·`reset`·통짜 `git add` 없이 통합 대기하라.
- ★**새 워크트리를 콜드로 만들지 마라.** 하나가 약 10GB다.
- **완료 보고**: `docs/tower_noncombat_return_selector_hidden_report.md`.
  푸시 금지. **통합하지 말고 보고 후 대기하라.**

## 0. Fable 이 좁힌 용의자 `[확인]`

`f4adbea3b` 가 `battle_scene_drawer.gd` 에 이 게이트를 넣었다.

```gdscript
func _should_draw_tower_battle_playfield(registry: Object) -> bool:
	var flow_owner: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	return (
		flow_owner == null
		or not flow_owner.has_method("has_renderable_retained_noncombat_node_background")
		or not bool(flow_owner.has_renderable_retained_noncombat_node_background())
	)
```

false 면 `_draw_playfield_scene` 을 통째로 건너뛰고
`_draw_tower_ascent_playfield_flow_only` 만 부른다. 그리고 그 함수는
`TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase()` 가
true 일 때만 `flow_owner.draw(canvas)` 를 한다.

### 확인해야 할 두 갈래 ★

**가. 유지 상태가 안 풀린다.**
`_retained_noncombat_background_kind` 는 `_clear_retained_noncombat_node_background()`
로만 풀린다. 호출자는 셋이다.

| 파일 | 줄 | 조건 |
|---|---|---|
| `tower_ascent_flow_map_progress.gd` | 466 | **전투** 노드를 고를 때만 |
| `tower_ascent_flow_ending_progress.gd` | 327 | 확인하라 |
| `tower_ascent_flow_snapshot_progress.gd` | 147 / 155 | 스냅샷 복원 경로 |

★**휴식처에서 볼일을 마치고 경로 선택으로 돌아오는 경로에 clear 가 있는가?**
없다면 배경이 계속 유지되고 플레이필드가 계속 숨겨진다.

**나. 정책이 그 페이즈를 배제한다.**
`tower_ascent_screen_space_surface_policy.gd:3`

```gdscript
const FLOW_PHASES := ["MAP_OVERLAY", "MAP_TRANSITION", "NODE_MODAL"]
```

경로 선택 페이즈 이름이 무엇인지 확인하고, 그 페이즈에서
`uses_playfield_flow_phase()` 가 실제로 true 인지 판정하라.

★**둘 중 어느 쪽인지, 혹은 둘 다인지 실측으로 가려라.** 정적 분석만으로
확정하지 마라. 실제 페이즈 이름과 유지 상태를 찍어 보라.

## 1. 계약

- ★**공이 안 보이는 것이 증상이다. 무엇이 공을 그리는지부터 파일:줄로
  지명하라.** 경로 선택 공(selector)이 flow 소유인지 플레이필드 소유인지
  확인하고 보고서에 적어라.
- 수정 방향은 판단하되 근거를 적어라. **유지 해제 지점을 추가하는 쪽**과
  **정책을 넓히는 쪽**은 부작용이 다르다.
- ★**비전투 노드 안에 있을 때 이전 보스가 다시 보이면 안 된다.**
  `f4adbea3b` 가 고친 것이 그것이다. 되돌리지 마라.
- ★**전투 노드 복귀 시 정상 복귀**를 유지하라.

## 2. 씰 ★

- **휴식처 → 볼일 종료 → 경로 선택** 순서로 태우고, 그 프레임에서
  선택 공이 **실제로 그려지는지** 단언하라. 플래그가 아니라 드로 결과다.
- **비전투 노드 안에서는 이전 보스가 안 그려지는지** 단언하라(무손상).
- **전투 노드 복귀** 부정 레그를 둬라.
- ★**픽셀로 확인하라.** 구조 단언만으로는 부족하다. 비헤드리스 캡처에서
  선택 공 픽셀을 세라.
- 회귀를 되살리면 RED 가 나는 반증 레그를 남겨라.

## 3. 규율

- 헝크 분리 커밋. 단독으로 씰 GREEN.
- 신규·개정 씰은 두 리터럴 목록에 동시 등재. 현재 190개다.
- ⚠ 씰 레그를 추가하면 `_leg_count` 류 상수를 함께 갱신하라.
- ⚠ `battle_scene_drawer.gd` 는 전 스테이지 공용이다. 비탑 경로가
  영향을 받으면 안 된다. 부정 레그를 둬라.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 푸시 금지.

## 4. 검증

- 씰 + `-Paths` 경고 + 헤드리스 + `git diff --check`.
- **Vulkan 캡처**, 실 해상도(2020x1246).
  - 휴식처 복귀 후 경로 선택 공이 보이는 프레임
  - 비전투 노드 내부에 이전 보스가 없는 프레임
  - 전투 노드 복귀
- **라이브 확인은 사용자가 본 트리에서 한다.** unverified 로 명시하라.
- 판정 불가 지점이 나오면 중단·보고.

**완료 선언 조건**: 원인 확정 + 수정·검증 + 반증 RED + 게이트 blocked 0건.
