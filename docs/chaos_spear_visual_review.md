# 카오스 스피어 비주얼 / 연출 포팅 참고 문서

현재 제품: Godot **환격전**. 영문 제품명은 미정이며, 아래 옛 이름은
호환성/역사 식별자로만 보존한다.

이 문서는 frozen Python/Pygame PingFighter의 `chaos_spear` 구현을
분석한 레거시 리뷰다. 아래 `pingfighter.py` 라인과 `pygame` 예시는
Godot 포팅을 위한 타이밍 / 상태 / 시각 의도 참고로만 사용한다.
새 구현은 `godot/`의 바이퍼 스킬 owner module, renderer, VFX host,
audio owner, smoke test에 매핑한 뒤 진행한다.

> 대상: 바이퍼 캐릭터 전용 5구슬 스킬 `chaos_spear`
> 원본 참고 파일: `pingfighter.py`
> 검토 범위: 시각 이펙트, 상태머신, 오브젝트 흡수 연출
> (게이지/쿨타임/입력 처리 등 게임 로직은 부가 설명만 포함)

---

## 1. 개요

`chaos_spear`는 바이퍼 캐릭터의 5구슬 액티브 스킬로, 다음 흐름의
시퀀스를 가진다:

1. **윈드업 (startup)**: 머리 위로 창을 들어올리며 보라 전기 차징
2. **투척 (flying)**: 단일 투사체가 화면 중심으로 직선 비행
3. **충돌 (impact)**: 박힘 → 균열 → 폭발 → 블랙홀 잉태 (3페이즈)
4. **블랙홀 (blackhole)**: 3초간 공을 묶고 보스 투사체/설치물을
   나선으로 끌어당겨 파괴
5. **잔광 (fade)**: 페이드아웃 후 idle 복귀

설계 목표:
- 한 자루의 창이 정확히 조준되어 던져진다는 **투사체감**
- 박힌 직후 **균열 → 폭발 → 블랙홀**로 끊김 없이 이어지는 시퀀스
- 흡수되는 오브젝트가 **자기 모습 그대로** 나선 궤적으로 빨려듦
  (별도 카오스 파편으로 대체하지 않음)

---

## 2. 상태머신 & 타이밍

### 상태 전이도

```
idle ──[A→W→D 커맨드 + 게이지/쿨 OK + 지상]──> startup (750ms, 입력잠금)
startup ──[750ms 경과]──> flying (280ms)
flying ──[280ms 경과]──> impact (360ms, 3페이즈)
impact ──[360ms 경과]──> blackhole (3000ms)
blackhole ──[3000ms 경과 OR 공-패들 접촉]──> fade (420ms)
fade ──[420ms 경과]──> idle

특수 분기:
startup ──[공-패들 접촉]──> idle (즉시 해제, fade 생략)
flying ──[공 충돌]──> 무시 (스피어 계속 비행)
```

### 상수 (`pingfighter.py` 5006~5016행)

```python
VIPER_CHAOS_SPEAR_STARTUP_MS = 750   # 윈드업 + 입력 잠금
VIPER_CHAOS_SPEAR_TRAVEL_MS = 280    # 비행 시간
VIPER_CHAOS_SPEAR_IMPACT_MS = 360    # 박힘+폭발+블랙홀잉태
VIPER_CHAOS_SPEAR_BLACKHOLE_MS = 3000  # 블랙홀 지속
VIPER_CHAOS_SPEAR_FADE_MS = 420      # 페이드아웃
VIPER_CHAOS_SPEAR_PULL_RADIUS = 175  # (현재 미사용, 레거시)
VIPER_CHAOS_SPEAR_SPEAR_HIT_RADIUS = 22  # (현재 미사용, 레거시)
VIPER_CHAOS_SPEAR_INGRESS_MS = 520   # blackhole 공 인입 시간
VIPER_CHAOS_SPEAR_VISUAL_LENGTH = 78 # 스피어 길이 (px)
```

### 전역 상태 변수 (`pingfighter.py` 5017~5038행)

```python
_viper_chaos_spear_state = "idle"           # 현재 상태
_viper_chaos_spear_state_start_ms = 0       # 상태 진입 시각
_viper_chaos_spear_origin_x/_y              # 발사 원점
_viper_chaos_spear_target_x/_y              # 명중 좌표
_viper_chaos_spear_current_x/_y             # 현재 스피어 위치 (렌더용)
_viper_chaos_spear_flight_angle = 0.0       # 비행 각도(rad), flying 진입 시 캐시
_viper_chaos_spear_impact_seed = 0.0        # 균열 패턴 시드
_viper_chaos_spear_locked_player_x = None   # 윈드업 동안 패들 X 잠금
_viper_chaos_spear_explosion_shaken = False # 임팩트 2차 셰이크 트리거 여부
_viper_chaos_spear_orbit_seed = 0.0         # 블랙홀 회전 위상
_viper_chaos_spear_base_radius = 52.0       # 블랙홀 공 궤도 반경
_viper_chaos_spear_blackhole_ball_origin    # 블랙홀 시작 시점 공 위치
_viper_chaos_spear_prev_ball_center         # 공 속도 계산용 이전 위치
_viper_chaos_spear_absorb_pulses = []       # 흡수/파괴 플래시 풀
_viper_chaos_spear_cancel_flash = 0         # 캔슬 플래시 카운터
_viper_chaos_spear_last_absorb_ms = 0       # 90ms 주기 흡수용
```

### 메인 업데이트 진입점 (`pingfighter.py` 5983행)

`_update_viper_chaos_spear_runtime()`이 메인 게임 루프에서 매 프레임
호출된다 (호출 위치: 182084행 근처). 함수는:
- 캔슬 플래시 카운터 감소
- 흡수 펄스 lifecycle 갱신 (가속/감쇠/소비 단계 진입)
- 현재 상태에 따라 분기 처리 및 자동 상태 전이

---

## 3. 윈드업 (Startup) 연출

### 게임플레이 효과
- 750ms 동안 패들 좌우 이동 입력 차단
- 공-패들 접촉 시 즉시 해제 (스피어 발사 없음)

### 시각 구성 (`draw_viper_chaos_spear_effect` 의 startup 분기, 6817행 부근)

