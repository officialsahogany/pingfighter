# §9-3 슬라이스 2 핸드오프 (Codex 실행용) — 영혼소환술 공용 초식 + 알 드랍·게이트·2~4타 부화

작성 2026-07-28. 기획 정본 = `docs/lingpet_guardian_duration_redesign_plan.md`
(§2·§4 필독). 선행 = 슬라이스 1 종결(b52e62e1d) + 수납 투영 분리(dc2b84466).
착수 기준 HEAD = 현재 브랜치 최신 (슬라이스 1 이후 커밋 포함). 이 문서 전체를
붙여넣으면 자기완결로 착수 가능하다.

## 0. 공통 가드레일 (슬라이스 1과 동일)

- git reset / checkout / stash 절대 금지. `git add -A` 금지 — 명시 경로만.
- 로컬 커밋만, 푸시 금지. 커밋 전 `git diff --check`, 커밋 후 목록 대조.
- 불가침: 정산 보류분 + 외래 캠페인 dirty(부동갑주·플라자 분해·퍽 파이프라인·
  프레임 컨트롤러·로딩팁·game_audio·활주방울/기력구슬 HUD·캐릭터정보 레이아웃
  WIP). CI 파일(`godot-ci.yml`·`run_pre_push_checks.ps1`)·ownership ledger
  접촉 금지 (등재는 외래 정산 후 별도 커밋).
- `docs/character_skill_perk_checklist.md`를 열고 작업할 것 (스킬/퍽 통합
  체크리스트 소유 문서). 완료 시 신규 "공용 초식" 카테고리 존재를 체크리스트에
  기입(문서 백필 1커밋 허용).

### 씰 실행 규정 (병렬 에디터 간섭 회피 — egg_runtime 일과성 RED 전례)

- 씰 실행 전 **Godot 에디터/라이브 세션이 닫혀 있거나 임포트·저장 중이 아닌
  시점**을 확보할 것.
- 판정은 표준 러너(`run_smoke_tests.ps1`) 또는 직접 godot 호출 + `ERROR:`/
  `SCRIPT ERROR` grep. 러너 출력은 Write-Host라 파이프라인 캡처가 안 되니
  종료 코드/원문으로 판정.
- RED 발생 시 **동일 씰 단독 2회 재실행**으로 일과성 여부를 판별하고, 보고에
  RED 원문과 재실행 결과를 함께 첨부 (일과성이어도 은폐 금지).

## Gate 0′ (슬라이스 착수 전 선행, 독립 커밋) — stats_projection 고아쌍 복원

`character_info_lingpet_stats_projection_smoke`가 3단언 RED다 (card_specs와
같은 WIP 소실 고아쌍 — 프레젠터 퍼사드 위임만 소실). **씰 수정 금지**, 씰이
스펙이다. `character_info_overlay_lingpet_presenter.gd`가
`character_info_overlay_lingpet_stats_projection.gd`로 위임하도록 복원:

1. presenter build-stats 퍼사드 → stats_projection 위임
2. presenter cached-stats 퍼사드 → stats_projection 위임
3. presenter stats-hash 퍼사드 → stats_projection 위임

완료 조건: 3단언 GREEN + presenter 계열 회귀(card_specs 포함) GREEN.
독립 커밋 후 슬라이스 2 착수.

## 1. 공용 초식 "영혼소환술" 계약

### 1-1. ID·소유권·레벨

- 스킬 id = **`soul_summon_art`**, 퍽(무공) id = **`unlock_soul_summon_art`**,
  표시명 "영혼소환술" (7언어 카피 동반).
- **소유권 정본 = 신규 공용 모듈 1개** (예:
  `godot/scripts/characters/common_skill_catalog.gd`) — 메타데이터(id·표시명·
  슬롯 점유·툴팁 필드·아이콘 참조)를 여기 단일 정의하고, **5캐릭터
  skill_config(smasher/viper/commando/blacksmith/optimus 경로)는 이 공용
  정의를 참조로 노출**한다. 5곳 복붙 정의 금지 (드리프트 방지).
