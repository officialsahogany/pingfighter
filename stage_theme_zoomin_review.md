# 스테이지 테마 줌인 뷰 — 코드 리뷰 문서

> 작성일: 2026-04-09  
> 대상 브랜치: feature/refactor-ui

---

## 1. 시스템 전체 구조

스테이지 시작 전 연출은 **3개의 독립 시스템**이 공존하며, 그 중 **1개만 실제 사용** 중이다.

| # | 시스템 | 파일 | 상태 |
|---|--------|------|------|
| A | **하강 랜딩 씬** | `ui/space_map.py:9883-10096` | **활성 (유일하게 사용 중)** |
| B | 인트로 비디오 플레이어 | `pingfighter.py:140253-140454` | 활성 (스테이지 전환 시 비디오 파일 존재 시 재생) |
| C | 레거시 오프닝 시스템 | `ui/opening_system.py:56-87` | **미사용 (dead code)** |

### 실행 흐름 (메인 게임 루프)

```
[main() — pingfighter.py:161365-161381]
  ├─ 1. draw_field()                          — 현재 게임 화면 1프레임 렌더 + 캡처
  ├─ 2. show_space_map_transition()           — 래퍼 (pingfighter.py:11965-11981)
  │      └─ SpaceMap.show_landing_scene()     — 하강 연출 본체 (space_map.py:9883-10096)
  ├─ 3. clock.tick() × 2 + delay(1)          — 타이머 리셋
  └─ 4. 공 생성 애니메이션 → 게임플레이 시작
```

조건: `stage_num != 50` (튜토리얼 제외) `and stage_num > 0`

---

## 2. 핵심 코드: show_landing_scene()

**위치**: `ui/space_map.py:9883-10096` (약 213줄)

### 2-1. 설정 데이터

```python
# space_map.py:9863-9872
_STAGE_INFO = {
    1: {"title": "STAGE 1", "subtitle": "조선 : 풍류의 거리", "color": (255, 220, 220)},
    2: {"title": "STAGE 2", "subtitle": "정글 : 야생의 늪지", "color": (240, 220, 180)},
    3: {"title": "STAGE 3", "subtitle": "멘헤라 : 인형의 방", "color": (255, 180, 255)},
    4: {"title": "STAGE 4", "subtitle": "사원 : 잊혀진 성소", "color": (255, 240, 200)},
    5: {"title": "STAGE 5", "subtitle": "해상 : 전장의 파도", "color": (0, 255, 255)},
    6: {"title": "STAGE 6", "subtitle": "화염 : 홍련의 거리", "color": (255, 150, 100)},
    7: {"title": "STAGE 7", "subtitle": "전자 : 블록의 차원", "color": (120, 180, 255)},
    8: {"title": "STAGE 8", "subtitle": "심해 : 어둠의 끝", "color": (90, 140, 200)},
}

# space_map.py:9875-9881
_SCAN_LINES = [
    "[ DESCENT INITIATED ]",
    "[ TERRAIN SCAN... ]",
    "[ 미확인 생체 신호 탐지 중... ]",
    "[ TARGET SEARCHING... ]",
    "[ WARNING : HOSTILE DETECTED ]",
]
```

### 2-2. 메인 함수 파라미터

```python
def show_landing_scene(self, to_planet, duration=1.8, fade_out=True,
                       ingame_frame=None, stage_num=None):
```

| 파라미터 | 호출 시 값 | 설명 |
|----------|------------|------|
| `to_planet` | `display_stage_num` | 행성 번호 (1~8, 30) |
| `duration` | `1.8` (고정) | 전체 하강 시간 (초) |
| `fade_out` | `False` | 페이드아웃 끔 (게임 화면으로 직결) |
| `ingame_frame` | 캡처된 SCREEN | 실제 게임 화면 Surface |
| `stage_num` | `display_stage_num` | 텍스트 오버레이용 스테이지 번호 |

### 2-3. 프레임별 타임라인 (duration=1.8초 / 60fps = 108프레임)

