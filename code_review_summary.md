# PingFighter 코드 리뷰 요청 - 2026-04-05 세션 변경사항

## 개요
총 7개 커밋, 4개 파일 수정, 215 insertions / 981 deletions (순 -766줄)

## 커밋 목록 (시간순)
1. `a49bf9cc` Fix: pingfighter.py 중복 함수 정의 9개 제거 (657줄 삭제)
2. `5662d153` Fix: 하드코딩된 절대 경로 2곳 제거 (크로스플랫폼 호환성)
3. `16ec31b9` Fix: 누락된 sounds/coin.wav 추가 (starpointstack.wav 기반)
4. `3f9e1ee5` Fix: passive_names 목록 동기화 및 유령 아이템 제거
5. `ad580bc0` Fix: 사운드 간헐적 재생 실패 문제 해결
6. `5dc46dd2` Perf: 매 프레임 폰트/Surface 생성 최적화
7. `d349f9f4` Perf: 캐릭터 패들 렌더링 Surface 재사용 (프레임 드랍 개선)

---

## 변경 1: 중복 함수 정의 9개 제거

### 문제
pingfighter.py(17만줄)에서 같은 이름의 함수가 2번 정의되어 Python이 두 번째 정의를 사용.
첫 번째 정의의 global 선언이 무시되어 `UnboundLocalError` 런타임 크래시 발생.
error_log.txt에 실제 크래시 기록 확인됨 (2026-04-04 `player_stun_immunity_timer`).

### 제거된 함수들
| 함수 | 삭제 대상 | 보존 이유 |
|------|----------|-----------|
| `handle_ball()` | 첫 번째 (380줄, 불완전) | 두 번째가 완전한 5876줄 버전 |
| `create_fireball_explosion()` | 두 번째 + 깨진 양자 코드 | 첫 번째가 정상 |
| `update_fireball_explosion_particles()` | 두 번째 | 첫 번째가 정상 |
| `draw_fireball_explosion_particles()` | 두 번째 | 첫 번째가 정상 |
| `_stage8_superspeed_dash()` | 첫 번째 (애니메이션 없음) | 두 번째에 trigger_dash() 포함 |
| `draw_tutorial_drive_counter()` | 두 번째 (축소판) | 첫 번째에 축하 이펙트 포함 |
| `show_tutorial_power_completion_dialogue()` | 두 번째 (global 누락) | 첫 번째에 global special_gauge |
| `record_dash_life_save()` | 첫 번째 (직접 stats 수정) | 두 번째가 메서드 위임 패턴 |
| `record_dash_victory()` | 첫 번째 (직접 stats 수정) | 두 번째가 메서드 위임 패턴 |

### 리뷰 포인트
- 9개 중복 중 올바른 버전을 선택했는지
- 삭제 후 참조가 깨진 곳은 없는지

---

## 변경 2: 하드코딩된 절대 경로 제거

### 변경 내용
```python
# Before (Mac 외장 드라이브 경로 - 배포 시 실패)
ufo_path = "/Volumes/T7/윈도우용최신/game/bosspong/ufo_player.png"
if os.path.exists(ufo_path):
    PLAYER_IMG = pygame.image.load(ufo_path).convert_alpha()
else:
    PLAYER_IMG = pygame.image.load(resource_path("ufo_player.png")).convert_alpha()

# After
PLAYER_IMG = pygame.image.load(resource_path("ufo_player.png")).convert_alpha()
```

```python
# Before (Windows 전용 폰트 경로)
elif os.path.exists("C:/Windows/Fonts/malgun.ttf"):
    font = "C:/Windows/Fonts/malgun.ttf"

# After (크로스플랫폼 시스템 폰트 탐색)
else:
    for sys_font in ["malgun.ttf", "AppleGothic.ttf", "NanumGothic.ttf"]:
        sys_path = pygame.font.match_font(sys_font.replace(".ttf", ""))
        if sys_path and os.path.exists(sys_path):
            font = sys_path
            break
```

### 리뷰 포인트
- `pygame.font.match_font()` 사용이 적절한지
- fallback 폰트 목록이 충분한지

---

## 변경 3: 누락된 coin.wav 추가

코드에서 8곳 이상 `resource_path("sounds/coin.wav")`를 참조하지만 파일 부재.
기존 `starpointstack.wav`를 `coin.wav`로 복사하여 해결.

---

## 변경 4: passive_names 동기화 및 유령 아이템 제거

### items.py
`spawn_random_item()` 내 `passive_names` 집합에 `hero_seal` 추가 (다른 두 목록과 동기화).

### pingfighter.py
`store_active_item()` 내 패시브 필터에서 `zeus_lightning`, `hades_helm` 제거.
이 두 아이템은 ITEM_TYPES에 정의되지 않은 유령 항목.

### 리뷰 포인트
- 세 곳의 패시브 목록(passive_names, update_items, store_active_item)이 정확히 동기화되었는지

---

## 변경 5: 사운드 간헐적 재생 실패 해결

### 문제
- `pygame.mixer.set_num_channels(32)` — 전투 중 32개 채널 모두 점유 시 sound.play()가 무시됨
- 74곳에서 `pygame.mixer.Sound(resource_path("sounds/xxx.wav"))`로 매번 디스크 로드

