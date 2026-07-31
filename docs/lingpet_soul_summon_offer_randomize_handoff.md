# 영혼소환술 퍽 등장 랜덤화 핸드오프 (Codex 실행용)

작성 2026-08-01. 사용자 확정: **영혼소환술 퍽의 초반 확정 등장을 폐지하고
랜덤 등장으로 바꾼다.** 정본 = `docs/lingpet_guardian_duration_redesign_plan.md`
§2 (기존 계약: "미보유 첫 1~2 무공 화면 확정 예약 + 이후 3화면 쿨다운").
가드레일·씰 실행 규정은 기존과 동일.

## 1. 현재 동작 (실측)

`runtime_perk_catalog._append_soul_summon_choice` +
`lingpet_egg_runtime.begin_soul_summon_offer_screen`:

| 무공 화면 | 현재 |
|---|---|
| 1·2번째 | **확정 등장** — `_soul_summon_reserved` **예약 레인**이라 셔플 풀보다 먼저 슬롯을 차지 |
| 3~5 | 미등장(쿨다운 3화면) |
| 6 | 확정 등장 → 이후 3화면 주기 반복 |

핵심 구조: `reserve=true`면 `SOUL_SUMMON_PRIORITY_KEY`가 붙고,
`get_choices()`가 `choices.shuffle()` **이전에** 예약분을 추출해 결과에 먼저
넣는다(:1352·1397). 즉 지금은 셔플 경쟁 자체를 건너뛴다.

## 2. 변경 계약

- **예약 레인 사용 중지**: `reserve`를 항상 `false`로 만들어 영혼소환술이
  **일반 후보 풀에 섞여 셔플 경쟁**하게 한다. `SOUL_SUMMON_PRIORITY_KEY`
  부여 중단.
- **2회 보장 폐지**: `_soul_summon_offer_guarantee_count` 로직 제거.
- **3화면 쿨다운 폐지**: 랜덤 경쟁이 되면 쿨다운은 이중 억제가 된다.
  `_soul_summon_offer_cooldown_screens` / `_soul_summon_offer_pending_choice`
  경로도 함께 정리.
- **유지되는 것**: 미보유 게이트(보유·장착 시 후보 제외),
  `mark_soul_summon_art_acquired()` 호출부(획득 즉시 후보 제외),
  퍽 융합 제외, 선택 시 알 1개 즉시 드랍(§2 계약 불변).
- ⇒ 결과: **매 무공 화면마다 다른 퍽들과 동등하게 경쟁하는 순수 랜덤.**
  못 뽑는 런이 존재할 수 있고, 그것이 이번 변경의 의도다.

### 죽은 코드 처리

예약/보장/쿨다운 필드와 그 소비자가 전부 죽으면 **본문까지 제거**한다
(호출만 지우고 함수·필드를 남기는 반쪽 정리 금지 — 이 리포의 재발 패턴).
`begin_soul_summon_offer_screen`이 사실상 "미보유면 offer_allowed=true"만
남는다면 **함수 자체를 없애고 카탈로그 쪽 미보유 판정만 남기는 편이 더 깔끔**한지
검토하고, 어느 쪽을 택했는지 보고할 것. ⚠️ 단 `already_owned=true` 경로가
`mark_soul_summon_art_acquired()`를 호출하는 부수효과를 갖고 있으니 그 호출부를
먼저 전수 확인하고 옮길 것.

## 3. 씰

- 기존 "첫 2화면 확정 등장 / 3화면 쿨다운" 단언이 있다면 **폐지 또는 반전**:
  - **예약 레인 미사용**: 결과에 `soul_summon_reserved` offer_lane 메타가
    붙지 않음.
  - **미보유면 후보 풀에 포함**되고, **보유·장착 시 제외**됨(미보유 게이트 유지).
  - **연속 화면에서 강제 등장/강제 미등장이 없음** — 결정론 RNG를 주입해
    "같은 시드에서 등장/미등장이 모두 발생 가능"을 단언(고정 확정도, 고정
    차단도 아님).
- 반증 1회(예약 플래그를 되살리면 확정 등장 단언이 RED로 뒤집히는지).
- 회귀: `soul_summon_art_skill_contract_smoke`,
  `guardian_egg_gate_smoke`, `soul_summon_art_egg_grant_smoke` GREEN 유지
  (특히 **선택 즉시 알 드랍**은 이번 변경과 무관하게 살아야 한다).

## 4. 정본 갱신

`docs/lingpet_guardian_duration_redesign_plan.md` §2의 "첫 1~2 화면 확정 예약 +
3화면 쿨다운" 문구를 **랜덤 경쟁**으로 개정하고, 개정 사유(사용자 확정
2026-08-01)를 남길 것.

## 5. 보고 형식

커밋 해시 / 죽은 코드 처리 방식(함수 존치 vs 제거)과 근거 /
`mark_soul_summon_art_acquired()` 호출부 전수 확인 결과 / 씰 원문·반증 /
미결·발견 사항.
