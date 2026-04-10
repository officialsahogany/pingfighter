# 구슬 UI 파이드로잉 코드 리뷰 문서

> **파일**: `pingfighter.py`  
> **핵심 함수**: `draw_player_gauge()` (L100458~L105275)  
> **작성일**: 2026-04-05  
> **목적**: 스페셜게이지 구슬(좌측), 대쉬토큰 구슬(우측), 보스 대쉬토큰 구슬(우측 상단) 의 파이게임 드로잉 코드 구조 정리

---

## 1. 아키텍처 개요

### 1.1 렌더링 파이프라인

```
draw_player_gauge()  (L100458)
├── [전체화면 모드] 별도 Surface에 그림 → 필러에 blit
│   ├── _player_gauge_surface_left  (250×650)  ← 스페셜 게이지 구슬 (좌측 필러)
│   ├── _player_gauge_surface       (240×320)  ← 대쉬 토큰 구슬 (우측 필러)
│   └── _player_gauge_surface_top   (240×320)  ← 보스/영웅 대쉬 토큰 구슬 (우측 상단)
└── [일반 모드] SCREEN에 직접 그림 (세로 바 형태)
```

### 1.2 구슬 종류 비교표

| 속성 | 스페셜 게이지 구슬 | 대쉬 토큰 구슬 (플레이어) | 보스 대쉬 토큰 구슬 |
|------|-------------------|------------------------|-------------------|
| **위치** | 좌측 필러 하단 | 우측 필러 하단 | 우측 필러 상단 |
| **색상 테마** | 파란색 계열 | 빨간색 계열 | 보라색 계열 |
| **캐시 딕셔너리** | `_blue_orb_cache` | `_red_orb_cache` | `_boss_orb_static_base/top` |
| **반지름** | 55px | 55px | 55px (동적 동기화) |
| **프레임 두께** | 10px | 10px | 10px |
| **스터드 수** | 8개 (파란 보석) | 8개 (빨간 보석) | 8개 (보라 보석) |
| **채우기 방식** | 액상 물결 (연속) | 섹터 분할 (토큰 단위) | 섹터 분할 (토큰 단위) |
| **표시 데이터** | `displayed_gauge / max_gauge` | `rolling_charges / max_tokens` | `boss_available / boss_max_tokens` |
| **코드 범위** | L100556~L101064 | L103615~L105222 | L104926~L105197 |

---

## 2. 스페셜 게이지 구슬 (파란색, 좌측 필러)

### 2.1 레이어 스택 (렌더링 순서)

```
[최상위]
  8. 킥차저/충전 애니메이션 글로우 (조건부)  L100895~L100944
  7. 수치 텍스트 "현재/최대" (Pretendard-Bold 16px)  L101051~L101064
  6. 글래스 오버레이 (캐시) + 볼트 4개  L100891~L100893
  5. 기포 파티클 5개 (액체 내부)  L100872~L100889
  4. 수면 글로우 라인 (물결선 위 빛)  L100849~L100870
  3. 액상 채우기 (물결 모양 클리핑)  L100796~L100847
  2. 별빛 파티클 12개 (구슬 내부)  L100780~L100794
  1. 프레임 + 배경 그라데이션 (캐시)  L100632~L100778
  0. 외곽 글로우 (맥동 펄스)  L100766~L100773
[최하위]
```

### 2.2 캐시 구조 (`_blue_orb_cache`)

캐시 키가 `orb_radius` 변경 시에만 재생성됨 (L100638 조건 체크).

```python
_blue_orb_cache = {
    "radius": int,         # 캐시 유효성 검사용
    "frame": Surface,      # 프레임 정적 레이어 (그림자+테두리+스터드+다이아몬드)
    "bg": Surface,         # 배경 원형 그라데이션 (어두운 남색)
    "glass": Surface,      # 글래스 오버레이 (하이라이트+림+볼트)
    "fills": {             # 4단계 채우기 그라데이션
        "gold": Surface,   # gauge_ratio >= 1.0 (황금색)
        "high": Surface,   # gauge_ratio >= 0.7 (밝은 파랑)
        "mid":  Surface,   # gauge_ratio >= 0.3 (중간 파랑)
        "low":  Surface,   # gauge_ratio <  0.3 (어두운 파랑)
    }
}
```

