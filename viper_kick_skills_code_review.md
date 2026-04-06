# 바이퍼 킥 스킬 시스템 코드 리뷰 문서

## 1. 아키텍처 개요

바이퍼의 킥 스킬은 **3단 연계 시스템**으로, Shadow Backstep → Marshal Kick → Phantom Kick 순서로 체이닝된다.
모든 코드는 `pingfighter.py`에 집중되어 있으며, 사운드 정의만 `sound_effects.py`, 파티클 이펙트 일부가 `effects_manager.py`에 분리되어 있다.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        바이퍼 킥 연계 시스템                           │
│                                                                      │
│  ┌───────────────────┐   공 타격 + 300ms   ┌──────────────────┐     │
│  │  쉐도우 백스텝     │ ─────────────────→  │   마샬 킥         │     │
│  │  Shadow Backstep  │   게이지≥80          │   Marshal Kick   │     │
│  │  게이지: 100      │   1.5초 윈도우       │   게이지: 80     │     │
│  │  쿨타임: 15초     │                      │   쿨타임: 25초   │     │
│  └───────────────────┘                      └──────────────────┘     │
│         │                                          │                 │
│         │ 대쉬 중 S키                               │ 공 타격 + 200ms │
│         │                                          ▼                 │
│         │                                   ┌──────────────────┐     │
│         │                                   │   팬텀 킥         │     │
│         │                                   │   Phantom Kick   │     │
│         │                                   │   게이지: 60     │     │
│         │                                   │   쿨타임: 40초   │     │
│         │                                   │   퍽 해금 필요    │     │
│         │                                   └──────────────────┘     │
│         │                                                            │
│  ┌──────┴───────────────────────────────────────────────────────┐    │
│  │                   공통 퍽: 킥 강화 (kick_enhance)              │    │
│  │   레벨당 +20% 정밀도, +5% 공속 (최대 Lv.5: +100%, +25%)      │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. 스킬 정의 데이터 (pingfighter.py:3686~3726)

### VIPER_SKILL_ICONS_DATA 배열

| 필드 | 쉐도우 백스텝 | 마샬 킥 | 팬텀 킥 |
|------|--------------|---------|---------|
| `name` | `"shadow_step"` | `"marshal_kick"` | `"phantom_kick"` |
| `korean` | `"쉐도우 백스텝"` | `"마샬 킥"` | `"팬텀 킥"` |
| `cost` | 100 | 80 | 60 |
| `color` | `(100, 0, 180)` | `(130, 0, 200)` | `(180, 0, 255)` |
| `symbol` | `"⟐"` | `"🕷"` | `"x2"` |
| `cooldown` | 15.0초 | 25.0초 | 40.0초 |
| `key` | `"대쉬+S"` | `"S/↓(연계)"` | `"S/↓(연계)"` |
| `effect_type` | - | `"wall_dive_purple"` | `"wall_dive_purple"` |

### 해금 상태 (pingfighter.py:3767~3813)

```python
# 기본 해금 (True)
"shadow_step": True,    # 라인 3773
"marshal_kick": True,   # 라인 3773 (shadow_step과 함께 자동 해금)

# 팬텀 킥은 퍽으로 해금
_viper_double_marshal_kick_unlocked = False  # 라인 49404
# double_marshal_kick 퍽 (Lv.1) 해금 시 True
```

---

## 3. 쉐도우 백스텝 (Shadow Backstep)

### 3-1. 상태 변수 (pingfighter.py:49196~49230)

```python
# 대쉬 출발점 기록
_viper_dash_origin_x = 0.0              # 라인 49196
_viper_dash_was_airborne = False         # 라인 49198

# 홀로그램 시스템
_viper_ss_hologram_active = False        # 라인 49200
_viper_ss_hologram_start_ms = 0          # 라인 49201
_viper_ss_hologram_target_x = 0          # 라인 49202 (목적지 X)
_viper_ss_hologram_origin_x = 0          # 라인 49203 (출발 X)
_viper_ss_hologram_origin_y = 0          # 라인 49204 (출발 Y)
_viper_ss_hologram_kick_dir = 0          # 라인 49205 (-1=좌, 1=우)
_VIPER_SS_HOLOGRAM_DURATION = 500        # 라인 49206 (500ms)

# 에너지파 시스템
_viper_ss_wave_active = False            # 라인 (추정)
_viper_ss_wave_speed = 25.0              # px/frame (매우 빠름)
_viper_ss_wave_trail = []                # 최대 12개 트레일

# 볼 타격 추적
_viper_ss_ball_touched = False           # 라인 49221
_viper_ss_ball_touched_ms = 0            # 라인 49222
_viper_ss_hit_consumed = False           # 라인 49285

# 팬텀 스트라이크 버프
_VIPER_PHANTOM_STRIKE_DURATION = 18      # 라인 49229 (0.3초 @ 60fps)
```

### 3-2. 발동 조건 (pingfighter.py:73841~73928)

```python
# 입력 감지 (라인 73841)
_viper_ss_input = _viper_s_pressed or keys[pygame.K_DOWN]

# 발동 조건 체크 (라인 73857~73865)
조건 1: 대쉬 중이거나 대쉬 직후 상태
조건 2: S키 또는 ↓키 단독 입력 (방향키 동시 입력 없음)
조건 3: 스페셜 게이지 >= 100
조건 4: shadow_step 쿨타임 <= 0
조건 5: 홀로그램 비활성 상태

# 발동 시퀀스 (라인 73866~73928)
1. is_viper_skill_unlocked("shadow_step") 확인      # 라인 73866
2. special_gauge -= 100 (게이지 소모)                # 라인 73870
3. trigger_viper_skill_cooldown("shadow_step")       # 라인 73873 (15초)
4. _viper_skill_cooldown_override.pop("shadow_step") # 라인 73872
5. VIPER_BACKSTEP 사운드 재생 (볼륨 0.5)             # 라인 73875~73878
6. 대쉬 상태 즉시 해제                                # 라인 73882~73885
7. 홀로그램 + 텔레포트 초기화                          # 라인 73888~73923
8. 팬텀 스트라이크 버프 활성화 (0.3초)                 # 라인 73925~73928
```

