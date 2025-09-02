# Stage 2 정글지진 벽돌 렌더링 버그 수정 완료

## 문제 설명
Stage 2에서 플레이어가 벽돌 아이템을 사용해 필드에 설치한 후, 보스가 정글지진을 발동하면 벽돌이 사라지거나 깜빡이는 버그가 있었습니다.

## 근본 원인 분석

### 1. 초기 문제
- 벽돌에 earthquake_offset이 적용되지 않아 화면과 다른 위치에 렌더링됨
- 이로 인해 벽돌이 화면 밖으로 밀려나거나 가려짐

### 2. 첫 번째 수정 시도 후 문제
- double temp_surface 문제: 메인 렌더링 루프와 draw_field()에서 각각 temp_surface 생성
- 이중 surface로 인한 렌더링 충돌

### 3. 두 번째 수정 시도 후 문제
- earthquake_offset을 screen_shake_offset에 통합했지만 화면 흔들림이 완전히 사라짐
- 원인: animated_bg_stage2.trigger_earthquake() 함수가 호출되지 않음
- activate_quake()에서 잘못된 변수명 사용 (animated_bg 대신 animated_bg_stage2 사용해야 함)

## 최종 수정 내용

### 1. activate_quake() 함수 수정 (3410-3415줄)
```python
# 수정 전
if current_stage == 2 and animated_bg is not None:
    animated_bg.spawn_skill_rocks()
    # trigger_earthquake() 호출 누락

# 수정 후
if current_stage == 2 and animated_bg_stage2 is not None:
    animated_bg_stage2.spawn_skill_rocks()
    # 🌋 정글지진 효과 시작 (화면 흔들림)
    animated_bg_stage2.trigger_earthquake()
```

### 2. draw_shaking_screen() 함수 (3470-3494줄)
- Stage 2 정글지진 시 earthquake_offset을 screen_shake_offset에 통합
- 다른 스테이지는 기본 흔들림 효과 유지

### 3. draw_objects() 함수 (10578-10585줄)
- 벽돌 렌더링 시 screen_shake_offset 적용
- 화면과 동기화된 흔들림 효과

## 작동 원리

1. **정글지진 발동**: activate_quake() → animated_bg_stage2.trigger_earthquake()
2. **오프셋 생성**: animated_bg_stage2.get_earthquake_offset() → 랜덤 흔들림 값
3. **오프셋 통합**: draw_shaking_screen() → earthquake_offset을 screen_shake_offset에 통합
4. **렌더링**: 메인 루프에서 temp_surface 생성 → 모든 객체 그리기 → 오프셋 적용하여 화면에 블릿

## 테스트 확인 사항

✅ Stage 2에서 정글지진 발동 시 화면 흔들림 효과 정상 작동
✅ 벽돌이 화면과 함께 흔들리며 계속 보임
✅ 다른 스테이지 흔들림 효과에 영향 없음
✅ FULLSCREEN_MODE와 일반 모드 모두 정상 작동

## 관련 파일
- `pingfighter.py`: 메인 게임 파일
- `backgrounds/animated_background_stage2.py`: Stage 2 배경 애니메이션
- `test_earthquake_brick_fix.py`: 버그 수정 테스트
- `test_stage2_earthquake_complete.py`: 통합 테스트

## 핵심 변경 사항
- **변수명 수정**: `animated_bg` → `animated_bg_stage2` (activate_quake 함수)
- **함수 호출 추가**: `animated_bg_stage2.trigger_earthquake()` 
- **오프셋 통합**: earthquake_offset과 screen_shake_offset 통합으로 일관된 렌더링