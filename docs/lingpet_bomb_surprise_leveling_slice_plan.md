# 볼탄 폭탄 서프라이즈 — 레벨 세분화 슬라이스 (코어 전용)

본 문서는 단일 소스 핸드오프 문서입니다. 설계/값/트랩/smoke 기대치는 Claude가
확정했고, GDScript 배선은 사용자가 수행하며, Claude가 적대적 diff 리뷰를 맡습니다
(작업 분담: [[feedback_design_slice_review_division]]).

## 0. 목표 / 범위

- 폭탄 서프라이즈(`volty_bomb_surprise`, `runtime_kind = bomb_surprise`)는 현재
  레벨 1~5에서 **게임플레이가 전혀 안 바뀌는** 평탄 스킬이다(범용 쿨/윈드업
  미세 감소만). 이를 **레벨당 5축 스케일**로 세분화한다.
- **스코프 = 코어만.** 보너스(α 보스편향 / β 더블폭탄 / γ 보스추가둔화)는 본
  슬라이스에서 제외. 향후 별도 슬라이스.
- **정체성 보존**: "어느 쪽(보스/플레이어)에 터질지 모르는 50/50 도박"은 그대로
  유지한다. 레벨링은 코인플립 자체를 건드리지 않고 **양쪽 결과를 둘 다 유리하게**
  만든다(상방↑ / 하방↓ / 회전율↑).

## 1. 현재 동작 (근거)

`godot/scripts/lingpet/lingpet_bomb_surprise_skill.gd`

- 시한폭탄(퓨즈 `FUSE_MIN 4.0`~`FUSE_MAX 8.0`s 랜덤)이 공에 부착 → 공이 패들에서
  vy 부호를 바꿀 때 폭탄 위치(`_location`)가 BALL↔TOP(보스)↔BOTTOM(플레이어)로
  토글되다가 퓨즈 만료 시 폭발.
- 폭발 결과는 **반경이 아니라 `_location`** 으로 보스/플레이어에 직접 적용된다
  (`_apply_explosion_status`). 폭발 반경 `EXPLOSION_RADIUS 350` / `SELF 180`은
  **순수 비주얼** — 반경 스케일은 게임플레이 무의미하므로 건드리지 않는다.
- 현재 평탄 상수 (line 11-17):
  - 보스: `BOSS_STUN_SECONDS 3.0`, `BOSS_KNOCKBACK_VELOCITY 52.0`,
    `BOSS_KNOCKBACK_FRAMES 18.0`
  - 자폭: `PLAYER_STUN_SECONDS 0.8`, `PLAYER_KNOCKBACK_SCALE 0.30`
    (자폭 넉백 = `BOSS_KNOCKBACK_VELOCITY * PLAYER_KNOCKBACK_SCALE`),
    `PLAYER_KNOCKBACK_FRAMES 10.0`
  - 공유: `KNOCKBACK_DECAY 0.85`
- 쿨다운(`cooldown 60.0`)은 모듈이 아니라 **카탈로그/엔진**이 관리.
- 모듈은 `launch_context`에서 레벨을 **읽지 않는다**(현 평탄의 근본 원인).

## 2. 확정 레벨 테이블

Lv.1 = 현재 밸런스와 동일하게 앵커(흔한 부화 레벨 0~3 너프 방지). 위로만 좋아짐.

| 레벨 | 보스 스턴(s) | 보스 넉백속도 | 자폭 스턴(s) | 자폭 넉백배율 | 쿨다운(s) |
|---|---|---|---|---|---|
| 1 | 3.0 | 52 | 0.80 | 0.30 | 60 |
| 2 | 3.3 | 56 | 0.72 | 0.27 | 56 |
| 3 | 3.7 | 60 | 0.62 | 0.24 | 52 |
| 4 | 4.1 | 66 | 0.52 | 0.21 | 47 |
| 5 | 4.6 | 72 | 0.40 | 0.18 | 42 |

