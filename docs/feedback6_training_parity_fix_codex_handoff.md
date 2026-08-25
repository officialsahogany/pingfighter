# 지시문 T1-수정 — CI 씰 RED · 비천보 총량 보존 · 씰 등재

- **발행**: 관제탑 2026-08-25. 대상: 브랜치
  `codex/fb6-training-display-parity-20260825`(워크트리
  `D:\codex_tmp\bosspong_trainparity_e1c6`)의 `9e6386381` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: 본체 수리는 APPROVE. 카드 앞쪽 수치 = amount × 숙련배율,
  천장 곱셈-후-클램프, 판정 배지, 7언어 라벨, 플래너 `applied_count`
  전달 전부 실측 확인했다. 신규 씰 99케이스 GREEN.
  **아래 3건만 수리하면 통합한다.**

## [P0] F1 — round 제거가 CI 등재 씰을 RED로 만든다 (실행 확인)

- 워크트리에서 `run_smoke_tests.ps1 -Tests res://tests/mystic_dice_stat_apply_smoke.gd`
  → **exit 1**. 실패 2건:
  - `:146` "dash-distance +3 raw should produce a 216px full dash
    (per-frame round)" — expected 216.000, got **216.300**
  - `:181` "TAB dash-distance row should match the real 216px
    dice-boosted dash" — 동일
  - `_expect_close` 허용오차는 `:237` 0.001이라 0.3px가 그대로 실패다.
- 이 파일은 `.github/workflows/godot-ci.yml:210`과
  `godot/tools/run_pre_push_checks.ps1:214`에 **양쪽 등재**돼 있다.
  착지 즉시 푸시 게이트가 빨간불이 된다.
- ⚠LFS 귀속 불가다. 자산 오류가 아니라 순수 수치 단언 실패다.
  (헤드리스 로드 RED의 LFS 귀속은 맞다 — 그건 별개이며 본 트리에서는
  재현되지 않는다. 확인 완료.)
- 수리: 아래 P0-B의 총량 보정을 먼저 확정한 뒤, 그 결과에 맞게
  `:146`/`:181` 기대값과 `"(per-frame round)"` 문구를 **새 계약으로
  갱신**하라. 갱신 사유를 주석 한 줄로 남겨라. 씰을 지우지 마라.

## [P0-B] F3 — 비천보 실거리 하향: **사용자 확정 = 총량 보존(B안)**

관측된 변화(신규 씰 종단선 `dash_distance=232.500/239.250/244.000`):

| 비천보 1회 | 기본 | 훌륭 | 회심 |
| --- | --- | --- | --- |
| 종전 | 240 | 240 | 240 |
| 현재 커밋 | **232.5** | 239.25 | 244.0 |

- 수련 0회 기본치 210px은 **불변**이다(확인 완료: duration 15.0 ×
  mult 1.0이면 speed가 항상 정수라 round가 no-op).
- 판정 3티어가 실거리에 반영되는 것 자체는 지시문 7번이 요구한 것이므로
  **유지한다**. 문제는 선언 없는 3.1% 하향이다.

**사용자 확정 사양**: 판정 차등은 유지하되 **총량을 종전 기준으로
보존**한다.

1. 비천보(`physique_dash_distance`)의 `amount`를 소폭 상향해
   **기본 판정 1회의 `compute_total_dash_distance`가 240px ± 1px**가
   되게 맞춰라. 훌륭·회심은 자연히 그 위로 올라간다.
2. ⚠`compute_total_dash_distance`는 fps 비의존이고 **캐릭터 정보 패널의
   활주 거리 행이 이 값을 쓴다.** 보정 기준은 이 함수값으로 잡아라.
3. 실제 이동거리는 `fps_scale` 의존이다. 프로젝트 기본 물리는
   **72Hz**(`project.godot:52` `physics_ticks_per_second=72`,
   `battle_view_layout.gd:521~533`이 모니터 유도 캡을 건다).
   **60Hz와 72Hz 양쪽에서** 보정 후 실이동거리가 종전 대비 하향이
   아님을 실측하고 표로 보고하라.
4. 상향한 amount가 **누적·천장·다른 소비자**에 미치는 영향을 확인하라.
   공유 소비자: `character_info_overlay_stats_presenter`(103/147/654/
   657/666/669/1504), `perk_fusion_returning_light_step_state`(216/220),
   `lingpet_ring_dash_state`(285~286, GRT-014 긴급지원 투영),
   `smasher_dash_motion_update_resolver:47`(오딘의 눈·주사위 배율).

## [P1] F2 — 신규 파리티 씰이 CI·pre-push 어디에도 없다

