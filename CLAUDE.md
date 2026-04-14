# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
PingFighter (핑파이터) is a Python-based arcade-style table tennis game with boss battles, power-ups, and special abilities. Built with Pygame framework and runs on both Windows and macOS.

## ⚠️ CRITICAL: Stage Order Reference (스테이지 순서 - 절대 헷갈리지 말 것!)
**과거에 스테이지 5와 6의 순서가 바뀌었음! 코드 변수명과 실제 스테이지 번호가 다름!**

| Stage | Boss Name | Theme | Pillar | 코드 내 변수명 (주의!) |
|-------|-----------|-------|--------|----------------------|
| 1 | 풍악보이 | 한국 전통 | pillar_stadium | stage1 |
| 2 | 악어장군 | 정글/늪지 | pillar_jungle | stage2 |
| 3 | 멘헤라걸 | 멘헤라/인형 | pillar_menhera | stage3 |
| 4 | 퐁크 | 사원 | pillar_temple | stage4 |
| **5** | **네메시스** | **해상전투 (Ocean/Battleship)** | pillar_nemesis_ocean | **animated_bg_stage6** (주의!) |
| **6** | **홍련** | **중국/화염 (Chinese Fire)** | (추가 예정) | **animated_bg_stage5** (주의!) |

### ⚠️ 매우 중요: 코드 변수명 vs 실제 스테이지
- 코드에서 `stage5`, `animated_bg_stage5`, `Stage5ChineseMarket` = **실제 스테이지 6 홍련**
- 코드에서 `stage6`, `animated_bg_stage6`, `AnimatedBackgroundStage6` = **실제 스테이지 5 네메시스**
- **유저가 "스테이지 5 작업해줘" → 네메시스(해상) 관련 코드 수정**
- **유저가 "스테이지 6 작업해줘" → 홍련(화염) 관련 코드 수정**

### 스테이지 작업 시 주의사항
- **스테이지 5 = 네메시스 (해상전투/바다 테마)** - 전함, 바다, 레이더, 파도
- **스테이지 6 = 홍련 (중국/화염 테마)** - 중국 전통, 불꽃, 등롱

## ⚠️ CRITICAL: 화면 좌표 표준 규격 (Screen Coordinate Standards)
**아이템, 스킬, 투사체, 이펙트 등 모든 좌표 작업 시 반드시 이 규격을 따를 것!**

### ⚠️ 핵심: 게임 물리 영역 = 전체 화면 (0 ~ WIDTH)
**공, 패들, 투사체, 이펙트 등 모든 게임 오브젝트는 0 ~ 760 전체 너비에서 동작한다.**
필러(좌우 80px)는 게임 영역 위에 덮어 그리는 **UI 오버레이**일 뿐, 물리적 경계가 아니다.

```
┌─────────────────────── 760px (WIDTH) ───────────────────────┐
│          게임 물리 영역: 0 ~ 760 (공, 패들, 투사체 전부)       │
│                                                              │
│  ┌─ 필러 ─┐                                    ┌─ 필러 ─┐   │
│  │ 0~79   │      UI 오버레이 (위에 덮어 그림)     │680~759 │   │
│  │ 80px   │      아이템 스폰 중앙: 380px         │ 80px   │   │
│  └────────┘                                    └────────┘   │
│                                                              │
│  공 반사: BALL.left <= 0 → 반사 / BALL.right >= WIDTH → 반사  │
└──────────────────────────────────────────────────────────────┘
```

### 화면 크기 상수 (config/constants.py 참조)
| 상수명 | 값 | 설명 |
|--------|-----|------|
| `WIDTH` / `INTERNAL_WIDTH` | **760px** | **실제 게임 물리 영역 너비 (공/패들/이펙트 모두 이 범위)** |
| `HEIGHT` / `INTERNAL_HEIGHT` | **750px** | 전체 높이 |
| `PILLAR_UI_WIDTH` | **80px** | 좌우 필러 UI 오버레이 각각의 너비 (물리 경계 아님!) |
| `GAME_AREA_OFFSET_X` | **80px** | 필러 너비 (UI 배치용으로만 사용) |
| `GAME_PLAY_WIDTH` | **600px** | 필러 제외 중앙 영역 (UI 배치/아이템 스폰 기준용) |

### ⚠️ 좌표 작업 시 어떤 너비를 써야 하는가?
| 작업 종류 | 사용할 너비 | 범위 | 이유 |
|-----------|-------------|------|------|
| **이펙트/방어막/벽** | `WIDTH` (760) | 0 ~ 760 | 공이 전체 너비에서 움직이므로 |
| **공 반사/패들 이동** | `WIDTH` (760) | 0 ~ 760 | 물리 경계 = 전체 화면 |
| **아이템 스폰 위치** | `GAME_PLAY_WIDTH` (600) | 80 ~ 680 | 필러 뒤에 숨지 않도록 |
| **UI 요소 배치** | `GAME_PLAY_WIDTH` (600) | 80 ~ 680 | 필러와 겹치지 않도록 |
| **보스/패들 중앙 X** | `WIDTH // 2` (380) | - | 전체 화면 기준 중앙 |

```python
# ❌ 잘못된 예 - 이펙트/방어막에 GAME_PLAY_WIDTH 사용
barrier_left = GAME_AREA_OFFSET_X  # 80 → 틀림! 좌측 80px가 비어버림
barrier_width = GAME_PLAY_WIDTH    # 600 → 틀림! 실제 게임 영역보다 좁음

# ✅ 올바른 예 - 이펙트/방어막은 전체 너비 사용
barrier_left = 0       # 화면 시작
barrier_width = WIDTH  # 760 (전체)

# ✅ 올바른 예 - 아이템 스폰은 필러 제외 영역
spawn_x = GAME_AREA_OFFSET_X + random(0, GAME_PLAY_WIDTH)  # 80 ~ 680
```

