# 두더지왕 스킬 파리티 r2 /goal 지시문 (2026-08-20)

- **출처**: 사용자 라이브 제보 3건.
  1. **회전발톱 방향이 원본과 다르다.** 지금은 무조건 왼쪽으로 발사된다.
  2. **회전발톱 이펙트 사운드가 포팅 안 됐다.**
  3. **친구 두더지 메커니즘 개편.** 4점 획득 시 해금은 유지하되, 상시 지속이
     아니라 **발동 시 10초 지속, 쿨타임 40초**로 바꾼다.
- **기준 HEAD**: 최신. ⚠ 본 트리에 미커밋 WIP이 3800건 있다. 격리 워크트리에서
  작업하고 `stash`·`checkout`·`reset`·통짜 `git add` 없이 통합 대기하라.
- ★**새 워크트리를 콜드로 만들지 마라.** 하나가 약 10GB다.
- **완료 보고**: `docs/molewang_skill_parity_r2_report.md`. 푸시 금지.
  **통합하지 말고 보고 후 대기하라.**

## 0. ★땅굴습격은 결함이 아니다 `[확인]`

사용자가 "땅굴습격이 작동 안 된다"고 먼저 보고했다가 **6:6 상황에서 발동을
직접 확인**했다. Fable 이 원본과 대조했다.

`pingfighter.py:80346` `activate_tunnel_raid()`

```python
if boss_special_gauge < 500:
    return False
boss_special_gauge = 0
```

`TUNNEL_RAID_COOLDOWN = 8000` (8초).

Godot 은 `TUNNEL_COST := 500`, `TUNNEL_COOLDOWN_SEC := 8.0` 이다.
**원본과 동일하다. 별도 해금 조건은 원본에도 없다.**

★**땅굴습격을 건드리지 마라.** 게이지 500 이 원본 사양이며 늦게 나오는 것이
정상이다. 다만 아래 §1-1 이 게이지 소비 구조를 바꾸므로 **체감 빈도가
달라진다.** 그 영향을 보고서에 적어라.

## 1. 계약

### 1-1. 회전발톱 방향 ★진범 후보 확정

**공식은 원본과 이미 같다.**

`pingfighter.py:80831`

```python
if BALL.centerx < BOSS.centerx:
    spinning_claw_direction = 1
else:
    spinning_claw_direction = -1
```

`stage2_molewang_boss_state.gd:135`

```gdscript
spinning_claw_direction = 1 if ball_center_x < boss_center_x else -1
```

**같다.** 그러므로 결함은 공식이 아니라 **소비 경로**다.

★`stage2_molewang_boss_state.gd:145` 가 결과에
`"ball_spin_direction": spinning_claw_direction` 을 싣는다.

★그런데 `paddle_bounce_boss_post_hit_handler.gd:65-68` 은 이렇게만 읽는다.

```gdscript
stage2_result = stage2_skill_state.register_boss_hit(next_ball_vel, context, deps)
next_ball_vel = _get_vector2(stage2_result, "ball_vel", next_ball_vel)
next_spin_strength = float(stage2_result.get("ball_spin_strength", next_spin_strength))
```

**`ball_spin_direction` 을 안 읽는다.** 스핀 세기만 적용되고 방향은 버려진다.
그래서 이전 방향이 그대로 남아 항상 같은 쪽으로 휘는 것으로 보인다.

⚠ **이것은 유력한 가설이지 확정이 아니다.** 실측으로 확인하라.
`ball_spin_direction` 이 이 경로 밖에서 다시 설정되는지, 그리고
`boss_paddle_width` / `ball_size` 가 공 경로 컨텍스트에 실제로 실려 있는지
둘 다 찍어 보라. 0 이면 중심 계산이 왼쪽 모서리 기준이 되어 같은 증상이 난다.

- 원인을 확정한 뒤 고쳐라. **공식을 바꾸지 마라.** 원본과 이미 같다.
- ★**형제 스킬을 깨뜨리지 마라.** 같은 핸들러가 스테이지1·3·4 를 함께 탄다.

### 1-2. 회전발톱 사운드

원본은 이렇다. `pingfighter.py:80856`

```python
play_cached_sound("sounds/clue.wav", 0.5)
```

