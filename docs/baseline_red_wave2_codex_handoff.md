# 지시문 U2 — [P1] 2차 기저 RED 정리 (vertical-slice 전제 스테일 외)

- **발행**: 관제탑 2026-08-25. 기준 HEAD `79c152cca`. 락스텝 241/241.
- **격리 워크트리**: `D:\codex_tmp\bosspong_baseline2_79c1` (브랜치
  `codex/baseline-red-wave2-20260825`).
- **금지**: 본 트리 편집·푸시·통합. 보고 후 대기.
- ⚠**D: 여유 공간 부족** — 워크트리는 1개만 만들고 작업 후 제거하라.
- **배경**: U1로 기저 RED 2종을 잡았는데, 그 뒤 통합 라운드에서 **또 다른
  6종**이 드러났다. 그중 1종은 CI·pre-push 등재라 **다시 푸시를 막는다.**

## [P1] 그룹 A — vertical-slice 전제 스테일 (2종, 원인 동일)

`TowerAscentFeatureFlags.DEFAULT_VERTICAL_SLICE_ENABLED = true`이므로
`roll_reward("guaranteed_mythic")`가 `_is_guaranteed_mythic_box_kind`
분기에 **도달하지 못하고** `_roll_tower_normal_box_reward`로 조기 반환된다
(`stage_clear_reward_resolver.gd:58` 계열). 씰들은 그 플래그가 꺼져 있던
시절의 전제 위에 서 있다. CI/pre-push에 env 오버라이드도 없다
(`TOWER_ASCENT_VERTICAL_SLICE`는 `run_tower_mode.ps1`에만 존재).

1. ★`tests/mythic_perk_acquisition_cinematic_smoke.gd:166`
   — **CI·pre-push 양쪽 등재.** 첫 실패
   "flag-ON mythic box should roll a mythic perk choice reward".
   **이것 때문에 푸시가 막힌다. 최우선.**
2. `tests/stage_clear_reward_resolver_smoke.gd` — 나이틀리.
   ⚠**주의**: 관제탑이 방금 `7555de8a5`로 보상 경제 3기능을 착지시켰다.
   그 커밋의 새 단언 3종(`is_advanced_box_kind == false`,
   `active_granted == 2`, 대성영단이 액티브 슬롯)이 **이 기저 RED 때문에
   한 번도 실행되지 않는다.** 이 씰을 살리면 그 세 계약도 같이 살아난다.

수리 방향: 씰의 전제를 **현행 플래그 기준으로 정본화**하라. 둘 중 택일하고
근거를 보고하라.
- (a) 씰이 vertical-slice ON 경로(`_roll_tower_normal_box_reward`)를
  검사하도록 재작성 — 라이브가 실제로 타는 경로다. **우선안.**
- (b) 씰이 플래그를 명시적으로 끄고 레거시 경로를 검사 — 그 경우
  "레거시 캠페인 전용 계약"임을 씰 이름·주석에 명시하라.
⚠어느 쪽이든 **단언을 지워서 통과시키지 마라.**

## [P2] 그룹 B — 나머지 4종

3. `tests/match_player_skill_deps_builder_smoke.gd:92`
   — "direct builder should include four skill configs" 외 16건.
   **대장장이(Blacksmith) skill config 4번째 슬롯** 계약이다.
   대장장이 캐릭터 작업이 진행 중인 다른 WIP와 얽혀 있을 수 있으니,
   **원인을 먼저 특정해 보고**하고 수리는 그 판정에 따르라.
4. `tests/dalji_vision_chosik_smoke.gd:659`
   — `_verify_reserved_offer_and_reward_box`에서
   `Out of bounds get index '0' (on base: 'Array')` + 이어서
   "Io owner aliases should route common unlocks to the Optimus config:
   expected optimus, got smasher".
5. `tests/cheongringwi_vision_chosik_smoke.gd:693`
   — `_verify_stage2_reward_box_contract`에서 같은 Out of bounds.
   ⚠**4·5는 보상 상자 경로를 탄다.** 관제탑이 `7555de8a5`를 착지시킨
   **뒤에는 실패 양상이 달라졌을 수 있다.** 착수 전 반드시 재측정하라.
6. `tests/perk_status_owned_tooltip_smoke.gd:236`
   — "fusion projection entry must survive the status-panel fold".
   exit 0인데 ERROR를 뿜어 러너의 심각-에러 게이트에 걸린다.

## [P3] 기록만 (수리 금지)

- `tests/tower_ascent_flow_owner_refactor_smoke.gd` — 2건.
- `tests/tower_audition_build_smoke.gd` — **보류 결정된 건**이다
  (`docs/tower_map_deferred_findings_2026_08_25.md`의 내보낸 빌드 지도
  생성 16.5% 실패). 손대지 마라.

## 작업 원칙

- **씰 스테일인지 제품 버그인지 먼저 판정**하고 보고에 명시하라.
  U1의 두 건은 전부 씰 스테일이었다. 이번에도 제품을 "고치려" 들기 전에
  전제부터 의심하라.
- 씰의 **입력 파라미터를 바꿔 통과시키는 것은 단언 약화**다(V3에서 실제로
  발생해 반려했다). 단언을 지우거나 벡터를 0으로 만들지 마라.
- 각 건마다 **마지막 GREEN 커밋과 회귀 커밋**을 특정하라. 특정이 어려우면
  코드 정독으로 유도하고 그렇게 했다고 명시하라.

## 게이트·보고

수리한 씰 + 형제 씰을 한 배치로(+RED 반증) → `-Paths` 경고 →
헤드리스 로드 → `git diff --check`.
보고=워크트리·커밋 해시·씰 종단선 원문·**건별 스테일/제품 판정과 회귀
커밋**·그룹 A에서 택한 안과 근거·`7555de8a5` 착지 후 4·5 재측정 결과·
미해결. **워크트리 제거까지 하고 보고하라.**