```python
if _viper_chaos_spear_state == "startup":
    t = elapsed / 750ms

    # === 페이즈 분리 ===
    if t < 0.55:  # rise 페이즈 (0~412ms)
        # 머리 옆에서 위로 들어올리는 보간
        rise = t / 0.55
        ease = 1.0 - (1.0 - rise) ** 2  # ease_out_quad
        anchor_x = px + (1.0 - ease) * 24
        anchor_y = py_top - 16 - ease * 70
    else:  # charge 페이즈 (412~750ms)
        anchor_x = px + sin(t * 0.018) * 3   # 미세 떨림
        anchor_y = py_top - 86 + sin(t * 0.024) * 3

    # === 사전 조준 (창끝이 미리 타겟을 향함) ===
    target_angle = atan2(target_y - anchor_y, target_x - anchor_x)
    if t < 0.55:
        # 위쪽(-π/2) → target_angle 보간 (제곱 이징으로 후반부 정렬)
        aim_t = rise * rise
        spear_angle = (-π/2) * (1 - aim_t) + target_angle * aim_t
    else:
        spear_angle = target_angle + sin(t * 0.022) * 0.025  # 미세 떨림
```

추가 시각 요소:
- **차지 오라**: 패들 주변 3겹 보라 글로우 (반경 34→60px로 확장)
- **에너지 라인**: 발 아래에서 위로 솟는 보라 수직선 5개 (반복 페이즈)
- **차지 스파크 입자**: t > 0.35에서 스피어 끝 주변에 5개 회전 입자
- **스피어 본체**: `_draw_chaos_spear_shape()`로 풀 디테일 렌더
- **전기 스파크 차징**: t > 0.33에서 보라 전기 아크가 스피어 표면에
  누적 (마지막 500ms 동안 0→1로 램프)

### `_draw_chaos_spear_charging_sparks` (`pingfighter.py` 6281행)

```python
def _draw_chaos_spear_charging_sparks(surface, anchor_x, anchor_y,
                                        angle, intensity, time_seed_ms):
    # 50ms 주기로 시드 변경 → 크래클링 효과
    seed = (int(time_seed_ms) // 50) * 17
    num_arcs = int(2 + intensity * 8)  # 2~10개

    for arc_i in range(num_arcs):
        # intensity 낮을 땐 코어(크로스가드 lx=-22) 주변 집중
        # intensity 높으면 스피어 전체 분포
        if intensity < 0.5:
            start_lx = -22 + (rng - 0.5) * 32 * intensity * 2
        else:
            start_lx = -L * rng

        # 3세그먼트 지그재그 번개
        # 외곽 보라 두께3 → 중간 보라 두께2 → 백색 코어 두께1

    # intensity > 0.3에서 크로스가드 위치에 펄스 글로우
```

**리뷰 포인트**:
- 50ms 주기 시드는 60fps 기준 약 3프레임마다 새 패턴이 그려짐 →
  너무 산만하지는 않은지 확인 필요
- intensity가 0.5에서 분포 모드가 갑자기 바뀜 → 부드러운 전환이
  나은지 검토

---

## 4. 비행 (Flying) 연출

### 메커니즘 (`_update_viper_chaos_spear_runtime`, 6075행)

```python
if _viper_chaos_spear_state == "flying":
    travel_t = elapsed / 280ms
    ease_t = 1.0 - ((1.0 - travel_t) ** 3)  # ease_out_cubic
    current_x = origin_x + (target_x - origin_x) * ease_t
    current_y = origin_y + (target_y - origin_y) * ease_t
    # 공 충돌은 무시 (스피어 계속 비행)
    if travel_t >= 1.0:
        → impact 상태 전이
```

비행 각도는 `flying` 진입 직전에 `atan2(dy, dx)`로 한 번만 계산
(`_viper_chaos_spear_flight_angle`).

### 렌더 (`draw_viper_chaos_spear_effect` flying 분기, 6877행 부근)

**설계 결정**: 단일 투사체 + 광선형 모션 블러 (잔상 스피어 다중 렌더 X)

```python
elif _viper_chaos_spear_state == "flying":
    angle = _viper_chaos_spear_flight_angle
    spear_x, spear_y = current_x, current_y

    # 1. 후방 모션블러 스트릭
    # 폼멜에서 origin 방향으로 90px 길이의 광선
    # 4겹 두께(14→8→4→2px) × 6세그먼트 그라데이션
    # 끝쪽으로 알파 1.5승 곡선으로 감쇠
    streak_start_x = spear_x - cos(angle) * VISUAL_LENGTH
    streak_end_x = streak_start_x - cos(angle) * 90

    # 2. 후방 스파크 입자 (공기 가르는 느낌)
    # 시드 기반 무작위 위치 8개

    # 3. 단일 본체 스피어 (회전 매칭)
    _draw_chaos_spear_shape(surface, spear_x, spear_y, angle,
                            alpha=255, glow=True, scale=1.0)
```

**리뷰 포인트**:
- 세그먼트별 임시 surface 할당이 매 프레임 4×6 = 24개 → 280ms 동안만
  발생하므로 실용적, 그러나 surface pool 도입 여지
- 모션블러 길이 90px는 비행 거리(약 350~450px)의 약 20~25%

---

## 5. 충돌 (Impact) 연출 - 3페이즈 핵심

### 메커니즘 (`_update_viper_chaos_spear_runtime`, 6082~6118행)

```python
# flying → impact 전이 시
_viper_chaos_spear_state = "impact"
_viper_chaos_spear_impact_seed = random.uniform(0.0, math.tau)
_viper_chaos_spear_explosion_shaken = False
# 1차 셰이크 (박히는 즉시): timer=14, intensity=18
screen_shake_timer = max(screen_shake_timer, 14)
screen_shake_intensity = max(screen_shake_intensity, 18)
play_cached_sound("sounds/gravityaccel.wav", 0.55 * sfx_volume)

# impact 상태 동안 매 프레임:
if _viper_chaos_spear_state == "impact":
    elapsed_imp = now - state_start
    explosion_threshold_ms = int(360 * 0.45)  # 162ms 시점
    if elapsed_imp >= explosion_threshold_ms and not _explosion_shaken:
        _explosion_shaken = True
        # 2차 강한 셰이크 + 폭발 사운드
        screen_shake_timer = max(screen_shake_timer, 24)
        screen_shake_intensity = max(screen_shake_intensity, 30)
        play_cached_sound("sounds/blackhole.wav", 0.45 * sfx_volume)
    if elapsed_imp >= 360:
        _activate_viper_chaos_blackhole(now)
```

