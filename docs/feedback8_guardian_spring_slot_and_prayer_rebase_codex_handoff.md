# 지시문 X1-재작성 — 새 입력 라우터 구조 위로 옮겨라

- **발행**: 관제탑 2026-08-26. 기준선 = 본 트리 **`44aafd425`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **판정 이력**: X1 은 **기능적으로 이미 통과했다.** 두 번 반려를 거쳐
  `5e0b386aa` 에서 P0·P2 가 전부 닫혔고 관제탑이 확인했다.
  **착지가 막힌 이유는 입력 컨트롤러 충돌 하나뿐이었다.**
- **이 지시문은 재작성이 아니라 이식이다.** 기능을 다시 설계하지 마라.

## ★먼저 읽어라

| | 문서 | 커밋 |
|---|---|---|
| 원 지시문 | `docs/feedback8_guardian_spring_slot_and_prayer_codex_handoff.md` | 기준선 `0bd1ee89c` |
| 1차 반려 | `..._fix_codex_handoff.md` | `8ce16ec88` |
| 2차 반려 | `..._fix2_codex_handoff.md` | `031d59beb` |
| 통과 | — | **`5e0b386aa`** ← 이식 원본 |
| **지금** | 이 문서 | 재기준 |

기존 브랜치 `codex/feedback8-guardian-spring-slot-prayer-20260826`
(워크트리 `D:\codex_tmp\bosspong_feedback8_guardian_x1_0bd1`)의 `5e0b386aa`
가 이식 원본이다. **그 워크트리는 아직 있다.**

---

## 무엇이 바뀌었나

X1 이 보류된 사이 **R1(`d0f922873`)이 입력 라우터 분해를 완결**했다.

`battle_scene_overlay_input_controller.gd` 가 678줄 monolith 에서 **파사드**가
됐고 라우터 6종이 추출됐다. X1 이 그 파일에 넣으려던 블록이 쓰던 심볼
(`_is_guardian_spring_chosik_swap_active`, `_get_module`,
`_get_registry_instance`)은 **이제 그 파일에 없다.**

그래서 `5e0b386aa` 를 그대로 착지시킬 수 없다.

## ★R1 이 만들어 둔 삽입 이음매 (여기에 넣어라)

`godot/scripts/core/battle_lingpet_priority_input_router.gd`

```gdscript
func handle_input(
	event, owner, registry, module_getter, view_size,
	pre_overflow_modal_router: Object = null
) -> bool:
	if _call_modal_gate_bool(module_getter, "is_lingpet_acquire_cutin_active"):
		_handle_acquire_cutin_input(...)
		return true
	# Stable X1 insertion seam: acquisition -> pre-overflow modal -> overflow.
	if _handle_pre_overflow_modal_input(pre_overflow_modal_router, ...):
		return true
	if _call_modal_gate_bool(module_getter, "is_lingpet_overflow_choice_active"):
		...
```

그리고 어댑터가 **삼킴 규칙을 소유한다**:

```gdscript
func _handle_pre_overflow_modal_input(modal_router, ...) -> bool:
	if (modal_router == null
		or not modal_router.has_method("is_active")
		or not bool(modal_router.call("is_active", module_getter))):
		return false
	if modal_router.has_method("handle_input"):
		modal_router.call("handle_input", event, owner, registry, module_getter, view_size)
	return true          # ← handle_input 반환값과 무관하게 삼킨다
```

**우선순위가 보존된다**: 획득 컷인 → **샘터 초식 교체** → 오버플로 선택.
**모달이 활성이면 내부 handler 가 무시해도 입력이 뒤로 새지 않는다.**

## 요구

1. **`5e0b386aa` 의 비입력 부분을 전부 그대로 가져와라.**
   샘터 노드, 자립 오버레이 호스트, 다국어, 씰, 프레임 컨트롤러/모달 게이트
   배선 등. **기능을 다시 설계하지 마라.**
   ⚠기준선이 `0bd1ee89c` 에서 `44aafd425` 로 바뀌었으니 그 사이 착지한 것들
   (X4·X5·X6·W2·W4·Z1·Z2·R1)과 3-way 로 맞춰라.
