# Legacy 코만도 화기류 시스템 개발 가이드

현재 제품: Godot **환격전**. 영문 제품명은 미정이며, 아래 옛 이름은
호환성/역사 식별자로만 보존한다.

이 문서는 frozen Python/Pygame PingFighter의 코만도 화기류 구현
가이드다. 아래 `pingfighter.py` / `pygame` 예시는 레거시 참고용이며,
새 화기류 또는 런타임 수정은 `docs/commando_godot_port_plan.md`,
`docs/commando_firearm_overhaul.md`, `docs/character_skill_perk_checklist.md`
를 함께 열고 `godot/`의 코만도 owner module, renderer, audio owner,
HUD tooltip, save/load state, smoke test에 매핑해서 진행한다.

원본 PingFighter 소스 작업을 명시적으로 요청받은 경우에만 아래
Python 체크리스트를 실행 기준으로 사용한다.

## 개요
신규 화기류 추가 시 반드시 따라야 할 체크리스트와 구현 가이드입니다.

---

## 📋 신규 화기류 추가 체크리스트

### 필수 구현 항목 (순서대로)

- [ ] **1. 화기류 클래스 정의** - 새 무기 클래스 생성
- [ ] **2. SoldierController에 등록** - 무기 목록에 추가
- [ ] **3. 획득 시스템 구현** - supply_drop.py에 추가
- [ ] **4. 화기류 HUD 아이콘** - draw_soldier_weapon_ui에 그리기
- [ ] **5. 좌측 하단 UI 박스** - weapon_rect 영역에 렌더링
- [ ] **6. 획득 시 깜빡임 효과** - ui_highlight_timer 트리거
- [ ] **7. 탄환 UI 정렬** - 무기 박스 가로길이에 맞춤
- [ ] **8. 노후화 시스템** - degraded 상태 처리
- [ ] **9. 탄약상자 재장전** - ammo_box.py에 등록
- [ ] **10. 비상보급 재장전** - 비상보급 시스템에 등록
- [ ] **11. 개발자 모드 탭** - 테스트 설정 추가

---

## 1. 화기류 클래스 정의

### 위치: `pingfighter.py` 또는 별도 모듈

```python
class NewWeapon:
    """신규 화기류 클래스"""

    def __init__(self):
        # 필수 속성
        self.ammo_count = 3           # 현재 탄약
        self.max_ammo = 3             # 최대 탄약
        self.is_active = False        # 활성화 상태
        self.cooldown = 0             # 쿨다운 타이머
        self.fire_cooldown = 60       # 발사 간격 (프레임)

        # 노후화 관련
        self.shots_fired = 0          # 발사 횟수
        self.deterioration_threshold = 10  # 노후화 임계값

    def fire(self):
        """발사 메서드"""
        if self.ammo_count > 0 and self.cooldown <= 0:
            self.ammo_count -= 1
            self.shots_fired += 1
            self.cooldown = self.fire_cooldown
            return True
        return False

    def reload(self, track_reload=False):
        """재장전 메서드 - 탄약상자용"""
        self.ammo_count = self.max_ammo
        if track_reload:
            print(f"🔄 신규무기 재장전 완료!")

    def update(self):
        """매 프레임 업데이트"""
        if self.cooldown > 0:
            self.cooldown -= 1
```

---

## 2. SoldierController 등록

### 위치: `pingfighter.py` - SoldierController 클래스

```python
class SoldierController:
    def __init__(self):
        # 기존 무기들
        self.pistol = Pistol()
        self.bazooka = Bazooka()
        self.ak47 = AK47()
        self.net_gun = NetGun()
        self.fire_support = FireSupport()

        # 🆕 신규 무기 추가
        self.new_weapon = NewWeapon()

        # 무기 목록 (획득 가능한 무기들)
        self.weapons = ["pistol"]  # 기본 무기
        self.current_index = 0

        # 노후화 추적
        self.degraded = set()

    def add_weapon(self, weapon_name):
        """무기 획득"""
        if weapon_name not in self.weapons:
            self.weapons.append(weapon_name)
            self.ui_highlight_timer = self.ui_highlight_duration  # 깜빡임 트리거!
            return True
        return False
```

---

## 3. 획득 시스템 (Supply Drop)

### 위치: `supply_drop.py` - SUPPLY_ITEMS 딕셔너리

