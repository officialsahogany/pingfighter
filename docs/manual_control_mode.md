# 투기장 수동 조작 모드 (Manual Control Mode)

**커밋**: `30f31f25` (feature/refactor-ui)  
**수정 파일**: `downtown/colosseum_arena.py` (+216줄, -14줄)  
**작성일**: 2026-04-10

---

## 1. 기획 요약

기존 투기장은 AI vs AI 자동 전투만 지원했다.  
수동 모드를 추가하여 플레이어가 하단 영웅을 직접 조작할 수 있게 한다.

| 항목 | 자동 (기존) | 수동 (신규) |
|------|------------|------------|
| 패들 이동 | AI (`AIPaddleController.update()`) | A/D 또는 ←/→ 방향키 |
| ON_COOLDOWN 스킬 | 쿨타임 되면 확률적 자동 발동 | 마우스 좌클릭으로 수동 발동 |
| ON_BALL_HIT 스킬 | 공 타격 시 자동 발동 | 공 타격 시 자동 발동 (동일) |
| 배속 | 1x ~ 3x 조절 가능 | 강제 1x 고정, 변경 불가 |
| 전환 | - | 배틀 중 토글 버튼 클릭 |

### 스킬 발동 규칙
- 영웅당 스킬은 보통 1개 (게임 시작 전 2개 중 1개 랜덤 선택)
- 추가스킬 퍽으로 2개가 되는 경우: **먼저 쿨타임이 충전된 스킬**을 발동
- 둘 다 충전된 상태에서도 먼저 충전된 것이 우선

---

## 2. 변경 지점 요약

### 2.1 상태 변수 추가 (`__init__`, L7599-7603)

```python
# 수동 조작 모드 (플레이어가 하단 영웅을 직접 컨트롤)
self.manual_control_active = False        # 자동/수동 토글
self.manual_control_btn_rect = None       # 토글 버튼 클릭 영역 (pygame.Rect)
self.manual_move_left = False             # A/← 키 누름 상태
self.manual_move_right = False            # D/→ 키 누름 상태
self.manual_skill_cooldown_order = []     # 스킬 충전 완료 순서 추적 [skill_id, ...]
```

---

### 2.2 배틀 업데이트 분기 (`update_battle`, L8683, L8736-8738)

```python
# 배속 강제 1x (수동 모드)
if self.manual_control_active:
    self.speed_multiplier = 1
dt *= self.speed_multiplier

# ...

# 하단 패들: 수동이면 플레이어 입력, 아니면 AI
if self.manual_control_active:
    self._update_manual_paddle(dt)
else:
    self.bottom_paddle.update(ball_x, ball_y, ball_vx, ball_vy, dt)
```

**설계 의도**: 상단 패들(상대 영웅)은 항상 AI. 하단 패들만 수동/자동 분기.

---

### 2.3 수동 패들 이동 (`_update_manual_paddle`, L9041-9095)

```python
def _update_manual_paddle(self, dt: float):
```

**처리 순서**:
1. `update_dash(dt)` / `update_ghost_step(dt)` — 대쉬, 귀신발걸음 물리는 유지
2. 스턴/대쉬 중이면 이동 불가 (AI와 동일 규칙)
3. `manual_move_left` / `manual_move_right` 플래그로 이동 방향 결정
4. 혼란(`is_confused`) 상태면 방향 반전
5. `base_speed` * `slow_multiplier`로 목표 속도 계산
6. 가속도 0.5 적용 (부드러운 이동감)
7. 키 미입력 시 `velocity *= 0.85` 감속
8. 중력 드리프트, 경계 클램핑 적용

**AI `update()`와의 차이점**:
- AI는 공 위치 예측 → 목표 좌표 설정 → 추적 이동
- 수동은 키 입력 방향 → 직접 속도 부여 → 물리 적용
- 대쉬/스턴/혼란/둔화 등 스킬 상태 효과는 동일하게 적용됨

---