### 2.3 프레임 드로잉 상세 (L100642~L100694)

```
프레임 구성:
├── 그림자 (4겹 원, alpha 60→15, 오프셋 +2,+3)
├── 베이스 원 (45,35,20) → 반지름 = orb_radius + frame_width
├── 테두리선 3중 (외곽→내곽: 금색→갈색→금색)
├── 베벨 아크 2개 (상단 하이라이트, 하단 그림자)
├── 스터드 8개 (45도 간격, 12시 방향 시작)
│   └── 6중 동심원: 외곽 갈색(6px) → 금색(5px) → 밝은금(4px) → 파랑(3px) → 밝은파랑(2px) → 하이라이트(1px)
├── 다이아몬드 장식 8개 (스터드 사이)
│   └── 폴리곤 + 외곽선 + 작은 점 2개
└── 내부 경계선 2중 (어두운 테두리)
```

### 2.4 채우기 (액상 효과) 상세 (L100796~L100889)

```python
# 물결 수면 계산
wave_y = fill_top + sin(x * 0.08 + time * 0.003) * 1.8 + sin(time * 0.002) * 1.5

# 채우기 높이
fill_height = orb_radius * 2 * gauge_ratio
fill_top = orb_center_y + orb_radius - fill_height
```

**물결 클리핑 메커니즘**:
1. 캐시된 채우기 그라데이션 Surface 복사
2. 물결 곡선 좌표 계산 (x 픽셀 단위)
3. 물결선 위쪽 영역을 투명 폴리곤으로 마스킹 (`BLEND_RGBA_SUB`)
4. 결과를 구슬 위치에 blit

**기포 파티클**: 5개, 수면 아래만 표시, 구슬 경계 내 클리핑, 흰색 하이라이트 점 포함

### 2.5 부가 효과

- **킥차저 충전 글로우** (L100895~L100944): `gauge_charge_animation_timer > 0` 일 때 황금빛 4겹 글로우 링 + 파티클 + "+XX" 텍스트
- **수치 텍스트** (L101051): 구슬 중앙에 `"현재/최대"`, 4방향 그림자
- **캐릭터별 스킬 아이콘**: 구슬 주변에 반원형 배치 (L100973~L101049)
  - 스매셔: `_draw_smasher_skill_icons()`
  - 바이퍼: `_draw_viper_skill_icons()`
  - 코만도: `draw_pillar_weapon_inventory()` + `_draw_soldier_skill_icons()`
  - 발토르: `draw_pillar_blacksmith_turret()` + `draw_pillar_blacksmith_divine()` + `_draw_blacksmith_skill_icons()`

---

## 3. 대쉬 토큰 구슬 (빨간색, 우측 필러)

### 3.1 레이어 스택

```
[최상위]
  7. 수치 텍스트 "현재/최대" (Pretendard-Bold 16px)  L105205~L105222
  6. 글래스 오버레이 (캐시)  L103774~L103787
  5. 분할선 (토큰 경계, 금색 그라데이션)  ~L104050 부근
  4. 섹터별 채우기 (토큰 상태별)  L103810~L103909
  3. 내부 파티클 10개 (주황-빨강)  L103794~L103808
  2. 프레임 (캐시) + 쉐도우+배경 (캐시)  L103701~L103787
  1. 외곽 글로우 (생성 애니메이션 중만)  L103628~L103651
  0. 파티클 효과 (생성 애니메이션 중만)  L103653~L103663
[최하위]
```

### 3.2 캐시 구조 (`_red_orb_cache`)

