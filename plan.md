# 스타포인트 기반 런타임 스킬 시스템 구현 계획

## 목표
- 모든 캐릭터(코만도, 발토르, 옵티머스, 스매셔)에 스타포인트 기반 스킬 선택 시스템 적용
- 기존 아카데미 시스템 제거
- 옵티머스 기존 스킬 선택과 병합

## 작업 범위 (유저 확인됨)
- **공용 스킬**: 모든 캐릭터에 적용 ✅
- **스매셔 전용**: 버스트업, 대쉬 스피릿 ✅
- **코만도/발토르 전용**: 나중에 추가 (지금은 공용만)
- **옵티머스**: 기존 시스템과 병합

## 현재 상태 분석

### 이미 구현된 것 ✅
1. **공용 스킬 풀** (`RUNTIME_SKILL_POOL`, 라인 2610)
   - 대쉬 트리: 경량화, 모듈제어, 도약, 배터리팩, 증폭 (5개)
   - 아이템 트리: 행운, 숙련, 숙달, 가방확장, 카페인, 연마, 연금술 (7개)
   - 광장 트리: 도박, 보물지도 (2개)
   - 총 14개 스킬, 3레벨 기준 조정 완료

2. **스매셔 전용 스킬** (`SMASHER_EXCLUSIVE_SKILLS`, 라인 2785)
   - 버스트업 (대쉬시 패들 크기 100%/레벨)
   - 대쉬 스피릿 (대쉬시 레이저 잔상 확률)

3. **옵티머스 전용 스킬** (`OPTIMUS_SKILL_POOL`, 라인 2837)
   - 메카체인, 메카차지, 메카벌크, 비상충전, 재부팅강화, 버그업데이트, 일렉패드, 옵티머스암, 스타체인지
   - 기존 경험치 기반 시스템 (레거시로 표시됨)

4. **스타포인트 트리거** (라인 2601)
   - `STARPOINT_PER_SKILL_CHOICE = 3` (3포인트당 1선택)
   - `pending_skill_choices` - 대기 중인 선택 횟수
   - 자동 누적 및 팝업 트리거

5. **스킬 선택 UI** (라인 60261)
   - `show_runtime_skill_choices()` - 3개 카드 선택 UI
   - 이미 게임 루프에서 호출됨 (라인 89632)

6. **스킬 효과 적용** (라인 8613)
   - `get_runtime_skill_bonus()` - 스킬별 효과값 반환
   - 아카데미 fallback 포함

### 필요한 작업

## 구현 계획

### Phase 1: 캐릭터별 전용 스킬 추가

#### 1.1 코만도(Soldier) 전용 스킬 풀 추가
```python
SOLDIER_EXCLUSIVE_SKILLS = {
    "soldier_ak47_unlock": {
        "name": "AK-47 해금",
        "max_level": 1,
        "descriptions": {1: "AK-47 무기 사용 가능"},
        "detail": "강력한 AK-47을 사용할 수 있게 됩니다.",
        "icon_color": (150, 150, 150),
        "tree": "special",
        "character_restriction": "soldier"
    },
    # 추가 스킬...
}
```

#### 1.2 발토르(Blacksmith) 전용 스킬 풀 추가
```python
BLACKSMITH_EXCLUSIVE_SKILLS = {
    "blacksmith_divine_enhance": {
        "name": "디바인스톤 강화",
        "max_level": 3,
        "descriptions": {...},
        "detail": "디바인스톤 효과가 강화됩니다.",
        "icon_color": (255, 215, 0),
        "tree": "special",
        "character_restriction": "blacksmith"
    },
    # 추가 스킬...
}
```

### Phase 2: 옵티머스 시스템 통합

#### 2.1 옵티머스 전용 스킬을 런타임 시스템으로 이전
```python
OPTIMUS_EXCLUSIVE_SKILLS = {
    "mecha_chain": {...},
    "mecha_charge": {...},
    "mecha_bulk": {...},
    "emergency_charge": {...},
    "reboot_enhance": {...},
    "bug_update": {...},
    "elec_pad": {...},
    "optimus_arm": {...},
    "star_change": {...},
}
```

#### 2.2 `get_runtime_skill_choices()` 수정
- soldier → SOLDIER_EXCLUSIVE_SKILLS 추가
- blacksmith → BLACKSMITH_EXCLUSIVE_SKILLS 추가
- optimus → OPTIMUS_EXCLUSIVE_SKILLS 추가

