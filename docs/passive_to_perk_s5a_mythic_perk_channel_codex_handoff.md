# S5a 코덱스 핸드오프 — 신화퍽 획득 채널 (신화 상자→확정 신화퍽)

발주: 2026-07-08. 버그 리포트: 결과화면에 죽은 신화 **아이템**(바알의 부츠)이
상자 보상으로 뜸. 대표 결정: **"제대로 — 신화상자→확정 신화퍽" (S5 일부 당김)**.
Claude 기획 → Codex 배선 → Claude 적대 리뷰 → 통과 시 자동커밋.

선행: S2b가 REWARD_PASSIVE만 스타포인트로 리다이렉트, **REWARD_MYTHIC는 미처리**.
플래그 ON에서 신화 아이템은 효과가 신화퍽 경로(레벨 0)를 읽어 **죽은 아이템**.
게다가 신화퍽 11종은 S2a에서 일반 오퍼 제외돼 **현재 획득 경로가 전무**.

## 근본 원인 (4경로 신화 아이템 누수)

플래그 ON에서도 신화 **아이템**이 여전히 드랍되는 경로:
1. `stage_clear_reward_resolver.gd` — guaranteed_mythic 상자(41행) + 일반/고급
   상자 mythic 가중치(60·85·156·173행) → `_roll_item_reward(REWARD_MYTHIC)` →
   `_grant_equipment_reward` (아이템 지급). **← 스크린샷의 바알의 부츠**
2. `active_item_field_spawn_pool.gd` — S2b는 `_get_spawn_group=="passive"`만 제외,
   mythic 그룹은 유지.
3. `pandora_legacy_pool_builder.gd` — S2b는 build_passive_pool만 empty, build_mythic_pool 유지.
4. `treasure_hunt_runtime.gd` — S2b는 passive 결과만 스타포인트, mythic 결과 유지.

## 목표

플래그 ON에서 **어떤 경로도 신화 아이템을 지급하지 않는다.** 대신:
- 신화 **상자**(guaranteed + 가중치 mythic) → **확정 신화퍽 지급** (D3 채널).
- 나머지 3경로(필드/판도라/보물)의 신화 누수 제거.

이로써 (a) 죽은 아이템 소멸, (b) 현재 획득불가한 신화퍽 11종에 획득 채널 부여.

## 핵심 신설: 신화퍽 그랜트 헬퍼

- **랜덤 미보유 신화퍽 1개를 Lv.1로 지급.** 후보 = `CONVERTED_MYTHIC_PERKS` 중
  `runtime_skill_levels[id] == 0`인 것. character_restriction 있으면 준수(현재
  신화 11종은 무제한이나 방어적으로 필터).
- **표준 퍽 apply 경로로 지급** (runtime_perk_state의 apply_choice 등가) — 효과
  게이트·HUD·피드백이 정상 발동하도록. 직접 `runtime_skill_levels[id]=1`만
  꽂지 말 것(사이드이펙트 누락 위험). get_perk_data(id)로 choice 구성 후 apply.
- **폴백**: 미보유 신화퍽이 없으면(11종 전부 보유 — 극히 드묾) 스타포인트
  보상으로 대체(guaranteed 상자는 넉넉히, 예: SP2~3).
- 공용 헬퍼로 만들어 상자/보물이 재사용.

## 경로별 처리 (flag ON)

| 경로 | 처리 |
|---|---|
| ① 스테이지클리어 상자 | REWARD_MYTHIC 결과를 **신규 `REWARD_MYTHIC_PERK`**로 전환 → 신화퍽 그랜트 헬퍼. guaranteed 상자 = 확정 신화퍽. 결과화면 표시도 "신화 퍽"으로(아래 UI) |
| ② 필드 스폰 | 플래그 ON이면 mythic 그룹도 스폰 제외 (기존 passive 제외에 mythic 추가 — 필드는 액티브 전용). 신화퍽은 필드 픽업이 아니라 상자 채널로 |
| ③ 판도라 | 플래그 ON이면 build_mythic_pool도 empty (build_passive_pool과 동일) → 판도라 3택 = 액티브만 |
| ④ 보물탐색 | 플래그 ON이면 mythic 결과도 신화퍽 그랜트 헬퍼로 (또는 폴백 스타포인트). passive→SP와 동일 위치에서 |

## 결과화면 UI (신화 퍽 표시)

