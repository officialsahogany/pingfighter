# 천사의 주사위 신화퍽 Godot 포팅 기획서

- 작성일: 2026-07-10
- 상태: **포팅 완료 (S1~S6, 2026-07-11)**
- 구현 대상: `godot/`의 런타임 신화퍽
- 퍽 ID: `angel_blessing`
- 표시명: **천사의 주사위**
- 원본 내부명/구명칭: 천사의 가호 (`AngelBlessing`)
- 기준선 주의: 이 문서는 2026-07-10의 dirty WIP 작업트리를 조사한 결과다. 구현을 시작할 때 신화퍽 수, 오퍼 정책, 수정 중인 관련 파일을 다시 확인한다.
- 구현 진행: **Foundation 1 완료** — 비노출 전용 굴림 상태/스모크를 먼저 완성했고, S6에서 카탈로그·획득 풀을 원자적으로 공개했다.
- 구현 진행: **Foundation 2 완료** — 6종 순수 수치 projection, runtime perk query 합성, HUD용 multiplier snapshot, 단독/복합/교체 회귀 봉인 완료. 최대 게이지 owner 반영은 기존 Fuel Pouch 비율 보존과 다른 `현재 절대값 유지 + clamp` 정책이 필요하므로 S3에서 전용 compositor로 연결한다.
- 구현 진행: **Foundation 3 / S3-1 완료** — `(기본 + Fuel) × Angel` 단일 owner writer, Fuel 비율 보존과 Angel 절대값 보존의 원인별 합성, TAB 단일 표시, full reset, Optimus 유효 최대 게이지 전달을 봉인했다.
- 구현 진행: **S3-2 완료** — Optimus 매 틱 패들 snapshot을 base-only로 바꾸고 공용 최종 compositor, Junior League 1.5배, 직접 캐릭터 전환 즉시 재합성을 봉인했다.
- 구현 진행: **S3-3 완료** — Horn Strawberry의 8 속도를 replacement base로 먼저 적용한 뒤 Angel·일반퍽·날씨·상태·액티브·링펫·신화 배율을 정확히 한 번 합성한다. Optimus 게이지 비율, Smasher Recovery/휠, Commando AK, Blacksmith 방패, Viper 체공의 캐릭터 전용 후단 덮어쓰기를 변신 중 차단·취소하고, 자폭 드론의 0배 정지와 일반 상태는 보존한다. TAB도 날씨·상태를 포함한 실제 조작값과 일치한다.
- 구현 진행: **S3-4 완료** — 실제 Hammer Shock이 없는 현재 Blacksmith에서는 스킬 쿨타임 축복을 후보에서 제외한다. 명시적 live skill-id 목록, config의 getter/runtime·item setter, configured timer trigger/remaining/total 계약이 모두 있을 때만 후보가 열리며, 공용 배율 입력은 빈 compatibility config까지 미리 연결했다. Hammer Shock 본체 포팅은 후속 캐릭터 슬라이스이며, 스테이지 발동은 S3-5에서 잇는다.
- 구현 진행: **S3-5 완료** — 기존 공 생성 인트로의 잔여 오버레이 종료 callback(총 4.4초)을 단일 발동점으로 사용한다. 차원개방·게이지 완충 deferred instant를 먼저 확정한 뒤 Angel을 스테이지당 한 번 굴리고, 성공한 새 굴림에서만 owner/config/최대 게이지 소비자를 재동기화한다. 득점 후 라운드 재시작은 현재 결과를 유지하고, 다음 스테이지 인트로는 이전 결과를 원자적으로 교체하며, full reset은 활성 결과·스테이지 이력·보유 레벨을 모두 지운다.

- 구현 진행: **S4 완료** — accepted raw `0→1` 최초 획득만 전투 현재 스테이지 또는 결과 화면의 다음 유효 인트로로 예약한다. 전투 예약은 공용 신화 획득 시네마틱의 자연 종료 뒤에만 해제되고, 남은 런타임 퍽 선택을 먼저 처리한 후 Angel 전용 3초 모달을 연다. pending-only는 게임을 막지 않고 active 모달만 물리·모바일 입력을 차단하며, 첫 프레임 입력 arm과 키보드·마우스·터치·게임패드 확인을 봉인했다. S6 공개 채널 종단 테스트가 이 예약 계약을 실제 카탈로그 카드로 재검증한다.
- 구현 진행: **S5 완료** — generated static/sheet 아이콘, 760×750 clip host, shader/texture/`GPUParticles2D` 레이어, 원본 WAV 2종과 3-voice 흡수음 풀, 비차단 흡수 lifecycle, 7개 지원 언어 동적 상태 문구를 연결했다. Angel-only 전투 셸 redraw를 제거하고 모달·흡수 GPU 상태를 공용 offscreen PSO prewarmer에 편입했으며, focused smoke와 non-headless clip/최대 눈 3 툴팁 QA를 통과했다.
- 구현 진행: **S6 완료** — 13번째 카탈로그·30% 값·두 신화 획득 목록·한국어+6개 비한국어 카탈로그 문구를 동시에 공개했다. 실제 잭팟, Angel-only 확정 신화 선택, 개발자 지급이 각각 시네마틱과 올바른 current-stage/next-intro 예약까지 이어짐을 봉인했고, 동일 레벨 개발자 재지급이 신화 시네마틱만 재생하던 결함도 same-target no-op으로 수정했다. Angel 전용/공용 31개 smoke, 2,428-script warning scan, headless load, Vulkan windowed clip/acquisition QA가 모두 통과했다.

---

## 1. 결론

`angel_blessing`은 논리·수치·스테이지 lifecycle·획득 예약·presentation·공개 획득 채널까지 Godot에 포팅 완료됐다. 원본 Python에서는 디자인상 신화인 효과를 전설 패시브 아이템 인프라에 얹었지만, Godot에서는 아이템으로 복원하지 않고 **13번째 전환 신화퍽**으로 제공한다.

목표 동작은 다음과 같다.

> 천사의 주사위를 보유한 채 실제 스테이지의 공 생성 인트로가 끝나면 1~3이 균등하게 나오는 주사위를 한 번 굴린다. 눈 수만큼 서로 다른 축복을 선택하고, 선택된 축복은 해당 스테이지의 모든 라운드 동안 30% 강도로 유지된다. 다음 스테이지에서는 이전 축복을 새 결과로 교체한다.

이 포팅은 원본의 정체성·확률·타이밍을 보존하되 다음 두 결함은 의도적으로 복제하지 않는다.

1. 미사용 파일에만 남은 7종 후보를 현행 원본으로 오인하지 않는다. 실제 후보는 **6종**이다.
2. `active_cooldown`이 플레이어 스킬과 액티브 아이템에 동시에 곱해지는 원본 중복 버그를 복제하지 않는다.

---

## 2. 소스 우선순위와 6종 정정

### 2-1. 우선순위

1. 실제 실행 소스 `legendary_items.py`, `pingfighter.py`
2. 현재 Godot 런타임과 체크리스트
3. 이 문서의 명시적 Godot 재설계 결정
4. 미사용 스냅샷·과거 핸드오프

`pingfighter.py:3117-3122`는 `legendary_items.py`를 import한다. 반면 `legendary_items_new.py`는 어느 Python 파일에서도 import되지 않는다.

### 2-2. 후보 수 정정

