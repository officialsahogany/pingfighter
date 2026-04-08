# PingFighter Performance Optimization Code Review
> Codex Code Review Document | 2026-04-09 | feature/refactor-ui

---

## 1. Overview

PingFighter는 Pygame 기반 아케이드 게임으로, 25,000줄 이상의 메인 파일(`pingfighter.py`)과 다수의 배경/필러/이펙트 렌더링 모듈로 구성됨.
프레임드랍 방지를 위해 **10개 이상의 최적화 전략**이 코드베이스 전반에 적용되어 있음.

### 최적화 카테고리 요약

| # | 카테고리 | 적용 파일 수 | 핵심 전략 |
|---|---------|-------------|----------|
| 1 | [플랫폼별 렌더러/VSync 설정](#2-플랫폼별-렌더러vsync-설정) | 3 | Direct3D, VSync, DOUBLEBUF |
| 2 | [Surface 캐싱 시스템](#3-surface-캐싱-시스템-핵심) | 1 (메인) | 10종 이상 전용 캐시 딕셔너리 |
| 3 | [Surface 풀링](#4-surface-풀링-object-pooling) | 3+ | SRCALPHA Surface 재사용 |
| 4 | [사전 렌더링(Prerender)](#5-사전-렌더링prerendering) | 5+ | 정적 요소 init 시 1회 생성 |
| 5 | [프레임 스킵 렌더링](#6-프레임-스킵-렌더링) | 1 (메인) | 2~3프레임 간격 갱신 |
| 6 | [시간 캐싱 & 프레임 카운터](#7-시간-캐싱--프레임-카운터) | 1 (메인) | get_ticks() 1회 호출 |
| 7 | [값 양자화(Bucketing)](#8-값-양자화bucketing) | 1 (메인) | 글로우/알파/스케일 버킷화 |
| 8 | [리소스 캐시 (LRU)](#9-리소스-캐시-lru) | 1 | 이미지 50 / 사운드 30 / 폰트 20 |
| 9 | [자동 품질 조절](#10-자동-품질-조절-시스템) | 1 | FPS 기반 파티클/이펙트/그림자 토글 |
| 10 | [프로파일링 시스템](#11-프로파일링--모니터링) | 2 | 실시간 FPS/메모리/섹션 타이밍 |

---

## 2. 플랫폼별 렌더러/VSync 설정

### 2.1 Windows 초기화 (`pingfighter.py:38-44`)
```python
# Windows: 창모드 프레임드랍 방지 (노트북 내장/외장 GPU 전환 + VSync)
if sys.platform == 'win32':
    os.environ.setdefault('SDL_RENDER_DRIVER', 'direct3d')   # Direct3D 렌더러
    os.environ.setdefault('SDL_RENDER_VSYNC', '1')           # VSync 활성화
    os.environ.setdefault('SHIM_MCCOMPAT', '0x800000001')    # NVIDIA Optimus: 고성능 GPU
```

**목적**: 노트북 환경에서 내장 GPU 대신 외장 GPU 사용 유도 + VSync로 티어링 방지

### 2.2 디스플레이 플래그 (`core/game_core.py:86-90`)
```python
flags = pygame.DOUBLEBUF                    # 더블 버퍼링
if self.config.fullscreen:
    flags |= pygame.FULLSCREEN
if self.config.vsync:
    flags |= pygame.HWSURFACE              # 하드웨어 가속 Surface
```

### 2.3 FPS 상수 (`config/constants.py:100-102`)
```python
TARGET_FPS = 60    # 목표 FPS
MIN_FPS = 30       # 최소 허용 FPS (이하 시 최적화 발동)
MAX_FPS = 120      # 최대 FPS 캡
```

### Review Notes
- `SHIM_MCCOMPAT` 환경변수는 일부 시스템에서만 효과가 있으며, `NvOptimusEnablement` DLL export도 고려할 수 있음
- `HWSURFACE`는 SDL2에서 대부분 무시됨 (SDL1 호환성) - 실질적 효과 제한적
- `DOUBLEBUF`는 올바르게 적용됨

---

## 3. Surface 캐싱 시스템 (핵심)

### 3.1 범용 캐시 선언 (`pingfighter.py:543-560`)
```python
# 매 프레임 Surface 생성을 방지하여 FPS 향상
_surface_cache = {}              # 범용 Surface 캐시
_scale_cache = {}                # transform.scale 결과 캐시
_glow_surface_cache = {}         # 글로우 이펙트 Surface 캐시
_predrawn_glow_cache = {}        # 사전 렌더링된 glow 원 캐시 (크기/색상/알파 버킷)
_font_cache = {}                 # 폰트 객체 캐시 (매 프레임 SysFont 생성 방지)
_static_text_cache = {}          # 정적 텍스트 Surface 캐시
_water_trail_cache = {}          # 물자국 타원 캐시 (크기/알파 버킷)
_pachinko_cache = {}             # 파칭코 UI 캐시
_overlay_cache = {}              # 전체화면 오버레이 캐시 (알파별 사전 렌더링)
_boss_hp_gradient_cache = {}     # 보스 HP바 그라데이션 캐시
_trail_point_cache = {}          # 에너지 트레일 포인트 캐시
_wall_impact_cache = {}          # 벽 충돌 이펙트 캐시
_gauge_gradient_cache = {}       # 게이지바 그라데이션 캐시
_gold_hud_cache = None           # 골드 HUD 캐시
_gold_hud_cached_value = -1      # 캐시된 골드 값
_gold_hud_scaled_cache = {}      # 스케일된 골드 HUD 캐시
_CACHE_MAX_SIZE = 500            # 캐시 최대 크기 (메모리 관리)
```

**총 16종의 전용 캐시** - 각각 특정 렌더링 작업의 중복 Surface 생성을 방지

### 3.2 보스/플레이어 오브 UI 캐시 (`pingfighter.py:3516-3544`)
```python
_top_orb_div_cache = None          # 분할선 캐시
_top_orb_div_max = -1              # 캐시 유효성 검사용
_top_orb_font_cached = None        # freetype 폰트 캐시 (파일 I/O 방지)
_top_orb_text_cache = {}           # 텍스트 Surface 캐시 {text: (main, shadow)}
_top_orb_reuse_glow = None         # 재사용 외곽 글로우 Surface
_top_orb_reuse_sparkle = None      # 재사용 파티클 Surface
# === 게이지 스케일링 캐시 ===
_gauge_scaled_cache = None          # 우측 하단 게이지 스케일 캐시
_gauge_top_scaled_cache = None      # 우측 상단 게이지 스케일 캐시
_gauge_left_scaled_cache = None     # 좌측 게이지 스케일 캐시
_top_orb_reuse_token_layer = None   # 재사용 토큰 글로우 레이어
_top_orb_reuse_glow2 = None         # 재사용 펄스 글로우 Surface
# === 보스 대쉬 토큰 구슬 캐시 ===
_boss_orb_static_base = None        # 정적 레이어 캐시 A (프레임+배경)
_boss_orb_static_top = None         # 정적 레이어 캐시 B (글래스+볼트)
_boss_orb_cached_radius = -1        # 캐시 유효성 검사용 반지름
_boss_orb_reuse_glow = None
_boss_orb_reuse_sparkle = None
_boss_orb_reuse_token_layer = None
_boss_orb_reuse_glow2 = None
_boss_orb_font_cached = None
_boss_orb_text_cache = {}
_boss_orb_div_cache = None
```

**전략**: 정적 요소(프레임, 배경)를 `static_base`/`static_top`에 캐싱, 동적 요소(글로우, 파티클)만 매 프레임 갱신. `_reuse_*` 접두사 Surface는 매 프레임 `fill(0,0,0,0)`으로 초기화 후 재사용.

### 3.3 패들 스케일링 캐시 (`pingfighter.py:845-871`)
```python
_paddle_scale_cache = {}
_paddle_rotate_cache = {}
_PADDLE_CACHE_MAX_SIZE = 100

def get_scaled_paddle(base_img, scale_ratio, char_type=""):
    quantized_scale = round(scale_ratio, 2)  # 0.01 단위 양자화
    cache_key = (id(base_img), quantized_scale, char_type)
    if cache_key not in _paddle_scale_cache:
        if len(_paddle_scale_cache) > _PADDLE_CACHE_MAX_SIZE:
            keys_to_remove = list(_paddle_scale_cache.keys())[:_PADDLE_CACHE_MAX_SIZE // 2]
            for k in keys_to_remove:
                del _paddle_scale_cache[k]
        _paddle_scale_cache[cache_key] = pygame.transform.scale(base_img, (new_width, new_height))
    return _paddle_scale_cache[cache_key]
```

**전략**: `transform.scale()`은 비용이 큰 연산 → 스케일 값을 0.01 단위로 양자화하여 캐시 적중률 극대화. 캐시 초과 시 절반 삭제 (LRU 근사).

### 3.4 이미지 사전 로드 & convert (`pingfighter.py:1016-1036`)
```python
"""자주 사용되는 게임 이미지를 미리 로드하고 convert()"""
img = pygame.image.load(img_path)
if img.get_alpha() is not None:
    img.convert_alpha()     # 알파 채널 있는 이미지
else:
    img.convert()           # 불투명 이미지
```

**목적**: `convert()`/`convert_alpha()`는 Surface 픽셀 포맷을 디스플레이와 일치시켜 blit 속도를 **2~5배** 향상시킴

### Review Notes
- 16종의 개별 캐시 딕셔너리는 관리 복잡도가 높음 → 통합 캐시 매니저로 리팩토링 고려
- `_CACHE_MAX_SIZE = 500`이 모든 캐시에 개별 적용되는지 공유되는지 불명확
- 패들 캐시의 절반 삭제 전략은 O(n) 복잡도 → `collections.OrderedDict` 기반 LRU가 더 효율적
- `_gold_hud_cached_value` 패턴 (값 비교 기반 무효화)은 좋은 패턴

---

## 4. Surface 풀링 (Object Pooling)

### 4.1 필러 Surface 풀 (`pillar_blazing_sun.py:18-28`, `pillar_hongryeon.py:16-26`)
```python
_blazing_surface_pool = {}

def _get_pooled_surface(w, h):
    """재사용 가능한 SRCALPHA Surface 반환"""
    key = (w, h)
    if key not in _blazing_surface_pool:
        _blazing_surface_pool[key] = pygame.Surface((w, h), pygame.SRCALPHA)
    surf = _blazing_surface_pool[key]
    surf.fill((0, 0, 0, 0))    # 투명으로 초기화 후 재사용
    return surf
```

**적용 범위**:
- `pillar_blazing_sun.py`: 글로우/셀 이펙트 (2회/프레임)
- `pillar_hongryeon.py`: 불꽃/트레일/글로우 (9회/프레임)

**원리**: `pygame.Surface()` 생성은 메모리 할당 + 초기화 비용이 큼. 풀에서 가져와 `fill()`로 초기화하면 할당 비용 제거.

### 4.2 범용 ObjectPool (`optimization_patch.py:188-216`)
```python
class ObjectPool:
    def __init__(self, create_func, reset_func, initial_size=10):
        self.create_func = create_func
        self.reset_func = reset_func
        self.available = []
        self.in_use = []
        for _ in range(initial_size):
            self.available.append(create_func())

    def acquire(self):
        if not self.available:
            obj = self.create_func()
        else:
            obj = self.available.pop()
        self.in_use.append(obj)
        return obj

    def release(self, obj):
        if obj in self.in_use:
            self.in_use.remove(obj)     # O(n) - 개선 필요
            self.reset_func(obj)
            self.available.append(obj)
```

### Review Notes
- `ObjectPool.release()`의 `self.in_use.remove(obj)`는 **O(n)** → `set` 기반으로 변경 권장
- 필러 Surface 풀은 크기가 무한 증가 가능 → 최대 크기 제한 필요
- `fill((0,0,0,0))`은 대형 Surface에서 비용이 있음 → 작은 Surface 위주로 사용하는 것이 적절 (현재 올바르게 사용 중)

---

## 5. 사전 렌더링(Prerendering)

### 5.1 배경 Stage 30 - 모래 바닥/경기장/테두리 (`backgrounds/animated_background_stage30.py`)
```python
def __init__(self, ...):
    self._prerender_floor()    # line 235 - 6-옥타브 노이즈 텍스처 (320+ lines)
    self._prerender_arena()    # line 236 - 경기장 라인 (중앙선, 원, 코너)
    self._prerender_border()   # line 237 - 이집트 스타일 장식 테두리

def _prerender_floor(self):
    _sin = math.sin  # 로컬 참조로 속도 향상
    def multi_noise(x, y, seed=0):
        v = 0.0
        v += 0.30 * _sin(x * 0.019 + y * 0.014 + seed)
        # ... 6-옥타브 합성 ...
```

**핵심**: `math.sin`을 로컬 변수 `_sin`에 바인딩하여 글로벌 룩업 비용 제거 (Python 최적화 관용구)

### 5.2 콜로세움 관중 & 비네트 (`pillar_colosseum.py`)
```python
def _prerender_crowd(self):     # line 246
    self._crowd_cache = []
    for person in self.crowd_list:
        idle_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
        self._draw_person_to_surface(idle_surf, ...)    # idle 상태
        excited_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
        self._draw_person_to_surface(excited_surf, ...)  # 환호 상태
        self._crowd_cache.append({'idle': idle_surf, 'excited': excited_surf, ...})

def _prerender_vignette(self):  # line 412
    self._vignette_surface = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(vignette_size):
        alpha = int(20 * (1 - i / vignette_size))
        pygame.draw.line(...)   # 상단/하단 비네트
```

**관중**: idle/excited 2종 Surface를 사전 생성 → 런타임에 상태에 따라 blit만 수행

### 5.3 Stage 7 - 빛줄기 밴드 (`backgrounds/animated_background_stage7.py:78-84`)
```python
self._prerendered_band = pygame.Surface((self.band_width, self.band_height), pygame.SRCALPHA)
half = self.band_width / 2
for x in range(self.band_width):
    intensity = max(0.0, 1.0 - abs(x - half) / half)
    alpha = int(70 * (intensity ** 1.8))
    pygame.draw.line(self._prerendered_band, (120, 186, 255, alpha), (x, 0), (x, self.band_height))
```

### 5.4 Stage 2 - 정글 덤불 캐시 (`backgrounds/animated_background_stage2.py`)
```python
self._bush_cache = {}              # {bush_id: (surface, last_rustle_amount, offset)}
self._bush_cache_dirty = True      # 캐시 갱신 필요 여부
self._last_scale = (1.0, 1.0)     # 마지막 스케일 값 추적

def _prerender_bush_to_surface(self, bush, scale_x, scale_y):
    bush_surface = pygame.Surface((surf_width, surf_height), pygame.SRCALPHA)
    # ... 덤불 렌더링 로직 ...
    return bush_surface, offset

# 런타임 캐시 조회 (line 1778-1791)
cached = self._bush_cache.get(bush_id)
if cached is None or cached[1] != bush['rustle_amount']:
    bush_surface, offset = self._prerender_bush_to_surface(bush, scale_x, scale_y)
    self._bush_cache[bush_id] = (bush_surface, bush['rustle_amount'], offset)
```

**전략**: 덤불의 `rustle_amount`(흔들림 정도)가 변할 때만 Surface 재생성. 정적 상태에서는 캐시 blit.

### Review Notes
- 사전 렌더링은 가장 효과적인 최적화 - 복잡한 draw call 수백 회를 blit 1회로 대체
- Stage 30의 320+ 줄 노이즈 함수는 초기화 시간에 영향 → 로딩 화면과 병렬 처리 가능
- `_bush_cache_dirty` 플래그가 있지만 개별 bush ID 단위로도 체크 → 이중 검증이라 하나 제거 가능

---

## 6. 프레임 스킵 렌더링

### 6.1 필러 배경 30FPS 렌더링 (`pingfighter.py:8667-8678`)
```python
_pillar_bg_cache = None               # 캐시 Surface (.convert())
_pillar_bg_cache_dirty = True         # 재렌더링 필요 플래그
_pillar_bg_render_interval = 2        # 2프레임마다 렌더링 = 30FPS
_pillar_bg_frame_counter = 0          # 프레임 카운터
_pillar_bg_cache_stage = -1           # 스테이지 변경 감지

# 렌더링 시점 (line 9808)
if _pillar_bg_cache_dirty or _pillar_bg_frame_counter % _pillar_bg_render_interval == 0:
    pillar_renderer.draw(_pillar_bg_cache)
    _pillar_bg_cache_dirty = True
```

**원리**: 필러(좌우 80px 장식 패널)는 초당 30프레임으로도 시각적 차이가 거의 없음. 메인 게임은 60FPS 유지하면서 필러만 절반 속도로 갱신.

### 6.2 신성 방패 20FPS 갱신 (`pingfighter.py:51319-51322`)
```python
_divine_shield_frame_counter = 0
_divine_shield_last_dynamic_surf = None
_divine_shield_dynamic_cache_key = None
DIVINE_SHIELD_DYNAMIC_SKIP_FRAMES = 3    # 3프레임마다 1회 = 20FPS

# 사용 (line ~44080)
_divine_shield_frame_counter += 1
if _divine_shield_frame_counter >= DIVINE_SHIELD_DYNAMIC_SKIP_FRAMES:
    _divine_shield_frame_counter = 0
    # 동적 요소 (룬, 구체, 스파클) 재렌더링
```

### 6.3 대장간 청사진 30FPS 갱신 (`pingfighter.py:51315-51317`)
```python
_blacksmith_blueprint_frame_counter = 0
_blacksmith_last_blueprint_progress = {}
BLACKSMITH_BLUEPRINT_CACHE_SKIP_FRAMES = 2    # 2프레임마다 = 30FPS
```

### 6.4 Stage 8 잔상 생성 간격 (`pingfighter.py:31824-31835`)
```python
stage8_superspeed_trail_frame_counter = 0
def spawn_stage8_superspeed_movement_trail(boss_rect, boss_image):
    stage8_superspeed_trail_frame_counter += 1
    if stage8_superspeed_trail_frame_counter < STAGE8_SUPERSPEED_TRAIL_SPAWN_INTERVAL:
        return    # 간격 미달 시 생략
    stage8_superspeed_trail_frame_counter = 0
```

### 6.5 범용 프레임 스킵 (`optimization_patch.py:34-40`)
```python
def should_skip_frame(self, skip_rate=2):
    self.frame_skip_counter += 1
    if self.frame_skip_counter >= skip_rate:
        self.frame_skip_counter = 0
        return False    # 이번 프레임 렌더링
    return True         # 이번 프레임 스킵
```

### Review Notes
- 프레임 스킵은 CPU 바운드 렌더링에 매우 효과적
- 필러 30FPS / 방패 20FPS 전략은 적절한 균형점
- `_pillar_bg_cache_dirty`가 매 프레임 `True`로 설정되는 부분(line 9810)이 있어 캐시 효과가 감소할 수 있음 → 조건부 설정으로 변경 검토

---

## 7. 시간 캐싱 & 프레임 카운터

### 7.1 프레임당 1회 시간 조회 (`pingfighter.py:2904-2918`)
```python
_current_frame_ticks = 0      # 현재 프레임의 pygame.time.get_ticks() 값
_frame_counter = 0            # 프레임 카운터

def get_frame_ticks():
    """현재 프레임의 캐시된 시간 반환 (get_ticks() 대신 사용)"""
    return _current_frame_ticks

def get_frame_counter():
    """현재 프레임 카운터 반환 (시간 기반 애니메이션 대체용)"""
    return _frame_counter

# 사전 계산된 프레임 상수
HALF_SECOND_FRAMES = 30
ONE_SECOND_FRAMES = 60
TWO_SECONDS_FRAMES = 120
THREE_SECONDS_FRAMES = 180
```

### 7.2 메인 루프에서 갱신 (`pingfighter.py:161759-161761`)
```python
_current_frame_ticks = now_ms
_frame_counter += 1
```

**목적**: `pygame.time.get_ticks()`는 시스템 콜이므로 매 프레임 수십 회 호출 대신 **1회 호출 후 캐시**. 프레임 상수로 `time.get_ticks() - start > 500` 같은 비교를 `frame_counter % 30 == 0`으로 대체.

### Review Notes
- 프레임 카운터 기반 타이밍은 FPS 변동 시 실제 시간과 괴리 발생 가능
- 중요한 타이밍(게임 로직)은 `_current_frame_ticks` 사용, 시각적 애니메이션은 `_frame_counter` 사용이 적절
- `_frame_counter`의 오버플로우 처리가 없음 → 장시간 플레이 시 정수 오버플로우 가능 (Python은 bigint이므로 실질적 문제 없음)

---

## 8. 값 양자화(Bucketing)

### 8.1 글로우 이펙트 버킷 (`pingfighter.py:562-567`)
```python
# Glow 최적화용 버킷 (메모리 절약을 위해 유사한 값들을 그룹화)
_GLOW_SIZE_BUCKETS = (8, 12, 16, 20, 24, 32, 40, 48, 60, 80, 100, 120, 150, 200)  # 14단계
_GLOW_ALPHA_BUCKETS = (32, 64, 96, 128, 160, 192, 224, 255)                        # 8단계
_WATER_ALPHA_BUCKETS = (20, 40, 60, 80, 100)                                        # 5단계
```

**원리**: 글로우 크기 37px → 가장 가까운 버킷 40px로 반올림. 최대 캐시 조합 수 = 14 x 8 = **112개**로 제한. 버킷 없이는 수천 종의 미세하게 다른 Surface가 생성됨.

### 8.2 패들 스케일 양자화 (`pingfighter.py:853`)
```python
quantized_scale = round(scale_ratio, 2)    # 0.01 단위로 양자화
```

**효과**: scale_ratio 0.9234 → 0.92, 0.9278 → 0.93 등으로 그룹화하여 캐시 적중률 향상

### Review Notes
- 버킷 간격이 균등하지 않음 (8→12→16... 로그 스케일에 가까움) → 작은 글로우에서 더 세밀한 제어
- 알파 버킷 8단계는 시각적으로 충분한 수준
- `bisect` 모듈을 사용하면 버킷 매칭 성능을 O(log n)으로 개선 가능

---

## 9. 리소스 캐시 (LRU)

### 9.1 ResourceCache 클래스 (`managers/resource_manager.py:159-196`)
```python
class ResourceCache:
    def __init__(self, max_size: int = 100):
        self.cache: Dict[str, Any] = {}
        self.access_count: Dict[str, int] = {}
        self.max_size = max_size
        self.lock = threading.Lock()    # 스레드 안전

    def get(self, key):
        with self.lock:
            if key in self.cache:
                self.access_count[key] = self.access_count.get(key, 0) + 1
                return self.cache[key]
        return None

    def add(self, key, resource):
        with self.lock:
            if len(self.cache) >= self.max_size and key not in self.cache:
                lru_key = min(self.access_count, key=self.access_count.get)  # LFU 실제로
                del self.cache[lru_key]
                del self.access_count[lru_key]
            self.cache[key] = resource
            self.access_count[key] = 1
```

### 9.2 캐시 크기 설정
```python
self.image_cache = ResourceCache(max_size=50)    # 이미지
self.sound_cache = ResourceCache(max_size=30)    # 사운드
self.font_cache = ResourceCache(max_size=20)     # 폰트
```

### 9.3 TextureCache - 크기 기반 LRU (`core/performance_optimizer.py:136-195`)
```python
class TextureCache:
    def __init__(self, max_size_mb: float = 100):
        self.cache: Dict[str, pygame.Surface] = {}
        self.access_times: Dict[str, float] = {}     # 시간 기반 LRU
        self.max_size_mb = max_size_mb

    def add(self, key, surface):
        size_mb = (surface.get_width() * surface.get_height() * 4) / 1024 / 1024
        while self.current_size_mb + size_mb > self.max_size_mb and self.cache:
            self._evict_oldest()        # 시간 기반 제거
```

### Review Notes
- `ResourceCache`는 접근 **횟수** 기반 (LFU) - 이름은 LRU이지만 실제로는 Least Frequently Used
- `min(self.access_count, key=...)` 는 **O(n)** → `heapq` 또는 `OrderedDict` 로 O(1) 가능
- `TextureCache`는 접근 **시간** 기반 (진정한 LRU) - 두 캐시의 전략이 다름
- 100MB 텍스처 캐시 상한은 적절한 수준

---

## 10. 자동 품질 조절 시스템

### 10.1 FPS 기반 자동 조절 (`core/performance_optimizer.py:263-374`)
```python
class PerformanceOptimizer:
    def __init__(self):
        self.quality_level = 1.0      # 0.5 ~ 1.0
        self.reduce_particles = False
        self.reduce_effects = False
        self.reduce_shadows = False

    def _auto_adjust_quality(self):
        current_fps = 1.0 / avg_frame_time
        if current_fps < self.target_fps * 0.9:      # 54 FPS 이하
            self.decrease_quality()
        elif current_fps > self.target_fps * 1.1:     # 66 FPS 이상
            self.increase_quality()

    def decrease_quality(self):
        self.quality_level = max(0.5, self.quality_level - 0.1)
        if self.quality_level < 0.9: self.reduce_particles = True    # 파티클 끔
        if self.quality_level < 0.7: self.reduce_effects = True      # 이펙트 품질 저하
        if self.quality_level < 0.6: self.reduce_shadows = True      # 그림자 끔

    def increase_quality(self):
        self.quality_level = min(1.0, self.quality_level + 0.05)     # 복구는 느리게
```

**감소 속도 0.1 vs 복구 속도 0.05**: 성능 저하 시 빠르게 대응, 복구 시 천천히 → 진동(oscillation) 방지

### 10.2 프레임 스킵 판단 (`core/performance_optimizer.py:434-448`)
```python
def should_skip_frame(self) -> bool:
    if self.frame_times and len(self.frame_times) >= 2:
        last_frame_time = self.frame_times[-1]
        target_frame_time = 1.0 / self.target_fps
        return last_frame_time > target_frame_time * 2    # 33ms 초과 시 스킵
    return False
```

### 10.3 메모리 자동 정리 (`core/performance_optimizer.py:315-318`)
```python
# 5초마다 GC 실행
if current_time - self.memory_tracker.last_gc_time >= self.memory_tracker.gc_interval:
    self.memory_tracker.last_gc_time = current_time
    self.memory_tracker.force_cleanup()
```

### Review Notes
- 품질 조절이 실제 게임 코드에 통합되어 있는지 확인 필요 (`reduce_particles` 플래그를 실제로 체크하는 코드)
- 5초 주기 GC는 공격적 → GC `collect()`가 프레임 스파이크를 유발할 수 있음
- `psutil.cpu_percent(interval=0)`은 비차단이지만 정확도가 떨어짐 → 1초 이상 축적 추천
- 감소/복구 비대칭 속도는 좋은 설계

---

## 11. 프로파일링 & 모니터링

### 11.1 GameProfiler (`core/profiler.py`)
```python
class GameProfiler:
    def __init__(self, screen, enabled=True):
        self.metrics = PerformanceMetrics()
        # 임계값
        self.fps_warning = 50        # 50 FPS 이하 경고
        self.fps_critical = 30       # 30 FPS 이하 위험
        self.frame_time_warning = 20 # 20ms 이상 경고
        self.frame_time_critical = 33 # 33ms 이상 위험

    def begin_frame(self):
        self.metrics.update_frame()
        self.metrics.draw_calls = 0

    def start_section(self, name):    # 섹션별 타이밍
        self.metrics.start_section(name)

    def end_section(self, name):
        self.metrics.end_section(name)

    def draw(self):                   # 실시간 오버레이 (FPS/메모리 그래프)
        # FPS 그래프, 메모리 그래프, 섹션 타이밍, 드로우 콜 수
```

### 11.2 SimpleProfiler (`optimization_patch.py:219-247`)
```python
class SimpleProfiler:
    def start(self, name):
        self.timings[name] = pygame.time.get_ticks()

    def end(self, name):
        elapsed = pygame.time.get_ticks() - self.timings[name]
        self.counts[name]['total'] += elapsed
        self.counts[name]['count'] += 1

    def get_report(self):
        # "section_name: 2.34ms avg (120 calls)"
```

### 11.3 최적화 제안 시스템 (`core/profiler.py:431-463`)
```python
def get_optimization_suggestions(self):
    if metrics['fps']['average'] < self.fps_critical:
        suggestions.append("심각한 FPS 저하 - 렌더링 최적화 필요")
    if metrics['rendering']['draw_calls'] > 100:
        suggestions.append("드로우 콜이 많음 - 배치 렌더링 고려")
    if metrics['rendering']['particles'] > 500:
        suggestions.append("파티클이 너무 많음 - 파티클 수 제한 필요")
    if metrics['memory']['current_mb'] > 500:
        suggestions.append("메모리 사용량이 높음 - 메모리 누수 점검 필요")
```

### Review Notes
- 두 개의 프로파일러 (`GameProfiler`, `SimpleProfiler`)가 공존 → 통합 권장
- `SimpleProfiler`는 `pygame.time.get_ticks()` (ms 정밀도) 사용, `GameProfiler`는 `time.perf_counter()` (us 정밀도) → 후자가 더 정확
- 메모리 추적이 `psutil` 의존 → PyInstaller 빌드 시 크기 증가 원인

---

## 12. 충돌 감지 최적화

### 12.1 SpatialHash (`optimization_patch.py:138-185`)
```python
class SpatialHash:
    def __init__(self, cell_size=100):
        self.cell_size = cell_size
        self.cells = {}

    def add_object(self, obj, rect):
        cells = self._get_cells(rect)
        for cell in cells:
            self.cells.setdefault(cell, []).append((obj, rect))

    def get_nearby_objects(self, rect):
        cells = self._get_cells(rect)
        nearby = []
        seen = set()
        for cell in cells:
            for obj, obj_rect in self.cells.get(cell, []):
                if obj not in seen:
                    seen.add(obj)
                    nearby.append((obj, obj_rect))
        return nearby
```

**원리**: 전체 충돌 검사 O(n^2) → 공간 해싱으로 O(n) 근사. 100px 셀 기준.

### Review Notes
- `cell_size=100`은 760x750 화면에서 약 8x8 그리드 → 적절한 크기
- 현재 코드에서 실제 사용 여부 확인 필요 (전역 인스턴스 생성은 되어 있음)

---

## 13. 배경 로딩 & 폴백 최적화

### 13.1 그라데이션 폴백 (`optimization_patch.py:66-90`)
```python
def create_simple_gradient(width, height, stage_num):
    surface = pygame.Surface((width, height))
    colors = {1: ((10,50,20), (30,100,50)), ...}
    # 10픽셀 단위로 그라데이션 (성능 최적화)
    for y in range(0, height, 10):
        ratio = y / height
        r = int(start_color[0] + (end_color[0] - start_color[0]) * ratio)
        # ...
        pygame.draw.rect(surface, (r, g, b), (0, y, width, 10))
```

**10px 스트라이드**: 750px 높이 기준 75회 draw 대신 75/10 = 75회 (원래 750회 → 75회). 시각적 차이 거의 없음.

### 13.2 배경 팩토리 캐싱 (`optimization_patch.py:42-64`)
```python
def optimize_background_loading():
    backgrounds = {}    # 클로저로 캐시 유지
    def load_or_create_background(stage_num, width, height):
        cache_key = f"stage{stage_num}_bg"
        if cache_key in backgrounds:
            return backgrounds[cache_key]
        try:
            bg = pygame.image.load(...).convert()
            bg = pygame.transform.scale(bg, (width, height))
        except:
            bg = create_simple_gradient(width, height, stage_num)
        backgrounds[cache_key] = bg
        return bg
    return load_or_create_background
```

### 13.3 서브서피스 타일링 (`background_manager.py:67-76`)
```python
stage1 = pygame.image.load(rp("stage1_field.png")).convert()
top_tile = stage1.subsurface((0, border, width, border)).copy()
bottom_tile = stage1.subsurface((0, height - border*2, width, border)).copy()
left_tile = stage1.subsurface((border, 0, border, height)).copy()
right_tile = stage1.subsurface((width - border*2, 0, border, height)).copy()
```

**`subsurface().copy()`**: 원본의 일부를 독립 Surface로 추출. `.copy()` 없이 사용하면 원본 Surface가 GC되지 않음.

---

## 14. Dirty Rect 시스템

### 14.1 구현 (`optimization_patch.py:14-32`)
```python
self.dirty_rects = []

def add_dirty_rect(self, rect):
    self.dirty_rects.append(rect)

def get_dirty_rects(self):
    rects = self.dirty_rects.copy()
    self.dirty_rects.clear()
    return rects
```

### 14.2 설정 플래그 (`core/performance_optimizer.py:66`)
```python
'use_dirty_rects': False    # 기본 비활성화
```

### Review Notes
- Dirty rect 시스템이 구현되어 있으나 **기본 비활성화** 상태
- `pygame.display.update(dirty_rects)` 대신 `pygame.display.flip()`을 전역 사용 중
- 전체 화면 갱신 게임 특성상 dirty rect의 효과가 제한적일 수 있음 (배경이 매 프레임 변경)

---

## 15. Delta Time 사용

### 15.1 게임 엔진 레벨 (`core/game_engine.py:169-293`)
```python
self.delta_time = (current_time - self.last_update_time) / 1000.0
# 프레임 독립적 업데이트
self.ball.update(self.delta_time)
self.paddle.update(self.delta_time)
self.boss.update(self.delta_time, self.ball)
```

### 15.2 메뉴/UI 레벨 (`start_menu.py` 다수)
```python
dt = clock.tick(60) / 1000.0    # 초 단위 delta time
```

### Review Notes
- `clock.tick(60) / 1000.0` 패턴이 일관적으로 사용됨 - 좋은 관행
- 메인 게임 루프(`pingfighter.py`)에서는 프레임 카운터 기반과 delta time 기반이 혼용됨

---

## 16. Draw Call 배처

### 16.1 DrawCallBatcher (`core/performance_optimizer.py:198-260`)
```python
class DrawCallBatcher:
    def __init__(self):
        self.batches: Dict[str, List] = defaultdict(list)

    def add_rect(self, color, rect, width=0):
        key = f"rect_{color}_{width}"
        self.batches[key].append(rect)

    def render(self, screen):
        for key, items in self.batches.items():
            if key.startswith("rect_"):
                color = eval(parts[1])    # ⚠️ 보안 취약점!
                for rect in items:
                    pygame.draw.rect(screen, color, rect, width)
        self.batches.clear()
```

### Review Notes
- **`eval()` 사용은 보안 취약점** → `ast.literal_eval()` 또는 직접 파싱으로 교체 필수
- 배처가 같은 색상의 rect를 모아서 그리지만, Pygame에서는 draw call 자체의 오버헤드보다 Python 루프 오버헤드가 더 큼
- `pygame.draw.rect` 대량 호출보다 `Surface.fill()` + blit이 더 빠를 수 있음

---

## 17. 종합 리뷰 의견

### 잘된 점
1. **다층 캐싱 전략**: Surface/스케일/폰트/텍스트 등 세분화된 캐시로 거의 모든 중복 생성 제거
2. **양자화(Bucketing)**: 글로우 크기/알파를 버킷화하여 캐시 폭발 방지 - 우수한 설계
3. **프레임 스킵의 차등 적용**: 필러 30FPS, 방패 20FPS 등 요소별 최적 갱신 주기 적용
4. **사전 렌더링**: 복잡한 배경/관중/비네트를 init 시 1회 생성 - 가장 효과적인 최적화
5. **플랫폼별 튜닝**: Windows Direct3D + NVIDIA Optimus 힌트

### 개선 권장 사항

| 우선순위 | 항목 | 현재 | 권장 |
|---------|------|------|------|
| **P0** | DrawCallBatcher의 `eval()` | `eval(parts[1])` | `ast.literal_eval()` 또는 키 구조 변경 |
| **P1** | ObjectPool.release() | O(n) list.remove | `set` 기반 O(1) |
| **P1** | ResourceCache eviction | O(n) min() | `OrderedDict` 기반 O(1) LRU |
| **P2** | 16종 개별 캐시 딕셔너리 | 각각 독립 관리 | 통합 CacheManager 클래스 |
| **P2** | 프로파일러 이중화 | SimpleProfiler + GameProfiler | GameProfiler로 통합 |
| **P2** | 5초 주기 강제 GC | `gc.collect()` 호출 | 프레임 간 여유 시간에만 실행 |
| **P3** | 필러 Surface 풀 크기 제한 없음 | 무제한 증가 | max_size 파라미터 추가 |
| **P3** | Dirty Rect 비활성화 | 구현만 존재 | 삭제 또는 활성화 (중간 없음) |
| **P3** | HWSURFACE 플래그 | SDL2에서 무효 | 제거 (혼란 방지) |

### 누락된 최적화 기회

1. **`pygame.surfarray`**: numpy 배열 기반 픽셀 조작이 Python 루프보다 10~100배 빠름 (Stage 30 노이즈 생성에 적용 가능)
2. **`pygame.sprite.LayeredDirty`**: 게임 오브젝트에 적용하면 자동 dirty rect 관리
3. **텍스처 아틀라스**: 작은 아이콘/이펙트를 하나의 큰 Surface에 모아 blit 횟수 감소
4. **C 확장 모듈**: 성능 크리티컬 루프(파티클 업데이트 등)를 Cython/ctypes로 이관
5. **멀티스레드 리소스 로딩**: 스테이지 전환 시 배경/사운드를 별도 스레드에서 로드

---

*이 문서는 PingFighter 코드베이스의 프레임드랍 방지 최적화 코드를 코드 리뷰 관점에서 정리한 것입니다.*