### 게임 객체 Y 좌표 (매우 중요!)
| 객체 | Y 좌표 | 설명 |
|------|--------|------|
| **보스 패들** | `BOSS_Y = 25` | 화면 상단 25px |
| **보스 히트박스 하단** | `~65px` | BOSS_Y(25) + BOSS_HEIGHT(40) |
| **보스 진영 영역** | `Y = 0 ~ 120` | 보스가 활동하는 상단 영역 |
| **중앙선** | `Y = 375` | HEIGHT / 2 |
| **플레이어 패들** | `Y = 710` | HEIGHT(750) - 40 |
| **플레이어 진영 영역** | `Y = 630 ~ 750` | 플레이어가 활동하는 하단 영역 |

### 진영 구분 기준 (투사체, 아이템 판정용)
| 진영 | Y 좌표 범위 | 판정 기준 |
|------|-------------|-----------|
| 보스 진영 | `Y < 120` | 보스 패들 주변 영역 |
| 중립 지대 | `120 ≤ Y < 630` | 공이 왕복하는 영역 |
| 플레이어 진영 | `Y ≥ 630` | 플레이어 패들 주변 영역 |

## Architecture & Code Structure

### Core Files
- **pingfighter.py** - Main game file (25,829 lines) containing all game logic
- **academy.py** - Academy mode with skill system and training features
- **gacha.py** - Gacha system for item collection
- **opening.py** - Opening cinematic and menu system
- **items.py** - Item definitions and management
- **legendary_items.py** - Legendary item system
- **pixel_font_manager.py** - Font management with pixel art support

### Module Organization
```
bosspong/
├── core/               # Core systems (game state, constants, events)
├── game_logic/         # Game mechanics (physics, collision, AI)
├── game_mechanics/     # Special mechanics (half-dash system)
├── entities/           # Game objects (ball, paddle, boss)
├── ai/                 # AI and boss behavior systems
├── managers/           # Resource and effect managers
├── ui/                 # UI components (menus, HUD, dialogs)
├── rendering/          # Rendering systems
├── item_effects/       # Modular item effect implementations
├── events/             # Stage-specific event systems
├── backgrounds/        # Animated background systems
└── tests/              # Test files for various components
```

## Development Commands

### Running the Game
```bash
# macOS/Linux
python3 pingfighter.py

# Windows
python pingfighter.py
# or use the batch file:
run_game.bat
```

### Testing
```bash
# Test icon loading
python3 test_icons.py

# Test specific features
python3 test_[feature_name].py

# Run all tests with pytest
python -m pytest tests/
```

### Building Executables

#### Windows Build
```bash
# Using PyInstaller spec file
pyinstaller PingFighter_Windows.spec

# Manual build
pyinstaller --onefile --windowed \
  --add-data "items;items" \
  --add-data "sounds;sounds" \
  --add-data "fonts;fonts" \
  --add-data "backgrounds;backgrounds" \
  --icon="ball.ico" \
  pingfighter.py
```

#### macOS Build  
```bash
# Using PyInstaller spec file
pyinstaller PingFighter.spec

# Manual build (note the colon separator for macOS)
pyinstaller --onefile --windowed \
  --add-data "items:items" \
  --add-data "sounds:sounds" \
  --add-data "fonts:fonts" \
  --add-data "backgrounds:backgrounds" \
  --icon="ball.ico" \
  pingfighter.py
```

### Dependencies
```bash
# Install all dependencies
pip install -r requirements.txt

# Core requirements:
# - pygame>=2.5.0
# - numpy>=1.21.0
# - pyinstaller>=5.0.0 (for building)
# - pytest>=7.0.0 (for testing)
```

## Critical Development Guidelines

### Cross-Platform Path Handling
**ALWAYS use the resource_path() function for file access:**
```python
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS  # PyInstaller temp folder
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# Usage example:
font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
icon_path = resource_path(os.path.join("items", "technical_vest.png"))
```

### Item Icon Management
**Icons MUST be declared globally and assigned to ITEM_TYPES:**
```python
# 1. Declare globally at module level
technical_vest_icon = None

# 2. Use global keyword in initialization
def initialize_icons():
    global technical_vest_icon  # REQUIRED!
    technical_vest_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    # ... draw icon ...
    
    # 3. Assign to ITEM_TYPES dictionary
    items.ITEM_TYPES["TECHNICAL_VEST"]["icon"] = technical_vest_icon
```

### Korean Text Rendering
**Use pygame.freetype with appropriate fonts:**
```python
import pygame.freetype

# Initialize Korean font
korean_font = pygame.freetype.Font(
    resource_path(os.path.join("fonts", "NanumSquareB.ttf")), 24
)

# Render text
text_surface, text_rect = korean_font.render("한글 텍스트", (255, 255, 255))
```

## Game Systems & Integration Points

### Academy Skill System
State variables that must be reset on game session end:
```python
acceleration_skill_level = 0     # Dash sound restoration
acceleration_height_bonus = 0    # Bustup skill paddle height bonus
rolling_charges = 1              # Basic dash tokens without amplification
rolling_charge_timer = 0         # Dash token charge timer
```

Reset locations (3 places):
1. Game over - around line 20185
2. ESC menu return to main - around line 20965
3. Force quit flag - around line 20506

### Trade Point System
- `trade_point_collected`: Stars collected in current stage (resets per stage)
- `academy.skill_points`: Total skill points available (persists between stages)
- Base reward: 1 point per stage clear

### Event Processing Order (ESC Menu)
**IMPORTANT: Call pygame.event.get() before key state checks to prevent input freezing:**
```python
# Correct order:
for event in pygame.event.get():  # Process events first
    # handle events
keys = pygame.key.get_pressed()    # Then check key states
```

## Adding New Items - Complete Workflow