### 3-3. 텔레포트 로직 (pingfighter.py:73908~73923)

```python
_ss_new_x = _viper_dash_origin_x           # 대쉬 출발점으로 복귀 (라인 73908)
_ss_reverse_dir = 1 if _ss_new_x > PLAYER.centerx else -1  # 커브 방향 (라인 73911)
PLAYER.centerx = _ss_new_x                  # 즉시 텔레포트 (라인 73914)
```

### 3-4. 볼 타격 메커닉 - 그래디언트 히트 시스템 (pingfighter.py:49241~49338)

```python
# 상수 (라인 49241~49247)
_VIPER_SS_HIT_SPEED_MIN = 1.4    # 가장자리: +40% 속도
_VIPER_SS_HIT_SPEED_MAX = 1.8    # 중심부: +80% 속도
_VIPER_SS_HIT_CURVE_MIN = 10     # 가장자리: ~0.17초 커브
_VIPER_SS_HIT_CURVE_MAX = 50     # 중심부: ~0.83초 커브
_VIPER_SS_HIT_FORCE_MIN = 0.4    # 가장자리 커브 힘
_VIPER_SS_HIT_FORCE_MAX = 2.0    # 중심부 커브 힘
```

**거리 기반 그래디언트 보간:**
```python
# 체비셰프 거리 계산 (라인 49274~49276)
dist_ratio = max(abs(dx) / half_w, abs(dy) / half_h)  # 0.0(중심) ~ 1.0(가장자리)

# 선형 보간 (라인 49280~49282)
speed_mult = MAX + (MIN - MAX) * dist_ratio  # 중심에 가까울수록 강함
curve_frames = MAX + (MIN - MAX) * dist_ratio
curve_force = MAX + (MIN - MAX) * dist_ratio
```

**3개의 볼 타격 소스:**

| 소스 | 위치 | 설명 |
|------|------|------|
| 홀로그램 킥 | 라인 108759~108763 | 홀로그램의 킥박스가 공과 충돌 (t > 0.3) |
| 에너지파 | 라인 75020~75022 | 에너지파가 공에 도달 |
| 패들 히트 | 라인 80336~80345 | 발동 후 첫 패들 접촉 |

### 3-5. 비주얼 이펙트

**홀로그램 렌더링 (pingfighter.py:108687~108770):**
```python
_holo_t = min(1.0, _holo_elapsed / _VIPER_SS_HOLOGRAM_DURATION)  # 라인 108691
# 이징: ease-in-out cubic (라인 108704)
# 알파: 0→255 점진적 출현 (라인 108707)
# 쉬머 효과: 아지랑이/열기 왜곡 (라인 108713~108716)
# 고스트 복사본: 킥 방향으로 8개 분신 (라인 108722~108743)
# 킥박스 충돌: 60px 확장 영역 (라인 108749~108763)
```

**에너지파 렌더링 (pingfighter.py:109294~109365):**
- 트레일 그래디언트 리본 (너비 20~35px)
- 초승달 모양 에너지 코어 + 3단계 외부 글로우
- 이동 방향 선행 스파크 3개

**넉백 면역 (pingfighter.py:47430):**
```python
# 바이퍼 쉐도우 백스텝 홀로그램 활성 중에는 넉백 무시
# (텔레포트 직후 밀려남 방지)
```

### 3-6. 사운드

| 사운드 | 키 | 파일 | 볼륨 | 위치 |
|--------|-----|------|------|------|
| 발동음 | `VIPER_BACKSTEP` | `sounds/backstep.wav` | 0.5 | sound_effects.py:120 |
| 킥 타격음 | `VIPER_SHADOW_KICK` | `sounds/shadowkick.wav` | - | sound_effects.py:124 |

### 3-7. 골드 보상

```python
# 쉐도우 백스텝 타격: 16골드
# 제트팩 체공 시: ×1.5 (24골드)
```

---

## 4. 마샬 킥 (Marshal Kick)

### 4-1. 상태 변수 (pingfighter.py:49373~49401)

```python
# 체이닝 윈도우
_viper_wall_dive_ready = False              # 라인 49373 (연계 윈도우 활성)
_viper_wall_dive_ready_timer = 0            # 라인 49374 (윈도우 타이머)
_VIPER_WALL_DIVE_READY_FRAMES = 90          # 라인 49375 (1.5초 @ 60fps)

# 실행 상태
_viper_wall_dive_active = False             # 라인 49376
_viper_wall_dive_phase = 0                  # 라인 49377 (0~5 페이즈)
_viper_wall_dive_start_ms = 0               # 라인 49378
_viper_wall_dive_ball_hit = False           # 라인 49387

# 위치 추적
# (start, wall, charge target, reclimb, return 위치들)  # 라인 49379~49391

# 이펙트
_viper_wall_dive_web_lines = []             # 라인 49392 (거미줄 로프)
_viper_wall_dive_particles = []             # 라인 49393 (파티클 배열)

# 타이밍 상수
_VIPER_WALL_DIVE_JUMP_MS = 412             # 라인 49396 (벽 점프 시간)
_VIPER_WALL_DIVE_CLING_MS = 250            # 라인 49397 (벽 매달림 시간)
_VIPER_WALL_DIVE_CHARGE_MS = 390           # 라인 49398 (돌진 시간)
_VIPER_WALL_DIVE_RETURN_MS = 350           # 라인 49394 (착지 복귀 시간)
_VIPER_WALL_DIVE_HIT_RADIUS = 90           # 라인 49399 (볼 충돌 반경 px)
_VIPER_WALL_DIVE_RECLIMB_THRESHOLD = 120   # 라인 49400 (벽 재등반 거리)
_VIPER_WALL_DIVE_RECLIMB_MS = 180          # 라인 49401 (재등반 속도)
_VIPER_WALL_DIVE_GAUGE_COST = 80           # 라인 49395
```

### 4-2. 연계 발동 조건 (pingfighter.py:74028~74053)