실행 소스의 `ANGEL_BLESSING_OPTIONS`는 `legendary_items.py:123-130`에 있는 다음 6종이다.

| 원본 ID | 표시 의미 |
|---|---|
| `paddle_size` | 패들 크기 증가 |
| `gauge_max` | 최대 스킬 게이지 증가 |
| `item_cooldown` | 액티브 아이템 쿨타임 감소 |
| `active_cooldown` | 플레이어 스킬 쿨타임 감소 |
| `dash_cooldown` | 대시 토큰 재충전 시간 감소 |
| `move_speed` | 이동 속도 증가 |

`legendary_items_new.py:48-55`에만 있는 `item_spawn`, `dash_cost`를 포함한 7종 상수는 미사용 잔재다. Godot 후보·문구·테스트에 두 효과를 넣지 않는다.

### 2-3. 이름과 등급

- 내부 ID와 클래스명은 `angel_blessing`, `AngelBlessing`이다.
- 실제 표시명은 `legendary_items.py:4300-4306`의 **천사의 주사위**다.
- “천사의 가호”는 클래스 주석과 과거 UI에 남은 개념명이다.
- Python에서는 `LegendaryItem`을 상속하지만 설명과 획득 가중치는 신화로 취급한다. Godot의 목표 분류는 아이템이 아닌 `tree/rarity = mythic` 런타임 퍽이다.

---

## 3. 원본 Python 동작 계약

### 3-1. 수치와 확률

- 원본 롤 옵션은 `buff_level` 1~5, 기본값 3이다 (`legendary_items.py:153-155`).
- 실제 배율은 `buff_level × 10%`이며 Lv.1~5가 10~50%다 (`legendary_items.py:4291-4298`, `4342-4350`).
- 매 스테이지 `1`, `2`, `3` 중 하나를 균등하게 뽑는다.
- 그 수만큼 6개 후보에서 복원 없이 균등 표본을 뽑는다 (`legendary_items.py:4755-4777`).
- 따라서 일반 캐릭터 기준 기대 축복 수는 2개이고, 개별 축복이 한 번의 결과에 포함될 주변 확률은 `2 / 6 = 1/3`이다.
- 눈 수는 특정 축복에 대응하지 않고 **선택되는 축복 수**만 뜻한다.

### 3-2. 발동·지속·리셋

- 원본의 유효 판정은 raw `stage >= 1`이며, Godot 목표의 캠페인-context 제한은 D13에서 별도로 잠근다.
- `_triggered_stages`로 같은 스테이지의 재장착·중복 훅·재방문 재굴림을 막는다 (`legendary_items.py:4352-4386`, `4755-4777`).
- 공 생성 인트로가 진행 중이면 굴림을 미루고 인트로가 끝난 뒤 시작한다 (`legendary_items.py:5972-6006`).
- 새 굴림을 확정할 때 이전 축복을 제거하고 새 축복을 즉시 적용한다.
- 점수로 인한 라운드 재시작에는 유지되고, 다음 실제 스테이지 굴림 때 교체된다.
- 새 게임/메인 메뉴 복귀의 full reset에서 결과·발동 이력·연출 상태를 모두 지운다 (`legendary_items.py:4741-4753`).

### 3-3. 연출과 입력

- 굴림 시작 시 `sounds/angeldice.wav`를 재생한다 (`legendary_items.py:4781-4787`).
- 3초 동안 성광, 주사위 회전, 깃털·별, 결과 강조를 보여 준다.
- 3초가 지나면 자동 종료하지 않고 Space/Enter 입력을 기다린다 (`legendary_items.py:5949-5968`).
- 종료 후 축복 수만큼 빛 입자가 각각 1.8초 동안 플레이어에게 이동하며 0.25초 간격으로 출발한다. 마지막 도착 뒤 플레이어 발광은 0.35초 더 유지된다.
- 입자 하나가 도착할 때마다 플레이어 발광과 `sounds/angeldicewhisp.wav`를 재생한다 (`legendary_items.py:4618-4651`).
- 모달 중 게임플레이는 멈추지만 연출 시간은 계속 진행한다 (`pingfighter.py:188252-188274`).

### 3-4. 획득 중첩과 UI

- 전설 획득 시네마틱과 겹치면 주사위 발동을 별도 대기 상태에 두고 시네마틱이 끝난 뒤 처리한다 (`legendary_items.py:13818-13853`).
- TAB 장비 정보는 현재 적용 중인 축복을 별도 목록으로 표시한다 (`pingfighter.py:194332-194364`).
- Python 저장은 아이템 보유·롤값을 저장하지만 현재 축복, 발동 스테이지 이력, 주사위 모달은 저장하지 않는다.

---

## 4. Godot 결정 잠금표

| ID | 결정 | 확정 내용 |
|---|---|---|
| D1 | 정체성 | ID `angel_blessing`, 표시명 `천사의 주사위`; “천사의 가호”는 검색·문서용 별칭만 유지 |
| D2 | 분류 | `CONVERTED_MYTHIC_PERKS` 소속 신화퍽, `max_level = 1`, 일반 퍽 슬롯 1칸 소비 |
| D3 | 강도 | 원본 기본 롤 Lv.3을 고정해 모든 축복 **30%** |
| D4 | 레벨 보정 | `effective_level_exempt = true`; 초월자의 관, 현자의 계약, 점화 오라, 연마, 아이템 강화가 강도를 올리지 않음 |
| D5 | 굴림 | 눈 1/2/3 각각 1/3, 후보 내 복원 없는 균등 표본, 결과는 눈 수와 정확히 같은 개수 |
| D6 | 지속 | 한 실제 스테이지 전체. 라운드 재시작에는 유지, 다음 스테이지 굴림에서 원자적으로 교체, full reset에서 제거 |
| D7 | 적용 시점 | 결과를 뽑는 순간 수치를 적용하고 모달은 이를 공개한다. 확인 후 흡수 연출은 표현이며 수치 적용 시점을 늦추지 않음 |
| D8 | 쿨타임 의미 | `item_cooldown`은 액티브 아이템에만, `active_cooldown`은 플레이어 스킬에만 적용 |
| D9 | 획득 채널 | 현재 신화퍽 잭팟 오퍼, 확정 신화퍽 선택 상자, 개발자 퍽 지급 경로만 사용 |
| D10 | 저장 | 런 단위 메모리 상태만 사용. 신규 디스크 저장 스키마와 Python 세이브 마이그레이션은 만들지 않음 |
| D11 | 보물탐색 | 제거된 `instant_treasure_hunt`를 획득 경로로 되살리지 않음 |
| D12 | 융합 | 현재 미구현인 퍽 융합은 범위 밖. 향후 메타가 도입되면 `mythic_system`, `penalty_hookable = false` 후보 |
| D13 | 유효 스테이지 | 캠페인 전투의 공 생성 인트로가 끝난 경우만 발동. 튜토리얼·아레나·광장·결과 화면·메인 메뉴는 제외 |

### 4-1. 캐릭터 능력 기반 스킬 쿨타임 후보 정책

현재 정책상 Optimus 스킬은 timestamp식 별도 경로를 사용하며 일반 쿨타임 감소 대상이 아니다 (`CLAUDE.md:1839-1853`). 이 때문에 모든 캐릭터에게 6종을 그대로 굴리면 Optimus에게 `active_cooldown`이 무효 결과가 된다.

