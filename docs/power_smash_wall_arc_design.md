# 파워스매싱 벽 반사 arc 재지정 설계 노트

작성 2026-06-11. 조사·시뮬레이션 근거는 본 노트 하단 참조. 배선은 이
노트의 신호 계약대로 진행하고, 완료 후 적대적 리뷰를 거친다.

## 1. 문제 (확정된 원인)

대각선 파워스매싱의 `arc_strength`(±0.68±0.08)는 발동 시점에 고정되고
벽 반사 시 뒤집히지 않는다. 벽이 vx를 반사하면 같은 호 힘(~0.3px/frame²,
부호는 항상 arc 부호)이 **반사된 가로 속도를 매 프레임 깎는 브레이크**가
된다. 60fps 시뮬레이션 수치:

- 부스트 윈도우(0.5s) 이후 벽 히트 시: 이후 0.5초간 |v| **−29.7~−39.6%**,
  vx ~−14 → ~−4 (가로 모멘텀 75% 소실).
- 행잉 랠리: 같은 벽에 1.35~1.5초 주기로 재접촉(벽-껴안기 루프),
  ~2.55초에 총속도 반토막.
- 부스트 윈도우 **안**의 벽 히트는 매 프레임 속도 재고정이 가려줌(−3.8%)
  — 체감 최악 케이스는 윈도우 이후 벽 히트뿐.

공속 캡은 원인이 아니다(파라볼라 중 전용 캡 35.0, 실측 최고 19.4).
Python 원본도 동일하게 안 뒤집는다 — 이 수정은 **의도적 Godot 분기**다.

## 2. 결정: FLIP @ 25% 스케일

벽 반사 시 arc를 **벽 반대 방향으로 재지정하되, 첫 재지정에서 크기를
원래의 25%로 축소**한다. 정책 비교(윈도우-후 벽 히트, 4시나리오 평균):

| 정책 | 벽 후 0.5s |v| 변화 | 도착각(수직 기준) | 행잉 랠리 3s |
|---|---|---|---|
| A 현행(미반전) | −29.7~−39.6% | 19~35° (속도 고갈) | 같은벽 루프, 반토막 |
| B 반전 100% | **+52~56%** | 59~71° (수평 읽힘), 반대벽 횡단(x=42) | 1.05s 주기 가속 핀볼 |
| B60 반전 60% | +32~34% | 65~67° 여전히 과커브 | 34~36 (캡 초과) |
| **B25 반전 25%** | **+15.1%** | ZERO 대비 +3.6~3.8°, 반대벽 횡단 없음 | **22~23 안착, 루프/반토막 없음** |
| C 제로화 | +2.6~3.2% | 무난 | 자연 교차 반사 |

- B25 선택 이유: 감속 체감 제거 + 가벼운 재가속(스매시 생동감 유지) +
  도착각·도착점이 ZERO와 거의 동일(과커브 없음) + 행잉 랠리 속도가
  파라볼라 캡(35)·일반 랠리 캡 모두 미만에서 안정.
- C(제로화)는 구현이 한 줄이어야 할 때의 차선 — 벽 이후 커브 정체성이
  죽는다.
- 튜닝 밴드: 스케일 0.15~0.35 (벽 후 속도 변화 ≈ 3% + 51%×스케일,
  선형 R≈1). 체감 QA에서 약하면 0.35, 과하면 0.15.

## 3. 신호 계약

### 훅 지점
`ball_motion_event_processor.gd _process_wall` —
`scene.merge(result, true)` 직후, 기존 `if not rematch_requested:` 블록
안에서 `_apply_chargebag_wall_gauge(...)`의 형제 호출로:

```gdscript
_notify_power_smash_wall_bounce(step_result, deps)
```

헬퍼 형태:

```gdscript
func _notify_power_smash_wall_bounce(step_result: Dictionary, deps: Dictionary) -> void:
    var power_state: Object = deps.get("power_state", null)
    if power_state == null or not power_state.has_method("notify_wall_bounce"):
        return
    power_state.notify_wall_bounce(str(step_result.get("side", "")))
```

- `power_state`는 스매셔 공용 ball update deps에 이미 존재
  (`ball_dependency_context.gd` `_append_smasher_update_deps`).
  **비스매셔는 `frame_deps["power_state"] = null`로 강제되므로 null 체크
  필수.**
- `side`는 step_result에 이미 있음(`check_wall`이 "left"/"right" 반환).
- rematch(무승부 재시작) 경로 제외는 기존 블록 게이트가 자연 처리.

### 상태 체인 (lock_freeze_pose / finish_motion 4단 패턴 미러)

```
power_state.notify_wall_bounce(side)        # facade — 가드 담당
  → runtime_state.notify_wall_bounce(side)  # 순수 패스스루
    → lifecycle_state.notify_wall_bounce(side)
      → parabola_state.repoint_arc_away_from(side)  # leaf
```

- **가드는 facade 안에서**: `is_parabola_active() and not
  is_ghost_shot_motion_active()`가 아니면 조기 return.
  `is_parabola_active()`만으로는 부족 — 고스트샷 모션 중에도 파라볼라가
  활성이고, 고스트 rise/chaos 페이즈는 `skip_ball_motion_step=false`라
  벽 체크가 실제로 돈다.
- leaf 의미:

```gdscript
const WALL_ARC_REPOINT_SCALE := 0.25

var wall_repointed: bool = false   # reset() / prepare()에서 false로

func repoint_arc_away_from(side: String) -> void:
    if not active:
        return
    var away_sign := 1.0 if side == "left" else -1.0   # resolve()와 동일 매핑
    if wall_repointed:
        arc_strength = away_sign * abs(arc_strength)    # 재지정만 (이중 축소 금지)
    else:
        arc_strength = away_sign * abs(arc_strength) * WALL_ARC_REPOINT_SCALE
        wall_repointed = true
```