**핵심 설계**: 셰이크가 두 번 발생하여 "박힘 → 떨림 → 폭발" 리듬
형성. 1차는 약하게(18), 2차 폭발 모멘트(45%)에서 강하게(30).

### 렌더 (`_draw_chaos_impact_effect`, 6415행)

총 360ms를 3페이즈로 분할:

#### 페이즈 A: 박힘 + 균열 (0~45%, 0~162ms)

```python
if progress < 0.45:
    a_t = progress / 0.45
    # 진동: 빠르게 부르르 (후반으로 갈수록 격렬)
    vib = sin(progress * 90) * (1.0 + a_t * 5) * 1.6
    spear_x = cx + vib

    # 응축 코어 (스피어 안쪽으로 모이는 에너지)
    core_r = int(6 + a_t * 18)
    # 외곽 보라 응축 → 내부 백색 코어 → 하이라이트

    # 박힌 스피어 (진동 + 글로우)
    _draw_chaos_spear_shape(surface, spear_x, spear_y, angle,
                            alpha=255, glow=True, scale=1.0)
    # 스피어 표면 균열 (intensity = a_t)
    _draw_chaos_spear_cracks(surface, spear_x, spear_y, angle, a_t, seed)

    # 작은 임팩트 링 (1회만, 빠르게 페이드)
```

#### 페이즈 B: 폭발 (45~85%, 162~306ms)

```python
elif progress < 0.85:
    b_t = (progress - 0.45) / 0.4

    # 풀스크린 백색 섬광 (b_t < 0.45 동안)
    flash_alpha = int(240 * (1.0 - b_t / 0.45))

    # 8가닥 방사형 균열 (3세그먼트 톱니)
    # 외곽 흰 글로우 + 어두운 보라 코어

    # 곁가지 균열 (b_t > 0.25)
    # 폭발 링 (확장 + 페이드)
    # 분쇄되는 스피어 (빠르게 페이드 + 균열 절정)
    spear_alpha = int(255 * max(0.0, 1.0 - b_t * 1.6))

    # 폭발 코어 + 9개 사방 파편
```

#### 페이즈 C: 블랙홀 잉태 (85~100%, 306~360ms)

```python
else:
    c_t = (progress - 0.85) / 0.15
    # 폭발 잔여 글로우 (페이드아웃)
    # 잉태된 블랙홀 코어 (점점 커지며 다음 상태로 자연스럽게 이어짐)
    nb_r = int(c_t * 22)
    pygame.draw.circle(surface, (24, 0, 42), (cx, cy), nb_r)
    pygame.draw.circle(surface, (220, 160, 255), (cx, cy), nb_r, 2)
    # 첫 어크리션 호 (회전 시작 암시)
    if nb_r > 8:
        for arc_i in range(3):
            arc_start = c_t * 8 + arc_i * (math.tau / 3)
            pygame.draw.arc(...)
```

### `_draw_chaos_spear_cracks` (`pingfighter.py` 6363행)

스피어 척추를 따라 5개 발생점에서 4방향 톱니 균열 발사:

```python
crack_origins = (
    (-3, 0),    # 칼끝 근처
    (-12, 0),   # 블레이드 중간
    (-22, 0),   # 크로스가드 (가장 큰 충격)
    (-38, 0),   # 샤프트 중간
    (-58, 0),   # 샤프트 후방
)

for ci, (cx_l, cy_l) in enumerate(crack_origins):
    # 각 발생점은 intensity 커질수록 늦게 활성화 (전파 효과)
    local_t = max(0.0, min(1.0, intensity * 1.6 - ci * 0.12))
    # 4방향 톱니 균열 발사
    # 외곽 따뜻한 글로우 (255,220,180) + 어두운 코어 (40,0,60)
```

**리뷰 포인트**:
- 페이즈 C(54ms)는 매우 짧음 → 다음 블랙홀 상태의 growth 0~200ms와
  자연스럽게 이어지는지 확인
- 페이즈 B의 풀스크린 섬광은 다른 보스 이펙트의 가독성을 가릴 수
  있음 (단 145ms 이내라서 짧음)
- 균열 발생점 5개의 시간차 활성화(`local_t = intensity * 1.6 - ci * 0.12`)는
  전파 효과를 의도. 칼끝부터 순차로 퍼짐

---

## 6. 블랙홀 (Blackhole) 연출 - 3초간 카오스 보텍스

### 메커니즘 (`_update_viper_chaos_spear_runtime`, 6125~6166행)

```python
if _viper_chaos_spear_state == "blackhole":
    # 1) 매 프레임: 실제 보스 투사체를 물리적으로 끌어당김
    _viper_chaos_spear_pull_named_lists()

    # 2) 90ms 주기: 상태 기반 보스 이벤트 흡수 (fan_wind, curse_chest 등)
    if now - last_absorb >= 90:
        _absorb_viper_chaos_spear_field_objects(now)
        last_absorb = now

    # 3) 공을 궤도에 묶음 (flame_trail 면제)
    if not flame_trail_active:
        # ease_out_cubic 인입 + 시간 기반 궤도 좌표
        angle = orbit_seed + elapsed * 0.011
        radius = base_radius * radius_ratio * (1.0 - 0.35 * progress)
        orbit_cx = center_x + cos(angle) * radius
        orbit_cy = center_y + sin(angle * 1.35 + ...) * radius * 0.75
        # ingress: blackhole_ball_origin → orbit으로 부드럽게 흡입
        BALL.center = lerp(ball_origin, orbit, ingress_t)
        ball_vel = (new_pos - prev_pos)  # 다음 프레임 속도

    # 4) 종료
    if elapsed >= 3000:
        _release_viper_chaos_blackhole(early_hit=False)
```

### 사출 속도 보장 (`_release_viper_chaos_blackhole`, 5950행)