- `tests/physique_training_display_apply_parity_smoke.gd`는 신규 파일
  (`git cat-file -e e1c6c886d:...` 부재 확인)인데 두 목록에 0건이다.
  워크트리 락스텝은 237/237로 기준선 그대로다(**본 트리는 현재 238/238,
  T2 착지분 포함**).
- 나이틀리 전수에는 잡히지만, 지시문 P0의 핵심 계약(표기=적용)이
  포커스드 CI·pre-push에서 한 번도 돌지 않는다. 누가 앞쪽 수치를 raw로
  되돌려도 푸시 게이트가 통과한다.
- 수리: `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1` **양쪽**에 알파벳 위치로 추가.
  ⚠GRT-035: 공유 목록 삽입은 형제 절대-인덱스 씰을 깨뜨린다. 삽입 후
  양쪽 개수가 같은지, 형제 인덱스 단언이 성립하는지 확인하라.

## [P2] 표시면 잔여 3건

5. **72Hz 파리티 공백**: 신규 씰의 `_simulate_dash_distance`가
   `fps_scale = 1.0`을 하드코딩한다. 배포 기본인 72Hz에서는 패널이
   232.5를 읽는데 실이동은 235.0으로 갈린다 — **이 커밋이 없애려던
   표기/적용 불일치가 다른 축에서 재발**한다. 씰을 fps_scale
   파라미터화해 60Hz·72Hz 양쪽 레그를 두어라.
6. **기력 절대 표기 반올림**: `character_info_overlay_stats_presenter.gd:182`가
   `"%dpt" % int(round(gauge_gain))`이라, floor 제거 후 실제 53.5pt인
   격기심법 1회가 **"54pt"**로 표기된다(종전에는 53=53 일치).
   소수 한 자리로 떨어뜨리거나 표시 반올림을 floor로 맞춰 **표기 ≤ 실제**를
   유지하라. 툴팁 계약을 먼저 확인할 것.
7. **카탈로그 주석 모순**: `physique_training_catalog.gd:233`이 아직
   "카드 문구 계약(2026-08-24): 앞쪽 수치는 언제나 원시 퍼레벨 증가량"
   이라고 선언한다. 지시문이 근거로 인용한 바로 그 기록이라, 다음
   세션이 정본으로 읽으면 이번 수리를 되돌린다. 새 계약으로 갱신하고
   일자·사유를 남겨라.

## [P3] 선택 (여력 있을 때만, 없으면 미해결로 보고)

8. **무공 비천보 문구 비대칭**: `runtime_perk_catalog.gd:84~88`이 같은
   지속 프레임 축을 쓰면서 여전히 "활주 거리 7/14/21/28/35% 증가"로
   광고한다(`language_settings_data.gd` 1609/1722/1835/1948/2061/2174도
   동일). 수련만 "활주 지속"으로 고치고 퍽을 남기면 사용자가 같은
   비천보 이름으로 두 어휘를 동시에 본다.
9. **소스 grep 씰 3건**: 신규 씰 `:270` 부근 `_verify_source_contracts`가
   프로덕션 소스 문자열 `contains`라 인자 개명만으로 RED가 되고 주석에
   같은 문자열만 넣어도 GREEN이다. 특히
   `tower_ascent_node_modal_localization.gd:41`의
   `KEY_TRAINING_BONUS_BADGE := KEY_TRAINING_TIMING_BADGE` **별칭**을
   쓰면 은퇴 키 금지 단언을 그대로 통과한다. 동작 레그로 바꾸고 별칭
   상수까지 금지 대상에 넣어라.

## 확인된 무결 (재작업 금지)

- 타격 기력 float 전환은 **정수 계약을 깨지 않는다.**
  `calculate_bluetooth_ring_gauge_charge`의 생산 소비자는
  `paddle_bounce_event_router.gd:137~139` 하나뿐이고, 결과는 float
  `special_gauge`에 누적된 뒤 `min(gauge_max, ...)`될 뿐이다.
  `special_gauge`는 network·저장 경로 어디에도 직렬화되지 않는다.
  스킬 임계값은 전부 float `>=` 비교이며 등호 경계 의존이 없다.
  표시면 1곳(P2-6)만 손보면 된다.
- `tower_training_lucky_bonus_smoke.gd:287`의 은퇴 배지 키 재주입 금지
  단언은 **문자 그대로 무변**이다. 형제 씰 5건 모두 약화 없음.
- 수련 0회 기본 활주 거리 210px 불변.

## 게이트·보고

`mystic_dice_stat_apply_smoke` 포함 포커스드 스모크(+RED 반증) →
`-Paths` 경고 → 헤드리스 로드 → `git diff --check` → 캡처.
보고=추가 커밋 해시·씰 종단선 원문·**보정 후 11종 대조표**·
**60Hz/72Hz 실이동거리 전후 비교표**·락스텝 개수(238→239)·미해결.