```python
# 쉐도우 백스텝 → 마샬 킥 연계 (라인 74028~74033)
조건 1: _viper_ss_ball_touched == True (쉐도우 백스텝 공 타격 성공)
조건 2: 300ms 딜레이 경과 (_VIPER_MARSHAL_KICK_1ST_DELAY_MS)
조건 3: marshal_kick 쿨타임 <= 0
조건 4: special_gauge >= 80
→ _viper_wall_dive_ready = True (1.5초 윈도우 활성화)

# 윈도우 유지/소멸 (라인 74036~74039)
_viper_wall_dive_ready_timer -= 1  # 매 프레임 감소
if timer <= 0 or gauge < 80:       # 시간 초과 또는 게이지 부족 시 해제
    _viper_wall_dive_ready = False
```

### 4-3. 입력 처리 (pingfighter.py:74061~74101)

```python
_wd_s_input = keys[pygame.K_s] or keys[pygame.K_DOWN]  # 라인 74068
_wd_dir_held = (방향키 동시 입력 감지)                    # 라인 74069

# 발동 조건 (라인 74074~74076)
_wd_can_fire = _viper_wall_dive_ready or _viper_double_marshal_ready
if _wd_s_input and not _wd_dir_held and _wd_can_fire and not _viper_wall_dive_active:

# 게이지 소모 (라인 74089)
special_gauge -= 80  # 마샬 킥
# (팬텀 킥일 경우 -= 60)

# 쿨타임 트리거 (라인 74093)
trigger_viper_skill_cooldown("marshal_kick")  # 25초
```

### 4-4. 실행 페이즈 시스템 (pingfighter.py:74138~74521)

```
Phase 0: 벽 점프     Phase 1: 벽 매달림    Phase 3: 벽 재등반    Phase 2: 돌진
412ms               250ms                180ms                390ms
┌──────┐           ┌──────┐             ┌──────┐            ┌──────┐
│플레이어│ ──로프──→│ ■벽  │ ──공 근접──→ │ 벽■  │ ──────→    │ ⚽공  │
│  위치  │         │ 매달림│             │재등반 │            │ 타격  │
└──────┘           └──────┘             └──────┘            └──────┘
                         │                                       │
                         │ (공이 멀면)                             ▼
                         └──────────── Phase 2 ──────────→  Phase 4/5
                                       돌진                  착지/프리즈
```

**Phase 0 - 벽 점프 (라인 74143~74176):**
- ease-in-out 보간으로 플레이어→벽 이동
- 거미줄 라인 파티클 생성
- 팬텀 킥은 30% 빠르게 실행

**Phase 1 - 벽 매달림 (라인 74178~74235):**
- 플레이어를 벽 위치에 고정
- 볼 근접 체크 (120px 이내 → Phase 3 재등반)
- 아니면 Phase 2 돌진으로 전환

**Phase 3 - 벽 재등반 (라인 74242~74310):**
- 반대편 벽으로 빠르게 이동 (180ms)
- 거미줄 + 파티클 이펙트
- Phase 1로 복귀

**Phase 2 - 돌진 (라인 74311~74474):**
- 실시간 볼 위치 추적
- 충돌 반경 90px 이내 시 타격 처리
- 팬텀 킥은 30% 빠르게 돌진

**Phase 4 - 착지 복귀 (라인 74484~74521):**
- ease-in-out으로 지면 복귀 (350ms)
- 파티클 정리

**Phase 5 - 팬텀 킥 프리즈 (라인 74475~74482):**
- 팬텀 킥 전용
- 볼 + 보스 일시 정지
- Phase 4로 전환

### 4-5. 볼 타격 물리 (pingfighter.py:74340~74468)

```python
# 속도 증가 (라인 74354~74357)
마샬 킥:   2.0× (100% 증가) × kick_enhance 보너스
팬텀 킥:   2.8× (180% 증가) × kick_enhance 보너스
최소 속도: 마샬 11.0 / 팬텀 14.0

# kick_enhance 퍽 보너스 (라인 74350~74351)
speed_bonus = 1.0 + (kick_enhance_level × 0.05)  # 최대 Lv.5 → 1.25

# 발사 각도 계산 (라인 74361~74375)
base_bias = 마샬 0.5 / 팬텀 0.8  # 보스 회피 편향 기본값
+ kick_enhance 보정
random_angle = ±55°
boss_avoidance = ±25~50°
minimum_angle = 마샬 20° / 팬텀 25°
final_clamp = ±60° 최대

# 커브 적용 (라인 74442~74449)
마샬: 기본 커브 지속시간
팬텀: 2.5배 커브 지속시간 (더 과장된 궤적)
```

### 4-6. 비주얼 이펙트

**플레이어 포즈 (pingfighter.py:33037~33125):**

| 포즈 | 파라미터 | 설명 |
|------|---------|------|
| 벽 매달림 | `wall_cling = ±1` | 스파이더맨식 웅크린 자세, 벽쪽 다리 구부림 |
| 플라잉 킥 | `flying_kick = ±1` | 이소룡식 비행 발차기, 수평 자세 |
| 킥 강도 | `flying_kick_intensity` | 0.0~1.0, 하강 시 감소 |

**거미줄 로프 렌더링 (pingfighter.py:109368~109419):**
```python
# 4겹 레이어 구조
Layer 1: 외부 글로우 (50, 10, 80)     - 10px 너비
Layer 2: 중간 글로우 (70, 15, 110)    - 6px 너비
Layer 3: 코어 라인  (90~140, 25~60, 140~200) - 3px, 맥동
Layer 4: 하이라이트 (140~200, 60~150, 200~255) - 1px
```

**벽 매달림 글로우 (pingfighter.py:109420~109430):**
- 맥동 원형 글로우 (70, 10, 120)
- 반경 35px, 0.02 속도로 맥동

**파티클 시스템 (pingfighter.py:109452~109464):**
- 최대 60개 파티클
- trail 타입: (70, 18, 110), 기타: (100, 30, 160)
- additive 블렌딩

**다크 레드 임팩트 (effects_manager.py:1063~1100):**