```python
# supply_drop.py 라인 20-31 부근

SUPPLY_ITEMS = {
    "grenade": 8,
    "molotov": 8,
    "flare": 10,
    "spider_mine": 4,
    "bazooka": 3,
    "ak47": 3,
    "net_gun": 3,
    "ammo_box": 8,
    "fire_support": 2,
    "suicide_drone": 3,
    "doping_potion": 5,

    # 🆕 신규 무기 추가 (드롭 확률 가중치)
    "new_weapon": 3,  # 낮을수록 희귀
}
```

### 위치: `pingfighter.py` - 아이템 획득 처리

```python
# pingfighter.py 라인 21543-21596 부근

# 🆕 신규 무기 획득 처리 추가
elif item_name == "new_weapon":
    if soldier_controller.add_weapon("new_weapon"):
        print(f"🔫 신규무기 획득! 현재 화기류: {soldier_controller.weapons}")
        # 획득 효과음, 메시지 등
```

---

## 4. 화기류 HUD 아이콘 그리기

### 위치: `pingfighter.py` - draw_soldier_weapon_ui 함수 (라인 28216)

```python
def draw_soldier_weapon_ui(screen):
    """좌측 하단 화기류 UI 그리기"""

    # UI 기본 설정
    slot_size = 60
    slot_margin = 10
    bottom_margin = 80
    weapon_size = int(slot_size * 0.8)  # 48px

    weapon_x = slot_margin
    weapon_y = HEIGHT - bottom_margin - slot_size - weapon_size + 15

    # 무기별 아이콘 그리기
    current_weapon = soldier_controller.weapons[soldier_controller.current_index]

    if current_weapon == "new_weapon":
        draw_new_weapon_icon(screen, weapon_x, weapon_y, weapon_size, is_active)
```

### 아이콘 그리기 함수 템플릿

```python
def draw_new_weapon_icon(screen, x, y, size, is_active):
    """신규 무기 아이콘 그리기

    Args:
        screen: pygame 화면
        x, y: 좌측 상단 좌표
        size: 아이콘 크기 (48px 기준)
        is_active: 활성화 상태
    """
    # 색상 설정 (활성/비활성)
    if is_active:
        body_color = (139, 90, 43)      # 갈색 (활성)
        metal_color = (100, 100, 100)   # 금속색
        accent_color = (255, 200, 0)    # 강조색
    else:
        body_color = (80, 80, 80)       # 회색 (비활성)
        metal_color = (60, 60, 60)
        accent_color = (100, 100, 100)

    # 중앙 좌표 계산
    cx = x + size // 2
    cy = y + size // 2

    # 메인 바디 (예: 총신)
    body_rect = pygame.Rect(x + 4, cy - 3, size - 8, 6)
    pygame.draw.rect(screen, body_color, body_rect)

    # 디테일 추가 (손잡이, 조준기 등)
    # ... 무기 컨셉에 맞게 커스터마이즈

    # 하이라이트 (활성 시)
    if is_active:
        pygame.draw.rect(screen, accent_color, body_rect, 1)
```

### 기존 무기 아이콘 참고

| 무기 | 주요 구성요소 | 라인 |
|------|--------------|------|
| Bazooka | 튜브, 스코프, 그립, 머즐 | 28352-28436 |
| AK-47 | 리시버, 탄창, 개머리판, 가스튜브 | 28500+ |
| Net Gun | 카트리지, 스프링, 네트 | - |
| Fire Support | 항공기 형태 | - |

---

## 5. 좌측 하단 UI 박스

### 박스 레이아웃

```
┌────────────────────────────────┐
│  ┌──────────┐                  │
│  │  WEAPON  │ ← weapon_rect    │
│  │   ICON   │   (48x48px)      │
│  │  48x48   │                  │
│  └──────────┘                  │
│  ┌──────────┐                  │
│  │ AMMO UI  │ ← 탄환 UI        │
│  └──────────┘   (박스 가로에 맞춤)│
└────────────────────────────────┘
  ↑
  weapon_x = 10px (좌측 여백)
```

### 박스 그리기

