# 수련(기초 수련) 시스템 구현 핸드오프 — Codex

작성 2026-08-05. **설계·수치 전건 확정(사용자 승인), 코드 미착수 — 이 문서가 구현 지시서다.**
계약 정본: `docs/perk_training_category_plan.md` (§ 번호 인용은 전부 그 문서 기준).
결정 사슬: e9edd3496(계약 v2) → 286045aa0(리뷰3) → 2a57122bb(리뷰4) → 5cc30026a(확정 도장).
계약 자체를 여기 재서술하지 않는다 — 착수 전 정본 §2(계약)·§3(카탈로그)·§4(호환 정책)를 먼저 읽을 것.

## 0. 확정 구현 시작값 (요약)

| 항목 | 값 |
|---|---|
| 수련 10종 회당 수치 | 정본 §3 표 (철심공·격기심법 **+3%/회**) |
| 회수 상한 | 기본 5회 · 태허심법 4회 · 수납술 1회 · **런 전체 6회** |
| 주사위 등장 확률 | **25%** (계측용 기본값, 런 3회 제한 불변) |
| 수련 조건부 확률 | **40%** (주사위 실패 시에만 판정, 체감 30%/40% 2구간) |
| 수납술 선택 가중치 | **0.5** (일반 수련 1.0 대비, 별도 확률 게이트 없음) |
| 내부 ID 프리픽스 | `physique_*` (`training_*` 금지 — §2.3) |
| 카드명 | 기존 무공명 승계 + " 수련" 접미사, 신규만 "수납술 수련" |
| 골드변환 | 완전 제거·폴백 없음 (표시 지원 코드는 보존 — §2.2) |
| 조식심법 | v1 잔류 (이관 금지) |

## 1. 아키텍처 지시 — 신규 owner 모듈 3개 (주사위 패턴 미러)

신비의 주사위 3분할(`mystic_dice_offer_planner` / `mystic_dice_state` /
`runtime_perk_mystic_dice_runtime_state`)을 그대로 미러한다:

- `scripts/characters/physique_training_catalog.gd` — 10종 데이터(표시명·회당
  수치·개별 상한·가중치·대상 스탯 키·현재값 포맷터 힌트). 정본 §3 표가 원본.
- `scripts/characters/physique_training_state.gd` — 능력치별 습득 횟수·누적량,
  런 전체 카운터, 상한 판정, 저장·복원 직렬화. **런 초기화는
  `RuntimePerkState.reset()` 계열 런-리셋 경로에 결합**(‼ `reset_round` 금지 —
  실점마다 재발동). 저장 채널은 주사위/합일 상태와 같은 경로를 미러.
- `scripts/characters/physique_training_offer_planner.gd` — 보조 레인 판정
  (조건부 40% → 상한 미도달 후보만 가중 추첨, 수납술 0.5 → 카드 dict 빌드).
  후보 0장 또는 런 6회 소진 시 **완전 no-op**(죽은 카드 금지 — §2.3).

## 2. 슬라이스 순서

### S1 — 오퍼 파이프라인 개편 (골드 제거·주사위 재배선·천안결 재작성)

파이프라인 소유자는 `runtime_perk_choice_open_flow.open_next_choice`
(:210-296 — 천안결 카운트 → `catalog.get_choices(target)` → 천안결 표식
:272-283 → ready). 정본 §2.1 순서를 이 흐름 위에 실현한다.

1. `runtime_perk_catalog.gd`: `get_choices` 말미의 골드 카드 상시 append 제거
   (:1389-1391 근방). **보존**: by-id 조회(:1442-1445), `is_gold_conversion`
   분기(:1506), 디버그 엔트리(:1631-1634) — 기존 씰 2종 불변 유지용(§2.2).
2. `mystic_dice_offer_planner.gd` + `runtime_perk_mystic_dice_runtime_state.gd`:
   `_find_gold_lane_index` 교체 방식 → **보조 레인 append** 방식으로 재작성,
   `APPEARANCE_CHANCE` 0.5 → **0.25**. 런 3회 제한·상한 소진 시 미등장 로직 불변.
