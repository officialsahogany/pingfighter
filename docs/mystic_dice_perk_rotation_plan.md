# 신비의 주사위(Mystic Dice) 퍽 로테이션 — 디자인 플랜

작성 2026-07-10. 설계의 단일 소스는 이 문서다. Codex 배선용 기획서이며,
퍽 융합 플랜(`docs/perk_fusion_system_plan.md`)과 같은 문서 계약을 따른다.

> **현행 전환 계약 (2026-08-06):** 아래 로테이션 설계는 이력 보존용이다.
> 신비의 주사위는 더 이상 퍽 오퍼에 등장하지 않고 희귀 소모성 액티브
> 아이템으로만 신규 획득된다. 오퍼 은퇴는
> `MysticDiceOfferPlanner.OFFER_ROTATION_ENABLED == false`가 소유하며,
> 액티브 아이템 사용 횟수는 `uses_unlimited == true`와 `-1` 센티널을 함께
> 제공한다. 사용 횟수 표현을 바꿔도 은퇴한 퍽 오퍼가 되살아나서는 안 된다.

경위:

1. 사용자 제안: 퍽 선택 화면 맨 오른쪽 골드변환 카드를 원본 핑파이터
   "악마의 주사위" 액티브 아이템 효과로 교체.
2. Claude 검토: 완전 교체는 이코노미 탈출구(골드변환) 상실 + EV 0 문제
   + 누적 폭주 위험 → **A안 로테이션** 권장.
3. 사용자 확정: **A안 로테이션 채택. 이름 "신비의 주사위"로 변경, 컨셉도
   악마→신비로 리스킨. 롤 범위 -5%~+10% 방향 채택.**
4. 본 문서 작성 (원본 `item_effects/devil_dice.py` 계약 대조 +
   현행 Godot 앵커 조사 완료 반영).

원본 참조: `item_effects/devil_dice.py` (frozen Python, 참고 전용).
포팅 방침은 `feedback_default_target_godot` 표준 — 원본 숫자/타이밍은
1차 참고, 의도 분기는 본 문서에 기록.

---

## 1. 컨셉 요약

퍽 선택 화면(3택 + 맨 오른쪽 대안 카드)의 **대안 카드 자리가 로테이션**
된다: 어떤 화면에서는 기존 **골드변환**(500골드), 어떤 화면에서는
**신비의 주사위**가 등장한다.

신비의 주사위 = 퍽을 포기하는 대신 7가지 능력치를 각각 소폭
**영구(런 한정) 조정**하는 도박 카드. 원본 악마의 주사위의 굴림 →
결과 확인 → 다시 굴리기/확정 루프를 그대로 계승하되, 컨셉/비주얼을
"악마(붉은 기운)"에서 **"신비(청보라·별빛·아케인)"**로 리스킨한다.

### 1.1. 원본(devil_dice.py) 계약 요약

| 항목 | 원본 값 | v1 계승 여부 |
|---|---|---|
| 대상 스탯 | 7종: 이동속도·몸집크기·최대 게이지·대쉬거리·대쉬후딜·대쉬쿨·아이템쿨 | 계승 (§5) |
| 롤 범위 | 정수 -10~+10 (대칭, EV 0) | **변경: 굴림당 ±3, 런 누적 캡 ±9 (§2, 2026-07-12 재조정)** |
| 누적 | 사용마다 영구 누적, 세이브 저장 | run 한정 누적으로 변경 (§6) |
| 리롤 | 총 3굴림 (첫 굴림 + 다시 굴리기 2회), 7스탯 묶음 재굴림 | 계승 |
| 취소 | 없음 (발동 즉시 굴림, 확정만 가능) | 계승 (§4 D2) |
| LOWER_IS_BETTER | dash_recovery / dash_cooldown / item_cooldown (음수=이득, 색 반전) | 계승 + 롤 미러 (§2) |
| 연출 | 주사위 낙하 바운스 2초 → 눈금 잠금 → 호버 대기 | 계승, 신비 리스킨 (§7) |
| 확정 후 | 패들 어두운 기운 파티클 3초 | 계승, 청보라 리스킨 (§7, 후순위) |
| 리셋 | 게임오버/메인메뉴 복귀 시 전체 초기화 | run 리셋 경계로 계승 (§6) |

---

## 2. 롤 모델 + 방향성(polarity) 규칙

### 2.1. 벤핏 공간 롤 (핵심 계약)

굴림은 스탯당 **벤핏 공간(beneficial space) 정수 균등분포
`[-3, +3]`**로 정의한다 (2026-07-12 재조정, §2.4 근거). 양수 = 플레이어에게 유리.

raw(실제 배율에 곱하는 부호 있는 %) 변환은 스탯 방향에 따라 갈린다:

- **일반 스탯** (이동속도·몸집크기·최대 게이지·대쉬거리):
  `raw = benefit` → raw ∈ [-3, +3]
- **낮을수록 좋은(LIB) 스탯** (대쉬후딜·대쉬쿨·아이템쿨):
  `raw = -benefit` → **raw ∈ [-3, +3]** (범위는 대칭이라 같지만 부호 반전 자체는 필수)

적용 산식은 전 스탯 공통: `최종값 = 기본계산값 × (1.0 + raw누적 / 100.0)`.
LIB 스탯은 raw가 음수일 때 프레임/msec가 줄어 이득이 된다.

**⚠ polarity 미러는 범위가 대칭이 된 뒤에도 여전히 최중요 함정이다.**
범위가 [-3,+3]으로 대칭이라 미러링을 빼먹어도 *범위*는 안 바뀌지만,
LIB 스탯에서 `raw = -benefit`을 안 하면 "벤핏 +3(유리)"이 raw +3 =
쿨타임 +3%(불리)로 적용돼 **색(초록=유리)과 실제 효과가 어긋난다**.
즉 미러는 범위가 아니라 부호-의미 정합을 지키는 계약이다. 스모크 반증 대상 (§9).

### 2.2. 기대값 분석 (밸런스 근거, 2026-07-12)

- 분포 자체는 대칭이라 스탯당 명목 EV = 0. **단, 다시 굴리기(3판 중
  best 선택)가 있어 실제 확정치는 소폭 +로 치우친다** — 함정 카드는
  아니고 "작은 행운" 스파이스. 타겟팅(한 스탯만 리롤로 노림) 시 그
  스탯 실현치 ≈ +2~3%p/사용.