### Phase 3: 스킬 효과 통합

#### 3.1 `get_runtime_skill_bonus()` 확장
- 코만도 전용 스킬 효과 추가
- 발토르 전용 스킬 효과 추가
- 옵티머스 전용 스킬 효과 병합

### Phase 4: 게임 루프 통합

#### 4.1 스타포인트 수집 → 선택지 팝업 (모든 캐릭터)
- 라인 89632 근처에서 이미 처리됨
- 캐릭터 타입 체크 확장 필요

#### 4.2 기존 옵티머스 경험치 시스템 제거
- `optimus_exp_orbs` 관련 코드 비활성화
- 스타포인트 시스템으로 통일

### Phase 5: 아카데미 제거/비활성화

#### 5.1 광장에서 아카데미 NPC 수정
- 스킬 투자 기능 제거
- 새로운 기능으로 대체 (예: 스킬 풀 해금)

#### 5.2 academy.py 의존성 정리
- `get_skill_bonus()` 호출 제거 (이미 fallback으로 처리됨)
- 필요시 완전 제거

## 파일 수정 목록

| 파일 | 수정 내용 |
|------|----------|
| pingfighter.py | 캐릭터별 전용 스킬 풀 추가, get_runtime_skill_choices 수정, get_runtime_skill_bonus 확장 |
| academy.py | 아카데미 UI/기능 비활성화 (나중에) |

## 수정할 주요 라인 번호

- 2785-2810: 스매셔 전용 스킬 (참고용)
- 2837-2950: 옵티머스 스킬 풀 (통합 대상)
- 8524-8595: get_runtime_skill_choices (캐릭터별 분기 추가)
- 8613-8654: get_runtime_skill_bonus (효과값 추가)
- 89632: 메인 루프에서 스킬 선택 호출

## 작업 순서 (수정됨)

1. ✅ 현재 시스템 분석 완료
2. [건너뜀] 코만도 전용 스킬 풀 - 나중에 추가
3. [건너뜀] 발토르 전용 스킬 풀 - 나중에 추가
4. [ ] 옵티머스 전용 스킬을 런타임 형식으로 변환 (`OPTIMUS_EXCLUSIVE_SKILLS`)
5. [ ] `get_runtime_skill_choices()` 수정 - 옵티머스 분기 추가
6. [ ] `get_runtime_skill_bonus()` 확장 - 옵티머스 스킬 효과 추가
7. [ ] 게임 루프에서 모든 캐릭터에 런타임 스킬 시스템 적용
8. [ ] 옵티머스 레거시 경험치 시스템 비활성화
9. [ ] 테스트

## 구현 상세

### Step 1: 옵티머스 전용 스킬을 런타임 형식으로 변환

기존 `OPTIMUS_SKILL_POOL` (리스트)를 `OPTIMUS_EXCLUSIVE_SKILLS` (딕셔너리)로 변환:

```python
OPTIMUS_EXCLUSIVE_SKILLS = {
    "mecha_chain": {
        "name": "메카체인",
        "max_level": 4,
        "descriptions": {1: "게이지 감소율 10% 감소", ...},
        "icon_color": (100, 200, 255),
        "tree": "optimus",
        "character_restriction": "optimus"
    },
    # ... 나머지 스킬들
}
```

### Step 2: get_runtime_skill_choices() 수정

```python
# 라인 8554 근처에 추가
if character_type == "optimus":
    for skill_id, skill_data in OPTIMUS_EXCLUSIVE_SKILLS.items():
        # 스킬 추가 로직
```

### Step 3: get_runtime_skill_bonus() 확장

```python
# 라인 8644 근처에 옵티머스 스킬 효과 추가
"mecha_chain": level * 0.10,  # 게이지 감소율 10%/레벨 감소
"mecha_charge": level * 0.10,  # 충전량 10%/레벨 증가
# ... 나머지 효과들
```

### Step 4: 게임 루프 수정

현재 라인 89632에서 이미 `runtime_skill_choice_pending` 체크가 있음.
모든 캐릭터에서 작동하도록 조건 확인 필요.

### Step 5: 옵티머스 레거시 시스템 비활성화

- 경험치 오브 생성 비활성화 (라인 8098 근처)
- 옵티머스 전용 선택 UI 대신 공용 런타임 UI 사용