```python
_red_orb_cache = {
    "radius": int,           # 캐시 유효성 검사용
    "shadow_bg": Surface,    # 그림자 + 배경 그라데이션 (어두운 적갈색)
    "frame": Surface,        # 프레임 (테두리+스터드+삼각형 돌기)
    "glass": Surface,        # 글래스 오버레이 (하이라이트+림)
}
```

### 3.3 프레임 차별점 (vs 스페셜 게이지)

| 요소 | 스페셜 게이지 (파랑) | 대쉬 토큰 (빨강) |
|------|---------------------|-----------------|
| 프레임 색상 | 갈색/금색 `(45,35,20)` | 어두운 갈색/적색 `(35,25,25)` |
| 스터드 보석 색 | 파랑 `(30,80,160)` → `(80,150,240)` | 빨강 `(160,30,30)` → `(220,60,60)` |
| 장식 형태 | **다이아몬드** (4각 폴리곤) | **삼각형 돌기** (3각 폴리곤, 6px 돌출) |
| 베벨 하이라이트 | `(220,200,140)` | `(200,175,165)` |
| 내부 파티클 색 | `(100,180,255)` 파랑 | `(255,120,80)` 주황-빨강 |

### 3.4 섹터 채우기 로직 (L103810~L103909)

```
토큰 상태별 렌더링:
├── 충전됨 (is_available=True)
│   ├── 진한 빨강 (200,40,50) 폴리곤
│   └── 3겹 하이라이트 레이어 (alpha 80/60/40, 중심에서 30%/45%/60% 범위)
├── 충전중 (charge_progress > 0)
│   ├── [일반] 어두운→밝은 빨강 그라데이션 (progress 비례)
│   │   색상: (60+140*p, 20+20*p, 30+20*p)
│   ├── [부스트차징] 무지개색 HSV 순환
│   │   hue = (time*0.003 + progress*2) % 1.0
│   └── [토큰 1~2개] 아래→위로 차오르는 방식 (클리핑)
│       [토큰 3+개] 섹터 단위 폴리곤 채움
└── 비어있음 → 아무것도 그리지 않음 (배경만 보임)
```

**섹터 각도**: 12시(-90도) 시작, 시계방향, `360 / max_tokens` 균등분할  
**폴리곤 해상도**: 32포인트 + 중심점 = 33포인트/섹터

### 3.5 분할선 애니메이션 (L103665~L103689)

```python
_dash_orb_divider_state = {
    'prev_max_tokens': 1,          # 이전 최대 토큰 수
    'animation_progress': 1.0,     # 0.0→1.0 (600ms)
    'animation_start_time': 0,     # 트리거 시각
    'new_divider_indices': []      # 새로 추가되는 분할선 인덱스
}
```

토큰 수 증가 시 600ms 동안 새 분할선이 페이드인됨.

---

## 4. 보스 대쉬 토큰 구슬 (보라색, 우측 상단)

### 4.1 코드 위치 및 조건

- **코드**: L104926~L105197
- **조건**: `not arena_mode_enabled and not _skip_right_orb_drawing`
- **Surface**: `_player_gauge_surface_top`

### 4.2 캐시 구조

```python
# 정적 캐시 (반지름/Surface크기 변경 시 재생성)
_boss_orb_static_base   # 프레임 + 배경 그라데이션
_boss_orb_static_top    # 글래스 하이라이트 + 볼트 장식

# 재사용 Surface (매 프레임 fill(0,0,0,0) 후 재사용)
_boss_orb_reuse_glow         # 외곽 글로우
_boss_orb_reuse_sparkle      # 내부 파티클
_boss_orb_reuse_token_layer  # 토큰 하이라이트 폴리곤
_boss_orb_reuse_glow2        # 대쉬 가능 펄스 글로우

# 텍스트 캐시
_boss_orb_font_cached   # freetype.Font 인스턴스
_boss_orb_text_cache     # {"0/1": (text_surf, shadow_surf), ...}

# 분할선 캐시
_boss_orb_div_cache     # 분할선 Surface
_boss_orb_div_max       # 캐시 유효성 검사용
```

