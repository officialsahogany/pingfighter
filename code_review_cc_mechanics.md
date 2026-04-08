# PingFighter CC(군중제어) 메카닉 코드리뷰 문서

> **작성일**: 2026-04-09  
> **대상**: 스턴(Stun), 넉백(Knockback), 둔화(Slow) 시스템 전체  
> **목적**: 코덱스 코드리뷰용 시스템 문서화

---

## 목차
1. [시스템 개요](#1-시스템-개요)
2. [스턴 (Stun)](#2-스턴-stun)
3. [넉백 (Knockback)](#3-넉백-knockback)
4. [둔화 (Slow)](#4-둔화-slow)
5. [CC 저항 & 면역 시스템](#5-cc-저항--면역-시스템)
6. [코드리뷰 포인트](#6-코드리뷰-포인트)

---

## 1. 시스템 개요

### CC 타입 요약

| CC 타입 | 효과 | 입력 차단 | 이동 가능 | 중첩 가능 |
|---------|------|----------|----------|----------|
| **스턴** | 행동 불가 + 넉백 드리프트만 허용 | ✅ 완전 차단 | ❌ (넉백만) | ❌ (max 덮어쓰기) |
| **넉백 (스턴형)** | 강제 밀림 + 행동 불가 | ✅ 완전 차단 | 넉백 방향만 | ❌ |
| **넉백 (화재형)** | 강제 밀림 + 조작 가능 | ❌ | ✅ 동시 이동 가능 | ✅ 누적 |
| **둔화** | 이동속도 감소 | ❌ | ✅ (느리게) | 부분적 (아래 4.3 참조) |

### CC 처리 흐름
```
[CC 소스 발생] → [면역 체크 (cleanse)] → [저항 적용 (resist %)] → [타이머/속도 설정] → [매 프레임 감쇠/업데이트] → [시각 효과]
```

---

## 2. 스턴 (Stun)

### 2.1 핵심 변수

#### 플레이어 스턴
| 변수 | 파일:라인 | 용도 |
|------|----------|------|
| `player_stunned_timer` | pingfighter.py:29157 | 메인 스턴 타이머 (프레임 단위) |
| `player_missile_stunned_timer` | pingfighter.py:27093 | 미사일 폭발 전용 스턴 |
| `rolling_stun_timer` | core/player_state.py:73-78 | 대시 후 경직 (바이퍼 전용) |
| `smasher_power_recoil_stun_pending` | pingfighter.py:29148 | 스매셔 반동 스턴 대기 플래그 |

#### 보스 스턴
| 변수 | 파일:라인 | 용도 | 런타임 사용 |
|------|----------|------|------------|
| `boss_stunned_timer` | pingfighter.py:146822 | 메인 보스 스턴 타이머 (전역) | ✅ **실제 경로** (14개소에서 직접 할당) |
| `Boss.is_stunned` / `Boss.stun_timer` | entities/boss.py:98-99 | 엔티티 클래스 스턴 | ❌ **미사용** (Boss.stun() 호출 없음) |

#### 아레나 스턴
| 변수 | 파일:라인 | 용도 |
|------|----------|------|
| `arena_top_dash_stun_timer` | pingfighter.py:24806 | 보스 대시 후 경직 (30프레임) |
| `arena_bottom_dash_stun_timer` | pingfighter.py:24837 | 플레이어 대시 후 경직 |
| `_judgment_lightning_stun_top_timer` | pingfighter.py:67076 | 스테이지30 번개 스턴 (2초) |

### 2.2 스턴 적용 함수

```python
# pingfighter.py:29151-29176
def try_apply_player_stun(stun_seconds, source="", knockback_scaled=False):
    """플레이어 스턴 적용 (저항/면역 자동 처리)"""
    global player_stunned_timer
    
    # 1) 클렌즈 면역 체크
    if is_cleanse_immune():
        return 0.0
    
    # 2) 스턴 저항 적용 (방탄모자)
    resist_pct = get_player_stun_resist_pct()  # 0~100
    actual_seconds = stun_seconds * (1.0 - resist_pct / 100.0)
    
    # 3) 넉백 스케일 추가 적용 (선택적)
    if knockback_scaled:
        actual_seconds *= _get_knockback_resist_scale()
    
    # 4) 프레임 변환 후 max 덮어쓰기
    stun_frames = int(actual_seconds * FPS)
    player_stunned_timer = max(player_stunned_timer, stun_frames)
    return actual_seconds
```

#### 보스 스턴 적용

> **주의**: `entities/boss.py`에 `Boss.stun(duration)` 메서드가 정의되어 있으나,
> 실제 게임 런타임에서는 **한 번도 호출되지 않는다** (grep 확인 완료).
> 보스 스턴은 전부 `pingfighter.py`의 전역 변수 직접 할당으로 처리된다.

```python
# 실제 런타임 경로 (pingfighter.py, 14개소 이상에서 직접 할당)
boss_stunned_timer = max(boss_stunned_timer, int(stun_duration * 60))

# 예시 호출 위치:
# L22227 - 슬링샷 총알 히트
# L22240 - 딸기 폭탄 히트
# L22536 - 뿔돌진 스킬
# L31548 - 수류탄 폭발
# L56912 - 자폭 드론
# L72543 - 헤드샷
# L72693 - AK47
```

### 2.3 스턴의 게임플레이 영향

#### 플레이어 스턴 시
```python
# pingfighter.py:77668-77713
if player_stunned_timer > 0:
    player_stunned_timer -= 1
    # 넉백 드리프트만 허용 (입력 완전 차단)
    if abs(player_knockback_vel) > 0.5:
        PLAYER.x += int(player_knockback_vel)
        PLAYER.x = max(0, min(WIDTH - PLAYER.width, PLAYER.x))
    # 감쇠 (뿔돌진: 0.92, 일반: 0.85)
    if horn_charge_player_knockback_active:
        player_knockback_vel *= 0.92
    else:
        player_knockback_vel *= 0.85 * _get_knockback_resist_scale()
    return  # ← handle_player 함수 조기 종료 (모든 입력 차단)
```

#### 보스 스턴 시 (실제 런타임 경로)
```python
# pingfighter.py:153864-153886 (handle_boss 내부)
if boss_stunned_timer > 0:
    boss_stunned_timer -= 1
    # 넉백 적용 (스턴 중에도 밀림은 처리)
    BOSS.x += boss_knockback_vel
    # 벽 충돌 시 멈춤 (튕기지 않음)
    if BOSS.x <= 0:
        BOSS.x = 0; boss_knockback_vel = 0
    elif BOSS.x >= WIDTH - BOSS.width:
        BOSS.x = WIDTH - BOSS.width; boss_knockback_vel = 0
    # 감쇠 (뿔돌진: 0.92, 일반: 0.85)
    if horn_charge_boss_knockback_active:
        boss_knockback_vel *= 0.92
    else:
        boss_knockback_vel *= 0.85
    return  # ← AI 전체 비활성화
```

#### 대시 차단
```python
# pingfighter.py:79716-79717
_player_stun_blocked = (
    player_stunned_timer > 0 or 
    player_stunned or 
    player_missile_stunned_timer > 0
)
# _player_stun_blocked == True → 대시 시작 불가
```

### 2.4 스턴 지속시간 상수

| 소스 | 지속시간 | 파일:라인 |
|------|---------|----------|
| 대시 경직 (아레나) | 0.5초 (30프레임) | pingfighter.py:24841 |
| 대장간 터렛 일반 | 0.1초 (6프레임) | pingfighter.py:51182 |
| 대장간 터렛 유도 | 0.4초 (24프레임) | pingfighter.py:51199 |
| AK47 | 0.1초 (6프레임) | pingfighter.py:55265 |
| 스테이지8 초고속대시 | ~0.03초 (1.8프레임) | pingfighter.py:50292 |
| 뿔돌진 딸기폭탄 | 0.75초 (45프레임) | item_effects/horn_strawberry_mask.py:2387 |
| 번개 심판 (스테이지30) | 2.0초 | pingfighter.py:67334 |
| 폭탄 서프라이즈 (아레나) | 1.5초 (90프레임) | game_mechanics/ingame_bodyguard.py:700 |

### 2.5 스턴 소스 목록

`try_apply_player_stun()`의 `source` 파라미터로 추적 (11개 유니크 소스, 12개 호출):

| 소스 | 지속시간 | knockback_scaled | 비고 |
|------|---------|-----------------|------|
| `"missile_explosion"` | 0.3초 | ✅ | 미사일 폭발 |
| `"땅굴 습격"` | 1.0초 | ✅ | 땅굴 습격 |
| `"optimus_charge_release"` | 0.5초 | ❌ | 옵티머스 차지 해제 |
| `"smasher_power_recoil"` | 0.5초 | ❌ | 스매셔 반동 (**아래 주의** 참조) |
| `"stage1_fan_throw"` | 0.3초 | ✅ | 스테이지1 부채 투척 (2개소) |
| `"stage7_tetro_explosion"` | 가변 | ✅ | 테트로미노 폭발 |
| `"hail"` | 가변 | ✅ | 우박 날씨 이벤트 |
| `"stage5_missile"` | 0.15초 | ✅ | 스테이지5 미사일 |
| `"stage5_fireball"` | 0.3초 | ✅ | 스테이지5 화염구 |
| `"flame_trail"` | 0.3초 | ✅ | 화염 자취 |
| `"tear_shower"` | 0.3초 | ✅ | 눈물 샤워 |

> **BUG: smasher_power_recoil 경로가 중앙 스턴 계약을 우회함**
> ```python
> # pingfighter.py:81185-81187
> if try_apply_player_stun(0.5, source="smasher_power_recoil", knockback_scaled=False) == 0:
>     player_stunned_timer = max(player_stunned_timer, int(0.5 * FPS))  # ← 면역 무시!
> ```
> `try_apply_player_stun()`이 클렌즈 면역이나 저항으로 0을 반환하면,
> 호출측이 그 0을 "실패"로 간주해 `player_stunned_timer`를 직접 강제 설정한다.
> 이로 인해 클렌즈 면역 중에도 스매셔 반동 스턴이 적용됨.

### 2.6 스턴 시각 효과

#### 보스 스턴 - 별 회전
```python
# pingfighter.py:113523-113561
if boss_stunned_timer > 0:
    # 3개 노란 별이 보스 머리 위에서 회전
    rotation_angle = (pygame.time.get_ticks() * 0.36) % 360  # 360°/초
    star_color = (255, 255, 100)  # 노란색
    outline_color = (255, 200, 0)
    # 반투명 노란 글로우 원 포함
    position_y = BOSS.top - 15  # 보스 머리 위 15px
```

#### 플레이어 롤링 경직 - 전기 스파크
```python
# pingfighter.py:106130-106167
if rolling_stun_timer > 0:
    # 어두운 보라/마젠타 오버레이 + 펄싱 애니메이션
    # 6개 지그재그 번개 볼트 방사
    # 사인파 변조 스파크 (0.4 rad/s, 0.025 rad/s)
```

---

## 3. 넉백 (Knockback)

### 3.1 넉백 타입 분류

| 타입 | 변수 | 조작 가능 | 감쇠율 | 벽 반사 |
|------|------|----------|--------|---------|
| **스턴 넉백** | `player_knockback_vel` | ❌ | 0.85/프레임 | ❌ 클램프 |
| **화재 넉백** | `player_fire_knockback_vel` | ✅ | 0.85 (빙결:0.94) | ✅ 30% 손실 |
| **미사일 넉백** | `player_missile_knockback_vel` | ❌ | 0.85/프레임 | ❌ 클램프 |
| **보스 스턴 넉백** | `boss_knockback_vel` | ❌ (AI 비활성) | - | - |
| **보스 화재 넉백** | `boss_fire_knockback_vel` | ✅ (AI 동작) | 0.85 (빙결:0.94) | ✅ 30% 손실 |

### 3.2 핵심 변수

#### 플레이어 넉백
| 변수 | 파일:라인 | 용도 |
|------|----------|------|
| `player_knockback_vel` | pingfighter.py:146864 | 스턴 상태 좌우 밀림 속도 |
| `player_fire_knockback_vel` | pingfighter.py:146844 | 화재/패들 히트 넉백 (조작 가능) |
| `player_missile_knockback_vel` | pingfighter.py:27811 | 스테이지6 미사일 넉백 |
| `player_flame_zone_knockback_vel` | pingfighter.py | 화염 지대 넉백 |
| `player_knockback_y` | pingfighter.py:146870 | Y축 넉백 (화상용) |

#### 보스 넉백
| 변수 | 파일:라인 | 용도 |
|------|----------|------|
| `boss_knockback_vel` | pingfighter.py:146873 | 좌우 밀림 속도 |
| `boss_fire_knockback_vel` | pingfighter.py:146845 | 화재 넉백 |
| `boss_knockback_timer` | pingfighter.py:146882 | 넉백 지속 프레임 |
| `boss_knockback_active` | pingfighter.py:59193 | 패들 히트 넉백 활성 플래그 |
| `boss_knockback_offset_x/y` | pingfighter.py:59194-59195 | 시각적 오프셋 |

### 3.3 넉백 스케일링 시스템

```python
# 전역 넉백 스케일링
GAME_KNOCKBACK_DISTANCE_REDUCTION = 1.0  # pingfighter.py:51825

def _scale_knockback(value: float) -> float:
    """전역 넉백 거리 스케일링"""
    return value * GAME_KNOCKBACK_DISTANCE_REDUCTION

def _apply_boss_knockback_velocity(raw_velocity: float) -> float:
    """보스에 스케일링된 넉백 적용"""
    global boss_knockback_vel
    boss_knockback_vel = _scale_knockback(raw_velocity)
    return boss_knockback_vel
```

### 3.4 패들 히트 넉백 (인텐시티 연동)

```python
# pingfighter.py:48948-48959
PADDLE_HIT_KNOCKBACK_BASE = 2.4  # 화재 넉백(12)의 20%

PADDLE_HIT_KNOCKBACK_INTENSITY_SCALE = {
    0: 1.5,   # 파랑 (150%) → 3.6
    1: 2.2,   # 시안 (220%) → 5.28
    2: 2.8,   # 초록 (280%) → 6.72
    3: 3.6,   # 노랑 (360%) → 8.64
    4: 3.6,   # 주황 (360%) → 8.64
    5: 5.5,   # 빨강 (550%) → 13.2
}
```

#### 패들 넉백 방향 결정
```python
# pingfighter.py:48972-49003
def apply_paddle_hit_knockback_player(ball_x=None):
    knockback_strength = get_paddle_hit_knockback_strength()
    # 공이 패들 중심 오른쪽 → 왼쪽으로 밀림 (반대 방향)
    if ball_x > paddle_center:
        knockback_dir = -1
    else:
        knockback_dir = 1
    raw_knockback = knockback_dir * knockback_strength
    player_fire_knockback_vel = apply_knockback_resist(_scale_knockback(raw_knockback))
```

### 3.5 화재 넉백 처리 (벽 반사 포함)

```python
# pingfighter.py:77717-77743 (플레이어)
if abs(player_fire_knockback_vel) > 0.3:
    new_x = PLAYER.x + player_fire_knockback_vel
    
    # 벽 반사 (30% 에너지 손실)
    if new_x <= 0:
        PLAYER.x = 0
        player_fire_knockback_vel = abs(player_fire_knockback_vel) * 0.7
    elif new_x >= WIDTH - PLAYER.width:
        PLAYER.x = WIDTH - PLAYER.width
        player_fire_knockback_vel = -abs(player_fire_knockback_vel) * 0.7
    else:
        PLAYER.x = new_x
    
    # 감쇠 (빙결: 6% 감쇠, 일반: 15% 감쇠)
    ice_decay = 0.94 if is_ice_active() else 0.85
    player_fire_knockback_vel *= ice_decay * _get_knockback_resist_scale()
    if abs(player_fire_knockback_vel) <= 0.3:
        player_fire_knockback_vel = 0.0
```

### 3.6 무기별 넉백 수치

| 소스 | 기본 파워 | 넉백 지속 | 특이사항 |
|------|----------|----------|---------|
| 군인 총알 (커맨도) | 14 | 18프레임 (0.3초) | 보스 위치 기반 방향 |
| 슬링샷 Lv1 | 9.8 (14×0.7) | 18프레임 | - |
| 슬링샷 Lv2 | 14 (14×1.0) | 18프레임 | - |
| 슬링샷 Lv3 | 21 (14×1.5) | 24프레임 (0.4초) | 지속시간 증가 |
| 파편갑옷 Lv1~4 | 8→12→16→20 | - | 레벨별 선형 증가 |
| 파편갑옷 Lv5+ | 19.2+(n-4)×4.8 | - | Lv5=24, Lv6=28.8 |
| 대장간 균열 | 7.2 + 세그먼트×1.6 | 5+n프레임 | 즉시 밀기 16.0 추가 |
| 테트로미노 폭발 | 12.0 | - | STAGE7_TETRO_EXPLOSION_KNOCKBACK |
| 라그나로크 해머 | base_power + ball_speed × weight | - | 공 속도 비례 |
| 패들 히트 (빨강) | 13.2 | 자연 감쇠 | 화재 넉백 타입 |

### 3.7 보스 패들 히트 넉백 (시각적 오프셋)

```python
# pingfighter.py:59197-59200
BOSS_KNOCKBACK_DURATION = 18   # 0.3초
BOSS_KNOCKBACK_STRENGTH = 2    # 2px/프레임 = 총 36px
BOSS_KNOCKBACK_DECAY = 0.8     # 감쇠율 (미사용)

# 트리거 (pingfighter.py:72257-72296)
def trigger_boss_knockback(bullet_x, bullet_y):
    """보스 패들 시각적 넉백 (물리 이동 아님, 오프셋만)"""
    boss_knockback_active = True
    boss_knockback_timer = BOSS_KNOCKBACK_DURATION
    # 맞은 방향 반대로 오프셋
    boss_knockback_offset_x = _scale_knockback(direction * BOSS_KNOCKBACK_STRENGTH)
```

### 3.8 넉백 디버그 시스템

```python
# 환경변수로 활성화: PINGF_DEBUG_KNOCKBACK=1
_KB_DEBUG = os.environ.get("PINGF_DEBUG_KNOCKBACK", "0").lower() in ("1","true","yes","on","debug")

def _kb_debug(msg: str):
    if _KB_DEBUG:
        print(f"[KBDBG] {msg}")
```

---

## 4. 둔화 (Slow)

### 4.1 플레이어 둔화 소스

#### A. 눈물 샤워 (멘헤라걸, 스테이지3)
```python
# pingfighter.py:59985-59990
PLAYER_SLOW_DEFAULT_FACTOR = 0.5
PLAYER_SLOW_STACK_AMOUNT = 0.20      # 눈물 1방울당 20% 감속 누적
PLAYER_SLOW_STACK_MAX = 0.80         # 최대 80% 감속
player_slow_timer = 0                # 디버프 지속시간 (프레임)
player_slow_factor = 1.0             # 1.0=정상, 0.2=최대 감속
```
- **트리거**: 눈물 피격 시 `player_slow_timer = 130` (2초), `player_slow_factor -= 0.20`
- **누적**: 매 피격 시 20%씩 추가 감속 (최대 80%)
- **리셋**: 라운드 전환 시

#### B. 자기장 투사체 (스테이지4)
```python
# pingfighter.py:61467
magnetic_projectile_slow_amount = 0.4  # 60% 속도 감소
# 적용: current_speed *= 0.4
```

#### C. 거미줄 함정 (아라크네)
```python
# pingfighter.py:32085-32095
WEB_TRAP_DURATION = 300          # 5초
WEB_TRAP_RADIUS = 50             # 반경 50px
WEB_TRAP_PLAYER_SLOW = 0.40      # 60% 감속
```

#### D. 그물덫총 (군인)
```python
# item_effects/net_gun.py
self.player_slow_factor = 0.7    # 30% 감속
```

#### E. 코만도 물자보급 홀드
```python
# pingfighter.py:77836-77857
speed_factor *= 0.6              # 40% 감속
```

#### F. 대장간 우산 페널티
```python
# pingfighter.py:77867-77873
if umbrella_guarding:
    speed_factor *= BLACKSMITH_UMBRELLA_MOVE_MULTIPLIER
```

#### G. 포도대장 포승줄
```python
# pingfighter.py:77832-77834
if arrest_rope_active:
    speed_factor *= 0.5          # 50% 감속
```

#### H. 솜사탕 폭탄 (테디베어)
```python
# pingfighter.py:53127-53135
COTTON_BOMB_PLAYER_SLOW_DURATION = 120   # 2초
COTTON_BOMB_SLOW_MULTIPLIER = 0.5        # 50% 감속
```

### 4.2 보스 둔화 소스

#### A. 거미지뢰 (Spider Mine)
```python
# pingfighter.py:31963-31973
SPIDER_MINE_SLOW_DURATION = 180      # 3초
SPIDER_MINE_SLOW_FACTOR = 0.4        # 60% 감속
spider_mine_slow_active = False
spider_mine_slow_timer = 0
```

#### B. 플라즈마 필드
```python
# pingfighter.py:24346-24361
plasma_field_base_slow = 0.20           # 기본 20% 둔화
plasma_field_slow_per_tick = 0.05       # 0.5초 홀딩당 +5%
# 최대 80% 둔화 (min cap)

boss_plasma_slowed = False
boss_plasma_slow_amount = 0.0           # 0.0 ~ 0.80
boss_plasma_slow_timer = 0

def get_boss_plasma_slow_multiplier():
    if boss_plasma_slowed:
        return 1.0 - boss_plasma_slow_amount  # 0.2 ~ 1.0
    return 1.0
```

#### C. 딸기 페인트 (뿔딸기)
```python
# pingfighter.py:22302-22305
boss_speed_reduction_factor = 1.0 - 0.30  # 30% 감속
boss_strawberry_paint_slowed = True
```

#### D. 레그샷 (복서)
```python
# pingfighter.py:55294-55297
LEG_SHOT_DURATION = 132              # 2.2초
LEG_SHOT_CHANCE = 0.12               # 12% 확률
LEG_SHOT_SPEED_REDUCTION = 0.7       # 30% 감속
```

#### E. 독안개 장갑 (바이퍼)
```python
# item_effects/venom_mist_gauntlet.py
_mist_radius = 120                   # 반경 120px
_mist_duration_frames = 180          # 3초
_boss_slow_amount = 0.50             # 50% 감속
_gauge_drain_per_sec = 50            # 보스 게이지 추가 감소
```

### 4.3 둔화 적용 메커니즘 (2계층 구조)

플레이어 둔화는 **2계층**으로 작동한다:

#### 계층 1: 공유 슬롯 (`player_slow_timer` / `player_slow_factor`) — 덮어쓰기

눈물 샤워, 자기장 투사체, 스테이지8 표창은 **같은 변수 쌍을 공유**한다.
이들은 독립 스택이 아니라 **마지막 기록값이 이전 값을 덮어쓴다**.

```python
# 눈물 샤워 (L61667): 누적 감산 방식
player_slow_timer = 130
player_slow_factor -= 0.20  # 피격마다 누적 (max 0.80 감속)

# 자기장 투사체 (L147758-147760): 매 프레임 덮어쓰기
player_slow_timer = 10           # ← 눈물의 130을 10으로 덮어씀!
player_slow_factor = 0.4         # ← 눈물 누적값을 0.4로 덮어씀!

# 스테이지8 표창 (L101794-101796): 즉시 덮어쓰기
player_slow_timer = 120          # STAGE8_SHURIKEN_SLOW_FRAMES
player_slow_factor = 0.2         # STAGE8_SHURIKEN_SLOW_FACTOR
```

#### 계층 2: 독립 곱연산 (`speed_factor *=`) — handle_player 내부

포승줄, 거미줄, 우산 등은 `speed_factor`에 곱연산으로 추가 적용된다.
이들은 계층 1과 **독립적으로 중첩**된다.

```python
# pingfighter.py:77810-77873 (handle_player 내부)
# 계층 1: 공유 슬롯에서 초기값 결정
if player_slow_timer > 0:
    speed_factor = player_slow_factor          # 마지막 기록값 (0.2~1.0)
else:
    speed_factor = 1.0
    player_slow_factor = 1.0                   # 타이머 만료 시 리셋

# 계층 2: 독립 소스 곱연산
if arrest_rope_active:
    speed_factor *= 0.5                        # 포승줄 (독립)
if commando_hold_active:
    speed_factor *= 0.6                        # 코만도 홀드 (독립)
web_slow = get_web_trap_player_slow()
if web_slow < 1.0:
    speed_factor *= web_slow                   # 거미줄 (독립)
if umbrella_guarding:
    speed_factor *= BLACKSMITH_UMBRELLA_MOVE_MULTIPLIER  # 우산 (독립)
```

**핵심 정리**:
- 계층 1 (눈물/자기장/표창): **단일 슬롯 덮어쓰기** — 동시에 2개가 걸리면 마지막이 이김
- 계층 2 (포승줄/거미줄/우산/홀드): **곱연산 누적** — 이들끼리는 독립 중첩
- 계층 1 + 계층 2: 곱연산 — 예: 표창(0.2) × 거미줄(0.4) = 0.08 (92% 감속)
- **하한선 없음** — 이론상 이동 불가 수준까지 감속 가능

### 4.4 둔화 시각 효과

#### 슬로우 웨이브 서피스 (공통)
```python
# pingfighter.py:72847-72893
def create_slow_wave_surface(width, height, base_color=(170,120,255), intensity=1.0):
    """물결 형태의 둔화 이펙트 생성"""
    # wave_count: 1~3개 웨이브
    # 반투명 물결 오버레이
```

| 둔화 소스 | 이펙트 색상 | 파일:라인 |
|-----------|-----------|----------|
| 거미지뢰 | (110, 170, 255) 파랑 | pingfighter.py:63001 |
| 레그샷 | (180, 110, 255) 보라 | pingfighter.py:72896 |
| 딸기 페인트 | (255, 100, 140) 핑크 | pingfighter.py:63012 |
| 독안개 | 3레이어 파티클 시스템 | venom_mist_gauntlet.py |

### 4.5 시간 둔화 (전설 아이템)

```python
# legendary_items.py:745-779 (ChronoAmulet)
self.time_slow_duration = 3000      # 3초
self.time_slow_cooldown = 30000     # 30초
self.time_scale = 0.3               # 전체 게임 속도 30%로 (70% 감소)
# → 모든 게임 엔티티에 동시 적용
```

---

## 5. CC 저항 & 면역 시스템

### 5.1 클렌즈 (완전 면역)

```python
# item_effects/cleanse_skill.py
CLEANSE_GAUGE_COST = 100
CLEANSE_COOLDOWN = 60               # 1초
CLEANSE_IMMUNITY_DURATION = 300     # 5초 면역
```

> **주의: 디버프 판정 함수가 2개 존재하며 범위가 다름**

#### A. `_check_player_has_debuff()` (pingfighter.py:3966-3991) — UI 표시용
```python
def _check_player_has_debuff() -> bool:
    """스킬 아이콘 활성 상태 표시용"""
    # 체크 대상: 스턴, 둔화, 화상
    # ❌ 넉백 명시적 제외 (L3988: "짧은 물리 효과이므로")
    if player_stunned_timer > 0: return True
    if player_slow_timer > 0: return True
    if spider_mine_slow_active: return True
    if player_burn_timer > 0: return True
    return False
```
- **사용처**: 클렌즈 스킬 아이콘 활성 표시 (L5135, L5249)

#### B. `check_player_has_status_effect()` (cleanse_skill.py:530-568) — 실제 발동 판정
```python
def check_player_has_status_effect(
    player_stunned_timer, player_knockback_vel, 
    player_missile_knockback_vel, smasher_power_recoil_timer, ...
) -> bool:
    """W키 클렌즈 실제 발동 가능 여부"""
    # 체크 대상: 스턴 + 둔화 + 화상 + ✅ 넉백 + ✅ 리코일
    if abs(player_knockback_vel) > 0.5: return True      # ← 넉백 포함!
    if abs(player_missile_knockback_vel) > 0.5: return True
    if smasher_power_recoil_timer > 0: return True        # ← 리코일 포함!
    # ...
```
- **사용처**: W키 클렌즈 실제 발동 경로 (L164790-164802)

**불일치 결과**: UI가 클렌즈 비활성으로 표시하지만 실제로는 발동 가능한 상태가 존재함 (넉백만 걸린 경우).

### 5.2 스턴 저항 (방탄모자)

```python
# pingfighter.py:29087-29092
def get_player_stun_resist_pct():
    """스턴 저항률 (0~100%)"""
    return max(0.0, min(100.0, float(bulletproof_hat_resist_pct)))

# 롤 옵션: stun_resist_pct (min 10%, max 20%)
```

### 5.3 넉백 저항 (스파이크 헬멧)

```python
# pingfighter.py:29095-29130
def get_player_knockback_resist_pct():
    """넉백 저항률 (0~100%)"""
    return max(0.0, min(100.0, float(spiked_helmet_knockback_resist_pct)))

def _get_knockback_resist_scale():
    """넉백 저항 → 스케일 팩터 (0~1)"""
    return max(0.0, 1.0 - get_player_knockback_resist_pct() / 100.0)

def apply_knockback_resist(value):
    """넉백 속도에 저항 적용"""
    if is_cleanse_immune():
        return 0.0
    return value * _get_knockback_resist_scale()

def clear_player_knockback_if_immune():
    """100% 저항 시 남은 넉백 전부 제거"""
    if _get_knockback_resist_scale() <= 0.0:
        global player_knockback_vel, player_missile_knockback_vel
        global player_flame_zone_knockback_vel, player_knockback_y
        global smasher_power_recoil_timer, smasher_power_recoil_vel
        player_knockback_vel = 0
        player_missile_knockback_vel = 0
        player_flame_zone_knockback_vel = 0
        player_knockback_y = 0
        smasher_power_recoil_timer = 0
        smasher_power_recoil_vel = 0.0
        smasher_power_recoil_pending_dir = 0      # ⚠️ BUG: global 선언 누락
        smasher_power_recoil_stun_pending = False  # ⚠️ BUG: global 선언 누락
```

> **BUG (pingfighter.py:29097-29098)**: `smasher_power_recoil_pending_dir`와
> `smasher_power_recoil_stun_pending`에 `global` 선언이 없어 지역 변수로 처리됨.
> 전역 pending 상태가 정리되지 않으므로 100% 넉백 저항 시에도
> 스매셔 반동 스턴이 계속 대기 상태로 남는다.

### 5.4 저항 아이템 롤 옵션

| 아이템 | 옵션 키 | 범위 | 효과 |
|--------|---------|------|------|
| 방탄모자 | `stun_resist_pct` | 10~20% | 스턴 지속시간 감소 |
| 스파이크 헬멧 | `knockback_resist_pct` | 10~20% | 넉백 거리/속도 감소 |

### 5.5 바이퍼 홀로그램 면역

```python
# pingfighter.py:49003
if _viper_ss_hologram_active:
    return  # 패들 히트 넉백 면역
```

---

## 6. 코드리뷰 포인트

### 6.1 아키텍처 이슈

1. **전역 변수 과다**: 스턴/넉백/둔화 모두 전역 변수로 관리 (`player_stunned_timer`, `boss_knockback_vel` 등). 상태 객체로 캡슐화하면 초기화 누락 버그 예방 가능.

2. **중복 스턴 변수**: `boss_stunned_timer`(pingfighter.py:22221)와 `boss_stun_timer`(pingfighter.py:154285), `Boss.stun_timer`(entities/boss.py) 3개가 별도 존재. 동기화 실수 위험.

3. **넉백 타입이 변수명으로만 구분**: `player_knockback_vel` vs `player_fire_knockback_vel` vs `player_missile_knockback_vel`이 각각 다른 동작(조작 차단/허용, 감쇠율 등)을 하지만 명시적 타입 없이 변수명으로만 구분.

### 6.2 일관성 이슈

4. **감쇠율 불일치**: 뿔돌진 넉백은 0.92, 일반 넉백은 0.85, 빙결 시 0.94 등 매직넘버가 코드 곳곳에 하드코딩. 상수화 필요.

5. **둔화 적용 방식 혼재**: 일부는 `player_slow_factor` 직접 수정, 일부는 `speed_factor *=`로 곱연산. 둔화 스택이 어디서 어떻게 적용되는지 추적 어려움.

6. **스턴 적용 경로 불일치**: 플레이어 스턴은 `try_apply_player_stun()`으로 중앙화되어 있으나, 보스 스턴은 `boss_stunned_timer = max(...)` 직접 할당이 곳곳에 산재.

### 6.3 확인된 버그 (코드 검증 완료)

7. **[높음] smasher_power_recoil 스턴 면역 우회** (pingfighter.py:81185-81187): `try_apply_player_stun()`이 0을 반환하면 (면역/저항), 호출측이 `player_stunned_timer`를 직접 강제 설정하여 클렌즈 면역을 무시한다. 중앙 스턴 함수의 계약을 깨는 버그.

8. **[높음] 클렌즈 디버프 판정 불일치**: UI용 `_check_player_has_debuff()`는 넉백을 제외하지만, 발동용 `check_player_has_status_effect()`는 넉백을 포함. 넉백만 걸렸을 때 UI는 비활성이지만 실제 W키 발동은 가능한 상태가 됨.

9. **[중간] clear_player_knockback_if_immune() global 누락** (pingfighter.py:29097-29098): `smasher_power_recoil_pending_dir`와 `smasher_power_recoil_stun_pending`에 global 선언이 없어 지역 변수로 처리됨. 100% 넉백 저항 시에도 pending 상태가 남아 반동 스턴이 트리거될 수 있음.

### 6.4 잠재적 이슈

10. **넉백 + 스턴 동시 적용 시**: `player_stunned_timer > 0`이면 `return`으로 즉시 종료하므로, 화재 넉백(`player_fire_knockback_vel`)이 스턴 중에는 처리 안 됨. 스턴 해제 후 잔여 화재 넉백이 갑자기 적용될 수 있음.

11. **둔화 최소값 미보장**: 계층1(0.2) × 거미줄(0.4) × 포승줄(0.5) = 0.04 (96% 감속). 이동 불가에 가까운 상태가 될 수 있으나, 하한선이 없음.

12. **보스 스턴 해제 시 속도 복원**: 스턴 중 `return`으로 AI를 건너뛰다가, 해제 후 다음 프레임에서 AI가 속도를 재계산하는 것에 의존. 명시적 복원 코드 없음.

### 6.5 개선 제안

13. **CC 상태 매니저 도입**: 
```python
class CCState:
    def __init__(self):
        self.stun_timer = 0
        self.knockback = KnockbackState()
        self.slow_factors = {}  # source → factor
    
    @property
    def effective_slow(self):
        result = 1.0
        for factor in self.slow_factors.values():
            result *= factor
        return max(0.1, result)  # 최소 10% 속도 보장
```

14. **넉백 프로파일 통합**: `legendary_items.py`의 `KNOCKBACK_PROFILES`와 `compute_knockback_magnitude()` 패턴을 전체 넉백 시스템에 확장 적용.

15. **CC 이벤트 로깅**: `try_apply_player_stun()`처럼 모든 CC 적용을 중앙 함수를 통해 처리하고, source 추적 + 디버그 로깅 통합.

---

## 부록: CC 관련 파일 인덱스

| 파일 | CC 관련 내용 |
|------|-------------|
| `pingfighter.py` | 스턴/넉백/둔화 핵심 로직 전부 |
| `core/player_state.py` | rolling_stun_timer 프로퍼티 |
| `entities/boss.py` | Boss.stun() 메서드 |
| `item_effects/cleanse_skill.py` | 클렌즈 면역 시스템 |
| `item_effects/horn_strawberry_mask.py` | 뿔돌진 스턴/넉백 |
| `item_effects/shrapnel_armor.py` | 파편갑옷 넉백 |
| `item_effects/bazooka.py` | 바주카 반동 넉백 |
| `item_effects/net_gun.py` | 그물덫총 둔화 |
| `item_effects/venom_mist_gauntlet.py` | 독안개 둔화 |
| `item_effects/dynamite.py` | 다이너마이트 스턴 |
| `item_effects/bowling_trap.py` | 볼링트랩 스턴 |
| `item_effects/boomerang.py` | 부메랑 스턴 |
| `legendary_items.py` | 라그나로크 넉백, 크로노 시간둔화 |
| `events/weather_event.py` | 우박 넉백/스턴, 화재 넉백 |
| `game_mechanics/ingame_bodyguard.py` | 폭탄서프라이즈 스턴 |
| `downtown/hero_skills.py` | 아레나 스킬 스턴 |