### Step 1: Create Item Module
Create in `item_effects/[item_name].py`:
```python
class [ItemClassName]:
    def __init__(self):
        self.active = False
        self.duration = 3600  # 60 seconds at 60 FPS
        
    def activate(self, game_state, current_stage):
        # Activation logic
        pass
    
    def update(self, current_stage):
        # Update logic
        pass
    
    def draw_effects(self, screen, **kwargs):
        # Visual effects
        pass

# Singleton instance
[item_name]_instance = None

def get_[item_name]_instance():
    global [item_name]_instance
    if [item_name]_instance is None:
        [item_name]_instance = [ItemClassName]()
    return [item_name]_instance
```

### Step 2: Register in items.py
```python
# Add to ITEM_TYPES array
{
    "name": "[item_name]",
    "color": (R, G, B),
    "effect": "[item_name]",
    "icon": None,
    "chance": 0.01,  # 1% spawn chance
    "duration": 600,
    "unlock_condition": None
}

# Add to unlocked_items
"[item_name]": True
```

### Step 3: Create Icon (REQUIRED)
- Create 32x32 PNG at `items/[item_name].png`
- Required for item to appear in TAB menu

### Step 4: Integrate in pingfighter.py
1. Import module (top of file)
2. Add to item manager UI (line ~14245)
3. Add Korean name (line ~24219)
4. Add item description (line ~24257) - **MUST include detailed effects**
5. Add activation handler (line ~2327)
6. Update get_item_icon() function (line ~14680) - **REQUIRED for icon display**

### Checklist for New Items
- [ ] Create `item_effects/[item_name].py` module
- [ ] Add to `items.py` ITEM_TYPES array
- [ ] Add to `items.py` unlocked_items
- [ ] Create `items/[item_name].png` icon (32x32)
- [ ] Add to item manager UI
- [ ] Update get_item_icon() function **[CRITICAL]**
- [ ] Add Korean name translation
- [ ] Add detailed item description **[CRITICAL]**
- [ ] Add activation handler
- [ ] Add update loop (for active items)
- [ ] Add visual effects rendering (if needed)
- [ ] Update gacha.py (for one-time passive items)
- [ ] Create `test_[item_name].py` test file

### ⚠️ CRITICAL: 패시브 아이템 추가 시 필수 체크리스트
**패시브 아이템이 필드에서 드랍/획득되지 않는 버그 방지를 위해 반드시 아래 모든 항목을 확인할 것!**

| # | 파일 | 위치 | 작업 내용 |
|---|------|------|----------|
| 1 | `items.py` | `ITEM_TYPES` 배열 | 아이템 정의 추가 (`chance`, `body_part` 등) |
| 2 | `items.py` | `unlocked_items` 딕셔너리 | `"[item_name]": True` 추가 **[필수!]** |
| 3 | `items.py` | `[item_name]_obtained` 변수 | 전역 변수 선언 (예: `gold_digger_obtained = False`) |
| 4 | `items.py` | `update_items()` 함수 내 패시브 목록 | 아이템 이름 추가 **[필수! 없으면 액티브로 처리됨]** |
| 5 | `items.py` | `spawn_random_item()` 내 `passive_names` | 아이템 이름 추가 (드랍 가중치 계산용) |
| 6 | `items.py` | `spawn_random_item()` 내 중복 방지 로직 | `if item["name"] == "[item_name]" and [item_name]_obtained...` 추가 |
| 7 | `items.py` | `PASSIVE_DUPLICATE_ALLOWED` 집합 | 중복 파밍 허용 시 추가 |
| 8 | `pingfighter.py` | `store_active_item()` 패시브 필터 목록 | 아이템 이름 추가 (액티브 슬롯 방지) |
| 9 | `pingfighter.py` | `store_passive_item()` 함수 | `elif item_data["name"] == "[item_name]":` 처리 추가 |
| 10 | `pingfighter.py` | `store_passive_item()` 중복 허용 로직 | **중복 허용 아이템은 `skip_append = True` 사용 금지!** ⚠️ |

```python
# items.py - update_items() 내 패시브 목록 (약 2227줄)
if item_name in ["speedboots", "speedgear", ..., "[NEW_ITEM_NAME]"]:

# items.py - spawn_random_item() 내 passive_names (약 2060줄)
passive_names = {
    "speedboots", "speedgear", ..., "[NEW_ITEM_NAME]"
}

# pingfighter.py - store_active_item() 패시브 필터 (약 59683줄)
if item_data["name"] in ["speedboots", ..., "[NEW_ITEM_NAME]"]:
    return
```

### ⚠️ CRITICAL: 중복 획득 허용 아이템의 store_passive_item() 구현 패턴
**PASSIVE_DUPLICATE_ALLOWED에 포함된 아이템은 반드시 아래 패턴을 따를 것!**

```python
# ❌ 잘못된 예 - 중복 획득 시 인벤토리에 추가 안됨
elif item_data["name"] == "gold_digger":
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        # 효과 적용...
    else:
        print("이미 보유 중입니다.")
        skip_append = True  # ❌ 이 줄이 문제! 두 번째 획득 시 인벤토리에 추가 안됨

# ✅ 올바른 예 - 중복 획득 시에도 인벤토리에 정상 추가
elif item_data["name"] == "gold_digger":
    # 첫 획득 시에만 활성화/장착 처리
    if not items.gold_digger_obtained:
        items.gold_digger_obtained = True
        from item_effects.gold_digger import activate_gold_digger, equip_gold_digger
        activate_gold_digger()
        equip_gold_digger()
        print("첫 획득!")
    # 롤 옵션과 인벤토리 추가는 항상 실행 (skip_append 없음!)
    item_data["type"] = "passive"
    ensure_passive_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
    # skip_append = True 절대 사용 금지!
```

**핵심 규칙:**
1. `PASSIVE_DUPLICATE_ALLOWED`에 포함된 아이템은 `skip_append = True` **절대 사용 금지**
2. 첫 획득 시에만 `obtained` 플래그 설정 및 효과 활성화
3. 롤 옵션 적용(`ensure_passive_rolls`, `apply_roll_bonuses_from_item`)은 **매번 실행**
4. 인벤토리 추가는 함수 끝에서 자동으로 처리됨 (skip_append가 False일 때)