- 사용 캡 3회(§3.3) 기준 런 최대 누적: **스탯당 최악 -9% / 최선 +9%**
  (3굴림 × ±3). 방어적 상수 `MYSTIC_DICE_RAW_ABS_CAP := 9` (= 자연
  최대치와 동일한 정수 클램프). 3회 정직한 굴림은 이 캡을 초과하지
  않으므로 캡은 순수 방어 바운드(사용 캡 증가/이중적용 대비).

### 2.4. ±3 재조정 근거 (신속·벌크업 정체성 보존)

기존 -5~+10 캡 ±30 모델은 주사위 한 스탯 최대치(+30%)가 만렙 신속/
벌크업(각 +30%)과 **정확히 같아**, ①"+30%"라는 목표 수치가 더 이상
전용 퍽만의 것이 아니게 되고 ②곱연산으로 겹치면 신속 Lv.5 × 주사위
+30 = ×1.69로 설계 천장을 뚫는 문제가 있었다 (사용자 발견).

±3/캡±9로 낮추면 주사위는 어느 스탯에서도 만렙 패시브(+30%)의
**최대 30%(=+9%)** 만 도달, 곱연산 겹침도 신속 Lv.5 × +9 = ×1.417로
천장을 사실상 안 뚫는다. 주사위는 "여러 스탯을 넓게 살짝 뿌리는"
고유 정체성으로 분리되고, 신속·벌크업은 "제대로 투자하는 확정 루트"로
남는다. LIB 3종은 이전에도 -15 한계라 패시브(-60~90%) 대비 부수효과라
영향 없음 — 이 재조정은 사실상 일반 4스탯(특히 신속/벌크업 겹침) 대상.

### 2.3. 롤 규칙 상세

- 다시 굴리기는 원본대로 **7스탯 묶음 전체 재굴림**. 개별 스탯
  잠금/선택 리롤은 v1 금지 (EV 상승 폭주 방지, v2 여지로만 기록).
- 리롤 시 직전 굴림은 완전 폐기된다 (확정 전 누적 반영 없음).
- 난수는 offer/롤 시점 1회 (per-frame 재롤 금지 — CLAUDE.md
  Per-Frame Probability Roll Trap). 테스트 가능성을 위해 융합
  `plan_offer(..., roll_unit)` 패턴처럼 **롤 유닛을 인자 주입**하는
  순수 플래너/롤러로 작성한다.

---

## 3. 등장 로테이션 규칙

### 3.1. 골드 lane 스왑 (offer 후처리)

- `runtime_perk_catalog.get_choices()`는 **건드리지 않는다**. 카탈로그는
  지금처럼 골드변환을 마지막에 append한다 (`runtime_perk_catalog.gd:1362-1364`,
  lane `"gold"`, protected). 카탈로그는 source를 모른다 — 융합 §6.1과
  같은 근거로 카탈로그 안에서 로테이션을 몰래 섞지 않는다.
- 로테이션은 **choice open flow의 offer 후처리 단계**에서 수행한다.
  선례: `runtime_perk_state.gd:223 _try_inject_perk_fusion_offer` +
  `perk_fusion_offer_planner.gd` (순수 플래너 + 롤 유닛 주입).
  신규 `mystic_dice_offer_planner.gd`가 최종 choices 배열에서
  `offer_lane == "gold"`인 카드를 찾아 주사위 카드로 치환한다.
- 후처리 순서: 카탈로그 offer-plan → Dowsing 보너스 카드 →
  퍽 융합 replaceable 치환 → **신비의 주사위 골드 lane 치환 (마지막)**.
  융합과 주사위는 서로 다른 lane을 건드리므로 **공존 가능·상호 독립**
  (v1 결정 D3). 주사위는 절대 replaceable/protected 퍽 lane을 밀어내지
  않고, 융합은 절대 gold lane을 밀어내지 않는다 — 기존 계약 유지.
- 치환된 주사위 카드 메타: `id="mystic_dice"`, `is_mystic_dice=true`,
  `offer_lane="mystic_dice"`, `offer_protected=true`. 골드 카드처럼
  마지막 위치·protected 성질을 그대로 계승한다.

### 3.2. source allowlist (융합 §6.1과 동일 틀)

| `current_choice_context.source` | 주사위 등장 | 비고 |
|---|---|---|
| `battle_starpoint` | O | 인배틀 스타포인트/연속 레벨업 |
| `result_box_starpoint_choice` | O | 결과상자 귀속. 모달 연장 중 raw `choice_active` 유지로 상자 입력 차단 |
| `plaza_academy` | **X** | 아카데미는 항상 골드변환 유지. `plaza_academy_transactions.gd:112`의 gold 필터 불변 |
| dedicated mythic / fixed / tutorial / debug / unknown | **X** | fail closed. unknown/빈 source는 골드 유지 |

### 3.3. 등장 확률 + 사용 캡

- 등장 롤: source 허용 + 사용 캡 잔여 시 **기회당 1회**,
  `MYSTIC_DICE_APPEARANCE_CHANCE := 0.5` (시작값, §12 밸런스 패스 대상).
  실패 시 골드변환 그대로.
- **사용 캡: 런당 3회** (`MYSTIC_DICE_MAX_USES_PER_RUN := 3`).
  캡 소진 시 등장 롤 자체를 하지 않고 항상 골드변환. 캡 카운트는
  **확정 커밋 시점**에만 증가한다 (등장·굴림·리롤은 소모 아님).
- 등장했지만 플레이어가 다른 퍽을 고른 경우: 아무것도 소모되지 않는다.

---

## 4. 모달 플로우 상태 전이표

전체 플로우는 융합 §6과 동일하게 **기존 퍽 선택 모달 세션 내부**에서
처리한다. **새 공 정지 액터 금지.** `runtime_perk_state.choice_active`
raw 필드를 D0 진입부터 D3 확정 완료까지 계속 true로 유지하고, 별도
active flag를 modal-gate facade에 OR하지 않는다. phase는 신규
`mystic_dice_modal_flow.gd`의 `ui_phase`로 표현한다.

