# 보스 스킬카드 쿨다운 계약

이 문서는 `stage_boss_variant_catalog.gd`에서 `ported=true`인 모든 보스가 좌측
필러 스킬카드에 제공해야 하는 쿨다운 상태 계약이다. 현재 전수 범위는 1~3층
9보스, 25스킬이다. 신규 보스를 catalog에 추가하면 전수 씰에도 반드시 어댑터를
추가해야 한다.

## 카드 payload

모든 카드는 다음 키를 낸다.

- `id`: 보스 안에서 안정적인 스킬 ID.
- `status`: 최소 `charging`, `ready`, `casting` 중 현재 상태.
- `cooldown_remaining`: 현재 남은 대기량. 초 기반 또는 고정 tick 기반이다.
- `cooldown_total`: 진행률 분모. 항상 epsilon보다 커야 한다.
- `progress`: `clamp(1.0 - cooldown_remaining / cooldown_total, 0.0, 1.0)`.
- `ready`: 실제 발동 가능 상태. 단순히 카드가 비활성이라는 뜻이 아니다.
- `cooldown_contract`: 아래의 `time`, `event_cycle`, `score_latched` 중 하나.
- `initial_ready_allowed`: 전투 첫 프레임 즉시 ready가 명시된 디자인 예외인지 여부.

기존 렌더러 호환 키(`active`, `cooldown`, `cooldown_progress` 등)는 소비자가 남아
있는 동안 유지한다. `cooldown_remaining`이 계약상의 정본이다.

## reset과 재충전

`time` 스킬은 스킬별 `*_INITIAL_COOLDOWN_*` 상수를 선언하고 `reset()`에서
`remaining = initial > 0`, `total > 0`, `progress < 1`, `ready = false`로 시작한다.
초기값 `0`은 카드가 첫 프레임부터 100%로 고정되는 즉시-ready 선언이므로 암묵적으로
쓰지 않는다. 정말 즉시 시전이 디자인이면 `initial_ready_allowed=true`를 payload에
명시하고 전수 씰의 해당 어댑터와 이 문서에 이유를 기록한다. 현재 예외는 0개다.

각 시전 owner는 발동이 성공한 순간 `cooldown_remaining`을 양수 재충전 값으로
되돌린다. 그 뒤 live update를 여러 번 돌렸을 때 `remaining`은 줄고 `progress`는
늘어야 한다. float 레일은 `<= epsilon` / `> epsilon` 밴드로 판정하고, 정확한
`== 0.0` 또는 `is_equal_approx()` write gate에 의존하지 않는다(GRT-037).

쿨다운 감소 owner는 `battle_effects_update_controller.gd`가 호출하는 활성 stage
state의 `update()` 한 경로뿐이다. ball/effects 두 경로에서 같은 state를 갱신하면
2배속이 되므로 금지한다(GRT-018). 전수 씰은 production controller를 통과시킨 한
틱의 정확한 감소량을 별도로 단언한다.

## 계약 종류

- `time`: 초 기반 레일. reset 후 진행하고 시전 후 양수로 재충전한다.
- `event_cycle`: 고정 physics tick 레일. `friend_moles`처럼 score unlock과 active
  window를 가지지만 reset 카드에는 양수 total/remaining을 제공하고, 실제 live
  tick마다 정확히 한 tick 감소한다.
- `score_latched`: `spider_rage`처럼 점수 사건 뒤 라운드에 발동하는 latch. 시간
  레일처럼 자동 증가하지 않지만 양수 total을 제공하고 score/cast 상태 전이를
  명시한다.

## 2026-08-22 신규 4보스 초기값 판단

기본 청린귀는 지진 40초, 물대포 30초, 속도방어 25초 간격을 초기 대기로 쓰고,
기본 연묘는 눈물 25초, 저주상자 35초, 사이코볼 70초를 채운 채 시작한다. 즉
전투 시작 직후 무조건 스킬이 터지는 것이 기존 보스의 의도가 아니다. 신규 4보스도
새 밸런스 값을 만들지 않고 이미 첫 시전 뒤 쓰던 재충전 총량을 초기 대기로
사용한다.

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

1층 각시탈·포도대장과 달지는 별도 cooldown state를 쓴다. 세 모듈 모두 reset에서
runtime timer를 0, duration을 양수로 두어 progress 0 / not-ready로 시작하고, update
한 경로로 충전하며, 시전 시 timer를 0으로 되돌린 뒤 재충전한다. 전수 씰에 6스킬
모두 포함된다.

## 봉인

정본은 `res://tests/boss_skill_card_cooldown_contract_smoke.gd`이다. 성공 마커는
보스/스킬/계약 종류 수를 출력한다.

```powershell
./tools/run_smoke_tests.ps1 -Tests res://tests/boss_skill_card_cooldown_contract_smoke.gd
$env:BOSS_SKILL_CARD_ZERO_INITIAL_FIXTURE='1'
./tools/run_smoke_tests.ps1 -Tests res://tests/boss_skill_card_cooldown_contract_smoke.gd
Remove-Item Env:BOSS_SKILL_CARD_ZERO_INITIAL_FIXTURE
```

첫 명령은 9보스·25스킬의 reset, 진행, 시전 owner, 재충전, 단일 update owner를
전수 검사한다. 두 번째 명령은 지굴왕 `tunnel_raid` 초기값을 0으로 되돌리는
부정 픽스처이며 반드시 러너 RED여야 한다. 씰은 focused CI와 pre-push 두 목록에
동시에 등재한다.
