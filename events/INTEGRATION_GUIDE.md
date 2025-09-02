# 🎈 Balloon Machine Event Integration Guide

## 개요
Stage 1에서 플레이어가 1점 획득 시 발동되는 특별 이벤트입니다.

## 이벤트 시퀀스
1. **1.5초** - 바닥에 문이 열림
2. **2초** - 기계가 서서히 올라옴
3. **3초** - 8개의 풍선을 사방으로 발사
4. **2초** - 기계가 서서히 내려감
5. **1.5초** - 바닥의 문이 닫힘

## 통합 방법

### 1. 메인 게임에 이벤트 매니저 추가

```python
# pingfighter.py 상단에 추가
from events.stage1_event_integration import Stage1EventManager

# 초기화 부분에 추가
stage1_events = Stage1EventManager()
```

### 2. 게임 루프에서 이벤트 체크

```python
# 점수 획득 후 체크 (플레이어가 점수를 얻었을 때)
if game_state.player_score >= 1 and current_stage == 1:
    if stage1_events.check_events(game_state.player_score, boss_score, current_stage, round_count):
        stage1_events.trigger_event(screen, game_state.player_score, current_stage)
```

### 3. 게임 업데이트 루프에 추가

```python
# 메인 게임 루프 안에서
# 이벤트 업데이트
stage1_events.update()

# 이벤트 중 게임 일시정지 처리
if stage1_events.should_pause_game():
    # 공 움직임, 패들 움직임 등을 일시정지
    pass
else:
    # 정상적인 게임 업데이트
    update_ball()
    update_paddles()
```

### 4. 렌더링 부분에 추가

```python
# 게임 요소를 그린 후, 이벤트를 위에 그리기
draw_game_elements()
stage1_events.draw(screen)
```

### 5. 게임 리셋 시

```python
# 새 게임 시작 또는 스테이지 변경 시
stage1_events.reset()
```

## 테스트 방법

1. 테스트 스크립트 실행:
```bash
python test_balloon_machine_event.py
```

2. 컨트롤:
   - **SPACE**: 플레이어 점수 +1 (테스트용)
   - **R**: 게임 리셋
   - **Arrow Keys**: 패들 이동
   - **ESC**: 종료

## 특징

- 게임당 **한 번만** 발동
- 이벤트 중 게임 자동 일시정지
- 풍악보이의 풍선파티와 동일한 풍선 디자인
- 8개의 풍선이 8방향으로 발사
- 부드러운 애니메이션 (Ease-in/out)

## 커스터마이징

`balloon_machine_event.py`에서 다음 값들을 조정할 수 있습니다:

- `DOOR_OPEN_TIME`: 문 열림 시간
- `MACHINE_RISE_TIME`: 기계 상승 시간
- `SHOOTING_TIME`: 풍선 발사 지속 시간
- `balloon_colors`: 풍선 색상
- 풍선 개수 (현재 8개)

## 파일 구조

```
events/
├── balloon_machine_event.py      # 핵심 이벤트 로직
├── stage1_event_integration.py   # 게임 통합 매니저
└── INTEGRATION_GUIDE.md          # 이 문서

test_balloon_machine_event.py     # 독립 실행 테스트
```