3. `runtime_perk_choice_offer_modifiers.build_dowsing_bonus_state_update`
   재작성: 게이트의 `+1`(골드 전제) 제거 →
   `choices.size() < target_choice_count` 시 거부, `bonus_card_index =
   target_choice_count - 1` (마지막 기본 카드; 보조 레인 append **이전** 시점이라
   안정). 보호 레인 스탬프(`offer_lane="dowsing_bonus"`, `offer_protected`) 유지.
4. 보조 레인 판정(주사위 → 실패 시 수련)은 **천안결 표식 이후** 시점에 배선.
   합일 교체(`perk_fusion_offer_planner`, 기본 레인 replaceable 교체)는 불변.
5. 주사위 **적격 화면 수 계측 채널**(런당 카운터 로그 1줄)을 같이 심는다 —
   §9-4의 25% 재확정용.

### S2 — 수련 코어 (state·적용 배선·카드 UI)

1. §1의 신규 모듈 3개 생성. 스탯 적용은 **query surface 단일 지점 합산**:
   `runtime_perk_effective_stat_query_surface.gd`에서 각 이관 스탯의 기존 게터
   (은퇴 무공 id를 소비하는 함수)에 training 항을 합산한다 — 게임플레이·HUD·
   툴팁이 자동 동기되는 지점이 그곳뿐이다. 개별 콜사이트 산개 합산 금지.
   - 순환결: `get_active_item_cooldown_msec`의 퍽 단계에 곱산 —
     `active_item_cooldown_composer` 체인이 5% 하한을 자동 강제(§3). **합성기
     우회 금지, 하한 재구현 금지.**
   - 수납술: `RuntimePerkState.get_active_item_slot_capacity`(퍽 계층 정본
     쿼리)에 +1 합산 — owner_state 최종 합성·슬롯 컨트롤러·기존 스모크가 전부
     이 지점을 읽는다. **총 슬롯 상한 신설 금지**(§3).
2. 카드 UI: **현재값 → 적용 후 값** 표시(§2.3, 예 `활주 거리 210px → 216px`).
   현재값 포맷은 `character_info_overlay_stats_presenter`의 능력치 패널 포맷터
   재사용. 선택 즉시 커밋·선택권 1회 소모.
3. 능력치 패널 원인표기(stat source breakdown)에 "수련" 소스 라인 추가(§2.4).
4. owner 동기 키를 쓴다면 `BattleSceneState.DEFAULT_VALUES` 선언 필수.

### S3 — 9종 이관 게이트 + 제외 계약

1. 9종(dash_lightweight·dash_module_control·dash_jump·common_swiftness·
   common_bulk_up·bulletproof_hat·fuel_pouch·bluetooth_ring·
   item_cooldown_mastery)을 **신규 제안 생성에서만 제외**하는 flag 게이트.
   카탈로그 데이터·ID·기보유 런 효과·표시·합일 기록 전부 보존(§4).
   ⚠ `exclude_from_perk_fusion` 플래그를 9종에 **찍지 마라** — 기보유 런의
   합일·한계돌파 기능은 유지가 계약이고, 신규 런은 보유 불가로 자연 제외된다.
2. 개광결 툴팁 제외 문구에 "수련" 명시(§2.4) + 다국어 동기.
3. 디버그 피커: 은퇴 9종 일반 목록 숨김 + 레거시 호환 주입 경로 유지, 신규
   수련은 별도 '수련' 그룹(§9-7).

### S4 — 다국어 + 씰 + 실렌더 QA

