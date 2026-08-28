# 지시문 Z1 [P0] — 초식 슬롯 트림이 배운 초식을 영구 삭제한다

- **발행**: 관제탑 2026-08-28. 기준선 = 본 트리 **`715535055`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **분류**: **데이터 손실 P0.** 플레이어가 획득한 초식이 말없이 사라진다.

## 사용자 보고

> 절세무공 **천문개결**로 초식 슬롯이 1개 늘어나 **5/6** 인 상태에서
> 스테이지 클리어 후 **비전초식을 배워 6/6** 이 됐는데, 파계승 노드에서
> 새 초식을 클릭하자 **초식 교체 화면이 뜨지 않고 마지막 배운 비전초식이
> 사라지면서** 파계승 초식이 등록됐다.

## ★진범 (관제탑 확정 — 재조사 금지)

`godot/scripts/characters/smasher_skill_config.gd` (형제 config 전부 동형)

```gdscript
func set_item_skill_slot_bonus(slot_bonus: int) -> Array:
	item_skill_slot_bonus = max(0, int(slot_bonus))
	return _trim_equipped_skills_to_max()

func _trim_equipped_skills_to_max() -> Array:
	var removed: Array = []
	var max_slots: int = get_max_skill_slots()
	while equipped_skills.size() > max_slots:
		removed.append(equipped_skills.pop_back())   # ★마지막 배운 것부터 버린다
	return removed
```

★**`pop_back()`** 이다. 사용자 증언 "**마지막 배운** 비전초식이 사라진다" 와
정확히 일치한다.

`godot/scripts/items/mythic_item_owner_syncer.gd:735~742`

```gdscript
var skill_slot_bonus: int = runtime.get_heavenly_cape_skill_slot_bonus()
for key in [...5개 skill_config...]:
	var removed_value: Variant = skill_config.set_item_skill_slot_bonus(skill_slot_bonus)
	if removed_value is Array:
		cleanup_removed_player_skills(runtime, registry, removed_value)   # ★영구 삭제
```

`cleanup_removed_player_skills` 는 버려진 스킬을
**`runtime_perk_state.runtime_skill_levels` 에서 `erase`** 한다.
장착 해제가 아니라 **보유 기록 자체를 지운다.**

### 확정 사실

- **천문개결 = `heavenly_cape` 퍽이다**(같은 것의 개명).
  `runtime_perk_catalog.gd:1067~1077`, `"descriptions": {1: "초식 슬롯 +1, ..."}`.
  따라서 보너스 출처는 하나뿐이고 "두 출처 충돌"이 아니다.
- `unlock_and_equip_skill` 은 만석이면 **false 를 반환하고 덮어쓰지 않는다.**
  즉 **파계승 등록이 비전을 지운 것이 아니다.** 트림이 먼저 지웠다.
- 파계승의 교체 UI 게이트는
  `tower_ascent_fallen_monk_node.gd:151`
  `if _is_shared_slot_full(skill_config) and not swap_candidates.is_empty():`
  트림이 이미 한 자리를 비웠으면 **만석이 아니므로 교체 UI 가 뜨지 않고**
  그냥 등록된다. **증상 세 개가 이 하나의 기전으로 전부 설명된다.**

## ★네가 증명할 것 — 트림이 왜 발동했나

`get_heavenly_cape_skill_slot_bonus()` 가 **일시적으로 0(또는 낮은 값)** 을
돌려주는 순간에 `sync_skill_cooldown_to_configs` 가 돌면 상한이 5로 내려가고
6번째가 잘린다. 관제탑 가설은 **동기화 시점 staleness** 다.

**증명하라.**
1. `sync_skill_cooldown_to_configs` 가 **스테이지 클리어 → 노드 이동 구간에서
   언제 몇 번 불리는지** 계측하라.
2. 그 각 시점의 `get_heavenly_cape_skill_slot_bonus()` 반환값을 찍어라.
3. `_trim_equipped_skills_to_max()` 가 **실제로 무엇을 몇 개 버렸는지** 찍어라.
4. **재현 픽스처**를 만들어라 — 천문개결 보유 + 초식 6/6 + 클리어 → 노드 이동.
   트림이 발동하면 그 시점의 보너스 값과 호출 스택을 보고하라.

⚠**원인을 특정하기 전에 고치지 마라.** 트림 자체를 없애면 보너스가 정말로
줄어드는 정상 경로(천문개결 상실 등)에서 초과 장착이 남는다.

## 요구

1. **보유 기록을 파괴하지 마라.**
   `cleanup_removed_player_skills` 가 `runtime_skill_levels` 에서 `erase` 하는
   것이 옳은지 판정하라. 관제탑 견해로는 **장착 해제와 보유 삭제는 분리**
   되어야 한다. 슬롯이 줄면 장착만 풀고 보유는 남기는 것이 자연스럽다.
   **판정 결과와 근거를 보고하라. 임의로 바꾸지 말고 관제탑 판정을 기다려라.**
2. **`pop_back()` 선택 기준을 재검토하라.** "마지막 배운 것"을 버리는 것은
   플레이어에게 가장 억울한 선택이다. 무엇을 버릴지가 정책이라면 명문화하고,
   아니라면 **플레이어가 고르게** 해야 한다.
3. **트림이 발동하면 조용히 넘어가지 마라.** 최소한 로그, 가능하면 플레이어
   고지가 필요하다. 지금은 아무 흔적이 없다.
4. **파계승 교체 UI 게이트**는 트림이 고쳐지면 자연히 정상화될 수 있다.
   그래도 **만석 판정이 시점 의존적이지 않은지** 확인하라.

## 씰 요구

1. ★**재현 씰**: 천문개결 보유 + 초식 6/6 → `sync_skill_cooldown_to_configs`
   호출 → **장착과 보유가 모두 유지**되는지 단언하라.
   수리 전 코드에서 RED 가 되는지 **반증**하고 원상복구하라.
2. **정상 축소 경로 씰**: 천문개결을 **실제로 잃었을 때**는 장착이 6→5로
   줄어야 한다. 트림을 통째로 없애면 이 레그가 RED 가 된다.
3. **파계승 만석 교체 UI 씰**: 6/6 에서 클릭하면 교체 화면이 뜬다.
4. **CI/pre-push 락스텝.** ⚠**현재 251/251 이다.** 통째 교체 금지.
   착지 전후 항목 집합을 `comm` 으로 대조해 **사라진 항목 0** 을 증명하라.

## ★알려진 기준선 RED (이 작업 탓 아님 — 반드시 읽어라)

관제탑이 **HEAD `715535055` 의 깨끗한 격리 워크트리**(미추적 0·더티 0,
신선한 클론과 동일)에서 CI 씰 251건을 돌린 결과 **다수가 RED** 다.
`docs/untracked_preload_dependency_audit_2026_08_27.md` 참조.

⚠**네 작업 전에 기준선을 먼저 재고, 네가 만든 RED 와 선재 RED 를 반드시
구분해서 보고하라.** 선재 RED 를 고치려 들지 마라. 범위 밖이다.

## 게이트·보고

포커스드 스모크(+반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs` 를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

## 보고

커밋 해시 · **트림 발동 시점과 그때의 보너스 값(계측 로그)** ·
`cleanup_removed_player_skills` 의 보유 삭제 판정과 근거 ·
`pop_back` 선택 기준 판정 · 파계승 게이트 시점 의존성 확인 ·
재현 씰 반증 종단선 · 정상 축소 경로 씰 · **기준선 RED 대비 신규 RED 0 증명** ·
CI 항목 집합 대조 · 미해결.