```python
if not early_hit and not flame_trail_active:
    base_speed = BALL_BASE_SPEED  # 일반적으로 8.0
    current_speed = math.hypot(ball_vel[0], ball_vel[1])
    # 항상 기준속도의 2배 이상 보장 (확정 빠른 사출)
    release_speed = max(16.0, base_speed * 2.0, current_speed * 1.6)
    release_angle = random.uniform(0.0, math.tau)
    ball_vel[0] = cos(release_angle) * release_speed
    ball_vel[1] = sin(release_angle) * release_speed
```

### 렌더 (`_draw_chaos_blackhole_effect`, 6568행)

```python
def _draw_chaos_blackhole_effect(surface, cx, cy, elapsed_ms, fade_ratio):
    # 등장 성장: 0~200ms 동안 0→1 (impact C 페이즈와 자연 연결)
    growth = min(1.0, elapsed_ms / 200.0)
    vis = fade_ratio * growth   # 등장 + 소멸 모두 자연스럽게
    if vis < 0.02:
        return
    fade_ratio = vis  # 이하 모든 곳에서 vis 사용
```

#### 6.1 중력파 (시공간 왜곡 링)

```python
# 1.2초 주기로 cx에서 솟아 바깥으로 확장하는 왜곡된 4개 링
for wave_i in range(4):
    wave_phase = (elapsed / 1200.0 + wave_i * 0.25) % 1.0
    wave_r = int((20 + wave_phase * 160) * fade_ratio)
    wave_alpha = int(110 * (1.0 - wave_phase) * fade_ratio)
    # 왜곡된 호: 18도 단위로 분할, 각 호에 wobble 추가
    for arc_seg in range(0, 360, 18):
        wobble = int(sin(arc_seg * 0.04 + chaos_t * 5 + wave_i) * 4)
        pygame.draw.arc(wave_surf, (180, 100, 255, wave_alpha), ...)
```

#### 6.2 외곽 헤일로 (5겹 소프트 보라)

```python
halo_r = int((104 + pulse * 28) * fade_ratio)
for i in range(5):
    r = halo_r - i * 16
    a = int((18 + i * 24) * fade_ratio)
    pygame.draw.circle(halo_surf, (130, 60, 220, a), (halo_r, halo_r), r)
```

#### 6.3 회전 플라즈마 링 (3겹)

```python
for ring_i in range(3):
    ring_phase = swirl_t * 1.4 + ring_i * 0.7
    ring_r = int(((62 - ring_i * 13) + sin(ring_phase) * 11) * fade_ratio)
    pygame.draw.circle(ring_surf, (170, 80, 245, ring_alpha), ..., 3)
```

#### 6.4 전기 아크 (무작위 번개)

```python
arc_count = 2 + int((sin(elapsed * 0.04) + 1) * 1.5)  # 2~5개
for arc_i in range(arc_count):
    # 80ms 단위로 시드 변경 → 깜빡이는 번개
    seed = (elapsed_ms // 80) * 7 + arc_i * 31
    # 5세그먼트 지그재그 (radius 50~120px)
    # 백색 코어 + 보라 글로우 + 끝점 스파크
```

#### 6.5 이벤트 호라이즌 코어

```python
core_r = int((32 + pulse * 6) * fade_ratio)
pygame.draw.circle(surface, (18, 0, 36), (cx, cy), core_r)  # 검은 보라 코어
# 어크리션 회전 디스크 (4개 호로 분할)
for disk_i in range(4):
    disk_a_start = swirl_t * 6 + disk_i * (math.tau / 4)
    pygame.draw.arc(surface, (235, 175, 255), ..., disk_a_start, +0.9, 3)
# 특이점 백색 점 (깜빡임)
# 보조 글로우
```

#### 6.6 양자중첩 고스트 볼

```python
# BALL 위치 주변에 5개의 확률적 고스트 (시간 기반 위상)
for ghost_i in range(5):
    ghost_phase = swirl_t * 1.6 + ghost_i * 1.27
    offset_x = cos(ghost_phase * 2.1) * 24
    offset_y = sin(ghost_phase * 1.3 + 1.1) * 20
    ghost_alpha = int(125 * fade_ratio * (0.45 + 0.55 * sin(...)))
    # 보라 외곽 + 백색 글로우 ring
```

#### 6.7 나선 흡수 입자 + 폭발 섬광

```python
# 12개 카오스 궤적 입자 (두 진동 합성으로 비원형)
for p_i in range(12):
    p_a = phase * 1.7 + p_i + sin(p_phase * 0.7) * 0.4
    p_x = cx + cos(p_a) * p_r

# 무작위 폭발 섬광 (180ms 시드 변경, 1/5 확률로 번쩍)
for burst_i in range(2):
    if (bs * 7 + burst_i * 3) % 5 == 0:
        ...
```

**리뷰 포인트**:
- 모든 시각 요소가 `fade_ratio`(= `growth × fade`) 곱해짐 → 시작/끝
  자연스러움
- 매 프레임 다수의 SRCALPHA surface 할당 (할로/링/글로우/고스트/번개 등) →
  성능 모니터링 필요. 현재는 3초 일회성이라 허용 가능
- 양자중첩 고스트는 BALL이 궤도에 있을 때만 활성. flame_trail 시
  공이 외부 제어를 받으므로 분리 처리됨

---

## 7. 오브젝트 끌어당김 시스템 (핵심 아키텍처)

### 설계 원칙

> **실제 보스 투사체를 자기 모습 그대로 중심으로 끌어당기고, 가운데에서 파괴**

이전: `*.clear()` + 카오스 펄스로 대체
현재: 매 프레임 위치 덮어쓰기 + 자체 속도 동결 + 도달 시 파괴

### 색상 힌트 / 끌기 대상 / 회전 가능 화이트리스트 (5461~5582행)

