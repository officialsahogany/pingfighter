# PingFighter Performance Optimization Code Review
> Codex Code Review Document | 2026-04-09 | feature/refactor-ui
> **v2** - 런타임 통합 여부 검증 반영 (미통합 코드 분리)

---

## 0. 문서 범위 및 검증 기준

- **검토 기준**: 현재 게임 엔트리인 `pingfighter.py`에서 **실제 import/호출되어 런타임에 동작하는 코드**를 1차로 정리
- **미통합 코드**: 저장소에 존재하지만 런타임에 연결되지 않은 프로토타입/유틸리티는 별도 섹션([Part B](#part-b-미통합-최적화-코드-저장소-내-프로토타입))으로 분리
- **정적 대조 리뷰만 수행**. 실제 프레임타임 측정이나 게임 실행 프로파일링은 하지 않음

### 최적화 카테고리 요약

#### Part A: 런타임 활성 최적화

| # | 카테고리 | 적용 위치 | 핵심 전략 |
|---|---------|----------|----------|
| 1 | [플랫폼별 렌더러/VSync 설정](#2-플랫폼별-렌더러vsync-설정) | pingfighter.py, core/game_core.py | Direct3D, VSync, DOUBLEBUF |
| 2 | [Surface 캐싱 시스템](#3-surface-캐싱-시스템-핵심) | pingfighter.py | 16종 전용 캐시 딕셔너리 |
| 3 | [Surface 풀링](#4-surface-풀링) | pillar_blazing_sun.py, pillar_hongryeon.py | SRCALPHA Surface 재사용 |
| 4 | [사전 렌더링(Prerender)](#5-사전-렌더링prerendering) | backgrounds/*.py, pillar_colosseum.py | 정적 요소 init 시 1회 생성 |
| 5 | [프레임 스킵 렌더링](#6-프레임-스킵-렌더링) | pingfighter.py | 2~3프레임 간격 갱신 |
| 6 | [값 양자화(Bucketing)](#7-값-양자화bucketing) | pingfighter.py | 글로우/알파/스케일 버킷화 |
| 7 | [이미지 사전 로드 & convert](#8-이미지-사전-로드--convert) | pingfighter.py, background_manager.py | convert()/convert_alpha() |

#### Part B: 미통합 최적화 코드

| # | 카테고리 | 파일 | 상태 |
|---|---------|------|------|
| 8 | [optimization_patch.py 전체](#9-optimization_patchpy) | optimization_patch.py | **미통합** - import 없음 |
| 9 | [자동 품질 조절 시스템](#10-자동-품질-조절-시스템) | core/performance_optimizer.py | **미통합** - import 없음 |
| 10 | [프로파일링 시스템](#11-프로파일링--모니터링) | core/profiler.py | **부분 통합** - 초기화만, 계측 API 미사용 |
| 11 | [시간 캐싱 헬퍼](#12-시간-캐싱-헬퍼-미완료) | pingfighter.py | **미완료** - 정의만, 호출처 0곳 |
| 12 | [리소스 캐시 (LRU)](#13-리소스-캐시-lru) | managers/resource_manager.py | **미통합** - 메인에서 미사용 |

---

# Part A: 런타임 활성 최적화

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
MIN_FPS = 30       # 최소 허용 FPS
MAX_FPS = 120      # 최대 FPS 캡
```

### Review Notes
- `SHIM_MCCOMPAT` 환경변수는 일부 시스템에서만 효과가 있으며, `NvOptimusEnablement` DLL export도 고려할 수 있음
- `HWSURFACE`는 SDL2에서 대부분 무시됨 (SDL1 호환성) — 실질적 효과 제한적. 제거해도 무방
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

**총 16종의 전용 캐시** — 각각 특정 렌더링 작업의 중복 Surface 생성을 방지. 이 캐시들은 pingfighter.py 내부에서 직접 참조되며 런타임에 활성 동작함.

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

### Review Notes
- 16종의 개별 캐시 딕셔너리는 관리 복잡도가 높음 → 통합 캐시 매니저로 리팩토링 고려
- `_CACHE_MAX_SIZE = 500`이 모든 캐시에 개별 적용되는지 공유되는지 불명확
- 패들 캐시의 절반 삭제 전략은 O(n) 복잡도 → `collections.OrderedDict` 기반 LRU가 더 효율적
- `_gold_hud_cached_value` 패턴 (값 비교 기반 무효화)은 좋은 패턴

---

## 4. Surface 풀링

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

**적용 범위 (런타임 활성)**:
- `pillar_blazing_sun.py`: 글로우/셀 이펙트 (2회/프레임)
- `pillar_hongryeon.py`: 불꽃/트레일/글로우 (9회/프레임)

**원리**: `pygame.Surface()` 생성은 메모리 할당 + 초기화 비용이 큼. 풀에서 가져와 `fill()`로 초기화하면 할당 비용 제거.

### Review Notes
- 풀 크기가 무한 증가 가능 → 최대 크기 제한 필요
- `fill((0,0,0,0))`은 대형 Surface에서 비용이 있음 → 작은 Surface 위주로 사용하는 것이 적절 (현재 올바르게 사용 중)

---

## 5. 사전 렌더링(Prerendering)

### 5.1 배경 Stage 30 — 모래 바닥/경기장/테두리 (`backgrounds/animated_background_stage30.py`)
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

### 5.3 Stage 7 — 빛줄기 밴드 (`backgrounds/animated_background_stage7.py:78-84`)
```python
self._prerendered_band = pygame.Surface((self.band_width, self.band_height), pygame.SRCALPHA)
half = self.band_width / 2
for x in range(self.band_width):
    intensity = max(0.0, 1.0 - abs(x - half) / half)
    alpha = int(70 * (intensity ** 1.8))
    pygame.draw.line(self._prerendered_band, (120, 186, 255, alpha), (x, 0), (x, self.band_height))
```

### 5.4 Stage 2 — 정글 덤불 캐시 (`backgrounds/animated_background_stage2.py`)
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
- 사전 렌더링은 가장 효과적인 최적화 — 복잡한 draw call 수백 회를 blit 1회로 대체
- Stage 30의 320+ 줄 노이즈 함수는 초기화 시간에 영향 → 로딩 화면과 병렬 처리 가능

---

## 6. 프레임 스킵 렌더링

### 6.1 필러 배경 30FPS 렌더링 (`pingfighter.py:8667-8678`)
```python
_pillar_bg_cache = None               # 캐시 Surface (.convert())
_pillar_bg_cache_dirty = True         # 재렌더링 필요 플래그
_pillar_bg_render_interval = 2        # 2프레임마다 렌더링 = 30FPS
_pillar_bg_frame_counter = 0          # 프레임 카운터
_pillar_bg_cache_stage = -1           # 스테이지 변경 감지

# 렌더링 시점 (line 9808, 10140 — 두 경로 동일 패턴)
if _pillar_bg_cache_dirty or _pillar_bg_frame_counter % _pillar_bg_render_interval == 0:
    pillar_renderer.draw(_pillar_bg_cache)
    _pillar_bg_cache_dirty = False    # 렌더링 후 False로 복귀
```

**원리**: 필러(좌우 80px 장식 패널)는 초당 30프레임으로도 시각적 차이가 거의 없음. 메인 게임은 60FPS 유지하면서 필러만 절반 속도로 갱신.

**dirty 플래그 설정 시점**: 캐시 Surface 재생성 시(line 9799), 스테이지 변경 감지 시(line 9805), `invalidate_pillar_bg_cache()` 호출 시(line 8678)에만 True로 설정됨. 렌더링 직후 False로 복귀하므로 캐시 효과가 정상 동작함.

### 6.2 신성 방패 20FPS 갱신 (`pingfighter.py:51319-51322`)
```python
_divine_shield_frame_counter = 0
_divine_shield_last_dynamic_surf = None
_divine_shield_dynamic_cache_key = None
DIVINE_SHIELD_DYNAMIC_SKIP_FRAMES = 3    # 3프레임마다 1회 = 20FPS
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

### Review Notes
- 프레임 스킵은 CPU 바운드 렌더링에 매우 효과적
- 필러 30FPS / 방패 20FPS 전략은 적절한 균형점

---

## 7. 값 양자화(Bucketing)

### 7.1 글로우 이펙트 버킷 (`pingfighter.py:562-567`)
```python
# Glow 최적화용 버킷 (메모리 절약을 위해 유사한 값들을 그룹화)
_GLOW_SIZE_BUCKETS = (8, 12, 16, 20, 24, 32, 40, 48, 60, 80, 100, 120, 150, 200)  # 14단계
_GLOW_ALPHA_BUCKETS = (32, 64, 96, 128, 160, 192, 224, 255)                        # 8단계
_WATER_ALPHA_BUCKETS = (20, 40, 60, 80, 100)                                        # 5단계
```

**원리**: 글로우 크기 37px → 가장 가까운 버킷 40px로 반올림. 최대 캐시 조합 수 = 14 x 8 = **112개**로 제한. 버킷 없이는 수천 종의 미세하게 다른 Surface가 생성됨.

### 7.2 패들 스케일 양자화 (`pingfighter.py:853`)
```python
quantized_scale = round(scale_ratio, 2)    # 0.01 단위로 양자화
```

**효과**: scale_ratio 0.9234 → 0.92, 0.9278 → 0.93 등으로 그룹화하여 캐시 적중률 향상

### Review Notes
- 버킷 간격이 균등하지 않음 (8→12→16... 로그 스케일에 가까움) → 작은 글로우에서 더 세밀한 제어
- 알파 버킷 8단계는 시각적으로 충분한 수준
- `bisect` 모듈을 사용하면 버킷 매칭 성능을 O(log n)으로 개선 가능

---

## 8. 이미지 사전 로드 & convert

### 8.1 게임 이미지 사전 로드 (`pingfighter.py:1016-1036`)
```python
"""자주 사용되는 게임 이미지를 미리 로드하고 convert()"""
img = pygame.image.load(img_path)
if img.get_alpha() is not None:
    img.convert_alpha()     # 알파 채널 있는 이미지
else:
    img.convert()           # 불투명 이미지
```

**목적**: `convert()`/`convert_alpha()`는 Surface 픽셀 포맷을 디스플레이와 일치시켜 blit 속도를 **2~5배** 향상시킴

### 8.2 배경 이미지 (`background_manager.py:67-76`)
```python
stage1 = pygame.image.load(rp("stage1_field.png")).convert()
top_tile = stage1.subsurface((0, border, width, border)).copy()
bottom_tile = stage1.subsurface((0, height - border*2, width, border)).copy()
```

**`subsurface().copy()`**: 원본의 일부를 독립 Surface로 추출. `.copy()` 없이 사용하면 원본 Surface가 GC되지 않음.

---

# Part B: 미통합 최적화 코드 (저장소 내 프로토타입)

> 아래 코드들은 저장소에 존재하지만, `pingfighter.py`에서 import/호출되지 않아 **현재 런타임에서 동작하지 않음**.
> 향후 통합 시 참조용으로 기록.

---

## 9. optimization_patch.py

**상태**: `pingfighter.py`에서 **import 없음**. 파일 자체가 `print("사용법: from optimization_patch import ...")`으로 끝남.

포함된 클래스/기능:
- `PerformanceOptimizer` — Surface 캐싱, dirty rect, 프레임 스킵
- `OptimizedParticleSystem` — 최대 파티클 수 제한, 리스트 컴프리헨션 업데이트
- `SpatialHash` — 공간 해싱 기반 충돌 감지 (100px 셀)
- `ObjectPool` — 객체 재사용 메모리 풀
- `SimpleProfiler` — `pygame.time.get_ticks()` 기반 구간 타이밍

### Review Notes
- `ObjectPool.release()`의 `self.in_use.remove(obj)`는 **O(n)** → `set` 기반 변경 필요
- 통합 시 pingfighter.py의 기존 캐시 시스템과 중복 가능성 확인 필요
- `SpatialHash`의 `cell_size=100`은 760x750 화면에서 약 8x8 그리드 → 적절

---

## 10. 자동 품질 조절 시스템

**파일**: `core/performance_optimizer.py`
**상태**: `pingfighter.py`에서 **import 없음**. `get_performance_optimizer()` 호출처 0곳.

포함된 클래스:
- `MemoryTracker` — weak reference 기반 메모리 추적, 5초 주기 GC
- `TextureCache` — 크기(MB) 기반 LRU 텍스처 캐시 (상한 100MB)
- `DrawCallBatcher` — 동일 색상/타입 draw call 그룹화
- `PerformanceOptimizer` — FPS 기반 품질 자동 조절 (0.5~1.0)

```python
# 품질 단계적 감소 (FPS < 54 시 발동)
if self.quality_level < 0.9: self.reduce_particles = True
if self.quality_level < 0.7: self.reduce_effects = True
if self.quality_level < 0.6: self.reduce_shadows = True

# 감소 속도 0.1 vs 복구 속도 0.05 — 진동 방지 설계
```

### Review Notes
- **`DrawCallBatcher.render()` 내부에 `eval()` 사용** — 보안 취약점이지만, 현재 미통합 상태이므로 런타임 영향 없음. 통합 시 반드시 `ast.literal_eval()` 또는 키 구조 변경 필요
- 5초 주기 `gc.collect()`는 공격적 → 프레임 스파이크 유발 가능. 통합 시 프레임 간 여유 시간에만 실행하도록 변경 권장
- 감소/복구 비대칭 속도는 좋은 설계

---

## 11. 프로파일링 & 모니터링

**파일**: `core/profiler.py`
**상태**: **부분 통합** — `pingfighter.py:2559`에서 import, `pingfighter.py:11331`에서 `init_profiler(SCREEN, enabled=True)` 호출. 그러나 계측 API(`count_draw_call()`, `count_particle()`, `count_ui_element()`, `start_section()`, `end_section()`)의 호출처가 코드베이스에 **0곳**.

```python
# 현재 유효한 기능: FPS, frame_time, memory (자동 수집)
# 현재 무효한 기능: draw_calls, particles, ui_elements (카운터 항상 0)
#                   section_times (start/end 호출 없음)
#                   최적화 제안 중 draw_call/particle 기반 항목 (항상 미트리거)
```

**`GameProfiler.draw()`**: `visible` 토글 기능이 있지만, 토글 키 바인딩이 연결되어 있는지 확인 필요.

### Review Notes
- FPS/메모리 자동 수집은 동작하므로 오버레이 표시 시 기본적인 모니터링은 가능
- 계측 API를 게임 루프 핵심 지점에 삽입하면 활성화 가능하지만, 현재는 사실상 빈 껍데기

---

## 12. 시간 캐싱 헬퍼 (미완료)

**파일**: `pingfighter.py:2904-2918`
**상태**: **정의만 존재, 호출처 0곳**. `pygame.time.get_ticks()` 직접 호출이 **699곳** 남아있음.

```python
_current_frame_ticks = 0      # 현재 프레임의 pygame.time.get_ticks() 값
_frame_counter = 0            # 프레임 카운터

def get_frame_ticks():
    """현재 프레임의 캐시된 시간 반환 (get_ticks() 대신 사용)"""
    return _current_frame_ticks

def get_frame_counter():
    """현재 프레임 카운터 반환 (시간 기반 애니메이션 대체용)"""
    return _frame_counter

HALF_SECOND_FRAMES = 30
ONE_SECOND_FRAMES = 60
TWO_SECONDS_FRAMES = 120
THREE_SECONDS_FRAMES = 180
```

**메인 루프 갱신 코드** (`pingfighter.py:161759-161761`):
```python
_current_frame_ticks = now_ms    # 값은 매 프레임 갱신됨
_frame_counter += 1              # 카운터도 증가함
```

**현재 상태**: 인프라(변수 정의 + 메인 루프 갱신)는 완성되어 있으나, 실제 소비자 코드가 `get_frame_ticks()`/`get_frame_counter()`를 호출하지 않고 여전히 `pygame.time.get_ticks()`를 직접 사용 중. **전면 대체는 미완료**.

### Review Notes
- 전면 대체 시 699곳의 `pygame.time.get_ticks()` → `get_frame_ticks()` 교체 필요
- 교체 전 주의: 일부 호출은 프레임 시작이 아닌 중간 시점의 정확한 시간이 필요할 수 있음 (애니메이션 보간 등)
- 프레임 카운터 기반 타이밍은 FPS 변동 시 실제 시간과 괴리 발생 가능

---

## 13. 리소스 캐시 (LRU)

**파일**: `managers/resource_manager.py:159-216`
**상태**: `pingfighter.py`에서 **import 없음**. `core/` 모듈 계열에서 사용될 수 있으나 메인 게임 루프와 연결되지 않음.

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
                self.access_count[key] += 1
                return self.cache[key]
        return None

    def put(self, key, resource):           # 메서드명: put (add 아님)
        with self.lock:
            if len(self.cache) >= self.max_size and key not in self.cache:
                lru_key = min(self.access_count, key=self.access_count.get)
                del self.cache[lru_key]
                del self.access_count[lru_key]
            self.cache[key] = resource
            self.access_count[key] = 0      # 초기 카운트: 0 (1 아님)
```

**캐시 크기 설정** (`ResourceManager.__init__()`):
```python
self.image_cache = ResourceCache(max_size=50)    # 이미지
self.sound_cache = ResourceCache(max_size=30)    # 사운드
self.font_cache = ResourceCache(max_size=20)     # 폰트
```

### Review Notes
- 접근 **횟수** 기반 제거 (LFU) — 이름은 LRU이지만 실제로는 Least Frequently Used
- `min(self.access_count, key=...)` 는 **O(n)** → `heapq` 또는 `OrderedDict`로 O(1) 가능
- 통합 시 pingfighter.py 내부 16종 캐시와의 역할 중복/병합 검토 필요

---

## 14. 종합 리뷰 의견

### 잘된 점 (런타임 활성 코드)
1. **다층 캐싱 전략**: Surface/스케일/폰트/텍스트 등 세분화된 캐시로 거의 모든 중복 생성 제거
2. **양자화(Bucketing)**: 글로우 크기/알파를 버킷화하여 캐시 폭발 방지 — 우수한 설계
3. **프레임 스킵의 차등 적용**: 필러 30FPS, 방패 20FPS 등 요소별 최적 갱신 주기 적용
4. **사전 렌더링**: 복잡한 배경/관중/비네트를 init 시 1회 생성 — 가장 효과적인 최적화
5. **플랫폼별 튜닝**: Windows Direct3D + NVIDIA Optimus 힌트

### 주요 문제: 미통합 코드의 사장

저장소에 상당한 양의 최적화 인프라가 구축되어 있으나 런타임에 연결되지 않음:

| 코드 | 상태 | 통합 난이도 | 기대 효과 |
|------|------|------------|----------|
| `optimization_patch.py` 전체 | 미통합 | 중 | 중복 (기존 캐시로 충분) |
| `core/performance_optimizer.py` | 미통합 | 상 | 자동 품질 조절 — FPS 저하 시 유용 |
| `core/profiler.py` 계측 API | 부분 통합 | 하 | 병목 진단에 즉시 활용 가능 |
| `get_frame_ticks()` 전면 대체 | 미완료 (699곳) | 중 | 미미 (get_ticks() 자체 비용 작음) |
| `ResourceCache` | 미통합 | 중 | 중복 (기존 캐시로 충분) |

### 개선 권장 사항

| 우선순위 | 항목 | 현재 | 권장 |
|---------|------|------|------|
| **P1** | 프로파일러 계측 API 연결 | init만 됨, 카운터 미사용 | 게임 루프 핵심 지점에 `start_section()`/`end_section()` 삽입 — 병목 진단에 즉시 유용 |
| **P1** | 자동 품질 조절 통합 검토 | 미통합 | 저사양 PC에서 FPS 유지에 효과적. `reduce_particles` 플래그를 파티클 생성 코드에 연결 |
| **P2** | 16종 개별 캐시 딕셔너리 | 각각 독립 관리 | 통합 CacheManager 클래스 (크기 제한, LRU, 모니터링) |
| **P2** | 패들 캐시 eviction | O(n) 절반 삭제 | `collections.OrderedDict` 기반 O(1) LRU |
| **P3** | 필러 Surface 풀 크기 제한 없음 | 무제한 증가 | max_size 파라미터 추가 |
| **P3** | `HWSURFACE` 플래그 | SDL2에서 무효 | 제거 (혼란 방지) |
| **P3** | `DrawCallBatcher`의 `eval()` | 미통합이므로 런타임 무영향 | 통합 시 반드시 `ast.literal_eval()` 또는 키 구조 변경 |

### 누락된 최적화 기회

1. **`pygame.surfarray`**: numpy 배열 기반 픽셀 조작이 Python 루프보다 10~100배 빠름 (Stage 30 노이즈 생성에 적용 가능)
2. **`pygame.sprite.LayeredDirty`**: 게임 오브젝트에 적용하면 자동 dirty rect 관리
3. **텍스처 아틀라스**: 작은 아이콘/이펙트를 하나의 큰 Surface에 모아 blit 횟수 감소
4. **C 확장 모듈**: 성능 크리티컬 루프(파티클 업데이트 등)를 Cython/ctypes로 이관
5. **멀티스레드 리소스 로딩**: 스테이지 전환 시 배경/사운드를 별도 스레드에서 로드

---

*이 문서는 PingFighter 코드베이스의 프레임드랍 방지 최적화 코드를 코드 리뷰 관점에서 정리한 것입니다.*
*v2 (2026-04-09): 런타임 통합 여부 검증 반영. 미통합 코드를 Part B로 분리.*