| 킥 종류 | 파티클 수 | 강도 | 색상 |
|---------|----------|------|------|
| 마샬 킥 | 24개 | 1.0 | (160~255, 0~50, 0~30) |
| 팬텀 킥 | 40개 | 2.5 | 동일 계열 + 보라색 혼합 |

### 4-7. 사운드

| 사운드 | 키 | 파일 | 볼륨 | 위치 |
|--------|-----|------|------|------|
| 팬텀킥 타격 | `VIPER_PHANTOM_KICK_HIT` | `sounds/pentomkick.wav` | 0.8 | sound_effects.py:128 |

> **참고**: 마샬 킥 자체의 전용 발동/이동 사운드는 별도 정의되어 있지 않음. 로프 사운드 등은 범용 SFX 사용.

### 4-8. 골드 보상 (pingfighter.py:74450~74458)

| 킥 종류 | 기본 골드 | 공중 보너스 (×1.5) |
|---------|----------|-------------------|
| 마샬 킥 | 30 | 45 |
| 팬텀 킥 | 50 | 75 |

---

## 5. 팬텀 킥 (Phantom Kick)

### 5-1. 상태 변수 (pingfighter.py:49403~49438)

```python
# 해금 & 연계
_viper_double_marshal_kick_unlocked = False  # 라인 49404 (퍽 해금)
_viper_ss_was_airborne = False               # 라인 49405 (공중 상태)
_viper_marshal_kick_hit_ball = False         # 라인 49406 (1차 타격 감지)
_viper_marshal_kick_hit_ms = 0               # 라인 49407 (1차 타격 시간)
_viper_double_marshal_ready = False          # 라인 49408 (2차 윈도우)
_viper_double_marshal_ready_timer = 0        # 라인 49409 (윈도우 타이머)
_viper_is_double_marshal = False             # 라인 49410 (현재 2차 킥 실행중)
_viper_phantom_kick_knockback_pending = False # 라인 49411

# 프리즈 이펙트
_viper_dmk_freeze_active = False             # 라인 49430
_viper_dmk_freeze_timer = 0                  # 라인 49431
_VIPER_DMK_FREEZE_DURATION = 60              # 라인 49432 (1초)

# 텍스트 이펙트
_viper_dmk_text_active = False               # 라인 49424
_viper_dmk_text_timer = 0                    # 라인 49425
_VIPER_DMK_TEXT_DURATION = 80                # 라인 49428 (80프레임)

# 팬텀 오라
_viper_phantom_aura_active = False           # 라인 49435
_viper_phantom_aura_start_ms = 0             # 라인 49436
_viper_phantom_hit_particles = []            # 라인 49438 (85개 다크 에너지 파편)
```

### 5-2. 연계 발동 조건 (pingfighter.py:74041~74053)

```python
# 마샬 킥 공 타격 → 팬텀 킥 윈도우 (라인 74041~74047)
조건 1: _viper_marshal_kick_hit_ball == True (1차 킥 공 타격)
조건 2: _viper_ss_was_airborne == True (공중 상태)
조건 3: 200ms 딜레이 경과 (_VIPER_MARSHAL_KICK_2ND_DELAY_MS)
조건 4: _viper_double_marshal_kick_unlocked == True (퍽 해금)
조건 5: phantom_kick 쿨타임 <= 0
조건 6: special_gauge >= 60

→ _viper_double_marshal_ready = True (1.5초 윈도우 활성화)
→ _viper_marshal_kick_hit_ball = False (소비)
```

### 5-3. 팬텀 킥 전용 차별점

마샬 킥과 동일한 페이즈 시스템을 공유하되, 다음이 다르다:

| 항목 | 마샬 킥 | 팬텀 킥 |
|------|---------|---------|
| 게이지 소모 | 80 | 60 |
| 쿨타임 | 25초 | 40초 |
| 속도 배율 | 2.0× (+100%) | 2.8× (+180%) |
| 최소 속도 | 11.0 | 14.0 |
| 커브 지속 | 기본 | ×2.5 |
| 정밀도 bias | 0.5 | 0.8 |
| 최소 각도 | 20° | 25° |
| 벽 점프 속도 | 412ms | ~289ms (30% 빠름) |
| 돌진 속도 | 390ms | ~273ms (30% 빠름) |
| 골드 보상 | 30 | 50 |
| 화면 흔들림 | force=12, intensity=5 | force=20, intensity=8 |
| 파티클 | 24개, 강도 1.0 | 40+85개, 강도 2.5 |
| 프리즈 | 없음 | 1초 (볼+보스 정지) |
| 넉백 | 없음 | 18.0 (보스 밀침) |
| 오라 | 없음 | 다크 플레임 스파이럴 |
| 텍스트 | 없음 | "팬텀 킥" 80프레임 표시 |

### 5-4. 팬텀 킥 전용 비주얼

**다크 플레임 스파이럴 오라 (pingfighter.py:109159~109246):**
- 내부 다크 글로우 + 맥동
- 6턴 다크 플레임 스파이럴 + 흔들림
- 14개 외부 다크 스모크 파티클 + 트레일
- 이중 그래파이트 링 + 맥동

**다크 에너지 파편 폭발 (pingfighter.py:109248~109284):**
```python
# 85개 파편 (라인 74426~74430)
8색 보라/다크 팔레트:
  (80, 15, 120), (110, 25, 160), (60, 8, 95), (130, 30, 180) 등
속도: 3.5~13.0 px/frame
수명: 30~65 프레임
중력 가속: 0.04 px/frame²
마찰: 0.97x/frame
50%에 밝은 코어 하이라이트
```

**프리즈 텍스트 렌더링 (pingfighter.py:117616~117667):**
```python
# "팬텀 킥" 텍스트 (36px 폰트)
렌더링 레이어:
1. 다크 오라 글로우 (타원형, 50x 어둡게)
2. 딥 섀도우 (오프셋 +3, +3)
3. 메인 텍스트: RGB(160, 50, 200) - 보라색 톤
4. 하이라이트 엣지: RGB(200, 120, 230) @ 18% 알파
5. 프리즈 중 화면 흔들림: ±2px X, ±1px Y
6. 14개 다크 파티클 텍스트 주위 궤도
```