- 시뮬레이션은 "첫 히트 25% 축소 + 이후 히트는 재지정만(크기 유지)"
  모델로 검증됐다. 매 히트 25% 복리 축소는 검증 안 된 변형 — 쓰려면
  행잉 랠리 체감 재QA 필요.
- 직선 스매시(arc=0)는 ±abs(0)=0으로 자연 no-op. leaf에 특수 분기 금지.
- 클린업 추가 부담 없음: `parabola_state.reset()/prepare()`가
  `wall_repointed`를 함께 초기화하면 기존 라운드/서브 리셋 경로
  (`ball_round_cleanup` → `power_state.reset()`)가 그대로 커버.

## 4. 슬라이스

1. `parabola_state`에 `WALL_ARC_REPOINT_SCALE`/`wall_repointed`/
   `repoint_arc_away_from` 추가 + reset/prepare 초기화.
2. lifecycle → runtime → facade 패스스루 3단 + facade 가드.
3. `_process_wall`에 헬퍼 1개 + 호출 1줄.
4. 스모크(§5) + 기존 스모크 회귀 확인
   (`smasher_ghost_shot_motion_skip_smoke`, `power_smash_player_return_smoke`,
   `junior_power_smash_tuning_smoke`, `smasher_power_smash_skill_lock_smoke`).
5. 인게임 체감 QA: 대각선 스매시→벽 반사 후 감속감 소멸 확인, 행잉
   랠리에서 핀볼화 안 됨 확인. 필요시 스케일 0.15~0.35 내 튜닝.

## 5. 스모크 계약 (outcome 단언, 새 `*_smoke.gd`)

하니스는 `smasher_ghost_shot_motion_skip_smoke`(풀루프) 또는
`power_smash_player_return_smoke`(직접 유닛) 형태 복사. 필수 케이스:

1. **재지정+축소**: `begin_activation(direction=-1, arc=-0.68, ...)` →
   `update_freeze`로 파라볼라 발진 → 왼쪽 벽 이벤트 → `get_arc_strength()
   > 0` **이고** 크기 ≈ 0.25×원본.
2. **브레이크 소멸(outcome)**: 재지정 후 `apply_motion` 수 프레임에서
   **매 프레임 Δvx > 0**(왼벽 반사 후 오른쪽으로 가속). chaos 난수가
   있어도 힘의 부호는 결정적이므로 부호만 단언, 크기 단언 금지.
   부스트 윈도우(0.5s) 이후 시점에서 단언(윈도우 안은 속도 재고정이
   가림).
3. **고스트샷 미적용**: 고스트 모션 중 `notify_wall_bounce` 호출이
   arc를 바꾸지 않음.
4. **직선 no-op**: arc=0이면 0 유지(부호 단언 금지).
5. **멱등성**: 같은 벽 2회 연속 히트 시 부호 유지 + 크기 불변(이중
   축소 없음).
6. **null 안전**: deps에 power_state 없음(비스매셔) → 크래시 없음.
7. 풀루프 사용 시: deps에 **real `WallBounceController` 필수**(없으면
   `_process_wall` 조기 return으로 훅 미도달), FakeMotionStepper의 벽
   이벤트 dict에 `"side"` 키 필수(누락 시 오른벽 취급).

## 6. 함정 브리프

- **같은 프레임 순서**: `apply_power_motion`(arc 적용)이
  `step_motion`(벽 해소)보다 먼저 돈다. 벽 히트 프레임은 구부호 arc
  1틱이 이미 적용된 상태 — 정상이며, 같은 프레임에 재적용(이중 적용)
  시도 금지.
- **프레임당 벽 이벤트는 최대 1회**(stepper가 첫 이벤트에서 스텝 중단)
  — 코너 더블파이어 없음. 프레임 간 반복 히트는 멱등 재지정으로 안전.
- **randf 2곳**: 발동 arc(±0.08)와 모션 chaos. 스모크는
  `begin_activation`에 arc를 직접 넣고, 모션은 부호만 단언.
- **벽 댐핑 0.95는 유지**(x·y 모두). 이번 수정 비범위(§7).
- **wall_bounce_state의 wall-clock**: rematch 동작까지 같은 스모크에서
  단언하려면 `current_msec` 명시 전달 필요(기본 `Time.get_ticks_msec()`).
- **패리티 기록 의무**: Python은 안 뒤집는다. 훅과 leaf에 의도 분기
  주석 + 랜딩 시 `docs/character_skill_perk_checklist.md` §3.2에 한 줄
  백필("벽 반사 arc 재지정은 2026-06-11 의도 분기 — 패리티 복원 금지").

## 7. 명시적 비범위 (이번에 바꾸지 않는 것)

- **벽 댐핑 0.95**: 물리감 + Python parity 유지. arc 수정만으로 체감
  문제의 주성분이 사라짐.
- **파라볼라 중 최저속도 플로어**: 도입 안 함. 행잉 랠리 반토막은
  벽-껴안기 루프가 원인이었고 재지정으로 루프 자체가 사라짐(시뮬 확인).
- **보스 카운터 `original_speed` 스냅백**: Python 주석으로 명시된 의도
  설계("보스 반격 시 감속용") — 유지.

## 8. 근거 산출물

- 시뮬레이션 스크립트: `d:/tmp/power_smash_arc_policy_sim.py`,
  `d:/tmp/power_smash_flip_scale_sweep.py` (60fps, 25°/40° ×
  16.37/18.39 발사, 윈도우 안/후 벽 히트, 행잉 랠리 3s 프로브).
- 원인 조사: 2026-06-11 멀티에이전트 검증(공속캡 기각, arc 미반전 확정,
  Python 1:1 패리티 확인).