```python
_VIPER_CHAOS_SPEAR_COLOR_HINTS = {
    "fireballs": (255, 140, 60),
    "turret_missiles": (255, 180, 80),
    "falling_tears": (140, 220, 255),
    "water_cannon_fragments": (120, 200, 255),
    "alice_rabbit_projectiles": (255, 180, 230),
    "cotton_throw_projectiles": (255, 240, 240),
    "cotton_bomb_projectiles": (255, 220, 220),
    "cotton_bomb_fragments": (240, 200, 200),
    "spider_rage_projectiles": (180, 120, 60),
    "fan_throw_extra_projectiles": (200, 240, 255),
    "stage8_shurikens": (220, 220, 230),
}

_VIPER_CHAOS_SPEAR_PULL_LISTS = (
    "fireballs", "turret_missiles", "falling_tears",
    "water_cannon_fragments", "alice_rabbit_projectiles",
    "cotton_throw_projectiles", "cotton_bomb_projectiles",
    "cotton_bomb_fragments", "spider_rage_projectiles",
    "fan_throw_extra_projectiles", "stage8_shurikens",
    "web_traps", "tunnel_raid_spikes", "interceptors",
    "stage7_tetrominoes",
)

_VIPER_CHAOS_SPEAR_ROTATABLE_LISTS = frozenset({"crisis_rocks"})
```

### 위치 어댑터 (`_viper_chaos_spear_obj_get_xy / set_xy`, 5498/5524행)

다양한 데이터 구조 통합 처리:

| 구조 | 예시 | 처리 |
|---|---|---|
| `dict` w/ x,y | turret_missiles, web_traps | obj["x"]/obj["y"] |
| `dict` w/ rect | stage8_shurikens | rect.center |
| `[pos, vel]` | fireballs | obj[0][0], obj[0][1] |
| `[x, y, speed, prev_y]` | falling_tears | obj[0], obj[1] |

**set_xy의 자체 속도/페이즈 동결** (5524행):
```python
for vk in ("vx", "vy", "speed_x", "speed_y", "dx", "dy", "speed",
           "fall_speed", "gravity"):
    if vk in obj and isinstance(obj[vk], (int, float)):
        obj[vk] = 0
# 페이즈 진행 동결 (가시 rising→falling 자체 단계 정지)
if "phase" in obj and isinstance(obj["phase"], str):
    obj["phase"] = "hold"
if "phase_timer" in obj and isinstance(obj["phase_timer"], (int, float)):
    obj["phase_timer"] = 0
# rect / collision_rect 동기화
```

### 나선 끌기 로직 (`_viper_chaos_spear_pull_one_list`, 5629행)

```python
# 중심에서 오브젝트로 향하는 벡터
dx_o = ox - cx
dy_o = oy - cy
dist = math.hypot(dx_o, dy_o)

if dist < 14.0:
    # 도달: 특수 destroy 함수 호출 후 또는 단순 제거 + 파괴 플래시
    handled = _viper_chaos_spear_destroy_object(list_name, obj)
    if not handled:
        lst.remove(obj)
    _viper_chaos_spear_spawn_destroy_flash(cx, cy, color)
    continue

# 현재 각도
angle = math.atan2(dy_o, dx_o)

# 회전 방향: id 기반 CW/CCW 혼재 → 카오스 회오리
spin_dir = 1.0 if (id(obj) & 1) else -1.0

# 각속도: 가까울수록 빠름 (각운동량 보존)
ang_v = min(0.22, 8.0 / dist) * spin_dir

# 새 각도 + 방사 속도 (가까울수록 빠르게)
new_angle = angle + ang_v
radial_speed = max(4.0, min(22.0, 460.0 / dist))
new_dist = max(0.0, dist - radial_speed)

# 새 위치 (나선 궤적)
new_x = cx + new_dist * cos(new_angle)
new_y = cy + new_dist * sin(new_angle)
_viper_chaos_spear_obj_set_xy(obj, new_x, new_y)

# 회전 가능한 오브젝트는 시각적 회전도 적용
_viper_chaos_spear_apply_spin(obj, list_name, math.degrees(ang_v) * 1.8)
```

### 특수 파괴 훅 (`_viper_chaos_spear_destroy_object`, 5608행)

```python
if list_name == "stage7_tetrominoes":
    destroy_stage7_tetromino(obj, now=pygame.time.get_ticks(), by_smoke=True)
    return True
if list_name == "crisis_rocks":
    animated_bg_stage2.destroy_rock(obj)
    if obj in animated_bg_stage2.crisis_rocks:
        animated_bg_stage2.crisis_rocks.remove(obj)
    return True
return False  # 호출측에서 lst.remove 처리
```

### 끌기 제외 필터 (`_viper_chaos_spear_should_pull`, 5595행)

```python
if list_name == "stage7_tetrominoes":
    if obj.get("super") or obj.get("wall_generated"):
        return False  # 슈퍼 블록 / 벽으로 변한 블록은 무적
if list_name == "crisis_rocks":
    if obj.get("falling"):
        return False  # 이미 낙하 중인 바위는 그대로 둠
return True
```

### 주 호출 (`_viper_chaos_spear_pull_named_lists`, 5684행)

```python
def _viper_chaos_spear_pull_named_lists() -> None:
    cx, cy = float(_target_x), float(_target_y)
    # 일반 globals 리스트
    for list_name in _VIPER_CHAOS_SPEAR_PULL_LISTS:
        lst = globals().get(list_name)
        if not isinstance(lst, list) or not lst:
            continue
        _viper_chaos_spear_pull_one_list(lst, list_name, cx, cy, now_t)
    # 특수: stage 2 crisis_rocks (animated_bg_stage2.crisis_rocks)
    if current_stage == 2 and animated_bg_stage2 is not None:
        rocks = animated_bg_stage2.crisis_rocks
        if isinstance(rocks, list) and rocks:
            _viper_chaos_spear_pull_one_list(rocks, "crisis_rocks", cx, cy, now_t)
```

### 파괴 플래시 (`_viper_chaos_spear_spawn_destroy_flash`, 5706행)

```python
_viper_chaos_spear_absorb_pulses.append({
    "x": x, "y": y,
    "vx": 0.0, "vy": 0.0,
    "size": 14.0, "base_size": 14.0,
    "life": 8, "max_life": 8,
    "trail": [], "color": color,
    "consumed": True,    # 즉시 파괴 플래시 모드
})
```

**리뷰 포인트**:
- `globals().get(list_name)`로 리스트를 동적 참조 → 보스 코드와의
  의존성을 약하게 유지 (리스트 이름만 알면 됨). 단점: 오타 시 조용히
  실패