```
Frame 0─11   (0.0s─0.2s)  │ 페이드인: 검정→투명 (12프레임)
Frame 6+     (0.1s~)       │ 탐색 UI: 좌하단 스캔 텍스트 시퀀스 시작
Frame 0─15   (0.0s─0.25s)  │ 경기장: 12% 고정 (hold_ratio=0.15)
Frame 16─107 (0.26s─1.8s)  │ 경기장: 12% → 100% ease-out 확대
Frame 43+    (0.4s~)       │ 스테이지 텍스트: "STAGE N" + 서브타이틀 페이드인
Frame 93─107 (1.55s─1.8s)  │ 페이드아웃: 투명→검정 (15프레임) ← fade_out=False이므로 스킵됨
Frame 108─121(1.8s─2.03s)  │ 스크린쉐이크: 강도 8, 14프레임, 디케이
```

### 2-4. 렌더링 파이프라인 (매 프레임)

```
1. 프리렌더 지형 Surface → crop+scale (줌 효과)
2. 인게임 프레임 scale → blit (경기장이 커지며 등장)
3. 스테이지별 아레나 보더 오버레이
4. "STAGE N" + 서브타이틀 텍스트 (t > 0.4부터)
5. 탐색 UI 스캔 텍스트 + 진행바 (t > 0.1부터)
6. 페이드인 오버레이 (첫 12프레임)
```

### 2-5. 캐싱 전략

```python
# 지형 Surface: 루프 전 1회 프리렌더 (space_map.py:9909-9910)
_surf_cached = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
self._draw_planet_surface(_surf_cached, to_planet, 1.0)

# 인게임 프레임 스케일: 크기 변경 시에만 재계산 (space_map.py:9913-9968)
if (ig_w, ig_h) != _ig_cache_size:
    _ig_cache_surf = pygame.transform.scale(ingame_frame, (ig_w, ig_h))
    _ig_cache_size = (ig_w, ig_h)
```

---

## 3. 지형 렌더러 (Planet Surface Renderers)

**디스패처**: `space_map.py:462-468`

```python
_SURFACE_RENDERERS = {
    1: '_draw_surface_joseon',     # 514-1936  (1422줄)
    2: '_draw_surface_jungle',     # 3712-4684 (972줄)
    3: '_draw_surface_menhera',    # 4685-6247 (1562줄)
    4: '_draw_surface_temple',     # 6248-6984 (736줄)
    30: '_draw_surface_colosseum', # 6985-7561 (576줄)
}
```

### 지형 렌더러 커버리지

| 스테이지 | 행성 | 전용 렌더러 | 아레나 보더 |
|----------|------|-------------|-------------|
| 1 | 조선 | `_draw_surface_joseon` | `_draw_joseon_arena_border` |
| 2 | 정글 | `_draw_surface_jungle` | `_draw_jungle_arena_border` |
| 3 | 멘헤라 | `_draw_surface_menhera` | `_draw_menhera_arena_border` |
| 4 | 사원 | `_draw_surface_temple` | `_draw_temple_arena_border` |
| **5** | **해상** | **없음 (generic 폴백)** | **없음** |
| **6** | **화염** | **없음 (generic 폴백)** | **없음** |
| **7** | **테트리스** | **없음 (generic 폴백)** | **없음** |
| **8** | **심해** | **없음 (generic 폴백)** | **없음** |
| 30 | 콜로세움 | `_draw_surface_colosseum` | `_draw_colosseum_arena_border` |

**스테이지 5~8은 전용 지형 렌더러와 아레나 보더가 없어 generic 폴백으로 처리된다.**

---

## 4. 인트로 비디오 시스템 (별도 연출)

**위치**: `pingfighter.py:140253-140454`

스테이지 전환 시 `.mov`/`.mp4` 비디오가 있으면 재생하는 시스템.
OpenCV(`cv2`) 의존, 없으면 조용히 스킵.

### 비디오 경로 상수 (pingfighter.py:11587-11594)

```python
STAGE1_INTRO_VIDEO_PATH = resource_path("stagevideo/stage1.mov")
STAGE2_INTRO_VIDEO_PATH = resource_path("stagevideo/stage2.mov")
# ... stage3~8 동일 패턴
```

### start_menu.py 인트로 맵 (3308-3316)

계속하기(Continue) → 다음 스테이지 진입 시 사용되는 비디오+텍스트 매핑:

```python
_stage_intro_map = {
    2: (STAGE2_INTRO_VIDEO_PATH, "STAGE 2", "악어장군", (240,220,180), (200,110,160)),
    3: (STAGE3_INTRO_VIDEO_PATH, "STAGE 3", "멘헤라걸", (255,180,255), (200,110,210)),
    # ... 4~8
}
```

