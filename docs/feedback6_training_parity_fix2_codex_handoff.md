# 지시문 V1 — [P0] 선택 항목 반쪽 이행이 CI 등재 씰을 새로 RED로 만들었다

- **발행**: 관제탑 2026-08-25. 대상: 브랜치
  `codex/fb6-training-display-parity-20260825`(워크트리
  `D:\codex_tmp\bosspong_trainparity_e1c6`)의 `c4e81ba0d` 위 **추가 커밋**.
  amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **B안(총량 보존) 본체는 전부 통과다.** `amount = 20/3`(≈6.6667%)로
  기본 판정 1회 duration이 정확히 16.0프레임 → `compute_total_dash_distance`
  = **240.000px**. 보고된 실거리표(60Hz 240.000/249.600/256.000,
  72Hz 242.778/252.278/258.611)를 씰 종단선 원문으로 1:1 확인했고
  **어느 티어에도 하향이 없다.** 파리티 씰은 CI·pre-push 양쪽 등재됐고
  72Hz 레그도 파라미터화됐다. `mystic_dice_stat_apply_smoke`도 216.3으로
  정상 갱신됐다.
- 그러나 **선택 항목이던 P3-8을 절반만 이행해 CI 등재 씰 하나를 새로
  RED로 만들었다.** 그것만 닫으면 통합한다.

## [P0] F1 — `runtime_perk_overflow_description_smoke`가 새로 RED다

- 비천보(dash_jump) Lv.1~5 문구를 `runtime_perk_catalog.gd:84`에서
  "활주 지속"으로 바꾸면서, **같은 문구를 생성하는 오버플로 템플릿**
  `runtime_perk_overflow_descriptions.gd:42`의 `"활주 거리 "`를 남겼다.
- 실행 확인: 워크트리에서 exit 1, 실패 5건
  (`dash_jump Lv.1 template drift: generated 활주 거리 7% 증가 /
  authored 활주 지속 7% 증가` ~ Lv.5). 본 트리 기저는 exit 0으로 GREEN.
- 등재 위치: `godot-ci.yml:63`, `run_pre_push_checks.ps1:67`.
  **착지 즉시 푸시 게이트가 빨간불이 된다.**
- 수리: `LINEAR_PATTERNS`의 해당 템플릿을 "활주 지속 "으로 맞춰라.

## [P1] F2 — 나이틀리 씰 `common_mugong_dash_rebrand_smoke` 실패 9건 신규

- `:118` `expected_contracts`가 **"값이 변하지 않아야 한다"**는 봉인인데
  갱신 없이 깨졌다. 신규 실패 9건:
  `dash_jump should expose its rebranded summary for ko/en/zh/ja/es/pt-BR/ru`(:100)
  + `first-level value must remain unchanged`(:129)
  + `final authored value must remain unchanged`(:130).
- 본 트리 기저에서는 dash_jump 실패가 **0건**이다(기저 RED는
  dash_amplification/dash_acceleration 별건).
- 수리: 봉인을 새 문구 계약으로 **갱신**하고 갱신 사유 주석을 남겨라.
  그냥 통과시키면 봉인의 의미가 사라진다.

## [P1] F3 — 같은 비천보가 레벨에 따라 두 어휘를 노출한다 (GRT-031 반쪽 랜딩)

- 효과레벨 부스트로 비천보가 Lv.6 이상이 된 런에서, Lv.5까지의 authored
  문구는 "활주 지속 35% 증가", Lv.6+ 생성 문구는 "활주 거리 42/49% 증가".
- 증거: 워크트리 `perk_status_owned_tooltip_smoke:85`의
  `_perk_stats_for_level(real_lv7) == "활주 거리 49% 증가"`가 여전히 통과한다.
- P3-8이 없애려던 "같은 이름에 두 어휘" 증상이 수련↔무공 축에서
  **무공 내부 레벨 축으로 옮겨갔을 뿐**이다.
- 신규 파리티 씰은 레벨 1~5만 검사해(`:180 range(1,6)`) 이 구간을 못 잡는다.
- 수리: F1을 고치면 생성 문구도 따라오지만, **Lv.6+ 구간을 실제로 단언하는
  레그를 추가**하고 형제 씰(`perk_status_owned_tooltip_smoke`)도 갱신하라.

## [P2] F4 — 기존 단언을 항진명제로 낮췄다 (요청하지 않은 약화)

- `physique_training_category_smoke.gd:57`과 `:472`의 비천보 수치 단언이
  리터럴 고정(5.0 / 105.0)에서 **상수 자기참조**로 바뀌었다.
  `get_amount("physique_dash_distance") == PhysiqueTrainingCatalog.DASH_DISTANCE_AMOUNT`는
  `get_amount`이 `DATA["amount"]`를 그대로 읽는 순수 읽기이므로 **어떤 값이든
  항상 참**이다. 사용자 확정 사양인 240px 총량은 신규 씰의 ±1.0px 밴드
  한 곳에만 남는다.
- ⚠지시문은 `mystic_dice` 씰만 "새 계약으로 갱신"하라고 했고 이 씰에 대해
  어떤 완화도 허가하지 않았다.
- 수리: 새 값(20/3 또는 그로부터 나오는 240px)을 **리터럴로 고정**하라.

## [P2] F5 — 활주 거리 행에 새 표기 오차를 만들었다

- `character_info_overlay_stats_presenter.gd:192`가
  `"%dpx" % int(round(dash_distance))`라, 훌륭 판정 1회
  (실이동 249.6px)에서 TAB 패널이 **"250px"**로 올려 적는다.
- 종전에는 per-frame round 때문에 이 값이 항상 정수여서 불일치가
  존재하지 않았다. **이 브랜치가 새로 만든 오차**이며, P2-6이 기력 행에
  요구한 "표기 ≤ 실제"와도 어긋난다.
- 기본(240.0)·회심(256.0)은 정수라 티가 안 나고 훌륭 티어에서만 드러난다.
- 신규 씰 `_verify_dash_judgment_distances`는 float끼리만 비교하고 렌더
  문자열을 보지 않아 못 잡는다. **렌더 문자열 레그를 추가**하라.

## [P3] 잔여 3건 (여력 있을 때)

6. 신규 씰 `:221`의 "하향 없음" 레그가 종전 출하 동작이 아니라 중간
   커밋(amount 5.0)을 기준선으로 삼는다. 실제 출하 기준은
   **표시 240/240/240, 72Hz 실이동 235.0**이다. 그 값을 명시적으로 봉인하라.
7. `character_info_overlay_formatter.gd:149~152`의 `"%.1f"`가 반올림이라
   숙련 2성 × 훌륭 판정 조합(실제 55.6875pt)에서 "55.7pt"로 올려 적는다.
   "표기 ≤ 실제" 미보장.
8. 신규 씰 `:406~412`가 아직 소스 문자열 `contains`다. 은퇴 별칭을 다른
   이름으로 되살리면 GREEN이고, 프로덕션 주석에 그 문자열만 적어도 RED다.

## 게이트·보고

`runtime_perk_overflow_description_smoke`·`common_mugong_dash_rebrand_smoke`·
`perk_status_owned_tooltip_smoke`·`physique_training_category_smoke` 포함
포커스드 스모크(+RED 반증) → `-Paths` 경고 → 헤드리스 로드 →
`git diff --check` → 캡처.
⚠**본 트리 HEAD가 움직였다**(현재 `e4a90dddd`, 락스텝 **240/240**).
이 브랜치가 착지하면 241이 된다.
보고=추가 커밋 해시·씰 종단선 원문·F1 수리 후 기저 대조·Lv.6+ 레그 결과·
미해결.