### ⚠️ CRITICAL: 전설 아이템 추가 시 필수 체크리스트
**전설 아이템은 패시브 체크리스트 + 아래 추가 항목 모두 확인!**

| # | 파일 | 위치 | 작업 내용 |
|---|------|------|----------|
| 1 | `legendary_items.py` | 클래스 정의 | `class [ItemName](LegendaryItem):` 생성 |
| 2 | `legendary_items.py` | `LEGENDARY_ROLL_OPTIONS` | 롤 옵션 정의 추가 |
| 3 | `legendary_items.py` | `LegendaryItemManager._init_legendary_items()` | 아이템 인스턴스 생성 |
| 4 | `pingfighter.py` | `get_item_icon()` 전설 아이템 목록 | 아이템 이름 추가 **[필수! 없으면 아이콘 ?로 표시]** |
| 5 | `pingfighter.py` | 전설 아이템 획득 플래그 동기화 | `sync_bool()` 호출 추가 |
| 6 | `items.py` | `spawn_random_item()` 내 `legendary_names` | 아이템 이름 추가 (스폰 배율용) |
| 7 | `downtown/constants.py` | `LEGENDARY_ITEM_NAMES` | 아이템 이름 추가 |
| 8 | `downtown/building_interior.py` | 상점 전설 아이템 목록 | 상점 판매용 아이템 추가 |

```python
# pingfighter.py - get_item_icon() 전설 아이템 목록 (약 95453줄)
if item_name in ["hermes_shoes", "ragnarok_hammer", "poseidon_trident",
                 "angel_blessing", "sacred_laurel", "transcendent_crown", "[NEW_LEGENDARY]"]:

# items.py - spawn_random_item() 내 legendary_names (약 2043줄)
legendary_names = {"ragnarok_hammer", "hermes_shoes", ..., "[NEW_LEGENDARY]"}
```

### ⚠️ CRITICAL: 전설 아이템은 중복 획득이 가능해야 함 (skip_append 금지!)
**모든 전설 아이템의 `store_passive_item()` 구현에서 `skip_append = True`를 절대 사용하지 않는다.**
전설 아이템은 롤 옵션 파밍을 위해 중복 획득이 허용되며, 필드/뽑기/상점/보물찾기 등 모든 경로에서 동일하게 적용된다.

```python
# ❌ 잘못된 예 - 두 번째 획득 시 인벤토리에 추가 안됨
elif item_data["name"] == "legendary_item":
    if not items.legendary_item_obtained:
        items.legendary_item_obtained = True
        # 첫 획득 처리...
    else:
        print("이미 보유 중입니다.")
        skip_append = True  # ❌ 절대 금지!

# ✅ 올바른 예 - 중복 획득 시에도 인벤토리에 정상 추가
elif item_data["name"] == "legendary_item":
    if not items.legendary_item_obtained:
        items.legendary_item_obtained = True
        # 첫 획득: 해금, 애니메이션 트리거 등
        legendary_manager = get_legendary_manager()
        if "legendary_item" not in legendary_manager.unlocked_items:
            legendary_manager.unlocked_items.append("legendary_item")
            legendary_manager.items["legendary_item"].unlocked = True
        trigger_legendary_acquisition(...)
    # 모든 획득(첫/중복 모두): 타입 설정, 롤 옵션, 인벤토리 추가
    item_data["type"] = "legendary"
    ensure_passive_rolls(item_data)
    apply_roll_bonuses_from_item(item_data)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
    # skip_append 없음 → 함수 끝에서 자동으로 인벤토리에 추가됨
```

**핵심 규칙:**
1. 첫 획득 시에만 `obtained` 플래그 설정 및 전설 매니저 해금
2. `item_data["type"]`, `ensure_passive_rolls`, `apply_roll_bonuses_from_item`은 **매번 실행**
3. `skip_append = True` **절대 사용 금지** (인벤토리 추가는 함수 끝에서 자동 처리)

## Common Issues & Solutions

### Icons Show as Empty Circles
**Cause**: Missing global declaration or ITEM_TYPES assignment
**Solution**: 
1. Declare icon as global variable
2. Use `global` keyword in initialization function
3. Assign to `items.ITEM_TYPES[key]["icon"]`

### ⚠️ CRITICAL: 퍽(Perk) 아이콘이 깨져 보임 (글자 하나만 표시됨)
**Cause**: `draw_skill_icon_mini()` 함수에 해당 퍽의 `elif skill_id == "..."` 분기가 없음
**Why**: 이 함수는 2000줄 이상의 하드코딩된 elif 체인으로 각 퍽별 아이콘을 그림. 새 퍽이 추가되면 자동으로 아이콘이 생성되지 않고, `else` 절로 빠져 스킬 이름의 첫 글자만 표시됨.
**Solution**: 새 퍽 추가 시 반드시 `draw_skill_icon_mini()` 함수 내 `else:` 절 **바로 위에** 해당 퍽의 아이콘 렌더링 코드를 추가해야 함.
**Location**: `pingfighter.py` 내 `draw_skill_icon_mini()` 함수 (약 16320~20640줄 부근)

**⚠️ 모든 종류의 퍽이 해당됨! (일반 퍽 + 스킬 해금 퍽 모두)**
- 일반 퍽: `VIPER_EXCLUSIVE_SKILLS` 딕셔너리에 정의된 퍽 (예: `jetpack_enhance`, `kick_enhance`)
- **스킬 해금 퍽**: `unlock_*` 접두사를 가진 퍽 (예: `unlock_magnum_grip`, `unlock_plasma`, `unlock_recovery_skill`, `unlock_cleanse`, `unlock_ghost_shot`, `unlock_nerve_strike`, `unlock_dive_strike`)
- 스킬 해금 퍽은 별도 딕셔너리에 정의되므로 누락하기 쉬움 → **반드시 확인!**