### 4.3 색상 테마

```python
_boss_empty_color     = (30, 15, 50)    # 빈 구슬 배경
_boss_full_color      = (140, 60, 200)  # 채워진 섹터
_boss_frame_dark      = (25, 15, 40)    # 프레임 베이스
_boss_frame_light     = (70, 40, 100)   # 프레임 테두리
_boss_frame_highlight = (120, 80, 160)  # 프레임 하이라이트
# 스터드: (120,40,180) → (180,80,240) → (220,180,255) 보라색 계열
```

### 4.4 레이어 스택

```
[최상위]
  10. 토큰 카운트 텍스트 (캐시)  L105181~L105195
   9. 펄스 글로우 (대쉬 가능 시, sin(time*0.004))  L105172~L105179
  7+8. 글래스+볼트 (정적 캐시)  L105169~L105170
   6. 분할선 (토큰 1개 초과 시, 캐시)  L105140~L105167
   5. 섹터별 토큰 상태  L105084~L105138
   4. 내부 파티클 10개 (보라색)  L105068~L105082
  2+3. 정적 베이스 (프레임+배경, 캐시)  L105065~L105066
   1. 외곽 글로우 (보라색 펄스, sin(time*0.0035))  L105055~L105063
```

### 4.5 보스 토큰 판정 로직

```python
_boss_available = 1 if (
    boss_special_gauge >= BOSS_DASH_GAUGE_COST  # 게이지 충분
    and not boss_on_cooldown                     # 쿨타임 아님
    and not boss_dashing                         # 현재 대쉬 중 아님
    and boss_dash_stun_timer <= 0                # 스턴 아님
) else 0

# 충전 진행률 (쿨다운 기반)
_boss_charge_progress = 1.0 - (remaining_ms / total_cooldown_ms)
```

---

## 5. 생성/접기 애니메이션 시스템

### 5.1 상태 딕셔너리 (L30575~L30599)

```python
_orb_spawn_animation = {
    'active': bool,           # 펼침 애니메이션 활성
    'start_time': int,        # 시작 시각 (ms)
    'duration': 4000,         # 전체 지속시간 4초
    
    # 좌측 (게이지 구슬)
    'left_phase': 0~4,        # 0:대기 1:나타남 2:확장 3:안정화 4:완료
    'left_scale': 0.0~1.0,    # 크기 배율
    'left_alpha': 0~255,      # 투명도
    'left_glow': 0.0~1.0,     # 글로우 강도
    'left_particles': [],      # 파티클 리스트
    
    # 우측 (토큰 구슬) — 동일 구조
    'right_phase/scale/alpha/glow/particles': ...,
    
    # 접기
    'collapse_active': bool,
    'collapse_start_time': int,
    'collapse_duration': 1500,  # 1.5초
    'collapsed': bool,          # 접기 완료 (True면 구슬 숨김)
}
```

### 5.2 타이밍

```
전체 duration = 4000ms

좌측 구슬 (스페셜 게이지):
  시작: 0ms (0%)  →  완료: 2800ms (70%)
  
우측 구슬 (대쉬 토큰):
  시작: 600ms (15%)  →  완료: 3400ms (85%)
  
접기 (양쪽 동시):
  duration: 1500ms (펼침의 37.5%)
```

### 5.3 이징 함수 (L100661~L100673)

```python
# 탄성 바운스 이징
if progress < 0.5:
    eased = 2 * progress^2                    # 가속
else:
    eased = 0.5 + 0.5 * (1 - (1-2t)^3)       # 감속
    if 0.6 < progress < 0.8:
        eased += 0.15 * sin(...)              # 오버슈트 (최대 1.15)
    elif progress >= 0.8:
        eased = 1.0 + 0.05 * sin(...)         # 미세 진동
```

### 5.4 관련 함수