선택지는 다음과 같다.

- A. 원본 완전 동일: Optimus도 6종을 굴리고 스킬 쿨타임 축복은 무효로 둔다.
- B. 능력 기반 후보 필터: `cooldown_reduction_eligible`인 스킬 계열이 없는 캐릭터에서는 `active_cooldown`을 후보에서 뺀다.

**권고 및 본 기획 기본값은 B**다. 특정 캐릭터 ID 하드코딩 대신 skill config가 명시한 live skill-id 목록, cooldown getter, runtime/item multiplier setter, cooldown state의 configured trigger/remaining/total 계약을 함께 확인한다. 현재는 Smasher, Viper, Commando가 6종을 굴리고, 일반 쿨타임 비대상인 Optimus와 Hammer Shock이 아직 없는 Baltor/Blacksmith는 5종을 굴린다. 5종 캐릭터에서 개별 유효 축복의 주변 확률은 `2 / 5 = 40%`다. 향후 Hammer Shock의 성공 release→타이머→투사체 종료 gate→HUD가 모두 포팅되고 config가 live 계약을 선언하면 Blacksmith는 코드의 캐릭터 예외 없이 자동으로 6종이 된다. 결과 화면과 상세 설명은 스킬 쿨타임 후보가 현재 캐릭터에서 제외됐음을 숨기지 않는다.

엄격한 원본 확률이 우선이라는 별도 결정이 내려지면 이 후보 필터 정책만 A로 바꾸고 확률·무효 결과 테스트를 함께 변경한다.

---

## 5. 여섯 축복의 Godot 사양

모든 동종 보정은 기존 체인과 **곱연산**한다. 최대 게이지만 기존 flat 보너스를 먼저 더한 뒤 천사 배율을 마지막에 곱한다.

| 축복 | 천사 배율 | 목표 소비점 | 합성·예외 계약 |
|---|---:|---|---|
| 패들 크기 | `×1.30` | `runtime_perk_state.get_player_paddle_size_multiplier()` → `runtime_perk_owner_effect_sync.gd` | 기존 일반퍽, 액티브 아이템, 신화 장비 배율과 1회만 합성. 위치 중심과 바닥 정렬을 유지 |
| 최대 게이지 | `×1.30` | 최종 `special_gauge_max` 합성 | 기본값과 `fuel_pouch` 같은 flat 보너스 뒤 곱함. 천사 결과 변경 시 현재 게이지 절대값을 유지하고 새 최대값으로 clamp |
| 액티브 아이템 쿨타임 | `×0.70` | `runtime_perk_state.get_active_item_cooldown_msec()` | `active_item_slot_controller.gd`와 `active_item_hud_state.gd`가 같은 최종값을 사용해야 함 |
| 플레이어 스킬 쿨타임 | `×0.70` | `runtime_perk_state.get_player_skill_cooldown_multiplier()` | 일반 훈련 보정 뒤, 천상의 망토 등 아이템 보정과 곱함. 액티브 아이템에는 재적용하지 않음 |
| 대시 쿨타임 | `×0.70` | `runtime_perk_state.get_dash_recharge_frames()` | 대시 토큰 재충전 시간만 감소. 대시 비용, 지속시간, 거리, 후딜은 변경하지 않으며 기존 최소 6프레임을 유지 |
| 이동 속도 | `×1.30` | `runtime_perk_state.get_player_speed_multiplier()` | 날씨·상태·액티브 아이템·링펫·신화 장비와 곱함. 플레이어 제어와 TAB 최종 스탯이 같은 값 사용 |

### 5-1. 필수 캐릭터 호환 보완

현재 공용 getter에 배율만 더하면 일부 캐릭터에서 효과가 지워진다. 다음 보완은 이 포팅의 필수 범위다.

1. **Optimus 패들**
   - `optimus_energy_state.gd`가 매 틱 패들 치수를 다시 만들며 공용 배율을 덮을 수 있다.
   - 에너지 상태는 캐릭터 기반 크기만 제공하고, 런타임 퍽·액티브 아이템·신화 배율의 최종 합성은 공용 패들 동기화에서 정확히 한 번 수행한다.

2. **Optimus 최대 게이지**
   - `optimus_energy_state.gd`의 하드코딩된 `500` 상한·clamp·비율 계산을 owner/config의 유효 최대 게이지로 교체한다.
   - 천사 최대 게이지를 보유한 Optimus도 충전 상한, HUD, 실제 소비가 같은 650을 보아야 한다.

3. **Baltor/Blacksmith 스킬 쿨타임**
   - 원본의 일반 쿨타임 대상은 Hammer Shock 하나뿐이며 단계별 실제 기본 쿨타임은 7/12/17초다. 현재 Godot의 `blacksmith_skill_config.gd`는 빈 스텁이고, 유일한 Thor Shield 런타임은 무쿨 토글/스윙이므로 대체 대상으로 삼지 않는다.
   - **구현 완료(S3-4):** `runtime_perk_angel_blessing_cooldown_capability.gd`가 config의 명시적 live skill-id 목록과 getter/runtime·item setter, 실제 cooldown state의 configured trigger/remaining/total 계약을 함께 확인한다. 현재 Blacksmith에서는 `active_cooldown`을 후보에서 빼고, 빈 compatibility config에는 향후 Hammer Shock용 runtime/item 배율 입력만 동기화한다. 숫자만 줄어드는 가짜 타이머는 만들지 않았다.
   - Hammer Shock 포팅 시 성공 release에서만 공용 state의 저장 total/timer를 시작하고, 타이머가 끝나도 투사체가 남으면 재사용을 막으며, orb wedge·남은 초·툴팁이 같은 config/state를 소비해야 한다. 그 완료 시 snapshot의 `cooldown_reduction_eligible = true`와 `cooldown_reduction_skill_ids = ["hammer_shock"]`를 함께 선언한다.

4. **Horn Strawberry 변신 이동속도**
   - 변신 경로가 공용 배율 이후 속도를 고정값으로 덮지 않도록 합성 순서를 고친다.
   - 변신 중에도 천사 이동속도 30%가 다른 허용 보정과 함께 남아 있어야 한다.
   - **구현 완료(S3-3):** 다섯 캐릭터 후단 controller 예외, 변신 전 잔존 스킬 상태, Commando 자폭 드론 0배 정지, TAB 날씨·상태 표시까지 `angel_blessing_horn_strawberry_speed_smoke.gd`로 봉인했다.

### 5-2. 수치 예시

- 기본 패들 배율 1.20과 패들 축복: `1.20 × 1.30 = 1.56`
- 기본 게이지 500 + 연료 파우치 140과 게이지 축복: `(500 + 140) × 1.30 = 832`
- 액티브 아이템 최종 쿨타임 8초에 아이템 쿨타임 축복: `8.0 × 0.70 = 5.6초`
- 대시 재충전 120프레임에 대시 축복: `120 × 0.70 = 84프레임`

각 소비점의 기존 반올림·최솟값 정책은 유지한다. 여러 경로에서 따로 반올림해 HUD와 실제 판정을 어긋나게 하지 않는다.

---

## 6. 획득 경로와 슬롯 정책

### 6-1. 현재 WIP 신화퍽 채널

