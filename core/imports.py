# -*- coding: utf-8 -*-
"""
Import 관리 모듈
모든 import를 체계적으로 관리하여 가독성과 유지보수성 향상
"""

# ============================================================
# 표준 라이브러리
# ============================================================
import os
import sys
import math
import random
import importlib

# ============================================================
# 외부 라이브러리
# ============================================================
import pygame
import pygame.freetype

# ============================================================
# 게임 핵심 모듈
# ============================================================
# 설정 및 상수
from config.constants import *
from config.game_settings import *
from config.stage_configs import *

# 코어 시스템
from core.constants import Colors, Sizes, Speeds, Timings, Balance, Physics
from core.game_state import GameState
from core.events import EventManager, EventType, emit_event
from core.bridge import get_bridge, handle_item_collection
from core.game_variables import get_game_vars
from core.profiler import init_profiler

# ============================================================
# UI 시스템
# ============================================================
from ui.hud_display import show_score, draw_dash_spirit_lasers
from ui.menu_system import MenuSystem
from ui.dialog_system import DialogSystem
from ui.simple_menu_background import SimpleMenuBackground
from ui.stage3_menhera_world import Stage3MenheraWorld
from ui.stage4_shaolin_temple import ShaolinTempleBackground
from ui.stage5_chinese_market import Stage5ChineseMarket

# UI 매니저
import ui_manager

# ============================================================
# 매니저 시스템
# ============================================================
from managers.unified_effects import UnifiedEffectsManager
from managers.unified_sound import UnifiedSoundManager
import effects_manager
from effects_manager import spawn_drive_particles, update_drive_particles, draw_drive_particles
import physics_manager
import dash_manager

# ============================================================
# 렌더링 시스템
# ============================================================
from rendering.unified_renderer import UnifiedRenderer

# 배경 시스템
from backgrounds.animated_background import AnimatedBackground
from backgrounds.animated_background_stage2 import AnimatedBackgroundStage2
from backgrounds.animated_background_stage6 import AnimatedBackgroundStage6

# ============================================================
# 게임 모듈
# ============================================================
import items
import option as option_module
import gacha
import opening
import skill
import academy
import cinematic

# 아이템 시스템
from legendary_items import get_legendary_manager, LegendaryItem
from pixel_font_manager import get_font, FontStyle, PixelColors

# ============================================================
# 아이템 효과 시스템
# ============================================================
from item_effects.dowsing_pendulum import dowsing_pendulum_effect
from item_effects.devil_dice import (
    activate_devil_dice, update_devil_dice, draw_devil_dice_effects,
    get_devil_dice_multipliers, is_devil_dice_active
)
from item_effects.technical_vest import (
    activate_technical_vest, deactivate_technical_vest,
    on_ball_paddle_collision_technical_vest, update_technical_vest,
    draw_technical_vest_effects, check_technical_vest_smoke_collision,
    get_technical_vest_smoke_areas
)
from item_effects.fuel_pouch import (
    activate_fuel_pouch, deactivate_fuel_pouch,
    get_fuel_pouch_gauge_bonus
)
from item_effects.bluetooth_ring import (
    activate_bluetooth_ring, deactivate_bluetooth_ring,
    get_bluetooth_ring_gauge_multiplier,
    calculate_bluetooth_ring_gauge_charge,
    is_bluetooth_ring_active
)

# ============================================================
# 이펙트 시스템
# ============================================================
from effects.legendary_integration import (
    initialize_legendary_effects, trigger_legendary_acquisition,
    update_legendary_effect, draw_legendary_effect,
    should_pause_for_legendary, is_legendary_effect_active,
    handle_legendary_space_press
)
from effects.item_acquisition import (
    initialize_item_effects, show_item_acquisition,
    update_item_effects, draw_item_effects
)

# ============================================================
# 이벤트 시스템
# ============================================================
from events.stage1_event_integration import Stage1EventManager
from trade_point_system import TradePointSystem
from game_logic.checkmate_system import get_checkmate_system

# ============================================================
# 유틸리티
# ============================================================
from utils.game_utils import clamp, lerp, distance, normalize_vector
from utils.render_utils import (
    create_cyberpunk_background, create_fire_background,
    create_ice_background, create_electric_background,
    create_shadow_background, draw_glow_effect
)

# ============================================================
# 옵셔널 시스템 (조건부 import)
# ============================================================

# 하프 대쉬 시스템
try:
    from game_mechanics.half_dash_integration import (
        integrate_half_dash_with_game,
        check_and_activate_half_dash,
        apply_half_dash_timer_adjustment,
        draw_half_dash_effects,
        reset_half_dash_round
    )
    HALF_DASH_ENABLED = True
except ImportError:
    HALF_DASH_ENABLED = False

# AI 시스템
try:
    from boss_ai_integration import EnhancedBossAI
    AI_AVAILABLE = True
except ImportError:
    AI_AVAILABLE = False

# 플레이어 스킬 분석
try:
    from player_skill_analyzer import get_player_analyzer
    SKILL_ANALYZER_AVAILABLE = True
except ImportError:
    SKILL_ANALYZER_AVAILABLE = False
    def get_player_analyzer():
        return None

# 부드러운 보스 움직임
try:
    from game_logic.smooth_boss_movement import get_smooth_movement, apply_smooth_boss_movement
    from game_logic.boss_movement_integration import integrate_smooth_movement, apply_smooth_movement_in_ai
    SMOOTH_MOVEMENT_AVAILABLE = True
except ImportError:
    SMOOTH_MOVEMENT_AVAILABLE = False

# Ultra Smooth 물리
try:
    from game_logic.advanced_boss_physics import get_ultra_smooth_movement, apply_ultra_smooth_movement
    ULTRA_SMOOTH_AVAILABLE = True
except ImportError:
    ULTRA_SMOOTH_AVAILABLE = False

# Stage 1 풍선 이벤트
try:
    from events.stage1_event_integration import Stage1EventManager
    BALLOON_EVENT_AVAILABLE = True
except ImportError:
    BALLOON_EVENT_AVAILABLE = False

# Stage 5 화염 이벤트
try:
    from events.stage5_event_integration import Stage5EventManager
    FIRE_EVENT_AVAILABLE = True
except ImportError:
    FIRE_EVENT_AVAILABLE = False