| 함수 | 위치 | 역할 |
|------|------|------|
| `start_orb_spawn_animation()` | L30615 | 펼침 시작 (인게임 진입 시) |
| `update_orb_spawn_animation()` | L30635 | 매 프레임 상태 업데이트 |
| `get_orb_spawn_animation_state()` | L30758 | 현재 상태 반환 |
| `is_orb_spawn_animation_active()` | L30762 | 활성 여부 |
| `start_orb_collapse_animation()` | L30766 | 접기 시작 (게임 종료 시) |
| `set_ingame_active(bool)` | L30606 | 인게임 플래그 설정 |
| `is_ingame_active()` | L30611 | 인게임 여부 확인 |

---

## 6. 캐시 전략 요약

### 6.1 캐시됨 (정적 - radius 변경 시만 재생성)

| 요소 | 재생성 조건 |
|------|------------|
| 프레임 (테두리+스터드+장식) | `_blue/red_orb_cache["radius"] != orb_radius` |
| 배경 그라데이션 | 위와 동일 |
| 글래스 오버레이 | 위와 동일 |
| 채우기 그라데이션 4티어 (파랑만) | 위와 동일 |
| 보스 분할선 | `_boss_orb_div_max != max_tokens` |
| 보스 텍스트 | `count_text not in _boss_orb_text_cache` |

### 6.2 매 프레임 렌더링 (동적)

| 요소 | 이유 |
|------|------|
| 외곽 글로우 펄스 | `sin(time)` 기반 알파 변화 |
| 내부 별빛/파티클 | 위치가 `sin(time)` 으로 이동 |
| 물결 수면 + 기포 | 물결 곡선 + 기포 위치 변화 |
| 섹터 채우기 (토큰) | 충전 progress 실시간 반영 |
| 수치 텍스트 | 게이지/토큰 수 변화 반영 |
| 충전 글로우 | 충전 이벤트 시 한시적 |

### 6.3 재사용 Surface (보스 구슬 전용)

보스 구슬은 `fill((0,0,0,0))` 후 재사용하는 Surface 4개를 사전 할당하여 매 프레임 `pygame.Surface()` 생성을 방지함.

---

## 7. 전체 좌표 체계

```
좌측 필러 Surface (_player_gauge_surface_left: 250×650)
┌──────────────────────────────┐
│  [스킬 아이콘/화기류 인벤토리]   │  ← 상단 (캐릭터별)
│           ...                 │
│                               │
│         ┌─────────┐           │
│         │ 게이지  │           │  ← orb_center = (125, 580)
│         │  구슬   │           │     radius = 55
│         └─────────┘           │     frame = 10
│                               │
└──────────────────────────────┘

우측 필러 Surface (_player_gauge_surface: 240×320)
┌──────────────────────────────┐
│                               │
│                               │
│     ┌─────────┐               │
│     │ 대쉬    │               │  ← orb_center = (80, 250)
│     │ 토큰    │               │     radius = 55
│     │  구슬   │               │     frame = 10
│     └─────────┘               │
│                               │
└──────────────────────────────┘

우측 필러 Surface Top (_player_gauge_surface_top: 240×320)
┌──────────────────────────────┐
│                               │
│     ┌─────────┐               │
│     │  보스   │               │  ← orb_center = (80, 70)
│     │ 토큰    │               │     radius = 55
│     │  구슬   │               │     frame = 10
│     └─────────┘               │
│                               │
└──────────────────────────────┘
```

---

## 8. draw_player_gauge() 함수 내부 흐름도