```python
# 새 퍽 아이콘 추가 위치: else 절 바로 위
elif skill_id == "new_perk_id":         # 일반 퍽
    color = icon_color
    lt = lighter
    dk = darker
    # pygame.draw 로 아이콘 그리기...

elif skill_id == "unlock_new_skill":    # 스킬 해금 퍽 (unlock_ 접두사)
    color = icon_color
    lt = lighter
    dk = darker
    # pygame.draw 로 아이콘 그리기...
    # + 마크 (해금 표시) 추가 권장

else:
    # 기본 fallback (여기로 빠지면 아이콘 깨짐!)
    symbol = skill.get("name", "?")[0] ...
```

### ⚠️ 새 퍽 추가 시 필수 체크리스트
| # | 작업 | 설명 |
|---|------|------|
| 1 | `VIPER_EXCLUSIVE_SKILLS` 딕셔너리 | 퍽 정의 추가 (name, max_level, descriptions, detail, icon_color) |
| 2 | `apply_runtime_skill_effect()` 함수 | 레벨업 처리 코드 추가 |
| 3 | **`draw_skill_icon_mini()` 함수** | **elif 분기 추가 [필수! 없으면 아이콘 깨짐]** |
| 4 | 실제 효과 적용 코드 | 게임 로직에 `runtime_skill_levels.get("perk_id", 0)` 반영 |
| 5 | `global` 선언 | 퍽 관련 전역 변수를 사용하는 모든 함수에 `global` 선언 추가 |

### ⚠️ CRITICAL: 퍽 유형 구분 — 일반 퍽 vs 스킬형 퍽 (5구슬 슬롯)
**퍽에는 두 가지 유형이 있으며, 등록 위치와 방식이 완전히 다릅니다.**

#### 1. 일반 퍽 (패시브 강화) — jetpack_enhance, kick_enhance 등
- 정의: `VIPER_EXCLUSIVE_SKILLS`에만 등록
- HUD: `draw_viper_perk_icons()` (구슬 **옆** 작은 아이콘)
- 해금: `runtime_skill_levels` 레벨업으로만 관리
- 쿨타임: 없음
- 예: 제트팩 강화, 킥 강화

#### 2. 스킬형 퍽 (5구슬 슬롯에 장착) — dark_blade 등
**쿨타임이 있고, 발동 조건이 있는 스킬은 5구슬 슬롯 시스템에 등록해야 합니다!**
- 정의: `VIPER_EXCLUSIVE_SKILLS` + `VIPER_SKILL_ICONS_DATA` **양쪽 모두**
- HUD: `draw_viper_skill_icons()` (5구슬 **슬롯**에 표시)
- 해금: `_viper_skill_unlocked` 딕셔너리 + `equip_viper_skill()` 장착
- 쿨타임: `VIPER_SKILL_ICONS_DATA`의 `cooldown` 필드
- 예: 다크 블레이드, 베놈 엣지, EMP 스트라이크

#### 스킬형 퍽 추가 시 필수 체크리스트 (5구슬 슬롯)
| # | 작업 | 설명 |
|---|------|------|
| 1 | `VIPER_EXCLUSIVE_SKILLS` | 퍽 정의 추가 (선택 풀에 등장시키기 위해) |
| 2 | `VIPER_SKILL_ICONS_DATA` | HUD 아이콘 + 툴팁 + 쿨타임 데이터 등록 |
| 3 | `_viper_skill_unlocked` 딕셔너리 (초기값 + reset 함수) | `"skill_name": False` 추가 |
| 4 | `_viper_skill_cooldowns` 딕셔너리 (초기값 + reset 함수) | `"skill_name": 0` 추가 |
| 5 | `_viper_skill_activation_times` + `_viper_skill_was_active` | 각각 항목 추가 |
| 6 | `apply_runtime_skill_effect()` | `unlock_viper_skill()` + `equip_viper_skill()` 호출 |
| 7 | **`draw_skill_icon_mini()` 함수** | **elif 분기 추가 [필수! 없으면 아이콘 깨짐]** |
| 8 | `global` 선언 | 관련 전역 변수를 사용하는 모든 함수에 `global` 선언 추가 |

```python
# apply_runtime_skill_effect() 내부 - 스킬형 퍽 해금+장착 패턴
if choice_id == "new_skill_perk":
    unlock_viper_skill("new_skill_perk")
    equip_result = equip_viper_skill("new_skill_perk")
    if not equip_result:
        removed = _show_viper_skill_swap_dialog("new_skill_perk")
        swap_viper_skill(removed, "new_skill_perk")
    runtime_skill_levels["new_skill_perk"] = 1
    return True
```

#### 일반 퍽의 HUD 아이콘 표시 (게이지 구슬 옆)
```python
# draw_viper_perk_icons() 내부에 추가 (하드코딩 방식)
_new_perk_lv = get_runtime_skill_level("new_perk_id")
if _new_perk_lv > 0:
    viper_perks.append({
        "name": "new_perk_id",
        "color": (R, G, B),
        "cost": 0,
        "symbol": "XX",
        "always_active": True,
    })
```

### ⚠️ 스킬 해금 퍽(unlock_*) 추가 시 추가 체크리스트
| # | 작업 | 설명 |
|---|------|------|
| 1 | 스킬 해금 퍽 딕셔너리 | `"unlock_[skill_name]"` 키로 퍽 정의 추가 |
| 2 | **`draw_skill_icon_mini()` 함수** | **`elif skill_id == "unlock_[skill_name]":` 분기 추가 [필수!]** |
| 3 | `apply_runtime_skill_effect()` 내 해금 처리 | `smasher_skill_unlocked` 등 해금 플래그 설정 |
| 4 | 런타임 스킬 딕셔너리 매핑 | `"unlock_[skill_name]": "[skill_name]"` 매핑 추가 |

### Korean Text Shows as Boxes
**Cause**: Wrong font or encoding
**Solution**: Use pygame.freetype with NanumSquare fonts and UTF-8 encoding