스크린샷의 "신화 아이템 1: 바알의 부츠" 섹션이 이제 **신화 퍽**을 표시해야 한다.
- 신화퍽 보상은 **퍽으로 렌더**(방금 만든 8프레임 애니 아이콘 재생) — 아이템
  아이콘이 아니라 `runtime_perk_icon_renderer`의 신화 시트 경로 사용.
- 라벨: "신화 퍽" 또는 획득 퍽 섹션에 통합(코드 구조상 자연스러운 쪽 —
  `stage_clear_result_*` 리워드 표시 빌더를 추적해 결정). 죽은 아이템 표시 금지.
- 보상 요약/카운트(`mythic_granted` 등)도 퍽 그랜트를 반영.

## 범위 (이번 실행)

1. 신화퍽 그랜트 공용 헬퍼 신설.
2. `stage_clear_reward_resolver.gd`: `REWARD_MYTHIC_PERK` 타입 + roll 전환(flag ON,
   guaranteed/가중치 mythic) + `grant_rewards` 그랜트 경로 + 결과 요약.
3. 결과화면 표시(`stage_clear_result_*`): 신화퍽 리워드를 퍽(애니 아이콘)으로 렌더.
4. 필드/판도라/보물 신화 누수 제거(위 표).
5. 스모크 + 적대 리뷰.

## 범위 제외

- 신화퍽 3택 셀렉션 UI(랜덤 그랜트로 충분, 셀렉션은 후속 폴리시)
- 세이브 마이그레이션(기존 세이브 장착 신화 아이템 → 퍽, 별도 S5 항목)
- 일반 오퍼에 신화퍽 노출(초희귀 채널은 상자로 확정 — 일반 오퍼 제외 유지)
- flag OFF 경로(전부 기존 그대로 — flag OFF는 신화 아이템 정상 드랍)

## 스모크 (신설: `godot/tests/perk_conversion_mythic_perk_channel_smoke.gd`)

- [ ] flag OFF: 4경로 모두 기존대로 신화 **아이템** 지급(회귀)
- [ ] flag ON: 상자 mythic 결과 → 신화 **퍽** 그랜트(runtime_skill_levels에 신화
      퍽 레벨 1), **신화 아이템 미지급**(equipment reward 아님)
- [ ] flag ON: guaranteed_mythic 상자 → 확정 신화퍽 1개
- [ ] flag ON: 미보유 신화퍽 소진 시 폴백 스타포인트
- [ ] flag ON: 필드 스폰 mythic 0건, 판도라 mythic 풀 empty, 보물 mythic→퍽/SP
- [ ] flag ON: 어떤 경로도 `_grant_equipment_reward`로 신화 아이템을 넣지 않음
- [ ] 신화퍽 그랜트가 표준 apply 경로 경유(효과 게이트 활성 확인 — 예: 지급 후
      해당 신화퍽 효과 게터가 활성값 반환)

## 반증검증 (필수 — git reset/checkout/stash 금지, in-place 토글 + 즉시 복원)

1. 상자 mythic→퍽 전환 게이트 임시 제거 → "flag ON 상자 신화 아이템 미지급" 레그
   RED → 복원
2. 그랜트 헬퍼의 apply 경로를 직접 level=1 꽂기로 임시 변경 → "표준 apply 경유"
   레그 RED → 복원

## 트랩 노트

- 스타포인트 단위 트랩: 폴백 스타포인트는 ★1~3 범위(collect_star_points 직결
  대량값 금지 — 모달 폭주).
- 신화퍽 그랜트는 exempt 유지(신화퍽은 유효레벨 보너스 비대상 — S1b 규칙).
- 결과화면이 리워드를 type으로 분기하므로(`REWARD_MYTHIC` 분기 존재), 신규
  타입 누락 시 조용히 빈 슬롯/폴백될 수 있음 — 표시 경로 끝까지 추적.
- 핫패스 아님(보상은 상자당 1회). owner set() 스키마 트랩 주의(신규 owner 키
  필요 시 중단·보고). UTF-8 BOM 금지, `.agents/skills/` 미러 수동 편집 금지.

## 완료 보고 형식

(1) 변경 파일 + 4경로 처리 지점 + 그랜트 헬퍼, (2) REWARD_MYTHIC_PERK end-to-end
(resolve→grant→결과표시) 배선, (3) 결과화면 신화퍽(애니 아이콘) 렌더 확인 +
스크린샷, (4) 신설 스모크 결과 원문, (5) 반증검증 2건 RED→GREEN, (6) flag OFF
회귀 무변화 자가 확인, (7) 이탈/가정.
