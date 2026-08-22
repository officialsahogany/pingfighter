# 보스 스킬카드 쿨다운 계약

이 계약은 `StageBossVariantCatalog`가 아니라 Godot 1~8층의 **런타임 보스
스킬 HUD producer 전수**에 적용한다. 정본 씰은 `scripts/stages/stage*/` 아래에서
`get_hud_context()`를 구현하고 `*_boss_skill_hud_skills` payload를 실제 게시하는
concrete state를 발견한다. Stage 2/3의 `*_boss_variant_skill_state.gd`는 같은
concrete owner를 위임하는 router이므로 중복 보스로 세지 않는다.

현재 전수는 14보스·39스킬이다.

- Stage 1: 달지, 각시탈, 포도대장
- Stage 2: 청린귀, 지굴왕, 거미각시
- Stage 3: 연묘, 포웅귀, 옥토선자
- Stage 4: 퐁크
- Stage 5: 홍련
- Stage 6: 테트리서
- Stage 7: 아카무
- Stage 8: 미노타우로스 placeholder

보스 목록을 별도 상수로 손 관리하지 않는다. 새 stage state가 런타임 HUD payload를
게시하면 탐색 결과에 자동 진입하며, metadata나 시전 fixture가 없으면 씰이 RED가
된다. 시전 fixture는 발견된 스킬을 production activation owner로 통과시키는
adapter일 뿐이며 보스 전수 목록의 원천이 아니다.

## 카드 payload

모든 카드는 다음 키를 낸다.

- `id`: 보스 안에서 안정적인 스킬 ID.
- `status`: 현재 상태. 최소 `charging`, `ready`, `casting`을 구분한다.
- `cooldown_remaining`: 다음 발동까지 남은 시간, tick 또는 자원량.
- `cooldown_total`: 진행률 분모. 항상 epsilon보다 커야 한다.
- `progress`: 기본 레일은
  `clamp(1.0 - cooldown_remaining / cooldown_total, 0.0, 1.0)`.
- `ready`: 실제 발동 가능 상태.
- `cooldown_contract`: 아래 계약 종류 중 하나.
- `initial_ready_allowed`: 전투 첫 publication에서 즉시 ready인 명시적 디자인
  예외인지 여부.
- `implemented`: `placeholder`이면 반드시 `false`.

기존 렌더러 호환 키(`active`, `cooldown`, `cooldown_progress` 등)는 소비자가
남아 있는 동안 유지한다. 계약 판정의 정본은 `cooldown_remaining`,
`cooldown_total`, `progress`, `ready`다.

## reset, 진행, 재충전

`time` 스킬은 스킬별 `*_INITIAL_COOLDOWN_*` 상수를 선언하고 `reset()`에서
`remaining = initial > 0`, `total > 0`, `progress < 1`, `ready = false`로
시작한다. 초기값 0은 카드를 첫 프레임부터 100%로 만드는 즉시-ready 선언이므로
암묵적으로 쓰지 않는다. 정말 즉시 시전이 디자인이면
`initial_ready_allowed=true`를 payload에 명시하고 이 문서에 이유를 기록한다.
현재 허용 예외는 0개다.

각 activation owner는 시전 성공 뒤 양수 cooldown 또는 양수 재충전 자원을
복구한다. 다음 production update/event를 진행하면 remaining은 줄고 progress는
늘어야 한다. float 레일은 `<= epsilon` / `> epsilon` 밴드로 판정하고 정확한
`== 0.0` 또는 `is_equal_approx()` write gate에 의존하지 않는다(GRT-037).

쿨다운 감소 owner는 production에서 정확히 한 경로다. Stage 1~3과 5~8은
`battle_effects_update_controller.gd`가 활성 state의 `update()`를 한 번 호출하고,
Stage 4는 controller → pillar background → map state → Ponk state 한 체인으로
호출한다. ball/effects 양쪽이 같은 state를 갱신하는 2배속 경로는 금지한다
(GRT-018).

## 계약 종류

- `time`: 초 기반 레일. reset 후 진행하고 시전 종료/성공 뒤 양수로 재충전한다.
- `deferred_time`: 첫 publication은 비활성·비-ready로 게시하고 첫 live update가
  양수 랜덤/스케줄 레일을 arm한다. 아카무 수리검처럼 0/0 표면만으로 결함 판정을
  내릴 수 없는 경우다.
- `event_cycle`: 고정 physics tick 레일. `friend_moles`처럼 score unlock과
  active window를 가지며 live tick마다 정확히 한 tick 진행한다.
- `score_latched`: `spider_rage`, `illusion_ripple`처럼 점수 사건 뒤 라운드나
  unlock 상태에 발동하는 latch. 양수 total과 score/cast 전이를 게시한다.
- `resource_gauge`: 홍련폭염의 용구슬과 테트리서 필살 게이지처럼 사건/전투
  update가 자원을 채운다. HUD에는 `remaining = total - current`를 게시해 같은
  progress 식을 유지한다.