### 수정
1. 채널 수 32 → 64
2. 사운드 캐시 시스템 추가:
```python
_sound_cache: dict[str, pygame.mixer.Sound | None] = {}

def get_cached_sound(relative_path: str) -> "pygame.mixer.Sound | None":
    if relative_path in _sound_cache:
        return _sound_cache[relative_path]
    try:
        full_path = resource_path(relative_path)
        if os.path.exists(full_path):
            snd = pygame.mixer.Sound(full_path)
            _sound_cache[relative_path] = snd
            return snd
        else:
            _sound_cache[relative_path] = None
            return None
    except Exception:
        _sound_cache[relative_path] = None
        return None

def play_cached_sound(relative_path: str, volume=None):
    snd = get_cached_sound(relative_path)
    if snd:
        return play_sound_with_volume(snd, volume)
    return None
```
3. 58곳의 매번 로드를 `play_cached_sound()` 한 줄로 교체

### 리뷰 포인트
- 캐시가 무한 성장할 수 있는지 (사운드 파일 수가 유한하므로 OK?)
- `_sound_cache`의 메모리 사용량이 합리적인지
- 쿠로미 각성 사운드 등 특수 패턴도 잘 교체되었는지

---

## 변경 6: 매 프레임 폰트/Surface 생성 최적화

### 폰트 캐싱
```python
_cached_cd_font = None
_cached_gauge_font = None

def _get_cached_cd_font():
    global _cached_cd_font
    if _cached_cd_font is None:
        _cached_cd_font = pygame.font.Font(None, 28)
    return _cached_cd_font

def _get_cached_gauge_font():
    global _cached_gauge_font
    if _cached_gauge_font is None:
        try:
            _cached_gauge_font = pygame.freetype.Font(
                resource_path(os.path.join("fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf")), 16)
        except Exception:
            _cached_gauge_font = pygame.freetype.SysFont(None, 16)
    return _cached_gauge_font
```
- 4곳의 `pygame.font.Font(None, 28)` → `_get_cached_cd_font()`
- 1곳의 `pygame.freetype.Font(Pretendard, 16)` → `_get_cached_gauge_font()`

### 파티클 Surface 풀 (effects_manager.py)
```python
_particle_surface_cache: Dict[int, pygame.Surface] = {}

def _get_particle_surface(diameter: int) -> pygame.Surface:
    d = max(1, int(diameter))
    surf = _particle_surface_cache.get(d)
    if surf is None or surf.get_width() != d or surf.get_height() != d:
        surf = pygame.Surface((d, d), pygame.SRCALPHA)
        _particle_surface_cache[d] = surf
    else:
        surf.fill((0, 0, 0, 0))
    return surf
```
- 파티클 render()에서 트레일/글로우/메인 Surface를 매번 생성 → 크기별 캐시 재사용

### 리뷰 포인트
- `_particle_surface_cache`가 동일 프레임에서 같은 크기의 Surface를 여러 파티클이 공유하면 덮어쓰기 문제 없는지
  - → 각 파티클이 Surface를 blit한 후 다음 파티클이 fill+재그리기하므로 순차 실행 시 문제 없음
- 캐시 크기가 무한 성장할 수 있는지 (파티클 크기 범위가 유한하므로 OK?)

---

## 변경 7: 캐릭터 패들 렌더링 Surface 재사용

### 문제
패들 크기 2배 → Surface 면적 4배 → 매 프레임 대형 Surface 할당/파괴로 프레임 드랍.

### 수정
각 캐릭터별 `create_*_surface()` 함수에서 전역 Surface 캐시 도입:

```python
_skeletal_smasher_surface: pygame.Surface | None = None

def _render_skeletal_smasher(...):
    global _skeletal_smasher_surface
    if _skeletal_smasher_surface is None:
        _skeletal_smasher_surface = pygame.Surface((250, 120), pygame.SRCALPHA)
    surface = _skeletal_smasher_surface
    surface.fill((0, 0, 0, 0))
    # ... 기존 렌더링 코드 ...
    return surface
```

적용 대상:
| 함수 | Surface 크기 |
|------|-------------|
| `_render_skeletal_smasher()` | 250×120 |
| `create_viper_paddle_surface()` | 250×120 |
| `_create_mecha_paddle_surface()` | 416×720 (가장 큰 효과) |
| `create_soldier_paddle_surface()` | 320×108 |
| `_apply_character_idle_effects()` | 가변 |
| `pygame.transform.scale()` 결과 | 가변 (scale_ratio 적용) |

### 리뷰 포인트
- 전역 Surface를 반환하면 호출자가 수정 시 원본이 변경되는 문제
  - → 현재 코드에서 호출자는 blit 또는 transform.scale만 수행 (원본 수정 없음)
  - → `vfx.post_process()`가 새 Surface를 반환하므로 안전
- `_create_mecha_paddle_surface` 내부의 leg_glow, glow_surface 등 3개 추가 Surface(416×720)는 미캐싱
  - → 추가 최적화 여지

---

## 전체 리뷰 요청사항

1. **안전성**: 각 변경이 기존 게임 동작을 깨뜨리지 않는지
2. **Surface 캐시 패턴**: 전역 Surface를 fill+재그리기하는 패턴이 pygame에서 안전한지
3. **사운드 캐시**: 메모리 사용량과 캐시 무효화 필요성
4. **누락된 최적화**: 추가로 개선할 수 있는 부분이 있는지
5. **코드 스타일**: Python best practices 준수 여부