### 5-5. 보스 넉백 (pingfighter.py:149349~149354)

```python
if _viper_phantom_kick_knockback_pending:
    _viper_phantom_kick_knockback_pending = False
    _dmk_kb_dir = 1 if BALL.centerx > BOSS.centerx else -1
    boss_fire_knockback_vel = _dmk_kb_dir * 18.0  # 강한 넉백
```

### 5-6. 사운드

| 사운드 | 키 | 파일 | 볼륨 | 시점 |
|--------|-----|------|------|------|
| 타격음 | `VIPER_PHANTOM_KICK_HIT` | `sounds/pentomkick.wav` | 0.8 | 볼 충돌 시 |
| 텍스트 표시음 | `VIPER_SHOW` | `sounds/bypershow.wav` | 0.7 | 프리즈 텍스트 출현 시 |

---

## 6. 공통 퍽 시스템

### 6-1. 킥 강화 (kick_enhance) - pingfighter.py:13252~13266

```python
"kick_enhance": {
    "name": "킥 강화",
    "max_level": 5,  # (코드상 7까지 확장 가능)
    "descriptions": {
        1: "+20% 정밀도, +5% 공속",
        2: "+40% 정밀도, +10% 공속",
        3: "+60% 정밀도, +15% 공속",
        4: "+80% 정밀도, +20% 공속",
        5: "+100% 정밀도, +25% 공속",
    },
    "detail": "쉐도우 백스텝, 마샬 킥, 팬텀 킥의 발사 정밀도와 공속이 강화됩니다.\n"
              "레벨당 보스 회피 편향 20% 증가 + 공속 5% 증가.\n"
              "(최대 Lv.5: 정밀도 100%, 공속 +25%)",
    "icon_color": (180, 0, 255),
    "tree": "viper",
    "character_restriction": "viper"
}
```

**적용 로직:**
```python
# 속도 보너스 (라인 74351)
speed_bonus = 1.0 + (kick_enhance_level × 0.05)
# Lv.0 → 1.0 / Lv.5 → 1.25 / Lv.7 → 1.35

# 정밀도 보너스 (라인 49303)
_ss_base_bias = 0.2  # 쉐도우 백스텝 기본 편향
# kick_enhance 레벨에 따라 편향 증가
```

### 6-2. 팬텀 킥 퍽 (double_marshal_kick) - pingfighter.py:13226~13236

```python
"double_marshal_kick": {
    "name": "팬텀 킥",
    "max_level": 1,
    "descriptions": {
        1: "마샬 킥 후 보스 반환 시 2차 마샬 킥 발동 가능 (최대 4연계)",
    },
    "detail": "마샬 킥 → 보스 반환 시 3초간 S/↓키로 2차 마샬 킥을 사용할 수 있습니다.\n"
              "게이지 50 소모, 공속 증가율 120%.",
    "icon_color": (180, 0, 255),
    "tree": "viper",
    "character_restriction": "viper"
}
```

### 6-3. 스킬 아이콘 렌더링 (pingfighter.py - draw_skill_icon_mini)

| 스킬 | 아이콘 설명 | 라인 범위 |
|------|-----------|----------|
| 쉐도우 백스텝 | "⟐" 심볼 + 고스트 트레일 (좌→우, 3단 페이드) | 4676~4690 |
| 마샬 킥 | 3D 벽 + 거미줄 곡선 + 돌진 궤적 + 임팩트 링 | 4815~4885 |
| 팬텀 킥 | 겹치는 발자국 2개 + "x2" 텍스트 | 4886~4925 |
| 킥 강화 | (퍽 UI 전용) | 13252~13266 |

---

## 7. 쿨타임 시스템 (pingfighter.py:3738~3890)

### 쿨타임 저장소

```python
_viper_skill_cooldowns = {
    "shadow_step": 0,     # 라인 3743
    "marshal_kick": 0,    # 라인 3743
    "phantom_kick": 0,    # 라인 3744
}

_viper_skill_cooldown_override = {}  # 라인 (쿨타임 오버라이드)
```

### 쿨타임 함수

```python
trigger_viper_skill_cooldown(skill_name)          # 라인 3832 - 쿨타임 시작
get_viper_skill_cooldown_remaining(skill_name)     # 라인 3838 - 남은 시간 반환
reset_viper_skill_cooldowns()                      # 라인 3890 - 전체 초기화
```

### UI 표시

| 상태 | 시각적 효과 |
|------|-----------|
| 준비 완료 | 붉은 맥동 글로우 |
| 연계 윈도우 활성 | 강한 빨간 글로우 + 게이지 충분 표시 |
| 쿨타임 중 | 쿨타임 아크 오버레이 |

---

## 8. 상태 초기화 (pingfighter.py)

### 초기화 시점

| 시점 | 위치 | 설명 |
|------|------|------|
| 스테이지 전환 | 라인 141712~141717 | 에너지파, 볼 터치 상태 리셋 |
| 풀 리셋 | 라인 59250~59301 | 모든 웨이브/홀로그램/파티클 상태 초기화 |
| 게임 오버 | 라인 ~20185 | 전체 스킬 리셋 |
| ESC 메뉴 | 라인 ~20965 | 전체 스킬 리셋 |

### 리셋 대상

```python
_viper_ss_wave_active = False
_viper_ss_wave_hit_ball = False
_viper_ss_wave_trail = []
_viper_ss_ball_touched = False
_viper_wall_dive_active = False
_viper_wall_dive_ready = False
_viper_double_marshal_ready = False
_viper_is_double_marshal = False
_viper_dmk_freeze_active = False
_viper_phantom_aura_active = False
_viper_phantom_hit_particles = []
# ... 기타 모든 상태 변수
```

---

## 9. 주요 이슈 요약