2026-07-10 현재 `runtime_perk_catalog.gd:25`의 일반 오퍼 정책은 `mythic_jackpot_offer_chance = 0.1`인 단일 잭팟 레인이다. 성공하면 채울 수 있는 비골드 카드가 서로 다른 미보유 신화퍽이 된다. 과거 문서의 “3% 단일 카드 + 1% 잭팟” 또는 “신화 1%”는 현재 소스와 `mythic_perk_offer_chance_smoke.gd`보다 오래된 정책이다.

중요한 해석은 다음과 같다.

- 10%는 `angel_blessing` 개인 확률이 아니라 신화 잭팟 이벤트 확률이다.
- 개별 등장 확률은 당시 미보유 신화퍽 수와 카드 수에 따라 달라진다.
- 빈 퍽 슬롯이 없으면 잭팟이 열리지 않는다.
- 이미 보유한 `angel_blessing`은 중복 후보가 되지 않는다.
- 현재 슬롯 계약은 기본 6칸, 확장 포함 최대 10칸이며 `angel_blessing`은 일반 퍽 슬롯 1칸을 소비한다.

### 6-2. 반드시 등록할 두 목록

1. `RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS`
   - 일반 신화 잭팟과 카탈로그 데이터를 소유한다.
2. `MythicPerkGrantHelper.MYTHIC_PERK_IDS`
   - 확정 신화퍽 선택 상자와 신화 획득 시네마틱 경로를 소유한다.

한쪽에만 넣으면 일반 잭팟과 확정 신화 상자의 후보 풀이 갈라진다. 둘 다 12종에서 13종으로 갱신한다.

### 6-3. 획득 직후 발동

- **전투 중 잭팟/디버그 지급:** 표준 신화 획득 시네마틱이 끝난 다음 현재 스테이지가 아직 유효하면 그 스테이지의 주사위를 한 번 예약한다.
- **스테이지 클리어 결과 화면의 확정 신화 상자:** 끝난 스테이지의 주사위를 결과 화면에서 굴리지 않는다. 다음 실제 스테이지의 공 생성 인트로 종료까지 예약한다.
- 예약은 `apply_choice`가 성공하고 base level이 0→1로 바뀐 최초 획득 결과에서만 만든다. 카드 ID나 시네마틱 시작 시도만 보고 선등록하지 않는다.
- 두 경로가 같은 스테이지를 동시에 예약해도 `(stage, reason)`을 중복 제거해 한 번만 굴린다.
- 슬롯이 가득 차 스타포인트 폴백이 발생한 경우 보유·발동 상태를 만들지 않는다.

### 6-4. 사용하지 않을 아이템 경로

다음 시스템에는 `angel_blessing`을 추가하지 않는다.

- `mythic_item_catalog`와 필드 드롭
- 액티브/패시브 아이템 슬롯과 장비 토글
- Pandora 아이템 풀
- 상점, 캡슐, 크레인, 보물찾기 아이템 보상
- 아이템 연마·강화·롤옵션
- Python 아이템 보유 플래그의 디스크 마이그레이션

---

## 7. 상태 모델과 라이프사이클

### 7-1. 전용 논리 소유자

논리 상태는 다음의 작은 소유자로 분리한다.

```text
runtime_perk_angel_blessing_state.gd
  active_stage / triggered_stages / active_buff_ids / roll_face / injected_rng
runtime_perk_angel_blessing_modal_flow.gd
  pending_rolls / pending_reveals / modal clock / input arm / absorb clock + trajectories
runtime_perk_angel_blessing_localization.gd
  modal copy / buff labels / dynamic status lines
```

`runtime_perk_state.gd`는 이 객체들을 보유하고 공개 facade와 audio cue dispatch만 제공한다.

- 보유·활성 축복 조회
- 여섯 배율 조회
- 스테이지 인트로 종료 통지
- 획득 직후 예약
- 모달 activity/input/update snapshot
- full reset

6개 raw 글로벌이나 battle owner 필드를 별도로 만들지 않는다. 불가피하게 owner 필드를 투영한다면 `battle_scene_state.gd::DEFAULT_VALUES`, bootstrap, full reset을 같은 슬라이스에서 갱신한다.

### 7-2. 스테이지 흐름

| 이벤트 | 결과 |
|---|---|
| 첫 실제 스테이지 공 생성 인트로 종료 | 보유 중이고 미발동 스테이지면 굴림 시작 |
| 같은 스테이지 중복 callback | `_triggered_stages`로 무시 |
| 점수/라운드 리셋 | 현재 축복과 발동 이력 유지 |
| 다음 스테이지 진입 | 인트로 동안 이전 결과 유지, 인트로 종료 시 새 결과로 원자적 교체 |
| 디버그로 이미 방문한 스테이지 재진입 | 원본처럼 재굴림하지 않음 |
| 전투 중 최초 획득 | 획득 시네마틱 종료 후 현재 스테이지 한 번 굴림 |
| 결과 화면 최초 획득 | 다음 유효 스테이지 인트로 종료까지 대기 |
| 패배/새 런/메인 메뉴 | 결과, 예약, 발동 이력, 연출 host, 관련 사운드 모두 정리 |

`stage_ball_spawn_intro_finish_lifecycle.gd:42-45`에는 이미 `runtime_perk_state.on_ball_spawn_intro_finished(owner, registry)` 호출이 있다. 새 core 훅을 중복 추가하지 말고 이 완료 지점을 확장한다. 기존 차원개방·게이지 충전 deferred instant 처리를 유지한 뒤 Angel 예약을 해소하도록 결과를 합성한다.

완료 callback만으로 스테이지 유효성을 추측하지 않는다. owner의 stage 값과 명시적 battle context를 함께 검사해 캠페인 전투만 허용하고, 튜토리얼 Stage 50이나 아레나 같은 특수 stage 번호를 `stage >= 1` 조건만으로 통과시키지 않는다. 미래 캠페인 스테이지를 막는 고정 `1..6` 상한도 두지 않는다.

### 7-3. 모달 큐와 우선순위

신화 획득 시네마틱, 퍽 선택, 결과 화면, 공 생성 인트로가 닫히기 전에 Angel 모달을 열지 않는다. 기존 단일 pending 슬롯을 덮어쓰는 방식 대신 전용 deduplicated queue를 사용한다.

권장 우선순위는 다음과 같다.

```text
스테이지/결과 화면 전용 모달
→ 신화 획득 시네마틱
→ 런타임 퍽 선택·교체
→ 천사의 주사위
→ 일반 게임 입력
```

Angel 모달이 활성화된 동안:

- 물리·게임플레이·모바일 액션을 차단한다.
- 연출 update는 pause 상태에서도 진행한다.
- Space, Enter, gamepad confirm, 좌클릭, touch confirm을 지원한다.
- 선행 시네마틱을 닫은 동일 입력 이벤트가 Angel 확인으로 재사용되지 않도록 다음 프레임에 입력을 arm한다.

### 7-4. 스냅샷과 저장

`runtime_perk_snapshot_builder.gd`에는 UI·테스트용으로 다음을 노출한다.

```text
angel_blessing.active_stage
angel_blessing.active_buff_ids
angel_blessing.roll_face
angel_blessing.pending_stage
angel_blessing.modal_phase
angel_blessing.waiting_for_confirm
```