효과: Lv.1→5 보스 스턴 +53% · 보스 넉백 +38% · **자폭 스턴 절반(0.8→0.4)** ·
자폭 넉백 -40% · 쿨다운 -30%. 넉백 프레임(보스 18 / 플레이어 10)은 속도 스케일이
체감을 책임지므로 **평탄 유지**. 모든 수치 튜닝 가능(Lv.5 4.6s가 과하면 4.0s로 하향).

## 3. 값 배치 — 모듈 vs 카탈로그 (중요)

스턴/넉백 4축은 **모듈 내부 상수**(런타임 진실)에만 두고, 쿨다운만 **카탈로그**에
둔다. 우유발사처럼 카탈로그+모듈 이중소스로 두지 말 것(동기화 트랩 회피).

### 3-1. 모듈 (`lingpet_bomb_surprise_skill.gd`)

내부 `*_BY_LEVEL` 상수 추가 + `launch()`에서 멤버로 캐싱(하이드로 스피어 패턴):

```gdscript
const BOSS_STUN_SECONDS_BY_LEVEL := [3.0, 3.3, 3.7, 4.1, 4.6]
const BOSS_KNOCKBACK_VELOCITY_BY_LEVEL := [52.0, 56.0, 60.0, 66.0, 72.0]
const PLAYER_STUN_SECONDS_BY_LEVEL := [0.80, 0.72, 0.62, 0.52, 0.40]
const PLAYER_KNOCKBACK_SCALE_BY_LEVEL := [0.30, 0.27, 0.24, 0.21, 0.18]

var _active_skill_level := 1
var _boss_stun_seconds := BOSS_STUN_SECONDS
var _boss_knockback_velocity := BOSS_KNOCKBACK_VELOCITY
var _player_stun_seconds := PLAYER_STUN_SECONDS
var _player_knockback_scale := PLAYER_KNOCKBACK_SCALE
```

- `reset()`: 위 멤버를 Lv.1 baseline(= 기존 const)으로 되돌린다.
- `launch()` 진입부에 추가:
  ```gdscript
  _active_skill_level = _get_active_skill_level(launch_context)
  _boss_stun_seconds = _get_level_float(BOSS_STUN_SECONDS_BY_LEVEL, _active_skill_level, BOSS_STUN_SECONDS)
  _boss_knockback_velocity = _get_level_float(BOSS_KNOCKBACK_VELOCITY_BY_LEVEL, _active_skill_level, BOSS_KNOCKBACK_VELOCITY)
  _player_stun_seconds = _get_level_float(PLAYER_STUN_SECONDS_BY_LEVEL, _active_skill_level, PLAYER_STUN_SECONDS)
  _player_knockback_scale = _get_level_float(PLAYER_KNOCKBACK_SCALE_BY_LEVEL, _active_skill_level, PLAYER_KNOCKBACK_SCALE)
  ```
- `_apply_explosion_status()`에서 const → 멤버로 교체:
  - 보스 분기: `direction * _boss_knockback_velocity`, `_boss_stun_seconds * 60.0`
  - 자폭 분기: `direction * _boss_knockback_velocity * _player_knockback_scale`,
    `_player_stun_seconds * 60.0`
- 헬퍼 `_get_active_skill_level(launch_context)` / `_get_level_float(values, level, fallback)`는
  `lingpet_milk_shot_skill.gd:478` / `lingpet_hydro_sphere_skill.gd:370`에서 그대로 이식.
- `get_snapshot()`에 `"bomb_surprise_active_skill_level": _active_skill_level` 추가
  (smoke OUTCOME 확인용; 기존 `bomb_surprise_last_stun_frames` /
  `bomb_surprise_last_knockback_velocity`도 검증에 사용).

### 3-2. 카탈로그 (`lingpet_catalog.gd`, volty 엔트리)

`cooldown_by_level`만 추가. 엔진이 `_apply_active_skill_level`(line 1796-1801)에서
적용하며, `cooldown_by_level`이 있으면 범용 12% 감소가 자동 비활성화되어 더블딥 없음.

```gdscript
"cooldown_by_level": [60.0, 56.0, 52.0, 47.0, 42.0],
```