| # | 이슈 | 심각도 | 설명 |
|---|------|--------|------|
| 1 | **커브 상태 오염** | 높음 | 마샬/팬텀 킥이 `_viper_ps_curve_total_frames`와 `_viper_ps_curve_force`를 세팅하지 않아 직전 쉐도우 백스텝의 그래디언트 값이 잔류. 가장자리 SS 후 팬텀 킥 시 커브 계산 왜곡 (§14 참조) |
| 2 | **모션↔발사각 분리** | 중간 | 세 스킬 모두 발차기 포즈 방향과 공 발사각이 독립 계산. 오른쪽 킥 모션인데 공이 왼쪽으로 날아가는 부자연스러움 (§12 참조) |
| 3 | **전역 변수 과다** | 중간 | 3개 스킬에 대해 50+ 전역 변수가 pingfighter.py 최상위에 산재. 클래스로 캡슐화되어 있지 않아 네임스페이스 오염 및 의도치 않은 상태 변경 위험 |
| 4 | **페이즈 시스템 복잡도** | 중간 | 마샬 킥/팬텀 킥이 Phase 0~5를 공유하면서 `_viper_is_double_marshal` 플래그로 분기. 조건부 타이밍(30% 빠름 등)이 곳곳에 인라인되어 유지보수 어려움 |
| 5 | **볼 타격 3중 소스** | 중간 | 쉐도우 백스텝의 공 타격이 홀로그램/에너지파/패들 3곳에서 독립 호출. `_viper_ss_hit_consumed` 플래그로 중복 방지하나, 레이스 컨디션 가능성 |
| 6 | **팬텀 프리즈 타이밍** | 중간 | 프리즈가 돌진 전(Phase 6)에 먼저 발동. 임팩트 히트스톱이 아닌 "예열 슬로모션" 체감. 성능적으로도 조준 보정 효과 발생 |
| 7 | **홀로그램 킥박스 비대칭** | 낮음 | 고스트는 kick_dir 방향으로 뿌리지만 충돌 박스는 좌우 대칭 60px 확장. 발이 닿지 않는 쪽의 공도 판정됨 |
| 8 | **퍽 설명 수치 불일치** | 낮음 | `double_marshal_kick` detail "게이지 50 소모" → 실제 60, "공속 120%" → 실제 180% |
| 9 | **사운드 불균형** | 낮음 | 쉐도우 백스텝·팬텀 킥은 전용 사운드 2개씩이나, 마샬 킥 발동/이동에는 전용 사운드 없음 |
| 10 | **kick_enhance max_level** | 낮음 | 퍽 정의에 `max_level: 5`이나 코드 내 speed_bonus 계산은 `level × 0.05`로 7까지 적용 가능 |
| 11 | **연계 윈도우 프레임 의존** | 낮음 | `_VIPER_WALL_DIVE_READY_FRAMES = 90`이 60fps 가정. 프레임 레이트가 다르면 윈도우 시간이 변함 |

---

## 10. 파일별 코드 분포

| 파일 | 기능 | 주요 라인 범위 |
|------|------|---------------|
| `pingfighter.py` | 스킬 정의 | 3686~3890 |
| `pingfighter.py` | 퍽 정의 | 13226~13266 |
| `pingfighter.py` | 플레이어 포즈 | 33037~33125 |
| `pingfighter.py` | 넉백 면역 | 47430 |
| `pingfighter.py` | 상태 변수/상수 | 49196~49438 |
| `pingfighter.py` | 초기화/리셋 | 59235~59301 |
| `pingfighter.py` | 입력/발동 로직 | 73841~74101 |
| `pingfighter.py` | 페이즈 실행 | 74138~74521 |
| `pingfighter.py` | 에너지파 이동 | 74986~75026 |
| `pingfighter.py` | 패들 히트 연동 | 80336~80345 |
| `pingfighter.py` | 홀로그램 렌더링 | 108687~108770 |
| `pingfighter.py` | 오라/파티클 렌더링 | 109159~109464 |
| `pingfighter.py` | 프리즈 텍스트 | 117606~117667 |
| `pingfighter.py` | 스테이지 리셋 | 141679~141717 |
| `pingfighter.py` | 보스 넉백 | 149349~149354 |
| `sound_effects.py` | 사운드 경로 | 120, 124, 128 |
| `effects_manager.py` | 다크레드 임팩트 | 1063~1100 |

---

## 11. 실제 연계 플로우 (타임라인)

```
t=0.0s  대쉬 시작 (대쉬 출발점 기록)
        │
t=?     대쉬 중/직후 + S키 + 게이지≥100
        ├─→ [쉐도우 백스텝 발동] 게이지 -100, 쿨타임 15초
        │   텔레포트 + 홀로그램 + 에너지파 생성
        │
t=+0~0.5s  공 타격 (홀로그램/에너지파/패들 중 하나)
           _viper_ss_ball_touched = True
        │
t=+0.3s (타격 후 300ms)
        ├─→ [마샬 킥 윈도우 활성화] 1.5초 동안 S키 입력 대기
        │   (게이지≥80 + 쿨타임 조건 충족 시)
        │
t=+?    S키 입력 + 게이지≥80
        ├─→ [마샬 킥 발동] 게이지 -80, 쿨타임 25초
        │   Phase 0(점프) → 1(매달림) → 2(돌진) → 공 타격
        │   _viper_marshal_kick_hit_ball = True
        │
t=+0.2s (1차 타격 후 200ms)
        ├─→ [팬텀 킥 윈도우 활성화] 1.5초 동안 S키 입력 대기
        │   (퍽 해금 + 게이지≥60 + 쿨타임 조건)
        │
t=+?    S키 입력 + 게이지≥60
        ├─→ [팬텀 킥 발동] 게이지 -60, 쿨타임 40초
        │   Phase 0~2 (30% 빠르게) → 공 타격
        │   프리즈 1초 + 넉백 18.0 + "팬텀 킥" 텍스트
        │
t=+1.0s 프리즈 해제 → Phase 4(착지)

총 게이지 소모: 100 + 80 + 60 = 240
총 쿨타임: 15초 + 25초 + 40초 (각각 독립)
```

---

## 12. 모션↔발사 방향 자연스러움 분석

### 핵심 발견: 발차기 모션과 공 발사 방향이 물리적으로 분리되어 있다

세 스킬 모두 **발차기 포즈 방향**과 **공 발사 각도**를 독립적으로 계산한다.

### 12-1. 쉐도우 백스텝