이 스냅샷은 디스크 세이브가 아니다. 현재 런타임 퍽과 마찬가지로 같은 battle registry의 스테이지 전환 동안 유지되고 full reset에서 소멸한다.

---

## 8. 카탈로그·값·로컬라이제이션

### 8-1. 카탈로그 엔트리

권장 한국어 원문:

```gdscript
"angel_blessing": {
    "name": "천사의 주사위",
    "max_level": 1,
    "descriptions": {1: "스테이지마다 서로 다른 축복 1~3개 획득 (효과 30%)"},
    "detail": "패들 크기·최대 게이지·이동 속도 증가 또는 액티브 아이템·플레이어 스킬·대시 재충전 시간 감소 축복을 얻습니다.",
    "icon_color": Color(...),
    "tree": "mythic",
    "rarity": "mythic",
    "effective_level_exempt": true,
    "conversion_source": "angel_blessing",
}
```

카드 상세나 동적 상태 줄에는 Optimus의 플레이어 스킬 쿨타임 후보 제외 정책을 짧게 설명한다. 선택 카드 본문을 과도하게 늘리지 않고 상세 툴팁에서 전체 6종을 보여 준다.

### 8-2. 고정값과 전환 매핑

`perk_conversion_values.gd`에 다음을 추가한다.

```gdscript
CONVERSION_SOURCE_TO_PERK["angel_blessing"] = "angel_blessing"
CONVERTED_MYTHIC_VALUES["angel_blessing"] = {"buff_pct": 30.0}
```

현재 고정 수치 검사는 모든 신화퍽이 하나 이상의 양수 값을 갖는다고 가정한다. 카탈로그 수는 12→13, 전환 소스 맵 수는 38→39로 함께 갱신한다.

### 8-3. 다국어

`language_settings_data.gd`의 다음 12개 맵에 직접 ID를 등록한다.

- `PERK_NAME_EN/ZH/JA/ES/PT_BR/RU`
- `PERK_SUMMARY_EN/ZH/JA/ES/PT_BR/RU`

한국어는 카탈로그 원문을 사용한다. 기존 Python `localization/ko.json`은 문구 참고일 뿐 Godot의 실시간 로컬라이제이션 경로로 사용하지 않는다.

이 카탈로그 이름·요약은 S6에서 등록 완료됐다. 실시간 모달·상태 문구는 전용 localization helper가 `ko/en/zh/ja/es/pt-BR/ru` 7개 지원 언어를 소유한다.

### 8-4. 동적 현재 축복 표시

정적 설명만으로는 매 스테이지 결과를 알 수 없으므로 TAB/상태 툴팁에 한 소스에서 만든 동적 줄을 추가한다.

```text
현재 축복 (2)
최대 게이지 +30%
대시 쿨타임 -30%
```

아직 굴리지 않았으면 `다음 스테이지 시작 후 발동`, 결과 화면에서 예약됐으면 `다음 스테이지에 주사위 대기`를 표시한다. 툴팁 렌더러마다 문구를 복제하지 않고 `runtime_perk_state.get_runtime_status_lines("angel_blessing")` 같은 단일 facade를 사용한다.

---

## 9. 아이콘·주사위 연출·오디오

### 9-1. 신화퍽 아이콘

현재 신화퍽 아이콘 계약을 그대로 따른다.

- 정적 fallback: `godot/assets/sprites/perks/angel_blessing_perk_icon.png`, 128×128
- 애니메이션: `godot/assets/sprites/perks/angel_blessing_perk_icon_sheet.png`, 1024×128
- 128×128 프레임 8개, 약 110ms/frame
- 외곽은 완전 투명, 반투명 찌꺼기 없는 hard alpha
- 핵심 실루엣: 금빛 날개와 후광이 달린 주사위. 작은 TAB 셀에서도 눈과 날개가 읽혀야 함

두 경로를 `runtime_perk_icon_renderer.gd::PERK_ICON_PATHS/PERK_SHEET_PATHS`에 모두 등록하고 sheet 우선, static fallback 순서를 유지한다.

### 9-2. 전용 모달 host

새 `godot/scripts/hud/angel_blessing_roll_overlay_host.gd`는 표현만 소유하고 논리 상태는 소유하지 않는다.

- full game canvas 760×750과 같은 rect의 `Control`에 `clip_contents = true`
- letterbox pillar로 새지 않도록 game offset/render scale 경계를 host에서 한 번만 변환
- 성광/후광, 날개 달린 주사위, 깃털·별 입자, 결과 카드, 흡수 궤적을 모듈식 texture/shader/`GPUParticles2D`로 구성
- 모든 레이어가 하나의 authoritative phase clock을 사용
- host 자체 `_process()`는 끄고 overlay controller의 sync/update에서만 전진
- `_draw()`에서 이미지 스캔, atlas 생성, `ImageTexture.create_from_image()`를 하지 않음
- 결과 모달이 닫힌 뒤 각 입자의 1.8초 이동과 0.25초 stagger, 마지막 0.35초 발광은 비차단으로 계속됨
- 논리 visibility가 false가 되어도 score/serve/stage/full reset이 직접 `set_active(false)` 또는 `tear_down()`을 호출

권장 phase:

| 시간 | 표현 |
|---:|---|
| 0.00~0.60초 | 성광 강림, 후광·날개 등장 |
| 0.60~2.25초 | 주사위 회전·바운스, 깃털·별 확장 |
| 2.25~2.70초 | 감속, 눈 수 고정, 축복 카드 진입 |
| 2.70~3.00초 | 선택된 축복 강조 |
| 3.00초 이후 | 확인 입력 대기 |
| 확인 후 | 각 입자가 1.80초 이동하며 0.25초 간격으로 출발 |
| 마지막 도착 후 0.35초 | 플레이어 발광 tail 후 정리 |
| 눈 3 전체 | 도착 1.80/2.05/2.30초, 전체 종료 2.65초 |

### 9-3. 오디오

원본 파일을 다음 경로로 옮긴다.

- `sounds/angeldice.wav` → `godot/assets/sounds/angeldice.wav`
- `sounds/angeldicewhisp.wav` → `godot/assets/sounds/angeldicewhisp.wav`

`game_audio.gd`에 one-shot player와 공개 메서드를 둔다.

- `play_angel_blessing_roll()` — 굴림 시작 한 번
- `play_angel_blessing_absorb()` — 1~3개 입자의 각 도착 시점
- `stop_angel_blessing_audio()` — 강제 reset/scene 이탈

흡수음은 최대 3개가 겹칠 수 있으므로 한 player를 매번 restart하지 말고 작은 player pool 또는 polyphonic 재생을 사용한다. loop flag를 변경하지 않으며, 경로 캐시된 공용 `AudioStream`을 변형하지 않는다.

### 9-4. prewarm

- 신화 아이콘 sheet는 기존 `RuntimePerkIconRenderer.prewarm_assets()` 경로에 자동 편입한다.
- 모달 texture/shader/particle material/audio는 battle boot 또는 공 생성 인트로의 staged prewarm에 편입한다.
- 모달 halo/ambient particle과 흡수 particle의 실제 draw 상태를 `battle_pso_prewarmer.gd`에서 offscreen으로 각각 렌더하고 flush 뒤 정리한다.
- 첫 실제 굴림 프레임에서 host 생성과 PNG/WAV cold load를 동시에 지불하지 않는다.

---

## 10. 구현 파일 인벤토리