```python
# 무기 박스 영역
weapon_rect = pygame.Rect(weapon_x, weapon_y, weapon_size, weapon_size)

# 비활성 상태: 회색 박스
pygame.draw.rect(screen, (40, 40, 40), weapon_rect)
pygame.draw.rect(screen, (100, 100, 100), weapon_rect, 2)

# 활성 상태: 올리브 + 금색 테두리
pygame.draw.rect(screen, (60, 60, 40), weapon_rect)
pygame.draw.rect(screen, (200, 180, 100), weapon_rect, 2)
```

---

## 6. 획득 시 깜빡임 효과

### 트리거 방법

```python
# 무기 획득 시 깜빡임 시작
soldier_controller.ui_highlight_timer = soldier_controller.ui_highlight_duration

# ui_highlight_duration 기본값: 약 90프레임 (1.5초)
```

### 깜빡임 렌더링 (라인 28299-28318)

```python
highlight_active = soldier_controller.ui_highlight_timer > 0

if highlight_active:
    # 펄스 계산 (사인파)
    pulse = int(128 + 127 * math.sin(soldier_controller.ui_highlight_timer * 0.3))
    glow_color = (255, pulse, 0)  # 금색 펄스

    # 외부 글로우 (3겹)
    for i in range(3, 0, -1):
        glow_rect = weapon_rect.inflate(i * 4, i * 4)
        alpha = 80 - i * 20
        glow_surface = pygame.Surface((glow_rect.width, glow_rect.height), pygame.SRCALPHA)
        pygame.draw.rect(glow_surface, (*glow_color, alpha), glow_surface.get_rect(), 2)
        screen.blit(glow_surface, glow_rect.topleft)

    # 강조 배경
    pygame.draw.rect(screen, (60, 60, 40), weapon_rect)
    pygame.draw.rect(screen, glow_color, weapon_rect, 4)

    # 타이머 감소
    soldier_controller.ui_highlight_timer -= 1
```

---

## 7. 탄환 UI 정렬

### 탄환 UI는 무기 박스 가로 길이에 맞춰 정렬

```python
# 탄환 UI 위치 계산
ammo_y = weapon_y + weapon_size + 6  # 무기 박스 바로 아래

# 가로 정렬 (균등 배치)
padding_x = 6
available_w = weapon_rect.width - padding_x * 2

# 탄환 개수에 따른 간격 계산
ammo_spacing = available_w / max(1, max_ammo - 1) if max_ammo > 1 else 0
ammo_width = max(6, min(12, int((available_w / max_ammo) * 0.55)))
```

### 무기별 탄환 UI 스타일

```python
# 바주카 - 로켓탄 형태
def draw_rocket_ammo(screen, x, y, width, height, is_loaded):
    if is_loaded:
        # 탄두 (빨강)
        pygame.draw.rect(screen, (200, 50, 50), (x, y, width//3, height))
        # 몸체 (회색)
        pygame.draw.rect(screen, (80, 80, 80), (x + width//3, y, width//3, height))
        # 추진부 (금색)
        pygame.draw.rect(screen, (255, 200, 0), (x + width*2//3, y, width//3, height))
    else:
        # 빈 슬롯 (테두리만)
        pygame.draw.rect(screen, (70, 70, 70), (x, y, width, height), 1)

# AK-47 - 탄창 + 총알 형태
def draw_magazine_ammo(screen, x, y, ammo_count, max_ammo):
    # 탄창 외형
    mag_width = 12
    mag_height = 20
    pygame.draw.rect(screen, (60, 60, 60), (x, y, mag_width, mag_height))

    # 총알 표시 (노란 점)
    bullet_spacing = mag_height / max_ammo
    for i in range(ammo_count):
        bullet_y = y + mag_height - (i + 1) * bullet_spacing
        pygame.draw.circle(screen, (255, 200, 0), (x + mag_width//2, int(bullet_y)), 2)

# 🆕 신규 무기 - 컨셉에 맞게 디자인
def draw_new_weapon_ammo(screen, x, y, ammo_count, max_ammo):
    # 무기 특성에 맞는 탄환 UI 구현
    pass
```

---

## 8. 노후화 시스템

### 노후화 조건 설정

```python
# 무기별 노후화 임계값
DETERIORATION_THRESHOLDS = {
    "bazooka": 8,      # 8발 발사 후 노후화
    "ak47": 90,        # 90발 발사 후 노후화
    "net_gun": 6,      # 6발 발사 후 노후화
    "fire_support": 5, # 5회 호출 후 노후화
    "new_weapon": 10,  # 🆕 신규 무기 임계값
}
```

