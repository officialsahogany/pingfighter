# 지시문 Z2 — 퐁크 각성 오오라가 노드 화면에 잔상으로 남는다

- **발행**: 관제탑 2026-08-28. 기준선 = 본 트리 **`7561584d6`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **선례**: **Y7(`8204cdc56`, 소나기 젖음 FX)과 같은 유형이다.**
  그 커밋을 먼저 읽어라. 구조를 그대로 재사용할 수 있다.

## 사용자 보고

> 스테이지4 **퐁크가 각성했을 때 퐁크 주변의 오오라가 잔상처럼 남아서**
> 다른 **노드 선택 화면에서도 잔상이 남아 있는** 버그.

## ★진범 (관제탑 확정 — 재조사 금지)

**스테이지4 퐁크 FX 호스트 코디네이터에 `tear_down` 이 하나도 없다.**

| 호스트 | `tear_down` 정의 | 코디네이터 호출 |
|---|---|---|
| `stage4_ponk_awaken_aura_fx_host.gd` | 있음 | **0** |
| `stage4_ponk_magnetic_fx_host.gd` | 있음 | **0** |
| `stage4_ponk_meditation_fx_host.gd` | 있음 | **0** |
| `stage4_ponk_illusion_ripple_fx_host.gd` | 없음 | — |

`stage4_ponk_fx_host_coordinator.gd` 의 `tear_down` 등장 횟수 = **0**.
`stage4_ponk_presentation_coordinator.gd`·`stage4_ponk_skill_state.gd` 도 0.

★**사용자가 본 것은 각성 오오라 하나지만 결함은 묶음 전체다.**
자기력·명상 호스트도 같은 상태이며 지금 안 보이는 것은 우연이다.

AGENTS.md 명시 규칙 위반이다.

> Detached FX/audio hosts need explicit score/serve/reset/cancel cleanup
> **even when logical visibility becomes false.**

## ★Y7 이 이미 답을 냈다 — 그대로 따르라

Y7(소나기 젖음)이 같은 결함을 닫으면서 확정한 것들이다.

1. **정리 지점 3곳.** 세션이 생산 경로를 증명해서 골랐다.
   - 타워 클리어 → 지도는 battle scene 을 **이탈하지 않는다.** 실제 성공 분기
     `battle_scene_match_flow_driver._try_start_tower_ascent_vertical_slice()`
     에서 `tear_down(false)`.
   - 점수·서브·라운드 재시작·취소는
     `battle_scene_match_event_driver._reset_ball()` 로 수렴 → `false`.
   - 최종 scene exit 만 `BattleSceneTeardownLifecycle.exit_tree()` 에서 `true`.
2. ★**숨김만으로는 부족하다.** Y7 에서 확인됐다 — 내부 누적값이 남아 다음
   sync 때 잔상이 복귀한다. **값과 시간 기준까지 리셋**해야 한다.
   퐁크 호스트들도 각자 누적 상태가 있는지 확인하고 같이 리셋하라.
3. **`tear_down(false)` 는 예열 자원을 재사용하고 `(true)` 만 해제한다.**
   프리웜을 깨지 마라.
4. **정확한 host 이름만 조회하는 lifecycle bridge** 를 써서 `_pso` 예열
   호스트를 건드리지 마라(Y7 의 `player_rain_wetness_lifecycle.gd` 참고).

⚠**Y7 의 지점이 퐁크에도 그대로 맞는지 네가 확인하라.** 스테이지4 는
전투 씬 구조가 다를 수 있다. **경로가 실제로 불린다는 것을 증명하고 보고하라.**
안 불리는 곳에 넣으면 GRT-031 반쪽 랜딩이다.

## 요구

1. **호스트 3종 전부** 정리 경로에 배선하라. 각성 오오라만 고치지 마라.
2. `illusion_ripple` 은 `tear_down` 이 없다. **필요한지 판정해서 보고하라.**
   필요하면 형제와 같은 시그니처로 추가하라.
3. **코디네이터가 정리를 소유하게 하라.** 호출부마다 호스트를 개별로 부르면
   다음에 호스트가 늘 때 또 빠진다. `stage4_ponk_fx_host_coordinator` 에
   일괄 `tear_down` 을 두는 것이 자연스럽다. **판정해서 보고하라.**
4. ★**형제 감사**: 다른 스테이지의 FX 호스트 코디네이터도 같은 상태인지
   확인하라. **목록만 보고하고 고치지 마라.** 범위는 관제탑이 정한다.
   (Y7 에서 weather 계열은 이상 없음이 확인됐다.)

## 씰 요구

Y7 이 만든 `godot/tests/player_rain_wetness_lifecycle_smoke.gd` 가 본보기다.
가짜 호스트로 **호출 계수**를 세는 방식이다.

1. ★**호출 계수 씰**: 지도 전환·리셋·exit 각 경로에서 호스트 3종의
   `tear_down` 이 **정확히 1회씩** 불리는지 단언하라.
   ⚠**소스텍스트 대조 금지.** 실제 호출 계수로 하라.
2. **누적값 리셋 씰**: 정리 후 각 호스트의 내부 상태가 0인지.
3. **반증**: 정리 호출을 제거하면 RED 가 되는지 확인하고 원상복구하라.
4. **프리웜 무회귀** 레그.
5. **CI/pre-push 락스텝.** ⚠**현재 251/251 이다.** 신규 씰은 양쪽 등재.
   착지 전후 항목 집합을 `comm` 으로 대조해 **사라진 항목 0** 을 증명하라.

## 게이트·보고

포커스드 스모크(+반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
★**픽셀 QA 필수.** 퐁크 각성 상태에서 클리어 → 노드 화면 진입 캡처로 잔상이
사라진 것을 확인하라. **수리 전 캡처도 함께 내라**(증상 재현 증거).

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs` 를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

## ★알려진 기준선 RED (이 작업 탓 아님)

관제탑이 HEAD 의 **깨끗한 격리 워크트리**(미추적 0·더티 0)에서 CI 씰 251건을
돌린 결과 다수가 이미 RED 다.
`docs/untracked_preload_dependency_audit_2026_08_27.md` 참조.
**착수 전 기준선을 먼저 재고, 네가 만든 RED 와 선재 RED 를 구분해서 보고하라.**
선재 RED 를 고치려 들지 마라. 범위 밖이다.

## 보고

커밋 해시 · **정리를 넣은 경로와 그 경로가 실제로 불린다는 증명** ·
호스트 3종 각각의 누적값 리셋 필요 여부 · `illusion_ripple` 판정 ·
코디네이터 소유 여부 판정 · `tear_down(false)` vs `(true)` 근거 ·
프리웜 무회귀 · **형제 스테이지 감사 목록(고치지 말고 목록만)** ·
씰 호출 계수 종단선과 제거 반증 · **수리 전·후 픽셀 캡처** ·
기준선 RED 대비 신규 RED 0 증명 · CI 항목 집합 대조 · 미해결.
