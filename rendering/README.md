# Rendering 모듈 구조

## 현재 상황
- `game_logic/draw_objects_module.py`: 2894줄의 거대한 단일 함수
- 모든 그리기 로직이 하나의 함수에 섞여있음
- 전역 변수에 과도하게 의존

## 개선 계획

### 1단계: 렌더링 모듈 분리
- `rendering/ball_renderer.py` - 공 렌더링
- `rendering/paddle_renderer.py` - 패들 렌더링
- `rendering/boss_renderer.py` - 보스 렌더링
- `rendering/ui_renderer.py` - UI 요소 렌더링
- `rendering/effect_renderer.py` - 이펙트 렌더링
- `rendering/item_renderer.py` - 아이템 렌더링
- `rendering/stage_renderer.py` - 스테이지별 배경 렌더링

### 2단계: 렌더링 매니저
- `rendering/render_manager.py` - 모든 렌더러 통합 관리
- 레이어 시스템 구현 (배경 → 게임 객체 → 이펙트 → UI)
- 렌더링 순서 최적화

### 3단계: 성능 최적화
- 더티 리전 시스템 구현
- 스프라이트 배칭
- 렌더링 캐싱

## 장점
- 코드 가독성 향상
- 유지보수 용이성
- 각 렌더러 독립 테스트 가능
- 성능 최적화 용이