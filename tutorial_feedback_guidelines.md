# 튜토리얼 긍정적 피드백 시스템 가이드라인

## 개요
모든 튜토리얼 챕터에는 성공 시 긍정적 피드백을 제공하여 학습 동기를 부여합니다.

## 기본 피드백 시스템 구조

### 1. 단계별 성공 피드백
- **첫 번째 성공**: `show_tutorial_success_feedback("잘했어요!", "normal")` - 파란색 별 효과
- **두 번째 성공**: `show_tutorial_success_feedback("훌륭해요!", "great")` - 초록색 별 효과
- **최종 마스터**: `show_tutorial_success_feedback("[스킬명] 마스터!", "perfect")` - 금색 별 + 박수 애니메이션

### 2. 향후 구현할 튜토리얼별 피드백

#### 드라이브 튜토리얼 (Chapter 3)
```python
# 드라이브 성공 카운터 추가 필요
tutorial_drive_success_count = 0

# 드라이브 성공 시
if drive_successful:
    tutorial_drive_success_count += 1
    if tutorial_drive_success_count == 1:
        show_tutorial_success_feedback("드라이브 성공!", "normal")
    elif tutorial_drive_success_count == 2:
        show_tutorial_success_feedback("멋진 드라이브!", "great")
    elif tutorial_drive_success_count == 3:
        show_tutorial_success_feedback("드라이브 마스터!", "perfect")
        # 챕터 완료 요약
        show_chapter_completion_summary(3)
```

#### 파워스매싱 튜토리얼 (Chapter 4)
```python
# 파워스매싱 성공 카운터
tutorial_powersmash_success_count = 0

# 파워스매싱 성공 시
if powersmash_successful:
    tutorial_powersmash_success_count += 1
    if tutorial_powersmash_success_count == 1:
        show_tutorial_success_feedback("파워스매시!", "normal")
    elif tutorial_powersmash_success_count == 2:
        show_tutorial_success_feedback("강력한 스매시!", "great")
    elif tutorial_powersmash_success_count == 3:
        show_tutorial_success_feedback("파워스매싱 마스터!", "perfect")
        show_chapter_completion_summary(4)
```

#### 아이템 획득 튜토리얼 (Chapter 5)
```python
# 아이템 획득 단계별 피드백
items_collected = 0

# 아이템 획득 시
if item_collected:
    items_collected += 1
    if items_collected == 1:
        show_tutorial_success_feedback("첫 아이템 획득!", "normal")
    elif items_collected == 2:
        show_tutorial_success_feedback("수집가의 눈!", "great")
    elif items_collected == 3:
        show_tutorial_success_feedback("아이템 마스터!", "perfect")
        show_chapter_completion_summary(5)
```

#### 별(트레이드 포인트) 획득 튜토리얼 (Chapter 6)
```python
# 별 획득 카운터
tutorial_stars_collected = 0

# 별 획득 시
if star_collected:
    tutorial_stars_collected += 1
    if tutorial_stars_collected == 1:
        show_tutorial_success_feedback("첫 별 획득!", "normal")
    elif tutorial_stars_collected == 3:
        show_tutorial_success_feedback("별 수집가!", "great")
    elif tutorial_stars_collected == 5:
        show_tutorial_success_feedback("별 마스터! ⭐", "perfect")
        show_chapter_completion_summary(6)
```

## 챕터 완료 요약 화면 템플릿

```python
def show_chapter_completion_summary(chapter_num):
    """각 챕터 완료 시 학습 내용 요약"""
    
    chapter_summaries = {
        3: {  # 드라이브
            "title": "Chapter 3: 드라이브",
            "skills": [
                "← + SPACE: 왼쪽 드라이브",
                "→ + SPACE: 오른쪽 드라이브",
                "공의 궤적을 휘어지게 만들기"
            ],
            "message": "드라이브를 마스터했습니다!"
        },
        4: {  # 파워스매싱
            "title": "Chapter 4: 파워스매싱",
            "skills": [
                "게이지 MAX 상태에서 SPACE",
                "강력한 공격력",
                "방어 불가능한 스매시"
            ],
            "message": "파워스매싱을 터득했습니다!"
        },
        5: {  # 아이템
            "title": "Chapter 5: 아이템 시스템",
            "skills": [
                "필드의 아이템 획득",
                "아이템 효과 이해",
                "전략적 아이템 사용"
            ],
            "message": "아이템 활용법을 익혔습니다!"
        },
        6: {  # 별
            "title": "Chapter 6: 트레이드 포인트",
            "skills": [
                "별 획득으로 포인트 수집",
                "아카데미 스킬 업그레이드",
                "성장 시스템 이해"
            ],
            "message": "성장 시스템을 이해했습니다!"
        }
    }
    
    if chapter_num in chapter_summaries:
        # 요약 화면 표시 코드...
        pass
```

## 특별 애니메이션 트리거

### 박수 애니메이션이 나오는 경우
- "마스터" 키워드가 포함된 메시지
- "완벽해요" 메시지
- 튜토리얼 전체 완료 시

### 추가 이펙트 제안
1. **드라이브 마스터**: 회전하는 공 애니메이션
2. **파워스매싱 마스터**: 폭발 이펙트
3. **아이템 마스터**: 아이템 아이콘들이 회전
4. **별 마스터**: 별똥별 효과

## 구현 시 주의사항

1. **일관성**: 모든 튜토리얼에서 동일한 피드백 패턴 유지
2. **점진적 강화**: normal → great → perfect 순서로 피드백 강도 증가
3. **시각적 차별화**: 각 레벨별로 색상과 파티클 수 차별화
4. **타이밍**: 성공 직후 즉시 피드백 제공 (1.5초 동안 표시)
5. **사운드**: 가능하다면 성공 사운드 추가 고려

## 호출 예시

```python
# 드라이브 성공 체크 (향후 구현)
def check_drive_success():
    global tutorial_drive_success_count
    
    if player_performed_drive_correctly:
        tutorial_drive_success_count += 1
        
        # 단계별 피드백
        if tutorial_drive_success_count == 1:
            show_tutorial_success_feedback("드라이브 성공!", "normal")
        elif tutorial_drive_success_count == 2:
            show_tutorial_success_feedback("멋진 드라이브!", "great")
        elif tutorial_drive_success_count == 3:
            show_tutorial_success_feedback("드라이브 마스터!", "perfect")
            # 다음 챕터로 진행
            advance_to_next_chapter()
```

## 통합 관리

모든 튜토리얼 피드백은 기존의 `show_tutorial_success_feedback()` 함수를 재사용하여 일관된 경험을 제공합니다.