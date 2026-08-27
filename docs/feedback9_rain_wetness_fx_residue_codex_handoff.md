# 지시문 Y7 — 소나기 젖음 FX 가 지도 화면에 잔상으로 남는다

- **발행**: 관제탑 2026-08-27. 기준선 = 본 트리 **`202bcadbc`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.

## 사용자 보고

> 날씨 **소나기** 상태에서 게임 클리어 시 **노드 지도 화면에서도** 플레이어
> 캐릭터에 비 맞을 때 이펙트가 **잔상처럼 그대로 남는** 버그.

## ★진범 (관제탑 확정 — 재조사 금지)

`godot/scripts/effects/player_rain_wetness_fx_host.gd` 는
`tear_down(free_self: bool = false)` 을 **정의만 하고 아무도 부르지 않는다.**

관제탑이 `godot/scripts` + `godot/tests` 전수로 확인했다. 이 호스트에 대한
`tear_down` 호출은 **정적·동적(`has_method`) 통틀어 0건**이다.

호스트는 `stage1_player_actor_renderer.gd:369~371` 에서 **캔버스의 자식으로
생성**된다.

```gdscript
_rain_wetness_host = PlayerRainWetnessFxHost.new()
_rain_wetness_host.name = RAIN_WETNESS_HOST_NAME
canvas.add_child(_rain_wetness_host)
```

`RAIN_WETNESS_HOST_NAME` 은 **생성·조회에만** 쓰이고 제거 경로가 없다
(`:17`, `:364`, `:370` 세 곳뿐).

### 저장소 관례를 혼자 어기고 있다

`tear_down` 을 가진 FX 호스트는 약 30개이고 **전부 소유자 쪽에서 호출**된다.
`stage5_hongryun_playfield_renderer`, `stage_ball_spawn_intro`,
`commando_supply_drop_fx_host_lifecycle`, `mythic_item_hermes_field_renderer`,
`plaza_interior_view`, `stage_clear_result_fx_host_pool` 등.

중앙 정리 소유자는 **`godot/scripts/core/battle_scene_teardown_lifecycle.gd`**
이며 이미 프롤로그·타워 시작 카드·아카무 프리배틀 프레젠테이션을 정리한다.

AGENTS.md 명시 규칙이다.

> Detached FX/audio hosts need explicit score/serve/reset/cancel cleanup
> **even when logical visibility becomes false.**

## ★두 번째 축도 함께 판정하라 — 젖음 누적값

`_advance_wetness(time_seconds, rain_active)` 로 쌓이는 젖음 값이
**리셋되는지** 확인하라. 노드를 지워도 다음 진입에서 `get_wetness()` 가
젖은 상태로 시작하면 증상이 남는다.

**호스트 제거만으로 증상이 사라지는지, 값 리셋도 필요한지 실측해서 보고하라.**
둘 다 필요하면 둘 다 고치되 **각각이 무엇을 고쳤는지 구분해서 보고하라.**

## 요구

1. **전투 종료·지도 진입 경로에서 호스트를 정리하라.**
   `battle_scene_teardown_lifecycle.gd` 를 1순위 후보로 검토하되, 실제
   생산 경로가 그곳을 지나는지 확인하고 아니면 올바른 소유자를 찾아라.
   ⚠**어느 경로가 실제로 불리는지 증명하고 보고하라.** 안 불리는 곳에
   넣으면 GRT-031 반쪽 랜딩이다.
2. **점수·서브·라운드 리셋·취소 경로도 함께 보라.** AGENTS 규칙이 그 네
   지점을 명시한다. 지도 진입만 막으면 다른 경로로 샌다.
3. ★**형제 감사**: 다른 날씨 FX(사막화 모래 등)도 같은 결함이 있는지
   확인하라. `weather_event_renderer.gd` / `weather_event_state.gd` 계열에
   정리 없는 분리 호스트가 더 있으면 **목록으로 보고하라.**
   ⚠**한꺼번에 고치지 말고 목록만 보고하라.** 범위는 관제탑이 정한다.

## 바꾸면 안 되는 것

- 전투 중 소나기 젖음 연출 자체. **정리 시점만 고치는 것이다.**
- 프리웜(`prewarm_assets` / `prewarm_runtime_nodes`)을 깨지 마라.
  `battle_pso_prewarmer.gd` 가 이 호스트를 참조한다. **정리가 프리웜을
  무효화해 다음 전투 첫 프레임에 셰이더 컴파일 스톨을 만들면 안 된다.**
  `tear_down(false)`(재사용 가능) 와 `tear_down(true)`(free) 중 어느 쪽이
  맞는지 판정하고 근거를 보고하라.

## 씰 요구

저장소에 **이미 같은 유형의 씰 패턴**이 있다. 그대로 따르라.

- `godot/tests/stage_ball_spawn_intro_fx_lifecycle_smoke.gd`
  — 가짜 호스트로 `tear_down_calls` 를 세는 방식
- `godot/tests/commando_supply_drop_fx_host_lifecycle_refactor_smoke.gd`

1. ★**호출 계수 씰**: 전투 종료/지도 진입 경로를 태우면
   `tear_down` 이 **정확히 1회** 불리는지 단언하라.
   ⚠**소스텍스트 대조로 판정하지 마라.** 실제 호출 계수로 하라.
2. **반증**: 정리 호출을 제거하면 RED 가 되는지 확인하고 원상복구하라.
3. **젖음 값 리셋이 필요하다고 판정했다면** 재진입 시 `get_wetness()` 가
   0에서 시작하는지 단언하라.
4. **프리웜 무회귀** 레그를 넣어라.
5. **CI/pre-push 락스텝.** ⚠**현재 250/250 이다.** 신규 씰은 양쪽 등재.
   착지 전후 항목 집합을 `comm` 으로 대조해 **사라진 항목 0** 을 증명하라.

## 게이트·보고

포커스드 스모크(+반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
★**픽셀 QA 필수.** **소나기 상태에서 클리어 → 지도 진입** 캡처로 잔상이
사라진 것을 눈으로 확인하라. 수리 전 캡처도 함께 내라(증상 재현 증거).

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs` 를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

## 보고

커밋 해시 · **정리를 넣은 경로와 그 경로가 실제로 불린다는 증명** ·
젖음 값 리셋 필요 여부 판정 · `tear_down(false)` vs `(true)` 판정 근거 ·
프리웜 무회귀 확인 · **형제 날씨 FX 감사 목록**(고치지 말고 목록만) ·
씰 호출 계수 종단선과 제거 반증 · **수리 전·후 픽셀 캡처** ·
CI 항목 집합 대조 · 미해결.

## 알려진 선재 RED (이 작업 탓 아님)

- 전체 경고 스캔 RED — 파스 오류 경로 테스트 17 + 도구 2.
  CI 등재 3건은 도입 시점부터 무효였다.
- `tower_ascent_flow_owner_refactor_smoke` — `tower_ascent_flow_runtime.gd`
  710줄 vs 500줄 예산.
- `tower_ascent_node_modal_shell_smoke` — outgoing candidate 개수 단언.