### 노후화 체크 및 처리

```python
# pingfighter.py 라인 22548 부근

def check_deterioration(weapon_name):
    """노후화 체크"""
    weapon = getattr(soldier_controller, weapon_name, None)
    if weapon and weapon.shots_fired >= DETERIORATION_THRESHOLDS.get(weapon_name, 999):
        if weapon_name not in soldier_controller.degraded:
            soldier_controller.degraded.add(weapon_name)
            print(f"⚠️ {get_item_name_korean(weapon_name)} 노후화!")
            return True
    return False
```

### 노후화 UI 표시 (라인 29417-29420)

```python
# 무기명 아래에 "노후화" 표시
if weapon_name in soldier_controller.degraded:
    degraded_text = small_font.render("노후화", True, (180, 100, 100))
    screen.blit(degraded_text, (text_x, text_y + 15))
```

### 노후화 상태 저장/로드

```python
# 게임 저장 시
save_data["degraded"] = list(soldier_controller.degraded)

# 게임 로드 시
soldier_controller.degraded = set(save_data.get("degraded", []))

# 새 게임 시작 시
soldier_controller.degraded.clear()
```

---

## 9. 탄약상자 재장전 등록

### 위치: `item_effects/ammo_box.py`

```python
class AmmoBox:
    def __init__(self):
        # 지원 무기 목록
        self.supported_weapons = [
            "pistol",
            "bazooka",
            "ak47",
            "net_gun",
            "fire_support",
            "new_weapon",  # 🆕 신규 무기 추가
        ]

    def activate(self, soldier_controller):
        """탄약상자 사용"""

        # 🆕 신규 무기 재장전 로직 추가
        if "new_weapon" in soldier_controller.weapons:
            new_weapon = soldier_controller.new_weapon

            # 노후화 체크 - 노후화된 무기는 재장전 불가
            if "new_weapon" in soldier_controller.degraded:
                print("⚠️ 노후화된 신규무기에는 재장전할 수 없습니다.")
            else:
                new_weapon.reload(track_reload=True)
                self.reloaded_weapon = "new_weapon"
```

### 재장전 애니메이션 추가

```python
def draw_effects(self, screen, **kwargs):
    """재장전 애니메이션"""

    if self.reloaded_weapon == "new_weapon":
        # 신규 무기 전용 애니메이션
        # 예: 탄창 교체, 장전 모션 등
        self._draw_new_weapon_reload_animation(screen)
```

---

## 10. 비상보급 재장전 등록

### 위치: `pingfighter.py` - 비상보급 처리 부분 (라인 22818 부근)

```python
def use_emergency_supply():
    """비상보급 사용"""
    current_weapon = soldier_controller.weapons[soldier_controller.current_index]

    # 노후화 체크
    if current_weapon != "pistol" and current_weapon in soldier_controller.degraded:
        print(f"⚠️ 노후화된 {get_item_name_korean(current_weapon)}에는 비상보급을 사용할 수 없습니다.")
        return False

    # 무기별 재장전
    if current_weapon == "new_weapon":
        soldier_controller.new_weapon.reload()
        soldier_emergency_supply_toast_timer = 90  # 토스트 알림
        return True

    # 기존 무기 처리...
```

### 비상보급 토스트 알림

```python
# 라인 28324-28341
if soldier_emergency_supply_toast_timer > 0:
    toast_ratio = soldier_emergency_supply_toast_timer / 90
    toast_alpha = max(0, min(255, int(255 * toast_ratio)))
    bounce_offset = int(4 * math.sin(pygame.time.get_ticks() * 0.03))

    # "비상보급!" 텍스트
    toast_surface = small_font.render("비상보급!", True, (255, 255, 210))
    toast_surface.set_alpha(toast_alpha)

    text_x = weapon_rect.right + 16
    text_y = weapon_rect.centery + bounce_offset
    screen.blit(toast_surface, (text_x, text_y))

    soldier_emergency_supply_toast_timer -= 1
```

---

## 11. 개발자 모드 탭 추가

### 위치: `pingfighter.py` - 개발자 모드 설정 (라인 20496-20563)