Godot 은 `_play_audio(deps, "play_stage2_molewang_spinning_claw")` 를 부른다.
★**그 메서드가 실제로 존재하고 소리를 내는지 확인하라.** 덕타이핑 동적
호출이라 없는 메서드는 조용히 무시된다(GRT-048).

- 원본 볼륨 0.5 를 지켜라.
- ★**루프 오디오가 아니면 정리 훅은 불필요하다.** 원본이 원샷이다.
- 자산이 없으면 후보를 제시하고 멈춰라. 임의 대체음을 넣지 마라.

### 1-3. 친구 두더지 개편 ★사용자 확정 사양

**해금은 지금 그대로다.** `stage2_molewang_boss_state.gd:151`

```gdscript
if scoring_side == "player" and int(score_result.get("player_score", 0)) == 4 and not friend_moles_triggered:
	friend_moles_pending = true
```

★**4점 해금은 이미 구현돼 있다. 바꾸지 마라.**

바꿀 것은 지속 구조다.

| 항목 | 현행 | 개정 |
|---|---|---|
| 해금 | 플레이어 4점 | **유지** |
| 지속 | 2라운드 내내 상시 | ★**발동 시 10초** |
| 재발동 | 없음 | ★**쿨타임 40초** |

- ★**시계는 물리 틱이다.** `_process` delta 누적이나 벽시계를 쓰지 마라.
  10초와 40초의 물리 틱 환산값을 보고서에 적어라.
- 해금 전에는 발동하지 않는다.
- 쿨타임 중에는 발동하지 않는다.
- ★**라운드 리셋·득점·서브 대기에서 상태가 어떻게 되는지 정하고 근거를
  적어라.** 원본은 상시라 이 경계가 없었다. 새 사양이므로 판단이 필요하다.
- ★**detached FX/오디오 호스트가 있으면 10초 종료 시 정리하라.** 논리적
  가시성이 false 가 되는 것만으로는 부족하다.

## 2. 씰

- **방향**: 공이 보스 중심보다 왼쪽일 때와 오른쪽일 때를 각각 태우고
  ★**최종 ball_spin_direction 이 서로 반대인지** 단언하라. 상태 내부 값이
  아니라 **소비된 결과**를 봐라. 이것이 이 목표의 핵심 씰이다.
- **사운드**: 발동 시 오디오 메서드가 실제로 호출되는지 단언하라.
  ⚠ `has_method` 게이트가 조용히 삼키지 않는지 확인하라.
- **친구 두더지**: 4점 미만 미발동 / 4점 발동 / 10초 후 종료 /
  40초 전 재발동 불가 / 40초 후 재발동 가능. 다섯 레그 전부.
- ★**땅굴습격 무손상** 부정 레그를 둬라. 게이지 500 게이트가 살아 있어야 한다.
- 형제 스테이지 무손상 부정 레그를 둬라.

## 3. 규율

- 슬라이스마다 헝크 분리 커밋 1개. 단독으로 씰 GREEN.
- 신규·개정 씰은 두 리터럴 목록에 동시 등재. 현재 190개다.
- ⚠ 씰 레그를 추가하면 `_leg_count` 류 상수를 함께 갱신하라.
- ⚠ `paddle_bounce_boss_post_hit_handler.gd` 는 전 스테이지 공용이다.
- 내부 식별자와 저장 키는 호환 식별자다. 바꾸지 마라.
- 통과 판정은 배치 종단선 `All Godot smoke tests passed.` + `SCRIPT ERROR` 0건.
- 로그 백업 선행. 표준 래퍼 `-AllowDuringPlay`. 푸시 금지.

## 4. 검증

- 슬라이스별 씰 + `-Paths` 경고 + 헤드리스 + `git diff --check`.
- **Vulkan 캡처**: 좌·우 각각의 회전발톱, 친구 두더지 발동과 종료.
- 사운드는 캡처로 판정할 수 없다. **호출 경로 단언 + 사용자 청취**로 나눠라.
- **라이브 확인은 사용자가 본 트리에서 한다.** unverified 로 명시하라.

**완료 선언 조건**: 1-1 원인 확정 + 1-1~1-3 구현·검증 + 땅굴습격 무손상 +
게이트 blocked 0건 + 보고서 완성.