### 10-1. 신규 파일

- `godot/scripts/characters/runtime_perk_angel_blessing_state.gd`
- `godot/scripts/characters/runtime_perk_angel_blessing_stage_lifecycle.gd`
- `godot/scripts/characters/runtime_perk_angel_blessing_localization.gd`
- `godot/scripts/hud/angel_blessing_roll_overlay_host.gd`
- `godot/shaders/angel_blessing_halo.gdshader`
- `godot/tests/angel_blessing_catalog_smoke.gd`
- `godot/tests/angel_blessing_roll_state_smoke.gd`
- `godot/tests/angel_blessing_buff_lanes_smoke.gd`
- `godot/tests/angel_blessing_stage_lifecycle_smoke.gd`
- `godot/tests/angel_blessing_modal_smoke.gd`
- `godot/tests/angel_blessing_mythic_routes_smoke.gd`
- `godot/tests/angel_blessing_overlay_host_smoke.gd`
- `godot/tests/angel_blessing_presentation_lifecycle_smoke.gd`
- `godot/tests/angel_blessing_audio_smoke.gd`
- `godot/tests/angel_blessing_status_tooltip_smoke.gd`
- `godot/assets/sprites/perks/angel_blessing_perk_icon.png`
- `godot/assets/sprites/perks/angel_blessing_perk_icon_sheet.png`
- `godot/assets/sounds/angeldice.wav`
- `godot/assets/sounds/angeldicewhisp.wav`

### 10-2. 주요 수정 대상

| 영역 | 파일/소유자 | 변경 목적 |
|---|---|---|
| 카탈로그 | `runtime_perk_catalog.gd` | 13번째 신화퍽 데이터와 잭팟 후보 |
| 값 | `perk_conversion_values.gd` | 30% 고정값, identity 전환 매핑 |
| 확정 신화 경로 | `mythic_perk_grant_helper.gd` | `MYTHIC_PERK_IDS` 편입 |
| 논리 facade | `runtime_perk_state.gd` | Angel state 보유, 조회/update/input/reset facade |
| 수치 쿼리 | `runtime_perk_effective_stat_query_surface.gd` | 기존 일반퍽 결과와 Angel 배율 합성 |
| owner sync | `runtime_perk_owner_effect_sync.gd`, `runtime_perk_owner_sync_flow.gd` | 굴림 직후 패들·스킬 config 즉시 갱신 |
| 리셋/스냅샷 | `runtime_perk_reset_state.gd`, `runtime_perk_snapshot_builder.gd` | run reset과 동적 UI 상태 |
| 획득 컨텍스트 | `runtime_perk_choice_apply_flow.gd`, `mythic_perk_grant_helper.gd`, `stage_clear_reward_resolver.gd` 및 result reward payload | accepted grant 뒤 현재-stage/next-stage 예약을 명시적으로 구분 |
| 획득 완료 감지 | 기존 `mythic_item_acquisition_cinematic_runtime.gd` facade 또는 전용 query | 선행 신화 시네마틱이 완전히 닫힌 다음 Angel 모달 open |
| 게이지 | `mythic_item_resource_bonus_runtime.gd`, `mythic_item_owner_syncer.gd` | flat 보너스 뒤 Angel 배율, 원인별 clamp 정책 |
| 캐릭터 호환 | `optimus_energy_state.gd`, Blacksmith 실제 skill timer/config 소유자 | 패들·게이지 덮어쓰기 제거, 쿨타임 감소 실제 적용 |
| 이동속도 | `mythic_item_stat_bonus_runtime.gd` 및 movement config 합성 | Horn 변신의 최종값 덮어쓰기 제거 |
| 모달 | `battle_scene_modal_gate_controller.gd`, `battle_scene_overlay_frame_controller.gd` | pause/update/draw/activity 분류 |
| 입력 | `battle_scene_input_controller.gd`, `battle_scene_overlay_input_controller.gd`, mobile gate | 확인 입력과 gameplay 차단 |
| 아이콘 | `runtime_perk_icon_renderer.gd` | static/sheet 등록과 prewarm |
| 번역 | `language_settings_data.gd` | 6개 비한국어 이름·요약 |
| 오디오 | `game_audio.gd` | 굴림/흡수 one-shot과 reset stop |
| prewarm | `battle_boot_resource_prewarm_controller.gd` 또는 기존 staged owner | 첫 굴림 hitch 방지 |
| 문서 | `godot_module_ownership_ledger.md`, `passive_to_perk_conversion_plan.md` | 신규 논리·host 소유권, 신화 수 13종과 전환 표 갱신 |

`stage_ball_spawn_intro_finish_lifecycle.gd`의 기존 완료 callback으로 충분하면 새 callback을 추가하지 않는다. 새 helper를 registry lazy module로 만들 경우에만 관련 `gameplay_*_module_catalog.gd`를 갱신한다.

### 10-3. 기존 하드코딩 테스트 갱신

- `perk_conversion_catalog_smoke.gd::CONVERTED_MYTHIC_PERK_IDS`
- `perk_conversion_values_smoke.gd`의 신화 수 12→13, 전환 맵 38→39
- `runtime_perk_mythic_icon_sheet_smoke.gd::MYTHIC_IDS`
- `perk_conversion_mythic_perk_channel_smoke.gd`
- `mythic_perk_acquisition_cinematic_smoke.gd`
- `mythic_perk_offer_chance_smoke.gd`

뒤 세 테스트가 helper 목록을 순회하더라도 새 아이콘과 카탈로그가 자동으로 통과하는지 확인한다. 숫자만 바꾸지 말고 새 ID의 양 채널 포함을 직접 단언한다.

---

## 11. 구현 슬라이스

### S1. 카탈로그·값·채널·번역·아이콘 계약

구현 상태: **완료**. S2~S5 동안 비노출로 유지한 뒤 S6 원자 공개에서 13번째 카탈로그, 30% 값, 잭팟/확정 신화 helper, 6개 비한국어 이름·요약과 static/sheet 아이콘 계약을 함께 활성화했다.

- 카탈로그, 고정값, conversion map, 두 신화 목록, 6개 언어를 추가한다.
- static/sheet 아이콘이 모두 준비되기 전에는 플레이어 노출을 켜지 않는다.
- Seal: `angel_blessing_catalog_smoke.gd`, 기존 catalog/value/icon/channel smoke.

완료 조건:

- 13번째 신화퍽으로 조회된다.
- max1, mythic, effective-level exempt, slot cost 1이다.
- 잭팟과 확정 신화 상자 양쪽 후보에 있다.
- 모든 언어에서 ID fallback이나 한국어 누수가 없다.

### S2. 순수 굴림 상태와 여섯 수치 lane

구현 상태: 비노출 상태에서 완료. `runtime_perk_angel_blessing_projection.gd`가 6종 수치 합성을 소유하고, 기존 query surface가 패들·아이템 쿨타임·스킬 쿨타임·대시 재충전·이동속도 getter에 이를 합성한다. 최대 게이지는 이중 적용을 피하는 전용 final-value facade까지만 제공하며 owner 갱신은 S3에 남긴다.

- 주입 가능한 RNG, 1~3 균등, 복원 없는 표본, stage dedupe를 먼저 구현한다.
- runtime perk query surface에 여섯 배율을 합성한다.
- Seal: `angel_blessing_roll_state_smoke.gd`, `angel_blessing_buff_lanes_smoke.gd`.

