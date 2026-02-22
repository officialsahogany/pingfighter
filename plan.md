# 우주 행성 맵 시스템 구현 계획

## 개요
아케이드 모드의 선형 스테이지 진행에 **우주 행성 맵** 시스템 추가.
캐릭터/난이도 선택 후 우주맵이 펼쳐지고, 우주선이 행성을 순서대로 방문하며 각 행성에서 보스를 랜덤 선출.

## 현재 흐름 (AS-IS)
```
캐릭터 선택 → 난이도 선택 → show_stage1_intro() → main(1)
→ 승리 → 스코어 화면 → (광장) → show_stage2_intro() → main(2) → ...
```

## 변경 흐름 (TO-BE)
```
캐릭터 선택 → 난이도 선택
→ 🌌 우주맵 등장 (행성들 배치)
→ 🚀 우주선이 행성1(조선시대)로 이동 애니메이션
→ 행성 도착 → 보스 3명 표시 → 랜덤 1명 선출 연출
→ show_stage1_intro() → main(1) (기존 그대로)
→ 승리 → 스코어 화면 → (광장)
→ 🌌 우주맵 복귀 → 🚀 우주선이 행성2(정글)로 이동
→ 보스 선출 → show_stage2_intro() → main(2) → ...
```

## 구현 계획

### Step 1: 우주맵 화면 모듈 (`ui/space_map.py`) - 새 파일
760x750 내부 해상도에 프로그래매틱 드로잉으로 렌더링.

**구성 요소:**
- 어두운 우주 배경 + 반짝이는 별 파티클
- 8개 행성이 곡선 경로를 따라 배치 (planet_configs.py 색상/크기 활용)
- 행성 간 점선 경로
- 우주선 스프라이트 (삼각형/로켓 도형)
- 클리어된 행성: 체크마크 + 약간 어두워짐
- 현재 목표 행성: 빛남 효과
- 행성 이름 라벨

**핵심 클래스/함수:**
```python
class SpaceMap:
    def __init__(self, screen, width, height)
    def show_travel_animation(self, from_planet, to_planet)  # 우주선 이동
    def show_arrival(self, planet_num)  # 행성 도착 연출
```

### Step 2: 보스 선출 화면 (`ui/boss_select_screen.py`) - 새 파일
행성 도착 후 보스 3명 카드 표시 → 랜덤 1명 선출 연출.

**구성 요소:**
- 보스 3명 카드 (구현된 보스: 이름+색상, 미구현: "???" 잠금)
- 하이라이트가 카드 사이를 빠르게 왕복하다 멈추는 룰렛 연출
- 선출된 보스 확대 + 이름 표시 (2~3초 대기)
- ESC로 건너뛰기 가능

**핵심 함수:**
```python
class BossSelectScreen:
    def __init__(self, screen, width, height)
    def show_selection(self, planet_num) -> str  # 선출된 보스 이름 반환
```

### Step 3: pingfighter.py 통합 수정

#### 3-1. 전역 상태 추가
```python
cleared_planets = []  # 클리어한 행성 번호 목록
```
- 게임 오버 / ESC 복귀 시 리셋 (기존 3곳 리셋 포인트에 추가)

#### 3-2. `start_game_with_difficulty()` 수정 (~line 114718)
기존 `show_stage1_intro()` 호출 직전에 우주맵 + 보스 선출 삽입:
```python
# 기존
show_stage1_intro()
main(1)

# 변경
show_space_map_transition(from_planet=0, to_planet=1)  # 우주 출발 → 행성1
show_stage1_intro()
main(1)
```

#### 3-3. 스코어 화면 스테이지 전환 수정 (~line 103497)
`show_stageN_intro()` 호출 직전에 우주맵 + 보스 선출 삽입:
```python
# 기존
show_stage2_intro()
main(next_stage_display)

# 변경
show_space_map_transition(from_planet=next_stage_display-1, to_planet=next_stage_display)
show_stage2_intro()
main(next_stage_display)
```

#### 3-4. 래퍼 함수 추가
```python
def show_space_map_transition(from_planet, to_planet):
    """우주맵 행성 이동 + 보스 선출 애니메이션"""
    space_map = SpaceMap(SCREEN, WIDTH, HEIGHT)
    space_map.show_travel_animation(from_planet, to_planet)

    boss_screen = BossSelectScreen(SCREEN, WIDTH, HEIGHT)
    selected_boss = boss_screen.show_selection(to_planet)
    return selected_boss
```

### Step 4: 리셋 처리
기존 3곳 리셋 포인트에 `cleared_planets = []` 추가:
1. 게임 오버 (~line 20185 부근)
2. ESC 메뉴 복귀 (~line 139508 부근)
3. Force quit (~line 20506 부근)

---

## 기존 코드 영향
- `main()`, `show_stageN_intro()`, 배경/필러/장치 → **수정 없음**
- `BOSS_CONFIGS`, `boss_names`, `boss_speed_config` → **수정 없음**
- `config/planet_configs.py` → **이미 존재**, 활용만
- 우주맵/보스 선출은 기존 스테이지 전환 **사이에 끼워넣는** 방식
- 현재 구현된 보스 1명뿐이므로 게임플레이는 기존과 동일 (연출만 추가)

## 작업 순서
| # | 작업 | 파일 | 규모 |
|---|------|------|------|
| 1 | 우주맵 화면 모듈 | `ui/space_map.py` 신규 | 대 |
| 2 | 보스 선출 화면 모듈 | `ui/boss_select_screen.py` 신규 | 중 |
| 3 | pingfighter.py 통합 (시작/전환) | `pingfighter.py` 수정 | 소 |
| 4 | 상태 관리 + 리셋 | `pingfighter.py` 수정 | 소 |
| 5 | 테스트 및 연출 조정 | 전체 | 소 |
