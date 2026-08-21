# 전투 금화 HUD 실시간 미반영 /goal 지시문 (2026-08-21)

- **출처**: 사용자 라이브 제보.
  > 전투에서 좌측 금화 HUD 가 실시간 증가를 반영하지 않고 **항상 0** 이다.
  > **무혼은 정상 연동**된다.
- **성격**: ★**오늘 착지한 `f4adbea3b` 의 후속이다.** 재화 출처를 런 경제로
  바꾼 결과다.
- **기준 HEAD**: 최신. ⚠ 미커밋 WIP 다수. 격리 워크트리에서 작업하고
  `stash`·`checkout`·`reset`·통짜 `git add` 없이 통합 대기하라.
- **완료 보고**: `docs/tower_battle_gold_hud_live_sync_report.md`. 푸시 금지.
  **통합하지 말고 보고 후 대기하라.**

## 0. 배경 `[확인]`

`stage1_pillar_hud_scene_drawer.gd`

```gdscript
func _build_gold_hud_amount(context: Dictionary, registry: Object) -> int:
	var tower_economy := _get_tower_run_economy(registry)
	if not tower_economy.is_empty():
		return maxi(0, int(tower_economy.get("gold", 0)))
	return maxi(0, _get_cached_plaza_gold(context, registry) + _get_runtime_gold(context, registry))
```

사용자 확정 "가"안(탑 런은 자기 경제만 쓴다)에 따른 배선이다.

**무혼이 정상인 이유**는 무혼이 전투 중 즉시 런 상태로 적립되기 때문이다.
**금화는 전투 중 `runtime_perk_gold` 에 쌓이고 런 상태에는 반영되지 않는다.**
그래서 런 경제만 읽는 HUD 가 계속 0 이다.

★**어느 쪽이 결함인지 판정하라.** 표시가 틀린 것인가, 적립 경로가 런 상태에
연결되지 않은 것인가. 둘의 수정 지점이 완전히 다르다.

## 1. 계약

- ★**"가"안 결정을 뒤집지 마라.** 탑 런은 자기 경제만 쓴다. 사용자 확정이다.
  광장 골드를 다시 섞는 것은 답이 아니다.
- ★**필러 HUD 와 상점 모달이 같은 값을 보여야 한다.** 그것이 "가"안의
  목적이었다. 어느 방향으로 고치든 이 불변식을 지켜라.
- 전투 중 획득한 금화가 **어디에 적립되는지** 파일:줄로 지명하라.
  그것이 런 경제로 흘러야 하는지, 아니면 전투 종료 정산에서 합쳐지는지
  기획 의도를 `docs/tower_ascent_run_map_plan.md` §3.16 에서 확인하라.
- ★**비탑 일반 캠페인은 종전 합산 표시를 유지**해야 한다.

## 2. 씰

- 탑 전투 중 금화를 적립하고 **HUD 값이 따라 오르는지** 단언하라.
  플래그가 아니라 표시 값이다.
- **필러 HUD 값과 상점 모달 값이 같은지** 단언하라.
- **무혼 무손상** 부정 레그를 둬라. 지금 정상이다.
- **비탑 캠페인 합산 표시 무손상** 부정 레그를 둬라.
- ★**드로 경로에서 무거운 조회를 늘리지 마라**(GRT-042). 지금 구조가
  non-instantiating peek 다. 유지하라.

## 3. 규율

- 헝크 분리 커밋. 단독으로 씰 GREEN.
- 신규·개정 씰은 두 리터럴 목록에 동시 등재. 현재 193개다.
- ⚠ 씰 레그를 추가하면 `_leg_count` 류 상수를 함께 갱신하라.
- 내부 식별자 `gold` 는 호환 식별자다. 바꾸지 마라.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 푸시 금지.

## 4. 검증

- 씰 + `-Paths` 경고 + 헤드리스 + `git diff --check`.
- **Vulkan 캡처**: 금화 적립 전후의 필러 HUD, 같은 시점의 상점 모달.
- **라이브 확인은 사용자가 본 트리에서 한다.** unverified 로 명시하라.

**완료 선언 조건**: 결함 방향 판정 + 구현·검증 + 게이트 blocked 0건.