### File Not Found on Windows
**Cause**: Hardcoded paths or wrong separators
**Solution**: Always use `resource_path()` and `os.path.join()`

### Passive Items Not Saving
**Cause**: Duplicate code in store_passive_item() function
**Solution**: Let the function end handle list addition automatically

### 중복 획득 허용 아이템이 두 번째부터 인벤토리에 안 보임
**Cause**: `PASSIVE_DUPLICATE_ALLOWED`에 포함된 아이템인데 `store_passive_item()`에서 `skip_append = True` 사용
**Solution**:
1. 해당 아이템이 `PASSIVE_DUPLICATE_ALLOWED`에 포함되어 있는지 확인
2. 포함되어 있다면 `else:` 블록에서 `skip_append = True` 제거
3. 첫 획득 시에만 `obtained` 플래그와 효과 활성화, 롤 옵션/인벤토리 추가는 매번 실행되도록 수정

### Active Items in Wrong Slot
**Cause**: Passive items not filtered in store_active_item()
**Solution**: Add passive item names to filter list

## Testing Strategy

### Pre-Release Testing
1. Run `python3 test_icons.py` - verify all icons load
2. Test Korean text rendering
3. Verify all paths use resource_path()
4. Test item effects and interactions
5. Check boss AI behaviors
6. Verify academy skill system

### Platform-Specific Testing
**Windows:**
- Test on Windows 10 and 11
- Check for DLL dependencies
- Verify antivirus compatibility

**macOS:**
- Test on Intel and Apple Silicon
- Check Gatekeeper compatibility
- Verify retina display support

## Current Development Status

### Active Branch: feature/refactor-ui
The project is currently undergoing UI refactoring with extensive changes to:
- UI management systems
- Font configuration
- Item systems
- Academy features
- Rendering optimizations

### Recent Updates (2025-08-31)
- Fixed item icon display bugs
- Resolved cross-platform font path issues
- Enhanced Windows compatibility
- Improved academy skill system integration
- Added trade point system
- **CRITICAL: Fixed legendary item (Ragnarok Hammer) animation system**
  - Field-spawned items now properly initialize animation
  - Item management window animations work correctly
  - Duplicate prevention functioning across all acquisition paths

## Performance Considerations

- Icons are cached on initialization for performance
- Fonts are loaded once and reused
- Use SRCALPHA for transparent surfaces
- Collision detection uses optimized rect-based checks
- Consider modular architecture refactoring for maintainability

## ⚠️ CRITICAL: 그래픽/디자인 작업 가이드라인 (Graphics & Effects Performance)

### 현재 렌더링 파이프라인
- **창모드**: `pygame.SCALED` + GPU 텍스처 2배 업스케일 (1488×918 → 2976×1836)
  - CPU 스케일링(`pygame.transform.scale()`) 완전 제거됨
  - GPU가 최종 화면 업스케일링 처리 → 내장 그래픽으로도 충분
- **전체모드**: 여전히 CPU 소프트웨어 스케일링 사용
  - DWM 우회로 충분히 빠름, 필요시 나중에 SCALED 적용 가능

### ✅ 자유롭게 해도 되는 것 (성능 영향 없음)
| 작업 | 이유 |
|------|------|
| 파티클/이펙트 수 늘리기 | gfxdraw 직접 렌더링이라 추가 비용 매우 작음 |
| 색상/알파 다양하게 사용 | gfxdraw는 색상 변경에 추가 비용 없음 |
| 배경 디테일 추가 | 캐싱된 배경 위에 그리는 것이므로 자유로움 |
| 새 이펙트 추가 | gfxdraw 또는 Surface 풀 패턴을 따르면 문제 없음 |
| 스킬 이펙트 고퀄리티 업그레이드 | 병목이 스케일링 파이프라인이었으므로 컨텐츠 퀄리티는 자유 |

### ❌ 여전히 주의해야 할 것 (CPU + pygame이 처리하는 영역)
| 패턴 | 왜 문제? | 해결책 |
|------|----------|--------|
| `pygame.Surface((...), SRCALPHA)` 루프 안에서 생성 | 매 프레임 메모리 할당 → 가장 큰 성능 킬러 | Surface 풀 사용 또는 gfxdraw 직접 렌더링 |
| `pygame.transform.rotate/scale` 매 프레임 호출 | CPU 연산 무거움 | 결과를 캐시하여 재사용 |
| `pygame.draw` 호출 수천 번 | draw 자체는 가벼워도 양이 많으면 느려짐 | 적절한 수로 제한 또는 배치 처리 |
| 전체화면 크기 `Surface.fill()` 남발 | 760×750 × 4바이트 = 2.3MB 매번 클리어 | 필요한 영역만 부분 클리어 |
| 투명 블렌딩(SRCALPHA) 남발 | 알파 블렌딩은 CPU 부담 큼 | 불필요한 투명 Surface 최소화 |

### 이펙트 작업 시 올바른 패턴
```python
# ❌ 잘못된 예 - 매 프레임 Surface 생성 + 회전
def update_particle(self):
    surf = pygame.Surface((20, 20), pygame.SRCALPHA)  # ❌ 매 프레임 새 Surface
    surf = pygame.transform.rotate(surf, self.angle)   # ❌ 매 프레임 회전
    screen.blit(surf, self.pos)

# ✅ 올바른 예 - gfxdraw 직접 렌더링
def update_particle(self):
    pygame.gfxdraw.filled_circle(screen, int(self.x), int(self.y), 
                                  self.radius, self.color)  # ✅ 직접 렌더링

# ✅ 올바른 예 - Surface 풀 + 캐싱된 회전
class ParticlePool:
    def __init__(self):
        self.cached_surfaces = {}  # 각도별 캐시
    
    def get_rotated(self, base_surf, angle):
        key = int(angle) % 360
        if key not in self.cached_surfaces:
            self.cached_surfaces[key] = pygame.transform.rotate(base_surf, key)
        return self.cached_surfaces[key]
```

