# 통합 보류 목록 (2026-08-21)

**보류 사유는 하나다. 사용자 미커밋 WIP 과 얽혀 안전하게 분리되지 않는다.**
자동 통합을 다시 시도하기 전에 이 문서를 먼저 읽어라.

## 0. 뿌리 원인

본 트리에 **전광판·정산 재설계**와 **스테이지3 보스 스킬 모듈화**가
미커밋 상태로 있다.

| 파일 | 상태 |
|---|---|
| `godot/scripts/hud/scoreboard_overlay_header_renderer.gd` | 수정됨 (재설계) |
| `godot/scripts/core/defeat_settlement_screen.gd` | 수정됨 (개편) |
| `godot/scripts/stages/stage3/stage3_boss_skill_state.gd` | 수정됨 |
| `stage3_boss_skill_hud_state_builder.gd` 외 5 | **미추적** |

★**HEAD 자체는 안전하다.** 추적 파일이 미추적 모듈을 참조하지 않는다.
깨끗한 체크아웃은 정상 로드된다.

## 1. 보류 1 — 스테이지1 변형 보스 라우팅

- 브랜치: `codex/stage1-variant-boss-routing-01a02287`
- HEAD: `703869a01`
- 내용: 달지·각시탈·포도대장 3-way 랜덤 선출, 포도대장 전투 2스킬 신규,
  HUD·오디오·이름·정산 경로 완성. **68개 파일.**

### 시도한 것과 결과

기준 `b57329dd1` 에서 3-way 병합(base=HEAD, ours=워크트리, theirs=브랜치).

| 결과 | 수 |
|---|---|
| 얽히지 않음 | 53 |
| 자동 병합 성공 | 7 |
| ★**충돌** | **8 (13곳, 약 300줄)** |

| 충돌 파일 | 충돌 |
|---|---|
| `scoreboard_overlay_header_renderer.gd` | 3곳 114줄 |
| `defeat_settlement_screen.gd` | 6곳 50줄 |
| `battle_draw_actor_context.gd` | 1곳 82줄 |
| `scoreboard_overlay_renderer.gd` | 1곳 |
| `defeat_settlement_screen_smoke.gd` | 1곳 |
| `stage1_gaksital_fan_throw_smoke.gd` | 1곳 |
| `.github/workflows/godot-ci.yml` | (수동 병합 대상) |
| `run_pre_push_checks.ps1` | (수동 병합 대상) |

### ★부분 통합 금지

깨끗한 53개만 넣는 안을 검토했으나 **`battle_draw_actor_context.gd` 가
충돌 목록에 있다.** 포도대장을 그리는 배선이다. 그것 없이 라우팅만 넣으면
**선출은 되는데 안 그려지거나 이름이 틀린다.** GRT-031 반쪽 랜딩이다.

**전부 넣거나 아무것도 넣지 않는다.**

## 2. 보류 2 — 변형 보스 표시 이름 씰

- `godot/tests/variant_boss_display_name_smoke.gd` 가 미추적 상태다.
- 전광판·정산·스테이지3 HUD 빌더를 관통하는데 그 셋이 WIP 이다.
- **본 트리에서는 GREEN 이지만 깨끗한 트리에서는 RED 다.**
  그래서 CI 에 등재하지 않았다.
- 표시 이름 수정 자체는 워크트리에 반영돼 있어 라이브는 정상이다.

## 3. 해제 조건

★**전광판·정산 재설계와 스테이지3 스킬 모듈화가 커밋되면 전부 풀린다.**

커밋 후 순서:

1. `703869a01` 을 최신 HEAD 기준으로 다시 3-way 병합한다. 충돌이 사라지는지
   먼저 확인하라. 남으면 **세션에 리베이스를 맡겨라.** 그 코드를 쓴 쪽이
   충돌을 제대로 푼다.
2. `variant_boss_display_name_smoke.gd` 를 추적으로 올리고 CI 두 목록에
   동시 등재한다.
3. 등재 전 **깨끗한 트리에서 GREEN 인지** 확인하라. 실패하는 씰을 넣지 마라.

## 4. 하지 말 것

- ★**브랜치 패치를 통째로 적용하지 마라.** 이 브랜치들은 오늘 착지한
  커밋들보다 오래된 기준에서 갈라졌다. 통째 적용하면 지도 방여도 배선 등이
  **삭제로 딸려 들어간다.** 오늘 두 번 걸렀다.
- ★**충돌을 임의로 해소하지 마라.** 미커밋 재설계는 되돌릴 수 없다.