- 레벨 개념 없음: `runtime_skill_levels["soul_summon_art"] = 1` 고정,
  레벨업·강화 대상 아님.
- 등록 매트릭스: `slot_occupancy = active_orb`(초식구슬 5칸 중 1칸),
  `cooldown_reduction_eligible = false`(쿨다운 자체가 없음 — 쿨감 퍽의 죽은
  대상 방지), cleanup은 unlock 계열 표준 스왑 경로.
- Optimus 특례: until-timestamp 쿨다운 경로와 무관(쿨다운 없음) — 등록·슬롯
  카운트만 정확하면 됨. Soldier 공유 화기 슬롯: 만석 카운트에 영혼소환술이
  1칸으로 합산되는지 명시 확인.

### 1-2. 획득 경로 (무공 풀)

- 영혼소환술 **미보유일 때만** 무공 선택지에 등장. 획득 보장을 위해
  **미보유 상태의 첫 1~2 무공 화면에 확정 예약 등장**(링코어 레인의
  reserve-by-tier 패턴 재사용), 미선택 시 이후 3화면 쿨다운으로 재등장.
- 슬롯 만석 시 기존 unlock 스왑 다이얼로그 흐름. **취소는 완전 no-op**
  (레벨·해금·알 드랍 어느 것도 발생하지 않음).
- 퍽 융합 제외 목록 등재.

### 1-3. 제거(스왑 아웃) 시 거동

- 영혼소환술을 스왑으로 제거하면: 소환 중이던 수호령 **강제 수납** + 재획득
  전까지 소환 불가 + 알 스폰 재잠금. 이미 보유한 펫·지속시간 풀·버프는
  삭제하지 않고 보존(재획득 시 그대로 복귀).

## 2. 선택 즉시 알 1개 드랍 + 중복 게이트

- `unlock_soul_summon_art` 적용 성공 시(스왑 취소가 아닌 경우) **즉시 필드에
  수호령알 1개 드랍** — 기존 `deploy_egg_from_item` 필드 배치 경로 재사용.
- **드랍 생략 게이트 3분기** (초식 획득 자체는 항상 유효, 알만 생략):
  1. 필드에 이미 수호령알이 존재
  2. 로스터(보유 3) 만석이고 오버플로 후보도 불가
  3. `has_unowned_pet_candidates` false (미보유 펫 없음)
- 인큐베이터 item-egg 이중경로(coexist) 패리티는 기존 계약 유지.

## 3. 알 스폰 해금 게이트 (미보유 = 미해금)

- `can_offer_egg_item`에 "영혼소환술 보유" 조건 추가. **4중 게이트 전부**에
  걸 것 (item_runtime_checklist §1.7): 스폰풀
  (`_should_skip_lingpet_egg_spawn`) · 픽업(slot_controller) ·
  `deploy_egg_from_item` 가드 · direct-grant(Pandora/플라자 가챠) 경로.
  판독은 non-instantiating cached peek (hot-path lazy-init 트랩).
- 미보유 시 스폰풀 지분은 기존 skip 패턴대로 다른 후보로 자연 재분배.
- **주니어/오토프레젠트 리그 면제**: auto-present 리그는 게이트 통과(초식
  없이도 기존 자동 지급 흐름 유지 — 슬라이스 1 드레인 면제와 같은 latch).
- §2의 퍽 트리거 드랍은 이 게이트와 별개 경로(초식 획득 직후이므로 항상
  보유 상태) — 게이트에 막히지 않음을 씰로 확인.

## 4. 2~4타 부화

- 스폰 시 required hits 롤 풀을 `[1,2,3]` → **`[2,3,4]`** 로 변경 (스폰마다
  랜덤, 기존 방식 유지, 결정론 RNG 주입 가능).