2. **입력 블록만 새 구조로 옮겨라.**
   - `guardian_spring_chosik_swap` 전용 라우터를 만들어라.
   - `is_active(module_getter) -> bool` 과
     `handle_input(event, owner, registry, module_getter, view_size)` 를 노출하라
     (위 어댑터가 부르는 시그니처 그대로).
   - 그것을 `pre_overflow_modal_router` 로 주입하라. 주입 지점은
     `battle_scene_overlay_input_controller` 파사드다.
   ⚠**`battle_lingpet_priority_input_router.gd` 의 이음매 자체를 고치지 마라.**
   고쳐야 한다면 그 이유를 보고하고 관제탑 판정을 기다려라.
3. **X1 이 원래 넣던 ESC/포인터 소유권**이 새 구조에서도 동일한지 확인하라.
   `battle_scene_input_controller` 오버레이 화이트리스트 등재도 여전히 필요한지
   판정하라(파사드 구조에서 불필요해졌을 수 있다).

## 씰 요구

1. ★**우선순위 씰 확장(필수)**: 신규
   `battle_overlay_input_priority_preservation_smoke.gd`(R1 이 만들었다)에
   **샘터 초식 교체 레그**를 추가하라 —
   - 획득 컷인과 교체 모달이 **동시 활성**일 때 획득 컷인이 먹는다
   - 교체 모달과 오버플로가 **동시 활성**일 때 교체 모달이 먹는다
   - **교체 모달이 활성이면 내부 handler 가 false 를 반환해도 입력이
     뒤의 타워 모달로 새지 않는다**
   각각 순서를 뒤집으면 RED 가 되는지 **반증**하고 원상복구하라.
2. **`5e0b386aa` 의 기존 씰 전부 GREEN 유지.** 특히
   `tower_guardian_spring_slot_and_prayer_smoke`,
   `tower_ascent_guardian_spring_node_smoke`,
   `tower_guardian_spring_presentation_smoke`,
   `tower_guardian_spring_chosik_bridge_smoke`.
3. **프레임당 1회 씰**(`unlock_swap_dialog_draw_calls == 1`)이 새 구조에서도
   유효한지 확인하라. R1 이 파사드를 바꿨으므로 재확인이 필요하다.
4. **CI/pre-push 락스텝.** ⚠**현재 248/248 이다.**
   통째 교체하지 말고 필요한 줄만 추가하라.

## 이미 통과했으니 재작업 금지

- 초식 만석 2단 교체(신호 보존 + 롤백 예외 + 확정 레그 후처리)
- 방문당 1행동 + **첫 수호령 선택은 같은 방문 유지**
- 결과 문구 `"모든 능력치가 3.0%p 상승했습니다."` KO/EN/ZH/JA
- 자동 진행이 `_try_enter_route_aim_from_node_modal` 하나만 통과
- 교체창 암막(`DIM_CORNER_PIXELS=25600`)과 프레임당 1회 렌더
- 5지선다 카드 아이콘/이름 간격 4px

## 게이트·보고

포커스드 스모크(+우선순위 반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` → **픽셀 QA(교체창 암막)**.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 커밋 해시 · **신규 라우터의 `is_active`/`handle_input` 구현** ·
**주입 지점** · 우선순위 씰 3레그 종단선과 RED 반증 ·
기존 씰 GREEN 유지 확인 · 화이트리스트 등재 판정 · 미해결.

## 알려진 선재 RED (이 작업 탓 아님)

- 전체 경고 스캔 RED — 파스 오류 경로 테스트 17 + 도구 2.
  CI 등재 3건은 도입 시점부터 무효였다.
- `tower_ascent_flow_owner_refactor_smoke` — `tower_ascent_flow_runtime.gd`
  710줄 vs 500줄 예산.