```
draw_player_gauge() 진입 (L100458)
│
├── [가드] _is_ingame_active == False → return
├── [가드] collapse_active or collapsed → return
│
├── 전체화면 판정 → _gauge_using_separate_surface 설정
│   ├── True: 별도 Surface 3개 생성, draw.screen 교체
│   └── False: SCREEN 직접 사용
│
├── [전체화면] 좌측 게이지 구슬 그리기 (L100556~L101064)
│   ├── 애니메이션 스케일 적용
│   ├── 캐시 유효성 체크 → 필요시 재생성
│   ├── 레이어 0~8 순서대로 렌더링
│   ├── 캐릭터별 스킬 아이콘 렌더링
│   └── 수치 텍스트 렌더링
│
├── [일반모드] 기존 세로 바 게이지 그리기 (L101066~)
│
├── SCREEN 복원 (draw.screen, SCREEN 원래대로)
│
├── [전체화면] 우측 대쉬 토큰 구슬 그리기 (L103590~L105222)
│   ├── 애니메이션 스케일 적용
│   ├── 캐시 유효성 체크 → 필요시 재생성
│   ├── 섹터별 토큰 상태 렌더링
│   ├── 분할선 애니메이션
│   ├── 호위무사 구슬 (조건부)
│   ├── 위험감지벨트 센서 구슬 (조건부)
│   ├── 투기장 상단 영웅 토큰 구슬 (조건부)
│   ├── 아케이드 보스 토큰 구슬 (조건부)
│   └── 수치 텍스트 렌더링
│
├── [일반모드] 기존 원형 토큰 그리기 (L105244~)
│
└── 함수 종료
```

---

## 9. 주요 상수/변수 참조

### 9.1 구슬 관련

```python
orb_radius_base = 55        # 기본 반지름 (px)
_frame_w = 10               # 프레임 두께 (px)
_num_studs = 8              # 스터드 보석 개수
orb_center_x = surface_width // 2   # 좌측: 125, 우측: 80
orb_center_y = surface_height - 55 - 15   # 하단 정렬 (15px 여백)
```

### 9.2 파티클 파라미터

| 파티클 | 개수 | 속도 계수 | 색상 |
|--------|------|----------|------|
| 별빛 (파랑 구슬) | 12개 | `time*0.001` | `(100,180,255)` |
| 내부 (빨강 구슬) | 10개 | `time*0.0012` | `(255,120,80)` |
| 내부 (보스 구슬) | 10개 | `time*0.0012` | `(180,120,255)` |
| 기포 (파랑 구슬) | 5개 | `time*0.001` | `(200,230,255)` + 흰 점 |
| 생성 파티클 (좌) | 동적 | `random 1~3` | `(100,150,255)` |
| 생성 파티클 (우) | 동적 | `random 1~3` | `(255,100,100)` |

### 9.3 애니메이션 주기

| 효과 | 수식 | 주기 |
|------|------|------|
| 외곽 글로우 (파랑) | `sin(time*0.003)` | ~2.1초 |
| 외곽 글로우 (보스) | `sin(time*0.0035)` | ~1.8초 |
| 물결 X축 | `sin(x*0.08 + time*0.003)` | ~2.1초 |
| 물결 Y축 느린 이동 | `sin(time*0.002)` | ~3.1초 |
| 보스 펄스 글로우 | `sin(time*0.004)` | ~1.6초 |
| 링 효과 (생성 중) | `time % 1000` | 1초 |
| 부스트차징 HSV | `time*0.003` | ~2.1초/회전 |

---

## 10. 의존성 맵

```
draw_player_gauge()가 참조하는 외부 상태:
├── game_state.special_gauge → displayed_gauge (보간된 값)
├── get_max_gauge() → current_max_gauge (악마의 주사위 효과 포함)
├── rolling_charges → 현재 사용 가능한 대쉬 토큰 수
├── max_tokens → 최대 대쉬 토큰 수 (아카데미 스킬 영향)
├── _charging_state → 현재 충전 중인 토큰 인덱스
├── _token_charge_states → 각 토큰별 충전 타이머/최대시간
├── selected_character_type → 캐릭터별 UI 분기
├── _is_fullscreen_active → 전체화면/일반 모드 분기
├── gauge_charge_animation_timer/amount → 충전 이펙트
├── boss_special_gauge, boss_dash_cooldown_* → 보스 토큰 상태
├── arena_mode_enabled → 투기장/아케이드 모드 분기
└── _orb_spawn_animation → 생성/접기 애니메이션 상태
```