- **양쪽 부화 경로 모두** 동일 풀: 정규 필드 알(`lingpet_egg_field_state`) +
  item-egg/overflow 경로. 한쪽만 남으면 이중경로 패리티 위반.
- 크랙 오버레이 2단은 진행 비율 매핑 유지 (required 4일 때도 크랙 1→2→부화
  순서가 자연스럽게 배분되는지 확인 — 비율 기반이면 무수정).

## 5. 원자 랜딩 (반쪽-랜딩 트랩 방지 — 링코어 "슬롯 6/6에 8칸" 전례)

슬롯 카운터 브리지·툴팁·오퍼 UI를 **같은 슬라이스에** 랜딩한다:

- **카운터 브리지**: 슬롯 만석 판정이 영혼소환술을 실제 1칸으로 카운트.
  표시(툴팁의 "슬롯 1칸 사용")와 카운터가 같은 커밋에 존재해야 한다.
- **툴팁**: 초식 툴팁 표준 포맷(헤더/상태/설명 3줄 이내/입력 안내 = Ctrl·R3
  토글, 쿨다운 표기 없음). `how_to_use`는 단일 문장·`\n` 금지. 7언어.
- **오퍼 UI**: 무공 카드에 "선택 즉시 수호령알 1개가 떨어진다" 효과 문구
  포함. 아이콘은 **절차 placeholder 허용** — 정식 아이콘 아트는 별도 아트
  트랙(imagegen)으로 후속, 보고서에 미결로 명시. 절차 아이콘도
  `draw_skill_icon` 계열 elif/레지스트리 등재 필수(첫 글자 폴백 금지).

## 6. 씰 계약 (신규 4종, 각각 반증검증 1회)

1. `soul_summon_art_skill_contract_smoke`: 5캐릭 config 전부에서 공용 정의
   노출(단일 소스 참조 확인), 슬롯 점유 1칸 카운트 — **픽스처는 슬롯 예산을
   가득 채워서** 만석 판정을 단언(미달 픽스처는 오버플로로 실패 불가 —
   반쪽랜딩 트랩 규정), 스왑 취소 완전 no-op, 제거 시 강제 수납+재잠금+펫
   보존.
2. `soul_summon_art_egg_grant_smoke`: 퍽 적용 즉시 알 드랍 + 생략 게이트
   3분기 각각 + 스왑 취소 시 드랍 없음.
3. `guardian_egg_gate_smoke`: 4중 게이트 미보유 잠금 / 보유 해금 / 주니어
   면제 / 퍽 트리거 드랍은 게이트 비저촉.
4. 부화 풀 [2,3,4]: 롤 범위·양 경로 패리티 (기존 egg 씰 확장 또는 신규 —
   기존 "3-hit egg" 단언들의 픽스처가 풀 변경과 충돌하지 않는지 정리).
- 회귀: egg_runtime·duration_pool·toggle·stow·collection·switch·card_specs·
  stats_projection(Gate 0′ 이후 GREEN 기준) 유지.

## 7. 커밋 분할 제안 (원자, 순서)

1. Gate 0′: stats_projection 퍼사드 복원 (+씰 GREEN)
2. 공용 초식 카탈로그 + 5캐릭 config 노출 + 슬롯 카운터 브리지 + 툴팁/오퍼
   UI + 7언어 (+씰 1)
3. 퍽 등장 예약 레인 + 적용 시 알 드랍 + 생략 게이트 (+씰 2)
4. 알 스폰 4중 게이트 + 주니어 면제 (+씰 3)
5. 부화 풀 [2,3,4] 양 경로 (+씰 4)
6. (허용) character_skill_perk_checklist 공용 초식 카테고리 백필 docs 커밋

## 8. 완료 보고 형식

커밋 해시별 요약 / 씰 실행 결과 원문(실행 규정 §0 준수 명시) / 반증검증
기록 / 슬롯 만석 픽스처가 예산을 가득 채웠는지 명시 / 미결(아이콘 아트 등)·
발견 사항.
