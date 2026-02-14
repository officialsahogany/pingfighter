# downtown/colosseum_arena.py
# 고대 투기장 토너먼트 시스템

import pygame
import random
import math
import sys
_sin = math.sin
_cos = math.cos
import os
import time
from enum import Enum
from typing import List, Dict, Optional, Tuple

# 영웅 스킬 시스템 임포트
try:
    from downtown.hero_skills import (
        get_skill_manager, HeroSkillManager, SkillTrigger,
        HERO_SKILLS, get_hero_skills
    )
    HERO_SKILLS_AVAILABLE = True
except ImportError:
    try:
        from hero_skills import (
            get_skill_manager, HeroSkillManager, SkillTrigger,
            HERO_SKILLS, get_hero_skills
        )
        HERO_SKILLS_AVAILABLE = True
    except ImportError:
        HERO_SKILLS_AVAILABLE = False
        print("Hero skills module not available")

# 스킬 아이콘 시스템 임포트
try:
    from downtown.hero_skill_icons import get_skill_icon as _get_hero_skill_icon
except ImportError:
    try:
        from hero_skill_icons import get_skill_icon as _get_hero_skill_icon
    except ImportError:
        def _get_hero_skill_icon(skill_id, size=32):
            return None

# 상수 (실제 게임과 동일)
SCREEN_WIDTH = 760
SCREEN_HEIGHT = 750
GAME_AREA_X = 80
GAME_AREA_WIDTH = 600
PADDLE_WIDTH = 80
PADDLE_HEIGHT = 12
BALL_SIZE = 10
WIN_SCORE = 5  # 5점 선취 승리

# === Surface 캐시 (최적화) ===
# 매 프레임 반복 생성되는 Surface를 크기별로 캐싱하여 재사용
_arena_surface_cache = {}
_arena_fullscreen_surface = None

def _get_arena_surface(w, h):
    """크기별 SRCALPHA Surface 캐시 재사용 (매 프레임 재생성 방지)"""
    w = max(4, ((w + 3) // 4) * 4)
    h = max(4, ((h + 3) // 4) * 4)
    key = (w, h)
    if key not in _arena_surface_cache:
        _arena_surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
    else:
        _arena_surface_cache[key].fill((0, 0, 0, 0))
    return _arena_surface_cache[key]

def _get_arena_fullscreen():
    """760x750 전체화면 SRCALPHA Surface 캐싱 재사용"""
    global _arena_fullscreen_surface
    if _arena_fullscreen_surface is None:
        _arena_fullscreen_surface = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
    else:
        _arena_fullscreen_surface.fill((0, 0, 0, 0))
    return _arena_fullscreen_surface

# 물리 상수 (실제 게임과 동일)
BALL_BASE_SPEED = 7.0       # 기본 공 속도
BALL_MAX_SPEED = 15.0       # 최대 공 속도
BALL_ACCELERATION = 1.03    # 충돌 시 가속률
PADDLE_HIT_ANGLE_FACTOR = 4.0  # 패들 타격 시 각도 변화 계수
WALL_BOUNCE_SLOWDOWN = 0.98  # 벽 반사 시 속도 감소

# 패들 위치 (실제 게임과 동일)
TOP_PADDLE_Y = 25           # 상단 패들 Y (보스 위치)
BOTTOM_PADDLE_Y = 710       # 하단 패들 Y (플레이어 위치)

# 배경/필러 임포트 (선택적)
try:
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from backgrounds.animated_background_stage30 import AnimatedBackgroundStage30
    from pillar_colosseum import ColosseumFrame
    VISUAL_ASSETS_AVAILABLE = True
except ImportError:
    VISUAL_ASSETS_AVAILABLE = False

# 영웅 패들 렌더러 임포트
try:
    from downtown.hero_paddles import get_hero_paddle_renderer
    HERO_PADDLES_AVAILABLE = True
except ImportError:
    try:
        from hero_paddles import get_hero_paddle_renderer
        HERO_PADDLES_AVAILABLE = True
    except ImportError:
        HERO_PADDLES_AVAILABLE = False

# 날씨 이벤트 임포트 (용의 날개 강풍 이펙트용)
try:
    from events import weather_event as weather_module
    WEATHER_EVENT_AVAILABLE = True
except ImportError:
    WEATHER_EVENT_AVAILABLE = False
    weather_module = None

# 호버 사운드 로드
_hover_sound = None
def _load_hover_sound():
    global _hover_sound
    if _hover_sound is not None:
        return
    try:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(base, "sounds", "button_hover.wav")
        if os.path.exists(path):
            _hover_sound = pygame.mixer.Sound(path)
            _hover_sound.set_volume(0.4)
    except Exception:
        _hover_sound = None

_prison_open_sound = None
def _load_prison_open_sound():
    global _prison_open_sound
    if _prison_open_sound is not None:
        return
    try:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(base, "sounds", "prisonopen.wav")
        if os.path.exists(path):
            _prison_open_sound = pygame.mixer.Sound(path)
            _prison_open_sound.set_volume(0.5)
    except Exception:
        _prison_open_sound = None

_select_swing_sound = None
def _load_select_swing_sound():
    global _select_swing_sound
    if _select_swing_sound is not None:
        return
    try:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(base, "sounds", "selectswing.wav")
        if os.path.exists(path):
            _select_swing_sound = pygame.mixer.Sound(path)
            _select_swing_sound.set_volume(0.5)
    except Exception:
        _select_swing_sound = None

_button_click_sound = None
def _load_button_click_sound():
    global _button_click_sound
    if _button_click_sound is not None:
        return
    try:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(base, "sounds", "button_click.wav")
        if os.path.exists(path):
            _button_click_sound = pygame.mixer.Sound(path)
            _button_click_sound.set_volume(0.5)
    except Exception:
        _button_click_sound = None

_gacha_result_sound = None
def _load_gacha_result_sound():
    global _gacha_result_sound
    if _gacha_result_sound is not None:
        return
    try:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(base, "sounds", "gatcharesult.wav")
        if os.path.exists(path):
            _gacha_result_sound = pygame.mixer.Sound(path)
            _gacha_result_sound.set_volume(0.6)
    except Exception:
        _gacha_result_sound = None

# ============================================================================
# 이집트 파피루스 테마 색상 팔레트
# ============================================================================
EGYPT_THEME = {
    # 배경
    "bg_dark":           (42, 30, 20),
    "bg_medium":         (62, 48, 32),
    "bg_light":          (85, 68, 45),
    "bg_panel":          (72, 56, 38),

    # 파피루스 질감
    "papyrus_base":      (180, 155, 110),
    "papyrus_light":     (210, 185, 140),
    "papyrus_dark":      (140, 115, 75),
    "papyrus_grain":     (120, 98, 62),

    # 금/청동 금속
    "gold_bright":       (255, 215, 50),
    "gold_medium":       (218, 175, 32),
    "gold_dark":         (170, 130, 20),
    "gold_pale":         (255, 230, 140),
    "bronze":            (180, 120, 60),

    # 이집트 보석 색상
    "lapis_lazuli":      (38, 97, 156),
    "lapis_light":       (80, 140, 200),
    "turquoise":         (64, 176, 166),
    "turquoise_light":   (100, 210, 200),
    "carnelian":         (180, 50, 30),
    "carnelian_light":   (220, 90, 60),
    "malachite":         (50, 150, 80),
    "malachite_light":   (80, 200, 110),
    "sand":              (220, 195, 150),

    # UI 상태
    "hover_glow":        (255, 220, 100),
    "selected_glow":     (100, 200, 160),
    "selected_border":   (80, 180, 150),

    # 텍스트
    "text_title":        (255, 215, 50),
    "text_subtitle":     (210, 185, 140),
    "text_body":         (200, 180, 140),
    "text_hint":         (150, 130, 95),
    "text_disabled":     (100, 85, 60),
    "text_white":        (240, 230, 210),

    # 대진표 선
    "bracket_line":      (140, 115, 75),
    "bracket_highlight": (255, 215, 50),

    # 오버레이
    "overlay_dark":      (20, 15, 8),
    "overlay_warm":      (30, 20, 10),

    # 버튼
    "btn_continue":      (50, 130, 70),
    "btn_continue_hover":(70, 160, 90),
    "btn_exit":          (38, 75, 130),
    "btn_exit_hover":    (55, 100, 165),
    "btn_danger":        (130, 40, 25),
    "btn_danger_hover":  (165, 55, 35),

    # 카드
    "card_bg":           (55, 42, 28),
    "card_bg_hover":     (70, 55, 38),
    "card_bg_completed": (45, 55, 35),
    "card_border":       (140, 115, 75),
    "card_border_hover": (218, 175, 32),
    "card_diagonal":     (120, 98, 62),

    # 스킬/VS/감옥
    "skill_bg":          (50, 40, 28),
    "skill_border":      (100, 85, 60),
    "vs_circle_bg":      (72, 56, 38),
    "vs_circle_border":  (140, 115, 75),
    "prison_bar":        (100, 80, 50),
    "prison_bar_hover":  (160, 130, 70),

    # 감옥 철창 연출
    "iron_bar":          (90, 90, 100),       # 쇠철창 기본색 (차가운 회색)
    "iron_bar_light":    (130, 130, 145),     # 철창 하이라이트
    "iron_bar_dark":     (50, 50, 58),        # 철창 그림자
    "iron_bar_hover":    (120, 120, 135),     # 호버 시 철창
    "iron_rivet":        (160, 155, 140),     # 리벳(볼트) 색상
    "iron_rivet_dark":   (70, 68, 60),        # 리벳 그림자
    "cell_shadow":       (15, 12, 8),         # 감옥 내부 그림자
}

ET = EGYPT_THEME  # 짧은 별칭

# ============================================================================
# 투기장 난이도 설정
# ============================================================================
ARENA_DIFFICULTIES = [
    {
        "key": "normal",
        "name": "일반",
        "description": "표준 투기장 규칙\n5점 선취",
        "entry_fee": 500,
        "prize_multiplier": 1.0,
        "ai_bonus_perks": 0,
        "win_score": 5,
        "color": (100, 200, 120),
        "border_color": (60, 160, 80),
    },
    {
        "key": "hard",
        "name": "격전",
        "description": "AI 퍽 추가 강화\n보상 1.8배",
        "entry_fee": 1000,
        "prize_multiplier": 1.8,
        "ai_bonus_perks": 1,
        "win_score": 5,
        "color": (255, 200, 60),
        "border_color": (200, 150, 30),
    },
    {
        "key": "hell",
        "name": "지옥",
        "description": "AI 대폭 강화\n보상 3배 | 7점 선취",
        "entry_fee": 2000,
        "prize_multiplier": 3.0,
        "ai_bonus_perks": 2,
        "win_score": 7,
        "color": (220, 60, 60),
        "border_color": (170, 30, 30),
    },
]

# ============================================================================
# 영웅 데이터
# ============================================================================
class HeroStyle(Enum):
    AGGRESSIVE = "aggressive"  # 공격적 - 빠른 반응, 강한 스매시
    DEFENSIVE = "defensive"    # 수비적 - 안정적 수비, 느린 공격
    BALANCED = "balanced"      # 균형형 - 평균적인 능력치
    TRICKY = "tricky"          # 트릭형 - 예측 불가, 변칙 플레이

# ============================================================================
# 영웅 상성 시스템 (순환 상성: AGGRESSIVE > TRICKY > BALANCED > DEFENSIVE > AGGRESSIVE)
# ============================================================================
STYLE_MATCHUP_BONUS = 0.08  # 상성 보정값 (±8%)
STYLE_ADVANTAGE = {
    HeroStyle.AGGRESSIVE: HeroStyle.TRICKY,     # 공격 → 트릭: 공격 유리
    HeroStyle.TRICKY: HeroStyle.BALANCED,        # 트릭 → 균형: 트릭 유리
    HeroStyle.BALANCED: HeroStyle.DEFENSIVE,     # 균형 → 수비: 균형 유리
    HeroStyle.DEFENSIVE: HeroStyle.AGGRESSIVE,   # 수비 → 공격: 수비 유리
}
STYLE_KOREAN_NAMES = {
    HeroStyle.AGGRESSIVE: "공격형",
    HeroStyle.DEFENSIVE: "수비형",
    HeroStyle.BALANCED: "균형형",
    HeroStyle.TRICKY: "트릭형",
}

def get_style_matchup(style_a: 'HeroStyle', style_b: 'HeroStyle') -> float:
    """상성 보정값 반환. +bonus(유리), -bonus(불리), 0(중립/동일)"""
    if style_a == style_b:
        return 0.0
    if STYLE_ADVANTAGE.get(style_a) == style_b:
        return STYLE_MATCHUP_BONUS
    elif STYLE_ADVANTAGE.get(style_b) == style_a:
        return -STYLE_MATCHUP_BONUS
    return 0.0

# 상단 패들 영웅 (hero1 - 화면 위쪽)
TOP_HEROES = [
    {
        "id": "mugen",
        "name": "무겐",
        "title": "귀검사",
        "style": HeroStyle.AGGRESSIVE,
        "color": (120, 60, 180),  # 보라색
        "speed": 1.3,
        "reaction": 0.85,
        "power": 1.25,
        "accuracy": 0.85,
        "position": "top",
        "description": "어둠의 검기를 다루는 동양의 귀검객"
    },
    {
        "id": "kraken",
        "name": "크라켄",
        "title": "심해의 포식자",
        "style": HeroStyle.TRICKY,
        "color": (40, 120, 140),  # 어두운 청록색
        "speed": 0.95,
        "reaction": 1.1,
        "power": 1.15,
        "accuracy": 0.85,
        "position": "top",
        "description": "심해에서 온 촉수 괴물 하이브리드"
    },
    {
        "id": "chronos",
        "name": "키르케",
        "title": "흑마녀",
        "style": HeroStyle.DEFENSIVE,
        "color": (120, 80, 160),  # 어두운 보라색
        "speed": 0.85,
        "reaction": 1.35,
        "power": 0.75,
        "accuracy": 0.98,
        "position": "top",
        "description": "금지된 흑마법으로 상대를 압도하는 암흑의 마녀"
    },
    {
        "id": "onimaru",
        "name": "오니마루",
        "title": "지옥의 요괴무사",
        "style": HeroStyle.BALANCED,
        "color": (200, 50, 70),  # 진한 빨강
        "speed": 1.2,
        "reaction": 0.9,
        "power": 1.35,
        "accuracy": 0.82,
        "position": "top",
        "description": "지옥에서 온 뿔 달린 도깨비 전사"
    },
]

# 하단 패들 영웅 (hero2 - 화면 아래쪽)
BOTTOM_HEROES = [
    {
        "id": "maria",
        "name": "연화",
        "title": "인형사",
        "style": HeroStyle.TRICKY,
        "color": (180, 100, 150),  # 분홍-보라
        "speed": 1.0,
        "reaction": 1.0,
        "power": 1.1,
        "accuracy": 0.85,
        "position": "bottom",
        "description": "마리오네트를 조종하는 기묘한 소녀"
    },
    {
        "id": "ignis",
        "name": "이그니스",
        "title": "드래곤 나이트",
        "style": HeroStyle.BALANCED,
        "color": (220, 100, 40),  # 주황-빨강
        "speed": 1.0,
        "reaction": 0.95,
        "power": 1.1,
        "accuracy": 0.85,
        "position": "bottom",
        "description": "드래곤의 힘을 갑옷에 담은 용기사"
    },
    {
        "id": "gear",
        "name": "마리",
        "title": "스팀펑크 메카닉",
        "style": HeroStyle.DEFENSIVE,
        "color": (140, 100, 60),  # 구리색
        "speed": 0.9,
        "reaction": 1.25,
        "power": 0.95,
        "accuracy": 0.95,
        "position": "bottom",
        "description": "증기 기관과 톱니바퀴로 무장한 천재 여성 발명가"
    },
    {
        "id": "kurokage",
        "name": "쿠로카게",
        "title": "그림자 닌자",
        "style": HeroStyle.AGGRESSIVE,
        "color": (50, 50, 70),  # 어두운 남색
        "speed": 1.4,
        "reaction": 0.85,
        "power": 1.0,
        "accuracy": 0.8,
        "position": "bottom",
        "description": "어둠 속에서 나타나는 닌자 암살자"
    },
    {
        "id": "banshee",
        "name": "벤시",
        "title": "유령 여왕",
        "style": HeroStyle.TRICKY,
        "color": (80, 130, 160),  # 유령빛 청회색
        "speed": 1.1,
        "reaction": 1.15,
        "power": 0.9,
        "accuracy": 0.92,
        "position": "bottom",
        "description": "저주받은 비명으로 적을 공포에 빠트리는 유령의 여왕"
    },
    {
        "id": "necro",
        "name": "네크로",
        "title": "해골의 여왕",
        "style": HeroStyle.TRICKY,
        "color": (160, 80, 200),  # 사령의 보라
        "speed": 1.1,
        "reaction": 0.9,
        "power": 0.9,
        "accuracy": 0.85,
        "position": "bottom",
        "description": "해골의 왕관을 쓴 망자들의 여왕"
    },
    {
        "id": "joker",
        "name": "조커",
        "title": "광대",
        "style": HeroStyle.TRICKY,
        "color": (220, 60, 80),  # 빨강+금 광대 테마
        "speed": 1.15,
        "reaction": 0.88,
        "power": 0.95,
        "accuracy": 0.82,
        "position": "bottom",
        "description": "예측 불가능한 서프라이즈로 상대를 혼란에 빠뜨리는 광대"
    },
    {
        "id": "mirage",
        "name": "세트",
        "title": "사막의 환술사",
        "style": HeroStyle.TRICKY,
        "color": (210, 180, 100),  # 사막 모래빛 금색
        "speed": 1.05,
        "reaction": 0.92,
        "power": 0.88,
        "accuracy": 0.9,
        "position": "bottom",
        "description": "사막의 모래바람을 조종하여 적을 가두고 혼란시키는 환술사"
    },
    {
        "id": "android",
        "name": "안드로이드",
        "title": "전투 병기",
        "style": HeroStyle.AGGRESSIVE,
        "color": (130, 140, 160),  # 건메탈 실버
        "speed": 1.15,
        "reaction": 0.88,
        "power": 1.3,
        "accuracy": 0.85,
        "position": "bottom",
        "description": "폭탄과 기관포로 무장한 냉혹한 전투 로봇"
    },
    {
        "id": "ra",
        "name": "호루스",
        "title": "천둥의 매",
        "style": HeroStyle.BALANCED,
        "color": (230, 160, 40),  # 태양 오렌지 골드
        "speed": 1.1,
        "reaction": 0.95,
        "power": 1.0,
        "accuracy": 0.95,
        "position": "bottom",
        "description": "독수리 가면을 쓴 천둥의 화신, 번개의 힘으로 적을 심판한다"
    },
    {
        "id": "monkeyking",
        "name": "원숭이왕",
        "title": "밀림의 패왕",
        "style": HeroStyle.AGGRESSIVE,
        "color": (205, 165, 75),  # 금빛 갈색 (원숭이 털색)
        "speed": 1.3,
        "reaction": 0.88,
        "power": 1.25,
        "accuracy": 0.82,
        "position": "bottom",
        "description": "밀림을 지배하는 야생의 왕, 강력한 팔 한 방으로 모든 것을 박살낸다"
    },
]

# 전체 영웅 목록
ARENA_HEROES = TOP_HEROES + BOTTOM_HEROES

# ============================================================================
# 토너먼트 상태
# ============================================================================
class TournamentState(Enum):
    DIFFICULTY_SELECT = "difficulty_select"  # 난이도 선택
    BRACKET_VIEW = "bracket_view"      # 대진표 보기
    SELECT_MATCH = "select_match"      # 경기 선택
    BETTING = "betting"                # 배팅
    VS_PREVIEW = "vs_preview"            # 배틀 전 VS 매치업 미리보기
    BATTLE = "battle"                  # AI 배틀 진행
    RESULT = "result"                  # 경기 결과
    ROUND_END = "round_end"            # 라운드 종료 (계속/나가기 선택)
    GUARD_NOTIFY = "guard_notify"              # 호위무사 생포 알림
    GUARD_SELECT = "guard_select"              # 결승 호위무사 선택 화면
    PERK_SELECT = "perk_select"                # 투기장 퍽 선택 화면
    BRACKET_ANIMATION = "bracket_animation"  # 대진표 진출 애니메이션
    VICTORY_CELEBRATION = "victory_celebration"  # 우승 축하 연출
    TOURNAMENT_END = "tournament_end"  # 토너먼트 종료
    # 초반 셋업 상태들
    MATCH_REVEAL = "match_reveal"              # 매치 공개 애니메이션
    HERO_SELECT = "hero_select"                # 영웅 선택
    SKILL_REVEAL = "skill_reveal"              # 스킬 랜덤 선택 연출
    PRISON_SELECT = "prison_select"            # 감옥 호위무사 선택
    GUARD_SKILL_REVEAL = "guard_skill_reveal"  # 호위무사 스킬 연출
    TENACITY_RETRY = "tenacity_retry"          # 반칙왕 퍽 재시작 연출

class TournamentRound(Enum):
    QUARTER_FINAL = "8강"
    SEMI_FINAL = "4강"
    FINAL = "결승"

# ============================================================================
# 투기장 퍽 - 신성월계수 잎 궤도 시스템
# ============================================================================
class ArenaLeafShield:
    """투기장 전용 신성월계수 잎 시스템 (간소화 버전)"""

    def __init__(self, leaf_count=4, is_top=False):
        self.leaf_count = leaf_count
        self.is_top = is_top       # 상단(보스) vs 하단(플레이어)
        self.active = False
        self.leaves = []           # [{'active': bool, 'base_angle': float, 'regen_timer': int, 'type': int}]
        self.current_angle = 0.0   # 전체 회전 각도
        self.rotation_speed = 1.8  # 회전 속도 (rad/s)
        self.orbit_radius = 196   # 궤도 반지름 (기존 170에서 15% 확대)
        self.ellipse_y = 0.3       # Y축 압축률 (전설 신성월계수와 동일)
        self.front_threshold = 30  # 패들 앞쪽 잎 충돌 무시 기준 (전설과 동일)
        self.leaf_size = 19        # 잎 그리기 크기 (기존 24에서 20% 감소)
        self.hitbox_size = 35      # 충돌 판정 크기 (전설 신성월계수와 동일)
        self.regen_delay = 30 * 60  # 잎 재생 시간 (30초 * 60fps)
        self.owner_x = 0.0
        self.owner_y = 0.0
        self.particles = []        # 파괴 파티클

    def activate(self, leaf_count=5):
        self.leaf_count = leaf_count
        self.active = True
        self.current_angle = 0.0
        self.leaves = []
        self.particles = []
        for i in range(self.leaf_count):
            self.leaves.append({
                'active': True,
                'base_angle': (2 * math.pi / self.leaf_count) * i,
                'regen_timer': 0,
                'type': random.randint(0, 3),
                'size_variation': random.uniform(0.8, 1.2),
            })

    def deactivate(self):
        self.active = False
        self.leaves = []
        self.particles = []

    def set_position(self, x, y):
        self.owner_x = x
        self.owner_y = y

    def update(self, dt):
        if not self.active:
            return
        self.current_angle += self.rotation_speed * dt
        # 파괴된 잎 재생
        for leaf in self.leaves:
            if not leaf['active']:
                leaf['regen_timer'] += 1
                if leaf['regen_timer'] >= self.regen_delay:
                    leaf['active'] = True
                    leaf['regen_timer'] = 0
                    leaf['type'] = random.randint(0, 3)
                    leaf['size_variation'] = random.uniform(0.8, 1.2)
        # 파티클 업데이트
        for p in self.particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= 1
            if p['life'] <= 0:
                self.particles.remove(p)

    def check_ball_collision(self, ball_x, ball_y, ball_radius):
        """공과 잎 충돌 체크. 충돌 시 True 반환.
        패들 앞쪽(공이 오는 방향)에 있는 잎은 충돌 무시 (전설 신성월계수와 동일).
        """
        if not self.active:
            return False
        for leaf in self.leaves:
            if not leaf['active']:
                continue
            angle = self.current_angle + leaf['base_angle']
            lx = self.owner_x + _cos(angle) * self.orbit_radius
            ly = self.owner_y + _sin(angle) * self.orbit_radius * self.ellipse_y
            # 패들 앞쪽 잎 충돌 무시 (스매셔 등 패들로 공을 맞춰야 하는 캐릭터 배려)
            # 하단(플레이어): 잎이 패들보다 위에 있으면 앞쪽 → 무시
            # 상단(보스): 잎이 패들보다 아래에 있으면 앞쪽 → 무시
            if not self.is_top and ly < self.owner_y - self.front_threshold:
                continue
            if self.is_top and ly > self.owner_y + self.front_threshold:
                continue
            dist = math.sqrt((ball_x - lx) ** 2 + (ball_y - ly) ** 2)
            if dist < ball_radius + self.hitbox_size:
                self._destroy_leaf(leaf, lx, ly)
                return True
        return False

    def _destroy_leaf(self, leaf, x, y):
        leaf['active'] = False
        leaf['regen_timer'] = 0
        for _ in range(15):
            self.particles.append({
                'x': x, 'y': y,
                'vx': random.uniform(-3, 3),
                'vy': random.uniform(-4, 1),
                'life': random.randint(20, 40),
                'color': random.choice([
                    (255, 215, 100),   # 금색
                    (255, 240, 150),   # 밝은 금색
                    (255, 200, 80),    # 진한 금색
                    (220, 180, 60),    # 어두운 금색
                    (255, 255, 200),   # 크림색
                ]),
            })

    # ------------------------------------------------------------------
    # 잎 타입별 그리기 (신화 아이템 SacredLaurel과 동일)
    # ------------------------------------------------------------------
    def _draw_leaf_type_0(self, surf, w, h, depth_factor):
        """클래식 월계수 잎 - 타원형 기본 (금빛)"""
        base_gold = (int(180 * depth_factor), int(140 * depth_factor), int(50 * depth_factor))
        mid_gold = (int(220 * depth_factor), int(180 * depth_factor), int(60 * depth_factor))
        light_gold = (int(255 * depth_factor), int(215 * depth_factor), int(80 * depth_factor))
        highlight = (int(255 * depth_factor), int(240 * depth_factor), int(150 * depth_factor))
        vein_color = (int(150 * depth_factor), int(110 * depth_factor), int(30 * depth_factor))
        # 외곽 그림자
        pygame.draw.ellipse(surf, base_gold, (1, 1, w - 2, h - 2))
        # 메인 잎
        pygame.draw.ellipse(surf, mid_gold, (2, 2, w - 4, h - 4))
        # 하이라이트 (왼쪽 상단)
        pygame.draw.ellipse(surf, light_gold, (3, 2, w // 3, h // 2))
        pygame.draw.ellipse(surf, highlight, (4, 3, w // 5, h // 3))
        # 중심 잎맥
        pygame.draw.line(surf, vein_color, (w - 2, h // 2), (3, h // 2), 2)
        # 측면 잎맥들
        for i in range(3):
            offset = (i + 1) * w // 5
            pygame.draw.line(surf, vein_color, (w - offset, h // 2), (w - offset - 4, h // 4 + 1), 1)
            pygame.draw.line(surf, vein_color, (w - offset, h // 2), (w - offset - 4, h * 3 // 4 - 1), 1)

    def _draw_leaf_type_1(self, surf, w, h, depth_factor):
        """뾰족한 월계수 잎 - 창 모양 (금빛)"""
        base_gold = (int(170 * depth_factor), int(130 * depth_factor), int(40 * depth_factor))
        mid_gold = (int(210 * depth_factor), int(170 * depth_factor), int(55 * depth_factor))
        light_gold = (int(245 * depth_factor), int(205 * depth_factor), int(70 * depth_factor))
        highlight = (int(255 * depth_factor), int(235 * depth_factor), int(140 * depth_factor))
        vein_color = (int(140 * depth_factor), int(100 * depth_factor), int(25 * depth_factor))
        # 뾰족한 잎 모양 (폴리곤)
        points = [
            (w - 2, h // 2),       # 뾰족한 끝
            (w * 2 // 3, h // 5),  # 상단
            (w // 4, h // 4),
            (3, h // 2),           # 줄기 연결
            (w // 4, h * 3 // 4),
            (w * 2 // 3, h * 4 // 5),  # 하단
        ]
        pygame.draw.polygon(surf, base_gold, points)
        # 내부 레이어
        inner_points = [(int(p[0] * 0.9 + w * 0.05), int(p[1] * 0.85 + h * 0.075)) for p in points]
        pygame.draw.polygon(surf, mid_gold, inner_points)
        # 하이라이트
        pygame.draw.ellipse(surf, light_gold, (w // 3, h // 4, w // 4, h // 3))
        pygame.draw.ellipse(surf, highlight, (w // 3 + 2, h // 4 + 2, w // 6, h // 5))
        # 중심 잎맥
        pygame.draw.line(surf, vein_color, (w - 3, h // 2), (5, h // 2), 2)

    def _draw_leaf_type_2(self, surf, w, h, depth_factor):
        """둥근 월계수 잎 - 부드러운 곡선 (금빛)"""
        base_gold = (int(190 * depth_factor), int(150 * depth_factor), int(55 * depth_factor))
        mid_gold = (int(225 * depth_factor), int(185 * depth_factor), int(65 * depth_factor))
        light_gold = (int(255 * depth_factor), int(220 * depth_factor), int(90 * depth_factor))
        highlight = (int(255 * depth_factor), int(245 * depth_factor), int(160 * depth_factor))
        vein_color = (int(155 * depth_factor), int(115 * depth_factor), int(35 * depth_factor))
        edge_color = (int(130 * depth_factor), int(95 * depth_factor), int(25 * depth_factor))
        # 둥근 외곽
        pygame.draw.ellipse(surf, edge_color, (0, 0, w, h))
        pygame.draw.ellipse(surf, base_gold, (1, 1, w - 2, h - 2))
        # 둥근 내부
        pygame.draw.ellipse(surf, mid_gold, (3, 2, w - 6, h - 4))
        # 원형 하이라이트
        pygame.draw.ellipse(surf, light_gold, (w // 4, h // 5, w // 3, h // 2))
        pygame.draw.ellipse(surf, highlight, (w // 4 + 2, h // 5 + 2, w // 5, h // 3))
        # 부드러운 잎맥
        pygame.draw.arc(surf, vein_color, (2, h // 4, w - 4, h // 2), 3.14, 0, 2)
        pygame.draw.line(surf, vein_color, (w - 2, h // 2), (4, h // 2), 1)

    def _draw_leaf_type_3(self, surf, w, h, depth_factor):
        """톱니 월계수 잎 - 가장자리 톱니 (금빛)"""
        base_gold = (int(175 * depth_factor), int(135 * depth_factor), int(45 * depth_factor))
        mid_gold = (int(215 * depth_factor), int(175 * depth_factor), int(60 * depth_factor))
        light_gold = (int(250 * depth_factor), int(210 * depth_factor), int(75 * depth_factor))
        highlight = (int(255 * depth_factor), int(238 * depth_factor), int(145 * depth_factor))
        vein_color = (int(145 * depth_factor), int(105 * depth_factor), int(28 * depth_factor))
        # 톱니 모양 외곽
        points = []
        num_teeth = 6
        for i in range(num_teeth * 2 + 1):
            t = i / (num_teeth * 2)
            x = w - 2 - (w - 4) * t
            if i % 2 == 0:
                y_offset = 0
            else:
                y_offset = h // 8 if i < num_teeth else -h // 8
            base_y = h // 2
            curve = math.sin(t * math.pi) * (h // 3)
            if i <= num_teeth:
                y = base_y - curve + y_offset
            else:
                y = base_y + curve + y_offset
            points.append((x, max(1, min(h - 1, y))))
        if len(points) > 2:
            pygame.draw.polygon(surf, base_gold, points)
        # 내부
        pygame.draw.ellipse(surf, mid_gold, (w // 6, h // 4, w * 2 // 3, h // 2))
        # 하이라이트
        pygame.draw.ellipse(surf, light_gold, (w // 4, h // 4, w // 3, h // 3))
        pygame.draw.ellipse(surf, highlight, (w // 4 + 3, h // 4 + 2, w // 5, h // 5))
        # 잎맥
        pygame.draw.line(surf, vein_color, (w - 3, h // 2), (5, h // 2), 2)
        # 측면 잎맥
        for i in range(2):
            offset = (i + 1) * w // 4
            pygame.draw.line(surf, vein_color, (w - offset, h // 2), (w - offset - 5, h // 3), 1)
            pygame.draw.line(surf, vein_color, (w - offset, h // 2), (w - offset - 5, h * 2 // 3), 1)

    # ------------------------------------------------------------------
    # draw (신화 아이템 SacredLaurel.draw_effects와 동일 품질)
    # ------------------------------------------------------------------
    def draw(self, screen):
        if not self.active:
            return
        # 깊이 정렬
        draw_order = []
        for leaf in self.leaves:
            if not leaf['active']:
                continue
            angle = self.current_angle + leaf['base_angle']
            lx = self.owner_x + _cos(angle) * self.orbit_radius
            ly = self.owner_y + _sin(angle) * self.orbit_radius * self.ellipse_y
            depth = _sin(angle)
            draw_order.append((depth, angle, lx, ly, leaf))
        draw_order.sort(key=lambda x: x[0])

        for depth, angle, lx, ly, leaf in draw_order:
            depth_f = 0.6 + 0.4 * ((depth + 1) / 2)
            alpha_f = 0.5 + 0.5 * ((depth + 1) / 2)
            size_var = leaf.get('size_variation', 1.0)
            sz = int(self.leaf_size * depth_f * size_var)
            if sz < 2:
                continue

            # 타원형 글로우 (신화 아이템과 동일)
            glow_w = sz * 4
            glow_h = sz * 3
            glow_s = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
            glow_a = int(40 * alpha_f)
            pygame.draw.ellipse(glow_s, (255, 215, 100, glow_a), (0, 0, glow_w, glow_h))
            screen.blit(glow_s, (int(lx) - glow_w // 2, int(ly) - glow_h // 2))

            # 잎 서피스 (가로로 길게 - 신화 아이템과 동일 비율)
            leaf_w = max(4, int(sz * 2.5))
            leaf_h = max(3, int(sz * 1.2))
            leaf_s = pygame.Surface((leaf_w, leaf_h), pygame.SRCALPHA)

            # 잎 타입별 디테일 그리기
            leaf_type = leaf.get('type', 0)
            if leaf_type == 0:
                self._draw_leaf_type_0(leaf_s, leaf_w, leaf_h, depth_f)
            elif leaf_type == 1:
                self._draw_leaf_type_1(leaf_s, leaf_w, leaf_h, depth_f)
            elif leaf_type == 2:
                self._draw_leaf_type_2(leaf_s, leaf_w, leaf_h, depth_f)
            else:
                self._draw_leaf_type_3(leaf_s, leaf_w, leaf_h, depth_f)

            # 회전
            rotated = pygame.transform.rotate(leaf_s, -math.degrees(angle))
            rect = rotated.get_rect(center=(int(lx), int(ly)))
            screen.blit(rotated, rect)

        # 파티클
        for p in self.particles:
            life_ratio = p['life'] / 40.0
            a = min(255, int(255 * life_ratio))
            sz = max(1, int(p['life'] / 8))
            ps = pygame.Surface((sz * 2, sz * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*p['color'], a), (sz, sz), sz)
            screen.blit(ps, (int(p['x']) - sz, int(p['y']) - sz))


# ============================================================================
# 투기장 퍽 시스템
# ============================================================================
ARENA_PERK_POOL = [
    # === 기본 퍽 (4종) ===
    {
        "id": "swift_foot",
        "name": "질풍각",
        "description": "이동속도 50% 증가",
        "icon_color": (100, 220, 255),   # 하늘색 (바람)
        "effect_type": "move_speed",
        "value": 0.50,
    },
    {
        "id": "quick_reflex",
        "name": "순발력",
        "description": "대쉬 쿨타임 50% 감소",
        "icon_color": (255, 180, 50),    # 주황 (번개)
        "effect_type": "dash_cooldown",
        "value": 0.50,
    },
    {
        "id": "spirit_flow",
        "name": "영기순환",
        "description": "스킬 쿨타임 30% 감소",
        "icon_color": (180, 100, 255),   # 보라 (마법)
        "effect_type": "skill_cooldown",
        "value": 0.30,
    },
    {
        "id": "command",
        "name": "호령",
        "description": "호위무사 쿨타임 30% 감소",
        "icon_color": (255, 100, 100),   # 빨강 (권위)
        "effect_type": "guard_cooldown",
        "value": 0.30,
    },
    # === 신규 퍽 (5종) ===
    {
        "id": "shadow_step",
        "name": "잔상술",
        "description": "대쉬 토큰 1개 추가",
        "icon_color": (80, 200, 180),    # 청록 (그림자)
        "effect_type": "dash_token",
        "value": 1,
    },
    {
        "id": "storm_rush",
        "name": "폭풍질주",
        "description": "대쉬 거리 50% 증가\n대쉬 시 패들 크기 210% 확대",
        "icon_color": (50, 180, 255),    # 파랑 (폭풍)
        "effect_type": "dash_distance",
        "value": 0.50,
    },
    {
        "id": "tenacity",
        "name": "반칙왕",
        "description": "실점 시 15% 확률로 무효화\n(횟수 제한 없음)",
        "icon_color": (255, 200, 60),    # 금색 (반칙왕)
        "effect_type": "retry_chance",
        "value": 0.15,
    },
    {
        "id": "extra_training",
        "name": "추가훈련",
        "description": "호위무사 스킬이\n한 개 더 해금됩니다",
        "icon_color": (100, 180, 220),   # 파란색 (훈련/학습)
        "effect_type": "guard_extra_skill",
        "value": 1,
    },
    {
        "id": "magic_barrier",
        "name": "마법결계",
        "description": "타격 시 15% 확률 6초 면역",
        "icon_color": (120, 200, 255),   # 밝은 파랑 (결계)
        "effect_type": "magic_immunity",
        "value": 0.15,
    },
    {
        "id": "laurel_shield",
        "name": "신성월계수",
        "description": "잎 4개가 영웅 주위를 회전하며 공을 방어",
        "icon_color": (200, 180, 60),    # 금색 (월계수)
        "effect_type": "laurel_shield",
        "value": 4,  # 잎 개수
    },
    {
        "id": "titan_body",
        "name": "거신화",
        "description": "패들+영웅 이미지 50% 확대",
        "icon_color": (220, 120, 60),    # 주황 (거대화)
        "effect_type": "paddle_enlarge",
        "value": 0.50,  # 50% 증가
    },
    {
        "id": "flash_inspiration",
        "name": "번뜩이는 영감",
        "description": "타격 시 8% 확률로\n스킬 쿨타임 즉시 충전",
        "icon_color": (255, 220, 100),   # 금빛 (영감/번쩍임)
        "effect_type": "instant_cooldown",
        "value": 0.08,
    },
    # === 해금 조건 퍽 ===
    {
        "id": "recall_guard",
        "name": "재소집령",
        "description": "해고했던 호위무사를 불러내어\n전투에 참가시킵니다\n(호위무사 2명)",
        "icon_color": (200, 160, 60),    # 금빛 (명령/충성)
        "effect_type": "recall_guard",
        "value": 1,
        "unlock_condition": "former_guards",  # 이전에 호위무사를 해고한 적이 있어야 함
    },
]

# ============================================================================
# 토너먼트 매치
# ============================================================================
class Match:
    def __init__(self, hero1: Dict, hero2: Dict, match_id: int):
        self.hero1 = hero1
        self.hero2 = hero2
        self.match_id = match_id
        self.winner: Optional[Dict] = None
        self.score1 = 0
        self.score2 = 0
        self.completed = False

    def set_result(self, winner: Dict, score1: int, score2: int):
        self.winner = winner
        self.score1 = score1
        self.score2 = score2
        self.completed = True

# ============================================================================
# AI 패들 컨트롤러 (실제 보스 AI 수준)
# ============================================================================
class AIPaddleController:
    """실제 게임의 보스 AI와 동일한 수준의 AI 컨트롤러"""

    def __init__(self, hero: Dict, is_top: bool):
        self.hero = hero
        self.is_top = is_top
        self.x = GAME_AREA_X + GAME_AREA_WIDTH // 2 - PADDLE_WIDTH // 2
        self.y = TOP_PADDLE_Y if is_top else BOTTOM_PADDLE_Y
        self.target_x = self.x
        self.velocity = 0.0
        self.visual_width = PADDLE_WIDTH  # 시각적 패들 너비 (스킬 효과용)
        self.width = PADDLE_WIDTH  # 스킬 코드 호환용 (target_paddle.width)
        self.height = PADDLE_HEIGHT  # 스킬 코드 호환용 (target_paddle.height)

        # 영웅 스탯 기반 능력치
        self.base_speed = 7.0 * hero["speed"]
        self.max_speed = 10.0 * hero["speed"]
        self.reaction_time = 0.08 / hero["reaction"]  # 반응 시간 (초)
        self.prediction_accuracy = hero["accuracy"]  # 예측 정확도
        self.power = hero["power"]

        # AI 상태
        self.style = hero["style"]
        self.reaction_timer = 0.0
        self.predicted_x = self.x + PADDLE_WIDTH // 2
        self.last_prediction_time = 0.0

        # 움직임 스무딩
        self.smoothing = 0.15
        self.idle_return_speed = 0.02

        # 실수 시스템 (정확도에 따라)
        self.error_offset = 0
        self.error_update_timer = 0

        # 스킬 상태 효과
        self.is_stunned = False
        self.slow_multiplier = 1.0
        self.is_confused = False  # 조작 반전
        self.paddle_scale = 1.0   # 패들 크기 배율
        self.gravity_drift = 0.0  # 중력 드리프트 (px/s, 중력조절 스킬용)

        # 대쉬 시스템 (보스 대쉬와 동일한 물리 엔진)
        self.dash_active = False
        self.dash_direction = 0  # -1: 왼쪽, 1: 오른쪽
        self.dash_timer = 0  # 대쉬 지속 시간
        self.dash_duration = 25  # 대쉬 총 지속 프레임 (보스와 동일)
        self.dash_high_phase = 15  # 고속 구간 프레임
        self.dash_cooldown_ms = 0  # 대쉬 쿨다운 (ms)
        self.dash_cooldown_min_ms = 4000  # 최소 쿨다운 4초 (신화리그 수준)
        self.dash_cooldown_max_ms = 6000  # 최대 쿨다운 6초
        self.dash_speed = 40.0  # 대쉬 속도 (보스와 동일)
        self.dash_target_x = 0.0  # 대쉬 목표 X
        self.dash_stun_timer = 0  # 대쉬 후딜
        self.dash_stun_duration = 18  # 대쉬 후딜 프레임 (0.3초)
        self.dash_afterimages = []  # 대쉬 잔상 효과 (이미지 기반)
        self.dash_delay_sound_playing = False  # 후딜 사운드 재생 중

        # AI 대쉬 판단용
        self.last_ball_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.emergency_dash_threshold = 120  # 긴급 대쉬 발동 거리

        # 귀신발걸음 (Ghost Step) y축 이동 시스템
        self.ghost_step_active = False  # 귀신발걸음 y축 이동 활성화 여부
        self.ghost_step_y_velocity = 0.0  # y축 이동 속도
        self.ghost_step_speed = 3.0  # 기본 y축 이동 속도 (부드럽게)
        self.ghost_step_max_offset = 120  # 최대 이동 거리 (원위치에서)
        self.ghost_step_phase = 0  # 0: 전진, 1: 복귀
        self.original_y = self.y  # 원래 y 위치 저장

    def _predict_x_with_walls(self, ball_x: float, ball_vx: float, ball_y: float,
                               ball_vy: float, target_y: float) -> float:
        """벽 반사를 고려한 도착 X 좌표 예측 (실제 보스 AI와 동일)"""
        if abs(ball_vy) < 0.1:
            return ball_x

        # 도착까지 걸리는 시간
        time_to_target = abs(target_y - ball_y) / abs(ball_vy)

        # X 이동량 계산
        total_dx = ball_vx * time_to_target
        predicted_x = ball_x + total_dx

        # 벽 반사 시뮬레이션
        left_wall = GAME_AREA_X + BALL_SIZE
        right_wall = GAME_AREA_X + GAME_AREA_WIDTH - BALL_SIZE

        # 반사 횟수 제한 (최대 10회)
        for _ in range(10):
            if predicted_x < left_wall:
                predicted_x = 2 * left_wall - predicted_x
            elif predicted_x > right_wall:
                predicted_x = 2 * right_wall - predicted_x
            else:
                break

        return predicted_x

    def update(self, ball_x: float, ball_y: float, ball_vx: float, ball_vy: float, dt: float):
        """AI 패들 업데이트 (실제 보스 AI 수준)"""
        # 대쉬 상태 업데이트 (항상 먼저)
        self.update_dash(dt)

        # 귀신발걸음 y축 이동 업데이트
        self.update_ghost_step(dt)

        # 스턴 상태면 움직이지 않음
        if self.is_stunned:
            return

        # 대쉬 중이거나 대쉬 후딜 중이면 일반 이동 안함
        if self.dash_active or self.dash_stun_timer > 0:
            return

        # AI 긴급 대쉬 시도
        self.ai_try_emergency_dash(ball_x, ball_y, ball_vx, ball_vy)

        # 공이 자기 방향으로 오는지 확인
        coming_towards = (ball_vy < 0 and self.is_top) or (ball_vy > 0 and not self.is_top)

        # 반응 타이머 업데이트
        self.reaction_timer += dt
        self.error_update_timer += dt

        # 실수 오프셋 주기적 업데이트
        if self.error_update_timer > 0.5:
            self.error_update_timer = 0
            # 정확도에 따른 실수 범위
            error_range = int(30 * (1 - self.prediction_accuracy))
            self.error_offset = random.randint(-error_range, error_range)

        if coming_towards and self.reaction_timer >= self.reaction_time:
            # 목표 위치 예측
            self.predicted_x = self._predict_x_with_walls(
                ball_x, ball_vx, ball_y, ball_vy, self.y
            )

            # 스타일에 따른 목표 위치 조정
            if self.style == HeroStyle.AGGRESSIVE:
                # 공격적: 공이 빠를 때 더 과감하게 이동, 끝쪽 타격 선호
                speed_factor = math.hypot(ball_vx, ball_vy) / 10.0
                offset = (0.5 - random.random()) * 18 * speed_factor
                self.target_x = self.predicted_x + offset + self.error_offset
            elif self.style == HeroStyle.DEFENSIVE:
                # 수비적: 정확한 중앙 타격
                self.target_x = self.predicted_x + self.error_offset * 0.5
            elif self.style == HeroStyle.TRICKY:
                # 트릭: 예측 불가능한 움직임
                if random.random() < 0.3:
                    offset = random.randint(-25, 25)
                else:
                    offset = 0
                self.target_x = self.predicted_x + offset + self.error_offset
            else:
                # 균형: 약간의 변동
                self.target_x = self.predicted_x + self.error_offset * 0.7
        else:
            # 공이 멀어질 때 중앙으로 서서히 복귀
            center = GAME_AREA_X + GAME_AREA_WIDTH // 2
            self.target_x = self.target_x * (1 - self.idle_return_speed) + center * self.idle_return_speed
            self.reaction_timer = 0  # 반응 타이머 리셋

        # 패들 중심 기준으로 목표 설정
        target_center = self.target_x
        current_center = self.x + PADDLE_WIDTH // 2

        # 혼란 상태면 방향 반전
        diff = target_center - current_center
        if self.is_confused:
            diff = -diff

        # 속도 계산 (스무딩 적용)
        target_velocity = diff * self.smoothing * 60  # 60fps 기준

        # 둔화 적용
        target_velocity *= self.slow_multiplier

        # 속도 제한
        max_spd = self.max_speed * self.slow_multiplier
        target_velocity = max(-max_spd, min(max_spd, target_velocity))

        # 가속도 적용
        accel = 0.3 * self.slow_multiplier
        if abs(target_velocity - self.velocity) > accel:
            if target_velocity > self.velocity:
                self.velocity += accel
            else:
                self.velocity -= accel
        else:
            self.velocity = target_velocity

        # 위치 업데이트
        self.x += self.velocity

        # 중력 드리프트 적용 (중력조절 스킬)
        if self.gravity_drift != 0:
            self.x += self.gravity_drift * dt

        # 경계 체크
        self.x = max(GAME_AREA_X, min(self.x, GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH))

    def get_rect(self) -> pygame.Rect:
        # paddle_scale 적용하여 축소 시 충돌 판정도 줄어들게
        scaled_width = int(PADDLE_WIDTH * self.paddle_scale)
        # 중심 기준으로 축소 (좌우 대칭)
        x_offset = (PADDLE_WIDTH - scaled_width) // 2
        return pygame.Rect(int(self.x) + x_offset, int(self.y), scaled_width, PADDLE_HEIGHT)

    def get_center_x(self) -> float:
        return self.x + PADDLE_WIDTH // 2

    def try_dash(self, target_x: float) -> bool:
        """대쉬 시도, 성공 시 True 반환 (보스 대쉬와 동일한 로직)"""
        now_ms = pygame.time.get_ticks()

        # 대쉬 불가능 상태 체크
        if self.dash_active or self.dash_stun_timer > 0 or self.is_stunned:
            return False

        # 쿨다운 체크
        if self.dash_cooldown_ms > 0 and now_ms < self.dash_cooldown_ms:
            return False

        # 대쉬 방향 결정
        paddle_center = self.x + PADDLE_WIDTH // 2
        direction = 1 if target_x > paddle_center else -1
        dash_distance = abs(target_x - paddle_center)

        # 최소 거리 체크
        if dash_distance < 30:
            return False

        # 대쉬 활성화
        self.dash_active = True
        self.dash_direction = direction
        self.dash_target_x = max(GAME_AREA_X + PADDLE_WIDTH // 2,
                                  min(GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH // 2, target_x))
        self.dash_timer = self.dash_duration

        # 🔊 대쉬 사운드 재생
        try:
            import pingfighter
            if hasattr(pingfighter, 'play_dash_sound'):
                pingfighter.play_dash_sound()
        except Exception:
            pass

        # 쿨다운 설정 (신화리그 수준: 4~6초)
        cooldown_ms = random.randint(self.dash_cooldown_min_ms, self.dash_cooldown_max_ms)
        self.dash_cooldown_ms = now_ms + cooldown_ms

        return True

    def update_dash(self, dt: float):
        """대쉬 상태 업데이트 (보스 대쉬와 동일한 물리 엔진)"""
        now_ms = pygame.time.get_ticks()

        # 잔상 효과 업데이트 (항상, 배속 적용)
        new_afterimages = []
        for after in self.dash_afterimages:
            after['alpha'] -= 25 * dt * 60
            after['life'] -= dt * 60
            if after['alpha'] > 0 and after['life'] > 0:
                new_afterimages.append(after)
        self.dash_afterimages = new_afterimages

        # 후딜 상태 처리
        if self.dash_stun_timer > 0:
            prev_stun = self.dash_stun_timer
            self.dash_stun_timer -= dt * 60

            # 🔊 후딜 종료 시 사운드 중지
            if prev_stun > 0 and self.dash_stun_timer <= 0:
                if self.dash_delay_sound_playing:
                    try:
                        import pingfighter
                        if hasattr(pingfighter, 'stop_dash_delay_sound'):
                            pingfighter.stop_dash_delay_sound()
                    except Exception:
                        pass
                    self.dash_delay_sound_playing = False
            return

        if not self.dash_active:
            return

        # 대쉬 타이머 감소 (배속 적용)
        self.dash_timer -= dt * 60

        # 🎮 대쉬 물리 엔진 (보스와 동일한 속도 곡선)
        # 고속 구간: dash_timer > high_phase_frames
        # 감속 구간: dash_timer <= high_phase_frames
        if self.dash_timer > self.dash_high_phase:
            move_step = self.dash_speed * self.dash_direction
        else:
            # 감속: 선형 감속
            decel_factor = max(0.0, self.dash_timer / float(self.dash_high_phase)) if self.dash_high_phase > 0 else 0.0
            move_step = self.dash_speed * self.dash_direction * decel_factor

        # 잔상 추가 (2프레임마다)
        if self.dash_timer % 2 == 0:
            self.dash_afterimages.append({
                'x': self.x + PADDLE_WIDTH // 2,
                'y': self.y + PADDLE_HEIGHT // 2,
                'alpha': 160,
                'life': 10,
                'color': self.hero["color"]
            })
            if len(self.dash_afterimages) > 6:
                self.dash_afterimages.pop(0)

        # 이동 적용 (배속 적용)
        self.x += move_step * dt * 60

        # 목표 도달 체크
        paddle_center = self.x + PADDLE_WIDTH // 2
        if self.dash_direction > 0 and paddle_center >= self.dash_target_x:
            self.x = self.dash_target_x - PADDLE_WIDTH // 2
        elif self.dash_direction < 0 and paddle_center <= self.dash_target_x:
            self.x = self.dash_target_x - PADDLE_WIDTH // 2

        # 경계 체크
        if self.x < GAME_AREA_X:
            self.x = GAME_AREA_X
            self._end_dash()
        elif self.x > GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH:
            self.x = GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH
            self._end_dash()

        # 대쉬 종료
        if self.dash_timer <= 0:
            self._end_dash()

    def _end_dash(self):
        """대쉬 종료 처리"""
        self.dash_active = False
        self.dash_stun_timer = self.dash_stun_duration

        # 🔊 대쉬 후딜 사운드 시작
        try:
            import pingfighter
            if hasattr(pingfighter, 'play_dash_delay_sound'):
                pingfighter.play_dash_delay_sound()
                self.dash_delay_sound_playing = True
        except Exception:
            pass

    def start_ghost_step(self):
        """귀신발걸음 y축 이동 시작 (상단→하단, 하단→상단으로 귀신처럼 다가옴)"""
        if self.ghost_step_active:
            return False

        self.ghost_step_active = True
        self.original_y = self.y
        self.ghost_step_phase = 0  # 전진 페이즈

        # 상단 영웅은 아래로 (y 증가), 하단 영웅은 위로 (y 감소)
        if self.is_top:
            self.ghost_step_y_velocity = self.ghost_step_speed  # 아래로
        else:
            self.ghost_step_y_velocity = -self.ghost_step_speed  # 위로

        return True

    def update_ghost_step(self, dt: float):
        """귀신발걸음 y축 이동 업데이트 (1회 왕복 후 종료)"""
        if not self.ghost_step_active:
            return

        # y축으로 이동 (배속 적용: dt * 60으로 프레임 기반 속도를 시간 기반으로 변환)
        self.y += self.ghost_step_y_velocity * dt * 60

        # 현재 이동 거리 계산
        current_offset = abs(self.y - self.original_y)

        if self.ghost_step_phase == 0:
            # 전진 페이즈: 최대 거리에 도달하면 복귀로 전환
            if current_offset >= self.ghost_step_max_offset:
                self.ghost_step_phase = 1
                self.ghost_step_y_velocity = -self.ghost_step_y_velocity  # 방향 반전
        else:
            # 복귀 페이즈: 원위치에 도달하면 귀신발걸음 종료
            if self.is_top:
                if self.y <= self.original_y:
                    self.end_ghost_step()
            else:
                if self.y >= self.original_y:
                    self.end_ghost_step()

    def end_ghost_step(self):
        """귀신발걸음 y축 이동 종료 및 원위치 복귀"""
        self.ghost_step_active = False
        self.y = self.original_y
        self.ghost_step_y_velocity = 0.0
        self.ghost_step_phase = 0

    def ai_try_emergency_dash(self, ball_x: float, ball_y: float, ball_vx: float, ball_vy: float) -> bool:
        """AI 긴급 대쉬 판단 (보스 AI와 동일한 로직)"""
        now_ms = pygame.time.get_ticks()

        # 대쉬 불가능 상태
        if self.dash_cooldown_ms > 0 and now_ms < self.dash_cooldown_ms:
            return False
        if self.dash_active or self.dash_stun_timer > 0 or self.is_stunned:
            return False

        # 공이 자기 방향으로 오는지 확인
        coming_towards = (ball_vy < 0 and self.is_top) or (ball_vy > 0 and not self.is_top)
        if not coming_towards:
            return False

        # 공까지의 Y 거리 계산
        y_distance = abs(ball_y - self.y)

        # 공이 너무 멀면 대쉬 불필요 (120px 이내)
        if y_distance > 120 or y_distance <= 0:
            return False

        # 도착 시간 계산 (프레임 단위)
        time_to_paddle = y_distance / max(1.0, abs(ball_vy))

        # 시간이 너무 많이 남으면 일반 이동으로 대응 가능
        if time_to_paddle > 20.0:
            return False

        # 벽 반사 고려한 예측 X 위치
        predicted_x = self._predict_x_with_walls(ball_x, ball_vx, ball_y, ball_vy, self.y)

        # 패들 중심과 예측 위치 간 거리
        paddle_center = self.x + PADDLE_WIDTH // 2
        required_distance = abs(predicted_x - paddle_center)

        # 일반 이동으로 커버 가능한 거리 계산
        max_travel = self.max_speed * time_to_paddle * 1.5  # 여유분 포함

        # 일반 이동으로 충분하면 대쉬 불필요
        if required_distance <= max_travel:
            return False

        # 긴급 대쉬 필요 - 스타일에 따른 확률
        dash_chance = 0.6  # 기본 60% 확률 (긴급 상황)
        if self.style == HeroStyle.AGGRESSIVE:
            dash_chance = 0.85  # 공격적: 85%
        elif self.style == HeroStyle.DEFENSIVE:
            dash_chance = 0.5  # 수비적: 50%
        elif self.style == HeroStyle.TRICKY:
            dash_chance = 0.7  # 트릭: 70%

        if random.random() < dash_chance:
            return self.try_dash(predicted_x)

        return False

    def draw_dash_effects(self, screen: pygame.Surface):
        """대쉬 효과 그리기 (잔상 + 후딜 표시)"""
        # 잔상 그리기 (이미지 기반)
        for after in self.dash_afterimages:
            alpha = after.get('alpha', 0)
            if alpha <= 0:
                continue

            x = after.get('x', 0)
            y = after.get('y', 0)
            color = after.get('color', self.hero["color"])

            # 잔상 표면 생성
            trail_w = int(PADDLE_WIDTH * 0.9)
            trail_h = int(PADDLE_HEIGHT * 1.5)
            trail_surf = _get_arena_surface(trail_w, trail_h)
            pygame.draw.ellipse(trail_surf, (*color, int(alpha * 0.7)),
                               (0, 0, trail_w, trail_h))
            screen.blit(trail_surf, (int(x - trail_w // 2), int(y - trail_h // 2)))

        # 대쉬 중 속도선 효과
        if self.dash_active:
            # 속도감 표현 줄무늬
            for i in range(3):
                offset = (3 - i) * 8 * (-self.dash_direction)
                alpha = 100 - i * 30
                line_surface = _get_arena_surface(4, PADDLE_HEIGHT)
                line_surface.fill((255, 255, 255, alpha))
                screen.blit(line_surface, (int(self.x + offset), int(self.y)))

# ============================================================================
# 공 클래스 (실제 게임 물리 적용)
# ============================================================================
class ArenaBall:
    """실제 게임과 동일한 물리를 가진 공"""

    def __init__(self):
        self.x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2
        self.vx = 0.0
        self.vy = 0.0
        self.visible = False
        self.trail = []  # 잔상 효과
        self.wall_bounced = False  # 벽 반사 감지 플래그

    def reset(self, direction: int = 1, serve_x: float = None):
        """공 초기화"""
        self.x = serve_x if serve_x else GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2

        # 실제 게임과 동일한 초기 속도
        angle = random.uniform(-0.4, 0.4)
        self.vx = BALL_BASE_SPEED * _sin(angle)
        self.vy = BALL_BASE_SPEED * direction
        self.visible = True
        self.trail = []
        self.wall_bounced = False

    def update(self, dt: float = 1/60) -> Optional[str]:
        """공 업데이트 (실제 게임 물리)"""
        if not self.visible:
            return None

        # 잔상 추가
        self.trail.append((self.x, self.y, 1.0))
        # 잔상 페이드 아웃
        self.trail = [(x, y, a - 0.1) for x, y, a in self.trail if a > 0.1]
        if len(self.trail) > 10:
            self.trail = self.trail[-10:]

        # 위치 업데이트
        self.x += self.vx
        self.y += self.vy

        # 좌우 벽 반사
        left_wall = GAME_AREA_X + BALL_SIZE
        right_wall = GAME_AREA_X + GAME_AREA_WIDTH - BALL_SIZE

        self.wall_bounced = False  # 매 프레임 초기화
        if self.x <= left_wall:
            self.x = left_wall
            self.vx = abs(self.vx) * WALL_BOUNCE_SLOWDOWN
            self.wall_bounced = True
        elif self.x >= right_wall:
            self.x = right_wall
            self.vx = -abs(self.vx) * WALL_BOUNCE_SLOWDOWN
            self.wall_bounced = True

        # 상하 득점 체크
        if self.y <= 0:
            self.visible = False
            return "bottom"  # 하단 플레이어 득점
        elif self.y >= SCREEN_HEIGHT:
            self.visible = False
            return "top"  # 상단 플레이어 득점

        return None

    def check_paddle_collision(self, paddle: AIPaddleController) -> bool:
        """패들 충돌 체크 (실제 게임과 동일)"""
        if not self.visible:
            return False

        paddle_rect = paddle.get_rect()

        # 확장된 충돌 박스 (실제 게임처럼)
        ball_rect = pygame.Rect(
            self.x - BALL_SIZE - 2,
            self.y - BALL_SIZE - 2,
            BALL_SIZE * 2 + 4,
            BALL_SIZE * 2 + 4
        )

        if paddle_rect.colliderect(ball_rect):
            # 이미 맞은 방향이면 무시 (관통 방지)
            if paddle.is_top and self.vy < 0:
                return False
            if not paddle.is_top and self.vy > 0:
                return False

            # 충돌 위치 보정
            if paddle.is_top:
                self.y = paddle_rect.bottom + BALL_SIZE + 1
            else:
                self.y = paddle_rect.top - BALL_SIZE - 1

            # 반사 및 가속
            self.vy = -self.vy * BALL_ACCELERATION

            # 패들 타격 위치에 따른 각도 변화 (실제 게임 공식)
            paddle_center = paddle.get_center_x()
            hit_offset = (self.x - paddle_center) / (PADDLE_WIDTH / 2)
            hit_offset = max(-1.0, min(1.0, hit_offset))

            # 타격 위치와 파워에 따른 X 속도 변화
            self.vx += hit_offset * PADDLE_HIT_ANGLE_FACTOR * paddle.power

            # 속도 제한
            speed = math.hypot(self.vx, self.vy)
            if speed > BALL_MAX_SPEED:
                scale = BALL_MAX_SPEED / speed
                self.vx *= scale
                self.vy *= scale

            # 최소 Y 속도 보장 (수평으로 가는 것 방지)
            min_vy = 3.0
            if abs(self.vy) < min_vy:
                self.vy = min_vy if self.vy > 0 else -min_vy

            return True
        return False

    def get_speed(self) -> float:
        return math.hypot(self.vx, self.vy)


# ============================================================================
# 공 생성 애니메이션
# ============================================================================
class BallSpawnAnimation:
    """실제 게임과 동일한 공 생성 애니메이션"""

    def __init__(self):
        self.active = False
        self.phase = 0  # 0: 에너지 수집, 1: 공 형성, 2: 서브 모션
        self.timer = 0.0
        self.particles = []
        self.center_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.center_y = SCREEN_HEIGHT // 2
        self.ball_alpha = 0
        self.serve_direction = 1
        self.complete = False

        # 페이즈 지속 시간
        self.phase_durations = [1.5, 0.8, 0.5]  # 빠른 버전

    def start(self, serve_direction: int = 1):
        """애니메이션 시작"""
        self.active = True
        self.phase = 0
        self.timer = 0.0
        self.complete = False
        self.serve_direction = serve_direction
        self.ball_alpha = 0

        # 파티클 생성
        self.particles = []
        for _ in range(30):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(100, 200)
            speed = random.uniform(80, 150)
            self.particles.append({
                'x': self.center_x + _cos(angle) * dist,
                'y': self.center_y + _sin(angle) * dist,
                'angle': angle,
                'speed': speed,
                'size': random.uniform(2, 5),
                'color_shift': random.uniform(0, 1),
            })

    def update(self, dt: float) -> bool:
        """업데이트, 완료 시 True 반환"""
        if not self.active:
            return False

        self.timer += dt

        phase_duration = self.phase_durations[self.phase]

        if self.phase == 0:
            # 페이즈 0: 에너지 수집 - 파티클이 중앙으로 모임
            progress = min(1.0, self.timer / phase_duration)
            for p in self.particles:
                # 중앙으로 수렴
                target_dist = 150 * (1 - progress)
                current_dist = math.hypot(p['x'] - self.center_x, p['y'] - self.center_y)
                if current_dist > target_dist:
                    move_speed = p['speed'] * dt
                    dx = self.center_x - p['x']
                    dy = self.center_y - p['y']
                    dist = math.hypot(dx, dy)
                    if dist > 0:
                        p['x'] += (dx / dist) * move_speed
                        p['y'] += (dy / dist) * move_speed

                # 회전
                p['angle'] += dt * 3

            if self.timer >= phase_duration:
                self.phase = 1
                self.timer = 0

        elif self.phase == 1:
            # 페이즈 1: 공 형성
            progress = min(1.0, self.timer / phase_duration)
            self.ball_alpha = int(255 * progress)

            # 파티클이 공으로 흡수
            for p in self.particles:
                p['size'] *= 0.95

            if self.timer >= phase_duration:
                self.phase = 2
                self.timer = 0

        elif self.phase == 2:
            # 페이즈 2: 준비 완료
            progress = min(1.0, self.timer / phase_duration)

            if self.timer >= phase_duration:
                self.active = False
                self.complete = True
                return True

        return False

    def draw(self, screen: pygame.Surface):
        """애니메이션 그리기"""
        if not self.active:
            return

        # 파티클 그리기
        for p in self.particles:
            if p['size'] < 0.5:
                continue

            # 색상 (노랑 ~ 주황 ~ 흰색)
            hue = p['color_shift'] + self.timer * 0.5
            r = int(200 + 55 * _sin(hue))
            g = int(180 + 75 * _sin(hue + 1))
            b = int(100 + 100 * _sin(hue + 2))

            size = int(p['size'])
            if size > 0:
                surf = _get_arena_surface(size * 2, size * 2)
                alpha = min(255, int(200 * (p['size'] / 5)))
                pygame.draw.circle(surf, (r, g, b, alpha), (size, size), size)
                screen.blit(surf, (int(p['x']) - size, int(p['y']) - size), special_flags=pygame.BLEND_ADD)

        # 중앙 글로우
        if self.phase >= 1:
            glow_size = 40 + int(20 * _sin(self.timer * 10))
            glow_surf = _get_arena_surface(glow_size * 2, glow_size * 2)
            for r in range(glow_size, 0, -5):
                alpha = int(30 * self.ball_alpha / 255 * (r / glow_size))
                pygame.draw.circle(glow_surf, (255, 220, 100, alpha), (glow_size, glow_size), r)
            screen.blit(glow_surf, (int(self.center_x) - glow_size, int(self.center_y) - glow_size),
                       special_flags=pygame.BLEND_ADD)

        # 공 그리기 (형성 중)
        if self.ball_alpha > 0:
            # 그림자
            pygame.draw.circle(screen, (40, 35, 30),
                             (int(self.center_x) + 2, int(self.center_y) + 3), BALL_SIZE)
            # 공 본체
            ball_color = (255, 255, 255, self.ball_alpha)
            ball_surf = _get_arena_surface(BALL_SIZE * 2 + 4, BALL_SIZE * 2 + 4)
            pygame.draw.circle(ball_surf, ball_color, (BALL_SIZE + 2, BALL_SIZE + 2), BALL_SIZE)
            screen.blit(ball_surf, (int(self.center_x) - BALL_SIZE - 2, int(self.center_y) - BALL_SIZE - 2))
            # 하이라이트
            if self.ball_alpha > 200:
                pygame.draw.circle(screen, (255, 255, 220),
                                 (int(self.center_x) - 3, int(self.center_y) - 3), 3)

    def get_spawn_position(self) -> Tuple[float, float]:
        return self.center_x, self.center_y

    def is_complete(self) -> bool:
        return self.complete

# ============================================================================
# 호위무사 시스템 (Guard Warrior System)
# ============================================================================
# 애니메이션 타이밍 상수
GUARD_ENTER_DURATION = 0.6    # 등장 시간 (초)
GUARD_CAST_DURATION = 0.8     # 시전 포즈 시간
GUARD_EXIT_DURATION = 0.5     # 퇴장 시간


class _GuardPaddle:
    """호위무사 위치를 패들처럼 사용하기 위한 가상 패들 객체"""
    def __init__(self, x, y, is_top, width=PADDLE_WIDTH, height=PADDLE_HEIGHT):
        self.x = x - width // 2  # centerx → left x
        self.y = y
        self.width = width
        self.height = height
        self.centerx = x
        self.centery = y + height // 2
        self.is_top = is_top
        self.is_bodyguard = True  # 호위무사 패들 식별용 (해골궁수 등에서 사용)
        self.paddle_scale = 1.0
        self.power = 1.0  # 공 반사 파워 (check_paddle_collision 호환)

    def get_rect(self):
        """패들 충돌 사각형 반환 (check_paddle_collision 호환)"""
        return pygame.Rect(int(self.x), int(self.y), self.width, self.height)

    def get_center_x(self):
        """패들 중심 X 좌표 (check_paddle_collision 호환)"""
        return self.centerx


class GuardWarriorSystem:
    """호위무사 시스템 - 4강/결승에서 패배 영웅이 승자를 돕는 시스템

    사용법:
        1. setup(guards_top, guards_bottom) 으로 호위무사 할당
        2. 매 프레임 update(dt, top_paddle, bottom_paddle, ball) 호출
        3. 매 프레임 draw(screen, ...) 호출
        4. 배틀 종료 시 reset() 호출
    """

    def __init__(self, skill_manager=None, hero_paddle_renderer=None):
        self.skill_manager = skill_manager
        self.hero_paddle_renderer = hero_paddle_renderer

        # 호위무사 목록
        self.guard_warriors_top = []       # 상단 영웅의 호위무사들 [hero_dict, ...]
        self.guard_warriors_bottom = []    # 하단 영웅의 호위무사들

        # 쿨타임
        self.cooldown_top = 0.0
        self.cooldown_bottom = 0.0
        self.cooldown_max_top = 30.0       # 현재 쿨타임 최대값 (게이지 표시용)
        self.cooldown_max_bottom = 30.0
        self.cooldown_range = (20.0, 30.0)  # 스킬 없을 때 폴백용
        self.GUARD_CD_PENALTY = 1.2        # 호위무사 스킬 쿨타임 +20% 페널티

        # 퍽 멀티플라이어 (호위무사 쿨타임 감소)
        self.guard_cd_mult_top = 1.0
        self.guard_cd_mult_bottom = 1.0

        # 다음 등장할 호위무사 인덱스 (2명일 때 화살표 표시용)
        self.next_guard_top_idx = 0
        self.next_guard_bottom_idx = 0

        # 등장 애니메이션 상태 (상단측)
        self.active_top = None             # 현재 등장 중인 호위무사 hero dict
        self.phase_top = None              # "entering" / "casting" / "exiting" / None
        self.anim_timer_top = 0.0
        self.x_top = 0.0                   # 현재 X 위치
        self.side_top = "left"             # 등장 방향
        self.selected_skill_top = None     # 선택된 스킬 인스턴스

        # 등장 애니메이션 상태 (하단측)
        self.active_bottom = None
        self.phase_bottom = None
        self.anim_timer_bottom = 0.0
        self.x_bottom = 0.0
        self.side_bottom = "right"
        self.selected_skill_bottom = None

        # 독립 스킬 인스턴스 (메인 스킬과 충돌 방지)
        self.skill_instances = {}          # hero_id -> [skill1, skill2]
        self.skill_selections = {}         # hero_id -> selected_skill_index (0 or 1)

        # 호위무사별 마지막 가상 패들 (스킬 이펙트 진행 중 위치 유지용)
        self.guard_paddles = {}            # hero_id -> _GuardPaddle

        # Y 위치 추적 (horn_charge 등에서 Y 이동 필요)
        self.y_top = TOP_PADDLE_Y              # 상단 호위무사 현재 Y (영웅 패들과 동일)
        self.y_bottom = BOTTOM_PADDLE_Y        # 하단 호위무사 현재 Y (영웅 패들과 동일)
        self._enter_x_top = 0.0      # 등장 완료 시 X 위치 (horn_charge 기준점)
        self._enter_x_bottom = 0.0
        self._exit_start_x_top = 0.0  # 퇴장 시작 시 X 위치
        self._exit_start_y_top = float(TOP_PADDLE_Y)
        self._exit_start_x_bottom = 0.0
        self._exit_start_y_bottom = float(BOTTOM_PADDLE_Y)

        # 호위무사 귀신발걸음 공 충돌 (1회 발동당 3회까지 허용)
        self._guard_ghost_step_hit_top = 0       # 상단 호위무사 이번 발동 충돌 횟수
        self._guard_ghost_step_hit_bottom = 0    # 하단 호위무사 이번 발동 충돌 횟수
        self._guard_ghost_step_max_hits = 3      # 최대 충돌 횟수
        self._guard_ball_cooldown = 0.0          # 연속 충돌 방지 쿨다운

        # 호위무사 말풍선 시스템
        self._bubble_top = None    # {'text': str, 'timer': float}
        self._bubble_bottom = None
        self._bubble_duration = 2.0  # 말풍선 표시 시간 (초)

        # 2번째 호위무사 독립 순찰 (재소집령 등으로 2명일 때)
        # 구조: _charmed 와 동일 - {'guard': hero_dict, 'x': float, 'y': float, ...}
        self._patrol2_top = None
        self._patrol2_bottom = None

        # 순찰 모드: 호위무사가 진영에 상주하며 순찰 (기본 동작)
        self.patrol_mode_top = False
        self.patrol_mode_bottom = False
        self._patrol_dir_top = 1     # 순찰 이동 방향 (1: 오른쪽, -1: 왼쪽)
        self._patrol_dir_bottom = -1
        self._patrol_speed = 140.0   # 순찰 이동 속도 (px/s)
        # 자연스러운 순찰 AI: 목표 지점 + 대기 시간
        self._patrol_target_top = None      # 현재 목표 X 좌표
        self._patrol_target_bottom = None
        self._patrol_wait_top = 0.0         # 잠시 멈춤 타이머 (초)
        self._patrol_wait_bottom = 0.0
        self._patrol_speed_top = 140.0      # 개별 속도 (랜덤 변동)
        self._patrol_speed_bottom = 140.0

        # 매혹(Charm)된 호위무사 독립 추적
        self._charmed = None  # dict or None

    def setup(self, guards_top, guards_bottom, initial_delay=(10.0, 15.0), skill_selections=None):
        """배틀 시작 시 호위무사 설정

        Args:
            guards_top: 상단 영웅의 호위무사 목록
            guards_bottom: 하단 영웅의 호위무사 목록
            initial_delay: 첫 등장까지의 대기 시간 범위 (초)
            skill_selections: {hero_id: skill_index} 스킬 선택 정보 (0 or 1)
        """
        self.guard_warriors_top = list(guards_top) if guards_top else []
        self.guard_warriors_bottom = list(guards_bottom) if guards_bottom else []
        self.skill_selections = skill_selections or {}

        # 다음 호위무사 인덱스 설정
        if self.guard_warriors_top:
            self.next_guard_top_idx = random.randint(0, len(self.guard_warriors_top) - 1)
        if self.guard_warriors_bottom:
            self.next_guard_bottom_idx = random.randint(0, len(self.guard_warriors_bottom) - 1)

        # 애니메이션 상태 초기화
        self.active_top = None
        self.active_bottom = None
        self.phase_top = None
        self.phase_bottom = None
        self.y_top = TOP_PADDLE_Y
        self.y_bottom = BOTTOM_PADDLE_Y

        # 호위무사 스킬 인스턴스 생성 (쿨타임 계산 전에 먼저 생성해야 함)
        self._init_guard_skills()

        # 쿨타임 초기화: 첫 등장 호위무사의 스킬 쿨타임 * 1.2 기반
        if self.guard_warriors_top:
            first_guard = self.guard_warriors_top[self.next_guard_top_idx % len(self.guard_warriors_top)]
            initial_cd = self._get_guard_cooldown(first_guard["id"])
            self.cooldown_top = initial_cd
            self.cooldown_max_top = initial_cd
        if self.guard_warriors_bottom:
            first_guard = self.guard_warriors_bottom[self.next_guard_bottom_idx % len(self.guard_warriors_bottom)]
            initial_cd = self._get_guard_cooldown(first_guard["id"])
            self.cooldown_bottom = initial_cd
            self.cooldown_max_bottom = initial_cd

        # 호위무사가 있으면 기본적으로 순찰 모드 활성화
        if self.guard_warriors_top:
            self.patrol_mode_top = True
        if self.guard_warriors_bottom:
            self.patrol_mode_bottom = True

        # 2번째 호위무사 초기화 (2명 이상일 때)
        self._patrol2_top = None
        self._patrol2_bottom = None

        guard_names_top = [g["name"] for g in self.guard_warriors_top]
        guard_names_bottom = [g["name"] for g in self.guard_warriors_bottom]
        print(f"[Guard] 호위무사 설정 완료 | 상단: {guard_names_top} | 하단: {guard_names_bottom}")

    # 순찰 모드 첫 등장 딜레이 (공 생성 애니메이션 후 2초)
    PATROL_ENTRY_DELAY = 2.0

    def activate_patrol_immediate(self):
        """호위무사 순찰 모드 시작 - 짧은 딜레이 후 입장 애니메이션으로 등장
        - 공 생성 애니메이션 후 2초 뒤 좌/우에서 걸어 들어옴
        - 입장 완료 후 바로 순찰 모드 진입 (시전 단계 없이)
        - 2명 이상이면 2번째 호위무사도 독립 순찰로 동시 등장
        """
        if self.patrol_mode_top and self.guard_warriors_top:
            idx = self.next_guard_top_idx % len(self.guard_warriors_top)
            guard = self.guard_warriors_top[idx]
            self.active_top = guard
            # "patrol_entering" 단계: 딜레이 대기 → 입장 애니메이션 → 순찰
            self.phase_top = "patrol_entering"
            self.anim_timer_top = 0.0
            self.side_top = random.choice(["left", "right"])
            start_x = (GAME_AREA_X - 60) if self.side_top == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)
            self.x_top = start_x
            self.y_top = TOP_PADDLE_Y
            # 첫 스킬 쿨타임 설정
            cd_mult = self.guard_cd_mult_top
            base_cd = self._get_guard_cooldown(guard["id"])
            self.cooldown_top = base_cd * cd_mult + self.PATROL_ENTRY_DELAY + GUARD_ENTER_DURATION
            self.cooldown_max_top = self.cooldown_top
            # 다음 호위무사 인덱스 갱신
            if len(self.guard_warriors_top) > 1:
                self.next_guard_top_idx = random.randint(0, len(self.guard_warriors_top) - 1)
            print(f"[Guard] 상단측 호위무사 {guard['name']} 순찰 등장 예약! ({self.PATROL_ENTRY_DELAY}초 후 입장)")

            # 2번째 호위무사 동시 등장 (2명 이상일 때)
            if len(self.guard_warriors_top) > 1:
                self._activate_patrol2(is_top=True, exclude_guard=guard)

        if self.patrol_mode_bottom and self.guard_warriors_bottom:
            idx = self.next_guard_bottom_idx % len(self.guard_warriors_bottom)
            guard = self.guard_warriors_bottom[idx]
            self.active_bottom = guard
            self.phase_bottom = "patrol_entering"
            self.anim_timer_bottom = 0.0
            self.side_bottom = random.choice(["left", "right"])
            start_x = (GAME_AREA_X - 60) if self.side_bottom == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)
            self.x_bottom = start_x
            self.y_bottom = BOTTOM_PADDLE_Y
            # 첫 스킬 쿨타임 설정
            cd_mult = self.guard_cd_mult_bottom
            base_cd = self._get_guard_cooldown(guard["id"])
            self.cooldown_bottom = base_cd * cd_mult + self.PATROL_ENTRY_DELAY + GUARD_ENTER_DURATION
            self.cooldown_max_bottom = self.cooldown_bottom
            if len(self.guard_warriors_bottom) > 1:
                self.next_guard_bottom_idx = random.randint(0, len(self.guard_warriors_bottom) - 1)
            print(f"[Guard] 하단측 호위무사 {guard['name']} 순찰 등장 예약! ({self.PATROL_ENTRY_DELAY}초 후 입장)")

            # 2번째 호위무사 동시 등장 (2명 이상일 때)
            if len(self.guard_warriors_bottom) > 1:
                self._activate_patrol2(is_top=False, exclude_guard=guard)

    def _init_guard_skills(self):
        """호위무사 전용 스킬 인스턴스 생성 (메인 스킬과 독립, 스킬 선택 반영)"""
        self.skill_instances = {}
        all_guards = self.guard_warriors_top + self.guard_warriors_bottom
        for guard_hero in all_guards:
            hero_id = guard_hero["id"]
            if hero_id not in self.skill_instances:
                try:
                    from downtown.hero_skills import HERO_SKILL_CLASSES
                    skill_classes = HERO_SKILL_CLASSES.get(hero_id, [])
                    selected_idx = self.skill_selections.get(hero_id, -1)
                    skills = []
                    for i, cls in enumerate(skill_classes):
                        # 스킬 선택 정보가 있으면 해당 스킬만 생성
                        if selected_idx >= 0 and i != selected_idx:
                            continue
                        skills.append(cls())
                    # game_state 연결 (메인 스킬 매니저와 공유)
                    game_state = self.skill_manager.game_state if self.skill_manager else {}
                    for skill in skills:
                        skill.game_state = game_state
                    self.skill_instances[hero_id] = skills
                    print(f"[Guard] {guard_hero['name']}({hero_id}) 스킬 인스턴스 생성: {[s.korean_name for s in skills]}")
                except Exception as e:
                    print(f"[Guard] 스킬 인스턴스 생성 실패 ({hero_id}): {e}")
                    self.skill_instances[hero_id] = []

    def _cleanup_all_active_skills(self):
        """모든 활성 스킬의 _end_effect 호출 후 비활성화 (game_state 키 잔류 방지)"""
        gs = self.skill_manager.game_state if self.skill_manager else {}
        for hero_id, skills in self.skill_instances.items():
            for skill in skills:
                if skill.is_active:
                    try:
                        skill._end_effect(None, None, None, gs)
                    except Exception:
                        pass
                    skill.is_active = False

    def unlock_extra_skills(self, is_top=None):
        """추가훈련 퍽: 호위무사의 두 번째 스킬도 해금 (2개 모두 사용 가능)

        Args:
            is_top: True=상단측만, False=하단측만, None=양쪽 모두
        """
        from downtown.hero_skills import HERO_SKILL_CLASSES
        game_state = self.skill_manager.game_state if self.skill_manager else {}

        target_guards = []
        if is_top is None or is_top is True:
            target_guards.extend(self.guard_warriors_top)
        if is_top is None or is_top is False:
            target_guards.extend(self.guard_warriors_bottom)

        for guard_hero in target_guards:
            hero_id = guard_hero["id"]
            current_skills = self.skill_instances.get(hero_id, [])
            skill_classes = HERO_SKILL_CLASSES.get(hero_id, [])
            # 이미 2개 이상이면 스킵
            if len(current_skills) >= len(skill_classes):
                continue
            # 현재 가진 스킬의 클래스 확인
            current_cls_names = {type(s).__name__ for s in current_skills}
            for cls in skill_classes:
                if cls.__name__ not in current_cls_names:
                    new_skill = cls()
                    new_skill.game_state = game_state
                    current_skills.append(new_skill)
                    print(f"[Guard] 추가훈련 퍽: {guard_hero['name']}({hero_id}) "
                          f"스킬 해금 → {new_skill.korean_name}")
            self.skill_instances[hero_id] = current_skills

    def _get_guard_cooldown(self, guard_id):
        """호위무사의 쿨타임 계산: 배정된 스킬 쿨타임 * 1.2 (20% 페널티)"""
        skills = self.skill_instances.get(guard_id, [])
        if skills:
            return skills[0].cooldown * self.GUARD_CD_PENALTY
        return random.uniform(*self.cooldown_range)

    # === 매혹 (Charm) 스킬 지원 (독립 추적 시스템) ===
    # 매혹된 호위무사는 기존 guard_warriors 리스트에 넣지 않고
    # self._charmed 딕셔너리로 완전 독립 관리한다.
    # → 기존 호위무사와 동시 필드 존재 가능
    # → 쿨타임 이어받기, 복귀 시 정상 반환

    def _handle_charm_requests(self, game_state):
        """매혹 4단계 페이즈 처리"""
        self._provide_enemy_guard_info(game_state)

        # 매혹 호위무사 위치 추적
        if self._charmed:
            game_state['_charmed_guard_pos'] = {
                'x': self._charmed['x'], 'y': self._charmed['y']
            }
            game_state['_charmed_guard'] = self._charmed['guard']

        # 레거시 호환
        charm_end = game_state.pop('charm_end_request', None)
        if charm_end:
            self._charm_return_to_enemy(game_state)

        phase_req = game_state.pop('charm_phase_request', None)
        if not phase_req:
            return

        caster_is_top = phase_req['caster_is_top']
        phase = phase_req['phase']

        if phase == 'projectile':
            print(f"[Charm] 자력 에너지 발사! 대상: {'하단' if caster_is_top else '상단'} 호위무사")

        elif phase == 'pulling':
            self._charm_steal_guard(game_state, caster_is_top)

        elif phase == 'active':
            self._charm_activate_guard(game_state, caster_is_top)

        elif phase == 'returning':
            self._charm_start_return(game_state, caster_is_top)

        elif phase == 'returned':
            return_x = phase_req.get('return_x', 380)
            self._charm_return_to_enemy(game_state, return_x)

    def _provide_enemy_guard_info(self, game_state):
        """양쪽 호위무사의 현재 좌표를 game_state에 제공"""
        if self.active_bottom and self.phase_bottom:
            game_state['_guard_info_bottom'] = {
                'x': self.x_bottom, 'y': self.y_bottom,
                'id': self.active_bottom.get('id')}
        elif self.guard_warriors_bottom:
            game_state['_guard_info_bottom'] = {'x': 380, 'y': BOTTOM_PADDLE_Y}
        if self.active_top and self.phase_top:
            game_state['_guard_info_top'] = {
                'x': self.x_top, 'y': self.y_top,
                'id': self.active_top.get('id')}
        elif self.guard_warriors_top:
            game_state['_guard_info_top'] = {'x': 380, 'y': TOP_PADDLE_Y}

    def _charm_steal_guard(self, game_state, caster_is_top):
        """Phase 'pulling': 상대 호위무사를 숨기고 견인 시작 (리스트에서 제거하지 않음!)"""
        if caster_is_top:
            enemy_guards = self.guard_warriors_bottom
        else:
            enemy_guards = self.guard_warriors_top

        if not enemy_guards:
            print("[Charm] 매혹 실패 - 상대에게 호위무사가 없음")
            return

        # 현재 화면에 보이는 활성 호위무사를 빼앗음
        stolen = None
        saved_cooldown = 5.0
        saved_cooldown_max = 5.0
        if caster_is_top and self.active_bottom:
            for g in enemy_guards:
                if g.get("id") == self.active_bottom.get("id"):
                    stolen = g
                    saved_cooldown = max(0, self.cooldown_bottom)
                    saved_cooldown_max = self.cooldown_max_bottom
                    break
        elif not caster_is_top and self.active_top:
            for g in enemy_guards:
                if g.get("id") == self.active_top.get("id"):
                    stolen = g
                    saved_cooldown = max(0, self.cooldown_top)
                    saved_cooldown_max = self.cooldown_max_top
                    break

        if not stolen:
            stolen = enemy_guards[0]
            saved_cooldown = 5.0
            saved_cooldown_max = 5.0

        # 상대측 활성 호위무사 숨기기 (리스트에서 제거 X, 화면에서만 숨김)
        if caster_is_top:
            if self.active_bottom and self.active_bottom.get("id") == stolen.get("id"):
                self.active_bottom = None
                self.phase_bottom = None
                self.anim_timer_bottom = 0.0
        else:
            if self.active_top and self.active_top.get("id") == stolen.get("id"):
                self.active_top = None
                self.phase_top = None
                self.anim_timer_top = 0.0

        # 독립 추적 딕셔너리 생성
        self._charmed = {
            'guard': stolen,
            'caster_is_top': caster_is_top,
            'stolen_from_top': not caster_is_top,
            'x': 380.0,
            'y': TOP_PADDLE_Y if caster_is_top else BOTTOM_PADDLE_Y,
            'phase': 'pulling',  # pulling → patrolling → done
            'cooldown': saved_cooldown,  # 쿨타임 이어받기!
            'cooldown_max': saved_cooldown_max,  # 원본 최대 쿨타임 유지 (UI 바 정확도)
            'patrol_target': None,
            'patrol_wait': 0.0,
            'patrol_speed': 140.0,
            'skill': None,
        }

        game_state['_charmed_guard'] = stolen
        game_state['_charm_caster_is_top'] = caster_is_top
        print(f"[Charm] 견인 시작! {stolen['name']}을(를) 빼앗음 (쿨타임 {saved_cooldown:.1f}초 이어받기)")

    def _charm_activate_guard(self, game_state, caster_is_top):
        """Phase 'active': 견인 완료, 매혹 호위무사 독립 순찰 시작"""
        if not self._charmed:
            return

        guard = self._charmed['guard']

        # 순찰 위치 설정 (시전자 진영)
        if caster_is_top:
            self._charmed['y'] = TOP_PADDLE_Y
        else:
            self._charmed['y'] = BOTTOM_PADDLE_Y
        self._charmed['x'] = random.uniform(GAME_AREA_X + 80, GAME_AREA_X + GAME_AREA_WIDTH - 80)
        self._charmed['phase'] = 'patrolling'

        # 매혹 호위무사 스킬 인스턴스만 리셋 (다른 호위무사 활성 스킬 보호)
        guard_id = guard["id"]
        try:
            gs = self.skill_manager.game_state if self.skill_manager else {}
            # ★ 기존 스킬 인스턴스 정리 (game_state 키 잔류 방지)
            old_skills = self.skill_instances.get(guard_id, [])
            for old_skill in old_skills:
                if old_skill.is_active:
                    try:
                        old_skill._end_effect(None, None, None, gs)
                    except Exception:
                        pass
                    old_skill.is_active = False

            from downtown.hero_skills import HERO_SKILL_CLASSES
            skill_classes = HERO_SKILL_CLASSES.get(guard_id, [])
            selected_idx = self.skill_selections.get(guard_id, -1)
            new_skills = []
            for i, cls in enumerate(skill_classes):
                if selected_idx >= 0 and i != selected_idx:
                    continue
                new_skills.append(cls())
            for sk in new_skills:
                sk.game_state = gs
            self.skill_instances[guard_id] = new_skills
        except Exception as e:
            print(f"[Charm] 매혹 스킬 인스턴스 재생성 실패: {e}")

        skills = self.skill_instances.get(guard_id, [])
        if skills:
            self._charmed['skill'] = random.choice(skills)
        print(f"[Charm] 매혹 활성! {guard['name']}이(가) {'상단' if caster_is_top else '하단'}에서 독립 순찰 시작")

    def _charm_start_return(self, game_state, caster_is_top):
        """Phase 'returning': 매혹 해제, 복귀 애니메이션 시작"""
        if not self._charmed:
            return
        # 귀신발걸음 활성 중이면 스킬 정리
        c = self._charmed
        if c.get('ghost_step_active'):
            c['ghost_step_active'] = False
            c['y'] = c.get('ghost_step_base_y', c['y'])
            skill = c.get('skill')
            if skill and getattr(skill, 'skill_id', '') == 'demon_step':
                skill.is_active = False
                if hasattr(skill, 'aura_particles'):
                    skill.aura_particles = []
        self._charmed['phase'] = 'returning'
        print(f"[Charm] 매혹 해제! {self._charmed['guard']['name']} 복귀 중...")

    def _charm_return_to_enemy(self, game_state, return_x=380):
        """매혹 완전 종료: 상대 진영에 호위무사를 복귀 위치 그대로 배치 (재등장 없음)"""
        if not self._charmed:
            return

        guard = self._charmed['guard']
        stolen_from_top = self._charmed['stolen_from_top']

        # ★ 남은 쿨타임 보존 (초기화 전에 저장!)
        remaining_cooldown = max(0, self._charmed.get('cooldown', 0))
        remaining_cooldown_max = self._charmed.get('cooldown_max', 0)

        # ★ 독립 추적 먼저 해제
        self._charmed = None
        game_state.pop('_charmed_guard', None)
        game_state.pop('_charm_caster_is_top', None)
        game_state.pop('_charmed_guard_pos', None)
        game_state.pop('charm_active', None)

        # 복귀 위치 X 클램핑
        return_x = max(GAME_AREA_X + 40, min(return_x, GAME_AREA_X + GAME_AREA_WIDTH - 40))

        # 상대 호위무사를 복귀 위치에서 바로 순찰 상태로 배치 (사라짐/재등장 없이)
        if stolen_from_top:
            self.patrol_mode_top = True
            if not self.active_top or self.phase_top is None:
                self.active_top = guard
                self.phase_top = "patrolling"
                self.anim_timer_top = 0.0
                self.x_top = return_x
                self.y_top = TOP_PADDLE_Y
                # 쿨타임 이어받기 (매혹 중 남은 쿨타임 유지, 초기화 없음)
                self.cooldown_top = remaining_cooldown
                if remaining_cooldown_max > 0:
                    self.cooldown_max_top = remaining_cooldown_max
                else:
                    self.cooldown_max_top = self._get_guard_cooldown(guard["id"]) * self.guard_cd_mult_top
                # 순찰 인덱스 업데이트
                for i, g in enumerate(self.guard_warriors_top):
                    if g.get("id") == guard.get("id"):
                        self.next_guard_top_idx = (i + 1) % len(self.guard_warriors_top)
                        break
        else:
            self.patrol_mode_bottom = True
            if not self.active_bottom or self.phase_bottom is None:
                self.active_bottom = guard
                self.phase_bottom = "patrolling"
                self.anim_timer_bottom = 0.0
                self.x_bottom = return_x
                self.y_bottom = BOTTOM_PADDLE_Y
                # 쿨타임 이어받기 (매혹 중 남은 쿨타임 유지, 초기화 없음)
                self.cooldown_bottom = remaining_cooldown
                if remaining_cooldown_max > 0:
                    self.cooldown_max_bottom = remaining_cooldown_max
                else:
                    self.cooldown_max_bottom = self._get_guard_cooldown(guard["id"]) * self.guard_cd_mult_bottom
                # 순찰 인덱스 업데이트
                for i, g in enumerate(self.guard_warriors_bottom):
                    if g.get("id") == guard.get("id"):
                        self.next_guard_bottom_idx = (i + 1) % len(self.guard_warriors_bottom)
                        break

        print(f"[Charm] 매혹 종료! {guard['name']} 원래 진영으로 완전 복귀 (x={return_x:.0f})")
        # ★ 활성 스킬 정리 후 재생성 (game_state 키 잔류 방지)
        self._cleanup_all_active_skills()
        self._init_guard_skills()

    def _update_charmed_guard(self, dt, top_paddle, bottom_paddle, ball):
        """매혹된 호위무사 독립 업데이트 (순찰 + 스킬 시전)"""
        if not self._charmed or self._charmed['phase'] != 'patrolling':
            return

        c = self._charmed
        left_bound = GAME_AREA_X + 40
        right_bound = GAME_AREA_X + GAME_AREA_WIDTH - 40

        # === 귀신발걸음 Y축 이동 처리 (일반 순찰 대신) ===
        if c.get('ghost_step_active'):
            DEMON_STEP_CHARMED_DURATION = 4.0
            FORWARD_DURATION = DEMON_STEP_CHARMED_DURATION / 2  # 2초 전진
            c['ghost_step_timer'] += dt
            timer = c['ghost_step_timer']

            caster_is_top = c['caster_is_top']
            base_y = c['ghost_step_base_y']
            # 상대 진영 끝까지 이동 (상단→화면 하단 700, 하단→화면 상단 50)
            dest_y = 700 if caster_is_top else 50

            # X축: 공을 따라감
            if ball:
                bx = max(GAME_AREA_X + 30, min(ball.x, GAME_AREA_X + GAME_AREA_WIDTH - 30))
                c['x'] = bx

            # Y축: 전진(0~2초) → 복귀(2~4초)
            if timer < FORWARD_DURATION:
                progress = timer / FORWARD_DURATION
                eased = self._ease_in_out(progress)
                c['y'] = base_y + (dest_y - base_y) * eased
            else:
                progress = min(1.0, (timer - FORWARD_DURATION) / (DEMON_STEP_CHARMED_DURATION - FORWARD_DURATION))
                eased = self._ease_in_out(progress)
                c['y'] = dest_y + (base_y - dest_y) * eased

            # 4초 후 강제 종료
            if timer >= DEMON_STEP_CHARMED_DURATION:
                c['ghost_step_active'] = False
                c['ghost_step_timer'] = 0.0
                c['ghost_step_hit_count'] = 0
                # 스킬 비활성화
                skill = c.get('skill')
                if skill and getattr(skill, 'skill_id', '') == 'demon_step':
                    skill.is_active = False
                    if hasattr(skill, 'aura_particles'):
                        skill.aura_particles = []
                # Y좌표 복원
                c['y'] = base_y
                print(f"[Charm] 매혹 호위무사 귀신발걸음 종료, 순찰 복귀")

            # 이동 애니메이션
            guard = c['guard']
            if guard and self.hero_paddle_renderer:
                self.hero_paddle_renderer.update_movement(guard["id"], c['x'], dt)

            # 쿨타임 감소는 귀신발걸음 중에도 계속
            c['cooldown'] -= dt
            return  # 귀신발걸음 중에는 순찰 이동 스킵

        # 순찰 이동 (기존 호위무사와 동일한 패턴)
        if c['patrol_wait'] > 0:
            c['patrol_wait'] -= dt
        else:
            if c['patrol_target'] is None:
                c['patrol_target'] = random.uniform(left_bound + 20, right_bound - 20)
                c['patrol_speed'] = random.uniform(110.0, 180.0)

            diff = c['patrol_target'] - c['x']
            if abs(diff) < 3.0:
                c['x'] = c['patrol_target']
                c['patrol_target'] = None
                c['patrol_wait'] = random.uniform(0.4, 1.5)
            else:
                direction = 1 if diff > 0 else -1
                c['x'] += direction * c['patrol_speed'] * dt
                c['x'] = max(left_bound, min(c['x'], right_bound))

        # 이동 애니메이션
        guard = c['guard']
        if guard and self.hero_paddle_renderer:
            self.hero_paddle_renderer.update_movement(guard["id"], c['x'], dt)

        # 쿨타임 감소 → 스킬 시전
        c['cooldown'] -= dt
        if c['cooldown'] <= 0:
            self._charmed_trigger_skill(top_paddle, bottom_paddle, ball)

    def _charmed_trigger_skill(self, top_paddle, bottom_paddle, ball):
        """매혹된 호위무사가 상대를 향해 스킬 사용"""
        if not self._charmed:
            return

        c = self._charmed
        guard = c['guard']
        caster_is_top = c['caster_is_top']

        # 스킬 선택
        skills = self.skill_instances.get(guard["id"], [])
        if not skills:
            c['cooldown'] = 8.0
            return
        skill = random.choice(skills)
        c['skill'] = skill

        # ★ 쿨타임을 먼저 설정 (예외 발생 시에도 매 프레임 재발동 방지)
        cd_mult = self.guard_cd_mult_top if caster_is_top else self.guard_cd_mult_bottom
        base_cd = self._get_guard_cooldown(guard["id"])
        c['cooldown'] = base_cd * cd_mult
        c['cooldown_max'] = c['cooldown']

        try:
            game_state = self.skill_manager.game_state if self.skill_manager else {}

            # 매혹 호위무사 위치의 가상 패들을 caster로 사용
            gp = _GuardPaddle(c['x'], c['y'], caster_is_top)
            gp.x = int(c['x']) - gp.width // 2
            gp.centerx = int(c['x'])
            gp.y = int(c['y'])
            gp.centery = int(c['y']) + gp.height // 2
            self.guard_paddles[guard["id"]] = gp  # 스킬 이펙트 진행 중 위치 유지
            guard_paddle = gp

            # 매혹 호위무사가 caster 편으로 싸우므로, caster의 상대를 타겟으로
            target_paddle = bottom_paddle if caster_is_top else top_paddle

            skill.caster_is_top = caster_is_top
            skill.current_cooldown = 0
            if skill.is_active:
                try:
                    skill._end_effect(guard_paddle, target_paddle, ball, game_state)
                except Exception:
                    pass
                skill.is_active = False

            caster_prefix = 'top_paddle' if caster_is_top else 'bottom_paddle'
            saved = self._save_caster_state(game_state, caster_prefix)
            result = skill.use(guard_paddle, target_paddle, ball, game_state)
            self._restore_caster_state(game_state, caster_prefix, saved)

            # duration=0 스킬 (OilSpill 등)은 use()에서 is_active가 안 켜짐 → 수동 활성화
            if result and not skill.is_active and skill.duration <= 0:
                skill.is_active = True

            if result:
                # 사운드 재생 + 상태 효과 적용 (_activate_skill과 동일)
                self._play_skill_sound(result)
                self._apply_status_effects(result, target_paddle)

                # 스킬별 글로벌 game_state 키 차단 (메인 영웅에 영향 방지)
                skill_id = getattr(skill, 'skill_id', '')
                if skill_id == 'horn_charge':
                    game_state['horn_charge_active'] = False
                elif skill_id == 'demon_step':
                    game_state['demon_eye_active'] = False
                    game_state.pop('ghost_step_start_top', None)
                    game_state.pop('ghost_step_start_bottom', None)
                    # 매혹 가드 귀신발걸음 독립 트래킹 시작
                    c['ghost_step_active'] = True
                    c['ghost_step_timer'] = 0.0
                    c['ghost_step_base_y'] = c['y']
                    c['ghost_step_hit_count'] = 0
                elif skill_id == 'steam_barrier':
                    # 호위무사가 시전한 배리어 → 메인 패들 정지 방지
                    game_state['steam_barrier_caster_frozen'] = False
                    game_state['steam_barrier_thaw_speed'] = 0.0

                # 말풍선 표시
                bubble_text = f"{skill.korean_name}!"
                bubble_color = guard.get("color") or (200, 200, 200)
                # color가 튜플/리스트가 아닐 경우 안전하게 기본값 사용
                if not isinstance(bubble_color, (tuple, list)) or len(bubble_color) < 3:
                    bubble_color = (200, 200, 200)
                if caster_is_top:
                    self._bubble_top = {'text': bubble_text, 'timer': self._bubble_duration,
                                        'x': c['x'], 'y': c['y'], 'color': bubble_color}
                else:
                    self._bubble_bottom = {'text': bubble_text, 'timer': self._bubble_duration,
                                           'x': c['x'], 'y': c['y'], 'color': bubble_color}

                print(f"[Charm] 매혹 호위무사 {guard['name']} → {skill.korean_name} 발동!")
            else:
                print(f"[Charm] 매혹 호위무사 {guard['name']} → {skill.korean_name} 발동 실패")
        except Exception as e:
            print(f"[Charm] 매혹 호위무사 스킬 발동 중 오류: {e}")
            import traceback
            traceback.print_exc()

    def _draw_charmed_guard(self, screen, shake_x, shake_y):
        """매혹된 호위무사 독립 렌더링"""
        if not self._charmed:
            return
        c = self._charmed
        if c['phase'] not in ('patrolling',):
            return  # pulling/returning은 Charm 스킬의 draw에서 처리
        self._draw_guard(screen, c['guard'],
                         c['x'] + shake_x, c['y'] + shake_y,
                         is_top=c['caster_is_top'])

    # === 2번째 호위무사 독립 순찰 시스템 (재소집령 등) ===

    def _activate_patrol2(self, is_top, exclude_guard=None):
        """2번째 호위무사를 독립 순찰로 활성화

        Args:
            is_top: True=상단측, False=하단측
            exclude_guard: 1번 호위무사 (중복 방지)
        """
        guards = self.guard_warriors_top if is_top else self.guard_warriors_bottom
        if len(guards) < 2:
            return

        # exclude_guard와 다른 호위무사 선택
        exclude_id = exclude_guard["id"] if exclude_guard else None
        guard2 = None
        for g in guards:
            if g["id"] != exclude_id:
                guard2 = g
                break
        if not guard2:
            return

        # 스킬 선택
        skills = self.skill_instances.get(guard2["id"], [])
        skill = random.choice(skills) if skills else None

        # 쿨타임 설정
        cd_mult = self.guard_cd_mult_top if is_top else self.guard_cd_mult_bottom
        base_cd = self._get_guard_cooldown(guard2["id"])
        initial_cd = base_cd * cd_mult + self.PATROL_ENTRY_DELAY + GUARD_ENTER_DURATION + random.uniform(3.0, 6.0)

        # 반대편에서 등장 (1번 호위무사와 반대 방향)
        side1 = self.side_top if is_top else self.side_bottom
        side2 = "right" if side1 == "left" else "left"
        start_x = (GAME_AREA_X - 60) if side2 == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)

        p2 = {
            'guard': guard2,
            'is_top': is_top,
            'x': float(start_x),
            'y': float(TOP_PADDLE_Y if is_top else BOTTOM_PADDLE_Y),
            'phase': 'patrol_entering',  # patrol_entering → entering → patrolling
            'anim_timer': 0.0,
            'side': side2,
            'cooldown': initial_cd,
            'cooldown_max': initial_cd,
            'skill': skill,
            'patrol_target': None,
            'patrol_wait': 0.0,
            'patrol_speed': random.uniform(110.0, 180.0),
        }

        if is_top:
            self._patrol2_top = p2
        else:
            self._patrol2_bottom = p2
        print(f"[Guard] {'상단' if is_top else '하단'}측 2번째 호위무사 {guard2['name']} "
              f"독립 순찰 등장 예약! ({self.PATROL_ENTRY_DELAY + random.uniform(3.0, 6.0):.1f}초 후)")

    def _update_patrol2(self, dt, is_top, top_paddle, bottom_paddle, ball):
        """2번째 호위무사 독립 업데이트 (순찰 + 스킬 시전)"""
        p2 = self._patrol2_top if is_top else self._patrol2_bottom
        if not p2:
            return

        phase = p2['phase']
        p2['anim_timer'] += dt

        # === patrol_entering: 딜레이 대기 → 입장 애니메이션 ===
        if phase == 'patrol_entering':
            p2['cooldown'] -= dt
            if p2['anim_timer'] < self.PATROL_ENTRY_DELAY:
                return  # 딜레이 대기 중

            # 입장 애니메이션
            enter_timer = p2['anim_timer'] - self.PATROL_ENTRY_DELAY
            progress = min(1.0, enter_timer / GUARD_ENTER_DURATION)
            eased = self._ease_in_out(progress)

            # 첫 프레임에서 목표 X 결정
            if '_enter_target_x' not in p2:
                p2['_enter_target_x'] = GAME_AREA_X + GAME_AREA_WIDTH // 2 + random.uniform(-80, 80)
            start_x = (GAME_AREA_X - 60) if p2['side'] == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)
            target_x = p2['_enter_target_x']
            p2['x'] = start_x + (target_x - start_x) * eased

            # 이동 애니메이션
            guard = p2['guard']
            if guard and self.hero_paddle_renderer:
                self.hero_paddle_renderer.update_movement(guard["id"], p2['x'], dt)

            if progress >= 1.0:
                p2['phase'] = 'patrolling'
                p2['anim_timer'] = 0.0
                print(f"[Guard] {'상단' if is_top else '하단'}측 2번째 호위무사 {guard['name']} 순찰 시작!")
            return

        # === patrolling: 순찰 + 쿨타임 ===
        if phase == 'patrolling':
            self._update_patrol2_movement(dt, p2)

            # 쿨타임 감소 → 스킬 시전
            p2['cooldown'] -= dt
            if p2['cooldown'] <= 0:
                self._patrol2_trigger_skill(is_top, top_paddle, bottom_paddle, ball)
            return

        # === casting: 스킬 시전 중 (지속 시간 후 순찰 복귀) ===
        if phase == 'casting':
            if p2['anim_timer'] >= GUARD_CAST_DURATION:
                p2['phase'] = 'patrolling'
                p2['anim_timer'] = 0.0
                p2['y'] = float(TOP_PADDLE_Y if is_top else BOTTOM_PADDLE_Y)

    def _update_patrol2_movement(self, dt, p2):
        """2번째 호위무사 순찰 이동 (랜덤 패턴)"""
        left_bound = GAME_AREA_X + 40
        right_bound = GAME_AREA_X + GAME_AREA_WIDTH - 40

        if p2['patrol_wait'] > 0:
            p2['patrol_wait'] -= dt
            # 대기 중 이동 애니메이션
            guard = p2['guard']
            if guard and self.hero_paddle_renderer:
                self.hero_paddle_renderer.update_movement(guard["id"], p2['x'], dt)
            return

        if p2['patrol_target'] is None:
            p2['patrol_target'] = random.uniform(left_bound + 20, right_bound - 20)
            p2['patrol_speed'] = random.uniform(110.0, 180.0)

        diff = p2['patrol_target'] - p2['x']
        if abs(diff) < 3.0:
            p2['x'] = p2['patrol_target']
            p2['patrol_target'] = None
            p2['patrol_wait'] = random.uniform(0.4, 1.5)
        else:
            direction = 1 if diff > 0 else -1
            p2['x'] += direction * p2['patrol_speed'] * dt
            p2['x'] = max(left_bound, min(p2['x'], right_bound))

        guard = p2['guard']
        if guard and self.hero_paddle_renderer:
            self.hero_paddle_renderer.update_movement(guard["id"], p2['x'], dt)

    def _patrol2_trigger_skill(self, is_top, top_paddle, bottom_paddle, ball):
        """2번째 호위무사 스킬 발동"""
        p2 = self._patrol2_top if is_top else self._patrol2_bottom
        if not p2:
            return

        guard = p2['guard']
        skills = self.skill_instances.get(guard["id"], [])
        if not skills:
            p2['cooldown'] = 8.0
            return
        skill = random.choice(skills)
        p2['skill'] = skill

        # ★ 쿨타임을 먼저 설정 (예외 발생 시에도 매 프레임 재발동 방지)
        cd_mult = self.guard_cd_mult_top if is_top else self.guard_cd_mult_bottom
        base_cd = self._get_guard_cooldown(guard["id"])
        p2['cooldown'] = base_cd * cd_mult
        p2['cooldown_max'] = p2['cooldown']

        try:
            game_state = self.skill_manager.game_state if self.skill_manager else {}

            # 가상 패들 생성
            gp = _GuardPaddle(p2['x'], p2['y'], is_top)
            gp.x = int(p2['x']) - gp.width // 2
            gp.centerx = int(p2['x'])
            gp.y = int(p2['y'])
            gp.centery = int(p2['y']) + gp.height // 2
            self.guard_paddles[guard["id"]] = gp

            target_paddle = bottom_paddle if is_top else top_paddle

            skill.caster_is_top = is_top
            skill.current_cooldown = 0
            if skill.is_active:
                try:
                    skill._end_effect(gp, target_paddle, ball, game_state)
                except Exception:
                    pass
                skill.is_active = False

            caster_prefix = 'top_paddle' if is_top else 'bottom_paddle'
            saved = self._save_caster_state(game_state, caster_prefix)
            result = skill.use(gp, target_paddle, ball, game_state)
            self._restore_caster_state(game_state, caster_prefix, saved)

            if result and not skill.is_active and skill.duration <= 0:
                skill.is_active = True

            if result:
                self._play_skill_sound(result)
                self._apply_status_effects(result, target_paddle)
                # 글로벌 game_state 키 차단 (메인 영웅에 영향 방지)
                skill_id = getattr(skill, 'skill_id', '')
                if skill_id == 'horn_charge':
                    game_state['horn_charge_active'] = False
                elif skill_id == 'demon_step':
                    game_state['demon_eye_active'] = False
                    game_state.pop('ghost_step_start_top', None)
                    game_state.pop('ghost_step_start_bottom', None)
                elif skill_id == 'steam_barrier':
                    # 호위무사가 시전한 배리어 → 메인 패들 정지 방지
                    game_state['steam_barrier_caster_frozen'] = False
                    game_state['steam_barrier_thaw_speed'] = 0.0
                # 말풍선
                bubble_text = f"{skill.korean_name}!"
                bubble_color = guard.get("color") or (200, 200, 200)
                if not isinstance(bubble_color, (tuple, list)) or len(bubble_color) < 3:
                    bubble_color = (200, 200, 200)
                if is_top:
                    self._bubble_top = {'text': bubble_text, 'timer': self._bubble_duration,
                                        'x': p2['x'], 'y': p2['y'], 'color': bubble_color}
                else:
                    self._bubble_bottom = {'text': bubble_text, 'timer': self._bubble_duration,
                                           'x': p2['x'], 'y': p2['y'], 'color': bubble_color}
                print(f"[Guard] {'상단' if is_top else '하단'}측 2번째 호위무사 {guard['name']} → {skill.korean_name} 발동!")
            else:
                print(f"[Guard] {'상단' if is_top else '하단'}측 2번째 호위무사 {guard['name']} → {skill.korean_name} 발동 실패")

            # 시전 모드 전환
            p2['phase'] = 'casting'
            p2['anim_timer'] = 0.0
        except Exception as e:
            print(f"[Guard] 2번째 호위무사 스킬 발동 중 오류: {e}")
            import traceback
            traceback.print_exc()

    def _draw_patrol2(self, screen, shake_x, shake_y):
        """2번째 호위무사 렌더링"""
        for p2 in (self._patrol2_top, self._patrol2_bottom):
            if not p2:
                continue
            phase = p2['phase']
            # patrol_entering 딜레이 중에는 미표시
            if phase == 'patrol_entering' and p2['anim_timer'] < self.PATROL_ENTRY_DELAY:
                continue
            self._draw_guard(screen, p2['guard'],
                             p2['x'] + shake_x, p2['y'] + shake_y,
                             is_top=p2['is_top'])

    def _spawn_patrol_guard(self, is_top):
        """호위무사를 즉시 순찰 등장시킴"""
        guards = self.guard_warriors_top if is_top else self.guard_warriors_bottom
        if not guards:
            return
        idx = (self.next_guard_top_idx if is_top else self.next_guard_bottom_idx) % len(guards)
        guard = guards[idx]

        # 매혹으로 빼앗긴 호위무사는 스킵
        if self._charmed and self._charmed['guard'].get("id") == guard.get("id"):
            # 다른 호위무사가 있으면 그걸로
            for i, g in enumerate(guards):
                if g.get("id") != guard.get("id"):
                    guard = g
                    idx = i
                    break
            else:
                return  # 모든 호위무사가 빼앗겨서 소환 불가

        if is_top:
            self.active_top = guard
            self.phase_top = "patrol_entering"
            self.anim_timer_top = 0.0
            self.side_top = random.choice(["left", "right"])
            start_x = (GAME_AREA_X - 60) if self.side_top == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)
            self.x_top = start_x
            self.y_top = TOP_PADDLE_Y
            cd_mult = self.guard_cd_mult_top
            base_cd = self._get_guard_cooldown(guard["id"])
            self.cooldown_top = base_cd * cd_mult + GUARD_ENTER_DURATION
            self.cooldown_max_top = self.cooldown_top
        else:
            self.active_bottom = guard
            self.phase_bottom = "patrol_entering"
            self.anim_timer_bottom = 0.0
            self.side_bottom = random.choice(["left", "right"])
            start_x = (GAME_AREA_X - 60) if self.side_bottom == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)
            self.x_bottom = start_x
            self.y_bottom = BOTTOM_PADDLE_Y
            cd_mult = self.guard_cd_mult_bottom
            base_cd = self._get_guard_cooldown(guard["id"])
            self.cooldown_bottom = base_cd * cd_mult + GUARD_ENTER_DURATION
            self.cooldown_max_bottom = self.cooldown_bottom

    def update(self, dt, top_paddle, bottom_paddle, ball):
        """매 프레임 호위무사 시스템 업데이트"""
        if not self.guard_warriors_top and not self.guard_warriors_bottom:
            # 매혹으로 호위무사가 임시 추가/견인 중인 경우에도 체크
            game_state = self.skill_manager.game_state if self.skill_manager else {}
            if not game_state.get('charm_active') and not game_state.get('_charmed_guard'):
                return

        # 말풍선 타이머 감소
        if self._bubble_top and self._bubble_top['timer'] > 0:
            self._bubble_top['timer'] -= dt
        if self._bubble_bottom and self._bubble_bottom['timer'] > 0:
            self._bubble_bottom['timer'] -= dt

        game_state = self.skill_manager.game_state if self.skill_manager else {}

        # === 호위무사 패들 위치를 game_state에 저장 (해골궁수 등 스킬에서 참조) ===
        guard_rects = []
        # 활성 호위무사 (등장/시전/퇴장/순찰 중)
        if self.phase_top is not None:
            guard_rects.append({
                'cx': self.x_top, 'cy': self.y_top,
                'width': PADDLE_WIDTH, 'height': PADDLE_HEIGHT,
                'is_top': True,
            })
        if self.phase_bottom is not None:
            guard_rects.append({
                'cx': self.x_bottom, 'cy': self.y_bottom,
                'width': PADDLE_WIDTH, 'height': PADDLE_HEIGHT,
                'is_top': False,
            })
        # 2번째 순찰 호위무사
        if self._patrol2_top:
            guard_rects.append({
                'cx': self._patrol2_top['x'], 'cy': self._patrol2_top['y'],
                'width': PADDLE_WIDTH, 'height': PADDLE_HEIGHT,
                'is_top': True,
            })
        if self._patrol2_bottom:
            guard_rects.append({
                'cx': self._patrol2_bottom['x'], 'cy': self._patrol2_bottom['y'],
                'width': PADDLE_WIDTH, 'height': PADDLE_HEIGHT,
                'is_top': False,
            })
        # 매혹된 호위무사
        if self._charmed:
            guard_rects.append({
                'cx': self._charmed['x'], 'cy': self._charmed['y'],
                'width': PADDLE_WIDTH, 'height': PADDLE_HEIGHT,
                'is_top': self._charmed.get('caster_is_top', True),
            })
        game_state['active_guard_rects'] = guard_rects

        # === 매혹 (Charm) 스킬 처리 ===
        self._handle_charm_requests(game_state)
        self._update_charmed_guard(dt, top_paddle, bottom_paddle, ball)

        # 🔥 호위무사 귀신발걸음 공 충돌 감지 (1회 발동당 3회까지)
        if self._guard_ball_cooldown > 0:
            self._guard_ball_cooldown -= dt
        if ball and self._guard_ball_cooldown <= 0:
            self._check_guard_demon_step_ball_collision(ball, game_state)
            # 일반 호위무사 패들 충돌 감지 (등장/시전/퇴장 중 공과 물리 반사)
            self._check_guard_general_ball_collision(ball, game_state)
            # 순찰 호위무사 패들 충돌 감지 (반사 - 영웅 패들과 동일한 물리)
            self._check_guard_patrol_ball_collision(ball, game_state)

        # 활성 호위무사 스킬 이펙트 업데이트 (호위무사 위치 기반)
        for hero_id, skills in self.skill_instances.items():
            # 매혹된 호위무사는 원래 진영이 아닌 caster 편으로 동작
            if self._charmed and self._charmed['guard'].get("id") == hero_id:
                is_top_guard = self._charmed['caster_is_top']
            else:
                # 이 호위무사가 어느 쪽인지 판별
                is_top_guard = any(g["id"] == hero_id for g in self.guard_warriors_top)
            # 호위무사 가상 패들 사용 (저장된 위치)
            guard_paddle = self.guard_paddles.get(hero_id)
            # 매혹 호위무사: 가상 패들 위치를 charmed 좌표로 갱신
            if self._charmed and self._charmed['guard'].get("id") == hero_id:
                if guard_paddle is None:
                    guard_paddle = _GuardPaddle(self._charmed['x'], self._charmed['y'], is_top_guard)
                    self.guard_paddles[hero_id] = guard_paddle
                guard_paddle.x = int(self._charmed['x']) - guard_paddle.width // 2
                guard_paddle.centerx = int(self._charmed['x'])
                guard_paddle.y = int(self._charmed['y'])
                guard_paddle.centery = int(self._charmed['y']) + guard_paddle.height // 2
            # 2번째 순찰 호위무사: 가상 패들 위치를 patrol2 좌표로 갱신
            elif (self._patrol2_top and self._patrol2_top['guard'].get("id") == hero_id):
                p2 = self._patrol2_top
                if guard_paddle is None:
                    guard_paddle = _GuardPaddle(p2['x'], p2['y'], True)
                    self.guard_paddles[hero_id] = guard_paddle
                guard_paddle.x = int(p2['x']) - guard_paddle.width // 2
                guard_paddle.centerx = int(p2['x'])
                guard_paddle.y = int(p2['y'])
                guard_paddle.centery = int(p2['y']) + guard_paddle.height // 2
            elif (self._patrol2_bottom and self._patrol2_bottom['guard'].get("id") == hero_id):
                p2 = self._patrol2_bottom
                if guard_paddle is None:
                    guard_paddle = _GuardPaddle(p2['x'], p2['y'], False)
                    self.guard_paddles[hero_id] = guard_paddle
                guard_paddle.x = int(p2['x']) - guard_paddle.width // 2
                guard_paddle.centerx = int(p2['x'])
                guard_paddle.y = int(p2['y'])
                guard_paddle.centery = int(p2['y']) + guard_paddle.height // 2
            elif guard_paddle is None:
                guard_paddle = top_paddle if is_top_guard else bottom_paddle
            target = bottom_paddle if is_top_guard else top_paddle
            for skill in skills:
                if skill.is_active:
                    skill_id = getattr(skill, 'skill_id', '')
                    # 드래곤 브레스: 공을 따라다니며 화염 발사
                    if skill_id == 'dragon_breath' and ball:
                        guard_paddle.x = ball.x - guard_paddle.width // 2
                        guard_paddle.centerx = ball.x
                    # 귀신발걸음 / 게틀링 버스트: 현재 호위무사 위치로 동기화 (X + Y)
                    elif skill_id in ('demon_step', 'gatling_burst'):
                        # 매혹 호위무사는 charmed 좌표 사용
                        if self._charmed and self._charmed['guard'].get("id") == hero_id:
                            gx = self._charmed['x']
                            gy = self._charmed['y']
                        elif self._patrol2_top and self._patrol2_top['guard'].get("id") == hero_id:
                            gx = self._patrol2_top['x']
                            gy = self._patrol2_top['y']
                        elif self._patrol2_bottom and self._patrol2_bottom['guard'].get("id") == hero_id:
                            gx = self._patrol2_bottom['x']
                            gy = self._patrol2_bottom['y']
                        else:
                            gx = self.x_top if is_top_guard else self.x_bottom
                            gy = self.y_top if is_top_guard else self.y_bottom
                        guard_paddle.x = gx - guard_paddle.width // 2
                        guard_paddle.centerx = gx
                        guard_paddle.y = gy
                        guard_paddle.centery = gy + guard_paddle.height // 2
                    # caster 측 game_state 보호 (호위무사 스킬이 메인 영웅에 영향 방지)
                    caster_prefix = 'top_paddle' if is_top_guard else 'bottom_paddle'
                    saved = self._save_caster_state(game_state, caster_prefix)
                    skill.update(dt, guard_paddle, target, ball, game_state)
                    self._restore_caster_state(game_state, caster_prefix, saved)
                    # 스킬별 글로벌 game_state 키 차단 (메인 영웅에 영향 방지)
                    if skill_id == 'horn_charge':
                        game_state['horn_charge_active'] = False
                    elif skill_id == 'demon_step':
                        game_state['demon_eye_active'] = False
                        game_state.pop('ghost_step_start_top', None)
                        game_state.pop('ghost_step_start_bottom', None)
                    elif skill_id == 'steam_barrier':
                        # 호위무사가 시전한 배리어 → 메인 패들 정지 방지
                        game_state['steam_barrier_caster_frozen'] = False
                        game_state['steam_barrier_thaw_speed'] = 0.0
                    # OilSpill: 발사체/웅덩이가 모두 소진되면 비활성화
                    elif skill_id == 'oil_spill':
                        if not skill.oil_projectiles and not skill.oil_puddles:
                            skill.is_active = False

        # 상단측 호위무사 업데이트
        self._update_side(dt, is_top=True, top_paddle=top_paddle,
                          bottom_paddle=bottom_paddle, ball=ball)

        # 하단측 호위무사 업데이트
        self._update_side(dt, is_top=False, top_paddle=top_paddle,
                          bottom_paddle=bottom_paddle, ball=ball)

        # 2번째 호위무사 독립 순찰 업데이트
        self._update_patrol2(dt, is_top=True, top_paddle=top_paddle,
                             bottom_paddle=bottom_paddle, ball=ball)
        self._update_patrol2(dt, is_top=False, top_paddle=top_paddle,
                             bottom_paddle=bottom_paddle, ball=ball)

    def _update_side(self, dt, is_top, top_paddle, bottom_paddle, ball):
        """한 쪽의 호위무사 업데이트"""
        guards = self.guard_warriors_top if is_top else self.guard_warriors_bottom
        if not guards:
            return

        # 현재 애니메이션 진행 중이면 애니메이션 처리
        phase = self.phase_top if is_top else self.phase_bottom

        # 순찰 첫 등장: 딜레이 대기 → 입장 → 순찰
        if phase == "patrol_entering":
            if is_top:
                self.anim_timer_top += dt
                timer = self.anim_timer_top
                self.cooldown_top -= dt
            else:
                self.anim_timer_bottom += dt
                timer = self.anim_timer_bottom
                self.cooldown_bottom -= dt

            if timer < self.PATROL_ENTRY_DELAY:
                # 아직 딜레이 대기 중 (화면에 안 보임)
                return

            # 딜레이 끝 → 입장 애니메이션 진행
            enter_timer = timer - self.PATROL_ENTRY_DELAY
            progress = min(1.0, enter_timer / GUARD_ENTER_DURATION)
            eased = self._ease_in_out(progress)

            side = self.side_top if is_top else self.side_bottom
            if side == "left":
                start_x = GAME_AREA_X - 60
                target_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
            else:
                start_x = GAME_AREA_X + GAME_AREA_WIDTH + 60
                target_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
            current_x = start_x + (target_x - start_x) * eased

            if is_top:
                self.x_top = current_x
            else:
                self.x_bottom = current_x

            # 이동 애니메이션 갱신 (걷기 모션)
            guard = self.active_top if is_top else self.active_bottom
            if guard and self.hero_paddle_renderer:
                gx = self.x_top if is_top else self.x_bottom
                self.hero_paddle_renderer.update_movement(guard["id"], gx, dt)

            if progress >= 1.0:
                # 입장 완료 → 바로 순찰 시작
                if is_top:
                    self.phase_top = "patrolling"
                    self.anim_timer_top = 0.0
                else:
                    self.phase_bottom = "patrolling"
                    self.anim_timer_bottom = 0.0
                if guard:
                    print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} 순찰 시작!")
            return

        # 순찰 모드: 진영 내 이동 + 쿨타임 동시 진행
        if phase == "patrolling":
            self._update_patrol(dt, is_top)
            # 쿨타임 감소 → 만료 시 현재 위치에서 바로 시전
            if is_top:
                self.cooldown_top -= dt
                if self.cooldown_top <= 0:
                    self._trigger_from_patrol(is_top, top_paddle, bottom_paddle, ball)
            else:
                self.cooldown_bottom -= dt
                if self.cooldown_bottom <= 0:
                    self._trigger_from_patrol(is_top, top_paddle, bottom_paddle, ball)
            return

        if phase:
            self._update_animation(dt, is_top, top_paddle, bottom_paddle, ball)
            return

        # 쿨타임 감소
        if is_top:
            self.cooldown_top -= dt
            if self.cooldown_top <= 0:
                self._trigger(is_top=True)
        else:
            self.cooldown_bottom -= dt
            if self.cooldown_bottom <= 0:
                self._trigger(is_top=False)

    def _trigger(self, is_top):
        """호위무사 등장 트리거"""
        guards = self.guard_warriors_top if is_top else self.guard_warriors_bottom
        if not guards:
            return

        # 미리 선택된 호위무사 사용 (UI 화살표로 표시된 대상)
        if is_top:
            idx = self.next_guard_top_idx % len(guards)
            guard = guards[idx]
            self.next_guard_top_idx = random.randint(0, len(guards) - 1)
        else:
            idx = self.next_guard_bottom_idx % len(guards)
            guard = guards[idx]
            self.next_guard_bottom_idx = random.randint(0, len(guards) - 1)

        # 매혹으로 빼앗긴 호위무사는 스킵
        if self._charmed and self._charmed['guard'].get("id") == guard.get("id"):
            for i, g in enumerate(guards):
                if g.get("id") != guard.get("id"):
                    guard = g
                    if is_top:
                        self.next_guard_top_idx = i
                    else:
                        self.next_guard_bottom_idx = i
                    break
            else:
                # 모든 호위무사가 매혹 중 → 쿨타임만 재설정
                cd_mult = self.guard_cd_mult_top if is_top else self.guard_cd_mult_bottom
                next_cd = random.uniform(*self.cooldown_range) * cd_mult
                if is_top:
                    self.cooldown_top = next_cd
                    self.cooldown_max_top = next_cd
                else:
                    self.cooldown_bottom = next_cd
                    self.cooldown_max_bottom = next_cd
                return

        # 스킬 2개 중 1개 랜덤 선택
        skills = self.skill_instances.get(guard["id"], [])
        if not skills:
            # 스킬이 없으면 폴백 쿨타임 설정 후 리턴 (퍽 적용)
            cd_mult = self.guard_cd_mult_top if is_top else self.guard_cd_mult_bottom
            next_cd = random.uniform(*self.cooldown_range) * cd_mult
            if is_top:
                self.cooldown_top = next_cd
                self.cooldown_max_top = next_cd
            else:
                self.cooldown_bottom = next_cd
                self.cooldown_max_bottom = next_cd
            return
        skill = random.choice(skills)

        # 등장 방향 랜덤
        side = random.choice(["left", "right"])
        start_x = (GAME_AREA_X - 60) if side == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)

        if is_top:
            self.active_top = guard
            self.phase_top = "entering"
            self.anim_timer_top = 0.0
            self.x_top = start_x
            self.side_top = side
            self.selected_skill_top = skill
        else:
            self.active_bottom = guard
            self.phase_bottom = "entering"
            self.anim_timer_bottom = 0.0
            self.x_bottom = start_x
            self.side_bottom = side
            self.selected_skill_bottom = skill

        # 다음 쿨타임 설정: 다음 호위무사의 스킬 쿨타임 * 1.2 * 퍽 보정
        cd_mult = self.guard_cd_mult_top if is_top else self.guard_cd_mult_bottom
        next_guard_idx = self.next_guard_top_idx if is_top else self.next_guard_bottom_idx
        next_guard = guards[next_guard_idx % len(guards)]
        base_cd = self._get_guard_cooldown(next_guard["id"])
        next_cd = base_cd * cd_mult
        if is_top:
            self.cooldown_top = next_cd
            self.cooldown_max_top = next_cd
        else:
            self.cooldown_bottom = next_cd
            self.cooldown_max_bottom = next_cd

        print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} 등장! "
              f"스킬: {skill.korean_name} | 방향: {side} | 다음 쿨타임: {next_cd:.1f}초")

    def _update_animation(self, dt, is_top, top_paddle, bottom_paddle, ball):
        """호위무사 등장/시전/퇴장 애니메이션"""
        if is_top:
            self.anim_timer_top += dt
            timer = self.anim_timer_top
            phase = self.phase_top
            side = self.side_top
        else:
            self.anim_timer_bottom += dt
            timer = self.anim_timer_bottom
            phase = self.phase_bottom
            side = self.side_bottom

        # 목표 좌표 계산
        if side == "left":
            target_x = GAME_AREA_X + 50
            exit_x = GAME_AREA_X - 60
            start_x = GAME_AREA_X - 60
        else:
            target_x = GAME_AREA_X + GAME_AREA_WIDTH - 50
            exit_x = GAME_AREA_X + GAME_AREA_WIDTH + 60
            start_x = GAME_AREA_X + GAME_AREA_WIDTH + 60

        if phase == "entering":
            progress = min(1.0, timer / GUARD_ENTER_DURATION)
            eased = self._ease_in_out(progress)
            current_x = start_x + (target_x - start_x) * eased

            if is_top:
                self.x_top = current_x
            else:
                self.x_bottom = current_x

            # 이동 애니메이션 갱신 (걷기 모션)
            guard = self.active_top if is_top else self.active_bottom
            if guard and self.hero_paddle_renderer:
                gx = self.x_top if is_top else self.x_bottom
                self.hero_paddle_renderer.update_movement(guard["id"], gx, dt)

            if progress >= 1.0:
                # 등장 완료 → 시전 단계 (등장 완료 X 저장)
                if is_top:
                    self.phase_top = "casting"
                    self.anim_timer_top = 0.0
                    self._enter_x_top = self.x_top
                else:
                    self.phase_bottom = "casting"
                    self.anim_timer_bottom = 0.0
                    self._enter_x_bottom = self.x_bottom
                # 스킬 발동!
                self._activate_skill(is_top, top_paddle, bottom_paddle, ball)

        elif phase == "casting":
            skill = self.selected_skill_top if is_top else self.selected_skill_bottom
            skill_id = getattr(skill, 'skill_id', '') if skill else ''

            # === 드래곤 브레스: 시전 중 공의 X좌표를 따라감 ===
            if skill_id == 'dragon_breath' and ball:
                bx = max(GAME_AREA_X + 30, min(ball.x, GAME_AREA_X + GAME_AREA_WIDTH - 30))
                if is_top:
                    self.x_top = bx
                else:
                    self.x_bottom = bx
                target_x = bx

            # === 뿔 박치기: 오니마루가 직접 돌진/복귀 ===
            elif skill_id == 'horn_charge' and skill and skill.is_active:
                base_y = 120 if is_top else 630
                enter_x = self._enter_x_top if is_top else self._enter_x_bottom
                skill_target_x = getattr(skill, 'target_x', enter_x)
                skill_impact_y = getattr(skill, 'impact_y', base_y)

                if skill.phase == skill.PHASE_CHARGING:
                    p = getattr(skill, 'charge_progress', 0) ** 2  # 이징(가속)
                    vy = base_y + (skill_impact_y - base_y) * p
                    vx = enter_x + (skill_target_x - enter_x) * p
                elif skill.phase == skill.PHASE_IMPACT:
                    vy = skill_impact_y
                    vx = skill_target_x
                elif skill.phase == skill.PHASE_RETURNING:
                    p = 1 - (1 - getattr(skill, 'return_progress', 0)) ** 2  # 이징(감속)
                    vy = skill_impact_y + (base_y - skill_impact_y) * p
                    vx = skill_target_x + (enter_x - skill_target_x) * p
                else:  # STUN
                    vy = base_y
                    vx = enter_x

                if is_top:
                    self.x_top = vx
                    self.y_top = vy
                else:
                    self.x_bottom = vx
                    self.y_bottom = vy
                return  # 타이머 기반 퇴장 안 함 - 스킬 종료 시 자동 퇴장

            # === 게틀링 버스트: 탱크 모드 중 현재 위치 고정, 스킬 끝날 때까지 대기 ===
            elif skill_id == 'gatling_burst' and skill and skill.is_active:
                # 게틀링 버스트 활성 상태 → 현재 위치에서 대기 (타이머 기반 퇴장 안 함)
                return

            elif skill_id == 'gatling_burst' and skill and not skill.is_active:
                # 게틀링 버스트 종료 → 퇴장 전환
                if is_top:
                    self._exit_start_x_top = self.x_top
                    self._exit_start_y_top = self.y_top
                    self.phase_top = "exiting"
                    self.anim_timer_top = 0.0
                else:
                    self._exit_start_x_bottom = self.x_bottom
                    self._exit_start_y_bottom = self.y_bottom
                    self.phase_bottom = "exiting"
                    self.anim_timer_bottom = 0.0
                return

            # === 촉수 휘감기: 크라켄이 촉수휘감기가 끝날 때까지 대기 후 퇴장 ===
            elif skill_id == 'tentacle_wrap' and skill and skill.is_active:
                # 촉수휘감기 활성 상태 → 현재 위치에서 대기 (타이머 기반 퇴장 안 함)
                return

            elif skill_id == 'tentacle_wrap' and skill and not skill.is_active:
                # 촉수휘감기 종료 → 퇴장 전환
                if is_top:
                    self._exit_start_x_top = self.x_top
                    self._exit_start_y_top = self.y_top
                    self.phase_top = "exiting"
                    self.anim_timer_top = 0.0
                else:
                    self._exit_start_x_bottom = self.x_bottom
                    self._exit_start_y_bottom = self.y_bottom
                    self.phase_bottom = "exiting"
                    self.anim_timer_bottom = 0.0
                return

            # === 귀신발걸음: 무겐이 공을 따라다니며 상대 진영으로 전진/복귀 ===
            elif skill_id == 'demon_step' and skill and skill.is_active:
                # X축: 공을 따라감
                if ball:
                    bx = max(GAME_AREA_X + 30, min(ball.x, GAME_AREA_X + GAME_AREA_WIDTH - 30))
                    if is_top:
                        self.x_top = bx
                    else:
                        self.x_bottom = bx
                    target_x = bx

                # Y축: 상대 진영으로 전진(0~2초) → 복귀(2~4초)
                DEMON_STEP_GUARD_DURATION = 4.0
                FORWARD_DURATION = DEMON_STEP_GUARD_DURATION / 2  # 2초 전진
                base_y = 120 if is_top else 630
                # 상대 진영 끝까지 이동 (상단→화면 하단 700, 하단→화면 상단 50)
                dest_y = 700 if is_top else 50

                if timer < FORWARD_DURATION:
                    # 전진 페이즈: base_y → dest_y
                    progress = timer / FORWARD_DURATION
                    eased = self._ease_in_out(progress)
                    current_y = base_y + (dest_y - base_y) * eased
                else:
                    # 복귀 페이즈: dest_y → base_y
                    progress = min(1.0, (timer - FORWARD_DURATION) / (DEMON_STEP_GUARD_DURATION - FORWARD_DURATION))
                    eased = self._ease_in_out(progress)
                    current_y = dest_y + (base_y - dest_y) * eased

                if is_top:
                    self.y_top = current_y
                else:
                    self.y_bottom = current_y

                # 4초 후 강제 종료
                if timer >= DEMON_STEP_GUARD_DURATION:
                    skill.is_active = False
                    skill.aura_particles = []
                    game_state = self.skill_manager.game_state if self.skill_manager else {}
                    game_state['demon_eye_active'] = False
                    # 공 충돌 횟수 카운터 리셋 (1회 발동당 3회까지)
                    if is_top:
                        self._guard_ghost_step_hit_top = 0
                    else:
                        self._guard_ghost_step_hit_bottom = 0
                    # 퇴장 전환 (순찰모드면 바로 순찰/교대, 아니면 퇴장)
                    self._transition_after_casting(is_top)
                return  # 타이머 기반 퇴장 안 함

            # === 기본: 시전 시간 후 퇴장 (순찰모드면 바로 순찰/교대) ===
            if timer >= GUARD_CAST_DURATION:
                self._transition_after_casting(is_top)

        elif phase == "exiting":
            progress = min(1.0, timer / GUARD_EXIT_DURATION)
            eased = self._ease_in_out(progress)
            # 퇴장 시작 위치에서 화면 밖으로 이동
            es_x = self._exit_start_x_top if is_top else self._exit_start_x_bottom
            es_y = self._exit_start_y_top if is_top else self._exit_start_y_bottom
            current_x = es_x + (exit_x - es_x) * eased
            current_y = es_y  # Y 고정: 등장할 때처럼 옆으로 걸어서 퇴장

            if is_top:
                self.x_top = current_x
                self.y_top = current_y
            else:
                self.x_bottom = current_x
                self.y_bottom = current_y

            # 이동 애니메이션 갱신 (걷기 모션)
            guard = self.active_top if is_top else self.active_bottom
            if guard and self.hero_paddle_renderer:
                gx = self.x_top if is_top else self.x_bottom
                self.hero_paddle_renderer.update_movement(guard["id"], gx, dt)

            if progress >= 1.0:
                patrol_on = self.patrol_mode_top if is_top else self.patrol_mode_bottom
                if patrol_on:
                    # 순찰모드: 퇴장 대신 진영 내 순찰 시작
                    patrol_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
                    if is_top:
                        self.phase_top = "patrolling"
                        self.anim_timer_top = 0.0
                        self.x_top = patrol_x
                        self.y_top = TOP_PADDLE_Y
                    else:
                        self.phase_bottom = "patrolling"
                        self.anim_timer_bottom = 0.0
                        self.x_bottom = patrol_x
                        self.y_bottom = BOTTOM_PADDLE_Y
                else:
                    # 퇴장 완료 → 초기화
                    if is_top:
                        self.phase_top = None
                        self.active_top = None
                        self.selected_skill_top = None
                        self.y_top = TOP_PADDLE_Y
                    else:
                        self.phase_bottom = None
                        self.active_bottom = None
                        self.selected_skill_bottom = None
                        self.y_bottom = BOTTOM_PADDLE_Y

    def _transition_after_casting(self, is_top):
        """시전 완료 후 전환: 순찰 복귀 또는 퇴장"""
        patrol_on = self.patrol_mode_top if is_top else self.patrol_mode_bottom
        if patrol_on:
            if is_top:
                self.phase_top = "patrolling"
                self.anim_timer_top = 0.0
                self.y_top = TOP_PADDLE_Y
            else:
                self.phase_bottom = "patrolling"
                self.anim_timer_bottom = 0.0
                self.y_bottom = BOTTOM_PADDLE_Y
        else:
            if is_top:
                self._exit_start_x_top = self.x_top
                self._exit_start_y_top = float(self.y_top)
                self.phase_top = "exiting"
                self.anim_timer_top = 0.0
            else:
                self._exit_start_x_bottom = self.x_bottom
                self._exit_start_y_bottom = float(self.y_bottom)
                self.phase_bottom = "exiting"
                self.anim_timer_bottom = 0.0

    def _update_patrol(self, dt, is_top):
        """순찰 모드: 호위무사가 진영 내에서 자연스럽게 랜덤 순찰"""
        left_bound = GAME_AREA_X + 40
        right_bound = GAME_AREA_X + GAME_AREA_WIDTH - 40

        if is_top:
            # 대기 중이면 타이머 감소
            if self._patrol_wait_top > 0:
                self._patrol_wait_top -= dt
                # 대기 중에도 이동 애니메이션 갱신 (정지 → 감쇠)
                guard = self.active_top
                if guard and self.hero_paddle_renderer:
                    self.hero_paddle_renderer.update_movement(
                        guard["id"], self.x_top, dt)
                return

            # 목표 없으면 새 목표 생성
            if self._patrol_target_top is None:
                self._patrol_target_top = random.uniform(left_bound + 20, right_bound - 20)
                self._patrol_speed_top = random.uniform(110.0, 180.0)

            # 목표를 향해 이동
            diff = self._patrol_target_top - self.x_top
            if abs(diff) < 3.0:
                # 목표 도달 → 잠시 대기 후 새 목표
                self.x_top = self._patrol_target_top
                self._patrol_target_top = None
                self._patrol_wait_top = random.uniform(0.4, 1.5)
            else:
                direction = 1 if diff > 0 else -1
                self._patrol_dir_top = direction
                self.x_top += direction * self._patrol_speed_top * dt
                # 경계 클램프
                self.x_top = max(left_bound, min(self.x_top, right_bound))

            # 이동 애니메이션 갱신
            guard = self.active_top
            if guard and self.hero_paddle_renderer:
                self.hero_paddle_renderer.update_movement(
                    guard["id"], self.x_top, dt)
        else:
            # 대기 중이면 타이머 감소
            if self._patrol_wait_bottom > 0:
                self._patrol_wait_bottom -= dt
                guard = self.active_bottom
                if guard and self.hero_paddle_renderer:
                    self.hero_paddle_renderer.update_movement(
                        guard["id"], self.x_bottom, dt)
                return

            # 목표 없으면 새 목표 생성
            if self._patrol_target_bottom is None:
                self._patrol_target_bottom = random.uniform(left_bound + 20, right_bound - 20)
                self._patrol_speed_bottom = random.uniform(110.0, 180.0)

            # 목표를 향해 이동
            diff = self._patrol_target_bottom - self.x_bottom
            if abs(diff) < 3.0:
                self.x_bottom = self._patrol_target_bottom
                self._patrol_target_bottom = None
                self._patrol_wait_bottom = random.uniform(0.4, 1.5)
            else:
                direction = 1 if diff > 0 else -1
                self._patrol_dir_bottom = direction
                self.x_bottom += direction * self._patrol_speed_bottom * dt
                self.x_bottom = max(left_bound, min(self.x_bottom, right_bound))

            # 이동 애니메이션 갱신
            guard = self.active_bottom
            if guard and self.hero_paddle_renderer:
                self.hero_paddle_renderer.update_movement(
                    guard["id"], self.x_bottom, dt)

    def _trigger_from_patrol(self, is_top, top_paddle, bottom_paddle, ball):
        """순찰 중 스킬 재시전 (입장 애니메이션 스킵, 현재 위치에서 바로 시전)"""
        guard = self.active_top if is_top else self.active_bottom
        if not guard:
            return

        # 스킬 선택 (커스텀 can_use 조건 확인 후 가능한 스킬 우선)
        skills = self.skill_instances.get(guard["id"], [])
        if not skills:
            return

        # 가상 패들로 스킬 상태 갱신 → can_use 조건 확인
        guard_paddle = self._make_guard_paddle(is_top)
        target_paddle = bottom_paddle if is_top else top_paddle
        game_state = self.skill_manager.game_state if self.skill_manager else {}
        usable = []
        for sk in skills:
            sk.caster_is_top = is_top
            sk.current_cooldown = 0
            try:
                sk.update(0.016, guard_paddle, target_paddle, ball, game_state)
            except Exception:
                pass
            if sk.can_use():
                usable.append(sk)

        skill = random.choice(usable) if usable else random.choice(skills)
        if is_top:
            self.selected_skill_top = skill
        else:
            self.selected_skill_bottom = skill

        # 현재 위치에서 바로 시전 단계로 전환
        if is_top:
            self.phase_top = "casting"
            self.anim_timer_top = 0.0
            self._enter_x_top = self.x_top
        else:
            self.phase_bottom = "casting"
            self.anim_timer_bottom = 0.0
            self._enter_x_bottom = self.x_bottom

        # 다음 쿨타임 설정
        cd_mult = self.guard_cd_mult_top if is_top else self.guard_cd_mult_bottom
        base_cd = self._get_guard_cooldown(guard["id"])
        next_cd = base_cd * cd_mult
        if is_top:
            self.cooldown_top = next_cd
            self.cooldown_max_top = next_cd
        else:
            self.cooldown_bottom = next_cd
            self.cooldown_max_bottom = next_cd

        # 스킬 발동
        self._activate_skill(is_top, top_paddle, bottom_paddle, ball)
        print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} 순찰 중 재시전! "
              f"스킬: {skill.korean_name}")

    def _make_guard_paddle(self, is_top):
        """현재 호위무사 위치로 가상 패들 생성"""
        if is_top:
            gx = self.x_top
            gy = self.y_top  # 추적된 Y 위치 사용
        else:
            gx = self.x_bottom
            gy = self.y_bottom  # 추적된 Y 위치 사용
        gp = _GuardPaddle(gx, gy, is_top)
        # hero_id로 저장 (스킬 이펙트 진행 중 위치 유지)
        guard = self.active_top if is_top else self.active_bottom
        if guard:
            self.guard_paddles[guard["id"]] = gp
        return gp

    def _check_guard_demon_step_ball_collision(self, ball, game_state):
        """호위무사 귀신발걸음 중 공과 충돌 감지 → game_state 플래그 설정 (1회 발동당 3회까지)"""
        import pygame
        GUARD_PADDLE_W, GUARD_PADDLE_H = PADDLE_WIDTH, PADDLE_HEIGHT

        # --- 매혹 가드 귀신발걸음 충돌 체크 ---
        if (self._charmed and self._charmed.get('ghost_step_active')
                and self._charmed['phase'] == 'patrolling'):
            c = self._charmed
            hit_count = c.get('ghost_step_hit_count', 0)
            if hit_count < self._guard_ghost_step_max_hits:
                gx = c['x']
                gy = c['y']
                guard_rect = pygame.Rect(
                    int(gx - GUARD_PADDLE_W // 2), int(gy),
                    GUARD_PADDLE_W, GUARD_PADDLE_H
                )
                ball_rect = pygame.Rect(int(ball.x), int(ball.y),
                                        getattr(ball, 'width', 20),
                                        getattr(ball, 'height', 20))
                if guard_rect.colliderect(ball_rect):
                    ball_vy = getattr(ball, 'vy', 0)
                    caster_is_top = c['caster_is_top']
                    # 매혹 가드는 caster 편 → caster_is_top이면 상단 가드처럼 동작
                    if caster_is_top and ball_vy >= 0:
                        pass  # 공이 아래로 가는 중 → 상단 가드가 칠 수 없음
                    elif not caster_is_top and ball_vy <= 0:
                        pass  # 공이 위로 가는 중 → 하단 가드가 칠 수 없음
                    else:
                        c['ghost_step_hit_count'] = hit_count + 1
                        self._guard_ball_cooldown = 0.3
                        hit_offset = (ball_rect.centerx - guard_rect.centerx) / (GUARD_PADDLE_W / 2)
                        game_state['guard_demon_step_ball_hit'] = {
                            'is_top_guard': caster_is_top,
                            'hit_offset': hit_offset,
                        }
                        return

        # --- 일반 가드 귀신발걸음 충돌 체크 ---
        for hero_id, skills in self.skill_instances.items():
            is_top_guard = any(g["id"] == hero_id for g in self.guard_warriors_top)
            for skill in skills:
                if not skill.is_active:
                    continue
                skill_id = getattr(skill, 'skill_id', '')
                if skill_id != 'demon_step':
                    continue

                # 매혹 가드는 위에서 별도 처리 → 스킵
                if self._charmed and self._charmed['guard'].get("id") == hero_id:
                    continue

                # 이번 발동에서 최대 횟수 도달했으면 스킵
                hit_count = self._guard_ghost_step_hit_top if is_top_guard else self._guard_ghost_step_hit_bottom
                if hit_count >= self._guard_ghost_step_max_hits:
                    continue

                # 현재 호위무사 위치로 충돌 rect 생성
                gx = self.x_top if is_top_guard else self.x_bottom
                gy = self.y_top if is_top_guard else self.y_bottom
                guard_rect = pygame.Rect(
                    int(gx - GUARD_PADDLE_W // 2), int(gy),
                    GUARD_PADDLE_W, GUARD_PADDLE_H
                )
                ball_rect = pygame.Rect(int(ball.x), int(ball.y),
                                        getattr(ball, 'width', 20),
                                        getattr(ball, 'height', 20))

                if guard_rect.colliderect(ball_rect):
                    # 공이 올바른 방향으로 오는지 확인
                    ball_vy = getattr(ball, 'vy', 0)
                    if is_top_guard and ball_vy >= 0:
                        continue
                    if not is_top_guard and ball_vy <= 0:
                        continue

                    # 충돌! 횟수 증가
                    if is_top_guard:
                        self._guard_ghost_step_hit_top += 1
                    else:
                        self._guard_ghost_step_hit_bottom += 1
                    self._guard_ball_cooldown = 0.3  # 연속 충돌 방지 쿨다운

                    hit_offset = (ball_rect.centerx - guard_rect.centerx) / (GUARD_PADDLE_W / 2)
                    game_state['guard_demon_step_ball_hit'] = {
                        'is_top_guard': is_top_guard,
                        'hit_offset': hit_offset,
                    }
                    return

    def _check_guard_general_ball_collision(self, ball, game_state):
        """호위무사가 화면에 보이는 동안 공과 물리 충돌 (영웅 패들과 동일)"""
        import pygame
        for is_top in (True, False):
            phase = self.phase_top if is_top else self.phase_bottom
            if phase is None or phase == "patrolling":
                continue  # 순찰 중은 전용 충돌 로직(_check_guard_patrol_ball_collision) 사용
            # 귀신발걸음은 전용 충돌 로직 사용 → 스킵
            skill = self.selected_skill_top if is_top else self.selected_skill_bottom
            if skill and getattr(skill, 'skill_id', '') == 'demon_step':
                continue

            gx = self.x_top if is_top else self.x_bottom
            gy = self.y_top if is_top else self.y_bottom
            guard_rect = pygame.Rect(
                int(gx - PADDLE_WIDTH // 2), int(gy),
                PADDLE_WIDTH, PADDLE_HEIGHT
            )
            ball_rect = pygame.Rect(
                int(ball.x) - BALL_SIZE - 2,
                int(ball.y) - BALL_SIZE - 2,
                BALL_SIZE * 2 + 4,
                BALL_SIZE * 2 + 4
            )

            if guard_rect.colliderect(ball_rect):
                ball_vy = getattr(ball, 'vy', 0)
                # 이미 맞은 방향이면 무시 (관통 방지)
                if is_top and ball_vy < 0:
                    continue
                if not is_top and ball_vy > 0:
                    continue

                hit_offset = (ball_rect.centerx - guard_rect.centerx) / (PADDLE_WIDTH / 2)
                hit_offset = max(-1.0, min(1.0, hit_offset))
                guard = self.active_top if is_top else self.active_bottom
                game_state['guard_general_ball_hit'] = {
                    'is_top_guard': is_top,
                    'hit_offset': hit_offset,
                    'guard_id': guard["id"] if guard else None,
                }

                # ON_BALL_HIT 스킬 발동 (바나나슬라이스 등)
                if guard and self.skill_manager:
                    self._trigger_ball_hit_skill(is_top, guard, ball, game_state)
                return

    def _check_guard_patrol_ball_collision(self, ball, game_state):
        """순찰 중인 호위무사 패들로 공을 반사 (영웅 패들과 동일한 물리)

        일반 충돌(_check_guard_general_ball_collision)과 달리,
        공이 호위무사 쪽으로 날아올 때 반대 방향으로 반사한다.
        """
        import pygame
        for is_top in (True, False):
            phase = self.phase_top if is_top else self.phase_bottom
            if phase != "patrolling":
                continue

            gx = self.x_top if is_top else self.x_bottom
            gy = self.y_top if is_top else self.y_bottom
            guard_rect = pygame.Rect(
                int(gx - PADDLE_WIDTH // 2), int(gy),
                PADDLE_WIDTH, PADDLE_HEIGHT
            )
            ball_rect = pygame.Rect(
                int(ball.x) - BALL_SIZE - 2,
                int(ball.y) - BALL_SIZE - 2,
                BALL_SIZE * 2 + 4,
                BALL_SIZE * 2 + 4
            )

            if guard_rect.colliderect(ball_rect):
                ball_vy = getattr(ball, 'vy', 0)
                # 공이 호위무사 쪽으로 오는 방향만 반사 (관통 방지)
                # 상단 호위무사: 공이 위로 올라오는 중 (vy < 0) → 아래로 반사
                # 하단 호위무사: 공이 아래로 내려오는 중 (vy > 0) → 위로 반사
                if is_top and ball_vy >= 0:
                    continue
                if not is_top and ball_vy <= 0:
                    continue

                hit_offset = (ball_rect.centerx - guard_rect.centerx) / (PADDLE_WIDTH / 2)
                hit_offset = max(-1.0, min(1.0, hit_offset))
                guard = self.active_top if is_top else self.active_bottom
                game_state['guard_patrol_ball_hit'] = {
                    'is_top_guard': is_top,
                    'hit_offset': hit_offset,
                    'guard_id': guard["id"] if guard else None,
                }
                self._guard_ball_cooldown = 0.15  # 연속 충돌 방지

                # ON_BALL_HIT 스킬 발동 (바나나슬라이스 등)
                if guard and self.skill_manager:
                    self._trigger_ball_hit_skill(is_top, guard, ball, game_state)
                return

    def _trigger_ball_hit_skill(self, is_top, guard, ball, game_state):
        """호위무사가 공을 칠 때 ON_BALL_HIT 스킬 발동"""
        from downtown.hero_skills import SkillTrigger
        skills = self.skill_instances.get(guard["id"], [])
        if not skills:
            return
        # ON_BALL_HIT 스킬만 필터
        hit_skills = [sk for sk in skills if getattr(sk, 'trigger', None) == SkillTrigger.ON_BALL_HIT]
        if not hit_skills:
            return
        for skill in hit_skills:
            if skill.current_cooldown > 0 or skill.is_active:
                continue
            # 호위무사 가상 패들 설정
            guard_paddle = self._make_guard_paddle(is_top)
            target_paddle = self._make_guard_paddle(not is_top)  # 상대쪽 가상 패들
            skill.caster_is_top = is_top
            # caster 측 보호
            caster_prefix = 'top_paddle' if is_top else 'bottom_paddle'
            saved = self._save_caster_state(game_state, caster_prefix)
            result = skill.use(guard_paddle, target_paddle, ball, game_state)
            self._restore_caster_state(game_state, caster_prefix, saved)
            if result:
                print(f"[Guard] 호위무사 {guard['name']} ON_BALL_HIT 스킬 발동: {skill.korean_name}")
                break  # 한 번에 하나만 발동

    # 호위무사 스킬이 game_state를 통해 메인 영웅에 영향주는 것 방지용 키 목록
    _CASTER_STATE_KEYS = ['_locked', '_locked_x', '_locked_y', '_stunned', '_speed_boost', '_size_boost',
                          '_sand_prison', '_confused', '_slowed', '_slow_amount', '_shrink', '_shrink_scale']

    def _save_caster_state(self, game_state, caster_prefix):
        """스킬 호출 전 caster 측 game_state 백업"""
        saved = {}
        for suffix in self._CASTER_STATE_KEYS:
            key = f'{caster_prefix}{suffix}'
            if key in game_state:
                saved[key] = game_state[key]
        return saved

    def _restore_caster_state(self, game_state, caster_prefix, saved):
        """스킬 호출 후 caster 측 game_state 복원 (호위무사가 변경한 것 되돌림)"""
        for suffix in self._CASTER_STATE_KEYS:
            key = f'{caster_prefix}{suffix}'
            if key in saved:
                game_state[key] = saved[key]
            else:
                # 스킬이 새로 추가한 키는 제거
                game_state.pop(key, None)

    def _activate_skill(self, is_top, top_paddle, bottom_paddle, ball):
        """호위무사 스킬 실제 발동 (호위무사 위치에서 직접 시전)"""
        skill = self.selected_skill_top if is_top else self.selected_skill_bottom
        guard = self.active_top if is_top else self.active_bottom
        if not skill or not guard:
            return

        game_state = self.skill_manager.game_state if self.skill_manager else {}

        # 호위무사 위치의 가상 패들을 caster로 사용
        guard_paddle = self._make_guard_paddle(is_top)
        # 드래곤 브레스: 공 위치에서 발동 시작
        if getattr(skill, 'skill_id', '') == 'dragon_breath' and ball:
            guard_paddle.x = ball.x - guard_paddle.width // 2
            guard_paddle.centerx = ball.x
        # 상대편이 target
        target_paddle = bottom_paddle if is_top else top_paddle

        # 스킬에 caster_is_top 설정 (위치 계산용)
        skill.caster_is_top = is_top

        # 스킬 직접 발동 (쿨타임 무시 - 호위무사 자체 쿨타임 사용)
        skill.current_cooldown = 0  # 강제 쿨타임 리셋
        if skill.is_active:
            # 이전 효과가 아직 진행 중이면 먼저 종료
            try:
                skill._end_effect(guard_paddle, target_paddle, ball, game_state)
            except Exception:
                pass
            skill.is_active = False

        # 커스텀 can_use()가 있는 스킬은 update()로 상태 갱신 필요 (예: WildRoar의 _ball_in_range)
        try:
            skill.update(0.016, guard_paddle, target_paddle, ball, game_state)
        except Exception:
            pass

        # caster 측 game_state 보호 (호위무사 스킬이 메인 영웅에 영향 방지)
        caster_prefix = 'top_paddle' if is_top else 'bottom_paddle'
        saved = self._save_caster_state(game_state, caster_prefix)
        result = skill.use(guard_paddle, target_paddle, ball, game_state)
        self._restore_caster_state(game_state, caster_prefix, saved)

        # 스킬별 글로벌 game_state 키 차단 (메인 영웅에 영향 방지)
        skill_id = getattr(skill, 'skill_id', '')
        if skill_id == 'horn_charge':
            game_state['horn_charge_active'] = False
        elif skill_id == 'demon_step':
            game_state['demon_eye_active'] = False
            game_state.pop('ghost_step_start_top', None)
            game_state.pop('ghost_step_start_bottom', None)
        elif skill_id == 'steam_barrier':
            # 호위무사가 시전한 배리어 → 메인 패들 정지 방지
            game_state['steam_barrier_caster_frozen'] = False
            game_state['steam_barrier_thaw_speed'] = 0.0

        # duration=0 스킬 (OilSpill 등)은 use()에서 is_active가 안 켜짐 → 수동 활성화
        # (호위무사 update/draw 루프가 is_active 기반이므로 필요)
        if result and not skill.is_active and skill.duration <= 0:
            skill.is_active = True

        if result:
            # 스킬 사운드 재생
            self._play_skill_sound(result)
            # 상태 효과를 game_state에 적용 (try_use_skill과 동일한 로직)
            self._apply_status_effects(result, target_paddle)

            print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} → "
                  f"{skill.korean_name} 발동 성공! (위치: x={guard_paddle.centerx:.0f})")
        else:
            print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} → "
                  f"{skill.korean_name} 발동 실패")

        # 말풍선 직접 설정 (호위무사 위치에 표시) - 영웅과 동일하게 스킬명만
        bubble_text = f"{skill.korean_name}!"
        bubble_data = {'text': bubble_text, 'timer': self._bubble_duration}
        if is_top:
            self._bubble_top = bubble_data
        else:
            self._bubble_bottom = bubble_data

    def _play_skill_sound(self, result):
        """스킬 결과에서 사운드 키를 꺼내 재생 (독립실행 모드용)"""
        if not result:
            return
        # 투기장 배틀 중이 아니면 사운드 재생 차단
        try:
            import pingfighter as _pf_snd
            if not getattr(_pf_snd, 'arena_mode_enabled', False):
                return
        except Exception:
            pass
        sound_key = result.get('sound')
        if not sound_key:
            return

        if not hasattr(ColosseumsArena, '_skill_sound_cache'):
            ColosseumsArena._skill_sound_cache = {}

        if sound_key not in ColosseumsArena._skill_sound_cache:
            try:
                project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                filepath = os.path.join(project_root, "sounds", f"{sound_key}.wav")
                if os.path.exists(filepath):
                    ColosseumsArena._skill_sound_cache[sound_key] = pygame.mixer.Sound(filepath)
                else:
                    ColosseumsArena._skill_sound_cache[sound_key] = None
            except Exception:
                ColosseumsArena._skill_sound_cache[sound_key] = None

        sound = ColosseumsArena._skill_sound_cache.get(sound_key)
        if sound:
            sound.play()

    def _apply_status_effects(self, result, target_paddle):
        """스킬 결과에서 상태 효과를 game_state에 적용"""
        if not result or not self.skill_manager:
            return

        game_state = self.skill_manager.game_state
        target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'

        from downtown.hero_skills import StatusEffect, ScreenEffect

        if result.get('target_status'):
            status = result['target_status']
            if status == StatusEffect.STUN:
                game_state[f'{target_prefix}_stunned'] = True
            elif status == StatusEffect.SLOW:
                game_state[f'{target_prefix}_slowed'] = True
                game_state[f'{target_prefix}_slow_amount'] = result.get('slow_amount', 0.5)
            elif status == StatusEffect.CONFUSION:
                game_state[f'{target_prefix}_confused'] = True
            elif status == StatusEffect.SHRINK:
                game_state[f'{target_prefix}_shrink'] = True
                game_state[f'{target_prefix}_shrink_scale'] = result.get('shrink_amount', 0.5)
            elif status == StatusEffect.BLIND:
                game_state['blind_target_is_top'] = target_paddle.is_top
            elif status == StatusEffect.PUPPET:
                game_state[f'{target_prefix}_locked'] = True

        # 화면 효과
        if 'screen_effect' in result and self.skill_manager:
            self.skill_manager.screen_effects.append({
                'type': result['screen_effect'],
                'duration': result.get('flash_duration', 0.3),
                'color': result.get('flash_color', (255, 255, 255)),
                'intensity': result.get('shake_intensity', 0)
            })

    def draw(self, screen, top_paddle=None, bottom_paddle=None, ball=None,
             shake_x=0, shake_y=0):
        """호위무사 캐릭터 및 스킬 이펙트 그리기"""
        game_state = self.skill_manager.game_state if self.skill_manager else {}

        # 호위무사 스킬 이펙트 그리기 (호위무사 위치 기반)
        for hero_id, skills in self.skill_instances.items():
            # 매혹된 호위무사는 caster 편으로 동작
            if self._charmed and self._charmed['guard'].get("id") == hero_id:
                is_top_guard = self._charmed['caster_is_top']
            else:
                is_top_guard = any(g["id"] == hero_id for g in self.guard_warriors_top)
            guard_paddle = self.guard_paddles.get(hero_id)
            # 매혹 호위무사: draw 전에도 패들 위치를 charmed 좌표로 동기화
            if self._charmed and self._charmed['guard'].get("id") == hero_id:
                if guard_paddle is None:
                    guard_paddle = _GuardPaddle(self._charmed['x'], self._charmed['y'], is_top_guard)
                    self.guard_paddles[hero_id] = guard_paddle
                guard_paddle.x = int(self._charmed['x']) - guard_paddle.width // 2
                guard_paddle.centerx = int(self._charmed['x'])
                guard_paddle.y = int(self._charmed['y'])
                guard_paddle.centery = int(self._charmed['y']) + guard_paddle.height // 2
            # 2번째 순찰 호위무사: draw 전에도 패들 위치를 patrol2 좌표로 동기화
            elif self._patrol2_top and self._patrol2_top['guard'].get("id") == hero_id:
                p2 = self._patrol2_top
                if guard_paddle is None:
                    guard_paddle = _GuardPaddle(p2['x'], p2['y'], True)
                    self.guard_paddles[hero_id] = guard_paddle
                guard_paddle.x = int(p2['x']) - guard_paddle.width // 2
                guard_paddle.centerx = int(p2['x'])
                guard_paddle.y = int(p2['y'])
                guard_paddle.centery = int(p2['y']) + guard_paddle.height // 2
            elif self._patrol2_bottom and self._patrol2_bottom['guard'].get("id") == hero_id:
                p2 = self._patrol2_bottom
                if guard_paddle is None:
                    guard_paddle = _GuardPaddle(p2['x'], p2['y'], False)
                    self.guard_paddles[hero_id] = guard_paddle
                guard_paddle.x = int(p2['x']) - guard_paddle.width // 2
                guard_paddle.centerx = int(p2['x'])
                guard_paddle.y = int(p2['y'])
                guard_paddle.centery = int(p2['y']) + guard_paddle.height // 2
            elif guard_paddle is None:
                guard_paddle = top_paddle if is_top_guard else bottom_paddle
            target = bottom_paddle if is_top_guard else top_paddle
            for skill in skills:
                # 유령소환은 is_active가 False여도 잔여 이펙트(dying, teleport)를 그려야 함
                has_lingering = (getattr(skill, 'skill_id', '') == 'ghost_summon'
                                 and (skill.dying_ghosts or skill._teleport_effects))
                if (skill.is_active or has_lingering) and hasattr(skill, 'draw'):
                    try:
                        # 귀신발걸음: draw 전에 현재 호위무사 위치로 동기화
                        skill_id = getattr(skill, 'skill_id', '')
                        if skill_id == 'demon_step' and guard_paddle:
                            # 매혹 호위무사는 charmed 좌표 사용
                            if self._charmed and self._charmed['guard'].get("id") == hero_id:
                                gx = self._charmed['x']
                                gy = self._charmed['y']
                            elif self._patrol2_top and self._patrol2_top['guard'].get("id") == hero_id:
                                gx = self._patrol2_top['x']
                                gy = self._patrol2_top['y']
                            elif self._patrol2_bottom and self._patrol2_bottom['guard'].get("id") == hero_id:
                                gx = self._patrol2_bottom['x']
                                gy = self._patrol2_bottom['y']
                            else:
                                gx = self.x_top if is_top_guard else self.x_bottom
                                gy = self.y_top if is_top_guard else self.y_bottom
                            guard_paddle.x = gx - guard_paddle.width // 2
                            guard_paddle.centerx = gx
                            guard_paddle.y = gy
                            guard_paddle.centery = gy + guard_paddle.height // 2
                        skill.draw(screen, guard_paddle, target, ball, game_state)
                    except Exception as e:
                        print(f"[Guard] skill draw error ({getattr(skill, 'skill_id', '?')}): {e}")

        # 상단측 호위무사 캐릭터 (patrol_entering 딜레이 중에는 미표시)
        if self.active_top and self.phase_top:
            if self.phase_top != "patrol_entering" or self.anim_timer_top >= self.PATROL_ENTRY_DELAY:
                self._draw_guard(screen, self.active_top,
                                 self.x_top + shake_x, self.y_top + shake_y,
                                 is_top=True)

        # 하단측 호위무사 캐릭터 (patrol_entering 딜레이 중에는 미표시)
        if self.active_bottom and self.phase_bottom:
            if self.phase_bottom != "patrol_entering" or self.anim_timer_bottom >= self.PATROL_ENTRY_DELAY:
                self._draw_guard(screen, self.active_bottom,
                                 self.x_bottom + shake_x, self.y_bottom + shake_y,
                                 is_top=False)

        # === 2번째 호위무사 렌더링 ===
        try:
            self._draw_patrol2(screen, shake_x, shake_y)
        except Exception as e:
            print(f"[Guard] patrol2 draw error: {e}")

        # === 매혹 순찰 중 호위무사 렌더링 ===
        try:
            self._draw_charmed_guard(screen, shake_x, shake_y)
        except Exception as e:
            print(f"[Guard] charmed guard draw error: {e}")

        # === 매혹 견인/복귀 중 호위무사 렌더링 ===
        try:
            self._draw_charm_transitioning_guard(screen, game_state, shake_x, shake_y)
        except Exception as e:
            print(f"[Guard] charm transition draw error: {e}")

        # 호위무사 말풍선 그리기
        try:
            self._draw_guard_bubbles(screen, shake_x, shake_y)
        except Exception as e:
            print(f"[Guard] bubble draw error: {e}")

    def _draw_charm_transitioning_guard(self, screen, game_state, shake_x, shake_y):
        """매혹 견인/복귀 중인 호위무사 캐릭터 렌더링"""
        charmed = game_state.get('_charmed_guard', None)
        if not charmed:
            return

        # 견인 중
        pull_pos = game_state.get('charm_pull_position', None)
        if pull_pos:
            caster_top = game_state.get('_charm_caster_is_top', True)
            self._draw_guard(screen, charmed,
                             pull_pos['x'] + shake_x, pull_pos['y'] + shake_y,
                             is_top=not caster_top)  # 원래 상대 방향으로 표시
            return

        # 복귀 중
        ret_pos = game_state.get('charm_return_position', None)
        if ret_pos:
            caster_top = game_state.get('_charm_caster_is_top', True)
            self._draw_guard(screen, charmed,
                             ret_pos['x'] + shake_x, ret_pos['y'] + shake_y,
                             is_top=not caster_top)

    def _draw_guard_bubbles(self, screen, shake_x, shake_y):
        """호위무사 스킬 발동 시 외침 풍선 표시 (영웅 스킬 발동과 동일한 스타버스트 스타일)"""
        charmed_top = self._charmed and self._charmed['caster_is_top']
        charmed_bottom = self._charmed and not self._charmed['caster_is_top']

        # 상단측 호위무사 말풍선 (캐릭터 아래)
        if (self._bubble_top and self._bubble_top['timer'] > 0
                and (self.phase_top is not None or charmed_top)):
            # 매혹 호위무사면 저장된 좌표 사용, 아니면 일반 호위무사 좌표
            if charmed_top and 'x' in self._bubble_top:
                bx = self._bubble_top['x'] + shake_x
                by = self._bubble_top['y'] + shake_y + 15
            else:
                bx = self.x_top + shake_x
                by = self.y_top + shake_y + 15
            timer = self._bubble_top['timer']
            theme = self._bubble_top.get('color', (200, 100, 60))
            self._draw_guard_shout_bubble(screen, bx, by, self._bubble_top['text'],
                                          timer, theme)

        # 하단측 호위무사 말풍선 (캐릭터 위)
        if (self._bubble_bottom and self._bubble_bottom['timer'] > 0
                and (self.phase_bottom is not None or charmed_bottom)):
            if charmed_bottom and 'x' in self._bubble_bottom:
                bx = self._bubble_bottom['x'] + shake_x
                by = self._bubble_bottom['y'] + shake_y - 50
            else:
                bx = self.x_bottom + shake_x
                by = self.y_bottom + shake_y - 50
            timer = self._bubble_bottom['timer']
            theme = self._bubble_bottom.get('color', (200, 100, 60))
            self._draw_guard_shout_bubble(screen, bx, by, self._bubble_bottom['text'],
                                          timer, theme)

    def _draw_guard_shout_bubble(self, screen, x, y, text, timer, theme_color):
        """호위무사 외침 풍선 렌더링 (뾰족한 스타버스트 - 영웅 스킬 발동과 동일)"""
        try:
            # theme_color 안전 검증
            if not isinstance(theme_color, (tuple, list)) or len(theme_color) < 3:
                theme_color = (200, 100, 60)
            import os, sys
            font = pygame.font.Font(None, 24)
            try:
                if hasattr(sys, '_MEIPASS'):
                    base = sys._MEIPASS
                else:
                    base = os.path.dirname(os.path.dirname(__file__))
                font_candidates = [
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf"),
                    os.path.join(base, "fonts", "NanumSquareB.ttf"),
                ]
                for fp in font_candidates:
                    if os.path.exists(fp):
                        font = pygame.font.Font(fp, 20)
                        break
            except Exception:
                pass

            text_surface = font.render(text, True, (255, 255, 255))
            text_w = text_surface.get_width()
            text_h = text_surface.get_height()

            # 내부 사이즈
            pad_x, pad_y = 22, 14
            inner_w = text_w + pad_x * 2
            inner_h = text_h + pad_y * 2

            # 팝업 스케일 애니메이션 (등장 시 1.3 → 1.0)
            max_timer = self._bubble_duration
            elapsed = max_timer - timer
            if elapsed < 0.15:
                scale = 1.0 + (1.0 - elapsed / 0.15) * 0.3
            else:
                scale = 1.0

            # 서피스 생성 (스파이크 여유)
            spike_len = 14
            surf_w = int((inner_w + spike_len * 2) * scale) + 8
            surf_h = int((inner_h + spike_len * 2) * scale) + 8
            bubble_surface = _get_arena_surface(surf_w, surf_h)
            cx = surf_w // 2
            cy = surf_h // 2

            # 스타버스트 다각형 (12개 뾰족한 끝)
            num_spikes = 12
            outer_rx = (inner_w / 2 + spike_len) * scale
            outer_ry = (inner_h / 2 + spike_len) * scale
            inner_rx = (inner_w / 2) * scale
            inner_ry = (inner_h / 2) * scale

            points = []
            for i in range(num_spikes * 2):
                angle = 2 * math.pi * i / (num_spikes * 2) - math.pi / 2
                variation = 1.0 + 0.12 * _sin(i * 2.7)
                if i % 2 == 0:
                    px = cx + math.cos(angle) * outer_rx * variation
                    py = cy + math.sin(angle) * outer_ry * variation
                else:
                    px = cx + math.cos(angle) * inner_rx
                    py = cy + math.sin(angle) * inner_ry
                points.append((px, py))

            # 그림자
            shadow_pts = [(p[0] + 3, p[1] + 3) for p in points]
            pygame.draw.polygon(bubble_surface, (0, 0, 0, 70), shadow_pts)

            # 메인 채우기 (테마 색상)
            pygame.draw.polygon(bubble_surface, theme_color, points)

            # 안쪽 하이라이트
            hl_color = (min(255, theme_color[0] + 50),
                        min(255, theme_color[1] + 50),
                        min(255, theme_color[2] + 50), 90)
            hl_rx = inner_rx * 0.8
            hl_ry = inner_ry * 0.6
            hl_pts = []
            for i in range(num_spikes * 2):
                angle = 2 * math.pi * i / (num_spikes * 2) - math.pi / 2
                r = hl_rx if i % 2 == 0 else hl_rx * 0.85
                ry = hl_ry if i % 2 == 0 else hl_ry * 0.85
                hl_pts.append((cx + math.cos(angle) * r, cy + math.sin(angle) * ry))
            pygame.draw.polygon(bubble_surface, hl_color, hl_pts)

            # 테두리 (어두운 색)
            border_color = (max(0, theme_color[0] - 60),
                            max(0, theme_color[1] - 60),
                            max(0, theme_color[2] - 60))
            pygame.draw.polygon(bubble_surface, border_color, points, 3)

            # 텍스트: 검정 외곽선 + 흰색 본문
            tx = int(cx - text_w / 2)
            ty = int(cy - text_h / 2)
            for dx, dy in [(-2, 0), (2, 0), (0, -2), (0, 2),
                            (-1, -1), (1, -1), (-1, 1), (1, 1)]:
                outline = font.render(text, True, (0, 0, 0))
                bubble_surface.blit(outline, (tx + dx, ty + dy))
            bubble_surface.blit(font.render(text, True, (255, 255, 255)), (tx, ty))

            # 흔들림 애니메이션
            float_offset = _sin(timer * 5.0) * 2

            # 화면에 그리기
            blit_x = int(x - surf_w // 2)
            blit_y = int(y + float_offset)
            blit_x = max(GAME_AREA_X + 5, min(blit_x, GAME_AREA_X + GAME_AREA_WIDTH - surf_w - 5))
            screen.blit(bubble_surface, (blit_x, blit_y))
        except Exception as e:
            print(f"[Guard] bubble render error: {e}")

    # 인게임 영웅 렌더링 기준 너비 130의 90% (호위무사는 영웅보다 10% 작게)
    _GUARD_RENDER_WIDTH = 117

    def _draw_guard(self, screen, guard_hero, x, y, is_top):
        """단일 호위무사 캐릭터 렌더링 (영웅보다 10% 작은 크기)"""
        ix, iy = int(x), int(y)
        color = guard_hero.get("color", (200, 200, 200))

        # 글로우 효과 (반투명 원, 영웅보다 10% 작게)
        glow_r = 36  # 영웅 40의 90%
        glow_size = glow_r * 2
        glow_surf = _get_arena_surface(glow_size, glow_size)
        glow_alpha = 60
        # 시전 중이면 글로우 강화
        phase = self.phase_top if is_top else self.phase_bottom
        if phase == "casting":
            glow_alpha = 120
        pygame.draw.circle(glow_surf, (*color, glow_alpha), (glow_r, glow_r), glow_r)
        screen.blit(glow_surf, (ix - glow_r, iy - glow_r))

        # 영웅 캐릭터 그리기 (인게임 영웅과 동일한 130 기준 너비 사용)
        if self.hero_paddle_renderer:
            facing = "down" if is_top else "up"
            try:
                self.hero_paddle_renderer.draw_hero_paddle(
                    screen,
                    guard_hero["id"],
                    ix, iy,
                    self._GUARD_RENDER_WIDTH, PADDLE_HEIGHT,
                    facing=facing,
                    color=color,
                    scale_mode="paddle"
                )
            except Exception:
                # 폴백: 간단한 원형 (영웅보다 10% 작게)
                pygame.draw.circle(screen, color, (ix, iy), 18)
        else:
            # 폴백: 간단한 원형 + 테두리 (영웅보다 10% 작게)
            pygame.draw.circle(screen, color, (ix, iy), 18)
            pygame.draw.circle(screen, (255, 255, 255), (ix, iy), 18, 2)

    def _get_guard_korean_font(self, size=14):
        """호위무사 UI용 한글 폰트 (캐싱)"""
        cache_key = f"_guard_font_{size}"
        cached = getattr(self, cache_key, None)
        if cached:
            return cached
        try:
            import os, sys
            if hasattr(sys, '_MEIPASS'):
                base = sys._MEIPASS
            else:
                base = os.path.dirname(os.path.dirname(__file__))
            # Pretendard 폰트 우선 시도 (프로젝트에 포함된 한글 폰트)
            font_candidates = [
                os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf"),
                os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Regular.ttf"),
                os.path.join(base, "fonts", "프리텐다드", "public", "static", "Pretendard-Bold.otf"),
                os.path.join(base, "fonts", "NanumSquareB.ttf"),
            ]
            for fp in font_candidates:
                if os.path.exists(fp):
                    font = pygame.font.Font(fp, size)
                    setattr(self, cache_key, font)
                    return font
        except Exception:
            pass
        font = pygame.font.Font(None, size)
        setattr(self, cache_key, font)
        return font

    def draw_guard_icons(self, screen, game_offset_x=0, game_offset_y=0, game_scale=1.0, fonts=None, mouse_pos=None):
        """필러 배경(관중석) 위에 호위무사 캐릭터 이미지 UI 표시
        screen: REAL_SCREEN (전체화면 서피스)
        game_offset_x/y: 게임 영역의 REAL_SCREEN 내 오프셋
        game_scale: 게임 스케일 팩터
        mouse_pos: REAL_SCREEN 좌표계의 마우스 위치 (호버 툴팁용)
        - 하단 영웅의 호위무사 → 왼쪽 하단 필러
        - 상단 영웅의 호위무사 → 오른쪽 상단 필러
        Returns: hover_info dict or None
        """
        if not self.guard_warriors_top and not self.guard_warriors_bottom:
            return None
        hover_info = None

        # 필러 영역 좌표 계산 (REAL_SCREEN 좌표계)
        game_scaled_w = int(SCREEN_WIDTH * game_scale)
        left_pillar_w = game_offset_x
        right_pillar_x = game_offset_x + game_scaled_w
        right_pillar_w = screen.get_width() - right_pillar_x

        # 필러가 없으면 (창 모드) 그리지 않음
        if left_pillar_w < 30 and right_pillar_w < 30:
            return

        # game_scale 비례 크기 (모든 디스플레이 모드에서 일관된 비율 유지)
        _s = game_scale

        # 한글 폰트
        name_font = self._get_guard_korean_font(max(10, int(14 * _s)))

        # 캐릭터 렌더링용 소형 서피스 크기
        char_surf_w = max(40, int(80 * _s))
        char_surf_h = max(40, int(80 * _s))
        frame_w = max(30, int(58 * _s))
        frame_h = max(30, int(58 * _s))
        slot_h = max(50, int(100 * _s))  # 슬롯 간격 (이름 포함, 겹침 방지)

        # UI 색상 (메탈릭 실버/화이트)
        bg_color = (210, 215, 225, 255)      # 메탈릭 실버 배경
        border_color = (170, 175, 190, 255)  # 연한 메탈릭 테두리
        label_bg = (185, 190, 200, 255)      # 이름 배경 (메탈릭)
        label_text_color = (30, 30, 40)      # 이름 텍스트 (어두운색)
        arrow_color = (255, 200, 50)         # 화살표 색상 (골드)

        # --- 상단 영웅의 호위무사 → 오른쪽 필러, 인게임창 상단 끝에 붙임 ---
        if right_pillar_w >= 30:
            # 인게임창 오른쪽 끝에 붙어있는 느낌 (프레임 왼쪽 = 게임 영역 오른쪽 끝 + 4px)
            frame_x_right = right_pillar_x + int(4 * _s)
            cx_right = frame_x_right + frame_w // 2
            y_start_top = game_offset_y + int(10 * game_scale)
            for i, guard in enumerate(self.guard_warriors_top):
                color = guard.get("color", (150, 150, 150))
                slot_cy = y_start_top + i * slot_h

                # 배경 프레임 (메탈릭 실버)
                frame_surf = _get_arena_surface(frame_w, frame_h)
                pygame.draw.rect(frame_surf, bg_color, (0, 0, frame_w, frame_h), border_radius=8)
                pygame.draw.rect(frame_surf, border_color, (0, 0, frame_w, frame_h), width=2, border_radius=8)
                screen.blit(frame_surf, (frame_x_right, slot_cy))

                # 영웅 캐릭터 이미지 (프레임 중앙 정렬)
                self._draw_guard_icon_character(
                    screen, guard, cx_right, slot_cy + frame_h // 2,
                    char_surf_w, char_surf_h, facing="down"
                )

                # 쿨타임 어둡게 오버레이 (대기 중, 순찰 중, 순찰 입장 중)
                _cd_phases_top = (None, "patrolling", "patrol_entering")
                if self.phase_top in _cd_phases_top and self.cooldown_top > 0:
                    cd_ratio = min(1.0, self.cooldown_top / self.cooldown_max_top) if self.cooldown_max_top > 0 else 0
                    overlay_h = int(frame_h * cd_ratio)
                    if overlay_h > 0:
                        cd_surf = _get_arena_surface(frame_w, overlay_h)
                        cd_surf.fill((0, 0, 0, 150))
                        screen.blit(cd_surf, (frame_x_right, slot_cy))
                    # 쿨타임 숫자 표시
                    try:
                        cd_num_font = self._get_guard_korean_font(max(10, int(16 * _s)))
                        cd_seconds = max(0, int(self.cooldown_top) + 1)
                        cd_num_surf = cd_num_font.render(str(cd_seconds), True, (255, 255, 255))
                        cd_num_rect = cd_num_surf.get_rect(center=(frame_x_right + frame_w // 2, slot_cy + frame_h // 2))
                        screen.blit(cd_num_surf, cd_num_rect)
                    except Exception:
                        pass

                # 다음 등장 화살표 표시 (2명 이상일 때, 쿨타임 중)
                if (len(self.guard_warriors_top) >= 2 and self.phase_top in _cd_phases_top
                        and i == self.next_guard_top_idx % len(self.guard_warriors_top)):
                    _aw = max(6, int(10 * _s))
                    _ah = max(8, int(14 * _s))
                    ax = frame_x_right - int(12 * _s)
                    ay = slot_cy + frame_h // 2
                    pulse = 0.5 + 0.5 * _sin(pygame.time.get_ticks() / 300.0)
                    a_alpha = int(160 + 80 * pulse)
                    arrow_s = _get_arena_surface(_aw, _ah)
                    ac = (*arrow_color[:3], a_alpha)
                    pygame.draw.polygon(arrow_s, ac, [(_aw, _ah // 2), (0, 0), (0, _ah)])
                    screen.blit(arrow_s, (ax, ay - _ah // 2))

                # 이름 표시 (한글 폰트)
                try:
                    name = guard.get("name", "?")
                    name_surf = name_font.render(name, True, label_text_color)
                    name_rect = name_surf.get_rect(centerx=cx_right, top=slot_cy + frame_h + 2)
                    bg_rect = name_rect.inflate(8, 4)
                    bg_s = _get_arena_surface(bg_rect.width, bg_rect.height)
                    pygame.draw.rect(bg_s, label_bg, (0, 0, bg_rect.width, bg_rect.height), border_radius=4)
                    screen.blit(bg_s, bg_rect)
                    screen.blit(name_surf, name_rect)
                except Exception:
                    pass

                # 호버 체크 (마우스가 프레임 위에 있으면 툴팁 정보 반환)
                if mouse_pos:
                    _fr = pygame.Rect(frame_x_right, slot_cy, frame_w, frame_h)
                    if _fr.collidepoint(mouse_pos):
                        # 선택된 스킬 정보 포함
                        _guard_skills = self.skill_instances.get(guard["id"], [])
                        # 순찰/순찰입장 중에도 쿨타임 표시
                        _cd_val = self.cooldown_top if self.phase_top in (None, "patrolling", "patrol_entering") else 0
                        hover_info = {
                            "name": guard.get("name", "?"),
                            "color": guard.get("color", (200, 200, 200)),
                            "cooldown": _cd_val,
                            "phase": self.phase_top,
                            "is_next": (i == self.next_guard_top_idx % len(self.guard_warriors_top)) if len(self.guard_warriors_top) >= 2 else True,
                            "side": "top",
                            "screen_x": frame_x_right + frame_w + 8,
                            "screen_y": slot_cy,
                            "skill": _guard_skills[0] if _guard_skills else None,
                            "skills": list(_guard_skills),  # 모든 스킬 목록
                        }

        # --- 하단 영웅의 호위무사 → 왼쪽 필러, 인게임창 하단 끝에 붙임 ---
        if left_pillar_w >= 30:
            # 인게임창 왼쪽 끝에 붙어있는 느낌 (프레임 오른쪽 = 게임 영역 왼쪽 끝 - 4px)
            frame_x_left = game_offset_x - frame_w - int(4 * _s)
            cx_left = frame_x_left + frame_w // 2
            game_scaled_h = int(SCREEN_HEIGHT * game_scale)
            y_end = game_offset_y + game_scaled_h - int(10 * game_scale)
            y_start_bottom = y_end - len(self.guard_warriors_bottom) * slot_h
            for i, guard in enumerate(self.guard_warriors_bottom):
                color = guard.get("color", (150, 150, 150))
                slot_cy = y_start_bottom + i * slot_h

                # 배경 프레임 (메탈릭 실버)
                frame_surf = _get_arena_surface(frame_w, frame_h)
                pygame.draw.rect(frame_surf, bg_color, (0, 0, frame_w, frame_h), border_radius=8)
                pygame.draw.rect(frame_surf, border_color, (0, 0, frame_w, frame_h), width=2, border_radius=8)
                screen.blit(frame_surf, (frame_x_left, slot_cy))

                # 영웅 캐릭터 이미지 (프레임 중앙 정렬)
                self._draw_guard_icon_character(
                    screen, guard, cx_left, slot_cy + frame_h // 2,
                    char_surf_w, char_surf_h, facing="down"
                )

                # 쿨타임 어둡게 오버레이 (대기 중, 순찰 중, 순찰 입장 중)
                _cd_phases_bottom = (None, "patrolling", "patrol_entering")
                if self.phase_bottom in _cd_phases_bottom and self.cooldown_bottom > 0:
                    cd_ratio = min(1.0, self.cooldown_bottom / self.cooldown_max_bottom) if self.cooldown_max_bottom > 0 else 0
                    overlay_h = int(frame_h * cd_ratio)
                    if overlay_h > 0:
                        cd_surf = _get_arena_surface(frame_w, overlay_h)
                        cd_surf.fill((0, 0, 0, 150))
                        screen.blit(cd_surf, (frame_x_left, slot_cy))
                    # 쿨타임 숫자 표시
                    try:
                        cd_num_font = self._get_guard_korean_font(max(10, int(16 * _s)))
                        cd_seconds = max(0, int(self.cooldown_bottom) + 1)
                        cd_num_surf = cd_num_font.render(str(cd_seconds), True, (255, 255, 255))
                        cd_num_rect = cd_num_surf.get_rect(center=(frame_x_left + frame_w // 2, slot_cy + frame_h // 2))
                        screen.blit(cd_num_surf, cd_num_rect)
                    except Exception:
                        pass

                # 다음 등장 화살표 표시 (2명 이상일 때, 쿨타임 중)
                if (len(self.guard_warriors_bottom) >= 2 and self.phase_bottom in _cd_phases_bottom
                        and i == self.next_guard_bottom_idx % len(self.guard_warriors_bottom)):
                    _aw = max(6, int(10 * _s))
                    _ah = max(8, int(14 * _s))
                    ax = frame_x_left + frame_w + int(2 * _s)
                    ay = slot_cy + frame_h // 2
                    pulse = 0.5 + 0.5 * _sin(pygame.time.get_ticks() / 300.0)
                    a_alpha = int(160 + 80 * pulse)
                    arrow_s = _get_arena_surface(_aw, _ah)
                    ac = (*arrow_color[:3], a_alpha)
                    pygame.draw.polygon(arrow_s, ac, [(0, _ah // 2), (_aw, 0), (_aw, _ah)])
                    screen.blit(arrow_s, (ax, ay - _ah // 2))

                # 이름 표시 (한글 폰트)
                try:
                    name = guard.get("name", "?")
                    name_surf = name_font.render(name, True, label_text_color)
                    name_rect = name_surf.get_rect(centerx=cx_left, top=slot_cy + frame_h + 2)
                    bg_rect = name_rect.inflate(8, 4)
                    bg_s = _get_arena_surface(bg_rect.width, bg_rect.height)
                    pygame.draw.rect(bg_s, label_bg, (0, 0, bg_rect.width, bg_rect.height), border_radius=4)
                    screen.blit(bg_s, bg_rect)
                    screen.blit(name_surf, name_rect)
                except Exception:
                    pass

                # 호버 체크 (마우스가 프레임 위에 있으면 툴팁 정보 반환)
                if mouse_pos:
                    _fr = pygame.Rect(frame_x_left, slot_cy, frame_w, frame_h)
                    if _fr.collidepoint(mouse_pos):
                        # 선택된 스킬 정보 포함
                        _guard_skills = self.skill_instances.get(guard["id"], [])
                        # 순찰/순찰입장 중에도 쿨타임 표시
                        _cd_val = self.cooldown_bottom if self.phase_bottom in (None, "patrolling", "patrol_entering") else 0
                        hover_info = {
                            "name": guard.get("name", "?"),
                            "color": guard.get("color", (200, 200, 200)),
                            "cooldown": _cd_val,
                            "phase": self.phase_bottom,
                            "is_next": (i == self.next_guard_bottom_idx % len(self.guard_warriors_bottom)) if len(self.guard_warriors_bottom) >= 2 else True,
                            "side": "bottom",
                            "screen_x": frame_x_left - 8,
                            "screen_y": slot_cy,
                            "skill": _guard_skills[0] if _guard_skills else None,
                            "skills": list(_guard_skills),  # 모든 스킬 목록
                        }

        return hover_info

    def draw_perk_pillar_icons(self, screen, player_perks, enemy_perks,
                                game_offset_x=0, game_offset_y=0, game_scale=1.0,
                                mouse_pos=None, draw_icon_func=None):
        """필러 배경 위에 획득한 퍽 아이콘 표시
        - 플레이어 퍽 → 왼쪽 필러, 호위무사 UI 위에 위로 쌓기
        - 상대 퍽 → 오른쪽 필러, 호위무사 UI 아래에 아래로 쌓기
        Returns: hover_info dict or None
        """
        hover_info = None
        game_scaled_w = int(SCREEN_WIDTH * game_scale)
        game_scaled_h = int(SCREEN_HEIGHT * game_scale)
        left_pillar_w = game_offset_x
        right_pillar_x = game_offset_x + game_scaled_w
        right_pillar_w = screen.get_width() - right_pillar_x

        if left_pillar_w < 30 and right_pillar_w < 30:
            return None

        # game_scale 비례 크기 (모든 디스플레이 모드에서 일관된 비율 유지)
        _s = game_scale
        icon_size = max(20, int(40 * _s))
        slot_gap = max(24, int(48 * _s))    # 아이콘 간격
        frame_w = max(30, int(58 * _s))     # 호위무사 프레임 너비 (draw_guard_icons와 동일)
        frame_h = max(30, int(58 * _s))
        slot_h_guard = max(50, int(100 * _s))  # 호위무사 슬롯 높이

        # --- 플레이어 퍽 → 왼쪽 필러, 호위무사 위에서 위로 쌓기 ---
        if left_pillar_w >= 30 and player_perks:
            frame_x_left = game_offset_x - frame_w - int(4 * _s)
            cx_left = frame_x_left + frame_w // 2
            # 호위무사 영역: 하단 끝에서 위로
            y_end = game_offset_y + game_scaled_h - int(10 * game_scale)
            n_guards = len(self.guard_warriors_bottom)
            guard_top_y = y_end - n_guards * slot_h_guard
            # 퍽은 호위무사 바로 위에서 위로 쌓음
            for i, perk in enumerate(player_perks):
                py = guard_top_y - (i + 1) * slot_gap
                if py < game_offset_y:
                    break
                # 퍽 아이콘 배경 (원형)
                bg_s = _get_arena_surface(icon_size + 6, icon_size + 6)
                pygame.draw.circle(bg_s, (30, 30, 40, 200), ((icon_size + 6) // 2, (icon_size + 6) // 2), (icon_size + 6) // 2)
                perk_color = perk.get("icon_color", (200, 200, 200))
                pygame.draw.circle(bg_s, (*perk_color[:3], 120), ((icon_size + 6) // 2, (icon_size + 6) // 2), (icon_size + 6) // 2, 2)
                screen.blit(bg_s, (cx_left - (icon_size + 6) // 2, py - (icon_size + 6) // 2))
                # 퍽 아이콘 그리기
                if draw_icon_func:
                    draw_icon_func(screen, perk["id"], cx_left, py, icon_size)
                # 호버 체크
                if mouse_pos:
                    _r = pygame.Rect(cx_left - (icon_size + 6) // 2, py - (icon_size + 6) // 2, icon_size + 6, icon_size + 6)
                    if _r.collidepoint(mouse_pos):
                        hover_info = {
                            "type": "perk",
                            "name": perk.get("name", "?"),
                            "description": perk.get("description", ""),
                            "icon_color": perk.get("icon_color", (200, 200, 200)),
                            "side": "player",
                            "screen_x": cx_left + (icon_size + 6) // 2 + 8,
                            "screen_y": py - 10,
                        }

        # --- 상대 퍽 → 오른쪽 필러, 호위무사 아래에서 아래로 쌓기 ---
        if right_pillar_w >= 30 and enemy_perks:
            frame_x_right = right_pillar_x + int(4 * _s)
            cx_right = frame_x_right + frame_w // 2
            # 호위무사 영역: 상단 끝에서 아래로
            y_start_top = game_offset_y + int(10 * game_scale)
            n_guards_top = len(self.guard_warriors_top)
            guard_bottom_y = y_start_top + n_guards_top * slot_h_guard
            # 퍽은 호위무사 바로 아래에서 아래로 쌓음
            for i, perk in enumerate(enemy_perks):
                py = guard_bottom_y + i * slot_gap + slot_gap // 2
                if py > game_offset_y + game_scaled_h:
                    break
                # 퍽 아이콘 배경 (원형)
                bg_s = _get_arena_surface(icon_size + 6, icon_size + 6)
                pygame.draw.circle(bg_s, (30, 30, 40, 200), ((icon_size + 6) // 2, (icon_size + 6) // 2), (icon_size + 6) // 2)
                perk_color = perk.get("icon_color", (200, 200, 200))
                pygame.draw.circle(bg_s, (*perk_color[:3], 120), ((icon_size + 6) // 2, (icon_size + 6) // 2), (icon_size + 6) // 2, 2)
                screen.blit(bg_s, (cx_right - (icon_size + 6) // 2, py - (icon_size + 6) // 2))
                # 퍽 아이콘 그리기
                if draw_icon_func:
                    draw_icon_func(screen, perk["id"], cx_right, py, icon_size)
                # 호버 체크
                if mouse_pos:
                    _r = pygame.Rect(cx_right - (icon_size + 6) // 2, py - (icon_size + 6) // 2, icon_size + 6, icon_size + 6)
                    if _r.collidepoint(mouse_pos):
                        hover_info = {
                            "type": "perk",
                            "name": perk.get("name", "?"),
                            "description": perk.get("description", ""),
                            "icon_color": perk.get("icon_color", (200, 200, 200)),
                            "side": "enemy",
                            "screen_x": cx_right - (icon_size + 6) // 2 - 8,
                            "screen_y": py - 10,
                        }

        return hover_info

    def _draw_guard_icon_character(self, screen, guard_hero, cx, cy,
                                    surf_w, surf_h, facing="down"):
        """호위무사 캐릭터를 소형 서피스에 렌더링 후 중앙 정렬하여 blit"""
        color = guard_hero.get("color", (200, 200, 200))
        if self.hero_paddle_renderer:
            try:
                # 소형 투명 서피스에 캐릭터를 중앙에 그림
                char_surf = _get_arena_surface(surf_w, surf_h)
                self.hero_paddle_renderer.draw_hero_paddle(
                    char_surf, guard_hero["id"],
                    surf_w // 2, surf_h // 2,
                    48, 24,
                    facing=facing, color=color,
                    scale_mode="preview"
                )
                # 중앙 정렬하여 screen에 blit
                screen.blit(char_surf, (cx - surf_w // 2, cy - surf_h // 2))
            except Exception:
                pygame.draw.circle(screen, color, (cx, cy), 14)
                pygame.draw.circle(screen, (255, 255, 255), (cx, cy), 14, 2)
        else:
            pygame.draw.circle(screen, color, (cx, cy), 14)
            pygame.draw.circle(screen, (255, 255, 255), (cx, cy), 14, 2)

    def reset_active_skills(self):
        """득점 시 호위무사 활성 스킬 리셋"""
        game_state = self.skill_manager.game_state if self.skill_manager else {}
        for hero_id, skills in self.skill_instances.items():
            # 이 호위무사가 어느 쪽인지 판별 (패들 정보 없이 리셋)
            for skill in skills:
                if skill.is_active:
                    try:
                        skill.reset_for_new_round(game_state)
                    except Exception:
                        skill.is_active = False
                        skill.active_timer = 0.0

    def reset(self):
        """배틀 종료 시 전체 초기화"""
        # 애니메이션 상태 초기화
        self.phase_top = None
        self.phase_bottom = None
        self.active_top = None
        self.active_bottom = None
        self.selected_skill_top = None
        self.selected_skill_bottom = None
        self.y_top = TOP_PADDLE_Y
        self.y_bottom = BOTTOM_PADDLE_Y
        self.next_guard_top_idx = 0
        self.next_guard_bottom_idx = 0
        self._bubble_top = None
        self._bubble_bottom = None
        # 순찰 상태 초기화
        self._patrol_target_top = None
        self._patrol_target_bottom = None
        self._patrol_wait_top = 0.0
        self._patrol_wait_bottom = 0.0
        # 2번째 호위무사 초기화
        self._patrol2_top = None
        self._patrol2_bottom = None
        # 매혹 호위무사 초기화
        self._charmed = None

        # 스킬 인스턴스 정리
        game_state = self.skill_manager.game_state if self.skill_manager else {}
        for hero_id, skills in self.skill_instances.items():
            for skill in skills:
                if skill.is_active:
                    try:
                        skill.reset_for_new_round(game_state)
                    except Exception:
                        skill.is_active = False

        self.guard_warriors_top = []
        self.guard_warriors_bottom = []
        self.skill_instances = {}

    @staticmethod
    def _ease_in_out(t):
        """이징 함수 (부드러운 시작/끝)"""
        if t < 0.5:
            return 2 * t * t
        return 1 - (-2 * t + 2) ** 2 / 2


# ============================================================================
# 토너먼트 시스템
# ============================================================================
class ColosseumsArena:
    _active_instance = None  # F8 퍽 선택용 싱글톤 참조

    def __init__(self, screen: pygame.Surface, fonts: Dict, player_gold: int, battle_callback=None):
        """
        Args:
            screen: Pygame 화면
            fonts: 폰트 딕셔너리
            player_gold: 플레이어 골드
            battle_callback: 배틀 시작 콜백 (top_hero, bottom_hero) -> bool
                            None이면 자체 물리 시스템 사용
        """
        ColosseumsArena._active_instance = self
        self.screen = screen
        self.fonts = fonts
        self.player_gold = player_gold
        self.battle_callback = battle_callback  # 실제 게임 엔진 사용 콜백
        self._text_cache: Dict[tuple, tuple] = {}  # (font_key, text, color) → (surf, rect)

        # 토너먼트 상태
        self.state = TournamentState.DIFFICULTY_SELECT
        self.current_round = TournamentRound.QUARTER_FINAL

        # 난이도 설정 (난이도 선택 후 업데이트됨)
        self.difficulty = "normal"
        self.difficulty_multiplier = 1.0
        self.ai_bonus_perks = 0
        self.win_score = WIN_SCORE  # 기본값 5
        self.hover_difficulty_index = -1  # 난이도 카드 호버

        # 대진표 생성 - 상단/하단 영웅 그룹 분리 후 랜덤 매칭
        self.top_heroes = random.sample(TOP_HEROES, 4)  # 상단 패들 영웅 4명 랜덤
        self.bottom_heroes = random.sample(BOTTOM_HEROES, 4)  # 하단 패들 영웅 4명 랜덤
        self.heroes = self.top_heroes + self.bottom_heroes  # 호환성용
        self.matches: Dict[TournamentRound, List[Match]] = {
            TournamentRound.QUARTER_FINAL: [],
            TournamentRound.SEMI_FINAL: [],
            TournamentRound.FINAL: [],
        }
        self._generate_bracket()

        # 상금 시스템 (라운드별 누적 상금)
        self.entry_fee = 500                    # 입장료
        self.entry_fee_paid = False             # 입장료 지불 여부
        self.accumulated_prize = 0              # 현재 획득 상금
        self.round_prizes = {                   # 라운드별 상금 (이기면 이 금액을 획득)
            TournamentRound.QUARTER_FINAL: 1000,
            TournamentRound.SEMI_FINAL: 2000,
            TournamentRound.FINAL: 3000,
        }
        self.recruited_hero = None              # 우승 시 등용한 호위무사 (인게임용)

        # 배팅 정보
        self.selected_match: Optional[Match] = None
        self.bet_hero: Optional[Dict] = None
        self.bet_amount = 0  # 레거시 호환용
        self.total_winnings = 0  # 레거시 호환용

        # 배틀 상태
        self.battle_active = False
        self.top_paddle: Optional[AIPaddleController] = None
        self.bottom_paddle: Optional[AIPaddleController] = None
        self.ball: Optional[ArenaBall] = None
        self.ball_spawn_animation: Optional[BallSpawnAnimation] = None  # 공 생성 애니메이션
        self.spawn_phase = False  # 공 생성 중 여부
        self.score_top = 0
        self.score_bottom = 0

        # 배속 시스템
        self.speed_multiplier = 1  # 1.3x, 2x, 3x
        self.speed_btn_rects = {}  # {multiplier: pygame.Rect}

        # UI 상태
        self.animation_timer = 0
        self.result_display_timer = 0
        self.exit_requested = False
        self.winnings_collected = False

        # 대진표 진출 애니메이션 상태
        self.bracket_anim_timer = 0.0          # 애니메이션 타이머
        self.bracket_anim_phase = 0            # 애니메이션 페이즈 (0: X표시, 1: 선 이동, 2: 완료)
        self.bracket_anim_progress = 0.0       # 애니메이션 진행도 (0.0 ~ 1.0)
        self.bracket_anim_completed_matches = []  # 완료된 매치 목록 (패자 X 표시용)
        self.bracket_anim_advancing_winners = []  # 진출하는 승자 목록 (선 이동용)
        self.bracket_anim_next_round = None    # 다음 라운드 정보
        self.bracket_anim_auto_battle = False  # 애니메이션 후 자동 배틀 진행 여부
        self.bracket_anim_x_delay = 0.6       # 순차 X 매치 간 딜레이
        self.bracket_anim_x_duration = 0.5    # 개별 X 애니메이션 시간
        self.bracket_anim_x_sound_played = set()
        self.bracket_anim_match_positions = {}

        # 투기장 퍽 시스템
        self.hero_perks: Dict[str, list] = {}   # {hero_id: [perk_dict, ...]}
        self.perk_selected_index = 0             # 현재 선택된 퍽 인덱스 (0~2)
        self.perk_anim_timer = 0.0               # 퍽 선택 애니메이션 타이머
        self.perk_anim_phase = "appearing"       # "appearing" / "active" / "selected"
        self.perk_selected_id = None             # 선택 확정된 퍽 ID
        self.perk_card_offsets = [0, 0, 0]       # 슬라이드-인 오프셋 (3장)
        self.perk_particles = []                  # 파티클 효과
        self.perk_frame_count = 0                 # 애니메이션 프레임 카운터
        self.current_perk_options = []            # 현재 표시 중인 랜덤 3개 퍽
        self.hero_has_both_skills: Dict[str, bool] = {}  # 영웅 양쪽 스킬 보유 여부

        # 마우스 호버 상태
        self.hover_perk_index = -1               # 퍽 카드 호버 인덱스 (-1 = 없음)
        self.hover_match_index = -1              # 대진표 매치 박스 호버 인덱스 (-1 = 없음)
        self.hover_btn_id = ""                   # 버튼 호버 ID
        self.hover_line_particles = []           # 호버 시 라인 파티클 이펙트
        self.hover_glow_timer = 0.0              # 호버 글로우 펄스 타이머

        # ============ 초반 셋업 시스템 (감옥 + 비공개 대진표) ============
        self.match_revealed = [False, False, False, False]  # 4매치 공개 상태
        self.selected_match_index = -1           # 플레이어가 선택한 매치 인덱스
        self.initial_setup_done = False          # 초반 셋업(영웅+호위무사 선택) 완료 여부

        # 감옥 시스템 (_remaining_heroes는 _generate_bracket()에서 설정됨)
        self.prison_heroes = []                  # 감옥 영웅 3명 (셔플됨)
        self.prison_selected = None              # 플레이어가 선택한 호위무사
        self.hover_hero_index = -1               # 영웅 선택 호버 인덱스
        self.hover_prison_index = -1             # 감옥 호버 인덱스

        # 플레이어 선택 정보
        self.player_hero = None                  # 플레이어가 선택한 영웅
        self.player_hero_skill_index = -1        # 플레이어 영웅 스킬 인덱스 (0 or 1)
        self.player_guard = None                 # 플레이어 호위무사
        self.player_guard_skill_index = -1       # 호위무사 스킬 인덱스 (0 or 1)
        self.opponent_hero = None                # 상대 영웅
        self.opponent_guard = None               # 상대 호위무사

        # 스킬 랜덤 선택 정보 (모든 영웅)
        # hero_selected_skills는 _generate_bracket()에서 이미 초기화+배정됨
        # 여기서 다시 {}로 덮어쓰면 안 됨!

        # 스킬 연출 애니메이션
        self.skill_reveal_timer = 0.0            # 스킬 연출 타이머
        self.skill_reveal_phase = "rolling"      # "rolling" → "selected" → "done"
        self.skill_reveal_target = None          # 연출 대상 (hero_id)
        self.skill_reveal_result = -1            # 확정된 스킬 인덱스
        self._skill_reveal_last_tick_idx = -1    # 틱 사운드 추적용

        # 매치 공개 애니메이션
        self.match_reveal_timer = 0.0
        self.match_reveal_index = -1

        # 시각 효과 (배경/필러)
        self.arena_background = None
        self.arena_pillar = None
        if VISUAL_ASSETS_AVAILABLE:
            try:
                self.arena_background = AnimatedBackgroundStage30(
                    width=GAME_AREA_WIDTH, height=SCREEN_HEIGHT
                )
                self.arena_pillar = ColosseumFrame(
                    screen_width=SCREEN_WIDTH,
                    screen_height=SCREEN_HEIGHT,
                    game_width=GAME_AREA_WIDTH,
                    game_height=SCREEN_HEIGHT,
                    offset_x=GAME_AREA_X,
                    offset_y=0
                )
            except Exception as e:
                print(f"Arena visual assets init error: {e}")
                self.arena_background = None
                self.arena_pillar = None

        # 영웅 패들 렌더러
        self.hero_paddle_renderer = None
        if HERO_PADDLES_AVAILABLE:
            try:
                self.hero_paddle_renderer = get_hero_paddle_renderer()
            except Exception as e:
                print(f"Hero paddle renderer init error: {e}")
                self.hero_paddle_renderer = None

        # 영웅 스킬 시스템
        self.skill_manager: Optional[HeroSkillManager] = None
        if HERO_SKILLS_AVAILABLE:
            try:
                self.skill_manager = get_skill_manager()
                self.skill_manager.reset()
            except Exception as e:
                print(f"Skill manager init error: {e}")
                self.skill_manager = None

        # 스킬 쿨다운 체크 타이머 (AI가 쿨다운 스킬 사용)
        self.skill_check_timer = 0.0
        self.skill_check_interval = 0.5  # 0.5초마다 체크

        # 말풍선 시스템 (스킬 발동 시 외침)
        self.top_speech_text = ""       # 상단 영웅 말풍선 텍스트
        self.top_speech_timer = 0       # 상단 영웅 말풍선 타이머
        self.bottom_speech_text = ""    # 하단 영웅 말풍선 텍스트
        self.bottom_speech_timer = 0    # 하단 영웅 말풍선 타이머
        self.speech_duration = 90       # 말풍선 표시 시간 (1.5초)

        # === 호위무사 시스템 ===
        self.guard_warrior_map = {}          # hero_id -> [guard hero dicts] (토너먼트 전체 누적)
        self.recalled_guard_map = {}         # hero_id -> guard dict (재소집령으로 복귀한 호위무사, 라운드 간 유지)
        self.former_guards = []              # 교체되어 탈락한 호위무사 목록 (우승 연출용)
        self.guard_warriors_top = []         # 현재 배틀 상단 영웅의 호위무사들
        self.guard_warriors_bottom = []      # 현재 배틀 하단 영웅의 호위무사들
        # 쿨타임
        self.guard_cooldown_top = 0.0
        self.guard_cooldown_bottom = 0.0
        self.guard_cooldown_range = (20.0, 30.0)  # 20~30초 랜덤
        # 등장 애니메이션 상태
        self.guard_active_top = None         # 현재 등장 중인 상단측 호위무사 hero dict
        self.guard_active_bottom = None      # 현재 등장 중인 하단측 호위무사 hero dict
        self.guard_phase_top = None          # "entering" / "casting" / "exiting" / None
        self.guard_phase_bottom = None
        self.guard_anim_timer_top = 0.0
        self.guard_anim_timer_bottom = 0.0
        self.guard_x_top = 0.0              # 현재 X 위치 (애니메이션용)
        self.guard_x_bottom = 0.0
        self.guard_side_top = "left"        # 등장 방향 ("left" or "right")
        self.guard_side_bottom = "right"
        self.guard_selected_skill_top = None     # 선택된 스킬 인스턴스
        self.guard_selected_skill_bottom = None
        # 호위무사 독립 스킬 인스턴스
        self.guard_skill_instances = {}      # hero_id -> [skill1, skill2]
        # GuardWarriorSystem 인스턴스
        self.guard_system = None

        # ============ 관리자 영웅 선택 (F5) ============
        self.admin_hero_select_active = False       # 관리자 영웅 선택 오버레이 활성화 여부
        self.admin_target_match_index = -1          # 수정할 매치 인덱스 (0~3)
        self.admin_selecting_slot = 0               # 0 = 매치 선택 중, 1 = hero1 선택 중, 2 = hero2 선택 중
        self.admin_hero1_pick = None                # 선택된 hero1 (상단)
        self.admin_hero2_pick = None                # 선택된 hero2 (하단)
        self.admin_hover_index = -1                 # 호버 중인 영웅/매치 인덱스
        self.admin_all_heroes = list(ARENA_HEROES)  # 선택 가능한 전체 영웅 목록
        self.admin_scroll_offset = 0                # 스크롤 오프셋 (영웅 많을 때)

    def _render_text(self, font_key: str, text: str, color: tuple):
        """정적 텍스트 렌더링 캐시 (매 프레임 동일 텍스트 재렌더링 방지)"""
        key = (font_key, text, color)
        cached = self._text_cache.get(key)
        if cached is not None:
            return cached
        font = self.fonts.get(font_key)
        if font is None:
            return None, None
        surf, rect = font.render(text, color)
        self._text_cache[key] = (surf, rect)
        return surf, rect

    # ========================================================================
    # 관리자 영웅 선택 (F5) - Admin Hero Select
    # ========================================================================
    def _handle_admin_hero_select_event(self, event: pygame.event.Event) -> bool:
        """관리자 영웅 선택 오버레이 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                # ESC: 단계별 뒤로가기 또는 닫기
                if self.admin_selecting_slot == 2:
                    # hero2 선택 중 → hero1 선택으로 복귀
                    self.admin_selecting_slot = 1
                    self.admin_hero2_pick = None
                    self.admin_hover_index = -1
                elif self.admin_selecting_slot == 1:
                    # hero1 선택 중 → 매치 선택으로 복귀
                    self.admin_selecting_slot = 0
                    self.admin_hero1_pick = None
                    self.admin_hover_index = -1
                else:
                    # 매치 선택 중 → 오버레이 닫기
                    self.admin_hero_select_active = False
                return False

        elif event.type == pygame.MOUSEMOTION:
            self._update_admin_hover(event.pos)

        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                self._handle_admin_click(event.pos)

        return False

    def _update_admin_hover(self, pos):
        """관리자 오버레이 마우스 호버 업데이트"""
        mx, my = pos
        self.admin_hover_index = -1

        if self.admin_selecting_slot == 0:
            # 매치 선택 단계: 4개 매치 버튼 호버
            btn_w, btn_h = 140, 50
            start_y = 280
            for i in range(4):
                bx = SCREEN_WIDTH // 2 - btn_w // 2
                by = start_y + i * (btn_h + 15)
                if bx <= mx <= bx + btn_w and by <= my <= by + btn_h:
                    self.admin_hover_index = i
                    break
        else:
            # 영웅 선택 단계: 영웅 카드 호버
            cols = 3
            card_w, card_h = 200, 80
            gap_x, gap_y = 15, 12
            total_w = cols * card_w + (cols - 1) * gap_x
            start_x = (SCREEN_WIDTH - total_w) // 2
            start_y = 180
            for i, hero in enumerate(self.admin_all_heroes):
                row = i // cols
                col = i % cols
                cx = start_x + col * (card_w + gap_x)
                cy = start_y + row * (card_h + gap_y)
                if cx <= mx <= cx + card_w and cy <= my <= cy + card_h:
                    # 이미 선택된 hero1과 같은 영웅은 hero2 단계에서 제외
                    if self.admin_selecting_slot == 2 and self.admin_hero1_pick:
                        if hero["id"] == self.admin_hero1_pick["id"]:
                            break
                    self.admin_hover_index = i
                    break

    def _handle_admin_click(self, pos):
        """관리자 오버레이 클릭 처리"""
        mx, my = pos

        if self.admin_selecting_slot == 0:
            # 매치 선택 단계
            btn_w, btn_h = 140, 50
            start_y = 280
            for i in range(4):
                bx = SCREEN_WIDTH // 2 - btn_w // 2
                by = start_y + i * (btn_h + 15)
                if bx <= mx <= bx + btn_w and by <= my <= by + btn_h:
                    self.admin_target_match_index = i
                    self.admin_selecting_slot = 1  # hero1 선택으로 진행
                    self.admin_hover_index = -1
                    return
        else:
            # 영웅 선택 단계
            cols = 3
            card_w, card_h = 200, 80
            gap_x, gap_y = 15, 12
            total_w = cols * card_w + (cols - 1) * gap_x
            start_x = (SCREEN_WIDTH - total_w) // 2
            start_y = 180
            for i, hero in enumerate(self.admin_all_heroes):
                row = i // cols
                col = i % cols
                cx = start_x + col * (card_w + gap_x)
                cy = start_y + row * (card_h + gap_y)
                if cx <= mx <= cx + card_w and cy <= my <= cy + card_h:
                    # 이미 선택된 hero1과 같은 영웅은 hero2 단계에서 제외
                    if self.admin_selecting_slot == 2 and self.admin_hero1_pick:
                        if hero["id"] == self.admin_hero1_pick["id"]:
                            return

                    if self.admin_selecting_slot == 1:
                        # hero1 (상단 패들) 선택
                        self.admin_hero1_pick = hero
                        self.admin_selecting_slot = 2  # hero2 선택으로 진행
                        self.admin_hover_index = -1
                    elif self.admin_selecting_slot == 2:
                        # hero2 (하단 패들) 선택 → 매치에 적용
                        self.admin_hero2_pick = hero
                        self._apply_admin_hero_selection()
                    return

    def _apply_admin_hero_selection(self):
        """관리자가 선택한 영웅을 대진표 매치에 적용"""
        idx = self.admin_target_match_index
        if idx < 0 or idx >= len(self.matches[TournamentRound.QUARTER_FINAL]):
            self.admin_hero_select_active = False
            return

        hero1 = self.admin_hero1_pick
        hero2 = self.admin_hero2_pick
        if not hero1 or not hero2:
            self.admin_hero_select_active = False
            return

        match = self.matches[TournamentRound.QUARTER_FINAL][idx]

        # 매치 영웅 교체
        match.hero1 = hero1
        match.hero2 = hero2

        # top/bottom 영웅 목록도 동기화
        if idx < len(self.top_heroes):
            self.top_heroes[idx] = hero1
        if idx < len(self.bottom_heroes):
            self.bottom_heroes[idx] = hero2

        # 스킬 배정 (아직 없으면 랜덤)
        if hero1["id"] not in self.hero_selected_skills:
            self.hero_selected_skills[hero1["id"]] = random.randint(0, 1)
        if hero2["id"] not in self.hero_selected_skills:
            self.hero_selected_skills[hero2["id"]] = random.randint(0, 1)

        print(f"[Admin] 매치 {idx+1} 영웅 변경: {hero1['name']} vs {hero2['name']}")

        # 오버레이 닫기
        self.admin_hero_select_active = False

    def _draw_admin_hero_select(self):
        """관리자 영웅 선택 오버레이 그리기"""
        # 반투명 어두운 배경
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 패널 배경
        panel_w, panel_h = 680, 650
        panel_x = (SCREEN_WIDTH - panel_w) // 2
        panel_y = (SCREEN_HEIGHT - panel_h) // 2
        pygame.draw.rect(self.screen, ET["bg_medium"], (panel_x, panel_y, panel_w, panel_h), border_radius=12)
        pygame.draw.rect(self.screen, ET["gold_medium"], (panel_x, panel_y, panel_w, panel_h), 2, border_radius=12)

        # 타이틀
        if self.fonts and "medium" in self.fonts:
            title_text = "[관리자] 영웅 직접 배치"
            title_color = (255, 100, 100)
            surf, _ = self.fonts["medium"].render(title_text, title_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 15))

        if self.admin_selecting_slot == 0:
            # ========== 매치 선택 단계 ==========
            if self.fonts and "small" in self.fonts:
                hint_text = "수정할 매치를 선택하세요 (ESC: 취소)"
                surf, _ = self.fonts["small"].render(hint_text, ET["text_subtitle"])
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 50))

            btn_w, btn_h = 140, 50
            start_y = 280
            for i in range(4):
                match = self.matches[TournamentRound.QUARTER_FINAL][i]
                bx = SCREEN_WIDTH // 2 - btn_w // 2
                by = start_y + i * (btn_h + 15)
                is_hover = (self.admin_hover_index == i)

                bg_color = ET["card_bg_hover"] if is_hover else ET["card_bg"]
                border_color = ET["gold_bright"] if is_hover else ET["card_border"]
                pygame.draw.rect(self.screen, bg_color, (bx, by, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(self.screen, border_color, (bx, by, btn_w, btn_h), 2, border_radius=8)

                if self.fonts and "small" in self.fonts:
                    label = f"매치 {i+1}: {match.hero1['name']} vs {match.hero2['name']}"
                    text_color = ET["gold_bright"] if is_hover else ET["text_body"]
                    surf, _ = self.fonts["small"].render(label, text_color)
                    self.screen.blit(surf, (bx + btn_w // 2 - surf.get_width() // 2, by + btn_h // 2 - surf.get_height() // 2))
        else:
            # ========== 영웅 선택 단계 ==========
            # 현재 상태 표시
            if self.fonts and "small" in self.fonts:
                match_label = f"매치 {self.admin_target_match_index + 1}"
                if self.admin_selecting_slot == 1:
                    status_text = f"{match_label} - 상단(hero1) 영웅을 선택하세요"
                else:
                    h1_name = self.admin_hero1_pick["name"] if self.admin_hero1_pick else "?"
                    status_text = f"{match_label} - 하단(hero2) 영웅을 선택하세요 (상단: {h1_name})"
                surf, _ = self.fonts["small"].render(status_text, ET["text_subtitle"])
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 50))

                esc_text = "ESC: 이전 단계로"
                surf2, _ = self.fonts["small"].render(esc_text, ET["text_hint"])
                self.screen.blit(surf2, (SCREEN_WIDTH // 2 - surf2.get_width() // 2, panel_y + 72))

            # 영웅 카드 그리드
            cols = 3
            card_w, card_h = 200, 80
            gap_x, gap_y = 15, 12
            total_w = cols * card_w + (cols - 1) * gap_x
            start_x = (SCREEN_WIDTH - total_w) // 2
            start_y = 180

            for i, hero in enumerate(self.admin_all_heroes):
                row = i // cols
                col = i % cols
                cx = start_x + col * (card_w + gap_x)
                cy = start_y + row * (card_h + gap_y)

                # hero2 선택 시 hero1과 같은 영웅은 비활성화
                is_disabled = False
                if self.admin_selecting_slot == 2 and self.admin_hero1_pick:
                    if hero["id"] == self.admin_hero1_pick["id"]:
                        is_disabled = True

                is_hover = (self.admin_hover_index == i) and not is_disabled
                is_hero1_selected = (self.admin_hero1_pick and hero["id"] == self.admin_hero1_pick["id"]
                                     and self.admin_selecting_slot == 2)

                # 카드 배경
                if is_disabled:
                    bg_color = (30, 25, 18)
                    border_color = (60, 50, 35)
                elif is_hero1_selected:
                    bg_color = (40, 60, 40)
                    border_color = ET["selected_border"]
                elif is_hover:
                    bg_color = ET["card_bg_hover"]
                    border_color = ET["gold_bright"]
                else:
                    bg_color = ET["card_bg"]
                    border_color = ET["card_border"]

                pygame.draw.rect(self.screen, bg_color, (cx, cy, card_w, card_h), border_radius=8)
                pygame.draw.rect(self.screen, border_color, (cx, cy, card_w, card_h), 2, border_radius=8)

                # 영웅 색상 바
                bar_alpha = 40 if is_disabled else 180
                color_bar = pygame.Surface((card_w - 16, 4), pygame.SRCALPHA)
                color_bar.fill((*hero["color"], bar_alpha))
                self.screen.blit(color_bar, (cx + 8, cy + 6))

                # 영웅 캐릭터 미리보기
                if self.hero_paddle_renderer:
                    preview_area = pygame.Surface((60, 50), pygame.SRCALPHA)
                    self.hero_paddle_renderer.draw_hero_paddle(
                        preview_area, hero["id"],
                        30, 25, 55, 40,
                        facing="down", color=hero["color"], scale_mode="preview"
                    )
                    if is_disabled:
                        preview_area.set_alpha(50)
                    self.screen.blit(preview_area, (cx + 5, cy + 18))

                # 영웅 이름
                if self.fonts and "small" in self.fonts:
                    h_color = hero["color"]
                    brightness = sum(h_color) / 3
                    name_color = h_color if brightness > 80 else (
                        min(255, h_color[0] + 100),
                        min(255, h_color[1] + 100),
                        min(255, h_color[2] + 100)
                    )
                    if is_disabled:
                        name_color = tuple(c // 3 for c in name_color)
                    surf, _ = self.fonts["small"].render(hero["name"], name_color)
                    self.screen.blit(surf, (cx + 70, cy + 15))

                # 영웅 칭호 + 스타일
                if self.fonts and "small" in self.fonts:
                    title_text = f"{hero.get('title', '')} ({hero['style'].value})"
                    title_color = (60, 50, 35) if is_disabled else ET["text_hint"]
                    surf, _ = self.fonts["small"].render(title_text, title_color)
                    self.screen.blit(surf, (cx + 70, cy + 38))

                # hero1 선택 표시
                if is_hero1_selected:
                    if self.fonts and "small" in self.fonts:
                        tag_surf, _ = self.fonts["small"].render("상단", (100, 255, 100))
                        self.screen.blit(tag_surf, (cx + card_w - tag_surf.get_width() - 10, cy + 8))

    def _select_difficulty(self, diff_index: int):
        """난이도 선택 적용"""
        diff = ARENA_DIFFICULTIES[diff_index]
        self.difficulty = diff["key"]
        self.entry_fee = diff["entry_fee"]
        self.difficulty_multiplier = diff["prize_multiplier"]
        self.ai_bonus_perks = diff["ai_bonus_perks"]
        self.win_score = diff["win_score"]
        # 상금 재계산 (기본 상금 × 난이도 배율)
        base_prizes = {
            TournamentRound.QUARTER_FINAL: 1000,
            TournamentRound.SEMI_FINAL: 2000,
            TournamentRound.FINAL: 3000,
        }
        self.round_prizes = {k: int(v * self.difficulty_multiplier) for k, v in base_prizes.items()}
        self.state = TournamentState.BRACKET_VIEW

    def _generate_bracket(self):
        """8강 대진표 생성 - 전체 영웅 셔플 후 대진표 8명 + 감옥 후보 분배

        전체 ARENA_HEROES를 셔플하여:
        - 앞 8명 → 대진표 4매치 (중복 없음)
        - 나머지 → 감옥 호위무사 후보 (대진표와 중복 없음)
        - 모든 영웅에게 스킬 2개 중 1개 랜덤 배정
        """
        # 현재 시간 기반 로컬 Random 인스턴스로 완전 랜덤화 (시드 고정 문제 방지)
        local_rng = random.Random(time.time())

        # 전체 영웅 셔플 → 앞 8명 대진표, 나머지 감옥 후보
        shuffled = list(ARENA_HEROES)
        local_rng.shuffle(shuffled)
        bracket_heroes = shuffled[:8]
        self._remaining_heroes = shuffled[8:]  # 감옥 후보 풀 (대진표와 절대 중복 없음)

        # 4개의 매치 생성 (0-1, 2-3, 4-5, 6-7 페어링)
        self.top_heroes = []
        self.bottom_heroes = []

        for i in range(4):
            hero_a = bracket_heroes[i * 2]
            hero_b = bracket_heroes[i * 2 + 1]

            # 랜덤으로 상단/하단 결정
            if local_rng.random() < 0.5:
                top_hero, bottom_hero = hero_a, hero_b
            else:
                top_hero, bottom_hero = hero_b, hero_a

            self.top_heroes.append(top_hero)
            self.bottom_heroes.append(bottom_hero)

            # hero1 = 상단 패들 (화면 위), hero2 = 하단 패들 (화면 아래)
            match = Match(top_hero, bottom_hero, i)
            self.matches[TournamentRound.QUARTER_FINAL].append(match)

        # 감옥 영웅은 PRISON_SELECT 진입 시 _remaining_heroes에서 선정
        self.prison_heroes = []

        # 모든 영웅(대진표 + 감옥 후보)에게 스킬 2개 중 1개 랜덤 배정
        self.hero_selected_skills = {}
        for hero in shuffled:
            self.hero_selected_skills[hero["id"]] = local_rng.randint(0, 1)

    def _advance_to_next_round(self):
        """다음 라운드 진출"""
        if self.current_round == TournamentRound.QUARTER_FINAL:
            # 8강 → 4강
            winners = [m.winner for m in self.matches[TournamentRound.QUARTER_FINAL]]

            # === 호위무사 할당: 8강 패자 → 승자의 호위무사 ===
            bet_id = self.bet_hero["id"] if self.bet_hero else ""
            for match in self.matches[TournamentRound.QUARTER_FINAL]:
                if match.winner:
                    loser = match.hero1 if match.winner == match.hero2 else match.hero2
                    winner_id = match.winner["id"]
                    # bet_hero의 호위무사는 생포 알림/선택 UI에서 이미 확정됨 → 중복 추가 방지
                    if winner_id == bet_id:
                        continue
                    if winner_id not in self.guard_warrior_map:
                        self.guard_warrior_map[winner_id] = []
                    # 이미 생포 알림에서 추가된 경우 중복 방지
                    if loser not in self.guard_warrior_map[winner_id]:
                        self.guard_warrior_map[winner_id].append(loser)
                    print(f"[Guard] 호위무사 할당: {loser['name']} → {match.winner['name']}의 호위무사")

            # 포지션 유지: top 영웅이 hero1, bottom 영웅이 hero2
            self.matches[TournamentRound.SEMI_FINAL] = [
                self._create_positioned_match(winners[0], winners[1], 0),
                self._create_positioned_match(winners[2], winners[3], 1),
            ]
            # AI 4강 진출자에게 랜덤 퍽 1개씩 부여 (배팅 영웅 제외)
            for w in winners:
                if w and (not self.bet_hero or w["id"] != self.bet_hero["id"]):
                    self._assign_ai_perks(w, 1 + self.ai_bonus_perks)
            self.current_round = TournamentRound.SEMI_FINAL
        elif self.current_round == TournamentRound.SEMI_FINAL:
            # 4강 → 결승
            winners = [m.winner for m in self.matches[TournamentRound.SEMI_FINAL]]

            # === 호위무사 할당: 4강 패자 → 승자의 추가 호위무사 ===
            bet_id = self.bet_hero["id"] if self.bet_hero else ""
            for match in self.matches[TournamentRound.SEMI_FINAL]:
                if match.winner:
                    loser = match.hero1 if match.winner == match.hero2 else match.hero2
                    winner_id = match.winner["id"]
                    # bet_hero의 호위무사는 생포 알림/선택 UI에서 이미 확정됨 → 중복 추가 방지
                    if winner_id == bet_id:
                        continue
                    if winner_id not in self.guard_warrior_map:
                        self.guard_warrior_map[winner_id] = []
                    # 이미 생포 알림에서 추가된 경우 중복 방지
                    if loser not in self.guard_warrior_map[winner_id]:
                        self.guard_warrior_map[winner_id].append(loser)
                    print(f"[Guard] 호위무사 추가 할당: {loser['name']} → {match.winner['name']}의 호위무사 (총 {len(self.guard_warrior_map[winner_id])}명)")

            self.matches[TournamentRound.FINAL] = [
                self._create_positioned_match(winners[0], winners[1], 0),
            ]
            # AI 결승 진출자에게 추가 랜덤 퍽 1개 부여 (배팅 영웅 제외)
            for w in winners:
                if w and (not self.bet_hero or w["id"] != self.bet_hero["id"]):
                    self._assign_ai_perks(w, 1 + self.ai_bonus_perks)
            self.current_round = TournamentRound.FINAL

    def _init_guard_warriors_for_battle(self, match: Match):
        """배틀 시작 시 호위무사 시스템 초기화"""
        hero1_guards = self.guard_warrior_map.get(match.hero1["id"], [])
        hero2_guards = self.guard_warrior_map.get(match.hero2["id"], [])

        # GuardWarriorSystem 인스턴스 생성
        self.guard_system = GuardWarriorSystem(
            skill_manager=self.skill_manager,
            hero_paddle_renderer=self.hero_paddle_renderer,
        )

        # 호위무사 할당 (hero1=상단, hero2=하단 기준)
        # 주의: start_battle()에서 bet_hero에 따라 top/bottom이 바뀔 수 있음
        # 실제 배치는 _run_real_game_battle()에서 글로벌 변수로 전달
        self.guard_warriors_top = hero1_guards
        self.guard_warriors_bottom = hero2_guards

        print(f"[Guard] 배틀 호위무사 초기화 | "
              f"{match.hero1['name']}: {[g['name'] for g in hero1_guards]} | "
              f"{match.hero2['name']}: {[g['name'] for g in hero2_guards]}")

    def _create_positioned_match(self, hero_a: Dict, hero_b: Dict, match_id: int) -> Match:
        """랜덤으로 hero1(상단)/hero2(하단) 결정

        변경사항:
        - 기존: 영웅의 원래 position 필드에 따라 배치
        - 변경: 항상 랜덤 배치 (모든 영웅이 상단/하단 모두 가능)
        - 스킬 방향은 is_top 플래그로 자동 조정됨
        """
        # 항상 랜덤 배치
        if random.random() < 0.5:
            return Match(hero_a, hero_b, match_id)
        else:
            return Match(hero_b, hero_a, match_id)

    def _calculate_odds(self, hero1: Dict, hero2: Dict) -> Tuple[float, float]:
        """배당률 계산"""
        # 능력치 기반 승률 계산
        power1 = hero1["speed"] + hero1["reaction"] + hero1["power"] + hero1["accuracy"]
        power2 = hero2["speed"] + hero2["reaction"] + hero2["power"] + hero2["accuracy"]

        total = power1 + power2
        prob1 = power1 / total
        prob2 = power2 / total

        # 배당률 (약간의 마진 포함)
        odds1 = round(1 / prob1 * 0.9, 2)
        odds2 = round(1 / prob2 * 0.9, 2)

        return odds1, odds2

    def _run_real_game_battle(self, top_hero: dict, bottom_hero: dict) -> bool:
        """실제 게임 엔진으로 배틀 실행 (pingfighter.main 호출)"""
        try:
            import pingfighter

            # 투기장 모드 글로벌 변수 설정
            pingfighter.arena_mode_enabled = True
            pingfighter.arena_battle_result = None  # 배틀 결과 초기화
            pingfighter.arena_top_hero = top_hero
            pingfighter.arena_bottom_hero = bottom_hero

            # 영웅 패들 렌더러 초기화
            try:
                pingfighter.arena_hero_paddle_renderer = get_hero_paddle_renderer()
            except Exception:
                pingfighter.arena_hero_paddle_renderer = None

            # 영웅 스킬 시스템 초기화 (스킬 선택 정보 반영)
            try:
                from downtown.hero_skills import get_skill_manager, HERO_SKILLS_AVAILABLE
                if HERO_SKILLS_AVAILABLE:
                    pingfighter.arena_skill_manager = get_skill_manager()
                    pingfighter.arena_skill_manager.reset()
                    # 추가훈련 퍽으로 양쪽 스킬 보유 시 -1 (모든 스킬 활성화)
                    _top_idx = -1 if self.hero_has_both_skills.get(top_hero["id"], False) else self.hero_selected_skills.get(top_hero["id"], -1)
                    _bottom_idx = -1 if self.hero_has_both_skills.get(bottom_hero["id"], False) else self.hero_selected_skills.get(bottom_hero["id"], -1)
                    pingfighter.arena_skill_manager.init_hero_skills(top_hero["id"], is_top=True, selected_skill_index=_top_idx)
                    pingfighter.arena_skill_manager.init_hero_skills(bottom_hero["id"], is_top=False, selected_skill_index=_bottom_idx)
                    pingfighter.arena_skill_check_timer = 0.0
            except Exception as e:
                print(f"Arena skill manager init error: {e}")
                import traceback
                traceback.print_exc()
                pingfighter.arena_skill_manager = None

            # === 호위무사 시스템 설정 (4강/결승) ===
            if self.current_round in (TournamentRound.SEMI_FINAL, TournamentRound.FINAL):
                try:
                    # top_hero/bottom_hero 기준으로 호위무사 할당
                    top_guards = self.guard_warrior_map.get(top_hero["id"], [])
                    bottom_guards = self.guard_warrior_map.get(bottom_hero["id"], [])
                    if top_guards or bottom_guards:
                        guard_system = GuardWarriorSystem(
                            skill_manager=pingfighter.arena_skill_manager,
                            hero_paddle_renderer=pingfighter.arena_hero_paddle_renderer,
                        )
                        guard_system.setup(top_guards, bottom_guards, skill_selections=self.hero_selected_skills)
                        pingfighter.arena_guard_system = guard_system
                        print(f"[Guard] pingfighter 호위무사 시스템 설정 완료")
                    else:
                        pingfighter.arena_guard_system = None
                except Exception as e:
                    print(f"[Guard] 호위무사 시스템 설정 오류: {e}")
                    pingfighter.arena_guard_system = None
            else:
                pingfighter.arena_guard_system = None

            # AI 플레이 모드 활성화
            pingfighter.player_ai_enabled = True

            # AI 컨트롤러 리셋
            try:
                from ai.player_ai import get_player_ai_controller
                get_player_ai_controller().on_stage_start()
            except Exception:
                pass

            # 스테이지 30에서 게임 실행
            result = pingfighter.main(30)

            return result

        except Exception as e:
            print(f"Real game battle error: {e}")
            import traceback
            traceback.print_exc()
            return random.choice([True, False])

        finally:
            # 투기장 모드 변수 초기화
            try:
                pingfighter.arena_mode_enabled = False
                pingfighter.arena_battle_result = None  # 배틀 결과 초기화
                pingfighter.arena_top_hero = None
                pingfighter.arena_bottom_hero = None
                pingfighter.arena_hero_paddle_renderer = None
                pingfighter.arena_skill_manager = None
                pingfighter.arena_skill_check_timer = 0.0
                # 호위무사 시스템 초기화
                if hasattr(pingfighter, 'arena_guard_system') and pingfighter.arena_guard_system:
                    pingfighter.arena_guard_system.reset()
                pingfighter.arena_guard_system = None
            except Exception:
                pass

    # ========================================================================
    # 초반 셋업 메서드 (영웅 선택 → 스킬 랜덤 → 감옥 → 게임 시작)
    # ========================================================================

    def _select_hero(self, chosen_hero, opponent_hero):
        """영웅 선택 확정 → 공격 퍼포먼스 → 스킬 랜덤 선택 연출로 전환"""
        self.player_hero = chosen_hero
        self.opponent_hero = opponent_hero
        self.bet_hero = chosen_hero  # 호환성: bet_hero도 설정

        # 공격 퍼포먼스 애니메이션 시작
        # (완료 후 update()에서 SKILL_REVEAL로 전환)
        heroes = [self.selected_match.hero1, self.selected_match.hero2]
        self._hero_select_anim_phase = "attack_motion"
        self._hero_select_anim_index = 0 if chosen_hero == heroes[0] else 1
        self._hero_select_anim_timer = 0.0
        self._hero_select_swing_triggered = False

    def _select_guard(self, guard_hero, prison_index):
        """감옥에서 호위무사 선택 → 철창 열림 애니메이션 시작"""
        self.player_guard = guard_hero
        self.prison_selected = guard_hero

        # 나머지 감옥 영웅 배정
        remaining = [h for i, h in enumerate(self.prison_heroes) if i != prison_index]
        if remaining:
            self.opponent_guard = remaining[0]  # 상대 호위무사

        # 철창 열림 + 공격 모션 애니메이션 시작
        # (완료 후 update()에서 GUARD_SKILL_REVEAL로 전환)
        _load_prison_open_sound()
        if _prison_open_sound:
            _prison_open_sound.play()
        self._prison_opening_phase = "bars_opening"
        self._prison_opening_index = prison_index
        self._prison_opening_timer = 0.0
        self._prison_attack_particles = []

    def _prepare_prison_candidates(self):
        """대진표에 포함되지 않은 나머지 영웅에서 감옥 후보 3명 선정"""
        remaining = getattr(self, '_remaining_heroes', [])
        # 나머지 영웅 중 3명을 감옥 후보로 선정 (대진표와 절대 중복 없음)
        pool_size = min(3, len(remaining))
        self.prison_heroes = random.sample(remaining, pool_size) if pool_size > 0 else []

    def _finalize_setup_and_start(self):
        """초반 셋업 완료 → 다른 매치 자동 진행 → VS 프리뷰 → 배틀"""
        self.initial_setup_done = True

        # 선택한 매치 공개 상태 유지
        if self.selected_match_index >= 0:
            self.match_revealed[self.selected_match_index] = True

        # 호위무사로 차출된 영웅 ID 수집
        guard_ids = set()
        if self.player_guard:
            guard_ids.add(self.player_guard["id"])
        if self.opponent_guard:
            guard_ids.add(self.opponent_guard["id"])

        # 나머지 3개 매치 자동 진행 (호위무사 차출 매치는 부전승)
        for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
            if i == self.selected_match_index:
                continue  # 플레이어 매치는 제외
            if match.completed:
                continue

            h1_drafted = match.hero1["id"] in guard_ids
            h2_drafted = match.hero2["id"] in guard_ids

            if h1_drafted and not h2_drafted:
                # hero1이 호위무사로 차출 → hero2 부전승
                match.set_result(match.hero2, 0, 5)
            elif h2_drafted and not h1_drafted:
                # hero2가 호위무사로 차출 → hero1 부전승
                match.set_result(match.hero1, 5, 0)
            else:
                # 둘 다 차출 안됨 → 일반 자동 진행
                self._auto_resolve_match(match)
            self.match_revealed[i] = True  # 결과 공개

        # 호위무사 맵 설정 (플레이어 + 상대)
        if self.player_hero and self.player_guard:
            player_id = self.player_hero["id"]
            if player_id not in self.guard_warrior_map:
                self.guard_warrior_map[player_id] = []
            self.guard_warrior_map[player_id].append(self.player_guard)

        if self.opponent_hero and self.opponent_guard:
            opponent_id = self.opponent_hero["id"]
            if opponent_id not in self.guard_warrior_map:
                self.guard_warrior_map[opponent_id] = []
            self.guard_warrior_map[opponent_id].append(self.opponent_guard)

        # VS 프리뷰 시작
        self._start_vs_preview()

    def _auto_resolve_match(self, match):
        """스탯 기반으로 매치 승패 자동 결정 (AI 시뮬레이션)"""
        h1 = match.hero1
        h2 = match.hero2
        # 종합 전투력 계산
        h1_power = h1["speed"] + h1["power"] + h1["accuracy"] + h1["reaction"]
        h2_power = h2["speed"] + h2["power"] + h2["accuracy"] + h2["reaction"]
        # 랜덤 변동 추가
        h1_score = h1_power + random.uniform(-0.8, 0.8)
        h2_score = h2_power + random.uniform(-0.8, 0.8)

        ws = self.win_score
        if h1_score >= h2_score:
            winner = h1
            score1, score2 = ws, random.randint(1, ws - 1)
        else:
            winner = h2
            score1, score2 = random.randint(1, ws - 1), ws

        match.set_result(winner, score1, score2)

    def _start_vs_preview(self, show_buttons=False):
        """VS 매치업 미리보기 시작
        show_buttons=False: 2초 후 자동 배틀 시작 (8강 첫 배틀)
        show_buttons=True: VS 화면 + 계속/나가기 버튼 (4강/결승 진출 후)
        """
        self.vs_preview_timer = 0.0
        self.vs_preview_progress = 0.0
        self.vs_preview_show_buttons = show_buttons
        self.state = TournamentState.VS_PREVIEW

    def start_battle(self, match: Match):
        """배틀 시작 - 실제 게임 엔진 사용 (pingfighter.main 스테이지 30)"""
        print(f"[DEBUG 반칙왕] start_battle() 호출됨! match={match.hero1.get('name','?')} vs {match.hero2.get('name','?')}")
        self.selected_match = match

        # 배틀 활성화 (중요: _end_battle()에서 체크하므로 반드시 설정해야 함)
        self.battle_active = True

        # 입장료는 manager.py에서 이미 차감됨 (이중 차감 방지)
        # 첫 배틀 시작 표시만 함
        if not self.entry_fee_paid:
            self.entry_fee_paid = True

        # 점수 리셋
        self.score_top = 0
        self.score_bottom = 0

        # 배속 리셋 (매 경기 1.3x로 초기화)
        self.speed_multiplier = 1

        # === 호위무사 초기화 (초반 셋업 완료 시 8강부터, 아니면 4강/결승만) ===
        if self.initial_setup_done or self.current_round in (TournamentRound.SEMI_FINAL, TournamentRound.FINAL):
            self._init_guard_warriors_for_battle(match)
        else:
            self.guard_warriors_top = []
            self.guard_warriors_bottom = []
            self.guard_skill_instances = {}

        # 배팅한 영웅이 하단(플레이어 AI)이 되도록 배치
        # 플레이어 AI는 항상 하단을 제어하므로, bet_hero가 하단이어야 배팅한 영웅이 유리
        if self.bet_hero == match.hero1:
            # bet_hero가 hero1이면 순서를 바꿔서 bet_hero가 하단이 되도록
            top_hero = match.hero2
            bottom_hero = match.hero1
        else:
            # bet_hero가 hero2이면 그대로 (hero2가 하단)
            top_hero = match.hero1
            bottom_hero = match.hero2

        # 실제 게임 엔진으로 배틀 실행
        try:
            if self.battle_callback:
                # battle_callback 사용 시 호위무사 데이터를 pingfighter에 저장
                # (start_arena_battle 내부에서 스킬 매니저 초기화 후 설정됨)
                try:
                    import pingfighter
                    # ★ 퍽/스킬 데이터를 먼저 전달 (호위무사 디버그 출력 실패 시에도 퍽 데이터 보존)
                    pingfighter._arena_pending_perk_data = self
                    pingfighter.arena_battle_arena_obj = self  # F8 퍽 선택용 직접 참조
                    pingfighter._arena_pending_skill_selections = self.hero_selected_skills
                    pingfighter._arena_pending_both_skills = self.hero_has_both_skills
                    # 호위무사 데이터 전달
                    if self.initial_setup_done or self.current_round in (TournamentRound.SEMI_FINAL, TournamentRound.FINAL):
                        pingfighter._arena_pending_top_guards = self.guard_warrior_map.get(top_hero["id"], [])
                        pingfighter._arena_pending_bottom_guards = self.guard_warrior_map.get(bottom_hero["id"], [])
                        # 재소집령 디버그: 배틀 시작 시 호위무사 수 확인
                        try:
                            _top_g = pingfighter._arena_pending_top_guards
                            _bot_g = pingfighter._arena_pending_bottom_guards
                            _recalled = self.recalled_guard_map
                            print(f"[Guard 재소집령] 배틀 시작 | 라운드={self.current_round} | "
                                  f"상단={[g.get('name','?') for g in _top_g]}({len(_top_g)}명) | "
                                  f"하단={[g.get('name','?') for g in _bot_g]}({len(_bot_g)}명) | "
                                  f"recalled_map={{{k: v.get('name','?') for k,v in _recalled.items()}}}")
                        except Exception as e:
                            print(f"[Guard] 디버그 출력 실패: {e}")
                    else:
                        pingfighter._arena_pending_top_guards = []
                        pingfighter._arena_pending_bottom_guards = []
                except Exception as e:
                    print(f"[Arena] 배틀 데이터 전달 실패: {e}")
                    import traceback
                    traceback.print_exc()
                # 스킬 선택 인덱스를 영웅 dict에 직접 삽입 (글로벌 변수 문제 방지)
                # 양쪽 스킬 보유 영웅은 -1 (모든 스킬 활성화)
                top_id = top_hero["id"]
                bottom_id = bottom_hero["id"]
                top_hero["_selected_skill_idx"] = -1 if self.hero_has_both_skills.get(top_id, False) else self.hero_selected_skills.get(top_id, -1)
                bottom_hero["_selected_skill_idx"] = -1 if self.hero_has_both_skills.get(bottom_id, False) else self.hero_selected_skills.get(bottom_id, -1)
                result = self.battle_callback(top_hero, bottom_hero)
            else:
                result = self._run_real_game_battle(top_hero, bottom_hero)

            # 디스플레이 모드 전환 시 SCREEN이 재생성될 수 있으므로 참조 갱신
            try:
                import pingfighter as _pf
                if hasattr(_pf, 'SCREEN') and _pf.SCREEN is not None:
                    self.screen = _pf.SCREEN
            except Exception:
                pass

            # 결과 처리: True = 하단 승리, False = 상단 승리, None = ESC 나가기
            if result is None:
                # ESC 나가기 → 토너먼트 종료
                self.battle_active = False
                self.exit_requested = True
                return
            elif result:
                winner = bottom_hero  # 하단 승리 = 배팅한 영웅 승리
                self.score_top = 0
                self.score_bottom = self.win_score
            else:
                winner = top_hero  # 상단 승리 = 배팅한 영웅 패배
                self.score_top = self.win_score
                self.score_bottom = 0

            print(f"[DEBUG 반칙왕] battle_callback 결과: result={result}, winner={winner.get('name','?')}")
            self._end_battle(winner)
            print(f"[DEBUG 반칙왕] _end_battle 후 state={self.state}")

        except Exception as e:
            print(f"Arena battle error: {e}")
            import traceback
            traceback.print_exc()
            # 에러 시 랜덤 승자 결정
            winner = random.choice([match.hero1, match.hero2])
            self.score_top = self.win_score if winner == match.hero1 else 0
            self.score_bottom = self.win_score if winner == match.hero2 else 0
            self._end_battle(winner)

    def update_battle(self, dt: float = 1/60) -> bool:
        """배틀 업데이트, 완료 시 True 반환"""
        if not self.battle_active:
            return False

        # 배속 적용
        dt *= self.speed_multiplier

        # === 달빛 베기 화면 정지 체크 (스킬 업데이트 전에 체크!) ===
        is_frozen = False
        if self.skill_manager:
            is_frozen = self.skill_manager.game_state.get('dark_slash_freeze', False)

        # 스킬 시스템 업데이트 (화면 정지 중에도 스킬 이펙트는 업데이트)
        if self.skill_manager and self.top_paddle and self.bottom_paddle and self.ball:
            self._update_skills(dt)

        # 날씨 파티클 업데이트 (용의 날개 강풍 이펙트)
        if WEATHER_EVENT_AVAILABLE and weather_module.weather_event_active and weather_module.weather_event_type == "gust":
            weather_module.update_weather_particles(SCREEN_WIDTH, SCREEN_HEIGHT)

        # 공 생성 애니메이션 처리
        if self.spawn_phase and self.ball_spawn_animation:
            if self.ball_spawn_animation.update(dt):
                # 애니메이션 완료 - 공 실제 생성
                self.spawn_phase = False
                direction = self.ball_spawn_animation.serve_direction
                self.ball.reset(direction=direction)

            # 스폰 중에도 패들은 중앙으로 이동
            self.top_paddle.update(
                GAME_AREA_X + GAME_AREA_WIDTH // 2,  # 중앙
                SCREEN_HEIGHT // 2,
                0.0, 0.0, dt
            )
            self.bottom_paddle.update(
                GAME_AREA_X + GAME_AREA_WIDTH // 2,
                SCREEN_HEIGHT // 2,
                0.0, 0.0, dt
            )
            return False

        # [DEBUG] 폭탄 넉백 상태 체크 (is_frozen 확인용)
        if self.skill_manager:
            _dbg_gs = self.skill_manager.game_state
            for _dbg_pfx in ['top_paddle', 'bottom_paddle']:
                if _dbg_gs.get(f'{_dbg_pfx}_bomb_kb_active', False):
                    print(f"[BombKB-DEBUG] PRE-CHECK → {_dbg_pfx} kb_active=True, is_frozen={is_frozen}, spawn_phase={self.spawn_phase}")

        if not is_frozen:
            # AI 패들 업데이트 (실제 게임과 동일한 파라미터)
            self.top_paddle.update(
                self.ball.x, self.ball.y,
                self.ball.vx, self.ball.vy, dt
            )
            self.bottom_paddle.update(
                self.ball.x, self.ball.y,
                self.ball.vx, self.ball.vy, dt
            )

            # 💣 폭탄 서프라이즈 넉백 처리 (AI 이동 후 적용, 최종 위치 오버라이드)
            if self.skill_manager:
                gs_kb = self.skill_manager.game_state
                for prefix, paddle in [('top_paddle', self.top_paddle), ('bottom_paddle', self.bottom_paddle)]:
                    if gs_kb.get(f'{prefix}_bomb_kb_active', False):
                        kb_vel = gs_kb.get(f'{prefix}_bomb_kb_vel', 0)
                        kb_dir = gs_kb.get(f'{prefix}_bomb_kb_dir', 0)
                        kb_frames = gs_kb.get(f'{prefix}_bomb_kb_frames', 0)
                        print(f"[BombKB-DEBUG] APPLY → prefix={prefix}, kb_dir={kb_dir}, kb_vel={kb_vel:.1f}, kb_frames={kb_frames}, paddle_x_before={paddle.x:.1f}, stunned={paddle.is_stunned}")
                        if kb_frames > 0 and kb_vel > 0:
                            # 프레임 기반 넉백 (다이너마이트와 동일 방식)
                            old_x = paddle.x
                            paddle.x += kb_dir * kb_vel * dt * 60
                            kb_frames -= 1
                            # 감속 (후반부 감속)
                            if kb_frames < 6:
                                kb_vel *= 0.75
                            gs_kb[f'{prefix}_bomb_kb_vel'] = kb_vel
                            gs_kb[f'{prefix}_bomb_kb_frames'] = kb_frames
                            # 경계 클램핑
                            paddle.x = max(GAME_AREA_X, min(paddle.x,
                                           GAME_AREA_X + GAME_AREA_WIDTH - getattr(paddle, 'width', 80)))
                            print(f"[BombKB-DEBUG] MOVED → {old_x:.1f} → {paddle.x:.1f} (delta={paddle.x - old_x:.1f})")
                        else:
                            gs_kb[f'{prefix}_bomb_kb_active'] = False
                            print(f"[BombKB-DEBUG] DEACTIVATED → frames={kb_frames}, vel={kb_vel:.1f}")

            # === 모래감옥 위치 강제 클램핑 (AI 이동 후 적용) ===
            if self.skill_manager:
                gs = self.skill_manager.game_state
                prison_cx = gs.get('sand_prison_center_x')
                prison_range = gs.get('sand_prison_range')
                if prison_cx is not None and prison_range is not None:
                    p_left = prison_cx - prison_range
                    p_right = prison_cx + prison_range
                    if gs.get('top_paddle_sand_prison', False):
                        pw = getattr(self.top_paddle, 'width', 80)
                        self.top_paddle.x = max(p_left, min(self.top_paddle.x, p_right - pw))
                    if gs.get('bottom_paddle_sand_prison', False):
                        pw = getattr(self.bottom_paddle, 'width', 80)
                        self.bottom_paddle.x = max(p_left, min(self.bottom_paddle.x, p_right - pw))

            # 공 업데이트
            scorer = self.ball.update(dt)

            # === 달빛 베기 벽 반사 시 즉시 상대 방향으로 꺾기 ===
            if self.skill_manager and self.ball.wall_bounced:
                game_state = self.skill_manager.game_state
                if game_state.get('dark_slash_active', False):
                    # 시전자 방향에 따라 상대 방향으로 즉시 꺾음
                    caster_is_top = game_state.get('dark_slash_caster_is_top', False)
                    if caster_is_top:
                        # 상단이 시전 → 하단 방향(양수)으로 강제
                        self.ball.vy = abs(self.ball.vy)
                    else:
                        # 하단이 시전 → 상단 방향(음수)으로 강제
                        self.ball.vy = -abs(self.ball.vy)
                    # 벽 반사 후 달빛 베기 효과 종료
                    game_state['dark_slash_active'] = False
                    print(f"[DarkSlash] 벽 반사 → 상대 방향으로 즉시 꺾음! vy={self.ball.vy:.1f}")

            # 패들 충돌 체크 + 스킬 발동
            if self.ball.check_paddle_collision(self.top_paddle):
                self._on_ball_hit(self.selected_match.hero1["id"], self.top_paddle, self.bottom_paddle)
                # 무기 휘두르기 애니메이션 트리거
                if self.hero_paddle_renderer:
                    self.hero_paddle_renderer.trigger_weapon_swing(self.selected_match.hero1["id"])
                # 관중 반응 (약한 흥분)
                if self.arena_pillar and hasattr(self.arena_pillar, 'trigger_excitement'):
                    self.arena_pillar.trigger_excitement(intensity=0.3, duration=0.5)
            if self.ball.check_paddle_collision(self.bottom_paddle):
                self._on_ball_hit(self.selected_match.hero2["id"], self.bottom_paddle, self.top_paddle)
                # 무기 휘두르기 애니메이션 트리거
                if self.hero_paddle_renderer:
                    self.hero_paddle_renderer.trigger_weapon_swing(self.selected_match.hero2["id"])
                # 관중 반응 (약한 흥분)
                if self.arena_pillar and hasattr(self.arena_pillar, 'trigger_excitement'):
                    self.arena_pillar.trigger_excitement(intensity=0.3, duration=0.5)
        else:
            # 화면 정지 중 - 공/패들 업데이트 없음
            scorer = None

        # 득점 처리
        if scorer:
            # 방어 로직: 배틀이 이미 종료되었으면 점수 증가 방지
            if not self.battle_active:
                return True

            if scorer == "top":
                self.score_top += 1
            else:
                self.score_bottom += 1

            # 관중 흥분 이벤트 트리거
            if self.arena_pillar and hasattr(self.arena_pillar, 'trigger_excitement'):
                self.arena_pillar.trigger_excitement(intensity=1.0, duration=2.5)

            # === 모든 활성 스킬 상태 리셋 (득점 시) ===
            # 스킬 사운드 즉시 중지 (라운드 전환)
            for snd in ColosseumsArena._skill_sound_cache.values():
                if snd:
                    snd.stop()

            if self.skill_manager:
                self.skill_manager.reset_active_skills_for_round()

                # 🔮 난쟁이마술 등으로 축소된 패들 크기 복원
                if self.top_paddle:
                    self.top_paddle.paddle_scale = 1.0
                    # 귀신발걸음 y축 이동 중이면 강제 종료 및 원위치 복귀
                    if self.top_paddle.ghost_step_active:
                        self.top_paddle.end_ghost_step()
                if self.bottom_paddle:
                    self.bottom_paddle.paddle_scale = 1.0
                    if self.bottom_paddle.ghost_step_active:
                        self.bottom_paddle.end_ghost_step()

            # 승리 체크 (5점 선취, 4:4부터 듀스)
            if self._check_winner():
                return True

            # 방어 로직: _check_winner에서 배틀이 종료되었으면 리턴
            if not self.battle_active:
                return True

            # 공 리셋 (애니메이션으로 시작)
            self.ball.visible = False
            self.ball_spawn_animation = BallSpawnAnimation()
            self.ball_spawn_animation.start(serve_direction=1 if scorer == "bottom" else -1)
            self.spawn_phase = True

        return False

    def _update_skills(self, dt: float):
        """스킬 시스템 업데이트"""
        if not self.skill_manager:
            return

        # 스킬 매니저 업데이트
        self.skill_manager.update(dt, self.top_paddle, self.bottom_paddle, self.ball)

        # 상태 효과 적용 (패들별)
        game_state = self.skill_manager.game_state

        # 상단 패들 상태 효과
        self.top_paddle.is_stunned = game_state.get('top_paddle_stunned', False)
        self.top_paddle.slow_multiplier = game_state.get('top_paddle_slow_amount', 1.0) if game_state.get('top_paddle_slowed', False) else 1.0
        self.top_paddle.is_confused = game_state.get('top_paddle_confused', False)
        self.top_paddle.paddle_scale = game_state.get('top_paddle_shrink_scale', 1.0) if game_state.get('top_paddle_shrink', False) else 1.0
        self.top_paddle.gravity_drift = game_state.get('top_paddle_gravity_drift', 0.0)

        # 하단 패들 상태 효과
        self.bottom_paddle.is_stunned = game_state.get('bottom_paddle_stunned', False)
        self.bottom_paddle.slow_multiplier = game_state.get('bottom_paddle_slow_amount', 1.0) if game_state.get('bottom_paddle_slowed', False) else 1.0
        self.bottom_paddle.is_confused = game_state.get('bottom_paddle_confused', False)
        self.bottom_paddle.paddle_scale = game_state.get('bottom_paddle_shrink_scale', 1.0) if game_state.get('bottom_paddle_shrink', False) else 1.0
        self.bottom_paddle.gravity_drift = game_state.get('bottom_paddle_gravity_drift', 0.0)


        # 🔫 개틀링 버스트 견착/발사 시 영웅 패들 연동
        if self.hero_paddle_renderer:
            hero_positions = game_state.get('hero_positions', {})
            for hero_id, is_top in hero_positions.items():
                side = 'top' if is_top else 'bottom'
                state = self.hero_paddle_renderer._get_state(hero_id)
                state['gatling_firing'] = game_state.get(f'gatling_burst_active_{side}', False)
                state['gatling_recoil'] = game_state.get(f'gatling_recoil_{side}', 0)
                state['gatling_mounting'] = game_state.get(f'gatling_mounting_{side}', False)
                state['gatling_mount_progress'] = game_state.get(f'gatling_mount_progress_{side}', 0.0)
                state['gatling_dismounting'] = game_state.get(f'gatling_dismounting_{side}', False)
                state['gatling_dismount_progress'] = game_state.get(f'gatling_dismount_progress_{side}', 0.0)

        # 💣 폭탄 서프라이즈 넉백은 update_battle()에서 AI 이동 후 적용 (paddle.update 이후)

        # 🔥 귀신발걸음 y축 이동 트리거 처리
        if game_state.get('ghost_step_start_top', False):
            self.top_paddle.start_ghost_step()
            game_state['ghost_step_start_top'] = False  # 플래그 초기화 (한번만 발동)

        if game_state.get('ghost_step_start_bottom', False):
            self.bottom_paddle.start_ghost_step()
            game_state['ghost_step_start_bottom'] = False  # 플래그 초기화

        # 쿨다운 스킬 자동 사용 (AI)
        self.skill_check_timer += dt
        if self.skill_check_timer >= self.skill_check_interval:
            self.skill_check_timer = 0
            self._try_use_cooldown_skills()

    def _on_ball_hit(self, hero_id: str, caster_paddle, target_paddle):
        """공을 칠 때 ON_BALL_HIT 스킬 발동"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE:
            return

        # === 달빛 베기 반격 처리 ===
        # 상대가 공을 반격하면 달빛 베기로 인한 공 가속을 원래 속도로 복귀
        game_state = self.skill_manager.game_state
        if game_state.get('dark_slash_active', False):
            # 달빛 베기 시전자와 현재 타자가 다르면 (= 상대가 반격)
            dark_slash_caster_is_top = game_state.get('dark_slash_caster_is_top', False)
            if dark_slash_caster_is_top != caster_paddle.is_top:
                # 무겐의 DarkSlash 스킬 찾아서 on_opponent_hit 호출
                mugen_skills = self.skill_manager.hero_skills.get('mugen', [])
                for skill in mugen_skills:
                    if skill.skill_id == 'dark_slash' and hasattr(skill, 'on_opponent_hit'):
                        skill.on_opponent_hit(self.ball, game_state)
                        break

        result = self.skill_manager.try_use_skill(
            hero_id,
            SkillTrigger.ON_BALL_HIT,
            caster_paddle,
            target_paddle,
            self.ball
        )
        # 스킬이 성공적으로 발동되면 사운드 재생 + 말풍선 표시
        if result and 'skill_korean_name' in result:
            self._play_skill_sound(result)
            is_top = result.get('caster_is_top', caster_paddle.is_top)
            self.show_speech_bubble(is_top, result['skill_korean_name'])

    def _try_use_cooldown_skills(self):
        """쿨다운 완료된 ON_COOLDOWN 스킬 자동 사용"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE:
            return

        # 상단 영웅 스킬
        if self.selected_match and random.random() < 0.7:  # 70% 확률로 사용 시도
            result = self.skill_manager.try_use_skill(
                self.selected_match.hero1["id"],
                SkillTrigger.ON_COOLDOWN,
                self.top_paddle,
                self.bottom_paddle,
                self.ball
            )
            # 스킬 발동 시 사운드 재생 + 말풍선 표시
            if result and 'skill_korean_name' in result:
                self._play_skill_sound(result)
                self.show_speech_bubble(True, result['skill_korean_name'])

        # 하단 영웅 스킬
        if self.selected_match and random.random() < 0.7:
            result = self.skill_manager.try_use_skill(
                self.selected_match.hero2["id"],
                SkillTrigger.ON_COOLDOWN,
                self.bottom_paddle,
                self.top_paddle,
                self.ball
            )
            # 스킬 발동 시 사운드 재생 + 말풍선 표시
            if result and 'skill_korean_name' in result:
                self._play_skill_sound(result)
                self.show_speech_bubble(False, result['skill_korean_name'])

    def show_speech_bubble(self, is_top: bool, skill_name: str):
        """영웅 말풍선 표시"""
        if is_top:
            self.top_speech_text = skill_name + "!"
            self.top_speech_timer = self.speech_duration
        else:
            self.bottom_speech_text = skill_name + "!"
            self.bottom_speech_timer = self.speech_duration

    def _draw_speech_bubbles(self):
        """영웅 말풍선 그리기"""
        # 상단 영웅 말풍선
        if self.top_speech_timer > 0 and self.top_paddle and self.top_speech_text:
            self._draw_single_speech_bubble(
                self.top_paddle.x + PADDLE_WIDTH // 2,
                self.top_paddle.y + PADDLE_HEIGHT + 10,
                self.top_speech_text,
                is_top=True
            )
            self.top_speech_timer -= 1

        # 하단 영웅 말풍선
        if self.bottom_speech_timer > 0 and self.bottom_paddle and self.bottom_speech_text:
            self._draw_single_speech_bubble(
                self.bottom_paddle.x + PADDLE_WIDTH // 2,
                self.bottom_paddle.y - 50,
                self.bottom_speech_text,
                is_top=False
            )
            self.bottom_speech_timer -= 1

    def _draw_single_speech_bubble(self, x: float, y: float, text: str, is_top: bool):
        """개별 말풍선 그리기"""
        try:
            # 폰트 설정 (한글 지원 Pretendard 폰트)
            import os
            import sys
            font = pygame.font.Font(None, 24)
            try:
                if hasattr(sys, '_MEIPASS'):
                    base = sys._MEIPASS
                else:
                    base = os.path.dirname(os.path.dirname(__file__))
                font_candidates = [
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf"),
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Regular.ttf"),
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "Pretendard-Bold.otf"),
                    os.path.join(base, "fonts", "NanumSquareB.ttf"),
                ]
                for font_path in font_candidates:
                    if os.path.exists(font_path):
                        font = pygame.font.Font(font_path, 20)
                        break
            except Exception:
                pass

            text_surface = font.render(text, True, (0, 0, 0))

            # 말풍선 크기 계산
            padding = 12
            bubble_width = text_surface.get_width() + padding * 2
            bubble_height = text_surface.get_height() + padding

            # 말풍선 위치
            bubble_x = int(x - bubble_width // 2)
            bubble_y = int(y)

            # 화면 경계 체크
            bubble_x = max(GAME_AREA_X + 5, min(bubble_x, GAME_AREA_X + GAME_AREA_WIDTH - bubble_width - 5))

            # 말풍선 표면 생성
            bubble_surface = _get_arena_surface(bubble_width + 15, bubble_height + 25)

            # 그림자
            shadow_rect = pygame.Rect(3, 3, bubble_width, bubble_height)
            pygame.draw.rect(bubble_surface, (0, 0, 0, 60), shadow_rect, border_radius=10)

            # 메인 말풍선
            main_rect = pygame.Rect(0, 0, bubble_width, bubble_height)
            pygame.draw.rect(bubble_surface, (255, 255, 255), main_rect, border_radius=10)
            pygame.draw.rect(bubble_surface, (50, 50, 50), main_rect, 2, border_radius=10)

            # 말풍선 꼬리 (위/아래 방향)
            if is_top:
                # 상단 영웅: 꼬리가 위쪽 (영웅을 향함)
                tail_points = [
                    (bubble_width // 2 - 8, 2),
                    (bubble_width // 2 + 8, 2),
                    (bubble_width // 2, -12)
                ]
            else:
                # 하단 영웅: 꼬리가 아래쪽 (영웅을 향함)
                tail_points = [
                    (bubble_width // 2 - 8, bubble_height - 2),
                    (bubble_width // 2 + 8, bubble_height - 2),
                    (bubble_width // 2, bubble_height + 12)
                ]

            pygame.draw.polygon(bubble_surface, (255, 255, 255), tail_points)
            pygame.draw.polygon(bubble_surface, (50, 50, 50), tail_points, 2)

            # 텍스트 그리기
            bubble_surface.blit(text_surface, (padding, padding // 2))

            # 애니메이션 (살짝 흔들림)
            timer = self.top_speech_timer if is_top else self.bottom_speech_timer
            float_offset = _sin(timer * 0.15) * 2

            # 화면에 그리기
            self.screen.blit(bubble_surface, (bubble_x, bubble_y + float_offset))

        except Exception as e:
            # 오류 시 무시
            pass

    def _check_winner(self) -> bool:
        """승자 체크 (5점 선취, 듀스 룰)"""
        s1, s2 = self.score_top, self.score_bottom

        # 방어 로직: selected_match가 없으면 강제 종료
        if not self.selected_match:
            print(f"[Arena] ERROR: selected_match is None! 강제 배틀 종료")
            self.battle_active = False
            self.state = TournamentState.BRACKET_VIEW
            return True

        # 방어 로직: 점수가 비정상적으로 높으면 강제 종료 (최대 15점)
        MAX_SCORE = 15
        if s1 >= MAX_SCORE or s2 >= MAX_SCORE:
            print(f"[Arena] 점수 상한 도달 ({s1}:{s2}) - 강제 종료")
            winner = self.selected_match.hero1 if s1 > s2 else self.selected_match.hero2
            self._end_battle(winner)
            return True

        # 듀스 상황 (둘 다 4점 이상): 2점 차이로 승리
        if s1 >= 4 and s2 >= 4:
            if abs(s1 - s2) >= 2:
                winner = self.selected_match.hero1 if s1 > s2 else self.selected_match.hero2
                self._end_battle(winner)
                return True
        # 일반 상황: 5점 선취
        else:
            if s1 >= self.win_score:
                self._end_battle(self.selected_match.hero1)
                return True
            if s2 >= self.win_score:
                self._end_battle(self.selected_match.hero2)
                return True

        return False

    def _end_battle(self, winner: Dict):
        """배틀 종료 - 누적 상금 시스템"""
        print(f"[DEBUG 반칙왕] _end_battle() 호출됨! winner={winner.get('name', '?')}, battle_active={self.battle_active}")
        # 방어 로직: 이미 종료된 배틀이면 무시
        if not self.battle_active:
            print(f"[DEBUG 반칙왕] battle_active=False → 즉시 리턴!")
            return

        self.battle_active = False

        # 모든 스킬 사운드 즉시 중지
        for snd in getattr(ColosseumsArena, '_skill_sound_cache', {}).values():
            if snd:
                snd.stop()

        # 방어 로직: selected_match 체크
        if not self.selected_match:
            print(f"[Arena] ERROR: selected_match is None in _end_battle!")
            self.state = TournamentState.BRACKET_VIEW
            return

        # === 반칙왕 퍽: 라운드 레벨로 이동됨 (pingfighter.py에서 실점 시 처리) ===
        _bet_name = self.bet_hero.get('name', '?') if self.bet_hero else None
        _win_name = winner.get('name', '?')
        if self.bet_hero and winner != self.bet_hero:
            print(f"[반칙왕] 배팅 영웅 '{_bet_name}' 매치 패배 (승자: '{_win_name}')")
        elif self.bet_hero:
            print(f"[반칙왕] 배팅 영웅 '{_bet_name}' 매치 승리!")

        self.selected_match.set_result(winner, self.score_top, self.score_bottom)

        # 상금 시스템 - 승패 결과 처리 (누적식)
        if self.bet_hero:
            if winner == self.bet_hero:
                # 승리 - 해당 라운드 상금을 누적
                round_prize = self.round_prizes.get(self.current_round, 0)
                self.accumulated_prize += round_prize
                self.total_winnings = self.accumulated_prize
            else:
                # 패배 - 누적 상금 몰수, 입장료만 잃음
                self.accumulated_prize = 0
                self.total_winnings = -self.entry_fee

        # 나머지 경기 자동 결정 (랜덤)
        self._auto_decide_remaining_matches()

        self.state = TournamentState.RESULT
        self.result_display_timer = 180  # 3초

        # 전투 종료 후 대기실 BGM 복구
        try:
            import bgm_manager
            bgm_manager.play_colosseum_room_bgm()
        except Exception:
            pass

    def _auto_decide_remaining_matches(self):
        """현재 라운드의 나머지 경기를 랜덤으로 결정"""
        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            if not match.completed:
                # 호위무사 보너스: 보유 수에 따른 승률 보정 (4강/결승)
                guard_count_1 = len(self.guard_warrior_map.get(match.hero1["id"], []))
                guard_count_2 = len(self.guard_warrior_map.get(match.hero2["id"], []))
                bonus_1 = guard_count_1 * 0.05  # 호위무사 1명당 5% 보정
                bonus_2 = guard_count_2 * 0.05
                # 상성 보너스 (hero1 기준)
                style_bonus = get_style_matchup(match.hero1["style"], match.hero2["style"])
                prob_1 = 0.5 + bonus_1 - bonus_2 + style_bonus
                prob_1 = max(0.2, min(0.8, prob_1))  # 20%~80% 제한

                # 보정된 확률로 승자 결정
                winner = match.hero1 if random.random() < prob_1 else match.hero2
                # 랜덤 스코어 (승자가 win_score점, 패자는 0~(win_score-1)점)
                ws = self.win_score
                if winner == match.hero1:
                    score1 = ws
                    score2 = random.randint(0, ws - 1)
                else:
                    score1 = random.randint(0, ws - 1)
                    score2 = ws
                match.set_result(winner, score1, score2)
                guard_info = f" (호위무사: {guard_count_1} vs {guard_count_2})" if guard_count_1 or guard_count_2 else ""

    def _auto_select_bet_hero_match(self):
        """배팅한 영웅이 포함된 경기를 자동 선택하고 바로 배틀 시작"""
        if not self.bet_hero:
            self.state = TournamentState.BRACKET_VIEW
            return

        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            if match.completed:
                continue
            # 배팅한 영웅이 이 경기에 있는지 확인
            if match.hero1 == self.bet_hero or match.hero2 == self.bet_hero:
                self.selected_match = match
                # 영웅 재선택 없이 바로 배틀 시작
                self.start_battle(match)
                return

        # 배팅 영웅을 찾지 못한 경우 (이론상 불가능)
        self.state = TournamentState.BRACKET_VIEW

    def _prepare_next_match(self):
        """배팅한 영웅이 포함된 다음 경기 준비 (배틀 시작 없이)"""
        if not self.bet_hero:
            return

        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            if match.completed:
                continue
            # 배팅한 영웅이 이 경기에 있는지 확인
            if match.hero1 == self.bet_hero or match.hero2 == self.bet_hero:
                self.selected_match = match
                return

    def update(self, dt: float):
        """메인 업데이트"""
        self.animation_timer += dt
        self.hover_glow_timer += dt

        # 호버 라인 파티클 업데이트
        for p in self.hover_line_particles:
            p['life'] -= dt; p['x'] += p['vx'] * dt; p['y'] += p['vy'] * dt
            p['alpha'] = max(0, p['alpha'] - 200 * dt)
        self.hover_line_particles[:] = [p for p in self.hover_line_particles if p['life'] > 0]

        # 시각 효과 업데이트
        if self.arena_background:
            ball_x = self.ball.x if self.ball else None
            ball_y = self.ball.y if self.ball else None
            self.arena_background.update(dt, ball_x, ball_y)
        if self.arena_pillar:
            self.arena_pillar.update(dt)

        # 영웅 패들 렌더러 업데이트
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.update(dt)
            # 이동 애니메이션 추적
            if self.top_paddle and self.selected_match:
                self.hero_paddle_renderer.update_movement(
                    self.selected_match.hero1["id"],
                    self.top_paddle.x + PADDLE_WIDTH // 2,
                    dt
                )
            if self.bottom_paddle and self.selected_match:
                self.hero_paddle_renderer.update_movement(
                    self.selected_match.hero2["id"],
                    self.bottom_paddle.x + PADDLE_WIDTH // 2,
                    dt
                )

        # ======== 초반 셋업 상태 업데이트 ========
        if self.state == TournamentState.MATCH_REVEAL:
            # 매치 공개 카드 플립 애니메이션 (1.2초)
            self.match_reveal_timer += dt
            if self.match_reveal_timer >= 1.2:
                if self.match_reveal_index >= 0:
                    self.match_revealed[self.match_reveal_index] = True
                self.state = TournamentState.HERO_SELECT

        elif self.state == TournamentState.HERO_SELECT:
            # 영웅 선택 후 공격 퍼포먼스 + 스킬 룰렛 (같은 화면)
            anim_phase = getattr(self, '_hero_select_anim_phase', None)
            if anim_phase == "attack_motion":
                self._hero_select_anim_timer += dt
                timer = self._hero_select_anim_timer
                if timer >= 1.2:
                    # 공격 애니 완료 → 같은 화면 하단에서 스킬 룰렛 시작
                    self._hero_select_anim_phase = "skill_rolling"
                    chosen_hero = self.player_hero
                    self.player_hero_skill_index = self.hero_selected_skills.get(
                        chosen_hero["id"], 0)
                    self.skill_reveal_timer = 0.0
                    self.skill_reveal_phase = "rolling"
                    self.skill_reveal_target = chosen_hero["id"]
                    self.skill_reveal_result = self.player_hero_skill_index
                    self._skill_reveal_last_tick_idx = -1
            elif anim_phase == "skill_rolling":
                self.skill_reveal_timer += dt
                if self.skill_reveal_phase == "rolling" and self.skill_reveal_timer >= 3.5:
                    self.skill_reveal_phase = "selected"
                    self._hero_select_anim_phase = "skill_selected"
                    self.skill_reveal_selected_timer = 0.0
                    self._skill_reveal_particles = []
                    _load_gacha_result_sound()
                    if _gacha_result_sound:
                        _gacha_result_sound.play()
            elif anim_phase == "skill_selected":
                self.skill_reveal_selected_timer = getattr(self, 'skill_reveal_selected_timer', 0) + dt
                self.skill_reveal_timer += dt

        elif self.state == TournamentState.SKILL_REVEAL:
            # 스킬 랜덤 선택 연출 (리얼 룰렛: 빠름→느림→빠름→매우느림 3.5초 + 확정 1.5초)
            self.skill_reveal_timer += dt
            if self.skill_reveal_phase == "rolling" and self.skill_reveal_timer >= 3.5:
                self.skill_reveal_phase = "selected"
                self.skill_reveal_selected_timer = 0.0
                self._skill_reveal_particles = []  # 선택 이펙트 파티클 초기화
                # 최종 선택 사운드 (가챠 결과음)
                _load_gacha_result_sound()
                if _gacha_result_sound:
                    _gacha_result_sound.play()
            elif self.skill_reveal_phase == "selected":
                self.skill_reveal_selected_timer = getattr(self, 'skill_reveal_selected_timer', 0) + dt
                # 자동 전환 없음 - 클릭으로만 진행

        elif self.state == TournamentState.PRISON_SELECT:
            # 철창 열림 + 공격 모션 애니메이션 업데이트
            opening_phase = getattr(self, '_prison_opening_phase', None)
            if opening_phase:
                self._prison_opening_timer += dt
                timer = self._prison_opening_timer

                # 파티클 업데이트
                particles = getattr(self, '_prison_attack_particles', [])
                for p in particles:
                    p['x'] += p['vx'] * dt
                    p['y'] += p['vy'] * dt
                    p['vy'] += 120 * dt  # 중력
                    p['alpha'] -= 180 * dt
                self._prison_attack_particles = [p for p in particles if p['alpha'] > 0]

                if opening_phase == "bars_opening" and timer >= 1.5:
                    self._prison_opening_phase = "attack_motion"
                    self._prison_swing_triggered = False  # 무기 스윙 트리거 플래그 초기화
                elif opening_phase == "attack_motion" and timer >= 2.5:
                    # 공격 애니 완료 → 같은 화면 하단에서 스킬 룰렛 시작
                    self._prison_opening_phase = "skill_rolling"
                    guard_hero = self.player_guard
                    self.player_guard_skill_index = self.hero_selected_skills.get(
                        guard_hero["id"], 0)
                    self.skill_reveal_timer = 0.0
                    self.skill_reveal_phase = "rolling"
                    self.skill_reveal_target = guard_hero["id"]
                    self.skill_reveal_result = self.player_guard_skill_index
                    self._skill_reveal_last_tick_idx = -1
                elif opening_phase == "skill_rolling":
                    self.skill_reveal_timer += dt
                    if self.skill_reveal_phase == "rolling" and self.skill_reveal_timer >= 3.5:
                        self.skill_reveal_phase = "selected"
                        self._prison_opening_phase = "skill_selected"
                        self.skill_reveal_selected_timer = 0.0
                        self._skill_reveal_particles = []
                        _load_gacha_result_sound()
                        if _gacha_result_sound:
                            _gacha_result_sound.play()
                elif opening_phase == "skill_selected":
                    self.skill_reveal_selected_timer = getattr(self, 'skill_reveal_selected_timer', 0) + dt
                    self.skill_reveal_timer += dt

        elif self.state == TournamentState.GUARD_SKILL_REVEAL:
            # 호위무사 스킬 랜덤 선택 연출 (클릭 대기 방식)
            self.skill_reveal_timer += dt
            if self.skill_reveal_phase == "rolling" and self.skill_reveal_timer >= 3.5:
                self.skill_reveal_phase = "selected"
                self.skill_reveal_selected_timer = 0.0
                self._skill_reveal_particles = []
                _load_gacha_result_sound()
                if _gacha_result_sound:
                    _gacha_result_sound.play()
            elif self.skill_reveal_phase == "selected":
                self.skill_reveal_selected_timer = getattr(self, 'skill_reveal_selected_timer', 0) + dt
                # 자동 전환 없음 - 클릭으로만 진행

        elif self.state == TournamentState.VS_PREVIEW:
            # VS 매치업 미리보기
            self.vs_preview_timer += dt
            vs_preview_duration = 2.0
            self.vs_preview_progress = min(1.0, self.vs_preview_timer / vs_preview_duration)
            if not getattr(self, 'vs_preview_show_buttons', False):
                # 버튼 없는 모드: 2초 후 자동 배틀 시작
                if self.vs_preview_timer >= vs_preview_duration:
                    self.start_battle(self.selected_match)
            # 버튼 있는 모드: 클릭 대기 (자동 시작 안함)

        elif self.state == TournamentState.BATTLE:
            self.update_battle(dt)
        elif self.state == TournamentState.RESULT:
            self.result_display_timer -= 1
            if self.result_display_timer <= 0:
                # 다음 단계 결정

                # 배팅한 영웅이 패배했으면 토너먼트 종료
                if self.bet_hero and self.selected_match and self.selected_match.winner != self.bet_hero:
                    self.state = TournamentState.TOURNAMENT_END
                elif self.current_round == TournamentRound.FINAL:
                    # 결승전 종료
                    final_matches = self.matches.get(TournamentRound.FINAL, [])
                    final_match = final_matches[0] if final_matches else None
                    is_champion = final_match and final_match.winner == self.bet_hero
                    if is_champion:
                        # 우승! → 축하 연출
                        self.victory_timer = 0.0
                        self.victory_confetti = []
                        self.state = TournamentState.VICTORY_CELEBRATION
                    else:
                        # 결승 패배 → 바로 종료
                        self.state = TournamentState.TOURNAMENT_END
                else:
                    # 승리 - 호위무사 생포 알림 후 대진표 애니메이션
                    bet_hero_loser = None
                    if self.bet_hero and self.selected_match:
                        match = self.selected_match
                        if match.winner == self.bet_hero:
                            bet_hero_loser = match.hero1 if match.winner == match.hero2 else match.hero2

                    if bet_hero_loser:
                        # 호위무사 생포 알림 먼저 표시
                        self.guard_notify_hero = bet_hero_loser
                        self.guard_notify_owner = self.bet_hero
                        self.guard_notify_timer = 0.0
                        self.guard_notify_progress = 0.0
                        # 생포한 호위무사를 즉시 guard_warrior_map에 추가
                        # (호위무사 선택 화면에서 참조하기 위함)
                        bet_id = self.bet_hero["id"]
                        if bet_id not in self.guard_warrior_map:
                            self.guard_warrior_map[bet_id] = []
                        if bet_hero_loser not in self.guard_warrior_map[bet_id]:
                            self.guard_warrior_map[bet_id].append(bet_hero_loser)
                        self.guard_notify_total = len(self.guard_warrior_map[bet_id])
                        self.state = TournamentState.GUARD_NOTIFY
                    else:
                        # 호위무사 없으면 퍽 선택으로
                        self._start_perk_select()

        elif self.state == TournamentState.GUARD_NOTIFY:
            # 호위무사 생포 알림 (2.5초)
            self.guard_notify_timer += dt
            guard_notify_duration = 2.5
            self.guard_notify_progress = min(1.0, self.guard_notify_timer / guard_notify_duration)
            if self.guard_notify_timer >= guard_notify_duration:
                # 알림 끝 → 호위무사 2명 이상이면 선택 화면, 아니면 퍽 선택
                bet_id = self.bet_hero["id"] if self.bet_hero else ""
                guards = self.guard_warrior_map.get(bet_id, [])
                if len(guards) >= 2:
                    self._start_guard_select()
                else:
                    self._start_perk_select()

        elif self.state == TournamentState.GUARD_SELECT:
            # 호위무사 선택 화면 애니메이션
            self.guard_select_timer += dt
            # 인라인 스킬 룰렛 phase 업데이트
            guard_anim = getattr(self, '_guard_select_anim_phase', None)
            if guard_anim == "skill_rolling":
                self.skill_reveal_timer += dt
                if self.skill_reveal_phase == "rolling" and self.skill_reveal_timer >= 3.5:
                    self.skill_reveal_phase = "selected"
                    self._guard_select_anim_phase = "skill_selected"
                    self.skill_reveal_selected_timer = 0.0
                    self._skill_reveal_particles = []
                    _load_gacha_result_sound()
                    if _gacha_result_sound:
                        _gacha_result_sound.play()
            elif guard_anim == "skill_selected":
                self.skill_reveal_selected_timer = getattr(self, 'skill_reveal_selected_timer', 0) + dt
                self.skill_reveal_timer += dt

        elif self.state == TournamentState.PERK_SELECT:
            self.perk_anim_timer += dt
            self.perk_frame_count += 1
            # 파티클 업데이트
            for p in self.perk_particles:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['alpha'] = max(0, p['alpha'] - 0.8)
            self.perk_particles[:] = [p for p in self.perk_particles if p['alpha'] > 0]
            if self.perk_anim_phase == "appearing":
                # 슬라이드-인 이징
                easing = 0.12
                num_options = len(self.current_perk_options)
                for k in range(num_options):
                    self.perk_card_offsets[k] += (0 - self.perk_card_offsets[k]) * easing
                if all(abs(o) < 3 for o in self.perk_card_offsets[:num_options]):
                    self.perk_card_offsets = [0] * num_options
                    self.perk_anim_phase = "active"
            elif self.perk_anim_phase == "selected":
                if self.perk_frame_count > 25:
                    # 퍽 선택 완료 → 라운드 종료 (계속/수령 선택)
                    self.state = TournamentState.ROUND_END

        elif self.state == TournamentState.TENACITY_RETRY:
            # 반칙왕 퍽 재시작 연출 (2초 대기 후 재시작)
            self.tenacity_timer += dt
            if self.tenacity_timer >= 2.0:
                print(f"[DEBUG 반칙왕] TENACITY_RETRY 2초 경과 → start_battle 호출!")
                self.tenacity_triggered = False
                # 배틀 재시작
                self.start_battle(self.selected_match)

        elif self.state == TournamentState.VICTORY_CELEBRATION:
            self.victory_timer += dt

        elif self.state == TournamentState.BRACKET_ANIMATION:
            self._update_bracket_animation(dt)

    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리, 종료 시 True 반환"""
        # ============ 관리자 영웅 선택 오버레이 이벤트 처리 ============
        if self.admin_hero_select_active:
            return self._handle_admin_hero_select_event(event)

        if event.type == pygame.KEYDOWN:
            # F5: 관리자 영웅 선택 모드 (초반 대진표 화면에서만)
            if event.key == pygame.K_F5:
                if (self.state in (TournamentState.BRACKET_VIEW, TournamentState.SELECT_MATCH)
                        and not self.initial_setup_done
                        and self.current_round == TournamentRound.QUARTER_FINAL):
                    self.admin_hero_select_active = True
                    self.admin_selecting_slot = 0  # 매치 선택부터 시작
                    self.admin_target_match_index = -1
                    self.admin_hero1_pick = None
                    self.admin_hero2_pick = None
                    self.admin_hover_index = -1
                    return False

            if event.key == pygame.K_ESCAPE:
                if self.state == TournamentState.BATTLE:
                    return False  # 배틀 중에는 나갈 수 없음
                if self.state == TournamentState.PERK_SELECT:
                    return False  # 퍽 선택 중에는 나갈 수 없음
                if self.state == TournamentState.ROUND_END:
                    return False  # 라운드 종료 선택 중에는 나갈 수 없음
                if self.state == TournamentState.GUARD_SELECT:
                    return False  # 호위무사 선택 중에는 나갈 수 없음
                if self.state in (TournamentState.MATCH_REVEAL, TournamentState.HERO_SELECT,
                                  TournamentState.SKILL_REVEAL, TournamentState.PRISON_SELECT,
                                  TournamentState.GUARD_SKILL_REVEAL):
                    return False  # 초반 셋업 중에는 나갈 수 없음
                self.exit_requested = True
                return True

            # 배틀 중 배속 변경 (1x / 1.5x / 2x / 3x)
            if self.state == TournamentState.BATTLE:
                if event.key == pygame.K_1:
                    self.speed_multiplier = 1
                elif event.key == pygame.K_2:
                    self.speed_multiplier = 1.5
                elif event.key == pygame.K_3:
                    self.speed_multiplier = 2
                elif event.key == pygame.K_4:
                    self.speed_multiplier = 3

            # 호위무사 선택 키보드 처리
            if self.state == TournamentState.GUARD_SELECT and self.guard_select_timer > 0.5:
                # 스킬 룰렛 애니메이션 중에는 키보드 입력 무시
                guard_anim_kb = getattr(self, '_guard_select_anim_phase', None)
                if guard_anim_kb == "skill_selected":
                    if event.key in (pygame.K_SPACE, pygame.K_RETURN):
                        self._guard_select_anim_phase = None
                        self.skill_reveal_phase = "done"
                        self._start_perk_select()
                elif guard_anim_kb:
                    pass  # 룰렛 진행 중 키 무시
                # 경고 다이얼로그가 열려 있으면 다이얼로그 입력 처리
                elif getattr(self, 'guard_confirm_showing', False):
                    if event.key == pygame.K_LEFT:
                        self.guard_confirm_selected = 0
                    elif event.key == pygame.K_RIGHT:
                        self.guard_confirm_selected = 1
                    elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                        if self.guard_confirm_selected == 0:  # 예
                            self.guard_confirm_showing = False
                            self._confirm_guard_select(self.guard_confirm_index)
                        else:  # 아니오
                            self.guard_confirm_showing = False
                    elif event.key == pygame.K_ESCAPE:
                        self.guard_confirm_showing = False
                else:
                    if event.key == pygame.K_LEFT:
                        self.guard_select_hover = 0
                    elif event.key == pygame.K_RIGHT:
                        self.guard_select_hover = 1
                    elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                        if self.guard_select_hover >= 0:
                            self._try_guard_select(self.guard_select_hover)

            # 퍽 선택 키보드 처리
            if self.state == TournamentState.PERK_SELECT and self.perk_anim_phase == "active":
                if event.key == pygame.K_LEFT:
                    self.perk_selected_index = max(0, self.perk_selected_index - 1)
                elif event.key == pygame.K_RIGHT:
                    self.perk_selected_index = min(len(self.current_perk_options) - 1, self.perk_selected_index + 1)
                elif event.key in (pygame.K_SPACE, pygame.K_RETURN):
                    self._confirm_perk_selection()

        elif event.type == pygame.MOUSEMOTION:
            self._update_hover(event.pos)

        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 좌클릭
                self._handle_click(event.pos)

        return self.exit_requested

    def _handle_click(self, pos: Tuple[int, int]):
        """클릭 처리"""
        mx, my = pos

        # 배속 버튼 클릭 처리
        if self.state == TournamentState.BATTLE:
            for multiplier, rect in self.speed_btn_rects.items():
                if rect.collidepoint(mx, my):
                    self.speed_multiplier = multiplier
                    return

        # 호위무사 선택 클릭 처리
        if self.state == TournamentState.GUARD_SELECT and self.guard_select_timer > 0.5:
            # 인라인 스킬 룰렛 phase 처리
            guard_anim = getattr(self, '_guard_select_anim_phase', None)
            if guard_anim == "skill_selected":
                # 스킬 확정 후 클릭 → 다음 단계로
                self._guard_select_anim_phase = None
                self.skill_reveal_phase = "done"
                self._start_perk_select()
                return
            if guard_anim:
                return  # 스킬 룰렛 애니메이션 중 클릭 무시

            # 경고 다이얼로그가 열려 있으면 다이얼로그 버튼 클릭 처리
            if getattr(self, 'guard_confirm_showing', False):
                dialog_w, dialog_h = 420, 200
                dx = SCREEN_WIDTH // 2 - dialog_w // 2
                dy = SCREEN_HEIGHT // 2 - dialog_h // 2
                btn_w, btn_h = 100, 40
                btn_y = dy + dialog_h - 60
                yes_x = SCREEN_WIDTH // 2 - btn_w - 20
                no_x = SCREEN_WIDTH // 2 + 20
                if yes_x <= mx <= yes_x + btn_w and btn_y <= my <= btn_y + btn_h:
                    self.guard_confirm_showing = False
                    self._confirm_guard_select(self.guard_confirm_index)
                    return
                elif no_x <= mx <= no_x + btn_w and btn_y <= my <= btn_y + btn_h:
                    self.guard_confirm_showing = False
                    return
                return  # 다이얼로그 외부 클릭 무시

            guards = getattr(self, 'guard_select_guards', [])
            if len(guards) >= 2:
                # 카드 히트박스 (좌/우)
                card_w, card_h = 220, 290
                gap = 60
                left_x = SCREEN_WIDTH // 2 - gap // 2 - card_w
                right_x = SCREEN_WIDTH // 2 + gap // 2
                card_y = 175
                if left_x <= mx <= left_x + card_w and card_y <= my <= card_y + card_h:
                    self._try_guard_select(0)
                    return
                elif right_x <= mx <= right_x + card_w and card_y <= my <= card_y + card_h:
                    self._try_guard_select(1)
                    return

        # 퍽 선택 클릭 처리
        if self.state == TournamentState.PERK_SELECT and self.perk_anim_phase == "active":
            num_options = len(self.current_perk_options)
            card_w, card_h = 210, 105
            card_gap = 10
            total_w = card_w * num_options + card_gap * (num_options - 1)
            start_x = (SCREEN_WIDTH - total_w) // 2
            card_y = 200
            for i in range(num_options):
                x = start_x + i * (card_w + card_gap)
                if x <= mx <= x + card_w and card_y <= my <= card_y + card_h:
                    self.perk_selected_index = i
                    self._confirm_perk_selection()
                    return

        if self.state in [TournamentState.BRACKET_VIEW, TournamentState.SELECT_MATCH]:
            box_w, box_h = 120, 140  # 대각선 레이아웃 크기

            if not self.initial_setup_done and self.current_round == TournamentRound.QUARTER_FINAL:
                # ========== 초반 셋업: 비공개 대진표 클릭 → 매치 공개 ==========
                y_base = 530
                x_positions = [60, 195, 430, 565]

                for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
                    if self.match_revealed[i]:
                        continue  # 이미 공개된 매치는 무시
                    x = x_positions[i]
                    if x <= mx <= x + box_w and y_base <= my <= y_base + box_h:
                        # 매치 공개 애니메이션 시작
                        _load_button_click_sound()
                        if _button_click_sound:
                            _button_click_sound.play()
                        self.match_reveal_index = i
                        self.match_reveal_timer = 0.0
                        self.selected_match = match
                        self.selected_match_index = i
                        self.state = TournamentState.MATCH_REVEAL
                        return
            else:
                # ========== 초반 셋업 완료 후: 기존 클릭 로직 (4강/결승) ==========
                # 8강 매치 클릭 체크 (초반 셋업 완료 후에는 자동 진행)
                y_base = 530
                x_positions = [60, 195, 430, 565]

                for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
                    if match.completed:
                        continue
                    x = x_positions[i]
                    if x <= mx <= x + box_w and y_base <= my <= y_base + box_h:
                        self.selected_match = match
                        self.state = TournamentState.BETTING
                        self.bet_amount = 100
                        return

                # 4강 매치 클릭 체크
                y_semi = 310
                x_semi = [127, 497]

                for i, match in enumerate(self.matches.get(TournamentRound.SEMI_FINAL, [])):
                    if match.completed:
                        continue
                    x = x_semi[i]
                    if x <= mx <= x + box_w and y_semi <= my <= y_semi + box_h:
                        # 4강/결승에서는 플레이어 영웅이 포함된 매치만 직접 플레이
                        if self.player_hero and (match.hero1 == self.player_hero or match.hero2 == self.player_hero):
                            self.selected_match = match
                            self.bet_hero = self.player_hero
                            self._start_vs_preview()
                        return

                # 결승 매치 클릭 체크
                y_final = 80
                x_final = 312

                for match in self.matches.get(TournamentRound.FINAL, []):
                    if match.completed:
                        continue
                    if x_final <= mx <= x_final + box_w and y_final <= my <= y_final + box_h:
                        if self.player_hero and (match.hero1 == self.player_hero or match.hero2 == self.player_hero):
                            self.selected_match = match
                            self.bet_hero = self.player_hero
                            self._start_vs_preview()
                        return

        elif self.state == TournamentState.HERO_SELECT:
            # ========== 영웅 선택 UI 클릭 ==========
            anim_phase = getattr(self, '_hero_select_anim_phase', None)
            # 스킬 확정 후 클릭 → 감옥 선택으로
            if anim_phase == "skill_selected":
                self._hero_select_anim_phase = None
                self.skill_reveal_phase = "done"
                self._prepare_prison_candidates()
                self.state = TournamentState.PRISON_SELECT
                return
            # 다른 애니메이션 중에는 클릭 무시
            if anim_phase:
                return
            panel_x = 130
            card_w, card_h = 200, 320
            gap = 40
            card1_x = panel_x + 25
            card2_x = panel_x + 25 + card_w + gap
            card_y = 100  # _draw_hero_select()와 동일

            # 영웅 1 선택
            if card1_x <= mx <= card1_x + card_w and card_y <= my <= card_y + card_h:
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self._select_hero(self.selected_match.hero1, self.selected_match.hero2)
                return

            # 영웅 2 선택
            if card2_x <= mx <= card2_x + card_w and card_y <= my <= card_y + card_h:
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self._select_hero(self.selected_match.hero2, self.selected_match.hero1)
                return

        elif self.state == TournamentState.SKILL_REVEAL:
            # 스킬 연출 중 클릭하면 스킵 (phase가 selected일 때)
            if self.skill_reveal_phase == "selected":
                if self.skill_reveal_target == (self.player_hero or {}).get("id"):
                    # 플레이어 영웅 스킬 확정 → 감옥 선택으로
                    self._prepare_prison_candidates()
                    self.state = TournamentState.PRISON_SELECT
                elif self.skill_reveal_target == (self.player_guard or {}).get("id"):
                    # 호위무사 스킬 확정 → VS 프리뷰로
                    self._finalize_setup_and_start()

        elif self.state == TournamentState.PRISON_SELECT:
            # ========== 감옥 호위무사 선택 UI 클릭 ==========
            opening_phase = getattr(self, '_prison_opening_phase', None)
            # 스킬 확정 후 클릭 → 다음 단계로
            if opening_phase == "skill_selected":
                self._prison_opening_phase = None
                self.skill_reveal_phase = "done"
                self._finalize_setup_and_start()
                return
            # 다른 애니메이션 중에는 클릭 무시
            if opening_phase:
                return
            cell_w, cell_h = 190, 220
            gap = 15
            total_w = cell_w * 3 + gap * 2
            start_x = (SCREEN_WIDTH - total_w) // 2
            cell_y = 130

            for i, prison_hero in enumerate(self.prison_heroes):
                cx = start_x + i * (cell_w + gap)
                if cx <= mx <= cx + cell_w and cell_y <= my <= cell_y + cell_h:
                    _load_button_click_sound()
                    if _button_click_sound:
                        _button_click_sound.play()
                    self._select_guard(prison_hero, i)
                    return

        elif self.state == TournamentState.GUARD_SKILL_REVEAL:
            # 호위무사 스킬 연출 중 클릭하면 진행
            if self.skill_reveal_phase == "selected":
                self.skill_reveal_phase = "done"
                if getattr(self, '_guard_skill_reveal_mid_tournament', False):
                    self._guard_skill_reveal_mid_tournament = False
                    # 호위무사 스킬 연출 완료 → 퍽 선택 화면으로
                    self._start_perk_select()
                else:
                    self._finalize_setup_and_start()

        elif self.state == TournamentState.BETTING:
            # 배팅 UI 클릭 처리 (4강/결승에서 사용)
            panel_x, panel_y = 200, 200
            panel_w, panel_h = 360, 400

            # 단순화된 배팅 UI - 영웅 클릭시 바로 배틀 시작
            panel_x, panel_y = 180, 180

            # 영웅 1 선택 버튼 (클릭하면 VS 미리보기 후 배틀)
            btn1_rect = pygame.Rect(panel_x + 20, panel_y + 145, 145, 100)
            if btn1_rect.collidepoint(mx, my):
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self.bet_hero = self.selected_match.hero1
                self._start_vs_preview()
                return

            # 영웅 2 선택 버튼 (클릭하면 VS 미리보기 후 배틀)
            btn2_rect = pygame.Rect(panel_x + 235, panel_y + 145, 145, 100)
            if btn2_rect.collidepoint(mx, my):
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self.bet_hero = self.selected_match.hero2
                self._start_vs_preview()
                return

            # 포기하고 나가기 버튼
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 300, 200, 40)
            if exit_rect.collidepoint(mx, my):
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                # 누적 상금을 total_winnings에 저장
                self.total_winnings = self.accumulated_prize
                self.winnings_collected = True
                self.exit_requested = True
                return

        elif self.state == TournamentState.VS_PREVIEW:
            # VS 미리보기 클릭 처리 (버튼 모드일 때)
            if getattr(self, 'vs_preview_show_buttons', False) and self.vs_preview_timer >= 1.5:
                btn_y = 610
                btn_w, btn_h = 180, 50
                # 계속 도전 버튼
                continue_rect = pygame.Rect(SCREEN_WIDTH // 2 - btn_w - 20, btn_y, btn_w, btn_h)
                if continue_rect.collidepoint(mx, my):
                    _load_button_click_sound()
                    if _button_click_sound:
                        _button_click_sound.play()
                    if self.selected_match:
                        self.start_battle(self.selected_match)
                    return

                # 상금 수령하고 나가기 버튼
                exit_rect = pygame.Rect(SCREEN_WIDTH // 2 + 20, btn_y, btn_w, btn_h)
                if exit_rect.collidepoint(mx, my):
                    _load_button_click_sound()
                    if _button_click_sound:
                        _button_click_sound.play()
                    self.total_winnings = self.accumulated_prize
                    self.winnings_collected = True
                    self.exit_requested = True
                    return

        elif self.state == TournamentState.RESULT:
            # 결과 화면 클릭 시 다음으로
            self.result_display_timer = 0

        elif self.state == TournamentState.VICTORY_CELEBRATION:
            # 축하 화면 - 보상 선택 (3초 이후)
            if getattr(self, 'victory_timer', 0) >= 3.0:
                center_x = SCREEN_WIDTH // 2
                btn_w, btn_h = 260, 55
                btn_y = 610

                # 상금 수령 버튼
                gold_rect = pygame.Rect(center_x - btn_w - 15, btn_y, btn_w, btn_h)
                if gold_rect.collidepoint(mx, my):
                    _load_button_click_sound()
                    if _button_click_sound:
                        _button_click_sound.play()
                    prize = self.accumulated_prize  # 누적 상금 전체 수령
                    self.total_winnings = prize
                    self.winnings_collected = True
                    self.exit_requested = True
                    return

                # 호위무사 등용 버튼
                hero_rect = pygame.Rect(center_x + 15, btn_y, btn_w, btn_h)
                if hero_rect.collidepoint(mx, my):
                    _load_button_click_sound()
                    if _button_click_sound:
                        _button_click_sound.play()
                    self.recruited_hero = self.bet_hero
                    self.total_winnings = 0
                    self.winnings_collected = True
                    self.exit_requested = True
                    return

        elif self.state == TournamentState.DIFFICULTY_SELECT:
            # 난이도 카드 클릭
            num = len(ARENA_DIFFICULTIES)
            card_w, card_h = 200, 320
            total_w = num * card_w + (num - 1) * 20
            start_x = (SCREEN_WIDTH - total_w) // 2
            card_y = 195
            for i, diff in enumerate(ARENA_DIFFICULTIES):
                cx = start_x + i * (card_w + 20)
                card_rect = pygame.Rect(cx, card_y, card_w, card_h)
                if card_rect.collidepoint(mx, my):
                    if self.player_gold >= diff["entry_fee"]:
                        _load_button_click_sound()
                        if _button_click_sound:
                            _button_click_sound.play()
                        self._select_difficulty(i)
                        return

        elif self.state == TournamentState.ROUND_END:
            # 라운드 종료 - 계속/수령 선택
            panel_x, panel_y = 150, 180
            continue_rect = pygame.Rect(panel_x + 40, panel_y + 220, 180, 50)
            exit_rect = pygame.Rect(panel_x + 240, panel_y + 220, 180, 50)
            if continue_rect.collidepoint(mx, my):
                # 계속 도전 → 대진표 애니메이션
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self._start_bracket_animation()
                return
            elif exit_rect.collidepoint(mx, my):
                # 상금 수령 후 퇴장
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self.total_winnings = self.accumulated_prize
                self.winnings_collected = True
                self.exit_requested = True
                return

        elif self.state == TournamentState.TOURNAMENT_END:
            # 토너먼트 종료 UI 클릭 처리 (그리기 좌표와 동일하게)
            panel_x, panel_y = 180, 180
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 270, 200, 50)
            if exit_rect.collidepoint(mx, my):
                _load_button_click_sound()
                if _button_click_sound:
                    _button_click_sound.play()
                self.total_winnings = self.accumulated_prize
                self.winnings_collected = True
                self.exit_requested = True
                return

    def _update_hover(self, pos: Tuple[int, int]):
        """마우스 호버 상태 업데이트"""
        mx, my = pos
        old_perk = self.hover_perk_index
        old_match = self.hover_match_index
        old_btn = self.hover_btn_id

        self.hover_perk_index = -1
        self.hover_match_index = -1
        self.hover_btn_id = ""

        # 호위무사 선택 화면 호버
        if self.state == TournamentState.GUARD_SELECT and self.guard_select_timer > 0.5:
            # 스킬 룰렛 애니메이션 중에는 호버 비활성화
            if getattr(self, '_guard_select_anim_phase', None):
                self.guard_select_hover = -1
                self.guard_select_skill_hover = None
            # 경고 다이얼로그 열려 있으면 버튼 호버만 처리
            elif getattr(self, 'guard_confirm_showing', False):
                dialog_w, dialog_h = 420, 200
                dx = SCREEN_WIDTH // 2 - dialog_w // 2
                dy = SCREEN_HEIGHT // 2 - dialog_h // 2
                btn_w, btn_h = 100, 40
                btn_y = dy + dialog_h - 60
                yes_x = SCREEN_WIDTH // 2 - btn_w - 20
                no_x = SCREEN_WIDTH // 2 + 20
                if yes_x <= mx <= yes_x + btn_w and btn_y <= my <= btn_y + btn_h:
                    self.guard_confirm_selected = 0
                elif no_x <= mx <= no_x + btn_w and btn_y <= my <= btn_y + btn_h:
                    self.guard_confirm_selected = 1
            else:
                guards = getattr(self, 'guard_select_guards', [])
                if len(guards) >= 2:
                    card_w, card_h = 220, 290
                    gap = 60
                    left_x = SCREEN_WIDTH // 2 - gap // 2 - card_w
                    right_x = SCREEN_WIDTH // 2 + gap // 2
                    card_y = 175
                    old_hover = getattr(self, 'guard_select_hover', -1)
                    self.guard_select_hover = -1
                    if left_x <= mx <= left_x + card_w and card_y <= my <= card_y + card_h:
                        self.guard_select_hover = 0
                    elif right_x <= mx <= right_x + card_w and card_y <= my <= card_y + card_h:
                        self.guard_select_hover = 1

                # 스킬 아이콘 호버 감지
                self.guard_select_skill_hover = None
                skill_rects = getattr(self, '_guard_skill_icon_rects', [])
                for sr in skill_rects:
                    if sr['rect'].collidepoint(mx, my):
                        self.guard_select_skill_hover = sr
                        break

        # 영웅 선택 화면 호버
        if self.state == TournamentState.HERO_SELECT:
            # 애니메이션 중에는 호버 비활성화
            if getattr(self, '_hero_select_anim_phase', None):
                self.hover_hero_index = -1
            else:
                panel_x = 130
                card_w, card_h = 200, 320
                gap = 40
                card1_x = panel_x + 25
                card2_x = panel_x + 25 + card_w + gap
                card_y = 100  # _draw_hero_select()와 동일
                old_hero_hover = self.hover_hero_index
                self.hover_hero_index = -1
                if card1_x <= mx <= card1_x + card_w and card_y <= my <= card_y + card_h:
                    self.hover_hero_index = 0
                    if old_hero_hover != 0:
                        self._spawn_hover_line_particles(card1_x, card_y, card_w, card_h)
                elif card2_x <= mx <= card2_x + card_w and card_y <= my <= card_y + card_h:
                    self.hover_hero_index = 1
                    if old_hero_hover != 1:
                        self._spawn_hover_line_particles(card2_x, card_y, card_w, card_h)

        # 감옥 호위무사 선택 화면 호버
        elif self.state == TournamentState.PRISON_SELECT:
            # 애니메이션 중에는 호버 비활성화
            if getattr(self, '_prison_opening_phase', None):
                self.hover_prison_index = -1
            else:
                cell_w, cell_h = 190, 220
                gap = 15
                total_w = cell_w * 3 + gap * 2
                start_x = (SCREEN_WIDTH - total_w) // 2
                cell_y = 130
                old_prison_hover = self.hover_prison_index
                self.hover_prison_index = -1
                for i in range(len(self.prison_heroes)):
                    cx = start_x + i * (cell_w + gap)
                    if cx <= mx <= cx + cell_w and cell_y <= my <= cell_y + cell_h:
                        self.hover_prison_index = i
                        if old_prison_hover != i:
                            self._spawn_hover_line_particles(cx, cell_y, cell_w, cell_h)
                        break

        # 퍽 선택 화면 호버
        if self.state == TournamentState.PERK_SELECT and self.perk_anim_phase == "active":
            num_options = len(self.current_perk_options)
            card_w, card_h = 210, 105
            card_gap = 10
            total_w = card_w * num_options + card_gap * (num_options - 1)
            start_x = (SCREEN_WIDTH - total_w) // 2
            card_y = 200
            for i in range(num_options):
                x = start_x + i * (card_w + card_gap)
                if x <= mx <= x + card_w and card_y <= my <= card_y + card_h:
                    self.hover_perk_index = i
                    if old_perk != i:
                        self._spawn_hover_line_particles(x, card_y, card_w, card_h)
                    break

        # 대진표 매치 박스 호버
        elif self.state in [TournamentState.BRACKET_VIEW, TournamentState.SELECT_MATCH]:
            box_w, box_h = 120, 140
            # 8강
            y_base = 530
            x_positions = [60, 195, 430, 565]
            for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
                if match.completed:
                    continue
                x = x_positions[i]
                if x <= mx <= x + box_w and y_base <= my <= y_base + box_h:
                    self.hover_match_index = i
                    if old_match != i:
                        self._spawn_hover_line_particles(x, y_base, box_w, box_h)
                    break
            # 4강
            if self.hover_match_index == -1:
                y_semi = 310
                x_semi = [127, 497]
                for i, match in enumerate(self.matches.get(TournamentRound.SEMI_FINAL, [])):
                    if match.completed:
                        continue
                    x = x_semi[i]
                    if x <= mx <= x + box_w and y_semi <= my <= y_semi + box_h:
                        self.hover_match_index = i + 4
                        if old_match != i + 4:
                            self._spawn_hover_line_particles(x, y_semi, box_w, box_h)
                        break
            # 결승
            if self.hover_match_index == -1:
                y_final = 80
                x_final = 312
                for match in self.matches.get(TournamentRound.FINAL, []):
                    if match.completed:
                        continue
                    if x_final <= mx <= x_final + box_w and y_final <= my <= y_final + box_h:
                        self.hover_match_index = 6
                        if old_match != 6:
                            self._spawn_hover_line_particles(x_final, y_final, box_w, box_h)
                        break

        # 배팅 UI 버튼 호버
        elif self.state == TournamentState.BETTING:
            panel_x, panel_y = 180, 180
            btn1_rect = pygame.Rect(panel_x + 20, panel_y + 145, 145, 100)
            btn2_rect = pygame.Rect(panel_x + 235, panel_y + 145, 145, 100)
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 300, 200, 40)
            if btn1_rect.collidepoint(mx, my):
                self.hover_btn_id = "hero1"
                if old_btn != "hero1":
                    self._spawn_hover_line_particles(btn1_rect.x, btn1_rect.y, btn1_rect.w, btn1_rect.h)
            elif btn2_rect.collidepoint(mx, my):
                self.hover_btn_id = "hero2"
                if old_btn != "hero2":
                    self._spawn_hover_line_particles(btn2_rect.x, btn2_rect.y, btn2_rect.w, btn2_rect.h)
            elif exit_rect.collidepoint(mx, my):
                self.hover_btn_id = "exit"

        # VS 미리보기 버튼 호버
        elif self.state == TournamentState.VS_PREVIEW:
            if getattr(self, 'vs_preview_show_buttons', False) and getattr(self, 'vs_preview_timer', 0) >= 1.5:
                btn_y = 610
                btn_w, btn_h = 180, 50
                continue_rect = pygame.Rect(SCREEN_WIDTH // 2 - btn_w - 20, btn_y, btn_w, btn_h)
                exit_rect = pygame.Rect(SCREEN_WIDTH // 2 + 20, btn_y, btn_w, btn_h)
                if continue_rect.collidepoint(mx, my):
                    self.hover_btn_id = "continue"
                    if old_btn != "continue":
                        self._spawn_hover_line_particles(continue_rect.x, continue_rect.y, continue_rect.w, continue_rect.h)
                elif exit_rect.collidepoint(mx, my):
                    self.hover_btn_id = "vs_exit"
                    if old_btn != "vs_exit":
                        self._spawn_hover_line_particles(exit_rect.x, exit_rect.y, exit_rect.w, exit_rect.h)

        # 우승 축하 보상 버튼 호버
        elif self.state == TournamentState.VICTORY_CELEBRATION:
            if getattr(self, 'victory_timer', 0) >= 3.0:
                center_x = SCREEN_WIDTH // 2
                btn_w, btn_h = 260, 55
                btn_y = 610
                gold_rect = pygame.Rect(center_x - btn_w - 15, btn_y, btn_w, btn_h)
                hero_rect = pygame.Rect(center_x + 15, btn_y, btn_w, btn_h)
                if gold_rect.collidepoint(mx, my):
                    self.hover_btn_id = "gold"
                    if old_btn != "gold":
                        self._spawn_hover_line_particles(gold_rect.x, gold_rect.y, gold_rect.w, gold_rect.h)
                elif hero_rect.collidepoint(mx, my):
                    self.hover_btn_id = "recruit"
                    if old_btn != "recruit":
                        self._spawn_hover_line_particles(hero_rect.x, hero_rect.y, hero_rect.w, hero_rect.h)

        # 난이도 선택 카드 호버
        elif self.state == TournamentState.DIFFICULTY_SELECT:
            self.hover_difficulty_index = -1
            num = len(ARENA_DIFFICULTIES)
            card_w, card_h = 200, 320
            total_w = num * card_w + (num - 1) * 20
            start_x = (SCREEN_WIDTH - total_w) // 2
            card_y = 195
            for i, diff in enumerate(ARENA_DIFFICULTIES):
                cx = start_x + i * (card_w + 20)
                card_rect = pygame.Rect(cx, card_y, card_w, card_h)
                if card_rect.collidepoint(mx, my) and self.player_gold >= diff["entry_fee"]:
                    self.hover_difficulty_index = i
                    break

        # 라운드 종료 (계속/수령) 버튼 호버
        elif self.state == TournamentState.ROUND_END:
            panel_x, panel_y = 150, 180
            cont_rect = pygame.Rect(panel_x + 40, panel_y + 220, 180, 50)
            exit_rect = pygame.Rect(panel_x + 240, panel_y + 220, 180, 50)
            if cont_rect.collidepoint(mx, my):
                self.hover_btn_id = "round_continue"
                if old_btn != "round_continue":
                    self._spawn_hover_line_particles(cont_rect.x, cont_rect.y, cont_rect.w, cont_rect.h)
            elif exit_rect.collidepoint(mx, my):
                self.hover_btn_id = "round_exit"
                if old_btn != "round_exit":
                    self._spawn_hover_line_particles(exit_rect.x, exit_rect.y, exit_rect.w, exit_rect.h)

        # 토너먼트 종료 (패배) 나가기 버튼 호버
        elif self.state == TournamentState.TOURNAMENT_END:
            panel_x, panel_y = 180, 180
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 270, 200, 50)
            if exit_rect.collidepoint(mx, my):
                self.hover_btn_id = "end_exit"
                if old_btn != "end_exit":
                    self._spawn_hover_line_particles(exit_rect.x, exit_rect.y, exit_rect.w, exit_rect.h)

        # 호버 상태가 변했으면 사운드 재생
        new_hover = (self.hover_perk_index, self.hover_match_index, self.hover_btn_id)
        old_hover = (old_perk, old_match, old_btn)
        if new_hover != old_hover and (self.hover_perk_index >= 0 or self.hover_match_index >= 0 or self.hover_btn_id):
            self._play_hover_sound()

    def _play_hover_sound(self):
        """호버 사운드 재생"""
        global _hover_sound
        _load_hover_sound()
        if _hover_sound:
            try:
                _hover_sound.play()
            except Exception:
                pass

    def _spawn_hover_line_particles(self, rx: int, ry: int, rw: int, rh: int):
        """호버 진입 시 테두리에서 파티클 생성"""
        import random as _rand
        for t in range(8):
            f = t / 7
            self.hover_line_particles.append({'x': rx+rw*f, 'y': ry, 'vx': _rand.uniform(-10,10), 'vy': _rand.uniform(-25,-10), 'alpha': 120.0, 'life': _rand.uniform(0.3,0.55), 'color': (200,220,255)})
            self.hover_line_particles.append({'x': rx+rw*f, 'y': ry+rh, 'vx': _rand.uniform(-10,10), 'vy': _rand.uniform(10,25), 'alpha': 120.0, 'life': _rand.uniform(0.3,0.55), 'color': (200,220,255)})
        for t in range(6):
            f = t / 5
            self.hover_line_particles.append({'x': rx, 'y': ry+rh*f, 'vx': _rand.uniform(-25,-10), 'vy': _rand.uniform(-10,10), 'alpha': 120.0, 'life': _rand.uniform(0.3,0.55), 'color': (200,220,255)})
            self.hover_line_particles.append({'x': rx+rw, 'y': ry+rh*f, 'vx': _rand.uniform(10,25), 'vy': _rand.uniform(-10,10), 'alpha': 120.0, 'life': _rand.uniform(0.3,0.55), 'color': (200,220,255)})

    def _draw_hover_border(self, rect_x: int, rect_y: int, rect_w: int, rect_h: int,
                           color: Tuple[int, int, int] = (200, 220, 255)):
        """호버 시 빛나는 테두리 + 코너 라인 이펙트"""
        t = self.hover_glow_timer
        pulse = 0.6 + 0.4 * abs(_sin(t * 4.0))
        al = int(120 * pulse)

        # 글로우
        glow_surf = _get_arena_surface(rect_w + 12, rect_h + 12)
        pygame.draw.rect(glow_surf, (*color, al // 3), (0, 0, rect_w + 12, rect_h + 12), border_radius=10)
        self.screen.blit(glow_surf, (rect_x - 6, rect_y - 6))

        # 보더
        border_surf = _get_arena_surface(rect_w + 4, rect_h + 4)
        pygame.draw.rect(border_surf, (*color, al), (0, 0, rect_w + 4, rect_h + 4), 2, border_radius=10)
        self.screen.blit(border_surf, (rect_x - 2, rect_y - 2))

        # 코너 라인 악센트
        ln = int(14 + 4 * pulse); la = int(200 * pulse)
        lsf = _get_arena_surface(rect_w + 20, rect_h + 20)
        ox, oy = 10, 10
        for c, he, ve in [((ox,oy),(ox+ln,oy),(ox,oy+ln)),((ox+rect_w,oy),(ox+rect_w-ln,oy),(ox+rect_w,oy+ln)),((ox,oy+rect_h),(ox+ln,oy+rect_h),(ox,oy+rect_h-ln)),((ox+rect_w,oy+rect_h),(ox+rect_w-ln,oy+rect_h),(ox+rect_w,oy+rect_h-ln))]:
            pygame.draw.line(lsf, (*color, la), c, he, 2)
            pygame.draw.line(lsf, (*color, la), c, ve, 2)
        self.screen.blit(lsf, (rect_x - 10, rect_y - 10))

        # 파티클
        for p in self.hover_line_particles:
            if p['alpha'] > 3:
                ps = _get_arena_surface(3, 3)
                pygame.draw.circle(ps, (*p['color'], int(p['alpha'])), (1, 1), 1)
                self.screen.blit(ps, (int(p['x']) - 1, int(p['y']) - 1))

    # ================================================================
    # 이집트 파피루스 테마 헬퍼 메서드
    # ================================================================

    def _draw_papyrus_bg(self, surface=None, rect=None):
        """파피루스 질감 배경 그리기 (캐시 활용)"""
        if surface is None:
            surface = self.screen
        if rect is None:
            rect = (0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        rx, ry, rw, rh = rect

        # 캐시된 텍스처가 없으면 생성
        cache_key = (rw, rh)
        if not hasattr(self, '_papyrus_cache') or getattr(self, '_papyrus_cache_key', None) != cache_key:
            tex = pygame.Surface((rw, rh), pygame.SRCALPHA)
            # 수평 결 라인 (파피루스 느낌)
            rng = random.Random(42)  # 고정 시드로 일관성
            for i in range(40):
                ly = rng.randint(0, rh - 1)
                alpha = rng.randint(12, 30)
                lx_start = rng.randint(0, rw // 6)
                lx_end = rw - rng.randint(0, rw // 6)
                pygame.draw.line(tex, (*ET["papyrus_grain"], alpha),
                                 (lx_start, ly), (lx_end, ly), 1)
            # 에이징 밴드 (넓은 어두운 줄)
            for _ in range(4):
                by = rng.randint(0, rh - 8)
                bh = rng.randint(4, 12)
                band = pygame.Surface((rw, bh), pygame.SRCALPHA)
                band.fill((*ET["papyrus_grain"], rng.randint(8, 18)))
                tex.blit(band, (0, by))
            # 작은 스펙클
            for _ in range(6):
                sx, sy = rng.randint(0, rw - 1), rng.randint(0, rh - 1)
                pygame.draw.circle(tex, (*ET["papyrus_dark"], rng.randint(15, 30)),
                                   (sx, sy), rng.randint(1, 3))
            self._papyrus_cache = tex
            self._papyrus_cache_key = cache_key

        surface.blit(self._papyrus_cache, (rx, ry))

    def _draw_egyptian_border(self, surface, rect, color=None, width=2, pattern=True):
        """금색 이집트 패턴 테두리"""
        if color is None:
            color = ET["gold_medium"]
        x, y, w, h = rect
        pygame.draw.rect(surface, color, (x, y, w, h), width)

        if pattern:
            # 상하 스텝 패턴
            step_size = 4
            gap = 10
            for px in range(x + 8, x + w - 8, gap):
                # 상단
                pygame.draw.rect(surface, ET["gold_dark"],
                                 (px, y + width, step_size, step_size))
                # 하단
                pygame.draw.rect(surface, ET["gold_dark"],
                                 (px, y + h - width - step_size, step_size, step_size))
            # 좌우 스텝 패턴
            for py in range(y + 8, y + h - 8, gap):
                pygame.draw.rect(surface, ET["gold_dark"],
                                 (x + width, py, step_size, step_size))
                pygame.draw.rect(surface, ET["gold_dark"],
                                 (x + w - width - step_size, py, step_size, step_size))
            # 코너 피라미드 장식
            tri_s = 6
            corners = [
                (x + 3, y + 3, 1, 1), (x + w - 3, y + 3, -1, 1),
                (x + 3, y + h - 3, 1, -1), (x + w - 3, y + h - 3, -1, -1),
            ]
            for cx, cy, dx, dy in corners:
                pts = [(cx, cy), (cx + tri_s * dx, cy), (cx, cy + tri_s * dy)]
                pygame.draw.polygon(surface, ET["gold_bright"], pts)

    def _draw_egyptian_card(self, x, y, w, h, is_hover=False, is_selected=False, is_completed=False):
        """이집트 스타일 카드 (파피루스 질감 + 금색 보더)"""
        if is_completed:
            bg = ET["card_bg_completed"]
        elif is_hover:
            bg = ET["card_bg_hover"]
        else:
            bg = ET["card_bg"]
        pygame.draw.rect(self.screen, bg, (x, y, w, h), border_radius=6)

        # 파피루스 결 텍스처 (카드 내부)
        grain_surf = _get_arena_surface(w, h)
        rng = random.Random(x * 31 + y * 17)
        for i in range(12):
            ly = rng.randint(0, h - 1)
            alpha = rng.randint(10, 22)
            pygame.draw.line(grain_surf, (*ET["papyrus_grain"], alpha),
                             (2, ly), (w - 2, ly), 1)
        self.screen.blit(grain_surf, (x, y))

        # 보더
        if is_selected:
            border_color = ET["selected_border"]
            border_w = 2
        elif is_hover:
            border_color = ET["card_border_hover"]
            border_w = 2
        else:
            border_color = ET["card_border"]
            border_w = 1

        pygame.draw.rect(self.screen, border_color, (x, y, w, h), border_w, border_radius=6)

        # 호버 시 글로우
        if is_hover:
            glow = _get_arena_surface(w + 8, h + 8)
            pygame.draw.rect(glow, (*ET["hover_glow"], 35), (0, 0, w + 8, h + 8), border_radius=8)
            self.screen.blit(glow, (x - 4, y - 4))

    def _draw_egyptian_title(self, text, y, color=None):
        """이집트 스타일 타이틀 (호루스의 눈 장식 + 수평선)"""
        if color is None:
            color = ET["gold_bright"]
        if not self.fonts or "large" not in self.fonts:
            return
        surf, _ = self.fonts["large"].render(text, color)
        tx = SCREEN_WIDTH // 2 - surf.get_width() // 2
        self.screen.blit(surf, (tx, y))

        # 양쪽 호루스의 눈 장식
        eye_size = 12
        for side in [-1, 1]:
            ex = tx - 24 if side == -1 else tx + surf.get_width() + 12
            ey = y + surf.get_height() // 2
            self._draw_eye_of_horus(self.screen, ex, ey, eye_size, ET["gold_medium"])

        # 수평선 (양쪽으로 페이드)
        line_y = y + surf.get_height() + 4
        line_surf = _get_arena_surface(SCREEN_WIDTH, 2)
        center = SCREEN_WIDTH // 2
        left_end = tx - 30
        right_end = tx + surf.get_width() + 30
        for lx in range(0, SCREEN_WIDTH):
            if lx < left_end:
                dist = (left_end - lx) / max(1, left_end)
                a = int(40 * max(0, 1 - dist * 2))
            elif lx > right_end:
                dist = (lx - right_end) / max(1, SCREEN_WIDTH - right_end)
                a = int(40 * max(0, 1 - dist * 2))
            else:
                a = 40
            if a > 0:
                line_surf.set_at((lx, 0), (*ET["gold_dark"], a))
                line_surf.set_at((lx, 1), (*ET["gold_dark"], a // 2))
        self.screen.blit(line_surf, (0, line_y))

    def _draw_egyptian_separator(self, y, width=400, color=None):
        """이집트 장식 구분선"""
        if color is None:
            color = ET["gold_dark"]
        cx = SCREEN_WIDTH // 2
        half = width // 2

        sep_surf = _get_arena_surface(width, 8)
        # 중앙 다이아몬드
        diamond_pts = [(half, 0), (half + 4, 4), (half, 8), (half - 4, 4)]
        pygame.draw.polygon(sep_surf, (*ET["gold_bright"], 180), diamond_pts)
        # 양쪽 라인 (페이드)
        for lx in range(0, half - 6):
            dist = lx / max(1, half - 6)
            a = int(80 * dist)
            sep_surf.set_at((lx, 3), (*color, a))
            sep_surf.set_at((lx, 4), (*color, a))
            sep_surf.set_at((width - 1 - lx, 3), (*color, a))
            sep_surf.set_at((width - 1 - lx, 4), (*color, a))
        # 양끝 연꽃 삼각형
        tri_s = 5
        for side_x in [4, width - 4]:
            dx = 1 if side_x < half else -1
            pts = [(side_x, 4), (side_x + tri_s * dx, 1), (side_x + tri_s * dx, 7)]
            pygame.draw.polygon(sep_surf, (*ET["gold_medium"], 140), pts)

        self.screen.blit(sep_surf, (cx - half, y))

    def _draw_egyptian_button(self, rect, text, is_hovered=False, btn_type="continue",
                              text_color=None):
        """이집트 스타일 버튼"""
        colors = {
            "continue": (ET["btn_continue"], ET["btn_continue_hover"], ET["malachite_light"]),
            "exit": (ET["btn_exit"], ET["btn_exit_hover"], ET["lapis_light"]),
            "danger": (ET["btn_danger"], ET["btn_danger_hover"], ET["carnelian_light"]),
        }
        base, hover, border_c = colors.get(btn_type, colors["continue"])
        bg = hover if is_hovered else base

        if is_hovered:
            self._draw_hover_border(rect.x, rect.y, rect.w, rect.h, border_c)

        pygame.draw.rect(self.screen, bg, rect, border_radius=5)
        pygame.draw.rect(self.screen, border_c, rect, 2, border_radius=5)

        # 양끝 피라미드 삼각 장식
        tri_s = 5
        mid_y = rect.centery
        # 좌
        pts_l = [(rect.x + 6, mid_y), (rect.x + 6 + tri_s, mid_y - tri_s),
                 (rect.x + 6 + tri_s, mid_y + tri_s)]
        pygame.draw.polygon(self.screen, ET["gold_dark"], pts_l)
        # 우
        pts_r = [(rect.right - 6, mid_y), (rect.right - 6 - tri_s, mid_y - tri_s),
                 (rect.right - 6 - tri_s, mid_y + tri_s)]
        pygame.draw.polygon(self.screen, ET["gold_dark"], pts_r)

        if text_color is None:
            text_color = ET["text_white"]
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render(text, text_color)
            self.screen.blit(surf, (rect.centerx - surf.get_width() // 2,
                                    rect.centery - surf.get_height() // 2))

    def _draw_egyptian_panel(self, x, y, w, h, border_color=None):
        """이집트 스타일 패널 (파피루스 내부 + 이중 보더 + 코너 장식)"""
        if border_color is None:
            border_color = ET["gold_medium"]
        # 배경
        pygame.draw.rect(self.screen, ET["bg_panel"], (x, y, w, h), border_radius=8)
        # 파피루스 결
        grain = _get_arena_surface(w, h)
        rng = random.Random(x + y * 7)
        for i in range(10):
            ly = rng.randint(0, h - 1)
            pygame.draw.line(grain, (*ET["papyrus_grain"], rng.randint(10, 22)),
                             (4, ly), (w - 4, ly), 1)
        self.screen.blit(grain, (x, y))
        # 외곽 보더
        pygame.draw.rect(self.screen, border_color, (x, y, w, h), 3, border_radius=8)
        # 내부 보더 (3px 안쪽)
        inner_surf = _get_arena_surface(w - 6, h - 6)
        pygame.draw.rect(inner_surf, (*ET["gold_dark"], 80),
                         (0, 0, w - 6, h - 6), 1, border_radius=6)
        self.screen.blit(inner_surf, (x + 3, y + 3))
        # 코너 스카라베 장식 (원 + 날개)
        for cx, cy in [(x + 8, y + 8), (x + w - 8, y + 8),
                       (x + 8, y + h - 8), (x + w - 8, y + h - 8)]:
            cs = _get_arena_surface(16, 16)
            pygame.draw.circle(cs, (*ET["gold_dark"], 120), (8, 8), 4)
            pygame.draw.arc(cs, (*ET["gold_medium"], 100),
                            (1, 2, 14, 12), 0.3, 2.8, 1)
            self.screen.blit(cs, (cx - 8, cy - 8))

    def _draw_eye_of_horus(self, surface, cx, cy, size, color=None):
        """호루스의 눈 (간략화)"""
        if color is None:
            color = ET["gold_medium"]
        s = max(4, size)
        hw = s  # 눈 반폭
        hh = s // 2  # 눈 반높이
        # 아몬드형 눈 외곽
        pts = [
            (cx - hw, cy),
            (cx - hw // 2, cy - hh),
            (cx + hw // 3, cy - hh),
            (cx + hw, cy),
            (cx + hw // 3, cy + hh),
            (cx - hw // 2, cy + hh),
        ]
        pygame.draw.polygon(surface, color, pts, 1)
        # 동공
        pygame.draw.circle(surface, color, (cx, cy), max(1, s // 4))
        # 눈물 라인 (아래로)
        pygame.draw.line(surface, color, (cx, cy + hh), (cx + s // 3, cy + hh + s // 2), 1)
        # 눈썹 곡선
        pygame.draw.arc(surface, color, (cx - hw, cy - hh - s // 3, hw * 2, s // 2),
                        0.3, 2.8, 1)

    def draw(self):
        """메인 그리기"""
        if self.state == TournamentState.VS_PREVIEW:
            self._draw_vs_preview()
        elif self.state == TournamentState.BATTLE:
            self._draw_battle()
        elif self.state == TournamentState.GUARD_NOTIFY:
            self._draw_guard_notification()
        elif self.state == TournamentState.GUARD_SELECT:
            self._draw_guard_select()
        elif self.state == TournamentState.PERK_SELECT:
            self._draw_perk_select()
        elif self.state == TournamentState.VICTORY_CELEBRATION:
            self._draw_victory_celebration()
        elif self.state == TournamentState.BRACKET_ANIMATION:
            self._draw_bracket_animation()
        elif self.state == TournamentState.MATCH_REVEAL:
            self._draw_bracket()  # 대진표 + 공개 애니메이션
        elif self.state == TournamentState.HERO_SELECT:
            self._draw_hero_select()
        elif self.state == TournamentState.GUARD_SKILL_REVEAL:
            self._draw_skill_reveal()
        elif self.state == TournamentState.PRISON_SELECT:
            self._draw_prison_select()
        elif self.state == TournamentState.TENACITY_RETRY:
            self._draw_tenacity_retry()
        elif self.state == TournamentState.DIFFICULTY_SELECT:
            self._draw_difficulty_select()
        else:
            self._draw_bracket()

        # 관리자 영웅 선택 오버레이 (항상 최상단에 그림)
        if self.admin_hero_select_active:
            self._draw_admin_hero_select()

    def _draw_vs_preview(self):
        """VS 매치업 미리보기 그리기 (배틀 전 표시)"""
        # 배경 그리기
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        # _draw_vs_matchup_animation 재사용 (progress 임시 설정)
        saved_progress = getattr(self, 'bracket_anim_progress', 0.0)
        self.bracket_anim_progress = self.vs_preview_progress
        self._draw_vs_matchup_animation()
        self.bracket_anim_progress = saved_progress

        # 버튼 모드: 1.5초 후 하단에 계속/나가기 버튼 페이드인
        if getattr(self, 'vs_preview_show_buttons', False) and self.vs_preview_timer >= 1.5:
            btn_fade = min(1.0, (self.vs_preview_timer - 1.5) / 0.5)  # 0.5초간 페이드인
            btn_alpha = int(255 * btn_fade)

            btn_y = 610
            btn_w, btn_h = 180, 50

            # 상금 정보 (버튼 위)
            if self.fonts and "medium" in self.fonts and btn_fade > 0.3:
                # 다음 라운드 승리 시 상금
                next_prize = self.round_prizes.get(self.current_round, 0)
                prize_text = f"승리 시 {next_prize}G 획득!"
                surf, _ = self.fonts["medium"].render(prize_text, (int(100 * btn_fade), int(255 * btn_fade), int(100 * btn_fade)))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, btn_y - 55))

                # 경고
                if "small" in self.fonts:
                    warn_text = f"패배 시 입장료 {self.entry_fee}G를 잃습니다!"
                    surf, _ = self.fonts["small"].render(warn_text, (int(255 * btn_fade), int(180 * btn_fade), int(100 * btn_fade)))
                    warn_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
                    self._draw_warning_icon(warn_x - 12, btn_y - 30, 10)
                    self.screen.blit(surf, (warn_x, btn_y - 35))

            # 계속 도전 버튼
            cont_hovered = (self.hover_btn_id == "continue")
            continue_rect = pygame.Rect(SCREEN_WIDTH // 2 - btn_w - 20, btn_y, btn_w, btn_h)
            if cont_hovered:
                self._draw_hover_border(continue_rect.x, continue_rect.y, continue_rect.w, continue_rect.h, (100, 255, 100))
            btn_surf = _get_arena_surface(btn_w, btn_h)
            cont_bg = (100, 210, 100, btn_alpha) if cont_hovered else (80, 180, 80, btn_alpha)
            pygame.draw.rect(btn_surf, cont_bg, (0, 0, btn_w, btn_h), border_radius=5)
            self.screen.blit(btn_surf, continue_rect.topleft)
            if self.fonts and "medium" in self.fonts:
                surf, _ = self._render_text("medium", "계속 도전!", (255, 255, 255))
                btn_text_x = continue_rect.centerx - surf.get_width() // 2
                self._draw_fire_icon(btn_text_x - 12, continue_rect.y + 15 + surf.get_height() // 2, 12)
                self.screen.blit(surf, (btn_text_x, continue_rect.y + 15))

            # 상금 수령 버튼
            vs_exit_hovered = (self.hover_btn_id == "vs_exit")
            exit_rect = pygame.Rect(SCREEN_WIDTH // 2 + 20, btn_y, btn_w, btn_h)
            if vs_exit_hovered:
                self._draw_hover_border(exit_rect.x, exit_rect.y, exit_rect.w, exit_rect.h, (150, 150, 255))
            btn_surf = _get_arena_surface(btn_w, btn_h)
            exit_bg = (120, 120, 210, btn_alpha) if vs_exit_hovered else (100, 100, 180, btn_alpha)
            pygame.draw.rect(btn_surf, exit_bg, (0, 0, btn_w, btn_h), border_radius=5)
            self.screen.blit(btn_surf, exit_rect.topleft)
            if self.fonts and "medium" in self.fonts:
                exit_text = f"{self.accumulated_prize}G 수령" if self.accumulated_prize > 0 else "포기하고 나가기"
                surf, _ = self.fonts["medium"].render(exit_text, (255, 255, 255))
                btn_text_x = exit_rect.centerx - surf.get_width() // 2
                self._draw_coin_icon(btn_text_x - 12, exit_rect.y + 15 + surf.get_height() // 2, 12)
                self.screen.blit(surf, (btn_text_x, exit_rect.y + 15))

    def _draw_battle(self):
        """배틀 화면 그리기"""
        # 화면 흔들림 오프셋
        shake_x, shake_y = 0, 0
        if self.skill_manager:
            shake_x, shake_y = self.skill_manager.get_screen_shake()

        # 배경
        self.screen.fill(ET["bg_dark"])

        # 콜로세움 배경 사용 (가능한 경우)
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X + shake_x, offset_y=shake_y)
        else:
            # 폴백: 기본 게임 영역
            pygame.draw.rect(self.screen, (194, 158, 108),  # 모래색
                            (GAME_AREA_X + shake_x, shake_y, GAME_AREA_WIDTH, SCREEN_HEIGHT))

        # 중앙선 (모래 위에 그려진 라인)
        center_y = SCREEN_HEIGHT // 2
        pygame.draw.line(self.screen, (164, 128, 88),
                        (GAME_AREA_X + 30 + shake_x, center_y + shake_y),
                        (GAME_AREA_X + GAME_AREA_WIDTH - 30 + shake_x, center_y + shake_y), 3)

        # 원형 경기장 라인
        pygame.draw.circle(self.screen, (164, 128, 88),
                          (GAME_AREA_X + GAME_AREA_WIDTH // 2 + shake_x, center_y + shake_y), 120, 2)

        # 스킬 이펙트 (배경 레이어)
        if self.skill_manager and self.top_paddle and self.bottom_paddle and self.ball:
            self.skill_manager.draw_skills(self.screen, self.top_paddle, self.bottom_paddle, self.ball)

        # 날씨 파티클 그리기 (용의 날개 강풍 이펙트)
        if WEATHER_EVENT_AVAILABLE and weather_module.weather_event_active and weather_module.weather_event_type == "gust":
            weather_module.draw_weather_particles(self.screen)

        # 대쉬 효과 그리기 (패들 뒤에)
        if self.top_paddle:
            self.top_paddle.draw_dash_effects(self.screen)
        if self.bottom_paddle:
            self.bottom_paddle.draw_dash_effects(self.screen)

        # 패들 그리기 (영웅 패들 렌더러 사용)
        if self.top_paddle and self.selected_match:
            paddle_rect = self.top_paddle.get_rect()
            # 패들 크기 스케일 적용
            scaled_width = int(PADDLE_WIDTH * self.top_paddle.paddle_scale)
            hero1 = self.selected_match.hero1
            # DEBUG
            if self.top_paddle.paddle_scale != 1.0:
                print(f"[DEBUG Draw] top_paddle scale={self.top_paddle.paddle_scale}, scaled_width={scaled_width}")

            if self.hero_paddle_renderer:
                # 영웅 패들 렌더러로 그리기 (상단 영웅은 아래를 바라봄)
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen,
                    hero1["id"],
                    paddle_rect.centerx + shake_x,
                    paddle_rect.centery + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT,
                    facing="down",
                    color=hero1["color"]
                )
            else:
                # 폴백: 기본 패들
                scaled_rect = pygame.Rect(
                    paddle_rect.centerx - scaled_width // 2 + shake_x,
                    paddle_rect.y + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT
                )
                shadow_rect = scaled_rect.copy()
                shadow_rect.y += 3
                pygame.draw.rect(self.screen, (60, 50, 40), shadow_rect, border_radius=4)
                pygame.draw.rect(self.screen, hero1["color"], scaled_rect, border_radius=4)

                # 스턴 표시
                if self.top_paddle.is_stunned:
                    stun_surf = _get_arena_surface(scaled_width + 10, PADDLE_HEIGHT + 10)
                    pygame.draw.rect(stun_surf, (255, 255, 0, 100), stun_surf.get_rect(), border_radius=6)
                    self.screen.blit(stun_surf, (scaled_rect.x - 5, scaled_rect.y - 5))

        if self.bottom_paddle and self.selected_match:
            paddle_rect = self.bottom_paddle.get_rect()
            scaled_width = int(PADDLE_WIDTH * self.bottom_paddle.paddle_scale)
            hero2 = self.selected_match.hero2

            if self.hero_paddle_renderer:
                # 영웅 패들 렌더러로 그리기 (하단 영웅은 위를 바라봄)
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen,
                    hero2["id"],
                    paddle_rect.centerx + shake_x,
                    paddle_rect.centery + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT,
                    facing="up",
                    color=hero2["color"]
                )
            else:
                # 폴백: 기본 패들
                scaled_rect = pygame.Rect(
                    paddle_rect.centerx - scaled_width // 2 + shake_x,
                    paddle_rect.y + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT
                )
                shadow_rect = scaled_rect.copy()
                shadow_rect.y += 3
                pygame.draw.rect(self.screen, (60, 50, 40), shadow_rect, border_radius=4)
                pygame.draw.rect(self.screen, hero2["color"], scaled_rect, border_radius=4)

                # 스턴 표시
                if self.bottom_paddle.is_stunned:
                    stun_surf = _get_arena_surface(scaled_width + 10, PADDLE_HEIGHT + 10)
                    pygame.draw.rect(stun_surf, (255, 255, 0, 100), stun_surf.get_rect(), border_radius=6)
                    self.screen.blit(stun_surf, (scaled_rect.x - 5, scaled_rect.y - 5))

        # 혼란 상태 물음표 효과 (패들 위에 빙글빙글 도는 물음표)
        self._draw_confusion_effect(shake_x, shake_y)

        # 공 생성 애니메이션
        if self.spawn_phase and self.ball_spawn_animation:
            self.ball_spawn_animation.draw(self.screen)

        # 공 그리기 (그림자 포함)
        if self.ball and self.ball.visible:
            ball_x = int(self.ball.x) + shake_x
            ball_y = int(self.ball.y) + shake_y

            # 잔상 그리기
            for tx, ty, alpha in self.ball.trail:
                trail_alpha = int(100 * alpha)
                if trail_alpha > 10:
                    trail_size = int(BALL_SIZE * 0.7 * alpha)
                    if trail_size > 1:
                        trail_surf = _get_arena_surface(trail_size * 2, trail_size * 2)
                        pygame.draw.circle(trail_surf, (255, 255, 200, trail_alpha),
                                          (trail_size, trail_size), trail_size)
                        self.screen.blit(trail_surf, (int(tx) + shake_x - trail_size, int(ty) + shake_y - trail_size))

            # 불 효과 (스킬)
            if self.skill_manager and self.skill_manager.game_state.get('ball_on_fire', False):
                fire_glow = _get_arena_surface(BALL_SIZE * 4, BALL_SIZE * 4)
                pygame.draw.circle(fire_glow, (255, 100, 0, 100), (BALL_SIZE * 2, BALL_SIZE * 2), BALL_SIZE * 2)
                self.screen.blit(fire_glow, (ball_x - BALL_SIZE * 2, ball_y - BALL_SIZE * 2), special_flags=pygame.BLEND_ADD)

            # 성스러운 공 효과 (스팀 배리어)
            if self.skill_manager and self.skill_manager.game_state.get('ball_holy', False):
                holy_glow = _get_arena_surface(BALL_SIZE * 5, BALL_SIZE * 5)
                pygame.draw.circle(holy_glow, (255, 215, 80, 70), (BALL_SIZE * 5 // 2, BALL_SIZE * 5 // 2), BALL_SIZE * 5 // 2)
                pygame.draw.circle(holy_glow, (255, 240, 180, 100), (BALL_SIZE * 5 // 2, BALL_SIZE * 5 // 2), BALL_SIZE * 2)
                self.screen.blit(holy_glow, (ball_x - BALL_SIZE * 5 // 2, ball_y - BALL_SIZE * 5 // 2), special_flags=pygame.BLEND_ADD)

            # 그림자
            pygame.draw.circle(self.screen, (60, 50, 40),
                             (ball_x + 2, ball_y + 3), BALL_SIZE)
            # 공 본체
            if self.skill_manager and self.skill_manager.game_state.get('ball_on_fire', False):
                ball_color = (255, 200, 100)
            elif self.skill_manager and self.skill_manager.game_state.get('ball_holy', False):
                ball_color = (255, 240, 180)
            else:
                ball_color = (255, 255, 255)
            pygame.draw.circle(self.screen, ball_color,
                             (ball_x, ball_y), BALL_SIZE)
            # 하이라이트
            pygame.draw.circle(self.screen, (255, 255, 200),
                             (int(self.ball.x) - 3, int(self.ball.y) - 3), 3)

            # 공 속도에 따른 글로우 효과
            speed = self.ball.get_speed()
            if speed > 10:
                glow_intensity = min(1.0, (speed - 10) / 5)
                glow_size = int(BALL_SIZE * 1.5 + glow_intensity * 5)
                glow_surf = _get_arena_surface(glow_size * 2, glow_size * 2)
                glow_alpha = int(50 * glow_intensity)
                pygame.draw.circle(glow_surf, (255, 200, 100, glow_alpha),
                                  (glow_size, glow_size), glow_size)
                self.screen.blit(glow_surf, (ball_x - glow_size, ball_y - glow_size),
                                special_flags=pygame.BLEND_ADD)

        # 스킬 화면 효과 (오버레이)
        if self.skill_manager:
            self.skill_manager.draw_screen_effects(self.screen)

        # 영웅 말풍선 그리기
        self._draw_speech_bubbles()

        # 필러 (사이드 UI)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        # 점수판
        self._draw_scoreboard()

        # 배속 버튼
        self._draw_speed_buttons()

        # 영웅 정보
        self._draw_hero_info()

        # 스킬 쿨타임 UI 표시
        self._draw_skill_cooldowns()

        # 전경 효과
        if self.arena_background:
            self.arena_background.draw_foreground(self.screen, offset_x=GAME_AREA_X, offset_y=0)

    def _draw_confusion_effect(self, shake_x: int = 0, shake_y: int = 0):
        """혼란 상태 물음표 효과 그리기 (패들 위에 빙글빙글 도는 물음표)"""
        current_time = pygame.time.get_ticks()
        rotation_speed = 0.005  # 회전 속도

        # 상단 패들 혼란 효과
        if self.top_paddle and self.top_paddle.is_confused:
            self._draw_question_marks(
                self.top_paddle.x + PADDLE_WIDTH // 2 + shake_x,
                self.top_paddle.y + PADDLE_HEIGHT // 2 + shake_y + 25,  # 패들 아래쪽에 표시
                current_time, rotation_speed
            )

        # 하단 패들 혼란 효과
        if self.bottom_paddle and self.bottom_paddle.is_confused:
            self._draw_question_marks(
                self.bottom_paddle.x + PADDLE_WIDTH // 2 + shake_x,
                self.bottom_paddle.y + PADDLE_HEIGHT // 2 + shake_y - 25,  # 패들 위쪽에 표시
                current_time, rotation_speed
            )

    def _draw_question_marks(self, center_x: float, center_y: float, current_time: int, rotation_speed: float):
        """빙글빙글 도는 물음표 그리기"""
        num_questions = 3
        orbit_radius = 25  # 회전 반경

        for i in range(num_questions):
            # 각 물음표의 각도 계산 (균등하게 배치)
            angle = current_time * rotation_speed + (i * 2 * math.pi / num_questions)

            # 물음표 위치 계산 (원형 궤도)
            x = center_x + orbit_radius * _cos(angle)
            y = center_y + orbit_radius * _sin(angle) * 0.5  # Y축은 타원형으로

            # 물음표 크기 변화 (앞뒤 구분)
            size_factor = 0.8 + 0.2 * _sin(angle)

            # 물음표 색상 (깜빡이는 효과)
            if _sin(current_time * 0.01 + i) > 0:
                color = (255, 255, 100)  # 밝은 노란색
            else:
                color = (255, 200, 50)   # 어두운 노란색

            # 물음표 그리기 (폰트가 있으면 사용, 없으면 원으로 대체)
            if self.fonts and "medium" in self.fonts:
                question_text, _ = self._render_text("medium", "?", color)
                # 크기 조절
                scaled_width = int(question_text.get_width() * size_factor)
                scaled_height = int(question_text.get_height() * size_factor)
                if scaled_width > 0 and scaled_height > 0:
                    scaled_question = pygame.transform.scale(question_text, (scaled_width, scaled_height))
                    question_rect = scaled_question.get_rect(center=(int(x), int(y)))
                    # 그림자
                    shadow_text, _ = self._render_text("medium", "?", (50, 50, 0))
                    scaled_shadow = pygame.transform.scale(shadow_text, (scaled_width, scaled_height))
                    shadow_rect = scaled_shadow.get_rect(center=(int(x + 2), int(y + 2)))
                    self.screen.blit(scaled_shadow, shadow_rect)
                    self.screen.blit(scaled_question, question_rect)
            else:
                # 폰트 없을 때 원으로 대체
                radius = int(8 * size_factor)
                pygame.draw.circle(self.screen, (50, 50, 0), (int(x + 2), int(y + 2)), radius)
                pygame.draw.circle(self.screen, color, (int(x), int(y)), radius)

    def _draw_speed_buttons(self):
        """배속 버튼 그리기 (1.3x, 2x, 3x)"""
        btn_w, btn_h = 32, 22
        gap = 3
        # 점수판(중앙 x=380, y=10, 120x50) 오른쪽에 배치
        start_x = SCREEN_WIDTH // 2 + 65
        start_y = 18

        self.speed_btn_rects = {}
        for i, mult in enumerate([1, 1.5, 2, 3]):
            x = start_x + i * (btn_w + gap)
            rect = pygame.Rect(x, start_y, btn_w, btn_h)
            self.speed_btn_rects[mult] = rect

            is_active = (self.speed_multiplier == mult)
            if is_active:
                bg = (220, 180, 80)
                text_color = (30, 25, 15)
            else:
                bg = (50, 55, 65)
                text_color = (140, 140, 140)

            pygame.draw.rect(self.screen, bg, rect, border_radius=3)
            pygame.draw.rect(self.screen, (80, 85, 95), rect, 1, border_radius=3)

            label = f"{mult}x"
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render(label, text_color)
                self.screen.blit(surf, (x + btn_w // 2 - surf.get_width() // 2,
                                        start_y + btn_h // 2 - surf.get_height() // 2))

    def _draw_scoreboard(self):
        """점수판 그리기"""
        # 배경
        board_rect = pygame.Rect(SCREEN_WIDTH // 2 - 60, 10, 120, 50)
        pygame.draw.rect(self.screen, (40, 45, 55), board_rect, border_radius=5)
        pygame.draw.rect(self.screen, (60, 65, 75), board_rect, 2, border_radius=5)

        # 점수
        if self.fonts and "large" in self.fonts:
            score_text = f"{self.score_top} : {self.score_bottom}"
            surf, _ = self.fonts["large"].render(score_text, (255, 255, 255))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 20))

    def _draw_hero_info(self):
        """영웅 정보 표시"""
        if not self.selected_match:
            return

        # 상단 영웅 (왼쪽 필러)
        hero1 = self.selected_match.hero1
        pygame.draw.rect(self.screen, hero1["color"], (5, 100, 70, 80), border_radius=5)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero1["name"], (255, 255, 255))
            self.screen.blit(surf, (10, 110))

        # 하단 영웅 (오른쪽 필러)
        hero2 = self.selected_match.hero2
        pygame.draw.rect(self.screen, hero2["color"], (685, 100, 70, 80), border_radius=5)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero2["name"], (255, 255, 255))
            self.screen.blit(surf, (690, 110))

    def _draw_skill_cooldowns(self):
        """스킬 쿨타임 UI 표시"""
        if not self.skill_manager or not self.selected_match:
            return

        # 상단 영웅 스킬 (왼쪽 필러)
        hero1_skills = self.skill_manager.active_skills.get(self.selected_match.hero1["id"], [])
        self._draw_skill_icons(hero1_skills, 5, 200, self.selected_match.hero1["color"])

        # 하단 영웅 스킬 (오른쪽 필러)
        hero2_skills = self.skill_manager.active_skills.get(self.selected_match.hero2["id"], [])
        self._draw_skill_icons(hero2_skills, 685, 200, self.selected_match.hero2["color"])

    def _draw_skill_icons(self, skills, base_x: int, base_y: int, hero_color: Tuple[int, int, int]):
        """스킬 아이콘과 쿨타임 표시"""
        if not skills:
            return

        icon_size = 30
        padding = 5

        for i, skill in enumerate(skills):
            x = base_x + 5
            y = base_y + i * (icon_size + padding)

            # 스킬 배경
            bg_color = hero_color if skill.can_use() else (40, 40, 40)
            pygame.draw.rect(self.screen, bg_color, (x, y, icon_size, icon_size), border_radius=5)
            pygame.draw.rect(self.screen, (80, 80, 80), (x, y, icon_size, icon_size), 2, border_radius=5)

            # 스킬 아이콘 이미지
            icon = _get_hero_skill_icon(skill.skill_id, icon_size)
            if icon:
                self.screen.blit(icon, (x, y))

            # 쿨타임 오버레이
            if skill.current_cooldown > 0:
                cooldown_ratio = skill.current_cooldown / skill.cooldown
                overlay_height = int(icon_size * cooldown_ratio)
                overlay_rect = pygame.Rect(x, y + (icon_size - overlay_height), icon_size, overlay_height)
                overlay_surf = _get_arena_surface(icon_size, overlay_height)
                overlay_surf.fill((0, 0, 0, 150))
                self.screen.blit(overlay_surf, (x, y + (icon_size - overlay_height)))

                # 쿨타임 숫자
                cd_text = f"{int(skill.current_cooldown)}"
                if self.fonts and "small" in self.fonts:
                    surf, _ = self.fonts["small"].render(cd_text, (255, 255, 255))
                    self.screen.blit(surf, (x + icon_size // 2 - surf.get_width() // 2,
                                           y + icon_size // 2 - surf.get_height() // 2))

            # 활성 중 표시
            if skill.is_active:
                glow_surf = _get_arena_surface(icon_size + 4, icon_size + 4)
                pygame.draw.rect(glow_surf, (255, 255, 100, 150), glow_surf.get_rect(), border_radius=6)
                self.screen.blit(glow_surf, (x - 2, y - 2))

            # 스킬 이니셜
            initial = skill.korean_name[0] if skill.korean_name else "?"
            if self.fonts and "small" in self.fonts:
                color = (255, 255, 255) if skill.can_use() else (100, 100, 100)
                surf, _ = self.fonts["small"].render(initial, color)
                self.screen.blit(surf, (x + icon_size // 2 - surf.get_width() // 2,
                                       y + icon_size + 2))

    def _draw_bracket(self):
        """대진표 화면 그리기"""
        # 배경 (이집트 파피루스)
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        # 타이틀 (이집트 스타일)
        self._draw_egyptian_title("8강 대진표", 30)

        # 대진표 그리기
        self._draw_tournament_bracket()

        # 현재 상태에 따른 UI
        if self.state == TournamentState.BRACKET_VIEW:
            self._draw_match_selection_hint()
        elif self.state == TournamentState.BETTING:
            self._draw_betting_ui()
        elif self.state == TournamentState.RESULT:
            self._draw_result_ui()
        elif self.state == TournamentState.ROUND_END:
            self._draw_round_end_ui()
        elif self.state == TournamentState.TOURNAMENT_END:
            self._draw_tournament_end_ui()

    def _draw_tournament_bracket(self):
        """토너먼트 대진표 그리기"""
        # 박스 크기 (120x160으로 확대)
        box_w, box_h = 120, 160

        # 8강 매치 (하단) - 위로 올림
        y_base = 530
        x_positions = [60, 195, 430, 565]

        for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
            x = x_positions[i]
            self._draw_match_box(match, x, y_base, i)

        # 4강 매치 (중간) - 위로 올림
        y_semi = 310
        x_semi = [127, 497]

        for i, match in enumerate(self.matches.get(TournamentRound.SEMI_FINAL, [])):
            self._draw_match_box(match, x_semi[i], y_semi, i + 4)

        # 빈 4강 슬롯
        if not self.matches.get(TournamentRound.SEMI_FINAL):
            for i, x in enumerate(x_semi):
                self._draw_empty_match_box(x, y_semi, "준결승 " + str(i + 1))

        # 결승 (상단) - 위로 올림
        y_final = 80
        x_final = 312

        final_matches = self.matches.get(TournamentRound.FINAL, [])
        if final_matches:
            self._draw_match_box(final_matches[0], x_final, y_final, 6)
        else:
            self._draw_empty_match_box(x_final, y_final, "결승")

        # 연결선 그리기
        self._draw_bracket_lines()

    def _draw_match_box(self, match: Match, x: int, y: int, match_idx: int):
        """매치 박스 그리기 (대각선 분할 레이아웃) - 이집트 파피루스 테마"""
        box_w, box_h = 120, 140

        # ========== 비공개 매치 표시 ==========
        if not self.initial_setup_done and self.current_round == TournamentRound.QUARTER_FINAL:
            if not self.match_revealed[match_idx]:
                is_hovered = (self.hover_match_index == match_idx)
                # 매치 공개 카드 플립 애니메이션
                if self.state == TournamentState.MATCH_REVEAL and self.match_reveal_index == match_idx:
                    total_duration = 1.2
                    progress = min(1.0, self.match_reveal_timer / total_duration)
                    # ease-in-out for smooth feel
                    eased = 0.5 - 0.5 * math.cos(progress * math.pi)

                    # 카드 플립: scale_x가 1→0→1 (0.5 지점에서 뒤→앞 전환)
                    if eased < 0.5:
                        t = eased / 0.5
                        scale_x = math.cos(t * math.pi / 2)  # 1.0 → 0.0
                        showing_front = False
                    else:
                        t = (eased - 0.5) / 0.5
                        scale_x = math.sin(t * math.pi / 2)  # 0.0 → 1.0
                        showing_front = True

                    # 전체 스케일: 최대 1.4배까지 커졌다가 복귀
                    scale_overall = 1.0 + 0.4 * math.sin(eased * math.pi)
                    # Y 오프셋: 위로 살짝 떠오름
                    y_lift = -35 * math.sin(eased * math.pi)
                    # 회전: 살짝 기울어졌다가 복귀
                    rotation = 6 * math.sin(eased * math.pi * 2)

                    # === 카드 표면 생성 ===
                    card_surf = pygame.Surface((box_w, box_h), pygame.SRCALPHA)

                    if not showing_front:
                        # 뒷면: 미스터리 "?" 카드
                        pygame.draw.rect(card_surf, ET["card_bg"], (0, 0, box_w, box_h), border_radius=8)
                        pygame.draw.rect(card_surf, ET["card_border"], (0, 0, box_w, box_h), 2, border_radius=8)
                        # 이집트풍 내부 테두리
                        inner = 6
                        pygame.draw.rect(card_surf, ET.get("gold_dark", (120, 95, 50)),
                                         (inner, inner, box_w - inner * 2, box_h - inner * 2), 1, border_radius=5)
                        # "?" 심볼
                        if self.fonts and "large" in self.fonts:
                            q_surf, _ = self.fonts["large"].render("?", ET["gold_pale"])
                            card_surf.blit(q_surf, (box_w // 2 - q_surf.get_width() // 2,
                                                    box_h // 2 - q_surf.get_height() // 2))
                    else:
                        # 앞면: 매치 내용 공개
                        pygame.draw.rect(card_surf, ET["card_bg"], (0, 0, box_w, box_h), border_radius=8)
                        pygame.draw.rect(card_surf, ET["gold_bright"], (0, 0, box_w, box_h), 2, border_radius=8)
                        # 대각선
                        pygame.draw.line(card_surf, ET["card_diagonal"],
                                         (5, box_h - 5), (box_w - 5, 5), 2)
                        # 영웅1 이름 (좌상단)
                        h1_color = match.hero1["color"]
                        h1_brightness = sum(h1_color) / 3
                        h1_name_color = h1_color if h1_brightness > 80 else (
                            min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))
                        if self.fonts and "small" in self.fonts:
                            surf1, _ = self.fonts["small"].render(match.hero1.get("name", "???"), h1_name_color)
                            card_surf.blit(surf1, (8, 8))
                        # 영웅1 캐릭터 이미지
                        if self.hero_paddle_renderer:
                            self.hero_paddle_renderer.draw_hero_paddle(
                                card_surf, match.hero1.get("id", "mugen"), 25, 55, 64, 45,
                                facing="down", color=h1_color, scale_mode="preview"
                            )
                        # VS 원형
                        vs_cx, vs_cy = box_w // 2, box_h // 2
                        pygame.draw.circle(card_surf, ET["vs_circle_bg"], (vs_cx, vs_cy), 16)
                        pygame.draw.circle(card_surf, ET["vs_circle_border"], (vs_cx, vs_cy), 16, 2)
                        if self.fonts and "small" in self.fonts:
                            vs_surf, _ = self.fonts["small"].render("VS", ET["gold_bright"])
                            card_surf.blit(vs_surf, (vs_cx - vs_surf.get_width() // 2,
                                                     vs_cy - vs_surf.get_height() // 2))
                        # 영웅2 캐릭터 이미지
                        h2_color = match.hero2["color"]
                        h2_brightness = sum(h2_color) / 3
                        h2_name_color = h2_color if h2_brightness > 80 else (
                            min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))
                        if self.hero_paddle_renderer:
                            self.hero_paddle_renderer.draw_hero_paddle(
                                card_surf, match.hero2.get("id", "chronos"), box_w - 25, box_h - 55, 64, 45,
                                facing="down", color=h2_color, scale_mode="preview"
                            )
                        # 영웅2 이름 (우하단)
                        if self.fonts and "small" in self.fonts:
                            surf2, _ = self.fonts["small"].render(match.hero2.get("name", "???"), h2_name_color)
                            card_surf.blit(surf2, (box_w - surf2.get_width() - 8, box_h - 22))

                    # === 변환 적용 ===
                    scaled_w = max(1, int(box_w * scale_x * scale_overall))
                    scaled_h = max(1, int(box_h * scale_overall))

                    scaled_surf = pygame.transform.smoothscale(card_surf, (scaled_w, scaled_h))

                    # 회전 적용
                    if abs(rotation) > 0.5:
                        rotated_surf = pygame.transform.rotate(scaled_surf, rotation)
                    else:
                        rotated_surf = scaled_surf

                    # 원래 위치 중심으로 배치
                    center_x = x + box_w // 2
                    center_y = y + box_h // 2 + int(y_lift)
                    draw_x = center_x - rotated_surf.get_width() // 2
                    draw_y = center_y - rotated_surf.get_height() // 2

                    # 글로우 이펙트 (플립 중 발광)
                    glow_alpha = int(100 * math.sin(eased * math.pi))
                    if glow_alpha > 10:
                        glow_pad = int(8 * scale_overall)
                        glow_surf = pygame.Surface(
                            (rotated_surf.get_width() + glow_pad * 2,
                             rotated_surf.get_height() + glow_pad * 2), pygame.SRCALPHA)
                        pygame.draw.rect(glow_surf,
                                         (*ET["gold_bright"], glow_alpha),
                                         (0, 0, glow_surf.get_width(), glow_surf.get_height()),
                                         border_radius=12)
                        self.screen.blit(glow_surf, (draw_x - glow_pad, draw_y - glow_pad))

                    self.screen.blit(rotated_surf, (draw_x, draw_y))
                    return
                # 비공개 상태
                if is_hovered:
                    self._draw_hover_border(x, y, box_w, box_h, ET["hover_glow"])
                bg = ET["card_bg_hover"] if is_hovered else ET["card_bg"]
                pygame.draw.rect(self.screen, bg, (x, y, box_w, box_h), border_radius=8)
                border = ET["bronze"] if is_hovered else ET["card_border"]
                pygame.draw.rect(self.screen, border, (x, y, box_w, box_h), 2, border_radius=8)
                cx, cy = x + box_w // 2, y + box_h // 2
                if self.fonts and "large" in self.fonts:
                    q_color = ET["gold_pale"] if is_hovered else ET["text_disabled"]
                    surf, _ = self.fonts["large"].render("?", q_color)
                    self.screen.blit(surf, (cx - surf.get_width() // 2, cy - surf.get_height() // 2))
                if self.fonts and "small" in self.fonts:
                    h_color = ET["gold_pale"] if is_hovered else ET["text_hint"]
                    surf, _ = self.fonts["small"].render("클릭하여 공개", h_color)
                    self.screen.blit(surf, (cx - surf.get_width() // 2, cy + 30))
                return

        is_hovered = (self.hover_match_index == match_idx and not match.completed)

        # 호버 시 테두리 이펙트
        if is_hovered:
            self._draw_hover_border(x, y, box_w, box_h, ET["hover_glow"])

        # 박스 배경 (이집트 팔레트)
        if is_hovered:
            bg_color = ET["card_bg_hover"]
        elif match.completed:
            bg_color = ET["card_bg_completed"]
        else:
            bg_color = ET["card_bg"]
        border_color = ET["card_border_hover"] if is_hovered else ET["card_border"]
        border_width = 2
        pygame.draw.rect(self.screen, bg_color, (x, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, border_color, (x, y, box_w, box_h), border_width, border_radius=8)

        # 대각선 (왼쪽 하단 → 오른쪽 상단)
        pygame.draw.line(self.screen, ET["card_diagonal"], (x + 5, y + box_h - 5), (x + box_w - 5, y + 5), 2)

        # === 영웅 1 (왼쪽 상단 삼각형) ===
        h1_color = match.hero1["color"]
        hero1_name = match.hero1.get("name", "???")
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h1_brightness = sum(h1_color) / 3
        h1_name_color = h1_color if h1_brightness > 80 else (min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))
        # 이름 (상단 좌측)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero1_name, h1_name_color)
            self.screen.blit(surf, (x + 8, y + 8))
        # 캐릭터 이미지 (좌측 - 더 왼쪽으로, 60% 크게)
        if self.hero_paddle_renderer:
            hero1_id = match.hero1.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1_id, x + 25, y + 55, 64, 45,
                facing="down", color=h1_color, scale_mode="preview"
            )

        # === VS (중앙 원) - 이집트 ===
        vs_x = x + box_w // 2
        vs_y = y + box_h // 2
        pygame.draw.circle(self.screen, ET["vs_circle_bg"], (vs_x, vs_y), 16)
        pygame.draw.circle(self.screen, ET["vs_circle_border"], (vs_x, vs_y), 16, 2)
        if self.fonts and "small" in self.fonts:
            surf, _ = self._render_text("small", "VS", ET["gold_bright"])
            if surf:
                self.screen.blit(surf, (vs_x - surf.get_width() // 2, vs_y - surf.get_height() // 2))

        # === 영웅 2 (오른쪽 하단 삼각형) ===
        h2_color = match.hero2["color"]
        hero2_name = match.hero2.get("name", "???")
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h2_brightness = sum(h2_color) / 3
        h2_name_color = h2_color if h2_brightness > 80 else (min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))
        # 캐릭터 이미지 (우측 - 더 오른쪽으로, 60% 크게)
        if self.hero_paddle_renderer:
            hero2_id = match.hero2.get("id", "chronos")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2_id, x + box_w - 25, y + box_h - 55, 64, 45,
                facing="down", color=h2_color, scale_mode="preview"
            )
        # 이름 (하단 우측)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero2_name, h2_name_color)
            self.screen.blit(surf, (x + box_w - surf.get_width() - 8, y + box_h - 22))

        # 결과 표시
        if match.completed and match.winner:
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render(f"{match.score1}:{match.score2}", ET["gold_bright"])
                self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + box_h + 5))

    def _draw_empty_match_box(self, x: int, y: int, label: str):
        """빈 매치 박스 - 이집트 테마"""
        box_w, box_h = 120, 140
        pygame.draw.rect(self.screen, ET["bg_medium"], (x, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, ET["card_border"], (x, y, box_w, box_h), 2, border_radius=8)

        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(label, ET["text_disabled"])
            self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + box_h // 2 - surf.get_height() // 2))

    # ========================================================================
    # 초반 셋업 UI 메서드
    # ========================================================================

    def _draw_hero_select(self):
        """영웅 선택 UI (2명 중 1명 선택)"""
        import math
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        if not self.selected_match:
            return

        # 공격 퍼포먼스 애니메이션 상태
        anim_phase = getattr(self, '_hero_select_anim_phase', None)
        anim_idx = getattr(self, '_hero_select_anim_index', -1)
        anim_timer = getattr(self, '_hero_select_anim_timer', 0)

        # 타이틀
        self._draw_egyptian_title("영웅을 선택하세요", 30)

        # 두 영웅 카드
        hero1 = self.selected_match.hero1
        hero2 = self.selected_match.hero2
        card_w, card_h = 200, 320
        gap = 40
        panel_x = 130
        card1_x = panel_x + 25
        card2_x = panel_x + 25 + card_w + gap
        card_y = 100

        for idx, (hero, cx) in enumerate([(hero1, card1_x), (hero2, card2_x)]):
            is_selected = (anim_phase and anim_idx == idx)
            is_dimmed = (anim_phase and anim_idx != idx)
            is_hovered = (self.hover_hero_index == idx) and not anim_phase

            # 카드 배경
            if is_dimmed:
                bg = (35, 28, 18)
                border = (80, 65, 42)
            elif is_selected or is_hovered:
                bg = ET["card_bg_hover"]
                border = ET["gold_medium"]
            else:
                bg = ET["card_bg"]
                border = ET["card_border"]
            pygame.draw.rect(self.screen, bg, (cx, card_y, card_w, card_h), border_radius=10)
            pygame.draw.rect(self.screen, border, (cx, card_y, card_w, card_h), 2, border_radius=10)

            # 영웅 색상 바
            color_bar = pygame.Surface((card_w - 20, 6), pygame.SRCALPHA)
            color_bar.fill((*hero["color"], 60 if is_dimmed else 180))
            self.screen.blit(color_bar, (cx + 10, card_y + 10))

            # 영웅 이름
            if self.fonts and "medium" in self.fonts:
                h_color = hero["color"]
                brightness = sum(h_color) / 3
                name_color = h_color if brightness > 80 else (min(255, h_color[0]+100), min(255, h_color[1]+100), min(255, h_color[2]+100))
                if is_dimmed:
                    name_color = tuple(c // 3 for c in name_color)
                surf, _ = self.fonts["medium"].render(hero["name"], name_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 25))

            # 영웅 칭호
            if self.fonts and "small" in self.fonts:
                title_color = (80, 70, 50) if is_dimmed else ET["text_subtitle"]
                surf, _ = self.fonts["small"].render(hero.get("title", ""), title_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 50))

            # ── 영웅 캐릭터 렌더링 (공격 모션 포함) ──
            hero_offset_y = 0
            hero_scale = 1.0

            if is_selected:
                mt = anim_timer
                if mt < 0.2:
                    # 뒤로 힘 모으기
                    p = mt / 0.2
                    hero_offset_y = int(-10 * p)
                    hero_scale = 1.0 + 0.05 * p
                elif mt < 0.4:
                    # 앞으로 돌진
                    p = (mt - 0.2) / 0.2
                    eased = p * p
                    hero_offset_y = int(-10 + 35 * eased)
                    hero_scale = 1.05 + 0.15 * eased
                else:
                    # 임팩트 유지 + 무기 스윙 모션 (복귀 없음)
                    hero_offset_y = 25
                    hero_scale = 1.2
                    if not getattr(self, '_hero_select_swing_triggered', False):
                        self._hero_select_swing_triggered = True
                        _load_select_swing_sound()
                        if _select_swing_sound:
                            _select_swing_sound.play()
                        if self.hero_paddle_renderer:
                            self.hero_paddle_renderer.trigger_weapon_swing(
                                hero["id"], 0.5)

            if self.hero_paddle_renderer:
                h_w = int(100 * hero_scale)
                h_h = int(70 * hero_scale)
                h_cx = cx + card_w // 2
                h_cy = card_y + 120 + hero_offset_y

                if is_dimmed:
                    dim_s = pygame.Surface((card_w, 140), pygame.SRCALPHA)
                    self.hero_paddle_renderer.draw_hero_paddle(
                        dim_s, hero["id"], card_w // 2, 70,
                        100, 70, facing="down", color=hero["color"], scale_mode="preview"
                    )
                    dim_s.set_alpha(80)
                    self.screen.blit(dim_s, (cx, card_y + 50))
                else:
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, hero["id"], h_cx, h_cy,
                        h_w, h_h, facing="down", color=hero["color"], scale_mode="preview"
                    )

            # ── 공격 퍼포먼스 이펙트 ──
            if is_selected and anim_timer >= 0.4:
                flash_t = anim_timer - 0.4
                if flash_t <= 0.3:
                    flash_alpha = int(180 * (1.0 - flash_t / 0.3))
                    flash_s = pygame.Surface((card_w + 40, 80), pygame.SRCALPHA)
                    pygame.draw.ellipse(flash_s, (255, 240, 180, flash_alpha),
                                        (0, 0, card_w + 40, 80))
                    self.screen.blit(flash_s, (cx - 20, card_y + 120 + hero_offset_y))

            # 스타일 표시
            style_names = {"aggressive": "공격형", "defensive": "수비형", "balanced": "균형형", "tricky": "트릭형"}
            style_text = style_names.get(hero["style"].value, "???")
            if self.fonts and "small" in self.fonts:
                style_color = (60, 52, 35) if is_dimmed else ET["text_hint"]
                surf, _ = self.fonts["small"].render(f"[{style_text}]", style_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 175))

            # 스킬 2개 표시
            from downtown.hero_skills import HERO_SKILLS
            hero_skills = HERO_SKILLS.get(hero["id"], [])
            skill_y = card_y + 200
            for si, skill in enumerate(hero_skills):
                skill_h = 32
                sk_bg = (30, 25, 16) if is_dimmed else ET["skill_bg"]
                sk_border = (50, 42, 28) if is_dimmed else ET["skill_border"]
                pygame.draw.rect(self.screen, sk_bg, (cx + 8, skill_y, card_w - 16, skill_h), border_radius=5)
                pygame.draw.rect(self.screen, sk_border, (cx + 8, skill_y, card_w - 16, skill_h), 1, border_radius=5)
                icon = _get_hero_skill_icon(skill.skill_id, 24)
                icon_x = cx + 14
                icon_y_pos = skill_y + 4
                if icon:
                    if is_dimmed:
                        dim_icon = icon.copy()
                        dim_icon.set_alpha(60)
                        self.screen.blit(dim_icon, (icon_x, icon_y_pos))
                    else:
                        self.screen.blit(icon, (icon_x, icon_y_pos))
                else:
                    pygame.draw.rect(self.screen, ET["bg_medium"], (icon_x, icon_y_pos, 24, 24), border_radius=4)
                if self.fonts and "small" in self.fonts:
                    label = f"{'A' if si == 0 else 'B'}: {skill.korean_name}"
                    txt_color = (60, 55, 40) if is_dimmed else ET["text_body"]
                    surf, _ = self.fonts["small"].render(label, txt_color)
                    self.screen.blit(surf, (icon_x + 30, skill_y + 8))
                skill_y += skill_h + 5

        # VS 텍스트 (애니메이션 중이 아닐 때만)
        if not anim_phase:
            vs_x = card1_x + card_w + gap // 2
            vs_y = card_y + card_h // 2
            if self.fonts and "large" in self.fonts:
                pulse = 0.7 + 0.3 * abs(_sin(self.animation_timer * 3))
                vs_color = (ET["carnelian_light"][0], int(100 + 100 * pulse), 50)
                vs_surf, _ = self.fonts["large"].render("VS", vs_color)
                self.screen.blit(vs_surf, (vs_x - vs_surf.get_width() // 2, vs_y - vs_surf.get_height() // 2))

        # ================================================================
        # 하단 스킬 룰렛 (영웅 선택 후 같은 화면에서 스킬 결정)
        # ================================================================
        if anim_phase in ("skill_rolling", "skill_selected"):
            self._draw_inline_skill_roulette()

    def _draw_inline_skill_roulette(self, base_y=432):
        """영웅/호위무사 선택 화면 하단 스킬 룰렛 UI (큰 아이콘 + 두루마리 펼침)
        base_y: 구분선 시작 Y좌표
        """
        target_id = self.skill_reveal_target
        if not target_id:
            return

        timer = self.skill_reveal_timer
        phase = self.skill_reveal_phase  # "rolling" or "selected"

        from downtown.hero_skills import HERO_SKILLS
        hero_skills = HERO_SKILLS.get(target_id, [])
        if len(hero_skills) < 2:
            return

        # 구분선
        pygame.draw.line(self.screen, ET["gold_dark"], (120, base_y), (640, base_y), 1)

        # 타이틀
        title_y = base_y + 8
        if self.fonts and "medium" in self.fonts:
            title_surf, _ = self.fonts["medium"].render("스킬 결정!", ET["gold_medium"])
            self.screen.blit(title_surf, (SCREEN_WIDTH // 2 - title_surf.get_width() // 2, title_y))

        # 카드 레이아웃 (큰 아이콘 중심)
        icon_size = 72  # 3배 크기
        sk_card_w = 200
        base_card_h = 115  # 롤링 시: 아이콘 + 이름만
        sk_gap = 30
        sk_total_w = sk_card_w * 2 + sk_gap
        sk_card1_x = (SCREEN_WIDTH - sk_total_w) // 2
        sk_card2_x = sk_card1_x + sk_card_w + sk_gap
        sk_card_y = title_y + 30

        # 두루마리 펼침 (선택 시 카드 확장)
        sel_timer = getattr(self, 'skill_reveal_selected_timer', 0)
        scroll_reveal = 0.0
        desc_extra_h = 105  # 설명 영역 최대 높이
        if phase == "selected":
            scroll_reveal = min(1.0, sel_timer / 0.6)  # 0.6초에 걸쳐 펼침
        sk_card_h = base_card_h + int(desc_extra_h * scroll_reveal)

        # === 룰렛 로직: 연속 감속 ===
        rolling_duration = 3.5
        highlight_idx = 0
        if phase == "rolling":
            t_norm = min(1.0, timer / rolling_duration)
            eased = 1.0 - (1.0 - t_norm) ** 4
            total_ticks = eased * 24
            current_tick = int(total_ticks)
            if (24 % 2) != self.skill_reveal_result:
                current_tick += 1
            highlight_idx = current_tick % 2
            if t_norm > 0.90:
                highlight_idx = self.skill_reveal_result
            # 틱 사운드
            if current_tick != self._skill_reveal_last_tick_idx:
                self._skill_reveal_last_tick_idx = current_tick
                _load_hover_sound()
                if _hover_sound:
                    _hover_sound.play()

        # 파티클
        particles = getattr(self, '_skill_reveal_particles', [])
        if phase == "selected":
            sel_cx = sk_card1_x if self.skill_reveal_result == 0 else sk_card2_x
            for _ in range(2):
                side = random.randint(0, 3)
                if side == 0:
                    px, py = random.uniform(sel_cx, sel_cx + sk_card_w), sk_card_y
                elif side == 1:
                    px, py = sel_cx + sk_card_w, random.uniform(sk_card_y, sk_card_y + sk_card_h)
                elif side == 2:
                    px, py = random.uniform(sel_cx, sel_cx + sk_card_w), sk_card_y + sk_card_h
                else:
                    px, py = sel_cx, random.uniform(sk_card_y, sk_card_y + sk_card_h)
                particles.append({
                    'x': px, 'y': py,
                    'vx': random.uniform(-1.2, 1.2),
                    'vy': random.uniform(-2.0, -0.3),
                    'life': 1.0,
                    'size': random.uniform(2, 4),
                    'color': random.choice([
                        (255, 215, 50), (100, 210, 200), (218, 175, 32),
                        (64, 176, 166), (255, 230, 140)
                    ])
                })
            for p in particles:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['life'] -= 0.03
                p['size'] *= 0.97
            particles[:] = [p for p in particles if p['life'] > 0]
            self._skill_reveal_particles = particles

        # 스킬 카드 2개 렌더링
        for si, (skill, cx) in enumerate([(hero_skills[0], sk_card1_x), (hero_skills[1], sk_card2_x)]):
            is_selected = (si == self.skill_reveal_result)
            is_faded = (phase == "selected" and not is_selected)

            if phase == "rolling":
                is_highlight = (si == highlight_idx)
                if is_highlight:
                    bg = ET["card_bg_hover"]
                    border = ET["gold_medium"]
                    border_w = 2
                else:
                    bg = ET["card_bg"]
                    border = ET["card_border"]
                    border_w = 1
            elif phase == "selected":
                if is_selected:
                    pulse = 0.6 + 0.4 * abs(_sin(sel_timer * 4))
                    bg = (35, int(55 + 25 * pulse), int(55 + 20 * pulse))
                    border = (64, int(160 + 60 * pulse), int(150 + 50 * pulse))
                    border_w = 3
                else:
                    bg = ET["bg_dark"]
                    border = (50, 40, 28)
                    border_w = 1
            else:
                bg = ET["card_bg"]
                border = ET["card_border"]
                border_w = 1

            # 탈락 카드는 확장 안 함
            cur_h = sk_card_h if (phase != "selected" or is_selected) else base_card_h

            # 글로우 오라
            if phase == "selected" and is_selected:
                glow_pulse = 0.5 + 0.5 * abs(_sin(sel_timer * 3))
                glow_alpha = int(35 + 25 * glow_pulse)
                glow_expand = int(4 + 3 * glow_pulse)
                glow_surf = _get_arena_surface(sk_card_w + glow_expand * 2, cur_h + glow_expand * 2)
                glow_color = (*ET["turquoise"], glow_alpha)
                pygame.draw.rect(glow_surf, glow_color,
                                 (0, 0, sk_card_w + glow_expand * 2, cur_h + glow_expand * 2),
                                 border_radius=10)
                self.screen.blit(glow_surf, (cx - glow_expand, sk_card_y - glow_expand))

            # 카드 배경
            pygame.draw.rect(self.screen, bg, (cx, sk_card_y, sk_card_w, cur_h), border_radius=8)
            pygame.draw.rect(self.screen, border, (cx, sk_card_y, sk_card_w, cur_h), border_w, border_radius=8)

            # 이중 보더
            if phase == "selected" and is_selected:
                inner_pulse = 0.3 + 0.7 * abs(_sin(sel_timer * 5))
                inner_color = (64, int(170 + 40 * inner_pulse), int(160 + 40 * inner_pulse))
                pygame.draw.rect(self.screen, inner_color,
                                 (cx + 2, sk_card_y + 2, sk_card_w - 4, cur_h - 4),
                                 1, border_radius=6)

            alpha_mod = 60 if is_faded else 255

            # 라벨 (좌상단)
            label = "A" if si == 0 else "B"
            if self.fonts and "small" in self.fonts:
                label_alpha = 80 if is_faded else 160
                surf, _ = self.fonts["small"].render(label, (label_alpha, int(label_alpha * 0.85), 30))
                self.screen.blit(surf, (cx + 10, sk_card_y + 8))

            # 큰 아이콘 (중앙 배치, 72px)
            icon = _get_hero_skill_icon(skill.skill_id, icon_size)
            icon_x = cx + sk_card_w // 2 - icon_size // 2
            icon_y = sk_card_y + 10
            if icon:
                if is_faded:
                    faded_icon = icon.copy()
                    faded_icon.set_alpha(80)
                    self.screen.blit(faded_icon, (icon_x, icon_y))
                else:
                    self.screen.blit(icon, (icon_x, icon_y))
            else:
                pygame.draw.rect(self.screen, ET["bg_medium"],
                                 (icon_x, icon_y, icon_size, icon_size), border_radius=8)

            # 스킬 이름 (아이콘 아래 중앙)
            if self.fonts and "medium" in self.fonts:
                name_color = (alpha_mod, alpha_mod, alpha_mod)
                surf, _ = self.fonts["medium"].render(skill.korean_name, name_color)
                self.screen.blit(surf, (cx + sk_card_w // 2 - surf.get_width() // 2, sk_card_y + 85))

            # === 두루마리 펼침: 선택 확정 후 설명 영역 ===
            if phase == "selected" and is_selected and scroll_reveal > 0.01:
                desc_area_y = sk_card_y + base_card_h
                revealed_h = int(desc_extra_h * scroll_reveal)
                # 클립 서피스로 두루마리 펼침 효과
                desc_w = sk_card_w - 4  # 넉넉한 너비로 텍스트 잘림 방지
                desc_surf = _get_arena_surface(desc_w, desc_extra_h)
                dy = 0

                # 장식 구분선 (두루마리 가장자리)
                line_alpha = min(200, int(255 * scroll_reveal))
                scroll_edge_color = (*ET["gold_dark"], line_alpha)
                pygame.draw.line(desc_surf, scroll_edge_color, (5, 0), (desc_w - 10, 0), 1)
                dy += 8

                # 발동 조건 + 쿨타임
                if self.fonts and "small" in self.fonts:
                    trigger_text = ""
                    trigger_color = (100, 100, 100)
                    trigger_val = getattr(skill, 'trigger', None)
                    if trigger_val:
                        from downtown.hero_skills import SkillTrigger
                        if trigger_val == SkillTrigger.ON_BALL_HIT:
                            trigger_text = "타격 발동"
                            trigger_color = ET["lapis_light"]
                        elif trigger_val == SkillTrigger.ON_COOLDOWN:
                            trigger_text = "자동 발동"
                            trigger_color = ET["gold_pale"]
                        else:
                            trigger_text = "패시브"
                            trigger_color = ET["malachite_light"]
                    if trigger_text:
                        cd_text = f"{trigger_text} | 쿨타임 {int(skill.cooldown)}초"
                        surf, _ = self.fonts["small"].render(cd_text, trigger_color)
                        desc_surf.blit(surf, (desc_w // 2 - surf.get_width() // 2, dy))
                    dy += 20

                # 스킬 설명 (최대 3줄)
                if self.fonts and "small" in self.fonts:
                    desc = getattr(skill, 'description', '')
                    desc_color = (180, 180, 180)
                    max_line = 16
                    lines = []
                    while desc and len(lines) < 3:
                        if len(desc) <= max_line:
                            lines.append(desc)
                            break
                        lines.append(desc[:max_line])
                        desc = desc[max_line:]
                    for line in lines:
                        surf, _ = self.fonts["small"].render(line, desc_color)
                        desc_surf.blit(surf, (desc_w // 2 - surf.get_width() // 2, dy))
                        dy += 18

                # 지속시간
                if skill.duration and skill.duration > 0 and skill.duration < 999:
                    if self.fonts and "small" in self.fonts:
                        surf, _ = self.fonts["small"].render(
                            f"지속: {skill.duration:.1f}초", ET["malachite_light"])
                        desc_surf.blit(surf, (desc_w // 2 - surf.get_width() // 2, dy))

                # 클립하여 펼침 효과
                if revealed_h >= desc_extra_h:
                    # 완전히 펼쳐짐 - 직접 blit
                    self.screen.blit(desc_surf, (cx + 2, desc_area_y))
                else:
                    # 펼침 중 - 클립 서피스로 잘라서 표시
                    clip_surf = _get_arena_surface(desc_w, revealed_h)
                    clip_surf.blit(desc_surf, (0, 0))
                    self.screen.blit(clip_surf, (cx + 2, desc_area_y))

                # 두루마리 하단 장식선
                if scroll_reveal > 0.3:
                    edge_y = desc_area_y + revealed_h - 2
                    edge_alpha = min(150, int(200 * (scroll_reveal - 0.3) / 0.7))
                    edge_s = _get_arena_surface(sk_card_w - 12, 3)
                    edge_s.fill((*ET["gold_dark"], edge_alpha))
                    self.screen.blit(edge_s, (cx + 6, edge_y))

            # SELECTED 마크
            if phase == "selected" and is_selected and scroll_reveal > 0.8:
                mark_alpha = min(1.0, (scroll_reveal - 0.8) / 0.2)
                if self.fonts and "medium" in self.fonts:
                    glow_text_pulse = 0.7 + 0.3 * abs(_sin(sel_timer * 3))
                    r = int(100 + 155 * glow_text_pulse * mark_alpha)
                    g = int(200 + 40 * glow_text_pulse * mark_alpha)
                    b = int(80 + 120 * glow_text_pulse * mark_alpha)
                    surf, _ = self.fonts["medium"].render("SELECTED", (r, g, b))
                    alpha_s = _get_arena_surface(*surf.get_size())
                    alpha_s.fill((255, 255, 255, int(255 * mark_alpha)))
                    surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                    self.screen.blit(surf, (cx + sk_card_w // 2 - surf.get_width() // 2,
                                            sk_card_y + cur_h - 24))

        # 파티클 렌더링
        if phase == "selected" and particles:
            for p in particles:
                a = max(0, min(255, int(255 * p['life'])))
                sz = max(1, int(p['size']))
                ps = _get_arena_surface(sz * 2, sz * 2)
                pc = (*p['color'][:3], a)
                pygame.draw.circle(ps, pc, (sz, sz), sz)
                self.screen.blit(ps, (int(p['x']) - sz, int(p['y']) - sz))

        # 하단 안내
        hint_y = sk_card_y + sk_card_h + 15
        if phase == "rolling":
            if self.fonts and "small" in self.fonts:
                dot_count = int(timer * 3) % 4
                dots = "." * dot_count
                surf, _ = self.fonts["small"].render(f"스킬 결정 중{dots}", ET["text_hint"])
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, hint_y))
        elif phase == "selected":
            if self.fonts and "small" in self.fonts:
                hint_alpha = min(200, int(max(0, sel_timer - 0.5) * 300))
                surf, _ = self.fonts["small"].render("클릭하여 계속", (hint_alpha, hint_alpha, hint_alpha + 20))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, hint_y))

    def _draw_skill_reveal(self):
        """스킬 랜덤 선택 연출 UI (감속 롤링 + 선택 이펙트)"""
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        target_id = self.skill_reveal_target
        is_guard = (self.state == TournamentState.GUARD_SKILL_REVEAL)
        hero = self.player_guard if is_guard else self.player_hero
        if not hero:
            return

        timer = self.skill_reveal_timer
        phase = self.skill_reveal_phase

        # 타이틀
        title = f"{'호위무사' if is_guard else '영웅'} 스킬 결정!"
        self._draw_egyptian_title(title, 40)

        # 영웅 이름
        if self.fonts and "medium" in self.fonts:
            h_color = hero["color"]
            brightness = sum(h_color) / 3
            name_color = h_color if brightness > 80 else (min(255, h_color[0]+100), min(255, h_color[1]+100), min(255, h_color[2]+100))
            surf, _ = self.fonts["medium"].render(f"{hero['name']} - {hero.get('title', '')}", name_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 90))

        # 스킬 카드 2개
        from downtown.hero_skills import HERO_SKILLS
        hero_skills = HERO_SKILLS.get(target_id, [])
        if len(hero_skills) < 2:
            return

        card_w, card_h = 240, 280
        gap = 40
        card1_x = SCREEN_WIDTH // 2 - gap // 2 - card_w
        card2_x = SCREEN_WIDTH // 2 + gap // 2
        card_y = 140

        # === 리얼 룰렛: 빠름 → 연속 감속 → 매우 느림 ===
        rolling_duration = 3.5
        highlight_idx = 0
        if phase == "rolling":
            t_norm = min(1.0, timer / rolling_duration)
            # ease-out quartic: 처음 빠르게 → 계속 감속 → 마지막에 매우 느림
            eased = 1.0 - (1.0 - t_norm) ** 4
            total_ticks = eased * 24
            current_tick = int(total_ticks)
            # 마지막 틱이 결과와 일치하도록 오프셋 보정
            if (24 % 2) != self.skill_reveal_result:
                current_tick += 1
            highlight_idx = current_tick % 2
            # 마지막 10%: 선택될 카드에 고정
            if t_norm > 0.90:
                highlight_idx = self.skill_reveal_result
            # 틱 변경 시 호버 사운드 재생
            if current_tick != self._skill_reveal_last_tick_idx:
                self._skill_reveal_last_tick_idx = current_tick
                _load_hover_sound()
                if _hover_sound:
                    _hover_sound.play()

        # === 선택 이펙트 파티클 생성/업데이트 ===
        sel_timer = getattr(self, 'skill_reveal_selected_timer', 0)
        particles = getattr(self, '_skill_reveal_particles', [])

        if phase == "selected":
            # 파티클 생성 (매 프레임 2~3개)
            sel_cx = card1_x if self.skill_reveal_result == 0 else card2_x
            for _ in range(3):
                # 카드 테두리를 따라 랜덤 위치에서 파티클 생성
                side = random.randint(0, 3)  # 0=상, 1=우, 2=하, 3=좌
                if side == 0:
                    px, py = random.uniform(sel_cx, sel_cx + card_w), card_y
                elif side == 1:
                    px, py = sel_cx + card_w, random.uniform(card_y, card_y + card_h)
                elif side == 2:
                    px, py = random.uniform(sel_cx, sel_cx + card_w), card_y + card_h
                else:
                    px, py = sel_cx, random.uniform(card_y, card_y + card_h)
                particles.append({
                    'x': px, 'y': py,
                    'vx': random.uniform(-1.5, 1.5),
                    'vy': random.uniform(-2.5, -0.5),
                    'life': 1.0,
                    'size': random.uniform(2, 5),
                    'color': random.choice([
                        (255, 215, 50), (100, 210, 200), (218, 175, 32),
                        (64, 176, 166), (255, 230, 140)
                    ])
                })
            # 파티클 업데이트
            for p in particles:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['life'] -= 0.03
                p['size'] *= 0.97
            particles[:] = [p for p in particles if p['life'] > 0]
            self._skill_reveal_particles = particles

        for si, (skill, cx) in enumerate([(hero_skills[0], card1_x), (hero_skills[1], card2_x)]):
            is_selected = (si == self.skill_reveal_result)
            is_faded = (phase == "selected" and not is_selected)

            if phase == "rolling":
                is_highlight = (si == highlight_idx)
                # 하이라이트 강도 (전환 시 부드러운 전환)
                if is_highlight:
                    bg = ET["card_bg_hover"]
                    border = ET["gold_medium"]
                    border_w = 2
                else:
                    bg = ET["card_bg"]
                    border = ET["card_border"]
                    border_w = 1
            elif phase == "selected":
                if is_selected:
                    # 펄스 글로우
                    pulse = 0.6 + 0.4 * abs(_sin(sel_timer * 4))
                    bg = (35, int(55 + 25 * pulse), int(55 + 20 * pulse))
                    border = (64, int(160 + 60 * pulse), int(150 + 50 * pulse))
                    border_w = 3
                else:
                    # 탈락 카드: 어둡게 + 축소 느낌
                    bg = ET["bg_dark"]
                    border = (50, 40, 28)
                    border_w = 1
            else:
                bg = ET["card_bg"]
                border = ET["card_border"]
                border_w = 1

            # 선택된 카드 글로우 오라 (배경 레이어)
            if phase == "selected" and is_selected:
                glow_pulse = 0.5 + 0.5 * abs(_sin(sel_timer * 3))
                glow_alpha = int(40 + 30 * glow_pulse)
                glow_expand = int(6 + 4 * glow_pulse)
                glow_surf = _get_arena_surface(card_w + glow_expand * 2, card_h + glow_expand * 2)
                glow_color = (*ET["turquoise"], glow_alpha)
                pygame.draw.rect(glow_surf, glow_color,
                                 (0, 0, card_w + glow_expand * 2, card_h + glow_expand * 2),
                                 border_radius=14)
                self.screen.blit(glow_surf, (cx - glow_expand, card_y - glow_expand))

            # 카드 배경
            pygame.draw.rect(self.screen, bg, (cx, card_y, card_w, card_h), border_radius=10)
            pygame.draw.rect(self.screen, border, (cx, card_y, card_w, card_h), border_w, border_radius=10)

            # 선택 카드 추가 내부 테두리 (이중 보더)
            if phase == "selected" and is_selected:
                inner_pulse = 0.3 + 0.7 * abs(_sin(sel_timer * 5))
                inner_color = (64, int(170 + 40 * inner_pulse), int(160 + 40 * inner_pulse))
                pygame.draw.rect(self.screen, inner_color,
                                 (cx + 3, card_y + 3, card_w - 6, card_h - 6),
                                 1, border_radius=8)

            alpha_mod = 60 if is_faded else 255

            # 스킬 라벨
            label = "A" if si == 0 else "B"
            if self.fonts and "medium" in self.fonts:
                label_alpha = 80 if is_faded else 180
                surf, _ = self.fonts["medium"].render(label, (label_alpha, int(label_alpha * 0.85), 30))
                self.screen.blit(surf, (cx + 15, card_y + 12))

            # 스킬 아이콘 (중앙 상단)
            icon = _get_hero_skill_icon(skill.skill_id, 48)
            icon_x = cx + card_w // 2 - 24
            icon_y = card_y + 30
            if icon:
                if is_faded:
                    faded_icon = icon.copy()
                    faded_icon.set_alpha(80)
                    self.screen.blit(faded_icon, (icon_x, icon_y))
                else:
                    self.screen.blit(icon, (icon_x, icon_y))
            else:
                pygame.draw.rect(self.screen, ET["bg_medium"], (icon_x, icon_y, 48, 48), border_radius=8)

            # 스킬 이름
            if self.fonts and "medium" in self.fonts:
                color = (alpha_mod, alpha_mod, alpha_mod)
                surf, _ = self.fonts["medium"].render(skill.korean_name, color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 90))

            # 발동 조건
            if self.fonts and "small" in self.fonts:
                trigger_text = ""
                trigger_color = (100, 100, 100)
                trigger_val = getattr(skill, 'trigger', None)
                if trigger_val:
                    from downtown.hero_skills import SkillTrigger
                    if trigger_val == SkillTrigger.ON_BALL_HIT:
                        trigger_text = "타격 발동"
                        trigger_color = ET["lapis_light"] if not is_faded else (40, 70, 100)
                    elif trigger_val == SkillTrigger.ON_COOLDOWN:
                        trigger_text = "자동 발동"
                        trigger_color = ET["gold_pale"] if not is_faded else (128, 115, 70)
                    else:
                        trigger_text = "패시브"
                        trigger_color = ET["malachite_light"] if not is_faded else (40, 100, 55)
                if trigger_text:
                    cd_text = f"{trigger_text} | 쿨타임 {int(skill.cooldown)}초"
                    surf, _ = self.fonts["small"].render(cd_text, trigger_color)
                    self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 118))

            # 스킬 설명 (2줄까지)
            if self.fonts and "small" in self.fonts:
                desc = getattr(skill, 'description', '')
                desc_color = (min(200, alpha_mod), min(200, alpha_mod), min(200, alpha_mod))
                max_line = 18
                lines = []
                while desc and len(lines) < 2:
                    if len(desc) <= max_line:
                        lines.append(desc)
                        break
                    lines.append(desc[:max_line])
                    desc = desc[max_line:]
                for li, line in enumerate(lines):
                    surf, _ = self.fonts["small"].render(line, desc_color)
                    self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 145 + li * 20))

            # 지속시간
            if skill.duration and skill.duration > 0 and skill.duration < 999:
                if self.fonts and "small" in self.fonts:
                    dur_color = ET["malachite_light"] if not is_faded else (40, 100, 55)
                    surf, _ = self.fonts["small"].render(f"지속: {skill.duration:.1f}초", dur_color)
                    self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 195))

            # 선택됨 마크 (페이드인 + 글로우)
            if phase == "selected" and is_selected:
                mark_alpha = min(1.0, sel_timer * 2.0)
                if self.fonts and "large" in self.fonts:
                    glow_text_pulse = 0.7 + 0.3 * abs(_sin(sel_timer * 3))
                    r = int(100 + 155 * glow_text_pulse * mark_alpha)
                    g = int(200 + 40 * glow_text_pulse * mark_alpha)
                    b = int(80 + 120 * glow_text_pulse * mark_alpha)
                    surf, _ = self.fonts["large"].render("SELECTED", (r, g, b))
                    alpha_s = _get_arena_surface(*surf.get_size())
                    alpha_s.fill((255, 255, 255, int(255 * mark_alpha)))
                    surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                    self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 230))

        # === 파티클 렌더링 (최상위) ===
        if phase == "selected" and particles:
            for p in particles:
                a = max(0, min(255, int(255 * p['life'])))
                sz = max(1, int(p['size']))
                ps = _get_arena_surface(sz * 2, sz * 2)
                pc = (*p['color'][:3], a)
                pygame.draw.circle(ps, pc, (sz, sz), sz)
                self.screen.blit(ps, (int(p['x']) - sz, int(p['y']) - sz))

        # 하단 안내
        if phase == "rolling":
            if self.fonts and "small" in self.fonts:
                dot_count = int(timer * 3) % 4
                dots = "." * dot_count
                surf, _ = self.fonts["small"].render(f"스킬 결정 중{dots}", ET["text_hint"])
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 440))
        elif phase == "selected":
            if self.fonts and "small" in self.fonts:
                hint_alpha = min(200, int(sel_timer * 200))
                surf, _ = self.fonts["small"].render("클릭하여 계속", (hint_alpha, hint_alpha, hint_alpha + 20))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 440))

    def _draw_prison_bars_overlay(self, cx, cy, cw, ch, is_hovered, open_ratio=0.0):
        """감옥 쇠철창 오버레이 - 카드 위에 철창이 덮이는 연출
        open_ratio: 0.0=완전 닫힘, 1.0=완전 열림 (위로 슬라이드)
        """
        if open_ratio >= 1.0:
            return  # 완전히 열린 상태 - 철창 안 그림

        bar_color = ET["iron_bar_hover"] if is_hovered else ET["iron_bar"]
        bar_light = ET["iron_bar_light"]
        bar_dark = ET["iron_bar_dark"]
        rivet_color = ET["iron_rivet"]
        rivet_dark = ET["iron_rivet_dark"]

        # 반투명 서피스로 철창 그리기
        bar_surf = pygame.Surface((cw, ch), pygame.SRCALPHA)

        # 열림 애니메이션 시 투명도 감소 (사라지면서 올라감)
        fade = 1.0 - open_ratio * 0.3  # 최대 30% 투명해짐

        # ── 세로 철창 바 (메인) ──
        bar_width = 6
        bar_spacing = 24
        bar_margin = 8
        for bx_local in range(bar_margin, cw - bar_margin, bar_spacing):
            x = bx_local
            alpha = int((220 if not is_hovered else 160) * fade)

            # 철창 본체 (진한 색)
            pygame.draw.line(bar_surf, (*bar_dark, alpha), (x, 0), (x, ch), bar_width + 2)
            # 철창 본체 (메인)
            pygame.draw.line(bar_surf, (*bar_color, alpha), (x, 0), (x, ch), bar_width)
            # 하이라이트 (왼쪽 빛 반사)
            pygame.draw.line(bar_surf, (*bar_light, max(0, alpha // 3)), (x - 1, 0), (x - 1, ch), 1)

        # ── 가로 철창 바 (상단, 중단, 하단) ──
        h_bar_positions = [12, ch // 3, ch * 2 // 3, ch - 12]
        h_bar_width = 5
        for hy in h_bar_positions:
            alpha = int((200 if not is_hovered else 140) * fade)
            # 가로바 그림자
            pygame.draw.line(bar_surf, (*bar_dark, alpha), (0, hy + 1), (cw, hy + 1), h_bar_width + 1)
            # 가로바 본체
            pygame.draw.line(bar_surf, (*bar_color, alpha), (0, hy), (cw, hy), h_bar_width)
            # 하이라이트
            pygame.draw.line(bar_surf, (*bar_light, max(0, alpha // 3)), (0, hy - 1), (cw, hy - 1), 1)

        # ── 리벳(볼트) - 가로/세로 교차점에 ──
        for bx_local in range(bar_margin, cw - bar_margin, bar_spacing):
            for hy in h_bar_positions:
                rivet_a = int(200 * fade)
                # 리벳 그림자
                pygame.draw.circle(bar_surf, (*rivet_dark, rivet_a), (bx_local, hy), 4)
                # 리벳 본체
                pygame.draw.circle(bar_surf, (*rivet_color, min(255, rivet_a + 20)), (bx_local, hy), 3)
                # 리벳 하이라이트 (빛 반사 점)
                pygame.draw.circle(bar_surf, (220, 220, 210, max(0, int(120 * fade))), (bx_local - 1, hy - 1), 1)

        # ── 상단/하단 고정 프레임 (철창을 고정하는 두꺼운 철제 프레임) ──
        frame_h = 10
        frame_alpha = int((230 if not is_hovered else 170) * fade)
        # 상단 프레임
        pygame.draw.rect(bar_surf, (*bar_dark, frame_alpha), (0, 0, cw, frame_h))
        pygame.draw.rect(bar_surf, (*bar_color, frame_alpha), (1, 1, cw - 2, frame_h - 2))
        pygame.draw.line(bar_surf, (*bar_light, max(0, frame_alpha // 2)), (2, 2), (cw - 2, 2), 1)
        # 하단 프레임
        pygame.draw.rect(bar_surf, (*bar_dark, frame_alpha), (0, ch - frame_h, cw, frame_h))
        pygame.draw.rect(bar_surf, (*bar_color, frame_alpha), (1, ch - frame_h + 1, cw - 2, frame_h - 2))
        pygame.draw.line(bar_surf, (*bar_light, max(0, frame_alpha // 2)), (2, ch - frame_h + 1), (cw - 2, ch - frame_h + 1), 1)

        # ── 감옥 내부 어둡게 (비네트 효과) ──
        if not is_hovered and open_ratio == 0:
            shadow_surf = pygame.Surface((cw, ch), pygame.SRCALPHA)
            for sx in range(15):
                a = int(40 * (1 - sx / 15))
                pygame.draw.line(shadow_surf, (0, 0, 0, a), (sx, 0), (sx, ch), 1)
                pygame.draw.line(shadow_surf, (0, 0, 0, a), (cw - 1 - sx, 0), (cw - 1 - sx, ch), 1)
            bar_surf.blit(shadow_surf, (0, 0))

        # ── 열림 애니메이션: 철창이 위로 슬라이드 ──
        if open_ratio > 0:
            shift_up = int(open_ratio * ch)
            if ch - shift_up > 0:
                # 클리핑: 셀 영역 내에서만 표시
                old_clip = self.screen.get_clip()
                self.screen.set_clip(pygame.Rect(cx, cy, cw, ch))
                self.screen.blit(bar_surf, (cx, cy - shift_up))
                self.screen.set_clip(old_clip)
        else:
            self.screen.blit(bar_surf, (cx, cy))

    def _draw_prison_select(self):
        """감옥 호위무사 선택 UI - 쇠철창 감옥 연출"""
        import math
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        # 애니메이션 타이머
        if not hasattr(self, '_prison_anim_t'):
            self._prison_anim_t = 0
        self._prison_anim_t += 1

        # 철창 열림 애니메이션 상태
        opening_phase = getattr(self, '_prison_opening_phase', None)
        opening_idx = getattr(self, '_prison_opening_index', -1)
        opening_timer = getattr(self, '_prison_opening_timer', 0)

        # 타이틀
        self._draw_egyptian_title("호위무사를 등용하세요", 35)

        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(
                "감옥에 갇힌 영웅 중 1명을 호위무사로 선택합니다", ET["text_subtitle"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 72))

        # ── 카드 레이아웃 (새 규격) ──
        cell_w = 190
        cell_h = 220          # 감옥 셀 높이 (기본)
        gap = 15
        total_w = cell_w * 3 + gap * 2
        start_x = (SCREEN_WIDTH - total_w) // 2
        cell_y = 130

        from downtown.hero_skills import HERO_SKILLS

        for i, hero in enumerate(self.prison_heroes):
            cx = start_x + i * (cell_w + gap)
            is_hovered = (self.hover_prison_index == i) and not opening_phase
            is_opening = (opening_phase is not None and opening_idx == i)
            is_dimmed = (opening_phase is not None and opening_idx != i)

            # ── 감옥 셀 배경 (어두운 석벽) ──
            if is_dimmed:
                bg = (35, 28, 18)
                border = (80, 65, 42)
            elif is_hovered:
                bg = ET["card_bg_hover"]
                border = ET["gold_medium"]
            elif is_opening:
                bg = ET["card_bg_hover"]
                border = ET["gold_medium"]
            else:
                bg = ET["card_bg"]
                border = ET["card_border"]

            pygame.draw.rect(self.screen, bg, (cx, cell_y, cell_w, cell_h), border_radius=6)

            # 감옥 벽면 질감 (어두운 줄무늬)
            if not is_hovered and not is_opening:
                for wy in range(cell_y + 3, cell_y + cell_h - 3, 7):
                    wall_line = pygame.Surface((cell_w - 6, 1), pygame.SRCALPHA)
                    wall_line.fill((0, 0, 0, 18 if not is_dimmed else 30))
                    self.screen.blit(wall_line, (cx + 3, wy))

            pygame.draw.rect(self.screen, border, (cx, cell_y, cell_w, cell_h), 2, border_radius=6)

            # ── 영웅 캐릭터 (2배 크기: 160x110) ──
            hero_draw_offset_y = 0
            hero_scale_mult = 1.0

            # 공격 모션 중이면 특수 처리
            if is_opening and opening_phase == "attack_motion":
                motion_t = opening_timer - 1.5
                if motion_t < 0.2:
                    # 뒤로 힘 모으기
                    p = motion_t / 0.2
                    hero_draw_offset_y = int(-12 * p)
                    hero_scale_mult = 1.0 + 0.05 * p
                elif motion_t < 0.4:
                    # 앞으로 돌진!
                    p = (motion_t - 0.2) / 0.2
                    eased = p * p
                    hero_draw_offset_y = int(-12 + 42 * eased)
                    hero_scale_mult = 1.05 + 0.15 * eased
                else:
                    # 임팩트 유지 + 실제 무기 스윙 모션 (복귀 없음)
                    hero_draw_offset_y = 30
                    hero_scale_mult = 1.2
                    # 무기 스윙 트리거 (한 번만 - 실제 타격 모션 재생)
                    if not getattr(self, '_prison_swing_triggered', False):
                        self._prison_swing_triggered = True
                        _load_select_swing_sound()
                        if _select_swing_sound:
                            _select_swing_sound.play()
                        if self.hero_paddle_renderer:
                            self.hero_paddle_renderer.trigger_weapon_swing(
                                hero["id"], 0.5)

            if self.hero_paddle_renderer:
                h_w = int(160 * hero_scale_mult)
                h_h = int(110 * hero_scale_mult)
                hero_cx = cx + cell_w // 2
                hero_cy = cell_y + cell_h // 2 + 10 + hero_draw_offset_y

                if is_dimmed:
                    # 디밍된 카드: 어두운 버전
                    dim_surf = pygame.Surface((cell_w, cell_h), pygame.SRCALPHA)
                    self.hero_paddle_renderer.draw_hero_paddle(
                        dim_surf, hero["id"], cell_w // 2, cell_h // 2 + 10,
                        160, 110, facing="down", color=hero["color"], scale_mode="preview"
                    )
                    dim_surf.set_alpha(80)
                    self.screen.blit(dim_surf, (cx, cell_y))
                else:
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, hero["id"], hero_cx, hero_cy,
                        h_w, h_h, facing="down", color=hero["color"], scale_mode="preview"
                    )

            # ── 공격 모션 이펙트 ──
            if is_opening and opening_phase == "attack_motion":
                motion_t = opening_timer - 1.5
                hero_cx = cx + cell_w // 2
                hero_base_cy = cell_y + cell_h // 2 + 10

                # 임팩트 플래시 (무기 스윙 시작 시 번쩍)
                if 0.4 <= motion_t <= 0.7:
                    flash_p = (motion_t - 0.4) / 0.3
                    flash_alpha = int(180 * (1.0 - flash_p))
                    flash_s = pygame.Surface((cell_w + 60, 100), pygame.SRCALPHA)
                    pygame.draw.ellipse(flash_s, (255, 240, 180, flash_alpha),
                                        (0, 0, cell_w + 60, 100))
                    self.screen.blit(flash_s, (cx - 30, hero_base_cy + 10))

                # 파편 파티클 (철창 파편)
                particles = getattr(self, '_prison_attack_particles', [])
                for p in particles:
                    pa = max(0, min(255, int(p['alpha'])))
                    if pa > 0:
                        ps = int(max(1, p['size']))
                        pygame.draw.rect(self.screen, (*p['color'], pa),
                                         (int(p['x']), int(p['y']), ps, ps))

            # ── 쇠철창 오버레이 ──
            if is_dimmed:
                self._draw_prison_bars_overlay(cx, cell_y, cell_w, cell_h, False, 0.0)
            elif is_opening:
                if opening_phase == "bars_opening":
                    # 이징 함수 적용 (천천히 시작 → 빠르게 열림)
                    raw_ratio = min(1.0, opening_timer / 1.5)
                    eased = raw_ratio * raw_ratio * (3.0 - 2.0 * raw_ratio)  # smoothstep
                    self._draw_prison_bars_overlay(cx, cell_y, cell_w, cell_h, False, eased)
                # attack_motion 중에는 철창 안 그림 (이미 열림)
            else:
                self._draw_prison_bars_overlay(cx, cell_y, cell_w, cell_h, is_hovered, 0.0)

            # ── 호버 시: 이름 탭 + 스킬 탭 (감옥 셀 아래에 표시) ──
            if is_hovered:
                tab_w = 240       # 셀보다 넓은 탭
                tab_x = cx + (cell_w - tab_w) // 2  # 셀 중앙 기준 정렬
                tab_y = cell_y + cell_h + 10

                # ── 이름 탭 (대형) ──
                name_tab_h = 78
                name_bg_s = pygame.Surface((tab_w, name_tab_h), pygame.SRCALPHA)
                pygame.draw.rect(name_bg_s, (*ET["card_bg_hover"], 240),
                                 (0, 0, tab_w, name_tab_h), border_radius=8)
                self.screen.blit(name_bg_s, (tab_x, tab_y))
                pygame.draw.rect(self.screen, ET["gold_medium"],
                                 (tab_x, tab_y, tab_w, name_tab_h), 2, border_radius=8)

                # 색상 바 (이름 탭 상단)
                color_bar = pygame.Surface((tab_w - 20, 3), pygame.SRCALPHA)
                color_bar.fill((*hero["color"], 200))
                self.screen.blit(color_bar, (tab_x + 10, tab_y + 5))

                # 영웅 이름 (대형 텍스트 - size 38)
                if self.fonts and "large" in self.fonts:
                    h_color = hero["color"]
                    brightness = sum(h_color) / 3
                    name_color = h_color if brightness > 80 else tuple(
                        min(255, c + 100) for c in h_color)
                    surf, _ = self.fonts["large"].render(hero["name"], name_color, size=38)
                    self.screen.blit(surf, (tab_x + tab_w // 2 - surf.get_width() // 2, tab_y + 12))

                # 칭호 (중형 텍스트 - size 22)
                if self.fonts and "small" in self.fonts:
                    surf, _ = self.fonts["small"].render(
                        hero.get("title", ""), ET["text_subtitle"], size=22)
                    self.screen.blit(surf, (tab_x + tab_w // 2 - surf.get_width() // 2, tab_y + 48))

                # ── 스킬 탭 (확장형) ──
                skill_tab_y = tab_y + name_tab_h + 6
                hero_skills = HERO_SKILLS.get(hero["id"], [])
                skill_rows = len(hero_skills)
                skill_tab_h = skill_rows * 34 + 32  # 스킬 + 스타일 배지

                skill_bg_s = pygame.Surface((tab_w, skill_tab_h), pygame.SRCALPHA)
                pygame.draw.rect(skill_bg_s, (*ET["card_bg"], 230),
                                 (0, 0, tab_w, skill_tab_h), border_radius=8)
                self.screen.blit(skill_bg_s, (tab_x, skill_tab_y))
                pygame.draw.rect(self.screen, ET["card_border"],
                                 (tab_x, skill_tab_y, tab_w, skill_tab_h), 2, border_radius=8)

                sy = skill_tab_y + 7
                for si, skill in enumerate(hero_skills):
                    s_h = 28
                    pygame.draw.rect(self.screen, ET["skill_bg"],
                                     (tab_x + 8, sy, tab_w - 16, s_h), border_radius=5)
                    icon = _get_hero_skill_icon(skill.skill_id, 20)
                    if icon:
                        self.screen.blit(icon, (tab_x + 13, sy + 4))
                    else:
                        pygame.draw.rect(self.screen, ET["bg_medium"],
                                         (tab_x + 13, sy + 4, 20, 20), border_radius=3)
                    if self.fonts and "small" in self.fonts:
                        label = f"{'A' if si == 0 else 'B'}: {skill.korean_name}"
                        surf, _ = self.fonts["small"].render(label, ET["text_body"], size=18)
                        self.screen.blit(surf, (tab_x + 38, sy + 5))
                    sy += s_h + 6

                # 스타일 배지
                style_names = {
                    "aggressive": "공격형", "defensive": "수비형",
                    "balanced": "균형형", "tricky": "트릭형"
                }
                style_text = style_names.get(hero["style"].value, "???")
                if self.fonts and "small" in self.fonts:
                    surf, _ = self.fonts["small"].render(f"[{style_text}]", ET["text_hint"])
                    self.screen.blit(surf, (tab_x + tab_w // 2 - surf.get_width() // 2, sy + 2))

        # ── 철창 열림 시 파편 파티클 생성 ──
        if opening_phase == "bars_opening" and opening_timer > 0.3:
            import random as _rand
            particles = getattr(self, '_prison_attack_particles', [])
            if not hasattr(self, '_prison_attack_particles'):
                self._prison_attack_particles = particles
            # 프레임당 1~2개 파편 생성 (열리는 동안)
            if _rand.random() < 0.6:
                ocx = start_x + opening_idx * (cell_w + gap)
                particles.append({
                    'x': float(ocx + _rand.randint(5, cell_w - 5)),
                    'y': float(cell_y + cell_h * (1.0 - min(1.0, opening_timer / 1.5))),
                    'vx': _rand.uniform(-20, 20),
                    'vy': _rand.uniform(30, 80),
                    'alpha': 200.0,
                    'size': _rand.uniform(2, 5),
                    'color': (120 + _rand.randint(0, 40), 115 + _rand.randint(0, 35), 100 + _rand.randint(0, 30))
                })

        # 하단 스킬 룰렛 (호위무사 선택 후 같은 화면에서 스킬 결정)
        if opening_phase in ("skill_rolling", "skill_selected"):
            self._draw_inline_skill_roulette(base_y=370)

    def _draw_bracket_lines(self):
        """대진표 연결선 (대각선 레이아웃 box_h=140 기준) - 이집트 테마"""
        line_color = ET["bracket_line"]

        # 8강 박스 중심 x좌표 (box_w=120 기준)
        q1_x, q2_x, q3_x, q4_x = 120, 255, 490, 625
        # 4강 박스 중심 x좌표
        s1_x, s2_x = 187, 557
        # 결승 박스 중심 x좌표
        f_x = 372

        # 8강 top y = 530, 4강 bottom y = 450 (310+140)
        y_q_top = 530
        y_mid1 = 490  # 8강→4강 연결 중간선
        y_s_bottom = 450  # 4강 박스 하단

        # 8강 → 4강 연결 (좌측)
        pygame.draw.line(self.screen, line_color, (q1_x, y_q_top), (q1_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q2_x, y_q_top), (q2_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q1_x, y_mid1), (q2_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (s1_x, y_mid1), (s1_x, y_s_bottom), 2)

        # 8강 → 4강 연결 (우측)
        pygame.draw.line(self.screen, line_color, (q3_x, y_q_top), (q3_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q4_x, y_q_top), (q4_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q3_x, y_mid1), (q4_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (s2_x, y_mid1), (s2_x, y_s_bottom), 2)

        # 4강 top y = 310, 결승 bottom y = 220 (80+140)
        y_s_top = 310
        y_mid2 = 265  # 4강→결승 연결 중간선
        y_f_bottom = 220  # 결승 박스 하단

        # 4강 → 결승 연결
        pygame.draw.line(self.screen, line_color, (s1_x, y_s_top), (s1_x, y_mid2), 2)
        pygame.draw.line(self.screen, line_color, (s2_x, y_s_top), (s2_x, y_mid2), 2)
        pygame.draw.line(self.screen, line_color, (s1_x, y_mid2), (s2_x, y_mid2), 2)
        pygame.draw.line(self.screen, line_color, (f_x, y_mid2), (f_x, y_f_bottom), 2)

    def _draw_match_selection_hint(self):
        """경기 선택 힌트 - 이집트 테마"""
        if self.fonts and "small" in self.fonts:
            hint = "관전할 경기를 클릭하세요"
            surf, _ = self.fonts["small"].render(hint, ET["text_subtitle"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 700))

    def _draw_betting_ui(self):
        """단순화된 배팅 UI - 영웅만 선택"""
        if not self.selected_match:
            return

        # 반투명 오버레이
        overlay = _get_arena_fullscreen()
        overlay.fill((*ET["overlay_dark"], 180))
        self.screen.blit(overlay, (0, 0))

        # 배팅 패널
        panel_x, panel_y = 180, 180
        panel_w, panel_h = 400, 355
        self._draw_egyptian_panel(panel_x, panel_y, panel_w, panel_h)

        # 라운드 타이틀
        round_names = {
            TournamentRound.QUARTER_FINAL: "8강전",
            TournamentRound.SEMI_FINAL: "4강전",
            TournamentRound.FINAL: "결승전",
        }
        if self.fonts and "large" in self.fonts:
            title = round_names.get(self.current_round, "배틀")
            surf, _ = self.fonts["large"].render(title, ET["gold_bright"])
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            title_y = panel_y + 15
            self.screen.blit(surf, (title_x, title_y))
            icon_y = title_y + surf.get_height() // 2
            if self.current_round == TournamentRound.FINAL:
                self._draw_crown_icon(title_x - 14, icon_y, 14)
                self._draw_crown_icon(title_x + surf.get_width() + 14, icon_y, 14)
            else:
                self._draw_sword_icon(title_x - 14, icon_y, 12)
                self._draw_sword_icon(title_x + surf.get_width() + 14, icon_y, 12)

        # 승리 보상 표시
        current_prize = self.round_prizes.get(self.current_round, 0)
        if self.fonts and "medium" in self.fonts:
            prize_text = f"승리 시 {current_prize}G 획득!"
            surf, _ = self.fonts["medium"].render(prize_text, ET["malachite_light"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 55))

        # 패배 시 경고
        if self.fonts and "small" in self.fonts:
            warn_text = f"패배 시 입장료 {self.entry_fee}G를 잃습니다"
            surf, _ = self.fonts["small"].render(warn_text, ET["gold_pale"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 85))

        # 안내 문구
        if self.fonts and "small" in self.fonts:
            hint = "승리할 영웅을 선택하세요!"
            surf, _ = self.fonts["small"].render(hint, ET["text_body"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 115))

        # 영웅 1 선택 버튼 (캐릭터 이미지 포함)
        hero1 = self.selected_match.hero1
        btn1_rect = pygame.Rect(panel_x + 20, panel_y + 145, 145, 100)
        h1_hovered = (self.hover_btn_id == "hero1")
        if h1_hovered:
            self._draw_hover_border(btn1_rect.x, btn1_rect.y, btn1_rect.w, btn1_rect.h, hero1["color"])
            bright_color = tuple(min(255, c + 30) for c in hero1["color"])
            pygame.draw.rect(self.screen, bright_color, btn1_rect, border_radius=8)
        else:
            pygame.draw.rect(self.screen, hero1["color"], btn1_rect, border_radius=8)
        btn1_border = (255, 255, 200) if h1_hovered else (255, 255, 255)
        pygame.draw.rect(self.screen, btn1_border, btn1_rect, 3, border_radius=8)
        if self.fonts:
            # 영웅 이름
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero1["name"], (255, 255, 255))
                self.screen.blit(surf, (btn1_rect.centerx - surf.get_width() // 2, btn1_rect.y + 10))
            # 영웅 칭호 - 골든 색상으로 차별화
            if "small" in self.fonts:
                title_text = f"「{hero1['title']}」"
                surf, _ = self.fonts["small"].render(title_text, (255, 220, 150))
                self.screen.blit(surf, (btn1_rect.centerx - surf.get_width() // 2, btn1_rect.y + 35))
        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            hero1_id = hero1.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1_id, btn1_rect.centerx, btn1_rect.y + 72, 50, 35,
                facing="down", color=hero1["color"], scale_mode="preview"
            )

        # VS
        if self.fonts and "large" in self.fonts:
            surf, _ = self._render_text("large", "VS", ET["carnelian_light"])
            if surf:
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 175))

        # 영웅 2 선택 버튼 (캐릭터 이미지 포함)
        hero2 = self.selected_match.hero2
        btn2_rect = pygame.Rect(panel_x + 235, panel_y + 145, 145, 100)
        h2_hovered = (self.hover_btn_id == "hero2")
        if h2_hovered:
            self._draw_hover_border(btn2_rect.x, btn2_rect.y, btn2_rect.w, btn2_rect.h, hero2["color"])
            bright_color = tuple(min(255, c + 30) for c in hero2["color"])
            pygame.draw.rect(self.screen, bright_color, btn2_rect, border_radius=8)
        else:
            pygame.draw.rect(self.screen, hero2["color"], btn2_rect, border_radius=8)
        btn2_border = (255, 255, 200) if h2_hovered else (255, 255, 255)
        pygame.draw.rect(self.screen, btn2_border, btn2_rect, 3, border_radius=8)
        if self.fonts:
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero2["name"], (255, 255, 255))
                self.screen.blit(surf, (btn2_rect.centerx - surf.get_width() // 2, btn2_rect.y + 10))
            # 영웅 칭호 - 골든 색상으로 차별화
            if "small" in self.fonts:
                title_text = f"「{hero2['title']}」"
                surf, _ = self.fonts["small"].render(title_text, (255, 220, 150))
                self.screen.blit(surf, (btn2_rect.centerx - surf.get_width() // 2, btn2_rect.y + 35))
        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            hero2_id = hero2.get("id", "chronos")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2_id, btn2_rect.centerx, btn2_rect.y + 72, 50, 35,
                facing="down", color=hero2["color"], scale_mode="preview"
            )

        # 경고 문구
        if self.fonts and "small" in self.fonts:
            warn_text = "패배시 누적 상금 전액 몰수!"
            surf, _ = self.fonts["small"].render(warn_text, ET["carnelian_light"])
            warn_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self._draw_warning_icon(warn_x - 12, panel_y + 265 + surf.get_height() // 2, 10)
            self.screen.blit(surf, (warn_x, panel_y + 265))

        # 포기하고 나가기 버튼
        exit_rect = pygame.Rect(panel_x + 100, panel_y + 300, 200, 40)
        exit_hovered = (self.hover_btn_id == "exit")
        exit_bg = ET["btn_danger_hover"] if exit_hovered else ET["btn_danger"]
        pygame.draw.rect(self.screen, exit_bg, exit_rect, border_radius=5)
        if exit_hovered:
            pygame.draw.rect(self.screen, ET["carnelian_light"], exit_rect, 2, border_radius=5)
        if self.fonts and "small" in self.fonts:
            exit_text_color = ET["text_white"] if exit_hovered else ET["text_body"]
            surf, _ = self._render_text("small", "포기하고 나가기", exit_text_color)
            self.screen.blit(surf, (exit_rect.centerx - surf.get_width() // 2, exit_rect.y + 12))

    def _draw_result_ui(self):
        """결과 UI - 심플 & 임팩트 버전"""
        if not self.selected_match or not self.selected_match.winner:
            return

        # 반투명 오버레이
        overlay = _get_arena_fullscreen()
        overlay.fill((*ET["overlay_dark"], 180))
        self.screen.blit(overlay, (0, 0))

        winner = self.selected_match.winner
        is_win = self.bet_hero == winner
        cx = SCREEN_WIDTH // 2

        if is_win:
            # ── 승리 화면 ──
            # 다음 라운드 이름 결정
            if self.current_round == TournamentRound.QUARTER_FINAL:
                advance_text = "4강 진출!"
            elif self.current_round == TournamentRound.SEMI_FINAL:
                advance_text = "결승 진출!"
            else:
                advance_text = "우승!"

            # 패널
            panel_w, panel_h = 380, 340
            panel_x = cx - panel_w // 2
            panel_y = 190
            self._draw_egyptian_panel(panel_x, panel_y, panel_w, panel_h)

            # "-- 승리 --" 타이틀
            if self.fonts and "large" in self.fonts:
                surf, _ = self.fonts["large"].render("-- 승리 --", ET["gold_bright"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 18))

            # "~강 진출!" 텍스트 + 트로피 아이콘
            if self.fonts and "large" in self.fonts:
                surf, _ = self.fonts["large"].render(advance_text, ET["gold_bright"])
                adv_x = cx - surf.get_width() // 2
                adv_y = panel_y + 55
                self.screen.blit(surf, (adv_x, adv_y))
                icon_cy = adv_y + surf.get_height() // 2
                self._draw_trophy_icon(adv_x - 16, icon_cy, 14)
                self._draw_trophy_icon(adv_x + surf.get_width() + 16, icon_cy, 14)

            # 영웅 이미지 + 호위무사 이미지
            hero_id = self.bet_hero.get("id", "mugen") if self.bet_hero else "mugen"
            hero_color = self.bet_hero.get("color", (200, 200, 200)) if self.bet_hero else (200, 200, 200)
            guards = self.guard_warrior_map.get(hero_id, []) if self.bet_hero else []

            hero_area_y = panel_y + 100
            hero_w, hero_h = 90, 64

            if guards:
                # 영웅 + 호위무사 함께 표시
                guard = guards[0]
                guard_id = guard.get("id", "chronos")
                guard_color = guard.get("color", (180, 180, 180))
                guard_w, guard_h = 54, 38
                total_w = hero_w + 12 + guard_w
                start_x = cx - total_w // 2

                # 메인 영웅 (크게)
                if self.hero_paddle_renderer:
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, hero_id,
                        start_x + hero_w // 2, hero_area_y + hero_h // 2,
                        hero_w, hero_h,
                        facing="down", color=hero_color, scale_mode="preview"
                    )
                # 호위무사 (작게, 오른쪽 아래)
                if self.hero_paddle_renderer:
                    guard_x = start_x + hero_w + 12 + guard_w // 2
                    guard_y = hero_area_y + hero_h - guard_h // 2
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, guard_id,
                        guard_x, guard_y,
                        guard_w, guard_h,
                        facing="down", color=guard_color, scale_mode="preview"
                    )
            else:
                # 영웅만 표시 (가운데)
                if self.hero_paddle_renderer:
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, hero_id,
                        cx, hero_area_y + hero_h // 2,
                        hero_w, hero_h,
                        facing="down", color=hero_color, scale_mode="preview"
                    )

            # 영웅 이름
            if self.fonts and "medium" in self.fonts and self.bet_hero:
                hero_name = self.bet_hero.get("name", "???")
                brightness = sum(hero_color) / 3
                name_color = hero_color if brightness > 80 else (
                    min(255, hero_color[0] + 100),
                    min(255, hero_color[1] + 100),
                    min(255, hero_color[2] + 100)
                )
                surf, _ = self.fonts["medium"].render(hero_name, name_color)
                self.screen.blit(surf, (cx - surf.get_width() // 2, hero_area_y + hero_h + 8))

            # 골드 획득 표시
            if self.fonts and "medium" in self.fonts:
                round_prize = self.round_prizes.get(self.current_round, 0)
                gold_text = f"+{round_prize}G"
                surf, _ = self.fonts["medium"].render(gold_text, ET["malachite_light"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 240))

            # 누적 상금
            if self.fonts and "small" in self.fonts and self.accumulated_prize > 0:
                acc_text = f"누적 상금: {self.accumulated_prize}G"
                surf, _ = self.fonts["small"].render(acc_text, ET["gold_pale"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 270))

            # 안내
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render("클릭하여 계속", ET["text_hint"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 305))

        else:
            # ── 패배 화면 ──
            panel_w, panel_h = 380, 250
            panel_x = cx - panel_w // 2
            panel_y = 230
            self._draw_egyptian_panel(panel_x, panel_y, panel_w, panel_h, border_color=ET["carnelian"])

            # "패배..." 타이틀 + 해골 아이콘
            if self.fonts and "large" in self.fonts:
                surf, _ = self.fonts["large"].render("패배...", ET["carnelian_light"])
                title_x = cx - surf.get_width() // 2
                title_y = panel_y + 25
                self.screen.blit(surf, (title_x, title_y))
                icon_y = title_y + surf.get_height() // 2
                self._draw_skull_icon(title_x - 16, icon_y, 14)
                self._draw_skull_icon(title_x + surf.get_width() + 16, icon_y, 14)

            # 스코어
            if self.fonts and "medium" in self.fonts:
                score_text = f"{self.selected_match.score1} : {self.selected_match.score2}"
                surf, _ = self.fonts["medium"].render(score_text, ET["text_body"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 75))

            # 손실 표시
            if self.fonts and "medium" in self.fonts:
                profit_text = f"입장료 {self.entry_fee}G를 잃었습니다!"
                surf, _ = self.fonts["medium"].render(profit_text, ET["carnelian_light"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 115))

            # 추가 메시지
            if self.fonts and "small" in self.fonts:
                lose_msg = f"누적 상금 {self.accumulated_prize}G 몰수..."
                surf, _ = self.fonts["small"].render(lose_msg, ET["text_disabled"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 155))

            # 안내
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render("클릭하여 계속", ET["text_hint"])
                self.screen.blit(surf, (cx - surf.get_width() // 2, panel_y + 210))

    def _draw_difficulty_select(self):
        """난이도 선택 UI"""
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        # 타이틀
        if self.fonts and "large" in self.fonts:
            pulse = abs(_sin(self.animation_timer * 3)) * 0.3 + 0.7
            gold_color = (int(ET["gold_bright"][0] * pulse), int(ET["gold_bright"][1] * pulse), int(ET["gold_bright"][2] * pulse))
            surf, _ = self.fonts["large"].render("난이도 선택", gold_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 80))
            # 검 아이콘
            icon_y = 80 + surf.get_height() // 2
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self._draw_sword_icon(title_x - 16, icon_y, 14, gold_color)
            self._draw_sword_icon(title_x + surf.get_width() + 16, icon_y, 14, gold_color)

        # 부제목
        if self.fonts and "medium" in self.fonts:
            sub = "도전할 난이도를 선택하세요"
            surf, _ = self.fonts["medium"].render(sub, ET["text_body"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 125))

        # 보유 골드 표시
        if self.fonts and "small" in self.fonts:
            gold_text = f"보유 골드: {self.player_gold}G"
            surf, _ = self.fonts["small"].render(gold_text, ET["gold_pale"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 155))

        # 3개 난이도 카드
        num = len(ARENA_DIFFICULTIES)
        card_w, card_h = 200, 320
        total_w = num * card_w + (num - 1) * 20
        start_x = (SCREEN_WIDTH - total_w) // 2
        card_y = 195

        for i, diff in enumerate(ARENA_DIFFICULTIES):
            cx = start_x + i * (card_w + 20)
            is_hovered = (self.hover_difficulty_index == i)
            can_afford = self.player_gold >= diff["entry_fee"]

            # 카드 배경
            bg_color = diff["color"] if can_afford else (80, 80, 80)
            border_color = diff["border_color"] if can_afford else (60, 60, 60)
            if is_hovered and can_afford:
                # 호버 글로우
                glow_surf = _get_arena_surface(card_w + 16, card_h + 16)
                glow_surf.fill((0, 0, 0, 0))
                pygame.draw.rect(glow_surf, (*diff["color"], 60), (0, 0, card_w + 16, card_h + 16), border_radius=12)
                self.screen.blit(glow_surf, (cx - 8, card_y - 8))

            # 카드 본체
            card_surf = _get_arena_surface(card_w, card_h)
            card_surf.fill((0, 0, 0, 0))
            # 배경 (반투명)
            inner_alpha = 200 if is_hovered else 160
            pygame.draw.rect(card_surf, (*ET["bg_panel"], inner_alpha), (0, 0, card_w, card_h), border_radius=8)
            # 상단 색상 바
            bar_h = 60
            bar_color = (*bg_color, 220 if can_afford else 100)
            pygame.draw.rect(card_surf, bar_color, (0, 0, card_w, bar_h), border_radius=8)
            pygame.draw.rect(card_surf, (0, 0, 0, 0), (0, bar_h - 8, card_w, 8))  # 하단 둥글기 제거
            # 테두리
            border_alpha = 255 if is_hovered else 150
            pygame.draw.rect(card_surf, (*border_color, border_alpha), (0, 0, card_w, card_h), 2, border_radius=8)
            self.screen.blit(card_surf, (cx, card_y))

            # 난이도 이름 (큰 글씨)
            if self.fonts and "large" in self.fonts:
                name_color = (255, 255, 255) if can_afford else (120, 120, 120)
                surf, _ = self.fonts["large"].render(diff["name"], name_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 12))

            # 설명
            if self.fonts and "small" in self.fonts:
                desc_lines = diff["description"].split("\n")
                desc_color = ET["text_body"] if can_afford else (100, 100, 100)
                for j, line in enumerate(desc_lines):
                    surf, _ = self.fonts["small"].render(line, desc_color)
                    self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 75 + j * 20))

            # 구분선
            line_y = card_y + 130
            pygame.draw.line(self.screen, (*ET["bracket_line"], 100), (cx + 15, line_y), (cx + card_w - 15, line_y))

            # 입장료
            if self.fonts and "medium" in self.fonts:
                fee_color = ET["gold_bright"] if can_afford else (120, 80, 80)
                fee_text = f"입장료: {diff['entry_fee']}G"
                surf, _ = self.fonts["medium"].render(fee_text, fee_color)
                self._draw_coin_icon(cx + card_w // 2 - surf.get_width() // 2 - 14, card_y + 148, 10)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 142))

            # 보상 배율
            if self.fonts and "small" in self.fonts:
                mult_color = ET["malachite_light"] if can_afford else (80, 80, 80)
                mult_text = f"보상 {diff['prize_multiplier']:.1f}배"
                surf, _ = self.fonts["small"].render(mult_text, mult_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 175))

            # 승점
            if self.fonts and "small" in self.fonts:
                ws_color = ET["lapis_light"] if can_afford else (80, 80, 80)
                ws_text = f"{diff['win_score']}점 선취"
                surf, _ = self.fonts["small"].render(ws_text, ws_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 197))

            # AI 강화 정보
            if diff["ai_bonus_perks"] > 0 and self.fonts and "small" in self.fonts:
                ai_color = ET["carnelian_light"] if can_afford else (80, 80, 80)
                ai_text = f"AI 퍽 +{diff['ai_bonus_perks']}"
                surf, _ = self.fonts["small"].render(ai_text, ai_color)
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + 219))

            # 상금 미리보기
            if self.fonts and "small" in self.fonts:
                preview_y = card_y + 250
                prizes_text = "상금:"
                surf, _ = self.fonts["small"].render(prizes_text, ET["text_hint"])
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, preview_y))
                prize_details = (
                    f"8강 {int(1000 * diff['prize_multiplier'])}G  "
                    f"4강 {int(2000 * diff['prize_multiplier'])}G  "
                    f"결승 {int(3000 * diff['prize_multiplier'])}G"
                )
                detail_color = ET["text_hint"] if can_afford else (70, 70, 70)
                # 상금은 좁으니 2줄로
                p1 = f"8강 {int(1000 * diff['prize_multiplier'])}G | 4강 {int(2000 * diff['prize_multiplier'])}G"
                p2 = f"결승 {int(3000 * diff['prize_multiplier'])}G"
                s1, _ = self.fonts["small"].render(p1, detail_color)
                self.screen.blit(s1, (cx + card_w // 2 - s1.get_width() // 2, preview_y + 18))
                s2, _ = self.fonts["small"].render(p2, detail_color)
                self.screen.blit(s2, (cx + card_w // 2 - s2.get_width() // 2, preview_y + 36))

            # 골드 부족 표시
            if not can_afford and self.fonts and "small" in self.fonts:
                lack_text = "골드 부족"
                surf, _ = self.fonts["small"].render(lack_text, (200, 60, 60))
                self.screen.blit(surf, (cx + card_w // 2 - surf.get_width() // 2, card_y + card_h - 25))

        # 하단 ESC 힌트
        if self.fonts and "small" in self.fonts:
            hint = "ESC: 투기장 나가기"
            alpha = int(abs(_sin(self.animation_timer * 2)) * 100 + 100)
            surf, _ = self.fonts["small"].render(hint, (alpha, int(alpha * 0.9), int(alpha * 0.7)))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 700))

    def _draw_round_end_ui(self):
        """라운드 종료 UI - 누적 상금 시스템"""
        # 반투명 오버레이
        overlay = _get_arena_fullscreen()
        overlay.fill((*ET["overlay_dark"], 180))
        self.screen.blit(overlay, (0, 0))

        # 패널
        panel_x, panel_y = 150, 180
        panel_w, panel_h = 460, 340
        self._draw_egyptian_panel(panel_x, panel_y, panel_w, panel_h)

        # 타이틀
        if self.fonts and "large" in self.fonts:
            round_name = "4강" if self.current_round == TournamentRound.SEMI_FINAL else "결승"
            title = f"{round_name} 진출!"
            surf, _ = self.fonts["large"].render(title, ET["gold_bright"])
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self.screen.blit(surf, (title_x, panel_y + 25))
            icon_y = panel_y + 25 + surf.get_height() // 2
            self._draw_trophy_icon(title_x - 16, icon_y, 14)
            self._draw_trophy_icon(title_x + surf.get_width() + 16, icon_y, 14)

        # 누적 상금 (크게)
        if self.fonts and "large" in self.fonts:
            acc_text = f"누적 상금: {self.accumulated_prize}G"
            surf, _ = self.fonts["large"].render(acc_text, ET["malachite_light"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 75))

        # 다음 라운드 보상 정보 (현재 라운드의 다음 라운드 상금)
        if self.fonts and "medium" in self.fonts:
            if self.current_round == TournamentRound.QUARTER_FINAL:
                next_round = TournamentRound.SEMI_FINAL
            else:
                next_round = TournamentRound.FINAL
            next_prize = self.round_prizes.get(next_round, 0)
            next_text = f"다음 라운드 보상: +{next_prize}G"
            surf, _ = self.fonts["medium"].render(next_text, ET["lapis_light"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 120))

        # 선택한 영웅 정보
        if self.bet_hero and self.fonts and "medium" in self.fonts:
            hero_name = self.bet_hero.get("name", "???")
            hero_color = self.bet_hero.get("color", (255, 255, 255))
            # 밝기 보정
            brightness = sum(hero_color) / 3
            display_color = hero_color if brightness > 80 else (min(255, hero_color[0] + 100), min(255, hero_color[1] + 100), min(255, hero_color[2] + 100))
            hero_text = f"[{hero_name}] 으로 계속 도전!"
            surf, _ = self.fonts["medium"].render(hero_text, display_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 155))

        # 경고
        if self.fonts and "small" in self.fonts:
            warn_text = "패배 시 누적 상금을 모두 잃습니다!"
            surf, _ = self.fonts["small"].render(warn_text, ET["gold_pale"])
            warn_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self._draw_warning_icon(warn_x - 12, panel_y + 185 + surf.get_height() // 2, 10)
            self.screen.blit(surf, (warn_x, panel_y + 185))

        # 계속 버튼 (도전)
        rc_hovered = (self.hover_btn_id == "round_continue")
        continue_rect = pygame.Rect(panel_x + 40, panel_y + 220, 180, 50)
        if rc_hovered:
            self._draw_hover_border(continue_rect.x, continue_rect.y, continue_rect.w, continue_rect.h, (100, 255, 100))
        rc_bg = ET["btn_continue_hover"] if rc_hovered else ET["btn_continue"]
        pygame.draw.rect(self.screen, rc_bg, continue_rect, border_radius=5)
        if rc_hovered:
            pygame.draw.rect(self.screen, ET["malachite_light"], continue_rect, 2, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self._render_text("medium", "계속 도전!", ET["text_white"])
            btn_text_x = continue_rect.centerx - surf.get_width() // 2
            self._draw_fire_icon(btn_text_x - 12, continue_rect.y + 15 + surf.get_height() // 2, 12)
            self.screen.blit(surf, (btn_text_x, continue_rect.y + 15))

        # 나가기 버튼 (상금 수령)
        re_hovered = (self.hover_btn_id == "round_exit")
        exit_rect = pygame.Rect(panel_x + 240, panel_y + 220, 180, 50)
        if re_hovered:
            self._draw_hover_border(exit_rect.x, exit_rect.y, exit_rect.w, exit_rect.h, (150, 150, 255))
        re_bg = ET["btn_exit_hover"] if re_hovered else ET["btn_exit"]
        pygame.draw.rect(self.screen, re_bg, exit_rect, border_radius=5)
        if re_hovered:
            pygame.draw.rect(self.screen, ET["lapis_light"], exit_rect, 2, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render(f"{self.accumulated_prize}G 수령", ET["text_white"])
            btn_text_x = exit_rect.centerx - surf.get_width() // 2
            self._draw_coin_icon(btn_text_x - 12, exit_rect.y + 15 + surf.get_height() // 2, 12)
            self.screen.blit(surf, (btn_text_x, exit_rect.y + 15))

        # 남은 보상 미리보기
        if self.fonts and "small" in self.fonts:
            remaining = []
            if self.current_round == TournamentRound.SEMI_FINAL:
                remaining = [f"4강: +{self.round_prizes[TournamentRound.SEMI_FINAL]}G",
                           f"결승: +{self.round_prizes[TournamentRound.FINAL]}G"]
            else:
                remaining = [f"결승: +{self.round_prizes[TournamentRound.FINAL]}G"]
            preview_text = "남은 보상: " + " → ".join(remaining)
            surf, _ = self.fonts["small"].render(preview_text, ET["lapis_light"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 285))

    def _draw_victory_celebration(self):
        """우승 축하 연출 화면 - 시상식 구도"""
        timer = getattr(self, 'victory_timer', 0.0)
        champion = self.bet_hero
        if not champion:
            self.state = TournamentState.TOURNAMENT_END
            return

        champion_id = champion.get("id", "mugen")
        champion_color = champion.get("color", (200, 200, 200))
        champion_name = champion.get("name", "???")
        champion_title = champion.get("title", "")
        guards = self.guard_warrior_map.get(champion_id, [])

        center_x = SCREEN_WIDTH // 2
        # 전체 연출 진행도
        intro = min(1.0, timer / 2.0)  # 0~2초: 등장
        eased = self._ease_in_out(intro)

        # === 배경 ===
        self.screen.fill((25, 18, 10))

        # 피라미드 실루엣
        pyr_surf = _get_arena_fullscreen()
        for px, pw, ph in [(150, 200, 120), (500, 160, 100), (80, 100, 65)]:
            pts = [(px, 540), (px + pw // 2, 540 - ph), (px + pw, 540)]
            pygame.draw.polygon(pyr_surf, (*ET["gold_dark"], 15), pts)
            pygame.draw.polygon(pyr_surf, (*ET["gold_dark"], 25), pts, 1)
        self.screen.blit(pyr_surf, (0, 0))

        # 방사형 빛줄기 (금색)
        if intro > 0.3:
            ray_alpha = int(30 * min(1.0, (intro - 0.3) * 2))
            ray_surf = _get_arena_fullscreen()
            num_rays = 12
            for i in range(num_rays):
                angle = (i / num_rays) * math.pi * 2 + self.animation_timer * 0.3
                end_x = center_x + int(_cos(angle) * 500)
                end_y = 350 + int(_sin(angle) * 500)
                pygame.draw.line(ray_surf, (255, 215, 0, ray_alpha), (center_x, 350), (end_x, end_y), 3)
            self.screen.blit(ray_surf, (0, 0))

        # 바닥 무대 (금색 그라데이션 라인)
        stage_y = 540
        if intro > 0.2:
            stage_alpha = int(180 * min(1.0, (intro - 0.2) * 3))
            stage_surf = _get_arena_surface(SCREEN_WIDTH, 4)
            for sx in range(SCREEN_WIDTH):
                dist = abs(sx - center_x) / (SCREEN_WIDTH / 2)
                a = int(stage_alpha * max(0, 1.0 - dist * 1.2))
                stage_surf.set_at((sx, 0), (255, 215, 0, a))
                stage_surf.set_at((sx, 1), (255, 215, 0, a // 2))
                stage_surf.set_at((sx, 2), (200, 170, 0, a // 3))
                stage_surf.set_at((sx, 3), (150, 130, 0, a // 4))
            self.screen.blit(stage_surf, (0, stage_y))

        # === 호위무사 (양옆, 챔피언보다 먼저 등장) ===
        guard_y_target = 420
        guard_size_w, guard_size_h = 80, 56
        former = getattr(self, 'former_guards', [])
        # 현재 호위무사(왼쪽) + 전 호위무사들(오른쪽, 반투명)
        all_display_guards = []  # (guard_dict, is_former)
        for g in guards:
            all_display_guards.append((g, False))
        for g in former:
            # 현재 호위무사와 중복 제거
            if g not in guards:
                all_display_guards.append((g, True))

        if all_display_guards and self.hero_paddle_renderer and intro > 0.1:
            guard_fade = min(1.0, (intro - 0.1) * 2.5)
            guard_eased = self._ease_in_out(guard_fade)

            # 배치: 현재 호위무사 왼쪽, 전 호위무사들 오른쪽
            current_guards = [(g, f) for g, f in all_display_guards if not f]
            former_guards_list = [(g, f) for g, f in all_display_guards if f]

            # 왼쪽: 현재 호위무사
            # 글로우 Y 보정: preview 모드 캐릭터는 torso가 cy-1.5b에 위치,
            # 시각적 중심이 cy보다 위쪽이므로 글로우를 위로 보정
            guard_b = max(3, guard_size_w // 12)
            glow_y_adj = int(guard_b * 0.75)
            if current_guards:
                g, _ = current_guards[0]
                g_target_x = center_x - 180
                g_start_x = -100
                gx = int(g_start_x + (g_target_x - g_start_x) * guard_eased)
                gy = int(guard_y_target + 100 * (1 - guard_eased))
                g_color = g.get("color", (150, 150, 150))

                glow_a = int(40 * guard_fade)
                glow_s = _get_arena_surface(120, 120)
                pygame.draw.circle(glow_s, (*g_color, glow_a), (60, 60), 55)
                self.screen.blit(glow_s, (gx - 60, gy - 60 - glow_y_adj))

                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen, g.get("id", "mugen"), gx, gy, guard_size_w, guard_size_h,
                    facing="down", color=g_color, scale_mode="preview"
                )
                if self.fonts and "small" in self.fonts and guard_fade > 0.5:
                    ns, _ = self.fonts["small"].render(g.get("name", ""), ET["text_body"])
                    self.screen.blit(ns, (gx - ns.get_width() // 2, gy + guard_size_h // 2 + 8))

            # 오른쪽: 전 호위무사들 (반투명, 현재 호위무사와 동일한 높이)
            if former_guards_list:
                hero_w = int(guard_size_w * 0.85)
                hero_h = int(guard_size_h * 0.85)
                # 영웅+이름을 담을 서피스 (충분한 여유 공간)
                surf_w = guard_size_w + 80
                surf_h = guard_size_h + 100
                surf_cx = surf_w // 2
                surf_cy = surf_h // 2

                for fi, (g, _) in enumerate(former_guards_list):
                    # 오른쪽에 간격두고 배치 (gy는 현재 호위무사와 동일)
                    g_target_x = center_x + 150 + fi * 80
                    g_start_x = SCREEN_WIDTH + 100
                    gx = int(g_start_x + (g_target_x - g_start_x) * guard_eased)
                    gy = int(guard_y_target + 100 * (1 - guard_eased))
                    g_color = g.get("color", (150, 150, 150))

                    # 글로우 (약하게) - 현재 호위무사와 동일한 방식 + Y 보정
                    glow_a_f = int(20 * guard_fade)
                    glow_s = _get_arena_surface(120, 120)
                    pygame.draw.circle(glow_s, (*g_color, glow_a_f), (60, 60), 45)
                    self.screen.blit(glow_s, (gx - 60, gy - 60 - glow_y_adj))

                    # 반투명 서피스에 영웅 렌더링 (중앙 기준)
                    ghost_surf = _get_arena_surface(surf_w, surf_h)

                    self.hero_paddle_renderer.draw_hero_paddle(
                        ghost_surf, g.get("id", "mugen"), surf_cx, surf_cy,
                        hero_w, hero_h,
                        facing="down", color=g_color, scale_mode="preview"
                    )

                    # 이름 (현재 호위무사와 동일한 오프셋 사용)
                    if self.fonts and "small" in self.fonts and guard_fade > 0.5:
                        ns, _ = self.fonts["small"].render(g.get("name", ""), ET["text_hint"])
                        ghost_surf.blit(ns, (surf_cx - ns.get_width() // 2,
                                             surf_cy + guard_size_h // 2 + 8))

                    # 반투명 적용 (100/255 ≈ 40% 불투명)
                    ghost_surf.fill((255, 255, 255, 100), special_flags=pygame.BLEND_RGBA_MULT)
                    self.screen.blit(ghost_surf, (gx - surf_cx, gy - surf_cy))

        # === 챔피언 (중앙, 크게) ===
        champ_target_y = 380
        champ_start_y = 600
        champ_y = int(champ_start_y + (champ_target_y - champ_start_y) * eased)
        champ_w, champ_h = 150, 105

        # 챔피언 글로우 (크고 화려하게) - Y 보정으로 캐릭터 시각적 중심에 맞춤
        champ_b = max(3, champ_w // 12)
        champ_glow_adj = int(champ_b * 0.75)
        if intro > 0.2:
            glow_pulse = abs(_sin(self.animation_timer * 2)) * 0.3 + 0.7
            glow_a = int(80 * min(1.0, (intro - 0.2) * 2) * glow_pulse)
            glow_r = 110
            glow_s = _get_arena_surface(glow_r * 2, glow_r * 2)
            pygame.draw.circle(glow_s, (255, 215, 0, glow_a), (glow_r, glow_r), glow_r)
            self.screen.blit(glow_s, (center_x - glow_r, champ_y - glow_r - champ_glow_adj))
            # 내부 캐릭터 색 글로우
            glow_s2 = _get_arena_surface(glow_r * 2, glow_r * 2)
            pygame.draw.circle(glow_s2, (*champion_color, glow_a // 2), (glow_r, glow_r), glow_r - 20)
            self.screen.blit(glow_s2, (center_x - glow_r, champ_y - glow_r - champ_glow_adj))

        # 챔피언 캐릭터
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, champion_id, center_x, champ_y, champ_w, champ_h,
                facing="down", color=champion_color, scale_mode="preview"
            )

        # === 트로피 (챔피언 위, 스케일업 등장) ===
        if intro > 0.5:
            trophy_progress = min(1.0, (intro - 0.5) * 3)
            trophy_eased = self._ease_in_out(trophy_progress)
            trophy_y = champ_y - champ_h // 2 - 60
            trophy_size = int(30 * trophy_eased)
            if trophy_size > 3:
                # 트로피 받침대 빛
                sparkle_a = int(60 * trophy_eased + abs(_sin(self.animation_timer * 4)) * 40)
                sparkle_s = _get_arena_surface(80, 80)
                pygame.draw.circle(sparkle_s, (255, 230, 100, sparkle_a), (40, 40), 35)
                self.screen.blit(sparkle_s, (center_x - 40, trophy_y - 40))
                self._draw_trophy_icon(center_x, trophy_y, trophy_size, (255, 215, 0))

        # === 타이틀 텍스트 ===
        if intro > 0.4 and self.fonts:
            text_fade = min(1.0, (intro - 0.4) * 2.5)
            text_alpha = int(255 * text_fade)

            # "토너먼트 우승!" (큰 금색)
            if "large" in self.fonts:
                pulse = abs(_sin(self.animation_timer * 3)) * 0.3 + 0.7
                gold = (int(255 * pulse), int(215 * pulse), 0)
                surf, _ = self.fonts["large"].render("토너먼트 우승!", gold)
                alpha_s = _get_arena_surface(*surf.get_size())
                alpha_s.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                title_x = center_x - surf.get_width() // 2
                self.screen.blit(surf, (title_x, 80))
                # 양쪽 트로피 아이콘
                if text_fade > 0.5:
                    icon_y = 80 + surf.get_height() // 2
                    self._draw_trophy_icon(title_x - 20, icon_y, 16)
                    self._draw_trophy_icon(title_x + surf.get_width() + 20, icon_y, 16)

            # 챔피언 이름
            if "large" in self.fonts:
                brightness = sum(champion_color) / 3
                name_color = champion_color if brightness > 80 else (
                    min(255, champion_color[0] + 100),
                    min(255, champion_color[1] + 100),
                    min(255, champion_color[2] + 100)
                )
                surf, _ = self.fonts["large"].render(champion_name, name_color)
                alpha_s = _get_arena_surface(*surf.get_size())
                alpha_s.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, champ_y - champ_h // 2 - 30))

            # 칭호
            if "small" in self.fonts and champion_title:
                surf, _ = self.fonts["small"].render(champion_title, ET["text_body"])
                alpha_s = _get_arena_surface(*surf.get_size())
                alpha_s.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, champ_y + champ_h // 2 + 12))

            # "보상을 선택하세요" 안내
            if "medium" in self.fonts and text_fade > 0.6:
                guide_alpha = int(255 * min(1.0, (text_fade - 0.6) * 3))
                guide_text = "보상을 선택하세요!"
                surf, _ = self.fonts["medium"].render(guide_text, (255, 215, 0))
                alpha_s = _get_arena_surface(*surf.get_size())
                alpha_s.fill((255, 255, 255, guide_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, 555))

        # === 보상 선택 버튼 (3초 후 표시) ===
        if timer >= 3.0 and self.fonts:
            btn_fade = min(1.0, (timer - 3.0) / 0.5)
            btn_alpha = int(255 * btn_fade)
            btn_w, btn_h = 260, 55
            btn_y = 610

            # 왼쪽: 상금 수령
            gold_hovered = (self.hover_btn_id == "gold")
            gold_rect = pygame.Rect(center_x - btn_w - 15, btn_y, btn_w, btn_h)
            if gold_hovered:
                self._draw_hover_border(gold_rect.x, gold_rect.y, gold_rect.w, gold_rect.h, (100, 255, 100))
            gold_surf = _get_arena_surface(btn_w, btn_h)
            gold_bg = (*ET["btn_continue_hover"], btn_alpha) if gold_hovered else (*ET["btn_continue"], btn_alpha)
            gold_border = (*ET["malachite_light"], btn_alpha) if gold_hovered else (*ET["malachite_light"], btn_alpha)
            pygame.draw.rect(gold_surf, gold_bg, (0, 0, btn_w, btn_h), border_radius=6)
            pygame.draw.rect(gold_surf, gold_border, (0, 0, btn_w, btn_h), 2, border_radius=6)
            self.screen.blit(gold_surf, gold_rect.topleft)
            if "medium" in self.fonts:
                prize = self.accumulated_prize  # 누적 상금 전체 표시
                surf, _ = self.fonts["medium"].render(f"{prize}G 수령", (255, 255, 255))
                self._draw_coin_icon(gold_rect.centerx - surf.get_width() // 2 - 14,
                                     gold_rect.centery, 12)
                self.screen.blit(surf, (gold_rect.centerx - surf.get_width() // 2,
                                        gold_rect.centery - surf.get_height() // 2))

            # 오른쪽: 호위무사 등용
            recruit_hovered = (self.hover_btn_id == "recruit")
            hero_rect = pygame.Rect(center_x + 15, btn_y, btn_w, btn_h)
            if recruit_hovered:
                self._draw_hover_border(hero_rect.x, hero_rect.y, hero_rect.w, hero_rect.h, (255, 180, 80))
            hero_surf = _get_arena_surface(btn_w, btn_h)
            hero_bg = (200, 140, 70, btn_alpha) if recruit_hovered else (*ET["bronze"], btn_alpha)
            hero_border = (*ET["gold_pale"], btn_alpha) if recruit_hovered else (*ET["gold_pale"], btn_alpha)
            pygame.draw.rect(hero_surf, hero_bg, (0, 0, btn_w, btn_h), border_radius=6)
            pygame.draw.rect(hero_surf, hero_border, (0, 0, btn_w, btn_h), 2, border_radius=6)
            self.screen.blit(hero_surf, hero_rect.topleft)
            if "medium" in self.fonts:
                recruit_text = f"{champion_name} 호위무사 등용"
                surf, _ = self.fonts["medium"].render(recruit_text, (255, 220, 150))
                self._draw_sword_icon(hero_rect.centerx - surf.get_width() // 2 - 14,
                                      hero_rect.centery, 12, (255, 200, 100))
                self.screen.blit(surf, (hero_rect.centerx - surf.get_width() // 2,
                                        hero_rect.centery - surf.get_height() // 2))

        # === 컨페티 파티클 ===
        if intro > 0.6:
            confetti = getattr(self, 'victory_confetti', [])
            # 새 파티클 생성
            if len(confetti) < 60 and random.random() < 0.4:
                confetti.append({
                    'x': random.randint(50, SCREEN_WIDTH - 50),
                    'y': random.randint(-20, 0),
                    'vx': random.uniform(-1, 1),
                    'vy': random.uniform(1.5, 3.5),
                    'color': random.choice([
                        (255, 215, 50), (220, 90, 60), (80, 140, 200),
                        (64, 176, 166), (80, 200, 110), (220, 195, 150)
                    ]),
                    'size': random.randint(3, 7),
                    'rot': random.uniform(0, math.pi * 2),
                    'rot_speed': random.uniform(-3, 3)
                })

            # 업데이트 + 그리기
            alive = []
            for p in confetti:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['vy'] += 0.02  # 약한 중력
                p['rot'] += p['rot_speed'] * 0.016
                if p['y'] < SCREEN_HEIGHT + 10:
                    alive.append(p)
                    # 직사각형 컨페티 (회전된 폴리곤 직접 그리기)
                    s = p['size']
                    cx, cy = p['x'], p['y']
                    a = p['rot']
                    ca, sa = _cos(a), _sin(a)
                    hw, hh = s, s * 0.5
                    pygame.draw.polygon(self.screen, p['color'], (
                        (cx - hw * ca + hh * sa, cy - hw * sa - hh * ca),
                        (cx + hw * ca + hh * sa, cy + hw * sa - hh * ca),
                        (cx + hw * ca - hh * sa, cy + hw * sa + hh * ca),
                        (cx - hw * ca - hh * sa, cy - hw * sa + hh * ca)))
            self.victory_confetti = alive

        # === 하단 힌트 (버튼 나오기 전) ===
        if timer < 3.0 and timer > 1.5 and self.fonts and "small" in self.fonts:
            blink = abs(_sin(self.animation_timer * 2)) * 155 + 100
            surf, _ = self.fonts["small"].render("잠시 후 보상을 선택합니다...", (int(blink), int(blink), int(blink)))
            self.screen.blit(surf, (center_x - surf.get_width() // 2, 690))

    def _draw_tournament_end_ui(self):
        """토너먼트 종료 UI - 패배 시"""
        # 반투명 오버레이
        overlay = _get_arena_fullscreen()
        overlay.fill((*ET["overlay_dark"], 200))
        self.screen.blit(overlay, (0, 0))

        # 패널
        panel_x, panel_y = 180, 180
        panel_w, panel_h = 400, 340
        self._draw_egyptian_panel(panel_x, panel_y, panel_w, panel_h, border_color=ET["carnelian"])

        # 타이틀
        if self.fonts and "large" in self.fonts:
            title = "패배..."
            title_color = ET["carnelian_light"]
            surf, _ = self.fonts["large"].render(title, title_color)
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self.screen.blit(surf, (title_x, panel_y + 25))
            icon_y = panel_y + 25 + surf.get_height() // 2
            self._draw_skull_icon(title_x - 16, icon_y, 14)
            self._draw_skull_icon(title_x + surf.get_width() + 16, icon_y, 14)

        # 손실 표시
        if self.fonts and "large" in self.fonts:
            profit_text = f"입장료 {self.entry_fee}G를 잃었습니다"
            surf, _ = self.fonts["large"].render(profit_text, ET["carnelian_light"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 100))

        # 메시지
        if self.fonts and "medium" in self.fonts:
            msg = "다음에 다시 도전하세요!"
            surf, _ = self.fonts["medium"].render(msg, ET["text_body"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 160))

        # 나가기 버튼
        end_exit_hovered = (self.hover_btn_id == "end_exit")
        exit_rect = pygame.Rect(panel_x + 100, panel_y + 270, 200, 50)
        if end_exit_hovered:
            self._draw_hover_border(exit_rect.x, exit_rect.y, exit_rect.w, exit_rect.h, (130, 170, 255))
        exit_bg = ET["btn_exit_hover"] if end_exit_hovered else ET["btn_exit"]
        pygame.draw.rect(self.screen, exit_bg, exit_rect, border_radius=5)
        if end_exit_hovered:
            pygame.draw.rect(self.screen, ET["lapis_light"], exit_rect, 2, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self._render_text("medium", "투기장 나가기", ET["text_white"])
            self.screen.blit(surf, (exit_rect.centerx - surf.get_width() // 2, exit_rect.y + 15))

    # ========================================================================
    # 투기장 퍽 선택 시스템
    # ========================================================================
    def _build_perk_pool(self):
        """현재 배팅 영웅에 맞는 퍽 풀 구성 (기본 퍽 + 미보유 스킬, 이미 선택한 퍽 제외)"""
        # 이미 보유한 퍽 ID 수집
        owned_perk_ids = set()
        if self.bet_hero:
            hero_id = self.bet_hero["id"]
            for perk in self.hero_perks.get(hero_id, []):
                owned_perk_ids.add(perk["id"])

        # 기본 퍽 풀에서 이미 보유한 것 제외 + 해금 조건 체크
        pool = []
        for p in ARENA_PERK_POOL:
            if p["id"] in owned_perk_ids:
                continue
            # 해금 조건 체크
            unlock_cond = p.get("unlock_condition")
            if unlock_cond == "former_guards":
                # 이전에 호위무사를 해고한 적이 있어야 함
                if not getattr(self, 'former_guards', []):
                    continue
            pool.append(p)

        # 영웅의 미선택 스킬을 퍽 옵션으로 추가
        if self.bet_hero and HERO_SKILLS_AVAILABLE:
            hero_id = self.bet_hero["id"]
            # 이미 두 스킬 모두 보유하면 스킬 옵션 추가 안 함
            if not self.hero_has_both_skills.get(hero_id, False):
                current_skill_idx = self.hero_selected_skills.get(hero_id, 0)
                other_skill_idx = 1 - current_skill_idx
                skills = HERO_SKILLS.get(hero_id, [])
                if len(skills) > other_skill_idx:
                    other_skill = skills[other_skill_idx]
                    hero_color = tuple(self.bet_hero.get("color", (200, 200, 100)))
                    pool.append({
                        "id": f"skill_{other_skill.skill_id}",
                        "name": other_skill.korean_name,
                        "description": f"추가 스킬 획득",
                        "icon_color": hero_color,
                        "effect_type": "add_skill",
                        "value": other_skill_idx,
                    })

        return pool

    def _start_perk_select(self):
        """퍽 선택 화면 시작"""
        self.perk_selected_index = 0
        self.perk_anim_timer = 0.0
        self.perk_anim_phase = "appearing"
        self.perk_selected_id = None
        self.perk_frame_count = 0

        # 퍽 풀에서 랜덤 3개 선택
        pool = self._build_perk_pool()
        self.current_perk_options = random.sample(pool, min(3, len(pool)))

        # 슬라이드-인 오프셋: 카드0=왼쪽에서, 카드1=아래에서, 카드2=오른쪽에서
        self.perk_card_offsets = [-400.0, 500.0, 400.0]
        # 초기 파티클 (40개)
        self.perk_particles = []
        for _ in range(40):
            self.perk_particles.append({
                'x': random.uniform(0, SCREEN_WIDTH),
                'y': random.uniform(0, SCREEN_HEIGHT),
                'vx': random.uniform(-1.5, 1.5),
                'vy': random.uniform(-3, -0.5),
                'size': random.uniform(2, 6),
                'alpha': random.randint(100, 220),
                'color': random.choice([ET["lapis_light"], ET["gold_bright"],
                                        ET["malachite_light"], ET["turquoise_light"]])
            })
        self.state = TournamentState.PERK_SELECT
        print(f"[Perk] 퍽 선택 시작 (라운드: {self.current_round.value}, "
              f"선택지: {[p['name'] for p in self.current_perk_options]})")

    def _confirm_perk_selection(self):
        """퍽 선택 확정"""
        if self.perk_selected_index < 0 or self.perk_selected_index >= len(self.current_perk_options):
            return
        _load_button_click_sound()
        if _button_click_sound:
            _button_click_sound.play()
        selected_perk = self.current_perk_options[self.perk_selected_index]
        self.perk_selected_id = selected_perk["id"]

        # 배팅 영웅에게 퍽/스킬 적용
        if self.bet_hero:
            hero_id = self.bet_hero["id"]

            if selected_perk["effect_type"] == "add_skill":
                # 추가 스킬 획득: 영웅에게 2번째 스킬 부여
                self.hero_has_both_skills[hero_id] = True
                # 필러 퍽 아이콘에도 표시되도록 hero_perks에 추가
                if hero_id not in self.hero_perks:
                    self.hero_perks[hero_id] = []
                self.hero_perks[hero_id].append(dict(selected_perk))
                print(f"[Perk] {self.bet_hero['name']}에게 추가 스킬 '{selected_perk['name']}' 부여! "
                      f"(양쪽 스킬 보유)")
            elif selected_perk["effect_type"] == "recall_guard":
                # 재소집령: 해고했던 호위무사를 복귀시켜 2명으로 만듦
                if hero_id not in self.hero_perks:
                    self.hero_perks[hero_id] = []
                self.hero_perks[hero_id].append(dict(selected_perk))
                # former_guards에서 한 명을 꺼내 guard_warrior_map에 추가
                if self.former_guards:
                    recalled = self.former_guards.pop(0)  # 가장 먼저 해고된 호위무사
                    if hero_id not in self.guard_warrior_map:
                        self.guard_warrior_map[hero_id] = []
                    self.guard_warrior_map[hero_id].append(recalled)
                    # 복귀 호위무사 추적 (호위무사 선택 시 보존용)
                    self.recalled_guard_map[hero_id] = recalled
                    # 복귀 호위무사 스킬 랜덤 배정
                    self.hero_selected_skills[recalled["id"]] = random.randint(0, 1)
                    print(f"[Perk] {self.bet_hero['name']}에게 '재소집령' 퍽 부여! "
                          f"호위무사 '{recalled['name']}' 복귀 (총 호위무사: "
                          f"{len(self.guard_warrior_map[hero_id])}명)")
                else:
                    print(f"[Perk] {self.bet_hero['name']}에게 '재소집령' 퍽 부여! "
                          f"(복귀 가능한 호위무사 없음)")
            else:
                # 일반 퍽 추가
                if hero_id not in self.hero_perks:
                    self.hero_perks[hero_id] = []
                self.hero_perks[hero_id].append(dict(selected_perk))
                print(f"[Perk] {self.bet_hero['name']}에게 '{selected_perk['name']}' 퍽 부여! "
                      f"(총 {len(self.hero_perks[hero_id])}개)")

        # 파티클 폭발 (선택 카드 중심에서)
        num_options = len(self.current_perk_options)
        card_w, card_h = 210, 105
        card_gap = 10
        total_w = card_w * num_options + card_gap * (num_options - 1)
        sx = (SCREEN_WIDTH - total_w) // 2
        vy = 200
        card_cx = sx + self.perk_selected_index * (card_w + card_gap) + card_w // 2
        card_cy = vy + card_h // 2
        for _ in range(60):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(4, 12)
            self.perk_particles.append({
                'x': card_cx, 'y': card_cy,
                'vx': _cos(angle) * speed,
                'vy': _sin(angle) * speed,
                'size': random.uniform(3, 8),
                'alpha': 255,
                'color': selected_perk["icon_color"]
            })

        # 선택 애니메이션 시작
        self.perk_anim_phase = "selected"
        self.perk_frame_count = 0

    def _assign_ai_perks(self, hero: Dict, count: int):
        """AI 영웅에게 랜덤 퍽 부여 (중복 방지, 스킬 추가 퍽 포함)"""
        hero_id = hero["id"]
        if hero_id not in self.hero_perks:
            self.hero_perks[hero_id] = []
        owned_ids = {p["id"] for p in self.hero_perks[hero_id]}
        available = []
        for p in ARENA_PERK_POOL:
            if p["id"] in owned_ids:
                continue
            # 해금 조건 체크 (AI에게도 동일하게 적용)
            unlock_cond = p.get("unlock_condition")
            if unlock_cond == "former_guards":
                if not getattr(self, 'former_guards', []):
                    continue
            available.append(p)

        # 스킬 추가 퍽도 후보에 포함 (아직 양쪽 스킬 미보유 시)
        if HERO_SKILLS_AVAILABLE and not self.hero_has_both_skills.get(hero_id, False):
            current_skill_idx = self.hero_selected_skills.get(hero_id, 0)
            other_skill_idx = 1 - current_skill_idx
            try:
                skills = HERO_SKILLS.get(hero_id, [])
                if len(skills) > other_skill_idx:
                    other_skill = skills[other_skill_idx]
                    hero_color = tuple(hero.get("color", (200, 200, 100)))
                    available.append({
                        "id": f"skill_{other_skill.skill_id}",
                        "name": other_skill.korean_name,
                        "description": "추가 스킬 획득",
                        "icon_color": hero_color,
                        "effect_type": "add_skill",
                        "value": other_skill_idx,
                    })
            except Exception:
                pass

        for _ in range(count):
            if not available:
                break
            perk = random.choice(available)
            if perk["effect_type"] == "add_skill":
                # 스킬 추가 퍽: hero_has_both_skills 설정 + hero_perks에 추가
                self.hero_has_both_skills[hero_id] = True
                self.hero_perks[hero_id].append(dict(perk))
                # 스킬 퍽은 1회만 가능하므로 풀에서 제거
                available = [p for p in available if p["effect_type"] != "add_skill"]
            elif perk["effect_type"] == "recall_guard":
                # 재소집령: AI도 해고된 호위무사 복귀
                self.hero_perks[hero_id].append(dict(perk))
                if self.former_guards:
                    recalled = self.former_guards.pop(0)
                    if hero_id not in self.guard_warrior_map:
                        self.guard_warrior_map[hero_id] = []
                    self.guard_warrior_map[hero_id].append(recalled)
                    # 복귀 호위무사 추적 (호위무사 선택 시 보존용)
                    self.recalled_guard_map[hero_id] = recalled
                    self.hero_selected_skills[recalled["id"]] = random.randint(0, 1)
                owned_ids.add(perk["id"])
                available = [p for p in available if p["id"] != perk["id"]]
            else:
                self.hero_perks[hero_id].append(dict(perk))
                owned_ids.add(perk["id"])
                available = [p for p in available if p["id"] != perk["id"]]
        print(f"[Perk] AI {hero['name']}에게 랜덤 퍽 {count}개 부여: "
              f"{[p['name'] for p in self.hero_perks[hero_id]]}")

    def get_hero_perk_multipliers(self, hero_id: str) -> Dict[str, float]:
        """영웅의 퍽에서 멀티플라이어 계산"""
        perks = self.hero_perks.get(hero_id, [])
        mults = {
            "move_speed": 1.0,
            "dash_cooldown": 1.0,
            "skill_cooldown": 1.0,
            "guard_cooldown": 1.0,
            "dash_tokens": 0,           # 추가 대쉬 토큰 수
            "dash_distance": 1.0,       # 대쉬 거리 배율
            "retry_chance": 0.0,        # 패배 시 재시작 확률
            "guard_extra_skill": False,  # 호위무사 추가 스킬 해금
            "magic_immunity": 0.0,      # 타격 시 마법 면역 확률
            "laurel_shield": 0,         # 신성월계수 잎 개수 (0이면 비활성)
            "paddle_enlarge": 1.0,      # 패들 확대 배율
            "recall_guard": False,      # 재소집령 (호위무사 복귀)
            "instant_cooldown": 0.0,    # 타격 시 스킬쿨 즉시 충전 확률
        }
        for perk in perks:
            etype = perk["effect_type"]
            val = perk["value"]
            if etype == "move_speed":
                mults["move_speed"] += val
            elif etype == "dash_cooldown":
                mults["dash_cooldown"] -= val
            elif etype == "skill_cooldown":
                mults["skill_cooldown"] -= val
            elif etype == "guard_cooldown":
                mults["guard_cooldown"] -= val
            elif etype == "dash_token":
                mults["dash_tokens"] += int(val)
            elif etype == "dash_distance":
                mults["dash_distance"] += val
            elif etype == "retry_chance":
                mults["retry_chance"] = val
            elif etype == "guard_extra_skill":
                mults["guard_extra_skill"] = True
            elif etype == "magic_immunity":
                mults["magic_immunity"] = val
            elif etype == "laurel_shield":
                mults["laurel_shield"] = int(val)
            elif etype == "paddle_enlarge":
                mults["paddle_enlarge"] += val
            elif etype == "recall_guard":
                mults["recall_guard"] = True
            elif etype == "instant_cooldown":
                mults["instant_cooldown"] = val
        return mults

    def _draw_perk_icon_swift_foot(self, surf, cx, cy, r, ss):
        """질풍각 아이콘 - 바람 소용돌이"""
        color = (100, 220, 255)
        # 소용돌이 곡선 3개
        for i in range(3):
            points = []
            base_angle = i * (2 * math.pi / 3)
            for t in range(20):
                frac = t / 19.0
                angle = base_angle + frac * math.pi * 1.5
                dist = r * ss * (0.15 + frac * 0.7)
                px = cx + int(_cos(angle) * dist)
                py = cy + int(_sin(angle) * dist)
                points.append((px, py))
            if len(points) >= 2:
                alpha = 200 - i * 30
                pygame.draw.lines(surf, (*color, alpha), False, points, max(2, int(3 * ss / 3)))
        # 중심 원
        pygame.draw.circle(surf, (*color, 220), (cx, cy), max(2, int(r * ss * 0.15)))

    def _draw_perk_icon_quick_reflex(self, surf, cx, cy, r, ss):
        """순발력 아이콘 - 번개 볼트"""
        color = (255, 180, 50)
        s = r * ss
        # 번개 모양 폴리곤
        bolt_points = [
            (cx - int(s * 0.15), cy - int(s * 0.8)),
            (cx + int(s * 0.3), cy - int(s * 0.8)),
            (cx + int(s * 0.05), cy - int(s * 0.15)),
            (cx + int(s * 0.35), cy - int(s * 0.15)),
            (cx - int(s * 0.1), cy + int(s * 0.8)),
            (cx + int(s * 0.1), cy + int(s * 0.15)),
            (cx - int(s * 0.2), cy + int(s * 0.15)),
        ]
        pygame.draw.polygon(surf, (*color, 230), bolt_points)
        # 외곽선
        pygame.draw.polygon(surf, (255, 220, 100, 180), bolt_points, max(1, int(2 * ss / 3)))

    def _draw_perk_icon_spirit_flow(self, surf, cx, cy, r, ss):
        """영기순환 아이콘 - 순환 고리"""
        color = (180, 100, 255)
        s = r * ss
        ring_r = int(s * 0.55)
        # 두 개의 반원 화살표
        for flip in [1, -1]:
            points = []
            for t in range(25):
                frac = t / 24.0
                angle = flip * (frac * math.pi - math.pi / 2)
                px = cx + int(_cos(angle) * ring_r)
                py = cy + int(_sin(angle) * ring_r * flip)
                points.append((px, py))
            if len(points) >= 2:
                pygame.draw.lines(surf, (*color, 220), False, points, max(2, int(3 * ss / 3)))
            # 화살표 머리
            if points:
                end = points[-1]
                arr_size = int(s * 0.2)
                arr_angle = math.atan2(
                    points[-1][1] - points[-2][1],
                    points[-1][0] - points[-2][0]
                )
                a1 = (end[0] - int(_cos(arr_angle - 0.5) * arr_size),
                      end[1] - int(_sin(arr_angle - 0.5) * arr_size))
                a2 = (end[0] - int(_cos(arr_angle + 0.5) * arr_size),
                      end[1] - int(_sin(arr_angle + 0.5) * arr_size))
                pygame.draw.polygon(surf, (*color, 230), [end, a1, a2])

    def _draw_perk_icon_command(self, surf, cx, cy, r, ss):
        """호령 아이콘 - 방패 + 삼각 문양"""
        color = (255, 100, 100)
        s = r * ss
        # 방패 외곽 (둥근 오각형 모양)
        shield_points = [
            (cx, cy - int(s * 0.75)),
            (cx + int(s * 0.6), cy - int(s * 0.4)),
            (cx + int(s * 0.5), cy + int(s * 0.3)),
            (cx, cy + int(s * 0.75)),
            (cx - int(s * 0.5), cy + int(s * 0.3)),
            (cx - int(s * 0.6), cy - int(s * 0.4)),
        ]
        pygame.draw.polygon(surf, (*color, 60), shield_points)
        pygame.draw.polygon(surf, (*color, 220), shield_points, max(2, int(3 * ss / 3)))
        # 안쪽 삼각형 (위를 가리키는 ▲)
        tri_s = int(s * 0.3)
        tri_points = [
            (cx, cy - tri_s),
            (cx + int(tri_s * 0.87), cy + int(tri_s * 0.5)),
            (cx - int(tri_s * 0.87), cy + int(tri_s * 0.5)),
        ]
        pygame.draw.polygon(surf, (255, 200, 200, 200), tri_points)

    def _draw_perk_icon_shadow_step(self, surf, cx, cy, r, ss):
        """잔상술 아이콘 - 겹쳐진 그림자 (잔상 3개)"""
        color = (80, 200, 180)
        s = r * ss
        # 3개의 잔상 (점점 진해짐)
        for i in range(3):
            offset_x = int(s * 0.25 * (2 - i))
            alpha = 60 + i * 70  # 60, 130, 200
            body_w = int(s * 0.3)
            body_h = int(s * 0.6)
            bx = cx - body_w // 2 - offset_x
            by = cy - body_h // 2
            pygame.draw.rect(surf, (*color, alpha), (bx, by, body_w, body_h),
                             border_radius=max(1, int(body_w * 0.3)))
            # 머리
            head_r = int(s * 0.15)
            pygame.draw.circle(surf, (*color, alpha), (bx + body_w // 2, by - head_r + 2), head_r)
        # "+1" 텍스트 효과 (우측 상단)
        plus_r = int(s * 0.2)
        pygame.draw.circle(surf, (255, 255, 255, 200), (cx + int(s * 0.5), cy - int(s * 0.4)), plus_r)
        lw = max(1, int(plus_r * 0.4))
        px, py = cx + int(s * 0.5), cy - int(s * 0.4)
        pygame.draw.line(surf, (80, 200, 180, 255), (px - plus_r + 2, py), (px + plus_r - 2, py), lw)
        pygame.draw.line(surf, (80, 200, 180, 255), (px, py - plus_r + 2), (px, py + plus_r - 2), lw)

    def _draw_perk_icon_storm_rush(self, surf, cx, cy, r, ss):
        """폭풍질주 아이콘 - 화살표 + 바람 줄"""
        color = (50, 180, 255)
        s = r * ss
        # 큰 화살표 (→)
        arrow_y = cy
        arrow_left = cx - int(s * 0.6)
        arrow_right = cx + int(s * 0.3)
        arrow_w = max(2, int(s * 0.2))
        pygame.draw.line(surf, (*color, 230), (arrow_left, arrow_y), (arrow_right, arrow_y), arrow_w)
        # 화살표 머리
        head_s = int(s * 0.35)
        tip_x = cx + int(s * 0.6)
        pygame.draw.polygon(surf, (*color, 230), [
            (tip_x, arrow_y),
            (arrow_right, arrow_y - head_s),
            (arrow_right, arrow_y + head_s),
        ])
        # 바람 줄 3개
        for i in range(3):
            wy = cy - int(s * 0.4) + i * int(s * 0.4)
            w_alpha = 120 - i * 20
            wx_start = cx - int(s * 0.7)
            wx_end = cx - int(s * 0.2)
            pygame.draw.line(surf, (*color, w_alpha), (wx_start, wy), (wx_end, wy), max(1, int(s * 0.06)))

    def _draw_perk_icon_tenacity(self, surf, cx, cy, r, ss):
        """반칙왕 아이콘 - 불꽃 + 주먹"""
        color = (255, 200, 60)
        s = r * ss
        # 불꽃 (아래에서 위로)
        flame_points = [
            (cx, cy - int(s * 0.75)),
            (cx + int(s * 0.35), cy - int(s * 0.3)),
            (cx + int(s * 0.2), cy + int(s * 0.1)),
            (cx + int(s * 0.4), cy + int(s * 0.5)),
            (cx, cy + int(s * 0.3)),
            (cx - int(s * 0.4), cy + int(s * 0.5)),
            (cx - int(s * 0.2), cy + int(s * 0.1)),
            (cx - int(s * 0.35), cy - int(s * 0.3)),
        ]
        pygame.draw.polygon(surf, (*color, 180), flame_points)
        # 안쪽 밝은 불꽃
        inner_points = [
            (cx, cy - int(s * 0.45)),
            (cx + int(s * 0.15), cy - int(s * 0.1)),
            (cx + int(s * 0.2), cy + int(s * 0.2)),
            (cx, cy + int(s * 0.1)),
            (cx - int(s * 0.2), cy + int(s * 0.2)),
            (cx - int(s * 0.15), cy - int(s * 0.1)),
        ]
        pygame.draw.polygon(surf, (255, 240, 150, 200), inner_points)

    def _draw_perk_icon_extra_training(self, surf, cx, cy, r, ss):
        """추가훈련 아이콘 - 검 두 자루 (스킬 2개 해금)"""
        color = (100, 180, 220)
        s = r * ss
        lw = max(2, int(2 * ss / 3))
        # 왼쪽 검
        sword_h = int(s * 0.7)
        sword_w = int(s * 0.12)
        sx1 = cx - int(s * 0.2)
        pygame.draw.line(surf, (*color, 220), (sx1, cy - sword_h), (sx1, cy + int(s * 0.1)), lw + 1)
        # 왼쪽 검 가드
        pygame.draw.line(surf, (*color, 180), (sx1 - int(s * 0.15), cy + int(s * 0.1)),
                         (sx1 + int(s * 0.15), cy + int(s * 0.1)), lw)
        # 왼쪽 검 손잡이
        pygame.draw.line(surf, (*color, 150), (sx1, cy + int(s * 0.1)), (sx1, cy + int(s * 0.35)), lw)
        # 오른쪽 검
        sx2 = cx + int(s * 0.2)
        pygame.draw.line(surf, (*color, 220), (sx2, cy - sword_h), (sx2, cy + int(s * 0.1)), lw + 1)
        # 오른쪽 검 가드
        pygame.draw.line(surf, (*color, 180), (sx2 - int(s * 0.15), cy + int(s * 0.1)),
                         (sx2 + int(s * 0.15), cy + int(s * 0.1)), lw)
        # 오른쪽 검 손잡이
        pygame.draw.line(surf, (*color, 150), (sx2, cy + int(s * 0.1)), (sx2, cy + int(s * 0.35)), lw)
        # 중앙 '+' 표시 (추가 해금)
        plus_s = int(s * 0.15)
        pygame.draw.line(surf, (255, 255, 255, 200), (cx - plus_s, cy + int(s * 0.5)),
                         (cx + plus_s, cy + int(s * 0.5)), lw)
        pygame.draw.line(surf, (255, 255, 255, 200), (cx, cy + int(s * 0.5) - plus_s),
                         (cx, cy + int(s * 0.5) + plus_s), lw)

    def _draw_perk_icon_magic_barrier(self, surf, cx, cy, r, ss):
        """마법결계 아이콘 - 반투명 보호막 원"""
        color = (120, 200, 255)
        s = r * ss
        # 외곽 보호막 원
        shield_r = int(s * 0.65)
        pygame.draw.circle(surf, (*color, 80), (cx, cy), shield_r)
        pygame.draw.circle(surf, (*color, 200), (cx, cy), shield_r, max(2, int(3 * ss / 3)))
        # 안쪽 보호막 원
        inner_r = int(s * 0.45)
        pygame.draw.circle(surf, (*color, 60), (cx, cy), inner_r)
        pygame.draw.circle(surf, (*color, 150), (cx, cy), inner_r, max(1, int(2 * ss / 3)))
        # 중심 별 모양 (마법 문양)
        star_r = int(s * 0.2)
        for i in range(6):
            angle = i * math.pi / 3
            ex = cx + int(_cos(angle) * star_r)
            ey = cy + int(_sin(angle) * star_r)
            pygame.draw.line(surf, (200, 240, 255, 220), (cx, cy), (ex, ey), max(1, int(2 * ss / 3)))

    def _draw_perk_icon_laurel_shield(self, surf, cx, cy, r, ss):
        """신성월계수 아이콘 - 잎 3개가 원형 궤도"""
        s = r * ss
        # 궤도 원 (점선 느낌)
        orbit_r = int(s * 0.55)
        pygame.draw.circle(surf, (200, 180, 60, 60), (cx, cy), orbit_r, max(1, int(1 * ss / 3)))
        # 잎 3개 배치
        for i in range(3):
            angle = i * (2 * math.pi / 3) - math.pi / 2
            lx = cx + int(_cos(angle) * orbit_r)
            ly = cy + int(_sin(angle) * orbit_r * 0.7)
            leaf_w = max(3, int(s * 0.25))
            leaf_h = max(2, int(s * 0.15))
            leaf_s = _get_arena_surface(leaf_w + 2, leaf_h + 2)
            pygame.draw.ellipse(leaf_s, (240, 220, 80, 220), (1, 1, leaf_w, leaf_h))
            rot = pygame.transform.rotate(leaf_s, -math.degrees(angle))
            rect = rot.get_rect(center=(lx, ly))
            surf.blit(rot, rect)
        # 중심 빛
        pygame.draw.circle(surf, (255, 240, 150, 120), (cx, cy), int(s * 0.15))

    def _draw_perk_icon_titan_body(self, surf, cx, cy, r, ss):
        """거신화 아이콘 - 위로 확대되는 몸체"""
        color = (220, 120, 60)
        s = r * ss
        # 큰 몸체 실루엣 (사다리꼴)
        bw = int(s * 0.6)
        bh = int(s * 0.75)
        top_w = int(bw * 0.7)
        body_top = cy - int(bh * 0.4)
        body_bot = cy + int(bh * 0.4)
        pts = [
            (cx - top_w // 2, body_top),
            (cx + top_w // 2, body_top),
            (cx + bw // 2, body_bot),
            (cx - bw // 2, body_bot),
        ]
        pygame.draw.polygon(surf, (*color, 180), pts)
        pygame.draw.polygon(surf, (*color, 255), pts, max(2, int(2 * ss / 3)))
        # 머리
        head_r = int(s * 0.2)
        pygame.draw.circle(surf, (*color, 200), (cx, body_top - head_r + 2), head_r)
        pygame.draw.circle(surf, (*color, 255), (cx, body_top - head_r + 2), head_r, max(1, int(2 * ss / 3)))
        # 확대 화살표 (↑)
        arr_x = cx + int(s * 0.45)
        arr_bot = cy + int(s * 0.3)
        arr_top = cy - int(s * 0.45)
        pygame.draw.line(surf, (255, 200, 100, 220), (arr_x, arr_bot), (arr_x, arr_top), max(2, int(2 * ss / 3)))
        pygame.draw.polygon(surf, (255, 200, 100, 220), [
            (arr_x, arr_top - int(s * 0.1)),
            (arr_x - int(s * 0.1), arr_top + int(s * 0.05)),
            (arr_x + int(s * 0.1), arr_top + int(s * 0.05)),
        ])

    def _draw_perk_icon_recall_guard(self, surf, cx, cy, r, ss):
        """재소집령 아이콘 - 두 명의 전사 실루엣 (한 명은 귀환 화살표)"""
        color = (200, 160, 60)
        s = r * ss
        lw = max(2, int(2 * ss / 3))
        # 왼쪽 전사 (기존 호위무사 - 진한 색)
        w1_x = cx - int(s * 0.3)
        body_w = int(s * 0.25)
        body_h = int(s * 0.45)
        head_r = int(s * 0.13)
        # 머리
        pygame.draw.circle(surf, (*color, 220), (w1_x, cy - int(s * 0.3)), head_r)
        # 몸체
        pygame.draw.rect(surf, (*color, 200),
                         (w1_x - body_w // 2, cy - int(s * 0.15), body_w, body_h),
                         border_radius=max(1, int(body_w * 0.2)))
        # 방패 (왼쪽 전사)
        shield_w = int(s * 0.12)
        shield_h = int(s * 0.2)
        pygame.draw.rect(surf, (180, 140, 50, 180),
                         (w1_x - body_w // 2 - shield_w, cy - int(s * 0.05), shield_w, shield_h),
                         border_radius=max(1, int(shield_w * 0.3)))

        # 오른쪽 전사 (복귀 호위무사 - 반투명, 귀환 중)
        w2_x = cx + int(s * 0.3)
        # 머리 (반투명)
        pygame.draw.circle(surf, (*color, 130), (w2_x, cy - int(s * 0.3)), head_r)
        # 몸체 (반투명)
        pygame.draw.rect(surf, (*color, 120),
                         (w2_x - body_w // 2, cy - int(s * 0.15), body_w, body_h),
                         border_radius=max(1, int(body_w * 0.2)))
        # 검 (오른쪽 전사)
        sword_h = int(s * 0.3)
        pygame.draw.line(surf, (220, 200, 100, 150),
                         (w2_x + body_w // 2 + 2, cy - int(s * 0.15)),
                         (w2_x + body_w // 2 + 2, cy - int(s * 0.15) - sword_h), lw)

        # 귀환 화살표 (오른쪽 → 왼쪽으로 향하는 곡선 화살표)
        arrow_y = cy + int(s * 0.45)
        arrow_left = cx - int(s * 0.35)
        arrow_right = cx + int(s * 0.35)
        pygame.draw.line(surf, (255, 220, 100, 200),
                         (arrow_right, arrow_y), (arrow_left, arrow_y), lw)
        # 화살표 머리 (왼쪽 방향)
        arr_s = int(s * 0.1)
        pygame.draw.polygon(surf, (255, 220, 100, 200), [
            (arrow_left - arr_s, arrow_y),
            (arrow_left + arr_s, arrow_y - arr_s),
            (arrow_left + arr_s, arrow_y + arr_s),
        ])

    def _draw_perk_icon_flash_inspiration(self, surf, cx, cy, r, ss):
        """번뜩이는 영감 아이콘 - 전구 + 반짝이는 빛"""
        color = (255, 220, 100)
        s = r * ss
        lw = max(2, int(2 * ss / 3))
        # 전구 유리 부분 (상단 원)
        bulb_r = int(s * 0.35)
        bulb_cy = cy - int(s * 0.15)
        pygame.draw.circle(surf, (*color, 200), (cx, bulb_cy), bulb_r)
        pygame.draw.circle(surf, (255, 255, 230, 120), (cx - int(s * 0.1), bulb_cy - int(s * 0.1)), int(bulb_r * 0.35))
        pygame.draw.circle(surf, (*color, 255), (cx, bulb_cy), bulb_r, lw)
        # 전구 나사산 (하단 직사각형)
        base_w = int(s * 0.22)
        base_h = int(s * 0.2)
        base_top = bulb_cy + bulb_r - int(s * 0.05)
        pygame.draw.rect(surf, (200, 170, 60, 200),
                         (cx - base_w, base_top, base_w * 2, base_h),
                         border_radius=max(1, int(base_w * 0.3)))
        # 나사산 줄
        for i in range(3):
            ly = base_top + int(base_h * (i + 1) / 4)
            pygame.draw.line(surf, (180, 150, 50, 150),
                             (cx - base_w + 2, ly), (cx + base_w - 2, ly), max(1, lw // 2))
        # 빛 방사선 (6방향)
        for i in range(6):
            angle = i * (math.pi / 3) + math.pi / 6
            inner_dist = int(s * 0.5)
            outer_dist = int(s * 0.7)
            x1 = cx + int(_cos(angle) * inner_dist)
            y1 = bulb_cy + int(_sin(angle) * inner_dist)
            x2 = cx + int(_cos(angle) * outer_dist)
            y2 = bulb_cy + int(_sin(angle) * outer_dist)
            pygame.draw.line(surf, (255, 240, 150, 180), (x1, y1), (x2, y2), lw)
        # 반짝이는 별 (4각 별 2개)
        for sx, sy in [(cx - int(s * 0.55), bulb_cy - int(s * 0.4)),
                       (cx + int(s * 0.5), bulb_cy + int(s * 0.1))]:
            star_s = int(s * 0.12)
            pygame.draw.line(surf, (255, 255, 200, 220), (sx - star_s, sy), (sx + star_s, sy), max(1, lw // 2))
            pygame.draw.line(surf, (255, 255, 200, 220), (sx, sy - star_s), (sx, sy + star_s), max(1, lw // 2))

    def _draw_perk_icon_skill(self, surf, cx, cy, r, ss):
        """스킬 추가 아이콘 - 검 (⚔) 모양"""
        color = (255, 220, 100)  # 골드
        s = r * ss
        # 칼날 (세로 직사각형)
        blade_w = int(s * 0.15)
        blade_h = int(s * 0.8)
        blade_top = cy - int(s * 0.55)
        pygame.draw.rect(surf, (*color, 220),
                         (cx - blade_w, blade_top, blade_w * 2, blade_h))
        # 칼날 하이라이트
        pygame.draw.rect(surf, (255, 255, 230, 150),
                         (cx - blade_w // 2, blade_top, blade_w, blade_h))
        # 가드 (가로 직사각형)
        guard_w = int(s * 0.5)
        guard_h = int(s * 0.12)
        guard_y = cy + int(s * 0.15)
        pygame.draw.rect(surf, (200, 160, 60, 220),
                         (cx - guard_w, guard_y, guard_w * 2, guard_h),
                         border_radius=max(1, int(guard_h * 0.4)))
        # 손잡이
        grip_w = int(s * 0.1)
        grip_h = int(s * 0.3)
        grip_y = guard_y + guard_h
        pygame.draw.rect(surf, (160, 120, 40, 200),
                         (cx - grip_w, grip_y, grip_w * 2, grip_h))
        # 끝 장식 (원)
        pommel_y = grip_y + grip_h
        pygame.draw.circle(surf, (200, 160, 60, 220), (cx, pommel_y), int(s * 0.12))

    def _draw_perk_icon(self, surface, perk_id, cx, cy, size):
        """퍽 아이콘 (3x 슈퍼샘플링으로 깨짐 방지)"""
        ss = 3
        hi = size * ss
        icon_surf = _get_arena_surface(hi, hi)
        center = hi // 2
        r = size // 2

        draw_funcs = {
            "swift_foot": self._draw_perk_icon_swift_foot,
            "quick_reflex": self._draw_perk_icon_quick_reflex,
            "spirit_flow": self._draw_perk_icon_spirit_flow,
            "command": self._draw_perk_icon_command,
            "shadow_step": self._draw_perk_icon_shadow_step,
            "storm_rush": self._draw_perk_icon_storm_rush,
            "tenacity": self._draw_perk_icon_tenacity,
            "extra_training": self._draw_perk_icon_extra_training,
            "magic_barrier": self._draw_perk_icon_magic_barrier,
            "laurel_shield": self._draw_perk_icon_laurel_shield,
            "titan_body": self._draw_perk_icon_titan_body,
            "recall_guard": self._draw_perk_icon_recall_guard,
            "flash_inspiration": self._draw_perk_icon_flash_inspiration,
        }
        # 스킬 타입 퍽은 별(★) 아이콘으로 표시
        if perk_id.startswith("skill_"):
            self._draw_perk_icon_skill(icon_surf, center, center, r, ss)
        else:
            func = draw_funcs.get(perk_id)
            if func:
                func(icon_surf, center, center, r, ss)

        # smoothscale로 축소 → 안티앨리어싱 적용
        result = pygame.transform.smoothscale(icon_surf, (size, size))
        surface.blit(result, (cx - size // 2, cy - size // 2))

    def _draw_tenacity_retry(self):
        """반칙왕 퍽 재시작 연출"""
        self.screen.fill(ET["bg_dark"])
        timer = getattr(self, 'tenacity_timer', 0.0)
        alpha = min(255, int(timer * 200))

        if self.fonts and "large" in self.fonts:
            text = "반칙왕 발동!"
            # 펄스 효과
            pulse = 1.0 + 0.1 * _sin(timer * 8)
            surf, _ = self.fonts["large"].render(text, (255, 200, 60))
            surf = pygame.transform.smoothscale(surf,
                (int(surf.get_width() * pulse), int(surf.get_height() * pulse)))
            surf.set_alpha(alpha)
            self.screen.blit(surf,
                (SCREEN_WIDTH // 2 - surf.get_width() // 2,
                 SCREEN_HEIGHT // 2 - 60))

        if self.fonts and "medium" in self.fonts:
            sub_text = "재시작합니다..."
            sub_surf, _ = self.fonts["medium"].render(sub_text, ET["gold_bright"])
            sub_surf.set_alpha(min(255, max(0, int((timer - 0.5) * 400))))
            self.screen.blit(sub_surf,
                (SCREEN_WIDTH // 2 - sub_surf.get_width() // 2,
                 SCREEN_HEIGHT // 2 + 20))

    def _draw_perk_select(self):
        """퍽 선택 화면 그리기 (스테이지 인게임 퍽 UI 스타일)"""
        # 배경 (어두운 배경)
        self.screen.fill(ET["bg_dark"])

        # 반투명 오버레이 (점진적 어두워짐)
        overlay_alpha = min(160, self.perk_frame_count * 6)
        overlay = _get_arena_fullscreen()
        overlay.fill((*ET["overlay_warm"], overlay_alpha))
        self.screen.blit(overlay, (0, 0))

        # 파티클 렌더링
        for p in self.perk_particles:
            if p['alpha'] > 0:
                ps = int(p['size'] * 2)
                if ps < 2:
                    ps = 2
                particle_surf = _get_arena_surface(ps, ps)
                pygame.draw.circle(particle_surf, (*p['color'], int(p['alpha'])),
                                   (ps // 2, ps // 2), max(1, ps // 2))
                self.screen.blit(particle_surf,
                                 (int(p['x'] - p['size']), int(p['y'] - p['size'])))

        # 카드 설정 (랜덤 3장) - 가로 사이즈 확대 + 위쪽 배치
        num_options = len(self.current_perk_options)
        card_w, card_h = 210, 105
        icon_size = 52
        card_gap = 10
        total_w = card_w * num_options + card_gap * (num_options - 1)
        start_x = (SCREEN_WIDTH - total_w) // 2
        vertical_y = 200

        # 타이틀 (골드, 스테이지 스타일)
        if self.fonts and "large" in self.fonts:
            title_alpha = min(255, self.perk_frame_count * 10)
            title_y_offset = max(0, 40 - self.perk_frame_count * 2)
            title = "퍽을 선택하세요"
            title_surf, _ = self.fonts["large"].render(title, ET["gold_bright"])
            title_surf.set_alpha(title_alpha)
            tx = SCREEN_WIDTH // 2 - title_surf.get_width() // 2
            ty = vertical_y - 70 - title_y_offset
            self.screen.blit(title_surf, (tx, ty))

        # 카드 렌더링 (랜덤 선택된 퍽들)
        for i, perk in enumerate(self.current_perk_options):
            # 카드 위치 계산 (슬라이드-인 적용)
            base_x = start_x + i * (card_w + card_gap)
            base_y = vertical_y
            if i == 0:
                card_x = base_x + self.perk_card_offsets[0]
                card_y_anim = base_y
            elif i == num_options - 1:
                card_x = base_x + self.perk_card_offsets[i]
                card_y_anim = base_y
            else:
                card_x = base_x
                card_y_anim = base_y + self.perk_card_offsets[i]

            is_selected = (i == self.perk_selected_index and
                           self.perk_anim_phase in ("active", "selected"))
            is_hovered = (i == self.hover_perk_index and
                          self.perk_anim_phase == "active" and not is_selected)

            # 선택 완료 애니메이션
            scale = 1.0
            card_alpha = 255
            if self.perk_anim_phase == "selected":
                if i == self.perk_selected_index:
                    scale = 1.0 + self.perk_frame_count * 0.015
                else:
                    card_alpha = max(0, 255 - self.perk_frame_count * 12)

            if card_alpha <= 0:
                continue

            # 카드 서피스 생성
            scaled_w = int(card_w * scale)
            scaled_h = int(card_h * scale)
            card_surf = _get_arena_surface(scaled_w, scaled_h)

            # 6단계 외곽 글로우 (선택 시, 스테이지 스타일)
            if is_selected:
                glow_intensity = int(30 + 25 * _sin(self.perk_frame_count * 0.12))
                glow_color = (
                    min(255, perk["icon_color"][0] + glow_intensity),
                    min(255, perk["icon_color"][1] + glow_intensity),
                    min(255, perk["icon_color"][2] + glow_intensity)
                )
                for offset in range(6, 0, -1):
                    glow_rect = pygame.Rect(offset, offset,
                                            scaled_w - offset * 2, scaled_h - offset * 2)
                    alpha = min(card_alpha, 100 - offset * 15)
                    if alpha > 0:
                        glow_s = _get_arena_surface(scaled_w, scaled_h)
                        pygame.draw.rect(glow_s, (*glow_color, alpha),
                                         glow_rect, border_radius=12)
                        card_surf.blit(glow_s, (0, 0))
                bg_color = (*ET["card_bg_hover"], min(card_alpha, 250))
                border_color = perk["icon_color"]
                border_width = 3
            elif is_hovered:
                # 호버 시 밝은 배경 + 아이콘 색상 테두리
                hover_pulse = 0.6 + 0.4 * abs(_sin(self.hover_glow_timer * 4.0))
                hover_glow_a = int(60 * hover_pulse)
                for offset in range(4, 0, -1):
                    glow_rect = pygame.Rect(offset, offset,
                                            scaled_w - offset * 2, scaled_h - offset * 2)
                    a = min(card_alpha, hover_glow_a - offset * 12)
                    if a > 0:
                        glow_s = _get_arena_surface(scaled_w, scaled_h)
                        pygame.draw.rect(glow_s, (*perk["icon_color"], a),
                                         glow_rect, border_radius=12)
                        card_surf.blit(glow_s, (0, 0))
                bg_color = (*ET["card_bg_hover"], min(card_alpha, 240))
                border_color = tuple(min(255, c + 40) for c in perk["icon_color"])
                border_width = 2
            else:
                bg_color = (*ET["card_bg"], min(card_alpha, 220))
                border_color = ET["card_border"]
                border_width = 2

            # 카드 배경
            card_rect = pygame.Rect(0, 0, scaled_w, scaled_h)
            pygame.draw.rect(card_surf, bg_color, card_rect, border_radius=12)
            pygame.draw.rect(card_surf, border_color, card_rect, border_width, border_radius=12)

            # 아이콘 (왼쪽, 스테이지 스타일)
            icon_margin = 10
            icon_scaled = int(icon_size * scale)
            icon_rect = pygame.Rect(icon_margin, (scaled_h - icon_scaled) // 2,
                                    icon_scaled, icon_scaled)
            # 아이콘 어두운 배경
            pygame.draw.rect(card_surf, (*ET["skill_bg"], min(card_alpha, 230)),
                             icon_rect, border_radius=10)
            pygame.draw.rect(card_surf, (*perk["icon_color"], min(card_alpha, 180)),
                             icon_rect, 2, border_radius=10)
            # 퍽 아이콘 (SSAA)
            icon_draw_size = icon_scaled - 8
            if icon_draw_size > 4:
                self._draw_perk_icon(card_surf, perk["id"],
                                     icon_rect.x + icon_scaled // 2,
                                     icon_rect.y + icon_scaled // 2,
                                     icon_draw_size)

            # 텍스트 (오른쪽, 아이콘 + 이름만)
            text_x = icon_margin + icon_scaled + 12

            # 퍽 이름 (세로 중앙 배치)
            if self.fonts and "medium" in self.fonts:
                name_surf, _ = self.fonts["medium"].render(perk["name"], (255, 255, 255))
                if card_alpha < 255:
                    name_surf.set_alpha(card_alpha)
                name_y = (scaled_h - name_surf.get_height()) // 2
                card_surf.blit(name_surf, (text_x, name_y))

            # 카드 그리기 (스케일 보정)
            draw_x = card_x - (scaled_w - card_w) // 2
            draw_y = card_y_anim - (scaled_h - card_h) // 2
            self.screen.blit(card_surf, (int(draw_x), int(draw_y)))

            # 호버 테두리 이펙트 (카드 위에 오버레이)
            if is_hovered:
                self._draw_hover_border(int(draw_x), int(draw_y), scaled_w, scaled_h,
                                        perk["icon_color"])

        # 하단 조작 안내 (스테이지 스타일)
        if self.perk_anim_phase == "active" and self.fonts and "small" in self.fonts:
            hint_y = vertical_y + card_h + 18
            hint = "← → 선택  |  SPACE 확정"
            hint_surf, _ = self.fonts["small"].render(hint, ET["text_hint"])
            hx = SCREEN_WIDTH // 2 - hint_surf.get_width() // 2
            self.screen.blit(hint_surf, (hx, hint_y))

        # ====== 설명 박스 (호버 시 퍽 설명 표시) ======
        if self.perk_anim_phase == "active":
            desc_box_y = vertical_y + card_h + 45
            desc_box_w = total_w
            desc_box_h = 55
            desc_box_x = start_x

            desc_surf = _get_arena_surface(desc_box_w, desc_box_h)
            pygame.draw.rect(desc_surf, (*ET["card_bg"], 200),
                             (0, 0, desc_box_w, desc_box_h), border_radius=8)
            pygame.draw.rect(desc_surf, (*ET["card_border"], 150),
                             (0, 0, desc_box_w, desc_box_h), 1, border_radius=8)

            # 호버 중이면 호버 퍽, 아니면 키보드 선택 퍽 표시
            show_idx = self.hover_perk_index if self.hover_perk_index >= 0 else self.perk_selected_index
            if 0 <= show_idx < len(self.current_perk_options):
                focused_perk = self.current_perk_options[show_idx]
                fp_color = focused_perk.get("icon_color", (200, 200, 200))
                # 퍽 이름 (medium, 컬러)
                if self.fonts and "medium" in self.fonts:
                    pn_surf, _ = self.fonts["medium"].render(
                        focused_perk["name"], fp_color)
                    desc_surf.blit(pn_surf, (14, 8))
                # 퍽 설명 (small, 밝은 회색)
                if self.fonts and "small" in self.fonts:
                    pd_surf, _ = self.fonts["small"].render(
                        focused_perk["description"], (220, 215, 200))
                    desc_surf.blit(pd_surf, (14, 32))

            self.screen.blit(desc_surf, (desc_box_x, desc_box_y))

            # ====== 내 영웅 현황 패널 ======
            if self.bet_hero:
                status_y = desc_box_y + desc_box_h + 15
                panel_w = total_w
                panel_h = 360
                panel_x = start_x
                panel_surf = _get_arena_surface(panel_w, panel_h)
                pygame.draw.rect(panel_surf, (*ET["bg_panel"], 180),
                                 (0, 0, panel_w, panel_h), border_radius=10)
                pygame.draw.rect(panel_surf, (*ET["card_border"], 120),
                                 (0, 0, panel_w, panel_h), 1, border_radius=10)

                hero = self.bet_hero
                hero_id = hero["id"]
                py_cursor = 10  # 패널 내부 y 커서

                # --- 영웅 아이콘 + "영웅" 라벨 (가로 한 줄) ---
                hero_icon_size = 48
                hero_frame_w, hero_frame_h = hero_icon_size + 8, hero_icon_size + 8
                hero_frame_rect = pygame.Rect(14, py_cursor, hero_frame_w, hero_frame_h)
                # 프레임 배경
                h_color = hero.get("color", (200, 200, 200))
                pygame.draw.rect(panel_surf, (*ET["skill_bg"], 220),
                                 hero_frame_rect, border_radius=8)
                pygame.draw.rect(panel_surf, (*h_color[:3], 180),
                                 hero_frame_rect, 2, border_radius=8)
                # 영웅 캐릭터 아이콘 - Y 보정으로 시각적 중심 맞춤
                if self.hero_paddle_renderer:
                    try:
                        hero_icon_surf = _get_arena_surface(hero_icon_size, hero_icon_size)
                        _hero_b = max(3, 50 // 12)
                        _hero_y_adj = int(_hero_b * 0.75)
                        self.hero_paddle_renderer.draw_hero_paddle(
                            hero_icon_surf, hero_id,
                            hero_icon_size // 2, hero_icon_size // 2 + _hero_y_adj,
                            50, 28, facing="down", color=h_color,
                            scale_mode="preview")
                        panel_surf.blit(hero_icon_surf,
                                        (14 + 4, py_cursor + 4))
                    except Exception:
                        pygame.draw.circle(
                            panel_surf, (*h_color[:3], 200),
                            (14 + hero_frame_w // 2, py_cursor + hero_frame_h // 2), 16)
                else:
                    pygame.draw.circle(
                        panel_surf, (*h_color[:3], 200),
                        (14 + hero_frame_w // 2, py_cursor + hero_frame_h // 2), 16)

                # "영웅" 라벨 + 이름 (아이콘 오른쪽)
                hero_text_x = 14 + hero_frame_w + 12
                if self.fonts and "medium" in self.fonts:
                    hero_label_surf, _ = self.fonts["medium"].render(
                        "영웅", ET["text_subtitle"])
                    panel_surf.blit(hero_label_surf, (hero_text_x, py_cursor + 4))
                if self.fonts and "small" in self.fonts:
                    hero_name_text = f"{hero['name']}  「{hero.get('title', '')}」"
                    hn_surf, _ = self.fonts["small"].render(
                        hero_name_text, ET["gold_bright"])
                    panel_surf.blit(hn_surf, (hero_text_x, py_cursor + 28))

                # 영웅 아이콘 툴팁 rect 저장 (스크린 좌표)
                self._perk_hero_tooltip_rect = pygame.Rect(
                    panel_x + 14, status_y + py_cursor,
                    hero_frame_w, hero_frame_h)
                self._perk_hero_tooltip_name = f"{hero['name']}  「{hero.get('title', '')}」"
                self._perk_hero_tooltip_color = h_color

                py_cursor += hero_frame_h + 8

                # --- 능력치 (인게임 실제 스탯) ---
                mults = self.get_hero_perk_multipliers(hero_id)
                base_speed = 5.0
                base_paddle = 130.0
                base_dash_dist = 420.0
                base_cd = 12.5

                game_stats = [
                    ("이동속도", f"{base_speed * mults['move_speed']:.2f}",
                     base_speed * mults['move_speed'], 7.0, True),
                    ("패들크기", f"{base_paddle * mults['paddle_enlarge']:.0f}px",
                     base_paddle * mults['paddle_enlarge'], 200.0, True),
                    ("대쉬거리", f"{base_dash_dist * mults['dash_distance']:.0f}px",
                     base_dash_dist * mults['dash_distance'], 630.0, True),
                    ("대쉬후딜", "0.50초", 0.5, 1.2, False),
                    ("대쉬쿨타임", f"{base_cd * mults['dash_cooldown']:.2f}초",
                     base_cd * mults['dash_cooldown'], 15.0, False),
                ]
                # 조건부 스탯
                if mults["dash_tokens"] > 0:
                    game_stats.append(("대쉬토큰", f"+{mults['dash_tokens']}",
                                       mults['dash_tokens'], 3, True))
                if mults["skill_cooldown"] < 1.0:
                    pct = int((1.0 - mults["skill_cooldown"]) * 100)
                    game_stats.append(("스킬쿨감소", f"{pct}%", pct, 50, True))
                if mults["guard_cooldown"] < 1.0:
                    pct = int((1.0 - mults["guard_cooldown"]) * 100)
                    game_stats.append(("호위쿨감소", f"{pct}%", pct, 50, True))

                if self.fonts and "small" in self.fonts:
                    sec_stat, _ = self.fonts["small"].render(
                        "능력치", ET["text_subtitle"])
                    panel_surf.blit(sec_stat, (14, py_cursor))
                py_cursor += 18

                # 2열 레이아웃 (간격 축소)
                num_cols = 2
                col_w = (panel_w - 28) // num_cols
                stat_base_y = py_cursor
                for si, (label, val_str, val, max_h, higher_better) in enumerate(game_stats):
                    col = si % num_cols
                    row = si // num_cols
                    sx = 14 + col * col_w
                    sy = stat_base_y + row * 22

                    if self.fonts and "small" in self.fonts:
                        sl_surf, _ = self.fonts["small"].render(
                            label, ET["text_body"])
                        panel_surf.blit(sl_surf, (sx, sy))

                        sv_surf, _ = self.fonts["small"].render(
                            val_str, ET["gold_pale"])
                        # 라벨 바로 옆에 값 배치 (간격 60px)
                        panel_surf.blit(sv_surf,
                                        (sx + 72, sy))

                rows_needed = (len(game_stats) + num_cols - 1) // num_cols
                py_cursor = stat_base_y + rows_needed * 22 + 4

                # --- 구분선 ---
                pygame.draw.line(panel_surf, (*ET["card_border"], 100),
                                 (14, py_cursor), (panel_w - 14, py_cursor))
                py_cursor += 10

                # --- 보유 퍽 아이콘 ---
                owned_perks = self.hero_perks.get(hero_id, [])
                if self.fonts and "small" in self.fonts:
                    sec_label, _ = self.fonts["small"].render(
                        "보유 퍽", ET["text_subtitle"])
                    panel_surf.blit(sec_label, (14, py_cursor))
                py_cursor += 20

                perk_icon_size = 28
                perk_icon_gap = 36
                _perk_owned_tooltips = []  # 보유 퍽 툴팁용 rect 수집
                if owned_perks:
                    for pi, op in enumerate(owned_perks):
                        px = 20 + pi * perk_icon_gap
                        if px + perk_icon_size > panel_w - 10:
                            break
                        pcy = py_cursor + perk_icon_size // 2
                        # 원형 배경
                        pc = op.get("icon_color", (200, 200, 200))
                        pygame.draw.circle(
                            panel_surf, (*ET["skill_bg"], 220),
                            (px + perk_icon_size // 2, pcy),
                            perk_icon_size // 2 + 3)
                        pygame.draw.circle(
                            panel_surf, (*pc[:3], 150),
                            (px + perk_icon_size // 2, pcy),
                            perk_icon_size // 2 + 3, 2)
                        # 퍽 아이콘 (SSAA)
                        self._draw_perk_icon(
                            panel_surf, op["id"],
                            px + perk_icon_size // 2, pcy,
                            perk_icon_size - 4)
                        # 툴팁 rect 수집 (패널 좌표 → 스크린 좌표)
                        _perk_owned_tooltips.append({
                            "rect": pygame.Rect(
                                panel_x + px,
                                status_y + py_cursor,
                                perk_icon_size, perk_icon_size),
                            "name": op.get("name", "?"),
                            "desc": op.get("description", ""),
                            "color": pc,
                        })
                else:
                    if self.fonts and "small" in self.fonts:
                        none_surf, _ = self.fonts["small"].render(
                            "없음", ET["text_disabled"])
                        panel_surf.blit(none_surf, (20, py_cursor))

                py_cursor += perk_icon_size + 14

                # --- 구분선 ---
                pygame.draw.line(panel_surf, (*ET["card_border"], 100),
                                 (14, py_cursor), (panel_w - 14, py_cursor))
                py_cursor += 10

                # --- 호위무사 + 스킬 ---
                guards = self.guard_warrior_map.get(hero_id, [])
                if self.fonts and "small" in self.fonts:
                    sec_label2, _ = self.fonts["small"].render(
                        "호위무사", ET["text_subtitle"])
                    panel_surf.blit(sec_label2, (14, py_cursor))
                py_cursor += 20

                _perk_guard_tooltips = []  # 스킬 아이콘 툴팁용 rect 수집

                if guards:
                    char_surf_w, char_surf_h = 56, 48
                    frame_w, frame_h = 52, 48
                    guard_slot_h = frame_h + 8
                    for gi, guard in enumerate(guards):
                        gx = 14
                        gy = py_cursor + gi * guard_slot_h
                        g_color = guard.get("color", (150, 150, 150))

                        # 호위무사 캐릭터 이미지 (확대된 프레임)
                        frame_rect = pygame.Rect(gx, gy, frame_w, frame_h)
                        pygame.draw.rect(panel_surf, (*ET["skill_bg"], 200),
                                         frame_rect, border_radius=8)
                        pygame.draw.rect(panel_surf, (*g_color[:3], 180),
                                         frame_rect, 2, border_radius=8)

                        if self.hero_paddle_renderer:
                            try:
                                char_s = _get_arena_surface(char_surf_w, char_surf_h)
                                # Y 보정: preview 모드에서 torso가 cy-1.5b에 위치하므로
                                # 시각적 중심이 프레임 중앙보다 위쪽 → 캐릭터를 아래로 보정
                                _icon_b = max(3, 44 // 12)
                                _icon_y_adj = int(_icon_b * 0.75)
                                self.hero_paddle_renderer.draw_hero_paddle(
                                    char_s, guard["id"],
                                    char_surf_w // 2, char_surf_h // 2 + _icon_y_adj,
                                    44, 26, facing="down", color=g_color,
                                    scale_mode="preview")
                                panel_surf.blit(char_s,
                                                (gx + frame_w // 2 - char_surf_w // 2,
                                                 gy + frame_h // 2 - char_surf_h // 2))
                            except Exception:
                                pygame.draw.circle(
                                    panel_surf, (*g_color[:3], 200),
                                    (gx + frame_w // 2, gy + frame_h // 2), 16)
                        else:
                            pygame.draw.circle(
                                panel_surf, (*g_color[:3], 200),
                                (gx + frame_w // 2, gy + frame_h // 2), 16)

                        # 호위무사 아이콘 툴팁 rect 수집 (이름 숨기고 호버 시 표시)
                        guard_name = guard.get("name", "?")
                        guard_title = guard.get("title", "")
                        guard_tt_text = f"{guard_name}  「{guard_title}」" if guard_title else guard_name
                        _perk_guard_tooltips.append({
                            "rect": pygame.Rect(
                                panel_x + gx, status_y + gy,
                                frame_w, frame_h),
                            "name": guard_tt_text,
                            "desc": "호위무사",
                            "color": g_color,
                        })

                        # 호위무사 스킬 아이콘 (이름 대신 바로 옆에 큰 아이콘)
                        sk_icon_sz = 32
                        sk_x = gx + frame_w + 12
                        sk_y = gy + (frame_h - sk_icon_sz) // 2
                        try:
                            g_id = guard["id"]
                            g_skill_idx = self.hero_selected_skills.get(g_id, 0)
                            if HERO_SKILLS_AVAILABLE:
                                from downtown.hero_skills import HERO_SKILLS
                                g_skills_list = HERO_SKILLS.get(g_id, [])
                                # 주인 영웅(hero_id)이 '추가훈련' 퍽을 보유한 경우에만 호위무사 2스킬 표시
                                has_both = any(
                                    p.get("effect_type") == "guard_extra_skill"
                                    for p in self.hero_perks.get(hero_id, [])
                                )
                                skills_to_show = g_skills_list if has_both else (
                                    [g_skills_list[g_skill_idx]] if len(g_skills_list) > g_skill_idx else [])

                                for ski, skill in enumerate(skills_to_show):
                                    icon_x = sk_x + ski * (sk_icon_sz + 8)
                                    # 스킬 아이콘 배경 (확대)
                                    pygame.draw.rect(
                                        panel_surf, (*g_color[:3], 120),
                                        (icon_x, sk_y, sk_icon_sz, sk_icon_sz),
                                        border_radius=6)
                                    pygame.draw.rect(
                                        panel_surf, (*g_color[:3], 200),
                                        (icon_x, sk_y, sk_icon_sz, sk_icon_sz),
                                        1, border_radius=6)
                                    # 스킬 아이콘 이미지
                                    sk_icon = _get_hero_skill_icon(
                                        skill.skill_id, sk_icon_sz)
                                    if sk_icon:
                                        panel_surf.blit(sk_icon, (icon_x, sk_y))
                                    else:
                                        # 폴백: 이니셜
                                        if self.fonts and "small" in self.fonts:
                                            ini, _ = self.fonts["small"].render(
                                                skill.korean_name[0],
                                                (255, 255, 255))
                                            panel_surf.blit(ini,
                                                (icon_x + sk_icon_sz // 2 - ini.get_width() // 2,
                                                 sk_y + sk_icon_sz // 2 - ini.get_height() // 2))
                                    # 스킬 아이콘 툴팁 (스킬 이름 + 설명)
                                    _perk_guard_tooltips.append({
                                        "rect": pygame.Rect(
                                            panel_x + icon_x,
                                            status_y + sk_y,
                                            sk_icon_sz, sk_icon_sz),
                                        "name": skill.korean_name,
                                        "desc": skill.description,
                                        "color": g_color,
                                    })
                        except Exception:
                            pass
                else:
                    if self.fonts and "small" in self.fonts:
                        none_surf2, _ = self.fonts["small"].render(
                            "없음", ET["text_disabled"])
                        panel_surf.blit(none_surf2, (20, py_cursor))

                self.screen.blit(panel_surf, (panel_x, status_y))

                # --- 툴팁 렌더링 (패널 위에 오버레이) ---
                mpos = pygame.mouse.get_pos()
                tooltip_shown = False

                # 영웅 아이콘 툴팁
                if (hasattr(self, '_perk_hero_tooltip_rect') and
                        self._perk_hero_tooltip_rect.collidepoint(mpos)):
                    tt_name = getattr(self, '_perk_hero_tooltip_name', '?')
                    tt_color = getattr(self, '_perk_hero_tooltip_color', (200, 200, 200))
                    tt_w, tt_h = 260, 32
                    tt_x = min(self._perk_hero_tooltip_rect.right + 5,
                               SCREEN_WIDTH - tt_w - 5)
                    tt_y = self._perk_hero_tooltip_rect.y
                    tt_surf = _get_arena_surface(tt_w, tt_h)
                    pygame.draw.rect(tt_surf, (30, 28, 22, 240),
                                     (0, 0, tt_w, tt_h), border_radius=6)
                    pygame.draw.rect(tt_surf, (*tt_color[:3], 180),
                                     (0, 0, tt_w, tt_h), 1, border_radius=6)
                    if self.fonts and "small" in self.fonts:
                        tn_s, _ = self.fonts["small"].render(
                            tt_name, ET["gold_bright"])
                        tt_surf.blit(tn_s, (8, 8))
                    self.screen.blit(tt_surf, (tt_x, tt_y))
                    tooltip_shown = True

                # 보유 퍽 아이콘 툴팁
                if not tooltip_shown and _perk_owned_tooltips:
                    for tt in _perk_owned_tooltips:
                        if tt["rect"].collidepoint(mpos):
                            tt_w, tt_h = 240, 48
                            tt_x = min(tt["rect"].x + tt["rect"].w + 5,
                                        SCREEN_WIDTH - tt_w - 5)
                            tt_y = tt["rect"].y - 10
                            tt_surf = _get_arena_surface(tt_w, tt_h)
                            pygame.draw.rect(tt_surf, (30, 28, 22, 240),
                                             (0, 0, tt_w, tt_h), border_radius=6)
                            pygame.draw.rect(tt_surf, (*tt["color"][:3], 180),
                                             (0, 0, tt_w, tt_h), 1, border_radius=6)
                            if self.fonts and "small" in self.fonts:
                                tn_s, _ = self.fonts["small"].render(
                                    tt["name"], tt["color"])
                                tt_surf.blit(tn_s, (8, 6))
                                td_s, _ = self.fonts["small"].render(
                                    tt["desc"], (200, 195, 180))
                                tt_surf.blit(td_s, (8, 26))
                            self.screen.blit(tt_surf, (tt_x, tt_y))
                            tooltip_shown = True
                            break

                # 호위무사/스킬 아이콘 툴팁
                if not tooltip_shown and _perk_guard_tooltips:
                    for tt in _perk_guard_tooltips:
                        if tt["rect"].collidepoint(mpos):
                            tt_w, tt_h = 220, 48
                            tt_x = min(tt["rect"].x + tt["rect"].w + 5,
                                        SCREEN_WIDTH - tt_w - 5)
                            tt_y = tt["rect"].y - 5
                            tt_surf = _get_arena_surface(tt_w, tt_h)
                            pygame.draw.rect(tt_surf, (30, 28, 22, 240),
                                             (0, 0, tt_w, tt_h), border_radius=6)
                            pygame.draw.rect(tt_surf, (*tt["color"][:3], 180),
                                             (0, 0, tt_w, tt_h), 1, border_radius=6)
                            if self.fonts and "small" in self.fonts:
                                tn_s, _ = self.fonts["small"].render(
                                    tt["name"], tt["color"])
                                tt_surf.blit(tn_s, (8, 6))
                                td_s, _ = self.fonts["small"].render(
                                    tt["desc"], (200, 195, 180))
                                tt_surf.blit(td_s, (8, 26))
                            self.screen.blit(tt_surf, (tt_x, tt_y))
                            break

    def _start_bracket_animation(self):
        """대진표 진출 애니메이션 시작"""
        self.bracket_anim_timer = 0.0
        self.bracket_anim_phase = 0  # 0: 패자 X 표시, 1: 승자 이동, 2: 대기 후 VS_PREVIEW 전환
        self.bracket_anim_progress = 0.0

        # 현재 라운드의 완료된 매치와 승자 수집
        current_matches = self.matches[self.current_round]
        self.bracket_anim_completed_matches = [m for m in current_matches if m.completed]
        self.bracket_anim_advancing_winners = [m.winner for m in self.bracket_anim_completed_matches if m.winner]

        # 다음 라운드 정보 저장
        if self.current_round == TournamentRound.QUARTER_FINAL:
            self.bracket_anim_next_round = TournamentRound.SEMI_FINAL
        elif self.current_round == TournamentRound.SEMI_FINAL:
            self.bracket_anim_next_round = TournamentRound.FINAL
        else:
            self.bracket_anim_next_round = None

        # 순차 X 애니메이션 상태
        self.bracket_anim_x_delay = 0.6       # 매치 간 딜레이 (초)
        self.bracket_anim_x_duration = 0.5    # 개별 X 애니메이션 시간 (초)
        self.bracket_anim_x_sound_played = set()

        self.bracket_anim_auto_battle = True
        self.state = TournamentState.BRACKET_ANIMATION

    def _update_bracket_animation(self, dt: float):
        """대진표 애니메이션 업데이트"""
        self.bracket_anim_timer += dt

        if self.bracket_anim_phase == 0:
            # 페이즈 0: 왼쪽부터 순차적으로 X 표시
            num = len(self.bracket_anim_completed_matches)
            delay = self.bracket_anim_x_delay
            x_dur = self.bracket_anim_x_duration
            total_phase0 = num * delay + x_dur + 0.6

            self.bracket_anim_progress = min(1.0, self.bracket_anim_timer / total_phase0)

            # 각 매치별 사운드 + 플로팅 텍스트 트리거
            for i, match in enumerate(self.bracket_anim_completed_matches):
                x_start = i * delay
                # X 시작 시 사운드 재생
                if self.bracket_anim_timer >= x_start and i not in self.bracket_anim_x_sound_played:
                    self.bracket_anim_x_sound_played.add(i)
                    self._play_bracket_sound("swing", 0.5)

            if self.bracket_anim_timer >= total_phase0:
                self.bracket_anim_phase = 1
                self.bracket_anim_timer = 0.0
                self.bracket_anim_progress = 0.0

        elif self.bracket_anim_phase == 1:
            # 페이즈 1: 승자 캐릭터 이동 애니메이션
            phase_duration = 1.5
            self.bracket_anim_progress = min(1.0, self.bracket_anim_timer / phase_duration)
            if self.bracket_anim_timer >= phase_duration:
                self.bracket_anim_phase = 2
                self.bracket_anim_timer = 0.0
                self.bracket_anim_progress = 0.0
                # 다음 라운드로 진출 (매치 생성)
                self._advance_to_next_round()
                # 배팅한 영웅이 포함된 경기 자동 선택
                self._prepare_next_match()

        elif self.bracket_anim_phase == 2:
            # 페이즈 2: 짧은 대기 후 전환
            wait_time = 0.3
            if self.bracket_anim_timer >= wait_time:
                self.bracket_anim_phase = 0
                self.bracket_anim_progress = 0.0
                self.bracket_anim_timer = 0.0

                # AI 호위무사를 1명으로 축소 (4강/결승)
                if self.bet_hero and self.current_round in (TournamentRound.SEMI_FINAL, TournamentRound.FINAL):
                    self._trim_all_ai_guards()

                # 호위무사 선택은 이미 퍽 선택 전에 완료됨 → 바로 VS_PREVIEW
                self._start_vs_preview(show_buttons=True)

    def _draw_bracket_animation(self):
        """대진표 진출 애니메이션 그리기"""
        # 배경
        self.screen.fill(ET["bg_dark"])
        self._draw_papyrus_bg()

        # 라운드 진출 타이틀
        if self.fonts and "large" in self.fonts:
            round_name = ""
            if self.bracket_anim_next_round == TournamentRound.SEMI_FINAL:
                round_name = "4강"
            elif self.bracket_anim_next_round == TournamentRound.FINAL:
                round_name = "결승"

            title = f"{round_name} 진출!"
            # 타이틀 펄스 효과
            pulse = abs(_sin(self.animation_timer * 3)) * 0.3 + 0.7
            gold_color = (int(ET["gold_bright"][0] * pulse), int(ET["gold_bright"][1] * pulse), int(ET["gold_bright"][2] * pulse))
            surf, _ = self.fonts["large"].render(title, gold_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 30))

        # 대진표 그리기 (애니메이션 효과 포함)
        self._draw_animated_bracket()

        # 진행 표시
        if self.fonts and "small" in self.fonts:
            if self.bracket_anim_phase < 2:
                hint = "잠시 후 다음 매치가 시작됩니다..."
                alpha = int(abs(_sin(self.animation_timer * 2)) * 155 + 100)
                surf, _ = self.fonts["small"].render(hint, (alpha, int(alpha * 0.9), int(alpha * 0.7)))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 700))

    def _draw_guard_notification(self):
        """호위무사 생포 알림 애니메이션"""
        guard = self.guard_notify_hero
        owner = self.guard_notify_owner
        if not guard or not owner:
            return

        progress = getattr(self, 'guard_notify_progress', 0.0)  # 0.0 ~ 1.0 over 2.5s

        # 배경
        self.screen.fill(ET["bg_dark"])

        # 반투명 다크 오버레이 (페이드인)
        overlay_alpha = int(min(180, 220 * min(1.0, progress * 3)))
        overlay = _get_arena_fullscreen()
        overlay.fill((*ET["overlay_warm"], overlay_alpha))
        self.screen.blit(overlay, (0, 0))

        center_x = SCREEN_WIDTH // 2

        # 호위무사 영웅 이미지 (아래에서 슬라이드 업)
        target_y = SCREEN_HEIGHT // 2 - 30
        start_y = SCREEN_HEIGHT // 2 + 100
        slide_progress = self._ease_in_out(min(1.0, progress * 2.5))
        hero_y = int(start_y + (target_y - start_y) * slide_progress)

        # 글로우 효과 (호위무사 색상) - Y 보정으로 캐릭터 시각적 중심에 맞춤
        guard_color = guard.get("color", (150, 150, 150))
        glow_alpha = int(60 + abs(_sin(self.animation_timer * 3)) * 40)
        glow_radius = 80
        intro_b = max(3, 120 // 12)  # preview 모드 블록 크기
        intro_glow_adj = int(intro_b * 0.75)
        glow_surf = _get_arena_surface(glow_radius * 2, glow_radius * 2)
        pygame.draw.circle(glow_surf, (*guard_color, glow_alpha), (glow_radius, glow_radius), glow_radius)
        self.screen.blit(glow_surf, (center_x - glow_radius, hero_y - glow_radius - intro_glow_adj))

        # 영웅 캐릭터 이미지
        if self.hero_paddle_renderer:
            guard_id = guard.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, guard_id, center_x, hero_y, 120, 84,
                facing="down", color=guard_color, scale_mode="preview"
            )
        else:
            pygame.draw.circle(self.screen, guard_color, (center_x, hero_y), 40)
            pygame.draw.circle(self.screen, (255, 255, 255), (center_x, hero_y), 40, 2)

        # 텍스트 (페이드인, progress > 0.2)
        text_alpha = max(0, min(255, int((progress - 0.2) * 4 * 255)))

        if text_alpha > 0 and self.fonts:
            guard_name = guard.get("name", "???")
            guard_title = guard.get("title", "")

            # 밝기 보정
            brightness = sum(guard_color) / 3
            name_color = guard_color if brightness > 80 else (
                min(255, guard_color[0] + 100),
                min(255, guard_color[1] + 100),
                min(255, guard_color[2] + 100)
            )

            # 이름 (큰 글씨)
            if "large" in self.fonts:
                surf, _ = self.fonts["large"].render(guard_name, name_color)
                alpha_surf = _get_arena_surface(*surf.get_size())
                alpha_surf.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, hero_y - 80))

            # 칭호 (작은 글씨)
            if "small" in self.fonts and guard_title:
                surf, _ = self.fonts["small"].render(guard_title, ET["text_subtitle"])
                alpha_surf = _get_arena_surface(*surf.get_size())
                alpha_surf.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, hero_y + 60))

            # 메인 알림 메시지
            if "medium" in self.fonts:
                msg1 = f"{guard_name}을(를) 생포했습니다!"
                gold_color = ET["gold_bright"]

                surf1, _ = self.fonts["medium"].render(msg1, gold_color)
                alpha_surf1 = _get_arena_surface(*surf1.get_size())
                alpha_surf1.fill((255, 255, 255, text_alpha))
                surf1.blit(alpha_surf1, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf1, (center_x - surf1.get_width() // 2, hero_y + 100))

            # 호위무사 카운트
            if "small" in self.fonts and self.guard_notify_total > 0:
                count_msg = f"현재 호위무사: {self.guard_notify_total}명"
                surf, _ = self.fonts["small"].render(count_msg, ET["text_body"])
                alpha_surf = _get_arena_surface(*surf.get_size())
                alpha_surf.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, hero_y + 165))

        # 장식 파티클 (궤도 도는 금색 스파크)
        if progress > 0.3:
            particle_count = int((progress - 0.3) * 10)
            for i in range(min(particle_count, 6)):
                angle = self.animation_timer * 2 + i * (math.pi * 2 / 6)
                dist = 100 + _sin(self.animation_timer * 3 + i) * 20
                px = center_x + int(_cos(angle) * dist)
                py = hero_y + int(_sin(angle) * dist * 0.6)
                spark_alpha = int(100 + abs(_sin(self.animation_timer * 5 + i)) * 100)
                spark_surf = _get_arena_surface(8, 8)
                pygame.draw.circle(spark_surf, (*ET["gold_bright"], spark_alpha), (4, 4), 3)
                self.screen.blit(spark_surf, (px - 4, py - 4))

    # ================================================================
    # 결승 호위무사 선택 시스템
    # ================================================================
    _GUARD_SKILL_NAMES = {
        "mugen": "달빛베기", "kraken": "촉수휘감기", "chronos": "중력제어",
        "onimaru": "지옥의 불꽃", "maria": "인형조종", "ignis": "드래곤 브레스",
        "gear": "스팀배리어", "kurokage": "그림자분신",
    }

    def _start_guard_select(self):
        """호위무사 선택 화면 시작 (매 라운드 진출 시)"""
        bet_id = self.bet_hero["id"] if self.bet_hero else ""
        guards = self.guard_warrior_map.get(bet_id, [])

        # 재소집령으로 복귀한 호위무사는 선택 후보에서 제외 (자동 유지)
        recalled = self.recalled_guard_map.get(bet_id)
        if recalled:
            selectable = [g for g in guards if g.get("id") != recalled.get("id")]
        else:
            selectable = list(guards)

        # 선택 가능 후보가 1명 이하면 선택 화면 건너뛰기
        if len(selectable) <= 1:
            print(f"[Guard] 재소집령 복귀 호위무사 보존 → 선택 화면 생략 "
                  f"(총 {len(guards)}명, 선택 가능 {len(selectable)}명)")
            self._start_perk_select()
            return

        self.guard_select_guards = list(selectable)
        self.guard_select_hover = -1
        self.guard_select_chosen = -1
        self.guard_select_timer = 0.0
        self.guard_select_skill_hover = None
        self._guard_skill_icon_rects = []
        # 기존(index 0) vs 신규(마지막 = 방금 생포된 호위무사) 구분
        self.guard_select_new_idx = len(selectable) - 1 if selectable else 0
        self.guard_select_particles = []
        # 경고 확인 다이얼로그 상태
        self.guard_confirm_showing = False
        self.guard_confirm_index = -1
        self.guard_confirm_selected = 0  # 0 = 예, 1 = 아니오
        # 인라인 스킬 룰렛 상태 초기화
        self._guard_select_anim_phase = None
        # 초기 파티클
        for _ in range(30):
            self.guard_select_particles.append({
                'x': random.uniform(0, SCREEN_WIDTH),
                'y': random.uniform(0, SCREEN_HEIGHT),
                'vx': random.uniform(-0.8, 0.8),
                'vy': random.uniform(-1.5, -0.3),
                'size': random.uniform(1.5, 4),
                'alpha': random.randint(80, 180),
                'color': random.choice([ET["gold_pale"], ET["turquoise_light"],
                                        ET["sand"], ET["lapis_light"]])
            })
        self.state = TournamentState.GUARD_SELECT
        print(f"[Guard] 호위무사 선택 시작 (후보 {len(selectable)}명: "
              f"{[g['name'] for g in selectable]}, 복귀 호위무사 자동유지: "
              f"{recalled['name'] if recalled else '없음'})")

    def _trim_all_ai_guards(self):
        """모든 AI 영웅 호위무사를 1명으로 랜덤 축소 (bet_hero 제외, 재소집령 복귀 호위무사 보존)"""
        if not self.bet_hero:
            return
        bet_id = self.bet_hero["id"]
        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            for hero in [match.hero1, match.hero2]:
                if not hero or hero["id"] == bet_id:
                    continue
                hero_id = hero["id"]
                guards = self.guard_warrior_map.get(hero_id, [])
                if len(guards) >= 2:
                    # 재소집령 복귀 호위무사가 있으면 보존
                    recalled = self.recalled_guard_map.get(hero_id)
                    if recalled:
                        non_recalled = [g for g in guards if g.get("id") != recalled.get("id")]
                        if non_recalled:
                            chosen = random.choice(non_recalled)
                            self.guard_warrior_map[hero_id] = [chosen, recalled]
                        else:
                            self.guard_warrior_map[hero_id] = [recalled]
                        print(f"[Guard] AI 호위무사 축소 (복귀 보존): {hero['name']} → "
                              f"{[g['name'] for g in self.guard_warrior_map[hero_id]]}")
                    else:
                        chosen = random.choice(guards)
                        self.guard_warrior_map[hero_id] = [chosen]
                        print(f"[Guard] AI 호위무사 축소: {hero['name']} → {chosen['name']}")

    def _try_guard_select(self, index: int):
        """호위무사 선택 시도 - 신규 선택 시 경고 다이얼로그 표시"""
        new_idx = getattr(self, 'guard_select_new_idx', -1)
        if index == new_idx:
            # 신규 호위무사 선택 → 경고 다이얼로그 표시
            self.guard_confirm_showing = True
            self.guard_confirm_index = index
            self.guard_confirm_selected = 1  # 기본값 '아니오'
        else:
            # 기존 호위무사 유지 → 바로 확정
            self._confirm_guard_select(index)

    def _confirm_guard_select(self, index: int):
        """호위무사 선택 확정"""
        guards = getattr(self, 'guard_select_guards', [])
        if index < 0 or index >= len(guards):
            return
        _load_button_click_sound()
        if _button_click_sound:
            _button_click_sound.play()
        selected = guards[index]
        bet_id = self.bet_hero["id"] if self.bet_hero else ""
        new_idx = getattr(self, 'guard_select_new_idx', len(guards) - 1)

        # 선택한 호위무사만 남기기 (교체된 기존 호위무사만 기록)
        # 신규 포획 호위무사(new_idx)를 거절한 경우는 기록하지 않음
        # (한 번도 실전 투입되지 않은 호위무사는 "교체당한" 것이 아님)
        dropped_guards = [g for i, g in enumerate(guards) if i != index]
        for i, g in enumerate(guards):
            if i == index:
                continue
            if i != new_idx and g not in self.former_guards:
                self.former_guards.append(g)
        self.guard_warrior_map[bet_id] = [selected]

        # 재소집령으로 복귀한 호위무사는 선택과 무관하게 유지
        recalled = self.recalled_guard_map.get(bet_id)
        if recalled and recalled.get("id") != selected.get("id"):
            self.guard_warrior_map[bet_id].append(recalled)
            # 복귀 호위무사가 former_guards에 추가됐으면 제거
            if recalled in self.former_guards:
                self.former_guards.remove(recalled)
            print(f"[Guard] 재소집령 복귀 호위무사 '{recalled['name']}' 자동 유지 "
                  f"(총 {len(self.guard_warrior_map[bet_id])}명)")

        self.guard_select_chosen = index
        print(f"[Guard] 호위무사 선택 완료: {selected['name']} (탈락: {[g['name'] for g in dropped_guards]})")

        # 신규 호위무사 선택 시 → 같은 화면 하단에서 인라인 스킬 룰렛
        if index == new_idx:
            self.hero_selected_skills[selected["id"]] = random.randint(0, 1)
            print(f"[Guard] 신규 호위무사 스킬 랜덤 배정: {selected['name']} "
                  f"(스킬 인덱스: {self.hero_selected_skills[selected['id']]})")
            # 인라인 스킬 룰렛 시작 (GUARD_SELECT 화면 유지)
            self._guard_select_anim_phase = "skill_rolling"
            self.skill_reveal_timer = 0.0
            self.skill_reveal_phase = "rolling"
            self.skill_reveal_target = selected["id"]
            self.skill_reveal_result = self.hero_selected_skills[selected["id"]]
            self._skill_reveal_last_tick_idx = -1
            self.skill_reveal_selected_timer = 0.0
            self._skill_reveal_particles = []
            return
        else:
            print(f"[Guard] 기존 호위무사 유지: {selected['name']} (스킬 유지)")

        # 퍽 선택 화면으로 전환 (호위무사 선택 → 퍽 선택 → 대진표)
        self._start_perk_select()

    def _draw_guard_select(self):
        """결승 호위무사 선택 화면 그리기 (고급 UI + 스킬 아이콘/툴팁)"""
        guards = getattr(self, 'guard_select_guards', [])
        if len(guards) < 2:
            self._start_vs_preview(show_buttons=True)
            return

        timer = self.guard_select_timer
        hover = getattr(self, 'guard_select_hover', -1)
        chosen = getattr(self, 'guard_select_chosen', -1)
        center_x = SCREEN_WIDTH // 2

        # 스킬 아이콘 rect 추적 (호버/툴팁용) - 매 프레임 리빌드
        self._guard_skill_icon_rects = []

        # === 배경 ===
        self.screen.fill(ET["bg_dark"])

        # 방사형 빛줄기 (어두운 금색)
        if timer > 0.3:
            ray_alpha = int(15 * min(1.0, (timer - 0.3) * 2))
            ray_surf = _get_arena_fullscreen()
            for i in range(8):
                angle = (i / 8) * math.pi * 2 + self.animation_timer * 0.15
                ex = center_x + int(_cos(angle) * 500)
                ey = 380 + int(_sin(angle) * 500)
                pygame.draw.line(ray_surf, (*ET["gold_medium"], ray_alpha),
                                 (center_x, 380), (ex, ey), 2)
            self.screen.blit(ray_surf, (0, 0))

        # 파티클
        for p in self.guard_select_particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['alpha'] = max(0, p['alpha'] - 0.3)
            if p['alpha'] > 0:
                sz = max(1, int(p['size']))
                ps = _get_arena_surface(sz * 2, sz * 2)
                pygame.draw.circle(ps, (*p['color'], int(p['alpha'])), (sz, sz), sz)
                self.screen.blit(ps, (int(p['x']) - sz, int(p['y']) - sz))
        # 파티클 재생성
        self.guard_select_particles[:] = [p for p in self.guard_select_particles if p['alpha'] > 0]
        while len(self.guard_select_particles) < 20:
            self.guard_select_particles.append({
                'x': random.uniform(0, SCREEN_WIDTH),
                'y': random.uniform(SCREEN_HEIGHT * 0.8, SCREEN_HEIGHT),
                'vx': random.uniform(-0.8, 0.8),
                'vy': random.uniform(-1.5, -0.3),
                'size': random.uniform(1.5, 4),
                'alpha': random.randint(80, 180),
                'color': random.choice([ET["gold_pale"], ET["turquoise_light"],
                                        ET["sand"], ET["lapis_light"]])
            })

        # === 타이틀 텍스트 ===
        title_fade = min(1.0, timer * 2.0)
        if title_fade > 0:
            # 메인 타이틀 (라운드별 동적)
            # 다음 라운드 기준 텍스트 (현재 라운드 승리 후 선택이므로)
            if self.current_round == TournamentRound.SEMI_FINAL:
                title_text = "결승전 호위무사 선택"
            else:
                title_text = "4강 호위무사 선택"
            self._draw_egyptian_title(title_text, 50)

            # 서브 타이틀
            if "medium" in self.fonts:
                if self.current_round == TournamentRound.SEMI_FINAL:
                    sub = "결승전에 데려갈 호위무사를 선택하세요"
                else:
                    sub = "4강에 데려갈 호위무사를 선택하세요"
                surf2, _ = self.fonts["medium"].render(sub, ET["text_subtitle"])
                alpha_s2 = _get_arena_surface(*surf2.get_size())
                alpha_s2.fill((255, 255, 255, int(255 * title_fade * 0.7)))
                surf2.blit(alpha_s2, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf2, (center_x - surf2.get_width() // 2, 100))

            # 경고 텍스트
            if "small" in self.fonts:
                warn = "전장에서는 오직 한명의 호위무사만 데려갈 수 있습니다."
                warn_surf, _ = self.fonts["small"].render(warn, ET["carnelian_light"])
                alpha_w = _get_arena_surface(*warn_surf.get_size())
                alpha_w.fill((255, 255, 255, int(255 * title_fade * 0.6)))
                warn_surf.blit(alpha_w, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(warn_surf, (center_x - warn_surf.get_width() // 2, 122))

        # 구분선
        if timer > 0.2:
            self._draw_egyptian_separator(145)

        # === VS 텍스트 (중앙) ===
        if self.fonts and "large" in self.fonts and timer > 0.4:
            vs_alpha = int(120 + 60 * abs(_sin(self.animation_timer * 2)))
            vs_surf, _ = self.fonts["large"].render("VS", (vs_alpha, int(vs_alpha * 0.3), int(vs_alpha * 0.15)))
            self.screen.blit(vs_surf, (center_x - vs_surf.get_width() // 2, 360))

        # === 영웅 카드 2장 ===
        card_w, card_h = 220, 290
        gap = 60
        card_positions = [
            (center_x - gap // 2 - card_w, 175),   # 왼쪽
            (center_x + gap // 2, 175),              # 오른쪽
        ]

        for idx, guard in enumerate(guards[:2]):
            cx, cy = card_positions[idx]
            is_hover = (hover == idx)
            is_chosen = (chosen == idx)

            # 카드 등장 애니메이션
            if idx == 0:
                slide = min(1.0, timer * 2.0)
                offset_x = int(-300 * (1 - self._ease_in_out(slide)))
            else:
                slide = min(1.0, max(0, timer - 0.15) * 2.0)
                offset_x = int(300 * (1 - self._ease_in_out(slide)))

            draw_x = cx + offset_x
            draw_y = cy

            g_color = guard.get("color", (150, 150, 150))
            g_name = guard.get("name", "???")
            g_title = guard.get("title", "")
            g_id = guard.get("id", "")

            # 밝기 보정
            brightness = sum(g_color) / 3
            bright_color = g_color if brightness > 80 else (
                min(255, g_color[0] + 80),
                min(255, g_color[1] + 80),
                min(255, g_color[2] + 80)
            )

            # 카드 배경 (호버/선택 시 강조)
            card_surf = _get_arena_surface(card_w, card_h)

            if is_chosen:
                card_surf.fill((*ET["card_bg_hover"], 220))
                border_color = ET["gold_bright"]
                border_w = 3
            elif is_hover:
                pulse = 0.7 + 0.3 * abs(_sin(self.animation_timer * 4))
                card_surf.fill((*ET["card_bg"], int(220 * pulse)))
                border_color = bright_color
                border_w = 2
            else:
                card_surf.fill((*ET["card_bg"], 200))
                border_color = ET["card_border"]
                border_w = 1

            pygame.draw.rect(card_surf, (*border_color, 200),
                             (0, 0, card_w, card_h), border_w, border_radius=8)
            self.screen.blit(card_surf, (draw_x, draw_y))

            # "기존"/"신규" 뱃지
            new_idx = getattr(self, 'guard_select_new_idx', 1)
            if self.fonts and "small" in self.fonts and slide > 0.5:
                if idx == new_idx:
                    badge_text, badge_color = "신규", ET["gold_pale"]
                else:
                    badge_text, badge_color = "기존", ET["lapis_light"]
                badge_surf, _ = self.fonts["small"].render(badge_text, badge_color)
                badge_bg = _get_arena_surface(badge_surf.get_width() + 10, badge_surf.get_height() + 4)
                badge_bg.fill((0, 0, 0, 160))
                pygame.draw.rect(badge_bg, (*badge_color, 120),
                                 (0, 0, badge_bg.get_width(), badge_bg.get_height()),
                                 1, border_radius=4)
                bx = draw_x + card_w - badge_bg.get_width() - 6
                by = draw_y + 6
                self.screen.blit(badge_bg, (bx, by))
                self.screen.blit(badge_surf, (bx + 5, by + 2))

            # 호버 시 글로우
            if is_hover or is_chosen:
                glow_color = (255, 215, 80) if is_chosen else bright_color
                glow_a = int(40 + 20 * abs(_sin(self.animation_timer * 3)))
                glow_surf = _get_arena_surface(card_w + 16, card_h + 16)
                pygame.draw.rect(glow_surf, (*glow_color, glow_a),
                                 (0, 0, card_w + 16, card_h + 16), border_radius=12)
                self.screen.blit(glow_surf, (draw_x - 8, draw_y - 8))

            # 영웅 캐릭터 이미지 (카드 상단)
            hero_cx = draw_x + card_w // 2
            hero_cy = draw_y + 90

            # 캐릭터 뒤 글로우 - Y 보정으로 캐릭터 시각적 중심에 맞춤
            card_b = max(3, 100 // 12)  # preview 모드 블록 크기 (w=100)
            card_glow_adj = int(card_b * 0.75)
            glow_r = 60
            glow_surf2 = _get_arena_surface(glow_r * 2, glow_r * 2)
            g_alpha = int(50 + 25 * abs(_sin(self.animation_timer * 2 + idx)))
            pygame.draw.circle(glow_surf2, (*g_color, g_alpha), (glow_r, glow_r), glow_r)
            self.screen.blit(glow_surf2, (hero_cx - glow_r, hero_cy - glow_r - card_glow_adj))

            if self.hero_paddle_renderer:
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen, g_id, hero_cx, hero_cy, 100, 70,
                    facing="down", color=g_color, scale_mode="preview"
                )
            else:
                pygame.draw.circle(self.screen, g_color, (hero_cx, hero_cy), 35)
                pygame.draw.circle(self.screen, (255, 255, 255), (hero_cx, hero_cy), 35, 2)

            # 이름 (큰 글씨)
            if self.fonts and "medium" in self.fonts:
                name_surf, _ = self.fonts["medium"].render(g_name, bright_color)
                self.screen.blit(name_surf, (hero_cx - name_surf.get_width() // 2,
                                              draw_y + 155))

            # 칭호 (작은 글씨)
            if self.fonts and "small" in self.fonts and g_title:
                title_surf, _ = self.fonts["small"].render(g_title, (160, 160, 180))
                self.screen.blit(title_surf, (hero_cx - title_surf.get_width() // 2,
                                               draw_y + 183))

            # === 스킬 아이콘 ===
            hero_skills = get_hero_skills(g_id) if HERO_SKILLS_AVAILABLE else []
            icon_sz = 36
            new_idx = getattr(self, 'guard_select_new_idx', 1)
            is_existing = (idx != new_idx)

            # 기존 호위무사: 선택된 스킬 1개만 / 신규: 2개 모두
            if is_existing:
                selected_si = self.hero_selected_skills.get(g_id, 0)
                display_skills = [hero_skills[selected_si]] if selected_si < len(hero_skills) else hero_skills[:1]
            else:
                display_skills = hero_skills[:2]

            num_skills = len(display_skills)
            # 아이콘 + 이름을 세로 배치 (겹침 방지)
            skill_slot_w = 80  # 각 스킬 슬롯 너비
            skill_slot_gap = 10
            slots_total_w = num_skills * skill_slot_w + max(0, num_skills - 1) * skill_slot_gap
            slots_start_x = draw_x + (card_w - slots_total_w) // 2
            icons_y = draw_y + 212

            # 라벨
            if self.fonts and "small" in self.fonts:
                lbl_text = "장착 스킬" if is_existing else "보유 스킬"
                lbl_surf, _ = self.fonts["small"].render(lbl_text, ET["text_hint"])
                self.screen.blit(lbl_surf, (hero_cx - lbl_surf.get_width() // 2, icons_y - 16))

            for si in range(num_skills):
                skill = display_skills[si]
                slot_x = slots_start_x + si * (skill_slot_w + skill_slot_gap)
                ix = slot_x + (skill_slot_w - icon_sz) // 2  # 아이콘 중앙 정렬
                iy = icons_y

                # 슬롯 배경 (필러 UI 동일)
                slot_bg = _get_arena_surface(icon_sz, icon_sz)
                slot_bg.fill((0, 0, 0, 120))
                self.screen.blit(slot_bg, (ix, iy))

                # 스킬 아이콘 (32px → icon_sz로 스케일)
                icon_surface = _get_hero_skill_icon(skill.skill_id, icon_sz)
                if icon_surface:
                    self.screen.blit(icon_surface, (ix, iy))

                # 테두리 (영웅 색상)
                border_surf = _get_arena_surface(icon_sz + 4, icon_sz + 4)
                pygame.draw.rect(border_surf, (*bright_color, 160),
                                 (0, 0, icon_sz + 4, icon_sz + 4), 2, border_radius=3)
                self.screen.blit(border_surf, (ix - 2, iy - 2))

                # 스킬 이름 (슬롯 중앙 기준으로 아이콘 아래)
                if self.fonts and "small" in self.fonts:
                    sk_name = skill.korean_name if skill.korean_name else "?"
                    if len(sk_name) > 5:
                        sk_name = sk_name[:4] + ".."
                    sn_surf, _ = self.fonts["small"].render(sk_name, ET["text_body"])
                    self.screen.blit(sn_surf, (slot_x + skill_slot_w // 2 - sn_surf.get_width() // 2,
                                                iy + icon_sz + 3))

                # (스킬 호버/툴팁 비활성화 - 획득 전 정보 비공개)

            # (능력치 바 제거 - 스킬 룰렛 공간 확보)

        # === 하단 안내 텍스트 (스킬 룰렛 중에는 숨김) ===
        if not getattr(self, '_guard_select_anim_phase', None):
            if self.fonts and "small" in self.fonts and timer > 0.6:
                hint_alpha = int(120 + 80 * abs(_sin(self.animation_timer * 2)))
                hint = "클릭 또는 ←→ 키로 선택"
                hint_surf, _ = self.fonts["small"].render(hint, (hint_alpha, int(hint_alpha * 0.85), int(hint_alpha * 0.65)))
                self.screen.blit(hint_surf, (center_x - hint_surf.get_width() // 2, 620))

            # 라운드 표기 (다음 라운드 기준)
            if self.fonts and "small" in self.fonts:
                if self.current_round == TournamentRound.SEMI_FINAL:
                    round_text = "FINAL"
                else:
                    round_text = "SEMI FINAL"
                rs, _ = self.fonts["small"].render(round_text, ET["gold_medium"])
                self.screen.blit(rs, (center_x - rs.get_width() // 2, 650))

        # 스킬 툴팁 비활성화 (획득 전 정보 비공개)

        # === 인라인 스킬 룰렛 (신규 호위무사 선택 후) ===
        guard_anim_phase = getattr(self, '_guard_select_anim_phase', None)
        if guard_anim_phase in ("skill_rolling", "skill_selected"):
            self._draw_inline_skill_roulette(base_y=470)

        # === 경고 확인 다이얼로그 (최상위 오버레이) ===
        if getattr(self, 'guard_confirm_showing', False):
            self._draw_guard_confirm_dialog()

    def _draw_guard_confirm_dialog(self):
        """신규 호위무사 선택 시 경고 확인 다이얼로그"""
        # 어두운 오버레이
        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 160))
        self.screen.blit(overlay, (0, 0))

        dialog_w, dialog_h = 420, 200
        cx = SCREEN_WIDTH // 2
        cy = SCREEN_HEIGHT // 2
        dx = cx - dialog_w // 2
        dy = cy - dialog_h // 2

        # 다이얼로그 배경 패널
        panel_surf = _get_arena_surface(dialog_w, dialog_h)
        panel_surf.fill((*ET["bg_panel"], 240))
        pygame.draw.rect(panel_surf, ET["gold_medium"], (0, 0, dialog_w, dialog_h), 2, border_radius=8)
        self.screen.blit(panel_surf, (dx, dy))

        if not self.fonts:
            return

        # 제목: ⚠ 경고
        if "medium" in self.fonts:
            title_surf, _ = self.fonts["medium"].render("경고", ET["carnelian_light"])
            self.screen.blit(title_surf, (cx - title_surf.get_width() // 2, dy + 20))

        # 본문
        if "small" in self.fonts:
            line1 = "신규 호위무사를 영입하면"
            line2 = "기존 호위무사는 해고됩니다."
            line3 = "계속하시겠습니까?"
            s1, _ = self.fonts["small"].render(line1, ET["text_body"])
            s2, _ = self.fonts["small"].render(line2, ET["text_body"])
            s3, _ = self.fonts["small"].render(line3, ET["gold_pale"])
            self.screen.blit(s1, (cx - s1.get_width() // 2, dy + 55))
            self.screen.blit(s2, (cx - s2.get_width() // 2, dy + 78))
            self.screen.blit(s3, (cx - s3.get_width() // 2, dy + 105))

        # 버튼
        btn_w, btn_h = 100, 40
        btn_y = dy + dialog_h - 60
        yes_x = cx - btn_w - 20
        no_x = cx + 20
        selected = getattr(self, 'guard_confirm_selected', 1)

        for i, (bx, label) in enumerate([(yes_x, "예"), (no_x, "아니오")]):
            is_sel = (selected == i)
            if is_sel:
                bg_color = ET["carnelian_light"] if i == 0 else ET["lapis_lazuli"]
                border_color = ET["gold_bright"]
            else:
                bg_color = ET["bg_medium"]
                border_color = ET["card_border"]

            pygame.draw.rect(self.screen, bg_color, (bx, btn_y, btn_w, btn_h), border_radius=6)
            pygame.draw.rect(self.screen, border_color, (bx, btn_y, btn_w, btn_h), 2, border_radius=6)

            if "small" in self.fonts:
                text_color = ET["text_white"] if is_sel else ET["text_hint"]
                bs, _ = self.fonts["small"].render(label, text_color)
                self.screen.blit(bs, (bx + btn_w // 2 - bs.get_width() // 2,
                                      btn_y + btn_h // 2 - bs.get_height() // 2))

    def _draw_guard_skill_tooltip(self, hover_info: dict):
        """호위무사 선택 화면의 스킬 아이콘 툴팁 (pingfighter _draw_arena_skill_tooltip 동일 폼)"""
        skill = hover_info.get('skill')
        slot_rect = hover_info.get('rect')
        hero_color = hover_info.get('hero_color', (150, 150, 150))
        if not skill or not slot_rect:
            return

        # 툴팁 크기
        tooltip_width = 280
        padding = 10
        header_height = 30

        # 설명 줄바꿈 계산
        description = getattr(skill, 'description', '') or ''
        desc_lines = []
        if self.fonts and "small" in self.fonts:
            max_text_w = tooltip_width - padding * 2
            current_line = ""
            for char in description:
                test_line = current_line + char
                test_surf, _ = self.fonts["small"].render(test_line, (255, 255, 255))
                if test_surf.get_width() <= max_text_w:
                    current_line = test_line
                else:
                    if current_line:
                        desc_lines.append(current_line)
                    current_line = char
            if current_line:
                desc_lines.append(current_line)
            desc_lines = desc_lines[:4]

        # 높이 계산
        y_offset = padding + header_height + 6  # 헤더
        y_offset += 18  # 쿨타임
        y_offset += len(desc_lines) * 16 + 4  # 설명
        duration = getattr(skill, 'duration', 0)
        show_duration = 0 < duration < 999
        if show_duration:
            y_offset += 16
        tooltip_height = y_offset + padding

        # 위치: 슬롯 위쪽
        tooltip_x = slot_rect.centerx - tooltip_width // 2
        tooltip_y = slot_rect.y - tooltip_height - 6

        # 화면 경계 보정
        if tooltip_x < 8:
            tooltip_x = 8
        if tooltip_x + tooltip_width > SCREEN_WIDTH - 8:
            tooltip_x = SCREEN_WIDTH - tooltip_width - 8
        if tooltip_y < 8:
            tooltip_y = slot_rect.y + slot_rect.height + 6

        # 툴팁 Surface
        tt = pygame.Surface((tooltip_width, tooltip_height), pygame.SRCALPHA)
        tt.fill((*ET["bg_panel"], 235))

        r, g, b = hero_color[:3]
        pygame.draw.rect(tt, (r, g, b), (0, 0, tooltip_width, tooltip_height), 2, border_radius=6)
        pygame.draw.rect(tt, (r, g, b, 50), (2, 2, tooltip_width - 4, header_height), border_radius=5)

        y_pos = padding

        # 스킬명
        if self.fonts and "medium" in self.fonts:
            name_text = getattr(skill, 'korean_name', '') or getattr(skill, 'name', '???')
            ns, _ = self.fonts["medium"].render(name_text, (255, 255, 255))
            tt.blit(ns, (padding, y_pos))

        # 발동 조건
        if self.fonts and "small" in self.fonts and HERO_SKILLS_AVAILABLE:
            trigger = getattr(skill, 'trigger', None)
            if trigger == SkillTrigger.ON_BALL_HIT:
                trig_text, trig_color = "타격 발동", ET["lapis_light"]
            elif trigger == SkillTrigger.ON_COOLDOWN:
                trig_text, trig_color = "자동 발동", ET["gold_pale"]
            else:
                trig_text, trig_color = "패시브", ET["malachite_light"]
            ts, _ = self.fonts["small"].render(trig_text, trig_color)
            tt.blit(ts, (tooltip_width - padding - ts.get_width(), y_pos + 4))

        y_pos += header_height + 6

        # 쿨타임
        if self.fonts and "small" in self.fonts:
            cooldown = getattr(skill, 'cooldown', 0)
            cd_text = f"쿨타임: {cooldown}초"
            cs, _ = self.fonts["small"].render(cd_text, ET["text_body"])
            tt.blit(cs, (tooltip_width - padding - cs.get_width(), y_pos))
        y_pos += 18

        # 설명
        if self.fonts and "small" in self.fonts:
            for line in desc_lines:
                ls, _ = self.fonts["small"].render(line, ET["text_white"])
                tt.blit(ls, (padding, y_pos))
                y_pos += 16
        y_pos += 4

        # 지속시간
        if show_duration and self.fonts and "small" in self.fonts:
            dur_text = f"지속시간: {duration}초"
            ds, _ = self.fonts["small"].render(dur_text, ET["malachite_light"])
            tt.blit(ds, (padding, y_pos))

        self.screen.blit(tt, (tooltip_x, tooltip_y))

    def _draw_animated_bracket(self):
        """애니메이션이 적용된 대진표 그리기"""
        # 8강 매치 (하단) - 확대 레이아웃
        y_base = 530
        x_positions = [60, 195, 430, 565]

        for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
            x = x_positions[i]
            self._draw_animated_match_box(match, x, y_base, i, TournamentRound.QUARTER_FINAL)

        # 4강 매치 (중간) - 확대 레이아웃
        y_semi = 310
        x_semi = [127, 497]

        semi_matches = self.matches.get(TournamentRound.SEMI_FINAL, [])
        for i, match in enumerate(semi_matches):
            self._draw_animated_match_box(match, x_semi[i], y_semi, i + 4, TournamentRound.SEMI_FINAL)

        # 빈 4강 슬롯 또는 승자 이동 애니메이션
        if not semi_matches or len(semi_matches) < 2:
            for i, x in enumerate(x_semi):
                if self.bracket_anim_phase >= 1 and self.current_round == TournamentRound.QUARTER_FINAL:
                    self._draw_winner_moving_to_slot(x, y_semi, i)
                else:
                    self._draw_empty_match_box(x, y_semi, "준결승 " + str(i + 1))

        # 결승 (상단) - 확대 레이아웃
        y_final = 80
        x_final = 312

        final_matches = self.matches.get(TournamentRound.FINAL, [])
        if final_matches:
            self._draw_animated_match_box(final_matches[0], x_final, y_final, 6, TournamentRound.FINAL)
        else:
            if self.bracket_anim_phase >= 1 and self.current_round == TournamentRound.SEMI_FINAL:
                self._draw_winner_moving_to_slot(x_final, y_final, 0, is_final=True)
            else:
                self._draw_empty_match_box(x_final, y_final, "결승")

        # 연결선 그리기 (애니메이션 효과 포함)
        self._draw_animated_bracket_lines()

    def _get_per_match_x_progress(self, match_idx: int, round_type: TournamentRound) -> float:
        """매치별 순차 X 애니메이션 진행도 계산"""
        if self.bracket_anim_phase >= 1:
            return 1.0
        # 라운드 내 순서
        if round_type == TournamentRound.QUARTER_FINAL:
            order = match_idx
        elif round_type == TournamentRound.SEMI_FINAL:
            order = match_idx - 4
        else:
            order = 0
        delay = getattr(self, 'bracket_anim_x_delay', 0.6)
        dur = getattr(self, 'bracket_anim_x_duration', 0.5)
        x_start = order * delay
        elapsed = self.bracket_anim_timer - x_start
        if elapsed <= 0:
            return 0.0
        return min(1.0, elapsed / dur)

    def _draw_animated_match_box(self, match: Match, x: int, y: int, match_idx: int, round_type: TournamentRound):
        """애니메이션이 적용된 매치 박스 그리기 (대각선 레이아웃)"""
        box_w, box_h = 120, 140  # 대각선 레이아웃 크기

        # 현재 라운드의 완료된 매치인지 확인
        is_current_round_match = (round_type == self.current_round)

        # 매치별 개별 X 진행도
        per_match_xp = self._get_per_match_x_progress(match_idx, round_type) if is_current_round_match else 0.0

        # 박스 배경
        if match.completed:
            bg_color = ET["card_bg_completed"]
        else:
            bg_color = ET["card_bg"]

        pygame.draw.rect(self.screen, bg_color, (x, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, ET["card_border"], (x, y, box_w, box_h), 2, border_radius=8)

        # 대각선 (왼쪽 하단 → 오른쪽 상단)
        pygame.draw.line(self.screen, ET["card_diagonal"], (x + 5, y + box_h - 5), (x + box_w - 5, y + 5), 2)

        # === 영웅 1 (왼쪽 상단 삼각형) ===
        hero1 = match.hero1
        h1_is_loser = match.completed and match.winner != hero1
        h1_alpha = 255

        if h1_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            h1_alpha = int(255 * (1.0 - per_match_xp * 0.5))

        h1_color = hero1["color"]
        hero1_name = hero1.get("name", "???")
        hero1_rect = pygame.Rect(x + 25 - 30, y + 55 - 30, 60, 60)
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h1_brightness = sum(h1_color) / 3
        h1_base_color = h1_color if h1_brightness > 80 else (min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))

        # 영웅 1 이름 (상단 좌측)
        if self.fonts and "small" in self.fonts:
            name_color = h1_base_color if h1_alpha == 255 else tuple(int(c * 0.5) for c in h1_base_color)
            surf, _ = self.fonts["small"].render(hero1_name, name_color)
            self.screen.blit(surf, (x + 8, y + 8))

        # 영웅 1 캐릭터 이미지 (좌측 - 더 왼쪽으로, 60% 크게)
        if self.hero_paddle_renderer and h1_alpha > 100:
            hero1_id = hero1.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1_id, x + 25, y + 55, 64, 45,
                facing="down", color=h1_color, scale_mode="preview"
            )

        # 패자 X 표시
        if h1_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            if per_match_xp > 0:
                self._draw_loser_x(hero1_rect, per_match_xp)

        # === VS (중앙 원) - 이집트 ===
        vs_x = x + box_w // 2
        vs_y = y + box_h // 2
        pygame.draw.circle(self.screen, ET["vs_circle_bg"], (vs_x, vs_y), 16)
        pygame.draw.circle(self.screen, ET["vs_circle_border"], (vs_x, vs_y), 16, 2)
        if self.fonts and "small" in self.fonts:
            surf, _ = self._render_text("small", "VS", ET["gold_bright"])
            if surf:
                self.screen.blit(surf, (vs_x - surf.get_width() // 2, vs_y - surf.get_height() // 2))

        # === 영웅 2 (오른쪽 하단 삼각형) ===
        hero2 = match.hero2
        h2_is_loser = match.completed and match.winner != hero2
        h2_alpha = 255

        if h2_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            h2_alpha = int(255 * (1.0 - per_match_xp * 0.5))

        h2_color = hero2["color"]
        hero2_name = hero2.get("name", "???")
        hero2_rect = pygame.Rect(x + box_w - 25 - 30, y + box_h - 55 - 30, 60, 60)
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h2_brightness = sum(h2_color) / 3
        h2_base_color = h2_color if h2_brightness > 80 else (min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))

        # 영웅 2 캐릭터 이미지 (우측 - 더 오른쪽으로, 60% 크게)
        if self.hero_paddle_renderer and h2_alpha > 100:
            hero2_id = hero2.get("id", "chronos")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2_id, x + box_w - 25, y + box_h - 55, 64, 45,
                facing="down", color=h2_color, scale_mode="preview"
            )

        # 영웅 2 이름 (하단 우측)
        if self.fonts and "small" in self.fonts:
            name_color = h2_base_color if h2_alpha == 255 else tuple(int(c * 0.5) for c in h2_base_color)
            surf, _ = self.fonts["small"].render(hero2_name, name_color)
            self.screen.blit(surf, (x + box_w - surf.get_width() - 8, y + box_h - 22))

        # 패자 X 표시
        if h2_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            if per_match_xp > 0:
                self._draw_loser_x(hero2_rect, per_match_xp)

        # 승자 하이라이트 효과
        if match.completed and match.winner and is_current_round_match:
            winner_rect = hero1_rect if match.winner == hero1 else hero2_rect
            if self.bracket_anim_phase >= 0:
                glow_alpha = int(abs(_sin(self.animation_timer * 4)) * 100 + 50)
                glow_surface = _get_arena_surface(winner_rect.width + 6, winner_rect.height + 6)
                pygame.draw.rect(glow_surface, (255, 215, 0, glow_alpha),
                               (0, 0, winner_rect.width + 6, winner_rect.height + 6),
                               border_radius=5)
                self.screen.blit(glow_surface, (winner_rect.x - 3, winner_rect.y - 3))

        # 결과 표시 (스코어)
        if match.completed and match.winner:
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render(f"{match.score1}:{match.score2}", ET["gold_bright"])
                self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + box_h + 5))

    # ====================================================================
    # 커스텀 심볼 드로잉 (이모지 대체)
    # ====================================================================
    def _draw_sword_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 215, 0)):
        """교차 검 아이콘 (⚔ 대체)"""
        s = size // 2
        # 검 1 (\)
        pygame.draw.line(self.screen, color, (x - s, y - s), (x + s, y + s), 2)
        pygame.draw.line(self.screen, color, (x - s // 2, y - s + 2), (x + s // 2, y - s + 2), 2)  # 가드
        # 검 2 (/)
        pygame.draw.line(self.screen, color, (x + s, y - s), (x - s, y + s), 2)
        pygame.draw.line(self.screen, color, (x - s // 2, y + s - 2), (x + s // 2, y + s - 2), 2)  # 가드

    def _draw_crown_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 215, 0)):
        """왕관 아이콘 (👑 대체)"""
        s = size // 2
        # 왕관 몸체
        points = [
            (x - s, y + s // 2),
            (x - s, y - s // 3),
            (x - s // 2, y),
            (x, y - s),
            (x + s // 2, y),
            (x + s, y - s // 3),
            (x + s, y + s // 2),
        ]
        pygame.draw.polygon(self.screen, color, points)
        pygame.draw.polygon(self.screen, (200, 170, 0), points, 2)

    def _draw_trophy_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 215, 0)):
        """트로피 아이콘 (🏆 대체)"""
        s = size // 2
        # 컵 몸체
        pygame.draw.rect(self.screen, color, (x - s + 2, y - s, s * 2 - 4, s + 2), border_radius=3)
        # 손잡이
        pygame.draw.arc(self.screen, color, (x - s - 3, y - s + 2, 8, s), -1.5, 1.5, 2)
        pygame.draw.arc(self.screen, color, (x + s - 5, y - s + 2, 8, s), 1.5, 4.5, 2)
        # 받침대
        pygame.draw.rect(self.screen, color, (x - s // 3, y + 2, s // 3 * 2, s // 3))
        pygame.draw.rect(self.screen, color, (x - s // 2, y + 2 + s // 3, s, 3))

    def _draw_skull_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 100, 100)):
        """해골 아이콘 (💀 대체)"""
        s = size // 2
        # 머리
        pygame.draw.circle(self.screen, color, (x, y - 2), s - 1)
        # 턱
        pygame.draw.rect(self.screen, color, (x - s // 2, y + s // 3, s, s // 3))
        # 눈
        pygame.draw.circle(self.screen, (30, 30, 30), (x - s // 3, y - 3), s // 4)
        pygame.draw.circle(self.screen, (30, 30, 30), (x + s // 3, y - 3), s // 4)

    def _draw_fire_icon(self, x: int, y: int, size: int = 14, color: Tuple[int, int, int] = (255, 150, 50)):
        """불꽃 아이콘 (🔥 대체)"""
        s = size // 2
        # 외곽 불꽃
        points = [
            (x, y - s), (x + s // 2, y - s // 3),
            (x + s, y + s // 2), (x + s // 3, y + s),
            (x - s // 3, y + s), (x - s, y + s // 2),
            (x - s // 2, y - s // 3),
        ]
        pygame.draw.polygon(self.screen, color, points)
        # 내부 불꽃 (밝은 색)
        inner = [
            (x, y - s // 3), (x + s // 3, y),
            (x + s // 4, y + s // 2), (x - s // 4, y + s // 2),
            (x - s // 3, y),
        ]
        pygame.draw.polygon(self.screen, (255, 220, 100), inner)

    def _draw_coin_icon(self, x: int, y: int, size: int = 14, color: Tuple[int, int, int] = (255, 215, 0)):
        """동전 아이콘 (💰 대체)"""
        s = size // 2
        pygame.draw.circle(self.screen, color, (x, y), s)
        pygame.draw.circle(self.screen, (200, 170, 0), (x, y), s, 2)
        # G 텍스트
        if self.fonts and "small" in self.fonts:
            g_surf, _ = self._render_text("small", "G", (200, 170, 0))
            self.screen.blit(g_surf, (x - g_surf.get_width() // 2, y - g_surf.get_height() // 2))

    def _draw_warning_icon(self, x: int, y: int, size: int = 14, color: Tuple[int, int, int] = (255, 200, 50)):
        """경고 삼각형 아이콘 (⚠ 대체)"""
        s = size // 2
        # 삼각형
        points = [(x, y - s), (x + s, y + s), (x - s, y + s)]
        pygame.draw.polygon(self.screen, color, points)
        pygame.draw.polygon(self.screen, (200, 150, 0), points, 2)
        # 느낌표
        pygame.draw.line(self.screen, (40, 40, 40), (x, y - s // 3), (x, y + s // 4), 2)
        pygame.draw.circle(self.screen, (40, 40, 40), (x, y + s // 2), 1)

    def _play_bracket_sound(self, sound_key: str, volume: float = 0.5):
        """대진표 애니메이션용 사운드 재생"""
        if not hasattr(ColosseumsArena, '_skill_sound_cache'):
            ColosseumsArena._skill_sound_cache = {}
        if sound_key not in ColosseumsArena._skill_sound_cache:
            try:
                project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                filepath = os.path.join(project_root, "sounds", f"{sound_key}.wav")
                if os.path.exists(filepath):
                    ColosseumsArena._skill_sound_cache[sound_key] = pygame.mixer.Sound(filepath)
                else:
                    ColosseumsArena._skill_sound_cache[sound_key] = None
            except Exception:
                ColosseumsArena._skill_sound_cache[sound_key] = None
        sound = ColosseumsArena._skill_sound_cache.get(sound_key)
        if sound:
            sound.set_volume(volume)
            sound.play()

    def _draw_loser_x(self, rect: pygame.Rect, progress: float):
        """패자에게 X 표시 그리기"""
        # X의 최종 크기 (progress와 독립적)
        max_size = int(min(rect.width, rect.height) * 0.6)
        center_x = rect.centerx
        center_y = rect.centery

        # X 색상 (빨간색)
        x_color = (255, 60, 60)
        line_width = 4

        # 첫 번째 대각선 (\) - 0~0.5 구간에서 성장
        if progress > 0:
            line1_progress = min(1.0, progress * 2)
            end_offset = int(max_size * line1_progress)
            pygame.draw.line(self.screen, x_color,
                           (center_x - end_offset, center_y - end_offset),
                           (center_x + end_offset, center_y + end_offset),
                           line_width)

        # 두 번째 대각선 (/) - 0.5~1.0 구간에서 성장
        if progress > 0.5:
            line2_progress = (progress - 0.5) * 2
            end_offset = int(max_size * line2_progress)
            pygame.draw.line(self.screen, x_color,
                           (center_x + end_offset, center_y - end_offset),
                           (center_x - end_offset, center_y + end_offset),
                           line_width)

    def _draw_winner_moving_to_slot(self, target_x: int, target_y: int, slot_idx: int, is_final: bool = False):
        """승자가 다음 라운드 슬롯으로 이동하는 애니메이션"""
        box_w, box_h = 100, 100

        # 진행도에 따른 슬롯 표시
        if self.bracket_anim_phase >= 1:
            # 이동 중인 승자 표시
            progress = self.bracket_anim_progress

            # 시작 위치 계산
            if self.current_round == TournamentRound.QUARTER_FINAL:
                # 8강 → 4강
                if slot_idx == 0:
                    # 첫 두 매치 승자
                    winners = [self.matches[TournamentRound.QUARTER_FINAL][0].winner,
                              self.matches[TournamentRound.QUARTER_FINAL][1].winner]
                    start_positions = [(150, 550), (300, 550)]
                else:
                    # 뒤 두 매치 승자
                    winners = [self.matches[TournamentRound.QUARTER_FINAL][2].winner,
                              self.matches[TournamentRound.QUARTER_FINAL][3].winner]
                    start_positions = [(480, 550), (630, 550)]

                # 중간점
                mid_y = 520

                for i, (winner, start_pos) in enumerate(zip(winners, start_positions)):
                    if winner:
                        # 이징 함수 적용
                        t = self._ease_in_out(progress)

                        # 위치 계산
                        if progress < 0.5:
                            # 상승 + 수평 이동
                            p = progress * 2
                            current_x = start_pos[0] + (target_x + box_w // 2 - start_pos[0]) * p
                            current_y = start_pos[1] - (start_pos[1] - mid_y) * p
                        else:
                            # 하강 + 최종 위치
                            p = (progress - 0.5) * 2
                            current_x = target_x + box_w // 2
                            current_y = mid_y - (mid_y - target_y - box_h // 2) * p

                        # 승자 이름 그리기 (이동 중)
                        self._draw_moving_winner(winner, int(current_x), int(current_y), progress)

            elif self.current_round == TournamentRound.SEMI_FINAL and is_final:
                # 4강 → 결승
                semi_matches = self.matches.get(TournamentRound.SEMI_FINAL, [])
                if len(semi_matches) >= 2:
                    winners = [semi_matches[0].winner, semi_matches[1].winner]
                    start_positions = [(225, 380), (555, 380)]

                    mid_y = 340

                    for i, (winner, start_pos) in enumerate(zip(winners, start_positions)):
                        if winner:
                            t = self._ease_in_out(progress)

                            if progress < 0.5:
                                p = progress * 2
                                current_x = start_pos[0] + (target_x + box_w // 2 - start_pos[0]) * p
                                current_y = start_pos[1] - (start_pos[1] - mid_y) * p
                            else:
                                p = (progress - 0.5) * 2
                                current_x = target_x + box_w // 2
                                current_y = mid_y - (mid_y - target_y - box_h // 2) * p

                            self._draw_moving_winner(winner, int(current_x), int(current_y), progress)
        else:
            # 빈 슬롯
            self._draw_empty_match_box(target_x, target_y, "결승" if is_final else f"준결승 {slot_idx + 1}")

    def _draw_moving_winner(self, winner: dict, x: int, y: int, progress: float):
        """이동 중인 승자 표시 (캐릭터 아이콘 포함)"""
        # 글로우 효과
        glow_radius = 40 + int(abs(_sin(self.animation_timer * 5)) * 10)
        glow_alpha = int(100 + progress * 100)

        glow_surface = _get_arena_surface(glow_radius * 2, glow_radius * 2)
        pygame.draw.circle(glow_surface, (*winner["color"], glow_alpha),
                         (glow_radius, glow_radius), glow_radius)
        self.screen.blit(glow_surface, (x - glow_radius, y - glow_radius))

        # 캐릭터 이미지 그리기
        if self.hero_paddle_renderer:
            hero_id = winner.get("id", "mugen")
            # 스케일 애니메이션 (이동 중 약간 커짐)
            scale_factor = 1.0 + progress * 0.2
            img_w = int(60 * scale_factor)
            img_h = int(42 * scale_factor)
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero_id, x, y, img_w, img_h,
                facing="down", color=winner["color"], scale_mode="preview"
            )
        else:
            # 폴백: 영웅 색상 원
            pygame.draw.circle(self.screen, winner["color"], (x, y), 25)
            pygame.draw.circle(self.screen, (255, 255, 255), (x, y), 25, 2)

        # 이름 표시
        if self.fonts and "small" in self.fonts:
            # 밝기 보정
            color = winner["color"]
            brightness = sum(color) / 3
            name_color = color if brightness > 80 else (min(255, color[0] + 100), min(255, color[1] + 100), min(255, color[2] + 100))
            surf, _ = self.fonts["small"].render(winner["name"], name_color)
            self.screen.blit(surf, (x - surf.get_width() // 2, y - 45))

    def _draw_vs_matchup_animation(self):
        """VS 매치업 애니메이션 (다음 경기 미리보기)"""
        if not self.selected_match:
            return

        hero1 = self.selected_match.hero1
        hero2 = self.selected_match.hero2
        progress = self.bracket_anim_progress

        # 라운드 이름
        round_names = {
            TournamentRound.QUARTER_FINAL: "8강전",
            TournamentRound.SEMI_FINAL: "4강전",
            TournamentRound.FINAL: "결승전",
        }
        round_name = round_names.get(self.current_round, "다음 경기")

        # 타이틀
        if self.fonts and "large" in self.fonts:
            pulse = abs(_sin(self.animation_timer * 3)) * 0.3 + 0.7
            gold_color = (int(ET["gold_bright"][0] * pulse), int(ET["gold_bright"][1] * pulse), int(ET["gold_bright"][2] * pulse))
            title = round_name
            surf, _ = self.fonts["large"].render(title, gold_color)
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self.screen.blit(surf, (title_x, 80))
            icon_y = 80 + surf.get_height() // 2
            self._draw_sword_icon(title_x - 16, icon_y, 14, gold_color)
            self._draw_sword_icon(title_x + surf.get_width() + 16, icon_y, 14, gold_color)

        # 영웅 1 (왼쪽에서 슬라이드 인)
        hero1_target_x = SCREEN_WIDTH // 2 - 150
        hero1_start_x = -100
        hero1_x = int(hero1_start_x + (hero1_target_x - hero1_start_x) * self._ease_in_out(min(1.0, progress * 2)))
        hero1_y = SCREEN_HEIGHT // 2

        # 글로우 효과
        glow_alpha = int(80 + abs(_sin(self.animation_timer * 4)) * 50)
        glow_surf = _get_arena_surface(160, 160)
        pygame.draw.circle(glow_surf, (*hero1["color"], glow_alpha), (80, 80), 70)
        self.screen.blit(glow_surf, (hero1_x - 80, hero1_y - 80))

        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1.get("id", "mugen"), hero1_x, hero1_y, 100, 70,
                facing="down", color=hero1["color"], scale_mode="preview"
            )

        # 이름 + 칭호
        if self.fonts:
            h1_color = hero1["color"]
            h1_brightness = sum(h1_color) / 3
            h1_name_color = h1_color if h1_brightness > 80 else (min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero1["name"], h1_name_color)
                self.screen.blit(surf, (hero1_x - surf.get_width() // 2, hero1_y - 70))
            # 별명(칭호) - 골든 색상 + 장식 괄호로 호위무사 이름과 차별화
            if "medium" in self.fonts:
                title_text = f"「{hero1['title']}」"
                title_color = ET["gold_pale"]
                # 그림자 효과
                shadow_surf, _ = self.fonts["medium"].render(title_text, ET["gold_dark"])
                self.screen.blit(shadow_surf, (hero1_x - shadow_surf.get_width() // 2 + 1, hero1_y + 46))
                # 본 텍스트
                surf, _ = self.fonts["medium"].render(title_text, title_color)
                self.screen.blit(surf, (hero1_x - surf.get_width() // 2, hero1_y + 45))

            # 호위무사 아이콘 (영웅1) - 1명만 표시
            h1_guards = self.guard_warrior_map.get(hero1.get("id"), [])
            if h1_guards and self.hero_paddle_renderer:
                g = h1_guards[0]
                guard_y = hero1_y + 90
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen, g.get("id", "mugen"), hero1_x, guard_y, 56, 40,
                    facing="down", color=g.get("color", (150, 150, 150)), scale_mode="preview"
                )
                if "small" in self.fonts:
                    g_name = g.get("name", "")
                    ns, _ = self.fonts["small"].render(g_name, ET["text_body"])
                    self.screen.blit(ns, (hero1_x - ns.get_width() // 2, guard_y + 28))

        # VS (중앙, 스케일 애니메이션)
        vs_scale = min(1.0, progress * 3) if progress < 0.5 else 1.0
        if self.fonts and "large" in self.fonts and vs_scale > 0.1:
            vs_color = (ET["carnelian_light"][0], int(100 + abs(_sin(self.animation_timer * 5)) * 100), 60)
            surf, _ = self.fonts["large"].render("VS", vs_color)
            # 스케일 적용
            if vs_scale < 1.0:
                scaled_w = int(surf.get_width() * vs_scale)
                scaled_h = int(surf.get_height() * vs_scale)
                if scaled_w > 0 and scaled_h > 0:
                    scaled_surf = pygame.transform.scale(surf, (scaled_w, scaled_h))
                    self.screen.blit(scaled_surf, (SCREEN_WIDTH // 2 - scaled_w // 2, SCREEN_HEIGHT // 2 - scaled_h // 2))
            else:
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, SCREEN_HEIGHT // 2 - surf.get_height() // 2))

        # 영웅 2 (오른쪽에서 슬라이드 인)
        hero2_target_x = SCREEN_WIDTH // 2 + 150
        hero2_start_x = SCREEN_WIDTH + 100
        hero2_x = int(hero2_start_x + (hero2_target_x - hero2_start_x) * self._ease_in_out(min(1.0, progress * 2)))
        hero2_y = SCREEN_HEIGHT // 2

        # 글로우 효과
        glow_surf = _get_arena_surface(160, 160)
        pygame.draw.circle(glow_surf, (*hero2["color"], glow_alpha), (80, 80), 70)
        self.screen.blit(glow_surf, (hero2_x - 80, hero2_y - 80))

        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2.get("id", "chronos"), hero2_x, hero2_y, 100, 70,
                facing="down", color=hero2["color"], scale_mode="preview"
            )

        # 이름 + 칭호
        if self.fonts:
            h2_color = hero2["color"]
            h2_brightness = sum(h2_color) / 3
            h2_name_color = h2_color if h2_brightness > 80 else (min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero2["name"], h2_name_color)
                self.screen.blit(surf, (hero2_x - surf.get_width() // 2, hero2_y - 70))
            # 별명(칭호) - 골든 색상 + 장식 괄호로 호위무사 이름과 차별화
            if "medium" in self.fonts:
                title_text = f"「{hero2['title']}」"
                title_color = ET["gold_pale"]
                # 그림자 효과
                shadow_surf, _ = self.fonts["medium"].render(title_text, ET["gold_dark"])
                self.screen.blit(shadow_surf, (hero2_x - shadow_surf.get_width() // 2 + 1, hero2_y + 46))
                # 본 텍스트
                surf, _ = self.fonts["medium"].render(title_text, title_color)
                self.screen.blit(surf, (hero2_x - surf.get_width() // 2, hero2_y + 45))

            # 호위무사 아이콘 (영웅2) - 1명만 표시
            h2_guards = self.guard_warrior_map.get(hero2.get("id"), [])
            if h2_guards and self.hero_paddle_renderer:
                g = h2_guards[0]
                guard_y = hero2_y + 90
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen, g.get("id", "mugen"), hero2_x, guard_y, 56, 40,
                    facing="down", color=g.get("color", (150, 150, 150)), scale_mode="preview"
                )
                if "small" in self.fonts:
                    g_name = g.get("name", "")
                    ns, _ = self.fonts["small"].render(g_name, ET["text_body"])
                    self.screen.blit(ns, (hero2_x - ns.get_width() // 2, guard_y + 28))

        # 상성 표시 (VS 텍스트 아래)
        matchup_val = get_style_matchup(hero1["style"], hero2["style"])
        if matchup_val != 0 and self.fonts and "small" in self.fonts:
            matchup_y = SCREEN_HEIGHT // 2 + 30
            if matchup_val > 0:
                # hero1 유리
                adv_text = f"▶ {hero1['name']} 상성 유리"
                adv_color = (100, 255, 120)
            else:
                # hero2 유리
                adv_text = f"▶ {hero2['name']} 상성 유리"
                adv_color = (100, 255, 120)
            surf, _ = self.fonts["small"].render(adv_text, adv_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, matchup_y))
            # 상성 관계 설명
            style1_name = STYLE_KOREAN_NAMES.get(hero1["style"], "?")
            style2_name = STYLE_KOREAN_NAMES.get(hero2["style"], "?")
            detail = f"({style1_name} vs {style2_name})"
            ds, _ = self.fonts["small"].render(detail, ET["text_hint"])
            self.screen.blit(ds, (SCREEN_WIDTH // 2 - ds.get_width() // 2, matchup_y + 18))

        # 하단 힌트 (버튼 모드에서 버튼이 나타나기 전까지만 표시)
        show_buttons = getattr(self, 'vs_preview_show_buttons', False)
        if self.fonts and "small" in self.fonts:
            if show_buttons and getattr(self, 'vs_preview_timer', 0) >= 1.5:
                pass  # 버튼이 표시되면 힌트 숨김
            else:
                hint = "잠시 후 배틀이 시작됩니다..." if not show_buttons else "잠시 후 계속 여부를 선택합니다..."
                alpha = int(abs(_sin(self.animation_timer * 2)) * 155 + 100)
                surf, _ = self.fonts["small"].render(hint, (alpha, int(alpha * 0.9), int(alpha * 0.7)))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 650))

    def _ease_in_out(self, t: float) -> float:
        """이징 함수 (부드러운 시작과 끝)"""
        if t < 0.5:
            return 2 * t * t
        else:
            return 1 - pow(-2 * t + 2, 2) / 2

    def _draw_animated_bracket_lines(self):
        """애니메이션이 적용된 대진표 연결선 (대각선 레이아웃 box_h=140 기준)"""
        base_color = ET["bracket_line"]
        highlight_color = ET["bracket_highlight"]

        # 대각선 레이아웃 좌표 (box_w=120, box_h=140)
        q1_x, q2_x, q3_x, q4_x = 120, 255, 490, 625  # 8강 박스 중심
        s1_x, s2_x = 187, 557  # 4강 박스 중심
        f_x = 372  # 결승 박스 중심
        y_q_top, y_mid1, y_s_bottom = 530, 490, 450
        y_s_top, y_mid2, y_f_bottom = 310, 265, 220

        # 8강 → 4강 연결
        if self.current_round == TournamentRound.QUARTER_FINAL and self.bracket_anim_phase >= 1:
            progress = self.bracket_anim_progress

            # 좌측 (매치 0, 1)
            self._draw_animated_line((q1_x, y_q_top), (q1_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q2_x, y_q_top), (q2_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q1_x, y_mid1), (q2_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((s1_x, y_mid1), (s1_x, y_s_bottom), progress, base_color, highlight_color)

            # 우측 (매치 2, 3)
            self._draw_animated_line((q3_x, y_q_top), (q3_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q4_x, y_q_top), (q4_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q3_x, y_mid1), (q4_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((s2_x, y_mid1), (s2_x, y_s_bottom), progress, base_color, highlight_color)
        else:
            # 기본 라인
            pygame.draw.line(self.screen, base_color, (q1_x, y_q_top), (q1_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q2_x, y_q_top), (q2_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q1_x, y_mid1), (q2_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (s1_x, y_mid1), (s1_x, y_s_bottom), 2)
            pygame.draw.line(self.screen, base_color, (q3_x, y_q_top), (q3_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q4_x, y_q_top), (q4_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q3_x, y_mid1), (q4_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (s2_x, y_mid1), (s2_x, y_s_bottom), 2)

        # 4강 → 결승 연결
        if self.current_round == TournamentRound.SEMI_FINAL and self.bracket_anim_phase >= 1:
            progress = self.bracket_anim_progress
            self._draw_animated_line((s1_x, y_s_top), (s1_x, y_mid2), progress, base_color, highlight_color)
            self._draw_animated_line((s2_x, y_s_top), (s2_x, y_mid2), progress, base_color, highlight_color)
            self._draw_animated_line((s1_x, y_mid2), (s2_x, y_mid2), progress, base_color, highlight_color)
            self._draw_animated_line((f_x, y_mid2), (f_x, y_f_bottom), progress, base_color, highlight_color)
        else:
            pygame.draw.line(self.screen, base_color, (s1_x, y_s_top), (s1_x, y_mid2), 2)
            pygame.draw.line(self.screen, base_color, (s2_x, y_s_top), (s2_x, y_mid2), 2)
            pygame.draw.line(self.screen, base_color, (s1_x, y_mid2), (s2_x, y_mid2), 2)
            pygame.draw.line(self.screen, base_color, (f_x, y_mid2), (f_x, y_f_bottom), 2)

    def _draw_animated_line(self, start: tuple, end: tuple, progress: float,
                           base_color: tuple, highlight_color: tuple):
        """애니메이션이 적용된 라인 그리기"""
        # 베이스 라인
        pygame.draw.line(self.screen, base_color, start, end, 2)

        # 진행도에 따른 하이라이트
        if progress > 0:
            # 라인을 따라 움직이는 하이라이트
            current_end = (
                start[0] + (end[0] - start[0]) * progress,
                start[1] + (end[1] - start[1]) * progress
            )
            pygame.draw.line(self.screen, highlight_color, start, current_end, 3)

            # 끝점에 글로우 효과
            glow_size = 6
            glow_surface = _get_arena_surface(glow_size * 2, glow_size * 2)
            pygame.draw.circle(glow_surface, (*highlight_color, 180), (glow_size, glow_size), glow_size)
            self.screen.blit(glow_surface, (int(current_end[0]) - glow_size, int(current_end[1]) - glow_size))

    def get_result(self) -> Dict:
        """결과 반환"""
        return {
            "winnings": self.total_winnings,
            "final_gold": self.player_gold + self.total_winnings,
            "completed": self.state in (TournamentState.TOURNAMENT_END, TournamentState.VICTORY_CELEBRATION),
            "recruited_hero": getattr(self, 'recruited_hero', None),
        }


# ============================================================================
# 테스트용 함수
# ============================================================================
def test_arena():
    """투기장 테스트"""
    import pygame
    import pygame.freetype

    pygame.init()
    pygame.freetype.init()

    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("콜로세움 투기장 테스트")
    clock = pygame.time.Clock()

    # 폰트 (테스트용)
    fonts = {}
    try:
        fonts["small"] = pygame.freetype.Font(None, 16)
        fonts["medium"] = pygame.freetype.Font(None, 20)
        fonts["large"] = pygame.freetype.Font(None, 28)
    except Exception as e:
        print(f"Font init error: {e}")

    arena = ColosseumsArena(screen, fonts, 1000)

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif arena.handle_event(event):
                running = False

        arena.update(dt)
        arena.draw()
        pygame.display.flip()

    pygame.quit()


if __name__ == "__main__":
    test_arena()