| 상태 | 화면 | 진입 | 이탈 |
|---|---|---|---|
| D0 | 퍽 선택지 (주사위 카드 포함) | 기존 퍽 모달 오픈 | 주사위 카드 선택 → D1 / 다른 카드 → 기존 플로우 |
| D1 | 주사위 굴림 연출 (~2초, 낙하 바운스 + 눈금 셔플 + 스탯 ??? 셔플) | D0 카드 선택 (즉시 굴림 시작) | 연출 종료 → D2 |
| D2 | 결과 표시 + [다시 굴리기]/[확정] 대기 (호버 애니메이션) | D1 | 다시 굴리기(잔여>0) → D1 재진입 / 확정 → D3 |
| D3 | 커밋 + finish (피드백 텍스트, 모달 종료 또는 다음 pending choice) | D2 확정 | 종료 |

계약 (융합 S2/S4 분리 계약의 축약 대응):

- **D0 주사위 카드 선택은 일반 `apply_choice()` /
  `_choice_confirm_flow`로 보내지 않는다.** 가로채기 지점은
  `runtime_perk_state.gd:417 choose_selected()` — 융합 분기
  (`:418-424`)의 형제 분기로 `is_mystic_dice` 검사 후
  `_begin_mystic_dice_modal()`을 연다. 마우스 클릭 경로도 같은
  choose_selected로 수렴하는지 확인하고, 다른 진입점(카드 클릭
  핸들러)이 있으면 거기에도 같은 분기를 건다.
- **D1/D2에는 취소가 없다** (D2 결정: 원본 계약 계승 — 카드 클릭 =
  커밋 의사, 리롤 2회가 플레이어 통제권. 골드변환도 클릭 즉시
  적용되는 동급 카드라는 일관성 근거). D2에서 [확정]만이 출구다.
  ESC/취소 입력은 소비만 하고 no-op.
- **D3 커밋은 원자 1회**: 롤 결과 raw를 `mystic_dice_state` 누적에
  가산 + `use_count += 1` + revision 증가를 한 트랜잭션으로. 그 후
  **idempotent finish**가 정확히 한 번: pending choice 1개 소비,
  `selected_choice_sequence`/`last_selected_choice(type:"mystic_dice")`
  갱신, 메긴교르드 extra-pick 1회 판정, pending 잔여 시 다음 choice
  오픈 / 없으면 `choice_active=false` + 쿨다운 재개·스타포인트 흡수·
  복귀 램프를 기존 close plan으로 1회 실행. 재입력/중복 callback은
  `dice_finish_consumed` 가드로 no-op. (융합 S4 finish와 동일 계약 —
  가능하면 융합 finish 헬퍼를 공용화해 재사용.)
- 복귀 안전 램프(상승 즉시 해제 규칙,
  `runtime_perk_resume_safety_release_smoke` 봉인)는 **플로우 전체가
  끝난 뒤 1회만** 발화. 연속 레벨업 큐가 남아 있으면 마지막 선택
  뒤에만 arm (기존 규칙 유지).
