# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
PingFighter (핑파이터) is a Python-based arcade-style table tennis game with boss battles, power-ups, and special abilities. Built with Pygame framework and runs on both Windows and macOS.

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

## Common Issues & Solutions

### Icons Show as Empty Circles
**Cause**: Missing global declaration or ITEM_TYPES assignment
**Solution**: 
1. Declare icon as global variable
2. Use `global` keyword in initialization function
3. Assign to `items.ITEM_TYPES[key]["icon"]`

### Korean Text Shows as Boxes
**Cause**: Wrong font or encoding
**Solution**: Use pygame.freetype with NanumSquare fonts and UTF-8 encoding

### File Not Found on Windows
**Cause**: Hardcoded paths or wrong separators
**Solution**: Always use `resource_path()` and `os.path.join()`

### Passive Items Not Saving
**Cause**: Duplicate code in store_passive_item() function
**Solution**: Let the function end handle list addition automatically

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

### Automatic Git Saving After Each Task
**IMPORTANT**: Per user request, save work to Git after completing each task.

#### Quick Git Commands
```bash
# Regular commit (for each completed task)
git add -A && git commit -m "Update: [task description]" && git push

# Checkmate commit (for important checkpoints)
--checkmate MM.DD-N  # Automatically creates: git commit -m "🏁 Checkmate MM.DD-N: [description]"

# Examples:
--checkmate 09.02-5  # Creates "🏁 Checkmate 09.02-5: 작업 체크포인트"
```

#### When to Commit
- After fixing any bug
- After implementing new feature
- After completing requested changes
- After significant code modifications
- At the end of each work session
- When user uses --checkmate command

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