### 한줄 요약
> **새 이펙트를 만들 때 `pygame.Surface()` 대신 gfxdraw로 직접 그리거나 Surface 풀을 쓰면 퀄리티를 올려도 프레임드랍 없음. 파티클마다 new Surface + transform.rotate만 안 하면 됨.**

## Legendary Item System (전설 아이템)

### Legendary Item Passive Classification (전설 아이템 패시브 분류)
**CRITICAL**: All legendary items MUST be classified as passive items to prevent them from being added to active item slots.

1. **In store_active_item()** - Add all legendary items to passive filter:
   ```python
   # 패시브 아이템들은 엑티브 슬롯에 추가하지 않음
   if item_data["name"] in [..., "ragnarok_hammer", "hermes_shoes", "poseidon_trident"]:
       return
   ```

2. **In store_passive_item()** - Ensure proper handling:
   ```python
   elif item_data["name"] == "poseidon_trident":
       items.poseidon_trident_obtained = True
       item_data["type"] = "legendary"  # Set type for animation
       passive_item_list.append(item_data)  # Add to passive list
       # Activate legendary manager
       legendary_manager = get_legendary_manager()
       if legendary_manager:
           trident = legendary_manager.get_item("poseidon_trident")
           if trident:
               trident.activate()
   ```

### ⚠️ CRITICAL: 전설 아이템 연마 퍽 + 강화 버프 적용 필수
**모든 전설 아이템의 롤 옵션 프로퍼티는 반드시 연마 퍽과 강화 버프를 모두 적용해야 합니다!**

#### 1. 클래스에 enhancement_bonus_pct 속성 추가
```python
class NewLegendaryItem(LegendaryItem):
    def __init__(self):
        super().__init__(...)
        # ... 기타 속성들 ...
        self.enhancement_bonus_pct = 0  # 강화 버프 보너스 (장착 시 동기화) ← 필수!
```

#### 2. 롤 옵션 프로퍼티에서 enhancement_bonus_pct 전달
```python
@property
def some_stat(self) -> float:
    """스탯 설명 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
    return get_legendary_roll_value(
        "new_legendary_item",
        "stat_key",
        apply_polish=True,  # 연마 퍽 적용
        enhancement_bonus_pct=self.enhancement_bonus_pct  # 강화 버프 적용 ← 필수!
    )
```

#### 3. sync_equipped_passive_effects()에 동기화 코드 추가
```python
# pingfighter.py - sync_equipped_passive_effects() 내부
# 장착 시 동기화
if legend_name == "new_legendary_item":
    item = next((i for i in equipped_items if i.get("name") == "new_legendary_item"), None)
    if item:
        legendary = legendary_manager.get_item("new_legendary_item")
        if legendary:
            legendary.enhancement_bonus_pct = item.get("enhancement_bonus_pct", 0)

# 장착 해제 시 초기화
elif legend_name == "new_legendary_item":
    legendary = legendary_manager.get_item("new_legendary_item")
    if legendary:
        legendary.enhancement_bonus_pct = 0
```

#### 현재 적용된 전설 아이템 목록
| 아이템 | 롤 옵션 | 연마 퍽 | 강화 버프 |
|--------|---------|---------|-----------|
| 오딘의 눈 | revival_chance | ✅ | ✅ |
| 포세이돈의 삼지창 | wave_power | ✅ | ✅ |
| 헤르메스의 신발 | speed_bonus | ✅ | ✅ |
| 라그나로크 해머 | trigger_chance | ✅ | ✅ |
| 신성 월계수 | leaf_count | ✅ | ✅ |
| 천사의 가호 | buff_level | ✅ | ✅ |
| 초월자의 관 | skill_bonus | ✅ | ✅ |

### Key Implementation Details
Legendary items like Ragnarok Hammer require special handling for animations:

1. **Animation Initialization**: When spawning in field (items.py:spawn_random_item):
   ```python
   # DO NOT call activate_item() - this applies effects immediately
   # Instead, only initialize the instance for animation:
   if selected_item["name"] == "ragnarok_hammer":
       legendary_manager = get_legendary_manager()
       if legendary_manager:
           hammer = legendary_manager.get_item("ragnarok_hammer")
           if not hammer:
               legendary_manager._init_legendary_items()  # Init only, no activation
   ```

2. **Drawing Animated Items** (items.py:draw_items):
   ```python
   if item_name == "ragnarok_hammer":
       legendary_manager = get_legendary_manager()
       if legendary_manager:
           hammer = legendary_manager.get_item("ragnarok_hammer")
           if hammer:
               hammer.update(0.016)  # Update animation (60fps)
               hammer.draw_icon(screen, x, y, size)  # Draw with animation
   ```

3. **Duplicate Prevention**: 
   - Check `ragnarok_hammer_obtained` flag in:
     - items.py:spawn_random_item (field spawning)
     - pingfighter.py:show_item_management_menu (item selection)
     - gacha.py:init_gacha (gacha system)

4. **Type Setting for Animation** (pingfighter.py:store_passive_item):
   ```python
   if item_data["name"] == "ragnarok_hammer":
       item_data["type"] = "legendary"  # CRITICAL for animation in UI
   ```

### Common Issues with Legendary Items
- **Animation not playing**: Check if instance is initialized before drawing
- **Effects applying before pickup**: Don't call activate_item() on spawn
- **Duplicate items appearing**: Ensure global flag is properly set and checked
- **UI not animating**: Set item["type"] = "legendary" when storing
- **Added to active slot by mistake**: Add to passive filter list in store_active_item()
- **Effects not working in game**: Must integrate legendary_manager.update() and effect calls in game loop

### Legendary Item Effect Integration (전설 아이템 효과 통합)
**CRITICAL**: Legendary item effects need to be integrated into the game loop to work properly.