**주의**: 이 맵에는 보스 이름이 하드코딩되어 있으나, 실제로는 보스가 3명 중 랜덤 선택이다.
(planet_configs.py에 각 행성별 boss_roster 3명 정의)

---

## 5. 래퍼 함수: show_space_map_transition()

**위치**: `pingfighter.py:11965-11981` (17줄)

```python
def show_space_map_transition(from_planet, to_planet, ingame_frame=None, stage_num=None):
    pygame.event.pump()
    pygame.event.get()         # 잔류 입력 정리
    try:
        from ui.space_map import SpaceMap
        smap = SpaceMap(SCREEN, WIDTH, HEIGHT)
        smap.show_landing_scene(
            to_planet=to_planet, duration=1.8, fade_out=False,
            ingame_frame=ingame_frame, stage_num=stage_num or to_planet)
    except Exception as e:
        print(f"[WARNING] 하강 연출 실패: {e}")
        import traceback
        traceback.print_exc()
```

**참고**: `from_planet` 파라미터는 받지만 내부에서 사용하지 않는다.

---

## 6. 호출 지점

**위치**: `pingfighter.py:161365-161381`

```python
if stage_num != 50 and stage_num > 0:
    draw_field()
    _ingame_captured = SCREEN.copy()
    show_space_map_transition(
        from_planet=max(0, display_stage_num - 1),
        to_planet=display_stage_num,
        ingame_frame=_ingame_captured,
        stage_num=display_stage_num)
    del _ingame_captured
    clock.tick()
    pygame.time.delay(1)
    clock.tick()
```

---

## 7. 레거시 코드 (Dead Code)

### ui/opening_system.py:56-87

```python
self.stage_intros = {
    1: {'title': 'Stage 1: Training Ground', 'subtitle': 'Master the basics', 'duration': 180},
    # ... 2~6 (영어, 구 테마명, 미사용)
}
```

이 시스템은 현재 어디에서도 호출되지 않으며, 테마명도 현재 게임과 불일치한다.

---

## 8. 보스 로스터 시스템 (연출 컨텍스트)

**위치**: `config/planet_configs.py:8-105`

각 행성(스테이지)에 보스 3명이 등록되어 있고, 진입 시 `select_random_boss()`로 랜덤 1명이 선택된다.

| 행성 | 보스 1 | 보스 2 | 보스 3 |
|------|--------|--------|--------|
| 1 조선 | 풍악보이 | 포도대장 | 각시탈 |
| 2 정글 | 악어장군 | 두더지왕 | 아라크네 |
| 3 멘헤라 | 멘헤라걸 | 테디베어 | 앨리스 |
| 4 사원 | 퐁크 | ??? | ??? |
| 5 해상 | 네메시스 | ??? | ??? |
| 6 화염 | 홍련 | ??? | ??? |
| 7 테트리스 | 테트리서 | ??? | ??? |
| 8 심해 | 아카무 리고 | ??? | ??? |

**연출 관련 이슈**: 하강 씬에서는 보스를 표시하지 않지만, `start_menu.py:3308`의 인트로 비디오 맵에는 보스 이름이 하드코딩되어 있어 랜덤 보스 시스템과 불일치.

---

## 9. 스킵 입력 처리

### show_landing_scene() (space_map.py:9921-9926)

```python
for ev in pygame.event.get():
    if ev.type == pygame.QUIT:
        return
    if ev.type == pygame.KEYDOWN:
        if ev.key in (pygame.K_ESCAPE, pygame.K_SPACE, pygame.K_RETURN):
            return
```

- ESC / SPACE / ENTER: 스킵 가능
- **마우스 클릭: 스킵 불가** (MOUSEBUTTONDOWN 미처리)

### play_stage_intro_video() (pingfighter.py:140358-140366)

```python
if (event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE) or \
   (event.type == pygame.MOUSEBUTTONDOWN):
    skip_video = True
```

- SPACE / 마우스 클릭: 스킵 가능
- AI 자동 스킵: 0.6초 후 자동 스킵
- 포커스 변화 감지로 자동 스킵

**비디오 플레이어는 마우스 스킵을 지원하지만, 하강 씬은 키보드만 지원한다.**

---

## 10. 이 문서의 용도

이 문서는 코드 리뷰 및 개선 작업을 위한 참조 자료이다.
실제 코드의 진실은 항상 소스 파일에 있으므로, 이 문서의 라인 번호는 수정 시 변경될 수 있다.