- 매 프레임 모든 pull 리스트를 순회 → 리스트가 비어있으면 빠르게
  스킵하므로 비용 작음
- `id(obj) & 1`로 회전 방향 결정 → 매 프레임 동일한 결과 (id는
  객체가 살아있는 동안 유지). 단, GC 후 재할당된 id가 우연히 같으면
  방향이 같아질 수 있으나 실용상 무시 가능
- 회전 적용 화이트리스트는 의도적으로 좁음 (`crisis_rocks`만):
  - tetrominoes의 `rotation`은 셀 레이아웃 정의용 → 손대면 모양 변형
  - turret_missiles의 `angle`은 발사 방향 의미 → 시각 회전과 충돌
  - shurikens는 자체 시간 기반 회전이 이미 있음

### 상태 기반 이벤트 (위치 없는 보스 스킬)

`_absorb_viper_chaos_spear_field_objects` (5744행)에서 90ms 주기로
처리:
- web_rescue (구조 페이즈): 즉시 취소 + 카오스 펄스
- tunnel_raid (보스 돌진): 즉시 취소
- fan_throw / fan_wind (선풍기): 즉시 취소 + 카오스 펄스
- arrest_rope (체포 로프): 즉시 취소
- curse_chest (저주 상자): 즉시 취소

이들은 물리 위치가 없는 "이벤트/상태"라 끌어당길 수 없으므로 카오스
펄스로 표시.

---

## 8. 흡수 펄스 lifecycle (`_viper_chaos_spear_absorb_pulses`)

상태 기반 이벤트 흡수 + 도달 파괴 플래시에 모두 사용되는 단일 풀.

### 펄스 데이터 구조

```python
{
    "x", "y": float,           # 현재 위치
    "vx", "vy": float,         # 속도
    "size": float,             # 현재 시각 크기
    "base_size": float,        # 원본 크기 (consumed 시 부풀림 기준)
    "life": int,               # 남은 수명 (프레임)
    "max_life": int,           # 최대 수명
    "trail": [],               # (현재 미사용, 레거시)
    "color": (R, G, B),        # 시각 색상
    "consumed": bool,          # 중심 도달 후 파괴 플래시 모드
}
```

### 업데이트 (`_update_viper_chaos_spear_runtime` 6014~6056행)

```python
for pulse in _absorb_pulses:
    pulse["life"] -= 1
    if pulse["life"] <= 0:
        continue

    # consumed 단계: 빠르게 줄어들며 사라짐
    if pulse.get("consumed"):
        pulse["size"] = max(0.0, pulse["size"] - 1.6)
        if pulse["size"] <= 0.5:
            continue
        updated_pulses.append(pulse)
        continue

    # 중력 가속도 (가까울수록 강함)
    accel = min(2.4, 110.0 / dist)
    pulse["vx"] += (dx / dist) * accel
    pulse["vy"] += (dy / dist) * accel
    # 접선 회전 성분 (멀리선 큰 소용돌이)
    tan_factor = max(0.0, 0.6 - dist / 200.0)
    pulse["vx"] += (-dy / dist) * tan_factor
    pulse["vy"] += (dx / dist) * tan_factor
    # 감쇠
    pulse["vx"] *= 0.93; pulse["vy"] *= 0.93
    # 위치 갱신
    pulse["x"] += pulse["vx"]; pulse["y"] += pulse["vy"]

    # 중심 근접 시 consumed 진입
    if new_dist < 14:
        pulse["consumed"] = True
        pulse["size"] = pulse["base_size"] * 1.6  # 부풀어 터짐
        pulse["life"] = min(pulse["life"], 8)
```

### 렌더 (`draw_viper_chaos_spear_effect` 6743~6772행)

```python
for pulse in _absorb_pulses:
    if pulse.get("consumed"):
        # 파괴 플래시: 컬러 외곽 + 백색 코어
        burst_surf = pygame.Surface(...)
        pygame.draw.circle(burst_surf, (*col, 220), ..., burst_r)
        pygame.draw.circle(burst_surf, (255, 255, 255, 240), ..., burst_r // 2)
        continue

    # 일반 (상태 기반 이벤트 잔여물): 단순 글로우
    glow_surf = pygame.Surface(...)
    pygame.draw.circle(glow_surf, (170, 100, 240, 110), ..., glow_r)
    pygame.draw.circle(glow_surf, (*col, 230), ..., radius)
    pygame.draw.circle(glow_surf, (255, 255, 255, 200), ..., radius // 3)
```

---

## 9. 입력 잠금 / 공-패들 접촉 처리

### 입력 잠금 (`pingfighter.py` 90201행 부근)

```python
# 바이퍼 카오스 스피어 윈드업(startup) 동안 패들 통제불능
if (selected_character_type == "viper"
        and _viper_chaos_spear_state == "startup"):
    left_pressed = False
    right_pressed = False
    MOVE_EVENT_LEFT = False
    MOVE_EVENT_RIGHT = False
    current_speed = 0.0
    if _viper_chaos_spear_locked_player_x is not None and PLAYER is not None:
        PLAYER.x = int(_viper_chaos_spear_locked_player_x)
```

### 공-패들 접촉 (`_handle_viper_chaos_spear_ball_contact`, 5973행)

```python
def _handle_viper_chaos_spear_ball_contact() -> None:
    """공-패들 접촉 시 호출. 윈드업 중이면 즉시 해제, 비행 중에는 영향 없음."""
    if _viper_chaos_spear_state == "startup":
        # 준비 동작 중 피격: 스피어 발사 X, 윈드업 즉시 해제
        _reset_viper_chaos_spear_state(clear_command=False)
    elif _viper_chaos_spear_state == "blackhole":
        _release_viper_chaos_blackhole(early_hit=True)
    # flying / impact / fade 상태에서는 무시
```

이 함수는 다음 위치에서 호출됨 (모두 공-패들 충돌 지점):
- `pingfighter.py:58764` (쉐도우 백스텝 히트)
- `pingfighter.py:86072, 86696, 86736, 86994` (벽 다이브, 마샬 킥)
- `pingfighter.py:92633` (일반 패들 히트)
- `pingfighter.py:159298` (스테이지별 히트)

### 발동 게이트 (`_start_viper_chaos_spear`, 5861행)