**Note**: As of current implementation, legendary item effects (especially Poseidon's Trident) are NOT fully integrated into the main game loop. The water wave effects and dash wave mechanics require manual integration in pingfighter.py's physics update sections.

**Required Integration Points**:
1. Ball physics update - Apply trajectory influence
2. Dash mechanics - Trigger dash wave on player dash
3. Rendering loop - Draw water wave effects
4. Update loop - Call legendary_manager.update(dt)

### Effect Reset Rules (효과 초기화 규칙)
**IMPORTANT**: Legendary item effects are temporary and must be reset when:

1. **Game Over** - Player loses the game
2. **Return to Main Menu** - Player exits to main menu via ESC
3. **Force Quit** - Game is forcefully terminated

**Reset Implementation**:
```python
# Reset legendary item effects (3 locations in pingfighter.py)
# 1. Game over - around line 20185
# 2. ESC menu return to main - around line 20965  
# 3. Force quit flag - around line 20506

# Example reset code:
if hasattr(legendary_manager, 'reset_all_items'):
    legendary_manager.reset_all_items()  # Deactivate all legendary effects
    
# Also reset obtained flags if items should be re-obtainable:
ragnarok_hammer_obtained = False  # Optional: allow re-obtaining
hermes_shoes_obtained = False     # Optional: allow re-obtaining
```

**Note**: The `obtained` flag can be kept as True if you want to prevent re-obtaining the same legendary item in the same session, or reset to False if items should be obtainable again.

## Git Workflow & Automatic Commits

### ⚠️ CRITICAL: 매 프롬프트 완수 시 자동 커밋 필수!
**IMPORTANT**: 사용자의 프롬프트(요청)를 완수할 때마다 반드시 Git에 커밋한다.

#### 커밋 규칙
1. **매 프롬프트 완수 시** → 즉시 커밋 (예외 없음!)
2. 커밋 메시지는 한글로 작성 가능
3. 커밋 후 자동 push

#### Quick Git Commands
```bash
# Regular commit (for each completed task)
git add -A && git commit -m "[Type]: [작업 내용 설명]" && git push

# Commit Types:
# Feat: 새 기능 추가
# Fix: 버그 수정
# Refactor: 코드 리팩토링
# Docs: 문서 수정
# Style: 코드 스타일 변경
# Debug: 디버그 코드 추가

# Checkmate commit (for important checkpoints)
--checkmate MM.DD-N  # Automatically creates: git commit -m "🏁 Checkmate MM.DD-N: [description]"

# Examples:
--checkmate 09.02-5  # Creates "🏁 Checkmate 09.02-5: 작업 체크포인트"
```

#### When to Commit (언제 커밋하나?)
- **프롬프트 완수 시** (가장 중요!)
- After fixing any bug
- After implementing new feature
- After completing requested changes
- After significant code modifications
- At the end of each work session
- When user uses --checkmate command

### ⚠️ CRITICAL: 안전한 Git 롤백 규칙 (Safe Rollback Rules)
**절대로 `git reset --hard`를 미커밋 상태에서 실행하지 않는다!**

#### 롤백이 필요할 때 반드시 따라야 할 순서:

```bash
# 1단계: 현재 작업 상태 저장 (필수!)
git stash -u -m "롤백 전 백업 $(date +%Y%m%d_%H%M%S)"
# 또는
git add -A && git commit -m "WIP: 롤백 전 임시 저장"

# 2단계: 롤백 실행
git reset --hard [커밋해시]

# 3단계: (필요시) 저장했던 작업 복원
git stash pop
```

#### 안전한 롤백 방법들:

| 상황 | 안전한 명령어 | 설명 |
|------|--------------|------|
| 특정 파일만 되돌리기 | `git checkout [커밋] -- [파일]` | 다른 파일에 영향 없음 |
| 테스트용 롤백 | `git checkout -b test-branch [커밋]` | 새 브랜치에서 안전하게 테스트 |
| 전체 롤백 (안전) | `git stash -u` → `git reset --hard` | 작업 내용 보존 |
| 커밋 취소 (기록 유지) | `git revert [커밋]` | 히스토리 보존하면서 취소 |

#### ❌ 절대 하지 말 것:
```bash
# 미커밋 변경사항이 있는 상태에서 직접 reset --hard 금지!
git reset --hard [커밋]  # ❌ 위험! 작업 손실 가능

# 반드시 먼저 stash 또는 commit 후 실행
git stash -u && git reset --hard [커밋]  # ✅ 안전
```

#### 롤백 후 문제 발생 시 복구 방법:
```bash
# stash로 저장한 경우
git stash list          # 저장된 stash 목록 확인
git stash pop           # 가장 최근 stash 복원

# 커밋으로 저장한 경우
git reflog              # 이전 커밋 히스토리 확인
git checkout [커밋해시] # 원하는 상태로 이동

# 백업 폴더가 있는 경우
# 'd:\백업\0130\main\bosspong' 등에서 파일 복사
```

#### 모듈 버전 불일치 방지:
- `pingfighter.py`와 모듈 파일들(`start_menu.py`, `items.py` 등)은 항상 **함께 커밋**
- 롤백 시 **모든 관련 파일이 같은 버전**인지 확인
- 문제 발생 시 백업 폴더에서 동기화된 버전 복사

### Git Repository Info
- **Remote**: https://github.com/officialsahogany/pingfighter.git
- **Current Branch**: feature/refactor-ui
- **GitHub Token**: Use Classic PAT for authentication

## Notes for Future Development

When modifying this codebase:
1. **ALWAYS** test on both Windows and macOS
2. **NEVER** hardcode paths - use resource_path()
3. **MAINTAIN** backward compatibility with save files
4. **PRESERVE** the monolithic architecture until full modularization
5. **DOCUMENT** any new item effects in detail
6. **TEST** with PyInstaller builds before release
7. **ENSURE** legendary item animations work in all contexts (field, UI, gacha)
8. **COMMIT** changes to Git after each completed task