- `placeholder`: 아직 시전 owner가 없는 명시적 빈 슬롯. 양수 total,
  `implemented=false`, `ready=false`, `progress<1`이어야 한다.

## 초기 대기값 판단

기본 청린귀는 지진 40초, 물대포 30초, 속도방어 25초를 초기 대기로 쓰고,
기본 연묘는 눈물 25초, 저주상자 35초, 사이코볼 70초를 채운 채 시작한다. 따라서
전투 시작 직후 모든 보스 스킬을 즉시 발동시키는 것이 기존 의도가 아니다.
2~3층 신규 보스에는 이미 첫 시전 뒤 사용하던 재충전 총량을 초기값으로 재사용했다.

| 보스 | 스킬 | 초기 대기 | 근거 |
|---|---|---:|---|
| 지굴왕 | tunnel_raid | 8초 | `TUNNEL_COOLDOWN_SEC` |
| 지굴왕 | spinning_claw | 20초 | `SPINNING_CLAW_COOLDOWN_SEC` |
| 지굴왕 | friend_moles | 2880 tick(40초) | `FRIEND_MOLES_COOLDOWN_TICKS` |
| 거미각시 | web_trap | 15초 | `WEB_TRAP_COOLDOWN_SEC` |
| 거미각시 | web_rescue | 25초 | `WEB_RESCUE_COOLDOWN_SEC` |
| 거미각시 | spider_rage | score latch | score event 계약 유지 |
| 포웅귀 | cotton_throw | 10초 | `COTTON_THROW_COOLDOWN_SEC` |
| 포웅귀 | cotton_bomb | 12초 | `COTTON_BOMB_COOLDOWN_SEC` |
| 포웅귀 | deadly_hug | 15초 | `DEADLY_HUG_COOLDOWN_SEC` |
| 포웅귀 | heart_beam | 8초 | `HEART_BEAM_COOLDOWN_SEC` |
| 옥토선자 | mirror_world | 15초 | `MIRROR_COOLDOWN_SEC` |
| 옥토선자 | size_shift | 10초 | `SIZE_SHIFT_COOLDOWN_SEC` |
| 옥토선자 | rabbit_projectile | 8초 | `RABBIT_COOLDOWN_SEC` |
| 아카무 | 그림자분신 | 8초 | 기존 시전 완료 재충전 `COOLDOWN_SEC` |
| 아카무 | 구름장막 | 15초 | 기존 균등 범위 10~20초의 기대값 midpoint |

구름장막 초기값은 최소 10초나 최대 20초로 치우치지 않는 균등 범위의 기대값
15초다. reset에서 RNG를 소비하면 전투 RNG 순서가 바뀌므로 deterministic
midpoint를 사용한다. 첫 시전 이후에는 기존대로 10~20초를 다시 roll하며,
`cooldown_remaining`과 `cooldown_total`을 같은 양수 값으로 재장전한다.

1층 세 보스는 별도 cooldown state를 쓴다. runtime timer 0 / duration 양수는
progress 0 / not-ready를 뜻하며 update가 timer를 채우는 반대 방향 레일이다.
아카무 수리검도 첫 live tick에서 8~25초 스케줄을 arm하는 정상
`deferred_time`이고, 극정호신은 Awakening 첫 공개 시 50초 레일을 arm한다.
표면의 reset 숫자만 보지 않고 첫 publication과 live owner를 함께 판정한다.

## 봉인

정본은 `res://tests/boss_skill_card_cooldown_contract_smoke.gd`이다. 성공 마커는
실제 발견한 보스/스킬/계약 종류 수를 출력한다.

```powershell
./tools/run_smoke_tests.ps1 -Tests res://tests/boss_skill_card_cooldown_contract_smoke.gd
$env:BOSS_SKILL_CARD_ZERO_INITIAL_FIXTURE='1'
./tools/run_smoke_tests.ps1 -Tests res://tests/boss_skill_card_cooldown_contract_smoke.gd
Remove-Item Env:BOSS_SKILL_CARD_ZERO_INITIAL_FIXTURE
```

첫 명령은 현재 14보스·39스킬의 required keys, 양수 total, reset 비-ready,
여러 tick/event의 progress 변화, production 시전 owner, 재충전, 단일 update owner를
전수 검사한다. 현재 계약 분포는
`TIME=32 DEFERRED_TIME=1 EVENT_CYCLE=1 SCORE_LATCHED=2 RESOURCE_GAUGE=2 PLACEHOLDER=1`이다.

두 번째 명령은 새 전수 범위인 Stage 7 아카무 `stage7_clone` 초기값을 0으로
되돌리는 반증 픽스처이며 반드시 러너 RED여야 한다. 씰은 focused CI와 pre-push
두 목록에 같은 경로로 등재한다.