- **연쇄 모달 입력가드** (런타임 퍽 모듈화 Blocker#1 패턴)를
  D0→D1, D2→D1(리롤), D2→D3 전 전환에 적용. 게임패드 RT confirm은
  융합 `perk_fusion_modal_input.gd`의 `suppress_confirm_until_release`
  래치 패턴을 재사용한다 (`ⓘ 링펫 교감 RT 폴링마스크 선례와 동일 축`).
- 입력/업데이트 라우팅 앵커: `runtime_perk_state.gd:330` (update),
  `:350` (input) 융합 분기의 형제로 dice 분기 추가.

---

## 5. 스탯 배선 표 (7종)

조사 완료된 현행 앵커 (2026-07-10 기준). 공용 산식 허브는
`runtime_perk_effective_stat_query_surface.gd`(이하 `surface`),
진입 파사드는 `runtime_perk_state.gd`(이하 `RPS`).

주입 원칙: **각 surface 산식에 `× (1.0 + dice_raw(key)/100.0)` 항을
하나 추가**하는 최소 침습. 하류 소비/배선은 이미 완비. dice_raw 조회는
`RPS.mystic_dice_state`(§6)를 runtime_state 경유로 읽는다 (융합
페널티가 surface에서 fusion 상태를 읽는 기존 패턴과 동일).

| # | 스탯 키 | 방향 | 주입 앵커 | 기존 선례 |
|---|---|---|---|---|
| 1 | `player_speed` | 일반 | `surface:368 get_player_speed_multiplier` (= 1.0 + bonus("common_swiftness") + …) 에 dice 항 곱 | `common_swiftness` 퍽. 소비: `battle_scene_player_control_config_builder.gd:112` |
| 2 | `paddle_size` | 일반 | `surface:375 get_player_paddle_size_multiplier` 에 dice 항 곱 (max(0.1,…) 클램프 안쪽) | `common_bulk_up` 퍽. 착지: `runtime_perk_owner_effect_sync.gd:45-46` → `runtime_paddle_scale` |
| 3 | `skill_gauge` | 일반 | **신규 헬퍼 필요** — RPS에 일반 퍽용 게이지 최대 배율 헬퍼가 없음(angel 전용만 존재). `mythic_item_owner_syncer.gd:497-529 sync_fuel_pouch_gauge_max`의 base 산정에 곱하는 게 1차 후보 | mythic `mythic_item_resource_bonus_runtime.gd:25`. ⚠ §5.1 검증 필수 |
| 4 | `dash_distance` | 일반 | **신규 레버 필요** — D1 결정: **대쉬 속도 배율** 채택. `smasher_dash_state.gd:109` motion_state.start에 배율 인자 전달 → `smasher_dash_active_motion_resolver.gd:44 _get_current_speed`에서 `DASH_BASE_SPEED × dice배율` | 거리=속도×지속. 지속프레임(`dash_jump`) 경로 재사용 대안은 "느리게 오래" 체감이라 기각 |
| 5 | `dash_recovery` | **LIB** | `surface:286 get_dash_recovery_frames` (= max(MIN, base×(1.0 - bonus("dash_module_control")))) 에 dice 항 곱, MIN 클램프 안쪽 | `dash_module_control` 퍽 |
| 6 | `dash_cooldown` | **LIB** | `surface:275 get_dash_recharge_frames` 에 dice 항 곱, MIN 클램프 안쪽 | `dash_lightweight` 퍽 (⚠ dash_boost는 액티브 아이템, 쿨감 퍽 아님) |
| 7 | `item_cooldown` | **LIB** | `surface:308 get_active_item_cooldown_msec` 에 dice 항 곱 | `item_cooldown_mastery` 퍽. 소비: `active_item_slot_controller.gd:535` + HUD `active_item_hud_state.gd:110-114` |

### 5.1. 스탯별 주의사항 (배선 전 필독)

- **#3 게이지 최대 — 게이팅 검증 필수.** `sync_fuel_pouch_gauge_max`가
  fuel pouch 미보유 시에도 무조건 매 프레임 도는지 먼저 추적하라.
  mythic 아이템 게이트 안쪽에서만 돈다면, 미보유 플레이어는
  `owner.set("special_gauge_max", …)`가 영영 안 불려 dice 배율이
  조용히 죽는다 (two-update-path 트랩 클래스). 그 경우 주입점은
  `special_gauge_max` owner 키(기본 500, `battle_scene_state.gd`
  DEFAULT_VALUES :147)의 **실제 소비/기본값 산정 지점**으로 옮기거나,
  syncer를 무조건 실행으로 확장한다. 어느 쪽이든 "mythic 미보유 +
  dice만 보유" 픽스처가 스모크에 반드시 들어간다.
- **#4/#5/#6 대쉬 — 5캐릭 공용 검증.** 대쉬 시스템은
  `smasher_dash_state.gd`에 살지만 5캐릭터 공용 위임이다
  (뿔딸기 대쉬 수정 선례). 스모크에 비-스매셔 캐릭터 레그 1개 포함.
- **#5/#6 클램프 순서.** dice 항은 기존 `max(MIN, …)` 클램프
  **안쪽**에 곱한다 — 클램프 바깥이면 MIN 미만으로 뚫린다.
- **#7 HUD 동기.** 아이템 쿨타임 표시(`active_item_hud_state.gd`)가
  같은 RPS 헬퍼를 읽는지 확인 — 게임플레이만 줄고 HUD가 raw를 읽으면
  [`item_runtime_checklist.md` §2.4](item_runtime_checklist.md#24-roll-options)의
  final-effective-cooldown 계약 위반.
- 산식에 dice 항을 넣을 때 **surface 함수의 기존 각 항(퍽 보너스·
  angel·fusion)과 곱셈 결합**한다. 덧셈 결합 금지 (배율 체계 일관성).
- **⚠ 음수 롤 바닥 함정 (실측 확인).** `get_player_speed_multiplier`는
  퍽 보너스를 `1.0 + maxf(0.0, bonus)`로 바닥 처리한다. dice raw를
  이 **maxf 안쪽 bonus에 덧셈으로** 넣으면 음수 롤이 0으로 잘려
  "손해가 안 나오는" 조용한 버그가 된다. dice 항은 반드시 그 표현식
  전체에 **별도 곱**으로: `(1.0 + maxf(0.0, bonus)) × dice_mult`.
  recharge/recovery/item-cooldown의 `maxf(0.0, 1.0 - bonus)`도 동형 —
  전부 별도 곱 항으로 결합하고, 스모크의 음수-롤 레그가 이 형태를
  봉인한다.

---

## 6. 상태 모델 / 리셋 경계

- 신규 `mystic_dice_state.gd` (RefCounted), `RPS`에
  `var mystic_dice_state` 로 보유 (융합 `perk_fusion_state` :121 형제).
  보유 데이터: `permanent_raw: Dictionary` (7키 → int, **raw 부호**로
  저장 — 원본 `permanent_bonuses` 의미론), `use_count: int`,
  `revision: int`. 조회 헬퍼:
  `get_multiplier(stat_key) -> float` (= 1.0 + clamp(raw)/100.0),
  `get_raw(stat_key) -> int`.
- 모달 상태는 별도 `mystic_dice_modal_flow.gd` (융합
  `perk_fusion_modal_flow.gd` 형제: phase 상수 + snapshot + 입력 액션).
- **리셋 경계 = 퍽 융합 record와 동일**: round/stage를 넘어 살아남고,
  new-run/전체 리셋에서 초기화. 앵커:
  `runtime_perk_reset_state.gd reset_from_runtime_state()`에
  `_reset_mystic_dice(runtime_state)` + `_reset_mystic_dice_modal(...)`
  형제 추가 (:17 융합 리셋 나란히). 원본의 세이브 저장은 v1 미계승
  (런 상태 모델 — 융합과 동일하게 atomic run-save 이전에는 프로세스
  강제종료 복구 비보장).
- 스냅샷: `runtime_perk_snapshot_builder.gd`에 dice 상태
  (modal snapshot + 누적 raw + use_count + 잔여 캡) 노출 — 렌더러와
  스모크가 이것만 읽는다.
- **표시 투영**: 누적이 1회 이상이면(use_count > 0) 융합 display
  projection 패턴을 따라 HUD 퍽 스트립 / TAB 캐릭터 정보 퍽 그리드에
  주사위 아이콘 엔트리 1개를 노출하고, 툴팁에 7스탯 누적표
  (raw % + LIB 색 반전)를 렌더한다. ⚠ TAB 스탯 패널에 **행 추가
  금지** — Stats-Panel Row Budget Trap. 퍽 그리드 엔트리 + 툴팁으로만.
  툴팁 7행은 고정 컨텐츠라 shared-line-budget 문제 없음(전용 툴팁),
  단 비한국어 locale 줄바꿈 확인.

---

## 7. UI / 렌더 / 자산

### 7.1. 주사위 연출 (D1/D2)

원본 `devil_dice.py`의 절차 드로잉을 Godot 절차 드로잉으로 포팅한다
(원본이 절차 드로잉이므로 imagegen 대체 대상 아님 — Direct Draw
라우팅 규칙의 "포팅" 케이스). 신규 `mystic_dice_overlay_renderer.gd`,
호출부는 `runtime_perk_overlay_renderer.gd` (융합 렌더러 preload :7 /
prewarm :83 / draw :153 형제).

- 구성: 반투명 전체 오버레이 → 중앙 주사위 (라운드 사각 + 눈금 pip,
  낙하 바운스 `dice_offset_y` + 스핀) → 결과 패널 (7행: 스탯명 / 롤값
  / 누적값) → D2에서 [다시 굴리기][확정] 버튼 + 남은 굴리기 표시.
  원본 `draw_dice_results` 레이아웃 참고, 좌표는 Godot 뷰포트 기준
  재산정 (레거시 760x750 상수 이식 금지 — 풀 캔버스 규칙).
- **리스킨 팔레트**: 원본 (70,0,0)/(220,40,40) 붉은 악마 →
  심청보라 바디 + 아케인 시안/보라 글로우 + 별빛 하이라이트.
  결과 색 규칙은 계승: 이득=초록, 손해=적, 0=회색, LIB 색 반전.
- **비주얼 프리미엄화 (2026-07-12, Claude)**: 초기 8점 폴리곤이
  회전 시 찌그러져 "허접"하다는 피드백 → 다시 짬. 안정 슈퍼타원
  (n=4, 32점) 라운드 스퀘어 + `draw_polygon` 정점-색 세로 그라디언트
  (위 밝은 보라→아래 심청, 볼륨) + 금색 베벨 폐기→시안 베벨/좌상 림라이트
  + 결정적 구름 트레일 + 트윙클 코너 스파클. draw 경로에 randf/Time 미사용
  (스모크 제약). 캡처 픽셀QA(760/300) 통과.
- **면 = 링펫어(링펫전용언어) 룬 (2026-07-12, 사용자 결정)**: 눈금(pip)은
  실제 결과(7스탯 조정)와 무관해 무의미 → 1~6 눈금 폐기, 6면에 **실제
  링펫어 Display 폰트 글리프**를 새김(해석기/펜들럼과 동일 언어 = 일관성).
  폰트 = `res://assets/fonts/LingpetScriptDisplay-Regular.ttf`(장식형, 로어용;
  본문/해석기는 기하 Regular). `preload` const(파스타임, 핫패스 로드 회피).
  `FACE_GLYPHS = ["c","o","g","m","t","z"]`(볼드·개방형 룬 6종, 다운스케일
  생존; 밀집 격자 i/k/y는 최소 해상도 muddy라 회피). 글리프는 upright 렌더
  (draw_string 회전 불가, 결과 phase 회전≈0이라 무해). 각인 언더레이+시안
  블룸+별빛 3패스. face 값은 여전히 데코(굴림 랜덤/확정 raw_sum%6). ⚠소스
  grep 봉인이 주석의 `draw_set_transform` 문자열도 오탐하므로 draw 파일에서
  그 리터럴 언급 금지(P2-2 취약성 실사례).
- 회전: 기획 당시 명세는 `draw_set_transform` 1회+복원이었으나,
  **실구현(2026-07-10 확정)은 `draw_set_transform` 자체를 쓰지 않는
  수동 회전 정점 계산 + D2 호버 시계 `fmod` 랩(`HOVER_TIME_WRAP`)** —
  트랩 #10(transform 복원)과 장시간 방치 텀블/정밀도 문제를 원천
  회피한 더 안전한 변형으로 리뷰 승인됨. 렌더러 스모크가
  `draw_set_transform` 부재를 봉인. D2 10초+ 방치 픽셀 QA는 유지.
- 핫패스 금지 규칙: draw 안 텍스처/폰트 lazy-init 금지. 프리웜은
  기존 렌더러 prewarm 훅에 편승.
- 확정 후 패들 신비 파티클 3초(원본 draw_paddle_effect 대응)는
  **후순위 슬라이스 S4** — 없어도 기능 완결.

### 7.2. 카드 아이콘

- 카드/퍽 그리드 아이콘: `res://assets/sprites/perks/mystic_dice_perk_icon.png`
  를 `runtime_perk_icon_renderer.gd:29` 형제 행으로 등록 (PNG-first).
  **자산 생성도 Codex imagegen 소관** (2026-07-10 사용자 확정 — 지금까지
  퍽 아이콘을 Codex imagegen으로 작업해온 관례 유지). 기존 퍽 아이콘군
  (convert_to_gold, instant_* 등)과 같은 스타일 계열로 생성: 청보라
  신비 주사위 모티프 + 아케인 글로우. 수용 전 알파 QA(투명 코너·비접변
  bbox·다크/라이트 프리뷰 프린지)와 최소 실그리드(Lv 라벨 비가림) 판독은
  기존 퍽 아이콘 QA 규칙 그대로. PNG 부재 동안의 절차 폴백:
  `runtime_perk_overlay_renderer.gd:1785`의 convert_to_gold "G" 원판
  분기 형제로, 청보라 원판 + 주사위 pip 5 문양 절차 드로잉.
- ⚠ 예약-부재 자산 per-frame re-stat 트랩: PNG 경로를 등록만 하고
  파일을 안 만들면 매 프레임 파일시스템 stat이 돈다. **아이콘 PNG
  랜딩과 경로 등록을 같은 슬라이스에서** 하거나, 랜딩 전에는 절차
  폴백 분기만 두고 경로 등록을 보류한다.

---

## 8. 다국어

`문구 수정=다국어 동기화` 표준 — 7개 locale (KO 기본 + EN/ZH/JA/ES/
PT_BR/RU) 전부 같은 슬라이스에서. 카드 name/summary는
`language_settings_data.gd`의 `PERK_NAME_*` / `PERK_SUMMARY_*` 맵에
`"mystic_dice"` 행 추가 (convert_to_gold 행 형제). 모달 전용 문구는
융합 `perk_fusion_localization.gd` 형제인 `mystic_dice_localization.gd`
(EN fallback 포함)로.

### 8.1. 카드 문구

| locale | name | summary |
|---|---|---|
| KO (카탈로그 기본) | 신비의 주사위 | 퍽을 포기하고 주사위를 굴려 7가지 능력치를 영구히 조정합니다. 다시 굴리기 2회. |
| EN | Mystic Dice | Skip the perk and roll the dice: permanently shifts 7 stats. Up to 2 rerolls. |
| ZH | 神秘骰子 | 跳过升级并掷骰子：7项能力值获得永久变化。最多重掷2次。 |
| JA | 神秘のダイス | パークをスキップしてダイスを振る：7つの能力値が永久に変化。振り直しは2回まで。 |
| ES | Dado Místico | Omite el perk y lanza el dado: 7 estadísticas cambian permanentemente. Hasta 2 relanzamientos. |
| PT_BR | Dado Místico | Pule o perk e role o dado: 7 atributos mudam permanentemente. Até 2 rerrolagens. |
| RU | Таинственный кубик | Пропустите перк и бросьте кубик: 7 характеристик изменятся навсегда. До 2 перебросов. |

detail(KO): "행운이 살짝 미소 짓는 주사위입니다. 유리한 변화가 조금 더
자주 나오지만, 손해도 감수해야 합니다." — 정확 범위(-5~+10)는 LIB 미러
때문에 표기가 혼란스러우므로 카드 문구에는 싣지 않는다 (D4 결정).

### 8.2. 스탯 표시명 (모달 결과 패널 + 툴팁)

기존 로컬라이즈된 스탯 라벨이 이미 있으면 그쪽 우선 (grep 선행 —
`grep 부정증거 감사 금지` 규칙대로 절단 없이). 부재 시 아래 표.

| 키 | KO | EN | ZH | JA | ES | PT_BR | RU |
|---|---|---|---|---|---|---|---|
| player_speed | 이동속도 | Move Speed | 移动速度 | 移動速度 | Vel. de movimiento | Vel. de movimento | Скорость |
| paddle_size | 몸집 크기 | Body Size | 体型大小 | 体の大きさ | Tamaño corporal | Tamanho do corpo | Размер тела |
| skill_gauge | 최대 게이지 | Max Gauge | 最大能量 | 最大ゲージ | Energía máx. | Energia máx. | Макс. энергия |
| dash_distance | 대쉬 거리 | Dash Distance | 冲刺距离 | ダッシュ距離 | Distancia de dash | Distância do dash | Дальность рывка |
| dash_recovery | 대쉬 후딜 | Dash Recovery | 冲刺后摇 | ダッシュ後隙 | Recuper. de dash | Recuper. do dash | Восстан. рывка |
| dash_cooldown | 대쉬 쿨타임 | Dash Cooldown | 冲刺冷却 | ダッシュCT | Enfriam. de dash | Recarga do dash | КД рывка |
| item_cooldown | 아이템 쿨타임 | Item Cooldown | 道具冷却 | アイテムCT | Enfriam. de objetos | Recarga de itens | КД предметов |

모달 버튼/라벨: 다시 굴리기 / 확정 / 남은 굴리기: N회 — 7 locale 동일
슬라이스. (EN: Reroll / Confirm / Rerolls left: N, 이하 대응 번역.)

---

## 9. 슬라이스 분할 + 스모크 계획

| 슬라이스 | 내용 | 봉인 스모크 |
|---|---|---|
| S1 백본 | `mystic_dice_state` + 롤러(벤핏 공간, polarity 미러, 클램프) + 리셋 배선 + 스냅샷 | `mystic_dice_state_smoke`: 롤 범위(일반 [-5,10]/LIB [-10,5]) · 누적 가산 · 클램프 · new-run 리셋 · **반증: polarity 미러 제거 시 RED** |
| S2 로테이션 | offer 플래너 + source allowlist + 사용 캡 + 카드 메타/문구 | `mystic_dice_offer_rotation_smoke`: allowlist 4분기 · 캡 소진→항상 골드 · 등장롤 1회성 · 골드/융합 lane 불간섭 · 아카데미 불변 · **반증: allowlist 제거 시 RED** |
| S3 모달+커밋 | choose_selected 가로채기 + modal_flow(D0~D3) + 입력(RT 래치) + 커밋/finish + 스탯 7종 surface 주입 | `mystic_dice_modal_commit_smoke`: D0 클릭이 apply_choice 미경유 · 리롤 폐기/카운트 · 확정 1회 커밋(중복 no-op) · choice_active 전구간 true · 램프 1회 · pending 큐 지속 // `mystic_dice_stat_apply_smoke`: 7스탯 **OUTCOME 단언**(예: raw -10 → recharge_frames == base×0.9) · 비-스매셔 대쉬 레그 · mythic 미보유 게이지 레그 · HUD 쿨다운 표시 동기 · **반증: LIB 항 방향 뒤집기 시 RED** |
| S4 폴리시 | 렌더 연출 리스킨 + 아이콘 PNG(Codex imagegen, §7.2) + 표시 투영(HUD/TAB 툴팁) + 패들 파티클 | 픽셀 QA (창모드 실렌더): D2 10초+ 방치 · 최소 해상도 툴팁 줄바꿈 · LIB 색 반전 육안 |

- 스모크 반증검증은 **in-place Edit 토글/임시 패치만** — `git reset`/
  `checkout`/`stash` 절대 금지 (repo 표준).
- 기존 스모크 회귀 확인: `dowsing_goggles_port_smoke`(골드 카드 마지막
  단언 — 카탈로그 불변이므로 GREEN 유지되어야 함),
  `gold_digger_port_smoke`, `runtime_perk_choice_apply_flow_smoke`,
  `perk_fusion_offer_planner_smoke`,
  `runtime_perk_resume_safety_release_smoke`.
- S1→S2→S3 순서 고정 (S3가 S1 상태 + S2 카드를 소비). S4는 병행 가능.

---

## 10. 트랩 체크리스트 (구현 시 필독)

1. **polarity 미러** (§2.1) — LIB 3종 롤 범위 [-10,+5]. 최중요.
2. **raw `choice_active` 유지** — 새 freeze actor / modal-gate OR 금지
   (융합 §6 계약 그대로).
3. **연쇄 모달 입력가드** — 전 phase 전환 + RT confirm 래치.
4. **복귀 램프 1회 + 상승 즉시 해제** — finish에서만 arm, 기존 씰 존중.
5. **per-frame 확률 롤 금지** — 등장 롤/굴림 모두 이벤트 시점 1회,
   롤 유닛 주입형 순수 플래너.
6. **owner-field schema** — 신규 `owner.set` 키를 만들면
   `BattleSceneState.DEFAULT_VALUES`(battle_scene_state.gd:3) 선언 +
   divergent(보정≠기본) 케이스 스모크. §5 주입안은 owner 키 신설을
   피하는 설계지만, #3 게이지 대안 경로가 신설하게 되면 적용.
7. **클램프 안쪽 곱** (§5.1) — MIN 프레임/0.1 스케일 하한 관통 금지.
8. **two-update-path** — #3 게이지 syncer 게이팅 검증 (§5.1).
9. **예약-부재 자산 re-stat** — 아이콘 PNG 랜딩 전 경로 등록 금지 (§7.2).
10. **draw_set_transform 복원 / 텀블 10초+ QA** (§7.1).
11. **Stats-Panel Row Budget** — TAB 스탯 행 추가 금지, 퍽 그리드
    엔트리+전용 툴팁만 (§6).
12. **다국어 동시 랜딩** — name/summary/스탯명/버튼 7 locale 같은
    슬라이스 (§8).
13. **모달 중 wall-clock 앵커 감사** — 주사위가 퍽 모달 체류 시간을
    늘린다. 액티브 아이템 쿨다운(msec)·기타 wall-clock 앵커가 모달
    중 진행되는지 1회 감사 (융합 S3 연출로 이미 늘어난 축이라 신규
    누수가 발견되면 융합과 공용 수정 + 트랩 백필).
14. **로테이션이 카탈로그 밖** — `get_choices()` 내부 치환 금지 (§3.1).

---

## 11. `convert_to_gold` 컨슈머 감사 목록 (alias 감사)

id 특별분기 전수 목록. 주사위는 골드 카드를 "대체 등장"만 하므로
대부분 무변경-확인이지만, 배선 후 전 행을 실제로 감사한다.

| 위치 | 내용 | 조치 |
|---|---|---|
| `plaza_academy_transactions.gd:112` | 아카데미 gold 필터 | 무변경 (source 게이트로 주사위 미등장) — 확인만 |
| `runtime_perk_icon_renderer.gd:29` | gold PNG 등록 | `mystic_dice` 행 추가 (§7.2 타이밍 규칙) |
| `runtime_perk_overlay_renderer.gd:1785` | gold 절차 아이콘 분기 | dice 절차 폴백 형제 분기 추가 |
| `runtime_perk_overlay_renderer.gd:1911,1928` | `_level_text` / `_long_level_text` — gold는 "골드"/"(500골드)" 뱃지 | `is_mystic_dice` 분기 추가 (예: "주사위" / "(운명 조정)"). 뱃지 로컬라이즈 정책은 gold 뱃지의 현행 관례를 그대로 따름 |
| `runtime_perk_catalog.gd:1419-1422` | id→choice data 리졸브 | `mystic_dice` 리졸브 분기 추가 (툴팁/그리드 소비) |
| `runtime_perk_catalog.gd:1438` | `is_slot_consuming_perk()` — gold는 false(슬롯 미소모) | dice도 **false 반환** 필수 — `is_mystic_dice` 검사 추가. 누락 시 슬롯 예산 로직이 주사위를 슬롯 소모 퍽으로 오판 |
| `runtime_perk_catalog.gd:1518` | 디버그 풀 목록 빌드 (gold를 debug_group "instant"로 append) | dice 항목도 표시용 append. 직접 그랜트 제외는 `runtime_perk_debug_grants.gd:83`에서 (모달 플로우 없이 그랜트 불가) |
| `runtime_perk_choice_dispatch.gd:4` | gold 액션 디스패치 | dice는 디스패치 미경유 (choose_selected 가로채기) — 확인만 |
| `runtime_perk_debug_grants.gd:83` | 디버그 그랜트 제외 | `mystic_dice` 제외 추가 |
| `language_settings_data.gd` PERK_NAME/SUMMARY ×7 | 다국어 맵 | `mystic_dice` 행 추가 (§8.1) |
| 테스트: `dowsing_goggles_port_smoke.gd:90`, `gold_digger_port_smoke.gd:106` | 골드 카드 위치/지급 단언 | 카탈로그 불변이므로 GREEN 유지 — 회귀 확인만 |

---

## 12. 밸런스 시작값 + 미결

전부 시작값이며 라이브 QA 후 §12만 갱신한다.

| 항목 | 시작값 | 비고 |
|---|---|---|
| 롤 범위 (벤핏) | **정수 [-3, +3]** (2026-07-12 재조정) | 대칭. 명목 EV 0, 리롤로 실현치 소폭 + |
| 등장 확률 | 50% | 골드 이코노미 체감 보며 조정 |
| 사용 캡 | 3회/런 | **스탯당 런 누적 ±9% 상한** |
| 리롤 | 첫 굴림 + 2회 | 원본 계승 |
| raw 절대 클램프 | **±9** (자연 최대치와 동일) | 방어적 상수 |
| 융합 카드와 공존 | 허용 (독립) | 체감상 과밀하면 상호배제 규칙 검토 |

확정된 결정 (재논의 금지):
- D1: 대쉬거리 = 대쉬 속도 배율 방식 (§5 #4).
- D2: D1/D2 취소 없음 — 원본 계승 (§4).
- D3: 융합 카드와 공존 허용 (§3.1).
- D4: 카드 문구에 정확 % 범위 미표기 (§8.1).
- **D5 (2026-07-12): 굴림당 ±3, 런 캡 ±9.** 신속·벌크업(+30%) 정체성
  보존 위해 -5~+10/±30에서 하향. 근거 §2.4.

미결 (배선과 무관, 후속):
- 세이브 저장(런 저장 시스템 도입 시 dice 상태 포함 여부).
- 개별 스탯 잠금 리롤 (v2 여지).
- 확정 순간 사운드/히트스톱 폴리시 (S4에서 기존 SFX 자산 재사용 검토).

---

## 12.1. 배선 후 적대 리뷰 결과 (2026-07-10, Claude)

S1~S4 배선 + 아이콘까지 구현 완료(58파일, 미커밋). 리뷰 판정:
**런타임 정합성 P0/P1 결함 없음** — polarity 미러, maxf 바닥, 클램프
안쪽 곱, choice_active 유지, idempotent finish, source fail-closed,
게이지 syncer 무조건 실행, 리셋 3종, §11 컨슈머 표 전 행 이행 확인.
wall-clock 일시정지 팬아웃도 부호/이중시프트/재진입/0ms 경계 전부
건전하며, 트리거는 주사위 전용이 아니라 **모든 퍽 초이스 모달 +
스킬오브 툴팁 + 캐릭터정보 오버레이**로 걸린다 (기존 모달 누수까지
함께 봉인된 셈 — 트랩 #13의 "공용 수정" 분기 실현).

봉인 갭 (후속 처리 대상):
- **P1 — 해소 (2026-07-10)**: 오퍼 로테이션 스모크에
  `open_next_choice()` 실경로 레그를 추가했다. 실제 카탈로그와 허용
  source를 사용하고, 실 플래너에 위임하는 테스트 더블로 등장 roll만
  `0.0` 주입해 주사위 등장 / 골드 lane 교체 / 후처리 1회 호출을
  단언한다. 프로듀서의 `_try_inject_mystic_dice_offer()` 호출 제거 시
  RED, 복원 후 GREEN을 확인했다.
- P2: ①이속/패들 스모크가 surface 반환까지만(실 소비지점 미도달),
  ②소스텍스트 grep 단언 다수(리팩터 취약), ③모달 중 wall-clock
  정지 자체를 단언하는 레그 부재, ④ghost_shot 블랙홀 FX start_msec
  미시프트(리줌 시 팝, 시각 전용), ⑤포탈 due-at-pause 캐치업 1회
  의심(저신뢰), ⑥viper core-flip 앵커 누수 시 동결(라운드 리셋이
  회수, 저위험).

## 13. 배선 완료 후 후속 의무

- `docs/character_skill_perk_checklist.md`에 "퍽 선택 대안 lane
  로테이션(골드변환/신비의 주사위)" 코드 위치 포인터 1줄 백필.
- 라이브 QA: 실전 런에서 등장→리롤→확정→스탯 체감 + TAB 툴팁 +
  결과상자 source에서 1회.
- 커밋은 이 작업 스코프만 헝크 분리 (엉킨 WIP 다수 — `--only <경로>`
  커밋 표준).

---

## 14. ±3 재조정 배선 스펙 (2026-07-12, Codex 레인)

D5(§12) 반영. **소스 상수 + 스모크 기대값을 원자적으로 함께 착지**해야
한다 (상수만 바꾸고 스모크를 놔두면 6개 스모크가 RED). 이 재계산은
정합성 배치라 Codex가 소유한다.

### 14.1. 소스 (2곳)

| 파일 | 변경 |
|---|---|
| `mystic_dice_roller.gd` | `BENEFIT_MIN := -3`, `BENEFIT_MAX := 3` (BUCKET_COUNT 자동 7). polarity 미러 코드(`raw_from_benefit`)·allowed_range 로직은 불변 — 범위만 좁아짐 |
| `mystic_dice_state.gd` | `RAW_ABS_CAP := 9` (30→9). clampi 로직 불변 |

그 외 소비 경로(surface 7주입, syncer, 대쉬)는 배율을 곱만 하므로 **무변경**.

### 14.2. 스모크 기대값 재계산 (6파일)

`_expect_close`는 실패 시 실제 계산값을 출력하므로, 러너 "got Y"로 안전
재핀 가능. 부호·색상 의미는 반드시 보존.

- **`mystic_dice_state_smoke.gd`**: 폴리티 min/max −5/+10 → **−3/+3**,
  미러 raw ±5/±10 → **±3**; 캡 테스트 3-best 누적 +30/−30 → **+9/−9**,
  mult 1.30/0.70 → **1.09/0.91**; 3-worst −15/+15 → **−9/+9**, mult
  0.85/1.15 → **0.91/1.09**; runtime reset raw 10/−10 → **3/−3** (전
  `== 10` / `== -10` 인스턴스).
- **`mystic_dice_stat_apply_smoke.gd`**: 픽스처 raw −5/10/−10 → **±3**
  (`_state_with_raw`가 commit 검증하므로 범위 초과 시 reject). 하류
  기대값 러너로 재핀: speed 0.95→**0.97**, paddle 1.10→**1.03**,
  recovery 42→37.8/**40.74**·recharge 300→270/**291.0**, item cooldown
  9000→**9700**, gauge 550/594/772.2·ratio·dash px 231/216.3 등 전부
  ±3 기준으로. 클램프 레그(1.0/6.0)는 min 상수 상호작용이라 러너 확인.
- **`mystic_dice_modal_commit_smoke.gd`**: 리롤/커밋 raw `== 10`/`== -10`
  → **3/−3** (best 굴림이 +3/−3).
- **`mystic_dice_display_projection_smoke.gd`**: `_raw_fixture()`를 ±3
  **부호 보존** 값으로(색상 테스트 유지: 일반 −(적)/+(초), LIB 미러
  −raw(초)/+raw(적)). 표시 문자열 `-5%`/`+10%`/`-10%`/`+5%`/`-4%` 및
  alias 방지 기대(60행 `-5`) 대응 갱신.
- **`mystic_dice_overlay_renderer_smoke.gd`**: `_verify_result_projection`
  raw 픽스처(player_speed 10, permanent_raw 25 등) → ±3/±9 범위. 헤더
  라벨 봉인(129~132)·polarity 부호 단언은 불변.
- **`mystic_dice_offer_rotation_smoke.gd`**: best_raw commit로 캡 소진만
  하므로 매그니튜드 무단언 — **무변경**(확인만).

### 14.3. 검증 + 반증

- 6개 주사위 스모크 + `run_headless_load_check` + `run_warning_scan`(0건).
- 반증(in-place 토글, git reset 금지): polarity 미러 제거 → LIB 색/부호
  RED, 범위를 다시 ±10 → 캡·표시 RED 확인 후 복원.
- 라이브 QA는 §13 그대로 + "한 스탯 최대 +9% 체감이 신속/벌크업 대비
  확실히 보조로 읽히는지" 1회 확인.
> **2026-08-06 후속 확정 — 기존 퍽 로테이션 계약 폐기:** 신비의 주사위는 퍽
> 선택지와 퍽 디버그 목록에서 제거하고 액티브 아이템으로 이관한다. 원본
> PingFighter 악마의 주사위와 같은 희귀 필드 가중치 `0.005`를 사용한다. 아이템
> 1개를 사용할 때 7종 능력치를 각각 ±3% 굴리고 최대 2회 다시 굴릴 수 있으며,
> 확정 결과는 런 동안 누적(각 능력치 raw ±9% 상한)된다. 아이템 획득 수만큼
> 반복 사용할 수 있으므로 기존 런당 3회 제한은 폐기한다. 아래 문서는 과거 퍽
> 설계 이력이며 이 메모와 충돌하는 조항은 모두 무효다.