완료 조건:

- 강제 눈 1/2/3에서 결과 수가 정확하고 중복이 없다.
- 6종 각각을 강제했을 때 실제 소비점과 HUD snapshot이 함께 변한다.
- 선택되지 않은 lane은 완전히 중립이다.
- 원본 `active_cooldown` 이중 적용이 재현되지 않는다.

### S3. 5캐릭 호환과 스테이지 라이프사이클

구현 상태: S3-1~S3-5 완료. 최대 게이지 owner compositor와 Optimus 유효 상한, Optimus base-only 패들 snapshot과 최종 공용 compositor, Horn Strawberry의 replacement-base 이동속도 순서 및 다섯 캐릭터 후단 예외/TAB parity가 연결됐다. Blacksmith는 실제 Hammer Shock 미포팅을 감지해 무효 쿨타임 후보를 제외하고, 향후 실제 config/state가 들어오면 자동 개방하는 능력 gate와 공용 배율 입력 계약까지 연결했다. 기존 공 생성 인트로 완료 callback이 deferred instant를 먼저 해소한 뒤 Angel을 발동하며, 중복 callback·라운드 유지·다음 스테이지 교체·full reset 계약을 봉인했다.

- Optimus 패들·게이지, Blacksmith 쿨타임 후보 능력 gate, Horn 변신 속도 합성을 고친다. Hammer Shock 본체는 별도 캐릭터 포트에서 실제 타이머/HUD와 함께 연다.
- 공 생성 인트로 완료, 라운드 유지, 다음 스테이지 교체, full reset을 연결한다.
- Seal: `angel_blessing_horn_strawberry_speed_smoke.gd`, `angel_blessing_stage_lifecycle_smoke.gd`와 5캐릭 행렬.

완료 조건:

- 중복 intro callback과 라운드 reset이 재굴림하지 않는다.
- 다음 스테이지에서 이전 6개 multiplier가 모두 중립화된 뒤 새 결과만 적용된다.
- 모든 캐릭터에서 유효 후보가 실제 동작하고 Optimus 및 현재 WIP Blacksmith에 무효 스킬 쿨타임 후보가 나오지 않는다. 향후 Hammer Shock live 계약이 들어오면 Blacksmith 후보가 자동 개방된다.

### S4. 획득 후 예약과 모달 큐

구현 상태: **완료**. `angel_blessing_mythic_routes_smoke.gd`, `angel_blessing_modal_smoke.gd`, `angel_blessing_s4_integration_edges_smoke.gd`, `angel_blessing_s4_controller_wiring_smoke.gd`가 전투/결과 분기, 중복·실패·full-slot 미예약, 실제 시네마틱 wait/자연 종료/취소 복구, 시네마틱→남은 선택→Angel 순서, 종료 프레임 한 틱 차단, 3초 최소 표시와 입력 arm, 공용 입력 우선순위를 봉인한다.

- 표준 신화 획득 시네마틱 뒤 전투 중/결과 화면 정책을 분기한다.
- 기존 모달과 충돌하지 않는 pending queue, pause gate, 입력 arm을 구현한다.
- Seal: `angel_blessing_modal_smoke.gd`, `angel_blessing_mythic_routes_smoke.gd`.

완료 조건:

- 획득 시네마틱과 Angel 모달이 겹치지 않는다.
- 결과 화면 획득은 다음 스테이지까지 기다린다.
- 선행 모달을 닫은 입력이 Angel 모달까지 연속으로 닫지 않는다.
- full slot 폴백과 이미 보유 상태에서 발동 예약이 생기지 않는다.

### S5. VFX·오디오·동적 상태 UI

구현 상태: **완료**. 클립된 modular VFX host, 3초 결과 모달, 각 1.8초 이동·0.25초 stagger·최대 2.65초 흡수 tail을 구현했다. 원본 WAV의 SHA-256 일치, 3-voice pool, 동적 상태 facade, offscreen PSO warmup과 detached-host-only redraw를 봉인했다.

- 클립된 modular VFX host, 3초 결과 모달, stagger된 흡수 연출을 구현한다.
- 원본 두 사운드, player pool, 강제 정리를 연결한다.
- TAB/상태 툴팁에 현재 축복을 표시한다.
- Seal: `angel_blessing_modal_smoke.gd`, `angel_blessing_overlay_host_smoke.gd`, `angel_blessing_presentation_lifecycle_smoke.gd`, `angel_blessing_audio_smoke.gd`, `angel_blessing_status_tooltip_smoke.gd`, `runtime_perk_mythic_icon_sheet_smoke.gd`, `battle_pso_prewarmer_smoke.gd`, non-headless clip/tooltip capture.

완료 조건:

- letterbox pillar에 픽셀이 새지 않는다.
- pause 중 연출은 진행하고 gameplay는 정지한다.
- 1~3개의 흡수음이 잘리지 않으며 reset 후 소리가 남지 않는다.
- 최대 결과인 눈 3에서 헤더와 축복 3줄이 잘리지 않고, 두 fixture를 통해 6종 축복 문구가 모두 검증된다.

### S6. 회귀·성능·문서 마감

구현 상태: **완료**. 공개 카탈로그/값/helper/현지화를 한 슬라이스로 등록했고, 실제 세 획득 채널 종단과 제외 아이템 경로를 재감사했다. 통합 31개 smoke, warning scan 2,428 scripts, headless load, Vulkan Forward+ windowed overlay clip 및 신화 획득 캡처를 통과했으며 아키텍처·소유권·전환 수 문서를 현재 구현에 맞췄다.

- S1에서 보류한 `runtime_perk_catalog`, `perk_conversion_values`, `mythic_perk_grant_helper`, `language_settings_data` 등록을 하나의 원자 슬라이스로 켜고 catalog/value/channel/acquisition/offer smoke가 통과하기 전에는 플레이어 노출을 활성화하지 않는다.
- 신규 모듈 소유권을 `godot_module_ownership_ledger.md`에 기록한다.
- 이 문서의 현재 WIP 수치와 실제 구현을 대조하고 차이가 있으면 갱신한다.
- 관련 전체 smoke, warning scan, headless load, scaled/windowed live QA를 실행한다.

---

## 12. QA 매트릭스

### 12-1. 굴림·확률 구조

- 강제 face 1/2/3 결과 수와 `roll_face`가 일치한다.
- 같은 결과에 중복 ID가 없다.
- 일반 캐릭터 후보는 6종, Optimus 후보는 권고안 기준 5종이다.
- seed를 고정한 반복 테스트에서 모든 후보가 도달 가능하다.
- 자연 난수를 장시간 돌려 “정확히 1/3”을 요구하는 flaky test 대신, RNG seam과 후보/가중치 구조를 단언한다.

### 12-2. 스테이지 경계

- 첫 스테이지 인트로 종료 후 정확히 한 번.
- 같은 스테이지의 중복 완료 callback에서 0회 추가.
- 득점 후 라운드 재시작에서 결과 유지.
- 다음 스테이지 인트로 종료 후 정확히 한 번 새 결과.
- 디버그로 과거 스테이지 재방문 시 원본처럼 재굴림 없음.
- full reset 후 Stage 1에서 다시 발동 가능.
- 튜토리얼, 아레나, 광장, 결과 화면, 메인 메뉴 callback에서는 발동·예약 없음.