```python
if _viper_chaos_spear_state != "idle": return False
if selected_character_type != "viper": return False
if not is_viper_skill_unlocked("chaos_spear"): return False
if get_viper_skill_cooldown_remaining("chaos_spear") > 0: return False
if special_gauge < 150: return False
if player_stunned or is_waiting_for_serve or is_player_serve or ball_spawn_animation_active:
    return False
# 제트팩 체공 중에는 발동 불가 (지상에서만 가능)
if _viper_jetpack_active or _viper_jetpack_offset_y < -2:
    return False

special_gauge -= 150
trigger_viper_skill_cooldown("chaos_spear")
# ... 상태 진입
```

### 명중 좌표 (`_get_viper_chaos_spear_center`, 5326행)

```python
def _get_viper_chaos_spear_center() -> tuple[float, float]:
    """카오스 스피어가 명중하는 중앙 좌표.
    바이퍼 쉐도우 백스탭 사정거리를 고려해 중앙선보다 60px 아래로 설정."""
    return (
        float(GAME_AREA_OFFSET_X + GAME_PLAY_WIDTH // 2),
        float(INTERNAL_HEIGHT // 2 + 60),  # +60 오프셋
    )
```

---

## 10. 스피어 쉐이프 헬퍼 (`_draw_chaos_spear_shape`, 6161행)

회전 가능한 장식적 스피어. anchor가 창 끝, angle은 진행 방향.

```python
def _draw_chaos_spear_shape(surface, anchor_x, anchor_y, angle,
                             alpha=255, glow=True, scale=1.0):
    """장식적 카오스 스피어 렌더링.
    (anchor_x, anchor_y)는 창 끝(tip), angle은 진행방향(rad)."""
    cos_a = cos(angle); sin_a = sin(angle)

    def proj(lx, ly):
        # lx: tip 기준 길이축(음수 = 손잡이 방향), ly: 수직축
        x = anchor_x + (lx * scale) * cos_a - (ly * scale) * sin_a
        y = anchor_y + (lx * scale) * sin_a + (ly * scale) * cos_a
        return (int(round(x)), int(round(y)))

    L = VIPER_CHAOS_SPEAR_VISUAL_LENGTH  # 78
    blade_back_lx = -22
    crossguard_lx = -22
    shaft_end_lx = -L

    # === 거대한 보라 글로우 오라 (장축 방향, optional) ===
    # === 샤프트 (다크 크롬, 룬 데코 3개) ===
    # === 크로스가드 (4점 박스 + 끝부분 삼각형 장식) ===
    # === 에너지 코어 (다이아몬드 + 백색 하이라이트) ===
    # === 블레이드 (정교한 마름모형 + 미드립 + 칼끝 발광) ===
    # === 폼멜 (보라색 보석) ===
```

좌표계:
```
      ly
       │
   ─22 │ blade
   ────┼─── tip(0,0)  → +lx 방향 (음수 = 손잡이 쪽)
       │ shaft
       │ pommel(-78)
```

**리뷰 포인트**:
- 모든 도형이 함수형 좌표 변환 `proj()`로 회전 적용 → 비행 중
  rotation이 자연스러움
- glow=True 시 매 호출마다 임시 surface + transform.rotate → CPU
  비용 있음. 윈드업/비행/임팩트 합쳐 약 1.4초 동안 매 프레임 호출

---

## 11. 퍼포먼스 노트

### 매 프레임 임시 surface 할당 위치
| 위치 | 빈도 | 비용 추정 |
|---|---|---|
| `_draw_chaos_spear_shape` glow | 윈드업/비행/임팩트 | 큰 SRCALPHA + rotate |
| `_draw_chaos_spear_charging_sparks` 글로우/스파크 | 윈드업 후반 0.5s | 작은 surface 다수 |
| `_draw_chaos_impact_effect` 섬광/링/파편 | 임팩트 360ms | 풀스크린 1회 + 작은 surface 다수 |
| `_draw_chaos_blackhole_effect` 헤일로/링/고스트/번개 | 블랙홀 3000ms | 매 프레임 5~10개 |

블랙홀 단계가 가장 무겁다 (3초 동안 매 프레임 다수 surface 할당).
`CLAUDE.md`의 성능 가이드에 따르면 surface pool 도입 여지가 있다.
현재는 일회성 스킬이라 실용상 허용 범위.

### 풀 시스템 비용
- `_viper_chaos_spear_pull_named_lists`: 매 프레임 호출
- 16개 리스트 순회 (대부분 비어있음 → 빠른 스킵)
- 각 활성 오브젝트당 hypot/atan2/cos/sin 4회 + 위치 덮어쓰기 → 가벼움

### 사운드 호출 위치
- `gravityaccel.wav`: 스킬 발동 (0.35), 임팩트 1차 (0.55)
- `blackhole.wav`: 블랙홀 활성 (0.4), 임팩트 폭발 모멘트 (0.45)

---

## 12. 검토 포인트 (Gemini 리뷰 의뢰 항목)

### 12.1 시각 디자인
1. 윈드업 0.5초 차징 스파크의 강도/밀도가 적절한가?
   (`_draw_chaos_spear_charging_sparks`, intensity 램프 0.33→1.0)
2. 비행 모션블러 광선 길이(90px)가 너무 짧/길지 않은가?
3. 임팩트 3페이즈 분할(45%/40%/15%)의 시간 비율이 자연스러운가?
4. 블랙홀의 시각 요소들(중력파/플라즈마링/번개/고스트)이 너무
   많아서 산만하지 않은가? (총 7가지 레이어)
5. 풀스크린 백색 섬광(임팩트 페이즈 B 초반)이 다른 스테이지 보스
   비주얼을 지나치게 가리지 않는가?

### 12.2 아키텍처
1. 오브젝트 끌기를 `globals().get(list_name)`으로 동적 참조하는
   설계: 보스 코드와 결합도는 낮지만 오타에 약함. 적절한가?
2. `_viper_chaos_spear_obj_get_xy/set_xy`가 4가지 데이터 구조를
   분기 처리: 새 보스 추가 시 어떤 구조를 권장해야 하는가?