```python
def _configure_soldier_weapon_preview(animation_id: str):
    """개발자 모드 무기 미리보기 설정"""

    # 테스트 시나리오 1: 모든 무기
    if animation_id == "all_weapons":
        soldier_controller.weapons[:] = [
            "pistol", "bazooka", "ak47",
            "net_gun", "fire_support",
            "new_weapon"  # 🆕 신규 무기 포함
        ]

    # 테스트 시나리오 2: 신규 무기만
    elif animation_id == "new_weapon_test":
        soldier_controller.weapons[:] = ["pistol", "new_weapon"]
        soldier_controller.current_index = 1

    # 테스트 시나리오 3: 노후화 테스트
    elif animation_id == "degraded_test":
        soldier_controller.weapons[:] = ["pistol", "new_weapon"]
        soldier_controller.degraded.add("new_weapon")
```

### 개발자 모드 UI 프리뷰

```python
def _get_soldier_weapon_ui_preview_rect() -> pygame.Rect:
    """개발자 모드 미리보기 영역"""
    slot_size = 60
    slot_margin = 10
    bottom_margin = 80
    weapon_size = int(slot_size * 0.8)

    weapon_x = slot_margin
    weapon_y = HEIGHT - bottom_margin - slot_size - weapon_size + 15

    preview_width = max(220, weapon_size + 170)
    preview_height = weapon_size + 120

    return pygame.Rect(weapon_x - 12, weapon_y - 24, preview_width, preview_height)
```

---

## 12. 한글 이름 등록

### 위치: `pingfighter.py` - get_item_name_korean 함수

```python
def get_item_name_korean(item_name):
    """아이템 한글 이름 반환"""
    names = {
        "pistol": "권총",
        "bazooka": "바주카포",
        "ak47": "AK-47",
        "net_gun": "그물덫총",
        "fire_support": "화력지원",
        "new_weapon": "신규무기",  # 🆕 추가
        # ...
    }
    return names.get(item_name, item_name)
```

---

## 빠른 참조 테이블

| 항목 | 파일 위치 | 라인 번호 |
|------|----------|----------|
| 무기 클래스 | pingfighter.py | 상단 클래스 정의 |
| SoldierController | pingfighter.py | 상단 |
| Supply Drop 설정 | supply_drop.py | 20-31 |
| 획득 처리 | pingfighter.py | 21543-21596 |
| HUD 그리기 | pingfighter.py | 28216 |
| 좌측 UI 박스 | pingfighter.py | 28285-28323 |
| 깜빡임 효과 | pingfighter.py | 28299-28318 |
| 탄환 UI | pingfighter.py | 28438-28469 |
| 아이콘 그리기 | pingfighter.py | 28352-28620 |
| 노후화 체크 | pingfighter.py | 22548 |
| 노후화 UI | pingfighter.py | 29417-29420 |
| 탄약상자 | item_effects/ammo_box.py | 27-284 |
| 비상보급 | pingfighter.py | 22818, 28324-28341 |
| 개발자 모드 | pingfighter.py | 20496-20563 |
| 한글 이름 | pingfighter.py | get_item_name_korean |

---

## 아이콘 디자인 가이드라인

### 일관된 스타일 유지

1. **크기**: 48x48 픽셀 기준
2. **색상 팔레트**:
   - 활성: 갈색(139,90,43), 금속(100,100,100), 강조(255,200,0)
   - 비활성: 회색(80,80,80), 어두운 회색(60,60,60)
3. **선 두께**: 1-2px
4. **디테일**: 최소 3개 이상의 구성요소 (몸체, 손잡이, 특징적 부분)

### 무기 컨셉별 권장 요소

| 무기 타입 | 권장 구성요소 |
|----------|-------------|
| 발사체 | 총신, 트리거, 탄창/카트리지 |
| 폭발물 | 튜브, 조준기, 그립 |
| 특수무기 | 고유 메커니즘, 특수 장치 |
| 지원무기 | 통신기, 호출 장치 |

---

## 주의사항

1. **UI 깜빡임**: `add_weapon()` 호출 시 자동으로 트리거되므로 별도 처리 불필요
2. **노후화**: 권총(pistol)은 노후화되지 않음 - 기본 무기 보장
3. **탄약상자 제한**: 노후화된 무기는 재장전 불가능하도록 체크 필수
4. **개발자 모드**: 새 무기 추가 시 테스트 시나리오도 함께 추가

---

*마지막 업데이트: 2024년*
*버전: 1.0*