### 2.4 ON_COOLDOWN 스킬 자동 발동 제어 (`_try_use_cooldown_skills`, L9017)

```python
# 하단 영웅 스킬 (수동 모드에서는 자동 발동 안함)
if self.selected_match and not self.manual_control_active:
    # 기존 AI 자동 발동 로직 (스타일별 확률 차등)
    ...
```

**추가: 충전 순서 추적** (L9033-9039)
```python
# 수동 모드: 스킬 충전 완료 순서 추적
if self.manual_control_active and self.selected_match and self.skill_manager:
    hero_id = self.selected_match.hero2["id"]
    skills = self.skill_manager.active_skills.get(hero_id, [])
    for s in skills:
        if s.can_use() and s.trigger != SkillTrigger.PASSIVE:
            if s.skill_id not in self.manual_skill_cooldown_order:
                self.manual_skill_cooldown_order.append(s.skill_id)
```

`_try_use_cooldown_skills()`는 0.5초 간격으로 호출되므로, 스킬이 사용 가능해지는 시점을 자연스럽게 추적한다.

---

### 2.5 수동 스킬 발동 (`_manual_try_use_skill`, L9097-9141)

```python
def _manual_try_use_skill(self):
```

**발동 우선순위**:
1. `manual_skill_cooldown_order` 리스트 순회 (먼저 충전된 순서)
2. `usable` 목록(쿨타임 완료 + 비패시브)과 교차 매칭
3. 매칭되면 해당 스킬 발동
4. 매칭 없으면 `usable[0]` 폴백
5. 발동 후 해당 skill_id를 `manual_skill_cooldown_order`에서 제거

**호출 시점**: `handle_event()` 내 MOUSEBUTTONDOWN → 배틀 중 + 수동 모드 + 토글/배속 버튼 영역이 아닌 좌클릭

---

### 2.6 이벤트 처리 (`handle_event`, L10350-10369, L10988-11015)

#### 키보드 입력 (KEYDOWN/KEYUP)
```python
# 수동 모드 키보드 입력 (기존 KEYDOWN 처리보다 앞에 배치)
if self.state == TournamentState.BATTLE and self.manual_control_active:
    if event.type == pygame.KEYDOWN:
        if event.key in (pygame.K_a, pygame.K_LEFT):
            self.manual_move_left = True
            return False
        elif event.key in (pygame.K_d, pygame.K_RIGHT):
            self.manual_move_right = True
            return False
    elif event.type == pygame.KEYUP:
        if event.key in (pygame.K_a, pygame.K_LEFT):
            self.manual_move_left = False
            return False
        elif event.key in (pygame.K_d, pygame.K_RIGHT):
            self.manual_move_right = False
            return False
```

**배치 위치**: 기존 `pygame.KEYDOWN` 블록 **앞**에 배치하여 A/D 키가 다른 핸들러에 먹히지 않도록 함.

#### 토글 버튼 클릭 (MOUSEBUTTONDOWN)
```python
# 자동/수동 토글 버튼
if self.manual_control_btn_rect and self.manual_control_btn_rect.collidepoint(mx, my):
    self.manual_control_active = not self.manual_control_active
    if self.manual_control_active:
        self.speed_multiplier = 1          # 배속 1x 강제
        self.manual_move_left = False      # 키 상태 초기화
        self.manual_move_right = False
        self.manual_skill_cooldown_order = []
    return
```

#### 배속 버튼 차단
```python
if self.manual_control_active:
    pass  # 수동 모드에서는 배속 변경 불가
```

#### 좌클릭 스킬 발동
```python
if self.state == TournamentState.BATTLE and self.manual_control_active:
    if self.skill_manager and ...:
        self._manual_try_use_skill()
    return  # 다른 클릭 핸들러로 전파 안함
```

---

### 2.7 UI 렌더링