3. `_VIPER_CHAOS_SPEAR_ROTATABLE_LISTS`를 화이트리스트로 관리하는
   이유 (tetrominoes/missiles의 의미 충돌). 다른 패턴이 더 나은가?
4. 상태 기반 이벤트(fan_wind/curse_chest 등)는 여전히 즉시 취소 +
   카오스 펄스 방식. 일관성을 위해 다른 방식으로 통일 필요한가?
5. `_viper_chaos_spear_absorb_pulses`가 두 가지 용도로 사용됨
   (상태 기반 흡수 + 파괴 플래시). 분리하는 게 나은가?

### 12.3 성능
1. 매 프레임 surface 할당: 풀 도입 가치가 있는가? (스킬 자체가
   드물게 발동되긴 함)
2. `_draw_chaos_blackhole_effect`의 `pygame.draw.arc` 호출이
   18도 단위로 4겹 × 4가지 → 총 ~80회/프레임. 호 그리기 비용 평가
   필요
3. 풀 시스템에서 충돌 처리 누락: 끌려가는 보스 투사체가 플레이어와
   충돌 가능. 빠르게 중심으로 모이므로 실용상 영향 적지만 명시적으로
   끄는 게 옳은가?

### 12.4 게임 디자인
1. 게이지 150 / 쿨타임 20초가 효과 강도 대비 적절한가?
   (3초 타임스톱 + 광역 클리어 + 확정 사출 2배 → EMP/베놈보다
   강한 유틸리티)
2. 명중 좌표 Y +60 오프셋은 쉐도우 백스탭 동선을 맞추기 위함.
   다른 캐릭터로 확장 시 대응 필요한가?
3. 윈드업 750ms 동안 패들 완전 잠금: 너무 긴가? 다른 캐릭터의
   윈드업과 비교 필요

### 12.5 누락/엣지 케이스
1. 풀 리스트가 비어있고 상태 기반 이벤트도 없을 때 블랙홀 3초간
   "흡수할 게 없는" 시각: 의도된 정상 상태인가?
2. flame_trail_active 상태에서 블랙홀 발동: 공이 외부 제어를 받아
   궤도 묶기 스킵. 의도된 동작인가?
3. 오브젝트가 끌려가는 도중 블랙홀이 종료되면(early_hit): 오브젝트는
   "고아 상태"로 화면에 남음. 정리 필요한가?

---

## 13. 참고: 함수 위치 인덱스

| 함수 | 행 | 역할 |
|---|---|---|
| `_get_viper_chaos_spear_center` | 5326 | 명중 좌표 계산 |
| `_reset_viper_chaos_spear_state` | 5338 | 상태 초기화 |
| `_viper_chaos_spear_spawn_absorb_pulse` | 5403 | 흡수 펄스 생성 (상태 기반) |
| `_viper_chaos_spear_obj_get_xy` | 5498 | 오브젝트 위치 추출 |
| `_viper_chaos_spear_obj_set_xy` | 5524 | 오브젝트 위치 덮어쓰기 + 동결 |
| `_viper_chaos_spear_apply_spin` | 5584 | 시각 회전 (화이트리스트) |
| `_viper_chaos_spear_should_pull` | 5595 | 끌기 제외 필터 |
| `_viper_chaos_spear_destroy_object` | 5608 | 특수 파괴 훅 |
| `_viper_chaos_spear_pull_one_list` | 5629 | 단일 리스트 나선 끌기 |
| `_viper_chaos_spear_pull_named_lists` | 5684 | 매 프레임 끌기 진입점 |
| `_viper_chaos_spear_spawn_destroy_flash` | 5706 | 도달 파괴 플래시 |
| `_absorb_viper_chaos_spear_field_objects` | 5744 | 상태 기반 이벤트 흡수 |
| `_start_viper_chaos_spear` | 5861 | 발동 게이트 |
| `_cancel_viper_chaos_spear` | 5917 | 캔슬 (fade 진입) |
| `_activate_viper_chaos_blackhole` | 5930 | blackhole 진입 |
| `_release_viper_chaos_blackhole` | 5950 | blackhole 종료 + 사출 |
| `_handle_viper_chaos_spear_ball_contact` | 5973 | 공-패들 접촉 |
| `_update_viper_chaos_spear_runtime` | 5983 | 메인 업데이트 (매 프레임) |
| `_draw_chaos_spear_shape` | 6161 | 스피어 본체 렌더 |
| `_draw_chaos_spear_charging_sparks` | 6281 | 윈드업 전기 차징 |
| `_draw_chaos_spear_cracks` | 6363 | 임팩트 균열 |
| `_draw_chaos_impact_effect` | 6415 | 임팩트 3페이즈 |
| `_draw_chaos_blackhole_effect` | 6568 | 블랙홀 카오스 보텍스 |
| `draw_viper_chaos_spear_effect` | 6727 | 메인 렌더 진입점 |

---

## 14. 메인 렌더 함수 (`draw_viper_chaos_spear_effect`, 6727행)

```python
def draw_viper_chaos_spear_effect(surface):
    if state == "idle" and not absorb_pulses and cancel_flash <= 0:
        return

    cx, cy = current_x, current_y
    center_x, center_y = target_x, target_y
    local_elapsed = now - state_start_ms

    # 1. 흡수 펄스 (consumed 또는 단순 글로우)
    for pulse in _absorb_pulses: ...

    # 2. 상태별 분기
    if state == "startup":
        # 윈드업 자세 + 차지 오라 + 에너지 라인 + 차지 스파크
        # 스피어 본체 + 전기 차징 스파크
    elif state == "flying":
        # 모션블러 광선 + 후방 스파크 + 본체 (회전 매칭)
    elif state == "impact":
        progress = elapsed_imp / IMPACT_MS
        _draw_chaos_impact_effect(surface, center_x, center_y, progress, seed, angle)
    elif state in ("blackhole", "fade"):
        fade_ratio = 1.0 if state == "blackhole" else (1.0 - elapsed/FADE_MS)
        _draw_chaos_blackhole_effect(surface, center_x, center_y, elapsed, fade_ratio)
        if cancel_flash > 0:
            # 분홍 캔슬 링
```

호출 위치: `pingfighter.py:120376` 부근의 메인 렌더 루프
(`draw_viper_chaos_spear_effect(SCREEN)`).