**트랩**: volty bomb_surprise는 카탈로그에 `active_skill`과 `active_skill_pool[0]`
**두 곳에 중복** 정의돼 있다. `cooldown_by_level`과 설명문 갱신을 **양쪽 모두**에 넣어야
한다(한쪽만 고치면 풀 경로/기본 경로 중 하나가 누락).

## 4. 플레이어 노출 (설명문 — 현재 레벨 문구 0건)

카탈로그 `description`(양쪽 사본) 끝에 레벨 문구 추가:

> "…플레이어 쪽에서는 약한 스턴과 넉백, 상대 쪽에서는 강한 스턴과 넉백을 일으킵니다.
> **레벨이 오를수록 상대 폭발의 스턴과 넉백이 강해지고, 자폭 시 받는 피해는 줄며,
> 쿨타임도 짧아집니다.**"

`effect_text`도 같은 취지로 한 줄 보강(선택).

## 5. 배선 순서

1. 모듈: 상수 4개 + 멤버 4개 + `_active_skill_level` 추가, `reset()` 보강.
2. 모듈: `launch()`에서 레벨 읽기 + 멤버 캐싱, 헬퍼 2개 이식.
3. 모듈: `_apply_explosion_status()` const→멤버 치환, snapshot 키 추가.
4. 카탈로그: `cooldown_by_level` + 설명문(양쪽 사본).
5. 검증: bomb_surprise launch 호출부가 `launch_context["active_skill_level"]`을
   싣는지 확인(우유발사/하이드로 스피어는 이미 받음 — 디스패처가 균일하면 추가 없음).
   안 싣고 있으면 그 디스패치 지점에 active_skill_level을 추가.
6. smoke 작성/확장 + 반증검증.

## 6. smoke 기대치 (OUTCOME 단위, 반증검증 필수)

신규 `godot/tests/lingpet_bomb_surprise_skill_smoke.gd`
(레퍼런스: `lingpet_milk_shot_skill_smoke.gd`). `launch_context`로 레벨을 주입하고,
보스/자폭 폭발을 강제(폭탄 위치를 TOP/BOTTOM으로 몰아 `_explode`)한 뒤
snapshot의 `bomb_surprise_last_stun_frames` / `bomb_surprise_last_knockback_velocity`
를 검사:

- Lv.1 보스폭발: 스턴 == 180프레임(3.0*60), 넉백속도 절대값 == 52.
- Lv.5 보스폭발: 스턴 == 276프레임(4.6*60), 넉백속도 절대값 == 72.
- Lv.5 자폭: 플레이어 스턴 == 24프레임(0.4*60), 넉백속도 절대값 == 72*0.18 = 12.96.
- 쿨다운: `LingpetCatalog.get_active_skill("volty","volty_bomb_surprise",5).cooldown == 42.0`,
  `level 1 == 60.0`.
- **반증검증(SAFE)**: 위 Lv.1≠Lv.5 OUTCOME 단언이 **현재 평탄 코드에서 FAIL**함을
  in-place Edit 토글(예: launch의 레벨 캐싱을 일시 주석 처리)로 증명한 뒤 되돌린다.
  `git reset/checkout/stash` 금지(미커밋 WIP 파괴) — [[feedback_fable_grade_operating_posture]].
- 상태머신 회귀 가드: 기존 payload_factory_smoke / skill smoke의 위치-토글(BALL↔
  TOP↔BOTTOM) 케이스가 그대로 통과하는지 확인(레벨 추가가 코인플립 로직을 안 깼는지).

## 7. 트랩 요약

- 폭발 반경은 비주얼 전용 → 게임플레이 스케일 축으로 쓰지 말 것.
- 카탈로그 중복(active_skill + active_skill_pool[0]) 양쪽 동기화.
- 스턴/넉백은 모듈에만(이중소스 회피), 쿨다운은 카탈로그에만.
- `cooldown_by_level` 존재 시 범용 쿨 감소 자동 OFF — 의도된 동작.
- launch_context에 active_skill_level이 실리는지 디스패처 확인.
- Lv.1 = 현행 수치 앵커(저레벨 너프 금지).