```python
# 킥 방향 결정 (라인 73916) — 텔레포트 기준
_viper_ss_hologram_kick_dir = _ss_reverse_dir  # 텔레포트 출발↔도착 위치 비교

# 실제 공 발사각 (라인 49303~49317) — kick_dir 안 씀
_ss_base_bias = 0.2
init_angle = random * (1 - bias) + boss_avoidance * bias  # 보스 회피 편향
rad = math.radians(-90 + init_angle)
ball_vel[0] = math.cos(rad) * new_speed
ball_vel[1] = math.sin(rad) * new_speed
```

- `kick_dir`은 **커브 방향과 포즈 렌더링에만** 사용
- 초기 발사각은 보스 회피 편향 + 랜덤 ±55°로 별도 계산
- **결과**: 오른쪽으로 차는 포즈인데 공이 왼쪽으로 날아갈 수 있음

### 12-2. 마샬 킥 / 팬텀 킥

```python
# 플라잉 킥 포즈 방향 (라인 111979) — 벽 위치 기준
_fk_dir = 1 if _viper_wall_dive_wall_x < WIDTH // 2 else -1

# 실제 공 발사각 (라인 74358~74376) — 벽 방향과 무관
_mk_boss_dx = _mk_boss_cx - BALL.centerx
_mk_away_dir = -1 if _mk_boss_dx > 0 else 1  # 보스 반대쪽
_mk_final_angle = random * (1 - bias) + avoidance * bias
```

- 벽 기준 킥 포즈 vs 보스 회피 기준 발사각이 **독립 계산**
- 왼쪽 벽에서 오른쪽으로 차는 모션인데, 보스가 오른쪽에 있으면 공이 왼쪽으로 빠짐

### 12-3. 홀로그램 킥박스 판정 — 비주얼과 불일치

```python
# 렌더링: kick_dir 방향으로 고스트 8개 (라인 108722~108743)
# 충돌 박스: 좌우 대칭 확장 (라인 108748~108754)
_kick_rect = pygame.Rect(
    _holo_x - _holo_w // 2 - 30,    # 킥 방향 무관하게 좌측 30px
    _holo_y - _holo_h // 2 - 25,
    _holo_w + 60,                     # 양쪽 동일 60px 확장
    _holo_h + 50
)
```

발이 닿지 않는 반대쪽 공도 맞을 수 있다.

### 12-4. 방향 자연스러움 요약

| 스킬 | 모션↔공 방향 일치 | 심각도 | 설명 |
|------|-----------------|--------|------|
| 쉐도우 백스텝 | **불일치** | 중간 | kick_dir는 포즈/커브에만, 발사각은 랜덤+회피 |
| 마샬 킥 | **불일치** | 중간 | 벽 기준 포즈 vs 보스 회피 기준 발사각 독립 |
| 팬텀 킥 | **불일치** | 중간 | 마샬과 동일 + 더 높은 bias로 회피 치우침 커짐 |
| 홀로그램 판정 | **불일치** | 낮음 | 비주얼은 한쪽, 판정은 좌우대칭 |

> **체감 이슈 1순위**: 연출은 화려하지만 "이쪽으로 찼으니 저쪽으로 날아간다"는 직관적 읽힘이 약함.

---

## 13. 스킬 성능 분석

### 13-1. 게이지 경제

| 항목 | 값 |
|------|-----|
| 최대 게이지 | **500** (라인 11647, 아카데미/아이템 보너스 별도) |
| 풀 연계 비용 | 100+80+60 = **240 (48%)** |
| 게이지 자동 회복 | **없음** — 랠리 타격/아이템으로만 충전 |
| 풀 연계 가능 횟수 | 게이지 풀 상태에서 현실적으로 **1~2회** |

### 13-2. 속도 부스트 — 현재 공속 기반 배율 (주의!)

속도 계산은 **고정값이 아니라 현재 공속 × 배율**이다:

```python
# 마샬 킥 (라인 74352)
_wd_new_spd = _wd_cur_spd * 2.0 * _mk_speed_bonus  # 현재 공속 × 2.0
# 팬텀 킥 (라인 74354)
_wd_new_spd = _wd_cur_spd * 2.8 * _mk_speed_bonus  # 현재 공속 × 2.8
```

| 시점 | 현재 공속 | 마샬 킥 결과 | 팬텀 킥 결과 | 캡(60) 대비 |
|------|----------|-------------|-------------|-------------|
| 초기 랠리 | 9 | 18 | 25.2 | 30% / 42% |
| 중반 랠리 | 15 | 30 | 42 | 50% / 70% |
| 후반 랠리 | 20 | 40 | 56 | 67% / **93%** |
| 빠른 공 | 22+ | 44+ | **60 (캡)** | **100%** |

> **후반 랠리에서 팬텀 킥은 속도 캡에 근접하거나 도달할 수 있다.** 초기 기준 25.2는 최솟값일 뿐이다.
>
> 속도 캡: `MAX_BALL_SPEED = 60` (라인 2930)

### 13-3. 쿨타임 vs 매치 길이

| 항목 | 값 |
|------|-----|
| 매치 형식 | **5선승제** (라인 30613) |
| 예상 매치 시간 | **25~90초** |
| 쉐도우 백스텝 | 15초 — 매치당 2~5회 가능 |
| 마샬 킥 | 25초 — 매치당 1~3회 가능 |
| 팬텀 킥 | 40초 — 매치당 **1~2회** 가능 |
| 풀 연계 | 실질적으로 **매치당 1회** |

### 13-4. 골드 수익 비교

| 소스 | 골드 |
|------|------|
| 일반 랠리 히트 | 4~12 (속도 보너스 포함) |
| 쉐도우 백스텝 | 16 (공중 시 24) |
| 마샬 킥 | 30 (공중 SS 연계 시 45) |
| 팬텀 킥 | 50 (공중 SS 연계 시 75) |
| **풀 연계 합계** | **96 (공중: 144)** — 일반 히트 대비 **8~24배** |

### 13-5. 팬텀 킥 프리즈 상세