1. 다국어는 `language_settings_data.gd` 중심(시스템 카드라 skill_config 경로
   아님 — §8): 수련 카드명 10종·설명·카테고리 라벨·주사위 툴팁("골드 카드를
   교체" 서술 제거)·개광결 제외 문구, 7언어 전부.
2. 씰 매트릭스는 §4 참조(아래).

## 3. 트랩 경고 (구현 중 실제로 밟을 순서대로)

1. **천안결 골드 전제 2곳** — `+1` 게이트와 `size-2` 인덱스. 게이트만 고치면
   표식이 보조 레인 카드에 붙는 2차 사고가 난다(§2.1-3).
2. **반쪽-랜딩 거울상**: 9종 제외 flag가 그 id를 스케일하던 소비자를 조용히
   0으로 만들 수 있다 — grep은 flag가 아니라 **9개 ID 각각**으로, 후보 수를
   세는 소비자의 빈-그룹 가드 확인, 씰은 flag-ON 레그로(§4).
3. **`reset_round` 금지** — training_state 초기화는 런 경계 훅만.
4. **상한 도달 시 카드 등장 자체 중단** — 선택해도 효과 없는 죽은 카드 금지.
5. **레거시 배낭(slot_add) 호환 불변** — 최종 슬롯 합성의 신화 계층과
   `bag_expansion_mugong_removal_smoke` 3→5 레그를 건드리지 마라(§5.8).
   "연환보 5단계 단독 8칸" 스모크 레그는 픽스처 전용 — 밸런스 근거 인용 금지.
6. **확률 표기 계약** — 문서·툴팁·주석에 조건부(40%)와 체감(소진 전 30%/후
   40%)을 병기.
7. **스모크 공허-GREEN** — `_expect`의 `quit(1)`은 실행을 안 멈춘다. `_failed`
   플래그로 말미 `ok`를 게이트하고 표준 러너(`run_smoke_tests.ps1`) 관통으로
   판정. 유닛이 게이트를 우회하면 공허-GREEN이다.
8. **다국어 grep 0건 단정 금지** — 문구 키는 7언어 맵 전부에서 확인.

## 4. 씰 매트릭스

- **갱신 5종**: `mystic_dice_offer_rotation_smoke`(교체→append 계약 전체),
  `dowsing_goggles_port_smoke`(3/4장 + target 기준 표식 위치),
  `perk_slot_limit_smoke`(만석 골드 유지 계약 제거),
  `runtime_perk_fusion_offer_integration_smoke`(골드 보호 레인 공존 단언 교체),
  `perk_offer_owned_upgrade_priority_smoke`(예약 레인 수·마지막 진입로).
- **신규**: ① 보조 레인 배타성(골드 없음 + 주사위/수련 중 최대 1장·주사위
  우선·합일과 공존) ② training_state 저장→복원 왕복(누적치·횟수 일치)
  ③ 개별·런 전체 상한 강제(도달 후 미등장 포함) ④ 9종 신규 제안 제외 +
  기보유 런 기능 유지 양방향 ⑤ 순환결 수련이 composer 하한을 관통(95% 캡)
  ⑥ 수납술 capacity 정본 쿼리 합산(슬롯 컨트롤러 수용 왕복) ⑦ 수련 카드
  현재값→적용값 표기.
- **불변 보존**: `mythic_perk_acquisition_cinematic_smoke`,
  `perk_single_level_tag_smoke`(골드 표시 지원 코드 보존 전제),
  `bag_expansion_mugong_removal_smoke`.

## 5. 수용 게이트

1. 표준 러너 전체 GREEN(엔진 `ERROR:` 실패 승격 포함).
2. **반증 검증(SAFE)**: 신규 씰 최소 2종(배타성·상한)을 in-place Edit 토글로
   버그 재현 → RED 확인 → 원복 → GREEN. **`git reset`/`checkout`/`stash` 절대
   금지**(이 저장소는 미커밋 WIP 파괴 사고 이력이 있다).
3. 선택지 3장(기본)/4장(천안결)/5장(천안결+보조 레인) 실렌더 캡처 —
   `runtime_perk_choice_layout`은 동적이지만 픽셀 확인 필수.
4. 라이브 QA 1판: 골드 카드 부재, 주사위·수련 카드 등장, 현재값→적용값 표기,
   상한 후 미등장, TAB 능력치 패널 "수련" 원인 라인.
5. 커밋 규율: 슬라이스별 자립 커밋·헝크 분리. 워크트리에 무관 WIP가 대량
   혼재하므로 **통짜 `git add` 금지**, 신규/수정 파일 명시 add만.

## 6. 비차단 잔여 (구현과 별도 트랙)

- 수납술 수련 아이콘(신규 1종) — 임시 폴백 허용, 아트는 별도 트랙.
  이관 9종 수련 카드는 기존 무공 아이콘 재사용(승계 명칭과 정합).
- 주사위 25% 재확정 — S1의 계측 채널 데이터가 쌓인 뒤 별도 결정.
- 잔여 수치형 무공(조식심법 등) 분류 감사 — §6, 별도 트랙.