### 12-3. 획득 컨텍스트

- 전투 중 잭팟 → 획득 시네마틱 → Angel 모달 순서.
- 결과 화면 확정 상자 → Angel 모달 없음 → 다음 스테이지 인트로 후 발동.
- full slot, 중복 보유, 스타포인트 폴백에서 예약 없음.
- 잭팟 chance를 테스트 seam에서 1.0으로 만든 경우 후보 포함, 0.0에서 미노출.

### 12-4. 여섯 효과

- 패들: 충돌 치수, 렌더 치수, 중심/바닥 정렬, Optimus 에너지 크기.
- 게이지: owner max, HUD 분모, 소비 상한, 중간 획득의 절대값 유지+clamp, Optimus 상한.
- 액티브 아이템: 실제 사용 gate와 HUD wipe가 같은 쿨타임.
- 플레이어 스킬: Smasher/Viper/Commando/Blacksmith 실제 timer와 orb/tooltip 일치; Optimus 후보 제외.
- 대시: token recharge max/remaining 비율과 HUD wedge 일치; 후딜·비용 불변.
- 이동: 다섯 캐릭터, 상태효과, Horn 변신 중 multiplier 유지.

### 12-5. 모달·시각·오디오

- 3초 전에는 dismiss 불가, 이후 확인 전까지 계속 대기.
- Space/Enter/gamepad/mouse/touch 각각 한 번만 처리.
- pause 중 timer 전진, physics/game input 차단.
- 획득 시네마틱과 동일 입력 이월 없음.
- 760×750 clip 밖과 pillar letterbox에 유출 없음.
- score/serve/stage/full reset 직후 host hidden, particles stopped, audio stopped.
- 첫 사용 프레임에서 cold texture 생성·이미지 스캔·큰 proc spike 없음.

### 12-6. 실행 기준

GDScript 구현 후 최소 실행 묶음:

```powershell
.\tools\run_smoke_tests.ps1 -Tests @(
  'res://tests/angel_blessing_catalog_smoke.gd',
  'res://tests/angel_blessing_roll_state_smoke.gd',
  'res://tests/angel_blessing_buff_lanes_smoke.gd',
  'res://tests/angel_blessing_stage_lifecycle_smoke.gd',
  'res://tests/angel_blessing_modal_smoke.gd',
  'res://tests/angel_blessing_mythic_routes_smoke.gd',
  'res://tests/angel_blessing_s4_integration_edges_smoke.gd',
  'res://tests/angel_blessing_s4_controller_wiring_smoke.gd',
  'res://tests/angel_blessing_overlay_host_smoke.gd',
  'res://tests/angel_blessing_presentation_lifecycle_smoke.gd',
  'res://tests/angel_blessing_audio_smoke.gd',
  'res://tests/angel_blessing_status_tooltip_smoke.gd',
  'res://tests/runtime_perk_mythic_icon_sheet_smoke.gd',
  'res://tests/battle_pso_prewarmer_smoke.gd'
)
.\tools\run_warning_scan.ps1
.\tools\run_headless_load_check.ps1
```

관련 기존 conversion, mythic channel, acquisition cinematic, icon, active-item cooldown, dash, character config smoke도 함께 실행한다. 시각 변경은 headless 성공만으로 완료 처리하지 않고 실제 창에서 Stage 1→2 전환, 전투 중 지급, 결과 화면 지급, 다섯 캐릭터를 확인한다.

각 핵심 seal은 대상 조건을 인플레이스 토글해 RED를 재현한 뒤 즉시 복원하고 GREEN을 다시 확인한다. dirty worktree에서 `git reset`, `git checkout`, `git stash`로 반증검증하지 않는다.

---

## 13. 주요 위험과 방지책

| 위험 | 방지책 |
|---|---|
| 미사용 7종 상수를 따라 포팅 | 실행 import와 6종 explicit smoke로 봉인 |
| 신화 목록 한쪽만 등록 | catalog/helper 양쪽 직접 단언 |
| 원본 스킬 쿨타임 이중 적용 | item/skill lane 별도 테스트 |
| 라운드마다 재굴림 | `triggered_stages`와 stage callback 테스트 |
| 결과 화면에서 끝난 스테이지를 재굴림 | 획득 컨텍스트에 명시적 defer 정책 사용 |
| 튜토리얼/특수 모드에서 오발동 | raw `stage >= 1` 대신 캠페인 battle context를 함께 검사 |
| 단일 pending 상태 덮어쓰기 | stage-keyed deduplicated queue와 모달 우선순위 |
| Optimus 패들·게이지 하드코딩이 효과 삭제 | 공용 유효값을 캐릭터 상태에 주입하고 5캐릭 smoke |
| Blacksmith UI만 감소하고 실제 timer는 불변 | 실제 스킬 소비점과 HUD를 같은 config snapshot으로 검증 |
| Horn 변신이 이동 배율 덮어쓰기 | 최종값 대입 대신 합성 순서 테스트 |
| 게이지 HUD와 gameplay 최대값 불일치 | owner `special_gauge_max`를 단일 최종값으로 사용 |
| 모달 픽셀이 pillar로 유출 | full-canvas clip host와 windowed capture |
| host cleanup이 draw 호출에 의존 | reset/score/serve/stage에서 직접 tear-down |
| 첫 굴림 hitch | boot/intro staged prewarm과 BattlePerf 첫 사용 확인 |
| 오래된 3%/1% 핸드오프 재도입 | 현재 10% 단일 잭팟 smoke를 기준으로 재감사 |

---

## 14. 최종 완료 조건

다음을 모두 만족해야 “천사의 주사위 신화퍽 포팅 완료”로 본다.

- [x] 실제 원본의 6종만 사용한다.
- [x] `angel_blessing`이 13번째 max1 신화퍽으로 두 획득 목록에 등록된다.
- [x] 30% 고정이며 연마·강화·유효레벨 보너스를 받지 않는다.
- [x] 1~3 균등 굴림, 복원 없는 선택, 스테이지당 1회가 봉인된다.
- [x] 라운드 유지, 다음 스테이지 교체, full reset 정리가 맞다.
- [x] 여섯 효과의 gameplay와 HUD 소비점이 일치한다.
- [x] 원본 `active_cooldown` 이중 적용 버그가 없다.
- [x] 권고안 기준 Optimus 및 현재 WIP Blacksmith에 무효 후보가 없다. 향후 Hammer Shock 포팅 뒤에는 성공 발동 타이머와 HUD가 같은 최종 배율로 실제 감소한다.
- [x] 전투 중/결과 화면 획득 예약 정책이 서로 다르게 동작한다.
- [x] 기존 신화 획득 시네마틱과 Angel 모달이 겹치거나 입력을 공유하지 않는다.
- [x] static/sheet 아이콘과 7개 지원 언어 동적 현재 축복 UI가 완성된다.
- [x] 카탈로그 이름·요약이 한국어 + 6개 비한국어 맵에 등록된다.
- [x] full-canvas clip, 강제 host/audio cleanup, resource/PSO prewarm이 검증된다.
- [x] focused smoke, 관련 회귀 smoke, warning scan, headless load, windowed visual QA가 통과한다.
- [x] 신규 모듈 소유권과 최종 구현 차이가 문서에 반영된다.