#### 토글 버튼 (`_draw_manual_control_button`, L13028-13050)
- **위치**: 배속 버튼 바로 아래 (x=445, y=44, 50x22px)
- **수동 활성**: 초록색 배경 `(80, 180, 120)`, "수동" 텍스트
- **자동 상태**: 회색 배경 `(50, 55, 65)`, "자동" 텍스트
- `_draw_battle()` 내에서 `_draw_speed_buttons()` 직후 호출

#### 배속 버튼 비활성화 표시 (`_draw_speed_buttons`, L13009)
```python
if self.manual_control_active and mult != 1:
    bg = (35, 38, 45)          # 어두운 배경
    text_color = (80, 80, 80)  # 흐린 텍스트
```

---

### 2.8 배틀 종료 초기화 (`_end_battle`, L9600-9602)

```python
# 수동 모드 키 입력 상태 초기화
self.manual_move_left = False
self.manual_move_right = False
self.manual_skill_cooldown_order = []
```

`manual_control_active`는 초기화하지 않음 — 다음 매치에서도 수동 모드 유지.

---

## 3. 데이터 플로우

```
[배틀 시작]
    │
    ▼
[토글 버튼 클릭] ──→ manual_control_active = True
    │                  speed_multiplier = 1 (강제)
    │                  키 상태 초기화
    ▼
[매 프레임 update_battle()]
    │
    ├── 상단 패들: AI update() (변경 없음)
    │
    ├── 하단 패들: manual_control_active?
    │       ├── True  → _update_manual_paddle(dt)
    │       │            A/D 키 플래그 → 속도 계산 → 위치 업데이트
    │       └── False → AI update() (기존)
    │
    ├── _try_use_cooldown_skills()
    │       ├── 상단: AI 자동 발동 (변경 없음)
    │       └── 하단: manual_control_active?
    │               ├── True  → 자동 발동 스킵 + 충전 순서 추적
    │               └── False → AI 자동 발동 (기존)
    │
    └── _on_ball_hit()
            └── ON_BALL_HIT 스킬: 양쪽 모두 자동 발동 (변경 없음)

[좌클릭 (배틀 중 + 수동)]
    │
    ▼
[_manual_try_use_skill()]
    ├── manual_skill_cooldown_order 순서대로 매칭
    ├── 매칭된 스킬 발동 (try_use_skill)
    └── 발동 후 순서 리스트에서 제거

[배틀 종료]
    └── 키 상태, 충전 순서 초기화
        (manual_control_active는 유지)
```

---

## 4. 기존 시스템과의 호환성

| 시스템 | 영향 | 비고 |
|--------|------|------|
| AI 패들 (`AIPaddleController`) | 변경 없음 | 상단은 항상 AI, 하단만 분기 |
| 스킬 매니저 (`HeroSkillManager`) | 변경 없음 | 동일한 `try_use_skill()` API 사용 |
| 폭탄 넉백 / 모래감옥 | 정상 작동 | `update_battle()`에서 수동 패들 후에도 동일 적용 |
| 하이라이트 녹화 | 정상 작동 | 화면 캡처 로직 변경 없음 |
| 퍽 시스템 | 정상 작동 | 퍽 효과는 패들 속성에 반영되므로 수동에서도 적용 |
| 호위무사 시스템 | 정상 작동 | 호위무사는 별도 로직, 수동과 무관 |
| 관중 반응 | 정상 작동 | 득점 기반이므로 조작 방식 무관 |

---

## 5. 향후 고려 사항

- **밸런스 조정**: 플레이어가 AI보다 잘하거나 못할 수 있음. 테스트 후 상대 AI 난이도 조절 또는 수동 전용 보상/랭킹 분리 검토
- **대쉬 수동 발동**: 현재 수동 모드에서 대쉬는 AI 긴급 대쉬 로직이 비활성 상태. 필요 시 별도 키(Shift 등)로 수동 대쉬 추가 가능
- **수동 모드 시각 피드백**: 수동 모드일 때 하단 패들에 외곽선 하이라이트 등 시각적 구분 추가 고려