- **1초간 (60프레임) 공 + 보스 동시 정지**
- 게임 루프에서 `_viper_dmk_freeze_active` 체크 → ball/boss 물리 업데이트 스킵
- 프리즈 중 화면 흔들림 + "팬텀 킥" 텍스트 (80프레임) + 다크 파티클 궤도
- **현재 타이밍 이슈**: 프리즈가 돌진 전(Phase 6)에 먼저 발동 → 임팩트 히트스톱이 아닌 "예열 슬로모션" 체감

### 13-6. 팬텀 킥 보스 넉백 상세

```python
# 넉백 예약 (라인 74385) — 팬텀 킥이 공을 맞히는 순간
_viper_phantom_kick_knockback_pending = True

# 넉백 적용 (라인 149347~149350) — 공이 보스 패들에 닿을 때
boss_fire_knockback_vel = _dmk_kb_dir * 18.0

# 감쇠 (라인 150543) — 매 프레임
boss_fire_knockback_vel *= 0.85  # 15% 감속
# 벽 반사 시 (라인 150530): *= 0.7 (30% 에너지 손실)
```

| 항목 | 값 |
|------|-----|
| 초기 넉백 속도 | 18.0 px/frame |
| 매 프레임 감쇠 | ×0.85 |
| 이론상 누적 이동량 | Σ 18×0.85^n ≈ **120px** |
| 벽 반사 시 | 추가 30% 에너지 손실 |
| 발동 시점 | 즉시가 아닌, **공이 보스에 도달 시 적용** |

> 넉백은 "히트 즉시 540px 밀림"이 아니라, **공이 보스에 맞을 때 ~120px 밀림**이 정확하다.

### 13-7. 종합 밸런스 평가

```
    위험도        ████████████████████░░  높음 (게이지 48%, 빗나가면 큰 손해)
    보상          ████████████████████░░  높음 (최대 속도캡, 프리즈, 넉백, 골드 96~144)
    사용 빈도     ████░░░░░░░░░░░░░░░░░░  낮음 (매치당 1회 풀연계)
    조건 난이도   ████████████████░░░░░░  높음 (대쉬→SS→히트→300ms→MK→히트→200ms→PK)
```

**결론**: 하이리스크 하이리턴으로 밸런스 자체는 적절하나, **후반 랠리 팬텀 킥의 속도 캡 근접**이 밸런스 상한선에 가깝다.

---

## 14. 커브 상태 오염 버그

### 14-1. 문제 상세

쉐도우 백스텝은 `_viper_ps_curve_total_frames`와 `_viper_ps_curve_force`를 **그래디언트 기반으로 세팅**하지만,
마샬/팬텀 킥은 이 두 값을 **덮어쓰지 않는다.**

```python
# 쉐도우 백스텝 — 5개 전부 세팅 (라인 49320~49325)
_viper_ps_curve_active = True
_viper_ps_curve_timer = curve_frames           # ✅
_viper_ps_curve_total_frames = curve_frames    # ✅ 그래디언트 반영
_viper_ps_curve_force = curve_force            # ✅ 그래디언트 반영
_viper_ps_curve_direction = curve_dir          # ✅

# 마샬/팬텀 킥 — 3개만 세팅 (라인 74441~74447)
_viper_ps_curve_active = True
_viper_ps_curve_timer = ...                    # ✅ 새 값
_viper_ps_curve_direction = ...                # ✅ 새 값
# _viper_ps_curve_total_frames → ❌ 안 건드림!
# _viper_ps_curve_force → ❌ 안 건드림!
```

### 14-2. 커브 적용부에서의 영향 (라인 74545~74548)

```python
_curve_total = _viper_ps_curve_total_frames  # ← SS의 그래디언트 값이 남아있음!
_curve_progress = 1.0 - (_viper_ps_curve_timer / _curve_total)
_curve_rot_deg = (1.0 - _curve_progress) * _viper_ps_curve_force * 0.35
#                                            ↑ SS의 그래디언트 값이 남아있음!
```

### 14-3. 구체적 시나리오

| SS 타격 위치 | `total_frames` | `force` | 마샬/팬텀 커브 영향 |
|-------------|---------------|---------|-------------------|
| 중심부 타격 | 50 | 2.0 | 정상 (기본값과 동일) |
| 가장자리 타격 | 10 | 0.4 | **커브 극도로 약해짐** — progress 계산 왜곡 |
| 중간 타격 | 30 | 1.2 | 중간 정도 영향 |

**가장자리 타격 후 팬텀 킥**: timer=125(2.5배) / total=10(SS 잔여) → progress가 음수 또는 비정상 범위 → 커브 계산 완전 왜곡

### 14-4. 수정 방안

마샬/팬텀 킥 타격 시 (라인 74441 부근) `_viper_ps_curve_total_frames`와 `_viper_ps_curve_force`도 명시적으로 세팅:

```python
# 수정안
_viper_ps_curve_active = True
if _viper_is_double_marshal:
    _viper_ps_curve_timer = int(_VIPER_PS_CURVE_FRAMES * 2.5)
else:
    _viper_ps_curve_timer = _VIPER_PS_CURVE_FRAMES
_viper_ps_curve_total_frames = _viper_ps_curve_timer  # ← 추가 필요
_viper_ps_curve_force = _VIPER_PS_CURVE_FORCE          # ← 추가 필요
_viper_ps_curve_direction = 1 if ball_vel[0] > 0 else -1
```

---

## 15. 수정 우선순위 (코덱스 합의)

| 순위 | 작업 | 심각도 | 설명 |
|------|------|--------|------|
| 1 | **모션↔발사각 연결** | 중간 | 발차기 방향을 발사각 계산에 반영하여 시각적 일관성 확보 |
| 2 | **커브 변수 완전 초기화** | 높음 | 마샬/팬텀 타격 시 `total_frames`와 `force`를 명시적으로 세팅 |
| 3 | **팬텀 프리즈 타이밍** | 중간 | 돌진 전 예열이 아닌 히트 순간 프리즈로 변경 |
| 4 | **퍽/툴팁 수치 정정** | 낮음 | "게이지 50"→60, "공속 120%"→180% 등 코드와 일치시키기 |
