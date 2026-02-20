# downtown/colosseum_dojo.py
# 투기장 - 도장깨기 모드
# 1점 속전속결, 끊임없이 상대를 만나는 서바이벌 모드

import pygame
import random
import math
import sys
import os
from enum import Enum
from typing import List, Dict, Optional, Tuple

# 기존 투기장에서 공유 컴포넌트 임포트
try:
    import downtown.colosseum_arena as _arena_mod
    from downtown.colosseum_arena import (
        AIPaddleController, ArenaBall, BallSpawnAnimation, Match,
        ARENA_HEROES, TOP_HEROES, BOTTOM_HEROES,
        ARENA_PERK_POOL,
        HeroStyle, STYLE_MATCHUP_BONUS, STYLE_ADVANTAGE,
        STYLE_KOREAN_NAMES, get_style_matchup,
        FACECARD_MAP, _load_facecard,
        _get_arena_surface, _get_arena_fullscreen,
        SCREEN_WIDTH, SCREEN_HEIGHT, GAME_AREA_X, GAME_AREA_WIDTH,
        PADDLE_WIDTH, PADDLE_HEIGHT, BALL_SIZE,
        TOP_PADDLE_Y, BOTTOM_PADDLE_Y,
        BALL_BASE_SPEED, BALL_MAX_SPEED,
        ET,  # 이집트 테마 색상
        _load_hover_sound, _load_button_click_sound,
        _load_start_button_sound, _load_gacha_result_sound,
        _load_select_swing_sound,
    )
except ImportError:
    import colosseum_arena as _arena_mod
    from colosseum_arena import (
        AIPaddleController, ArenaBall, BallSpawnAnimation, Match,
        ARENA_HEROES, TOP_HEROES, BOTTOM_HEROES,
        ARENA_PERK_POOL,
        HeroStyle, STYLE_MATCHUP_BONUS, STYLE_ADVANTAGE,
        STYLE_KOREAN_NAMES, get_style_matchup,
        FACECARD_MAP, _load_facecard,
        _get_arena_surface, _get_arena_fullscreen,
        SCREEN_WIDTH, SCREEN_HEIGHT, GAME_AREA_X, GAME_AREA_WIDTH,
        PADDLE_WIDTH, PADDLE_HEIGHT, BALL_SIZE,
        TOP_PADDLE_Y, BOTTOM_PADDLE_Y,
        BALL_BASE_SPEED, BALL_MAX_SPEED,
        ET,
        _load_hover_sound, _load_button_click_sound,
        _load_start_button_sound, _load_gacha_result_sound,
        _load_select_swing_sound,
    )

# 영웅 스킬 시스템
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

# 스킬 아이콘
try:
    from downtown.hero_skill_icons import get_skill_icon as _get_hero_skill_icon
except ImportError:
    try:
        from hero_skill_icons import get_skill_icon as _get_hero_skill_icon
    except ImportError:
        def _get_hero_skill_icon(skill_id, size=32):
            return None

# 배경/필러 임포트
try:
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from backgrounds.animated_background_stage30 import AnimatedBackgroundStage30
    from pillar_colosseum import ColosseumFrame
    VISUAL_ASSETS_AVAILABLE = True
except ImportError:
    VISUAL_ASSETS_AVAILABLE = False

# 영웅 패들 렌더러
try:
    from downtown.hero_paddles import get_hero_paddle_renderer
    HERO_PADDLES_AVAILABLE = True
except ImportError:
    try:
        from hero_paddles import get_hero_paddle_renderer
        HERO_PADDLES_AVAILABLE = True
    except ImportError:
        HERO_PADDLES_AVAILABLE = False

# 날씨 이벤트
try:
    from events import weather_event as weather_module
    WEATHER_EVENT_AVAILABLE = True
except ImportError:
    WEATHER_EVENT_AVAILABLE = False
    weather_module = None

_sin = math.sin
_cos = math.cos


# ============================================================================
# 도장깨기 상태 머신
# ============================================================================
class DojoState(Enum):
    DIFFICULTY_SELECT = "difficulty_select"
    HERO_SELECT = "hero_select"
    SKILL_REVEAL = "skill_reveal"
    VS_PREVIEW = "vs_preview"
    BATTLE = "battle"
    RESULT = "result"
    PERK_SELECT = "perk_select"
    GAME_OVER = "game_over"


# ============================================================================
# 도장깨기 난이도
# ============================================================================
DOJO_DIFFICULTIES = [
    {
        "key": "normal",
        "name": "수련",
        "description": "기본 도장깨기\n라이프 3개",
        "entry_fee": 300,
        "lives": 3,
        "stat_base": 1.0,
        "reward_multiplier": 1.0,
        "color": (100, 200, 120),
        "border_color": (60, 160, 80),
    },
    {
        "key": "hard",
        "name": "달인",
        "description": "강화된 상대\n보상 1.8배",
        "entry_fee": 700,
        "lives": 3,
        "stat_base": 1.2,
        "reward_multiplier": 1.8,
        "color": (255, 200, 60),
        "border_color": (200, 150, 30),
    },
    {
        "key": "hell",
        "name": "무쌍",
        "description": "극한의 상대\n보상 3배 | 라이프 2개",
        "entry_fee": 1500,
        "lives": 2,
        "stat_base": 1.5,
        "reward_multiplier": 3.0,
        "color": (220, 60, 60),
        "border_color": (170, 30, 30),
    },
]

# 연승 보상 골드
DOJO_GOLD_PER_WIN = 80  # 기본 승리 골드


# ============================================================================
# 도장깨기 메인 클래스
# ============================================================================
class ColosseumsDojoBreaker:
    """투기장 - 도장깨기 모드 (끊임없는 1점 속전속결)"""

    def __init__(self, screen: pygame.Surface, fonts: Dict, player_gold: int,
                 battle_callback=None):
        self.screen = screen
        self.fonts = fonts
        self.player_gold = player_gold
        self.battle_callback = battle_callback
        self._text_cache: Dict[tuple, tuple] = {}

        # 도장깨기 상태
        self.state = DojoState.DIFFICULTY_SELECT
        self.exit_requested = False

        # 1점 속전속결 (start_arena_battle에서 win_score 읽음)
        self.win_score = 1

        # 호위무사 없음 (apply_arena_perks_for_battle 호환용)
        self.guard_loyalty_cd_bonus: Dict[str, int] = {}

        # 난이도
        self.difficulty = "normal"
        self.difficulty_data = DOJO_DIFFICULTIES[0]
        self.hover_difficulty_index = -1

        # 라이프 & 연승
        self.lives = 3
        self.max_lives = 3
        self.win_streak = 0
        self.best_streak = 0
        self.total_wins = 0
        self.total_gold_earned = 0

        # 영웅 선택
        self.player_hero = None
        self.player_hero_skill_index = -1
        self.hero_selected_skills: Dict[str, int] = {}
        self.hero_perks: Dict[str, list] = {}
        self.hero_has_both_skills: Dict[str, bool] = {}
        self.hover_hero_index = -1

        # 현재 상대
        self.current_opponent = None
        self.opponent_skill_index = -1
        self._used_opponents: List[str] = []  # 최근 상대 기록 (연속 중복 방지)

        # 배틀 상태
        self.battle_active = False
        self.top_paddle: Optional[AIPaddleController] = None
        self.bottom_paddle: Optional[AIPaddleController] = None
        self.ball: Optional[ArenaBall] = None
        self.ball_spawn_animation: Optional[BallSpawnAnimation] = None
        self.spawn_phase = False
        self.score_top = 0
        self.score_bottom = 0

        # 스킬 매니저
        self.skill_manager: Optional[HeroSkillManager] = None
        self._skill_sound_cache: Dict[str, Optional[pygame.mixer.Sound]] = {}

        # VS 프리뷰
        self.vs_timer = 0.0
        self.vs_duration = 0.8  # 0.8초 빠른 프리뷰

        # 결과 표시
        self.result_timer = 0.0
        self.result_duration = 0.8  # 0.8초 결과 표시
        self.result_winner = None  # "player" or "opponent"
        self.life_lost_anim = 0.0  # 라이프 소실 애니메이션

        # 퍽 선택
        self.perk_selected_index = 0
        self.perk_anim_timer = 0.0
        self.perk_anim_phase = "appearing"
        self.perk_selected_id = None
        self.perk_card_offsets = [0, 0, 0]
        self.perk_particles = []
        self.perk_frame_count = 0
        self.current_perk_options = []
        self.hover_perk_index = -1

        # 스킬 공개 애니메이션
        self.skill_reveal_timer = 0.0
        self.skill_reveal_phase = "rolling"
        self.skill_reveal_result = -1
        self._skill_reveal_last_tick_idx = -1

        # 게임오버
        self.game_over_timer = 0.0

        # 배속
        self.speed_multiplier = 1
        self.speed_btn_rects = {}

        # UI 타이머
        self.animation_timer = 0.0
        self.hover_glow_timer = 0.0

        # 시각 에셋
        self.arena_background = None
        self.arena_pillar = None
        self.hero_paddle_renderer = None
        self._init_visual_assets()

        # 사운드 로드
        _load_hover_sound()
        _load_button_click_sound()
        _load_start_button_sound()
        _load_select_swing_sound()
        _load_gacha_result_sound()

    def _init_visual_assets(self):
        """스테이지30 시각 에셋 초기화"""
        if VISUAL_ASSETS_AVAILABLE:
            try:
                self.arena_background = AnimatedBackgroundStage30()
            except Exception as e:
                print(f"[도장깨기] 배경 초기화 실패: {e}")

            try:
                self.arena_pillar = ColosseumFrame()
            except Exception as e:
                print(f"[도장깨기] 필러 초기화 실패: {e}")

        if HERO_PADDLES_AVAILABLE:
            try:
                self.hero_paddle_renderer = get_hero_paddle_renderer()
            except Exception as e:
                print(f"[도장깨기] 패들 렌더러 실패: {e}")

    # ========================================================================
    # 메인 루프 인터페이스 (ColosseumsArena와 동일 패턴)
    # ========================================================================
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리, 종료 시 True 반환"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.state == DojoState.BATTLE:
                    return False  # 배틀 중 ESC 무시
                if self.state == DojoState.DIFFICULTY_SELECT:
                    self.exit_requested = True
                    return True
                # 다른 상태에서는 난이도 선택으로 복귀
                self.exit_requested = True
                return True

        # 상태별 이벤트 처리
        if self.state == DojoState.DIFFICULTY_SELECT:
            return self._handle_difficulty_event(event)
        elif self.state == DojoState.HERO_SELECT:
            return self._handle_hero_select_event(event)
        elif self.state == DojoState.SKILL_REVEAL:
            return self._handle_skill_reveal_event(event)
        elif self.state == DojoState.VS_PREVIEW:
            return False  # 자동 진행
        elif self.state == DojoState.BATTLE:
            return self._handle_battle_event(event)
        elif self.state == DojoState.RESULT:
            return False  # 자동 진행
        elif self.state == DojoState.PERK_SELECT:
            return self._handle_perk_event(event)
        elif self.state == DojoState.GAME_OVER:
            return self._handle_game_over_event(event)

        return False

    def update(self, dt: float):
        """메인 업데이트"""
        self.animation_timer += dt
        self.hover_glow_timer += dt

        # 배경 업데이트
        if self.arena_background:
            self.arena_background.update(dt)

        # 상태별 업데이트
        if self.state == DojoState.SKILL_REVEAL:
            self._update_skill_reveal(dt)
        elif self.state == DojoState.VS_PREVIEW:
            self._update_vs_preview(dt)
        elif self.state == DojoState.BATTLE:
            self._update_battle(dt)
        elif self.state == DojoState.RESULT:
            self._update_result(dt)
        elif self.state == DojoState.PERK_SELECT:
            self._update_perk_select(dt)
        elif self.state == DojoState.GAME_OVER:
            self._update_game_over(dt)

    def draw(self):
        """메인 그리기"""
        if self.state == DojoState.DIFFICULTY_SELECT:
            self._draw_difficulty_select()
        elif self.state == DojoState.HERO_SELECT:
            self._draw_hero_select()
        elif self.state == DojoState.SKILL_REVEAL:
            self._draw_skill_reveal()
        elif self.state == DojoState.VS_PREVIEW:
            self._draw_vs_preview()
        elif self.state == DojoState.BATTLE:
            self._draw_battle()
        elif self.state == DojoState.RESULT:
            self._draw_result()
        elif self.state == DojoState.PERK_SELECT:
            self._draw_perk_select()
        elif self.state == DojoState.GAME_OVER:
            self._draw_game_over()

    def get_result(self) -> Dict:
        """결과 반환"""
        return {
            "winnings": self.total_gold_earned,
            "final_gold": self.player_gold + self.total_gold_earned,
            "win_streak": self.best_streak,
            "total_wins": self.total_wins,
            "mode": "dojo",
        }

    # ========================================================================
    # 텍스트 렌더링 유틸
    # ========================================================================
    def _render_text(self, font_key: str, text: str, color: Tuple, target_surf=None,
                     center_x: int = 0, y: int = 0):
        """캐싱된 텍스트 렌더링"""
        cache_key = (font_key, text, color)
        if cache_key not in self._text_cache:
            font = self.fonts.get(font_key)
            if font:
                surf, rect = font.render(text, color)
                self._text_cache[cache_key] = (surf, rect)
            else:
                return
        surf, rect = self._text_cache[cache_key]
        if target_surf:
            target_surf.blit(surf, (center_x - surf.get_width() // 2, y))
        else:
            self.screen.blit(surf, (center_x - surf.get_width() // 2, y))

    def _render_text_left(self, font_key: str, text: str, color: Tuple, x: int, y: int):
        """좌측 정렬 텍스트"""
        font = self.fonts.get(font_key)
        if font:
            surf, _ = font.render(text, color)
            self.screen.blit(surf, (x, y))

    # ========================================================================
    # 난이도 선택
    # ========================================================================
    def _handle_difficulty_event(self, event) -> bool:
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos
            card_w, card_h = 180, 220
            total_w = len(DOJO_DIFFICULTIES) * card_w + (len(DOJO_DIFFICULTIES) - 1) * 20
            start_x = SCREEN_WIDTH // 2 - total_w // 2
            y = SCREEN_HEIGHT // 2 - card_h // 2

            for i, diff in enumerate(DOJO_DIFFICULTIES):
                cx = start_x + i * (card_w + 20)
                rect = pygame.Rect(cx, y, card_w, card_h)
                if rect.collidepoint(mx, my):
                    # 골드 체크
                    if self.player_gold >= diff["entry_fee"]:
                        self.difficulty = diff["key"]
                        self.difficulty_data = diff
                        self.lives = diff["lives"]
                        self.max_lives = diff["lives"]
                        self.player_gold -= diff["entry_fee"]
                        self._play_sound("click")
                        # 영웅 선택으로
                        self.state = DojoState.HERO_SELECT
                    else:
                        self._play_sound("error")
                    return False

        if event.type == pygame.MOUSEMOTION:
            mx, my = event.pos
            card_w, card_h = 180, 220
            total_w = len(DOJO_DIFFICULTIES) * card_w + (len(DOJO_DIFFICULTIES) - 1) * 20
            start_x = SCREEN_WIDTH // 2 - total_w // 2
            y = SCREEN_HEIGHT // 2 - card_h // 2
            old_hover = self.hover_difficulty_index
            self.hover_difficulty_index = -1
            for i in range(len(DOJO_DIFFICULTIES)):
                cx = start_x + i * (card_w + 20)
                rect = pygame.Rect(cx, y, card_w, card_h)
                if rect.collidepoint(mx, my):
                    self.hover_difficulty_index = i
                    break
            if self.hover_difficulty_index != old_hover and self.hover_difficulty_index >= 0:
                self._play_sound("hover")

        return False

    def _draw_difficulty_select(self):
        """난이도 선택 화면"""
        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        # 반투명 오버레이
        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 160))
        self.screen.blit(overlay, (0, 0))

        # 타이틀
        self._render_text("medium", "도장깨기", ET["text_title"],
                          center_x=SCREEN_WIDTH // 2, y=100)
        self._render_text("small", "끊임없는 1:1 대결! 연승을 이어가라",
                          ET["text_subtitle"], center_x=SCREEN_WIDTH // 2, y=140)

        # 난이도 카드
        card_w, card_h = 180, 220
        total_w = len(DOJO_DIFFICULTIES) * card_w + (len(DOJO_DIFFICULTIES) - 1) * 20
        start_x = SCREEN_WIDTH // 2 - total_w // 2
        y = SCREEN_HEIGHT // 2 - card_h // 2

        for i, diff in enumerate(DOJO_DIFFICULTIES):
            cx = start_x + i * (card_w + 20)
            is_hover = (i == self.hover_difficulty_index)
            can_afford = self.player_gold >= diff["entry_fee"]

            # 카드 배경
            bg_color = diff["color"] if is_hover else ET["card_bg"]
            alpha = 255 if is_hover else 200
            card_surf = _get_arena_surface(card_w, card_h)
            pygame.draw.rect(card_surf, (*bg_color[:3], alpha), (0, 0, card_w, card_h), border_radius=12)

            # 테두리
            border_color = diff["border_color"] if is_hover else ET["card_border"]
            pygame.draw.rect(card_surf, border_color, (0, 0, card_w, card_h), 3, border_radius=12)
            self.screen.blit(card_surf, (cx, y))

            # 난이도 이름
            self._render_text("medium", diff["name"],
                              (255, 255, 255) if is_hover else ET["text_title"],
                              center_x=cx + card_w // 2, y=y + 20)

            # 설명
            desc_lines = diff["description"].split("\n")
            for li, line in enumerate(desc_lines):
                self._render_text("small", line, ET["text_body"],
                                  center_x=cx + card_w // 2, y=y + 65 + li * 22)

            # 입장료
            fee_color = (255, 200, 60) if can_afford else (200, 80, 80)
            self._render_text("small", f"입장료: {diff['entry_fee']}G", fee_color,
                              center_x=cx + card_w // 2, y=y + 140)

            # 보상 배율
            self._render_text("small", f"보상 {diff['reward_multiplier']}x배",
                              ET["text_hint"], center_x=cx + card_w // 2, y=y + 170)

            # 골드 부족 표시
            if not can_afford:
                dim = _get_arena_surface(card_w, card_h)
                dim.fill((0, 0, 0, 120))
                self.screen.blit(dim, (cx, y))
                self._render_text("small", "골드 부족", (200, 80, 80),
                                  center_x=cx + card_w // 2, y=y + card_h // 2 - 8)

        # 보유 골드
        self._render_text("small", f"보유 골드: {self.player_gold}G",
                          ET["gold_bright"], center_x=SCREEN_WIDTH // 2, y=y + card_h + 30)

        # ESC 안내
        self._render_text("small", "ESC: 나가기", ET["text_hint"],
                          center_x=SCREEN_WIDTH // 2, y=SCREEN_HEIGHT - 50)

    # ========================================================================
    # 영웅 선택
    # ========================================================================
    def _handle_hero_select_event(self, event) -> bool:
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos
            # 하단 영웅만 선택 가능 (플레이어는 하단 패들)
            heroes = BOTTOM_HEROES
            card_w, card_h = 90, 130
            cols = min(6, len(heroes))
            gap = 12
            total_w = cols * card_w + (cols - 1) * gap
            start_x = SCREEN_WIDTH // 2 - total_w // 2
            start_y = 250

            for i, hero in enumerate(heroes):
                row = i // cols
                col = i % cols
                cx = start_x + col * (card_w + gap)
                cy = start_y + row * (card_h + gap)
                rect = pygame.Rect(cx, cy, card_w, card_h)
                if rect.collidepoint(mx, my):
                    self.player_hero = hero
                    self._play_sound("click")
                    self._assign_all_skills()
                    self._start_skill_reveal()
                    return False

        if event.type == pygame.MOUSEMOTION:
            mx, my = event.pos
            heroes = BOTTOM_HEROES
            card_w, card_h = 90, 130
            cols = min(6, len(heroes))
            gap = 12
            total_w = cols * card_w + (cols - 1) * gap
            start_x = SCREEN_WIDTH // 2 - total_w // 2
            start_y = 250
            old_hover = self.hover_hero_index
            self.hover_hero_index = -1
            for i, hero in enumerate(heroes):
                row = i // cols
                col = i % cols
                cx = start_x + col * (card_w + gap)
                cy = start_y + row * (card_h + gap)
                rect = pygame.Rect(cx, cy, card_w, card_h)
                if rect.collidepoint(mx, my):
                    self.hover_hero_index = i
                    break
            if self.hover_hero_index != old_hover and self.hover_hero_index >= 0:
                self._play_sound("hover")

        return False

    def _draw_hero_select(self):
        """영웅 선택 화면"""
        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 160))
        self.screen.blit(overlay, (0, 0))

        self._render_text("medium", "영웅 선택", ET["text_title"],
                          center_x=SCREEN_WIDTH // 2, y=80)
        self._render_text("small", "도장깨기에 함께할 영웅을 선택하세요",
                          ET["text_subtitle"], center_x=SCREEN_WIDTH // 2, y=120)

        # 난이도 표시
        self._render_text("small", f"난이도: {self.difficulty_data['name']}  |  라이프: {'❤' * self.lives}",
                          ET["text_hint"], center_x=SCREEN_WIDTH // 2, y=160)

        heroes = BOTTOM_HEROES
        card_w, card_h = 90, 130
        cols = min(6, len(heroes))
        gap = 12
        total_w = cols * card_w + (cols - 1) * gap
        start_x = SCREEN_WIDTH // 2 - total_w // 2
        start_y = 250

        for i, hero in enumerate(heroes):
            row = i // cols
            col = i % cols
            cx = start_x + col * (card_w + gap)
            cy = start_y + row * (card_h + gap)
            is_hover = (i == self.hover_hero_index)

            # 카드 배경
            card_surf = _get_arena_surface(card_w, card_h)
            bg = hero["color"] if is_hover else ET["card_bg"]
            alpha = 220 if is_hover else 180
            pygame.draw.rect(card_surf, (*bg[:3], alpha), (0, 0, card_w, card_h), border_radius=8)
            border = (255, 215, 50) if is_hover else ET["card_border"]
            pygame.draw.rect(card_surf, border, (0, 0, card_w, card_h), 2, border_radius=8)
            self.screen.blit(card_surf, (cx, cy))

            # 페이스카드
            face = _load_facecard(hero["id"], card_w - 10, 60)
            if face:
                self.screen.blit(face, (cx + 5, cy + 5))
            else:
                # 색상 원
                pygame.draw.circle(self.screen, hero["color"],
                                   (cx + card_w // 2, cy + 35), 20)

            # 이름
            self._render_text("small", hero["name"],
                              (255, 255, 255) if is_hover else ET["text_body"],
                              center_x=cx + card_w // 2, y=cy + 75)

            # 타이틀
            self._render_text("small", hero["title"], ET["text_hint"],
                              center_x=cx + card_w // 2, y=cy + 95)

            # 스타일
            style_name = STYLE_KOREAN_NAMES.get(hero["style"], "")
            self._render_text("small", style_name, hero["color"],
                              center_x=cx + card_w // 2, y=cy + 112)

        # 호버 중인 영웅 상세 정보
        if 0 <= self.hover_hero_index < len(heroes):
            hero = heroes[self.hover_hero_index]
            info_y = start_y + ((len(heroes) - 1) // cols + 1) * (card_h + gap) + 20
            self._render_text("small", hero["description"], ET["text_body"],
                              center_x=SCREEN_WIDTH // 2, y=info_y)

    # ========================================================================
    # 스킬 배정 & 공개 연출
    # ========================================================================
    def _assign_all_skills(self):
        """모든 영웅에 랜덤 스킬 배정"""
        if not HERO_SKILLS_AVAILABLE:
            return
        for hero in ARENA_HEROES:
            skills = HERO_SKILLS.get(hero["id"], [])
            if skills:
                self.hero_selected_skills[hero["id"]] = random.randint(0, len(skills) - 1)

    def _start_skill_reveal(self):
        """스킬 공개 연출 시작"""
        self.state = DojoState.SKILL_REVEAL
        self.skill_reveal_timer = 0.0
        self.skill_reveal_phase = "rolling"
        if self.player_hero and HERO_SKILLS_AVAILABLE:
            self.skill_reveal_result = self.hero_selected_skills.get(
                self.player_hero["id"], 0)
            self.player_hero_skill_index = self.skill_reveal_result

    def _handle_skill_reveal_event(self, event) -> bool:
        if event.type == pygame.KEYDOWN or event.type == pygame.MOUSEBUTTONDOWN:
            if self.skill_reveal_phase == "done":
                self._start_next_opponent()
                return False
        return False

    def _update_skill_reveal(self, dt):
        self.skill_reveal_timer += dt
        if self.skill_reveal_phase == "rolling":
            if self.skill_reveal_timer >= 1.5:
                self.skill_reveal_phase = "selected"
                self.skill_reveal_timer = 0.0
                self._play_sound("result")
        elif self.skill_reveal_phase == "selected":
            if self.skill_reveal_timer >= 0.8:
                self.skill_reveal_phase = "done"

    def _draw_skill_reveal(self):
        """스킬 공개 연출"""
        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        self._render_text("medium", "스킬 결정", ET["text_title"],
                          center_x=SCREEN_WIDTH // 2, y=150)

        if self.player_hero and HERO_SKILLS_AVAILABLE:
            hero_id = self.player_hero["id"]
            skills = HERO_SKILLS.get(hero_id, [])

            if self.skill_reveal_phase == "rolling":
                # 슬롯머신 효과
                idx = int(self.skill_reveal_timer * 8) % max(1, len(skills))
                if skills:
                    skill = skills[idx]
                    self._render_text("medium", skill.korean_name,
                                      (200, 200, 200),
                                      center_x=SCREEN_WIDTH // 2, y=320)
            elif self.skill_reveal_phase in ("selected", "done"):
                idx = self.skill_reveal_result
                if 0 <= idx < len(skills):
                    skill = skills[idx]
                    self._render_text("medium", skill.korean_name,
                                      ET["gold_bright"],
                                      center_x=SCREEN_WIDTH // 2, y=320)
                    self._render_text("small", skill.description,
                                      ET["text_body"],
                                      center_x=SCREEN_WIDTH // 2, y=370)

            if self.skill_reveal_phase == "done":
                self._render_text("small", "클릭하여 계속",
                                  ET["text_hint"],
                                  center_x=SCREEN_WIDTH // 2, y=500)

    # ========================================================================
    # 상대 생성 & VS 프리뷰
    # ========================================================================
    def _start_next_opponent(self):
        """다음 상대 생성"""
        # 16명 풀에서 랜덤 (플레이어 영웅 제외, 최근 상대 피하기)
        candidates = [h for h in ARENA_HEROES
                      if h["id"] != self.player_hero["id"]
                      and h["id"] not in self._used_opponents[-2:]]
        if not candidates:
            candidates = [h for h in ARENA_HEROES if h["id"] != self.player_hero["id"]]

        self.current_opponent = random.choice(candidates)
        self._used_opponents.append(self.current_opponent["id"])
        if len(self._used_opponents) > 5:
            self._used_opponents.pop(0)

        # 상대 스킬 배정
        if HERO_SKILLS_AVAILABLE:
            opp_skills = HERO_SKILLS.get(self.current_opponent["id"], [])
            if opp_skills:
                self.opponent_skill_index = random.randint(0, len(opp_skills) - 1)

        # 상대 스탯 스케일링 (연승에 비례)
        streak_bonus = self.win_streak * 0.03  # 연승 10회 = +30%
        self.current_stat_mult = self.difficulty_data["stat_base"] + streak_bonus

        # VS 프리뷰
        self.state = DojoState.VS_PREVIEW
        self.vs_timer = 0.0

    def _update_vs_preview(self, dt):
        self.vs_timer += dt
        if self.vs_timer >= self.vs_duration:
            self._start_battle()

    def _draw_vs_preview(self):
        """VS 프리뷰 (빠른 전환)"""
        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 연승 표시
        if self.win_streak > 0:
            streak_color = (255, 100, 50) if self.win_streak >= 10 else ET["gold_bright"]
            self._render_text("medium", f"{self.win_streak}연승",
                              streak_color, center_x=SCREEN_WIDTH // 2, y=80)

        # 상대 영웅 이름
        if self.current_opponent:
            progress = min(1.0, self.vs_timer / self.vs_duration)
            # 슬라이드 인 효과
            slide_x = int(200 * (1 - progress))

            # 상단: 상대
            opp = self.current_opponent
            self._render_text("medium", f"VS {opp['name']}",
                              opp["color"],
                              center_x=SCREEN_WIDTH // 2 + slide_x, y=280)
            self._render_text("small", opp["title"], ET["text_body"],
                              center_x=SCREEN_WIDTH // 2 + slide_x, y=330)

            # 하단: 플레이어
            if self.player_hero:
                self._render_text("small", self.player_hero["name"],
                                  self.player_hero["color"],
                                  center_x=SCREEN_WIDTH // 2 - slide_x, y=420)

        # 라이프 표시
        self._draw_lives_ui(SCREEN_WIDTH // 2, 560)

    # ========================================================================
    # 배틀
    # ========================================================================
    def _start_battle(self):
        """배틀 시작"""
        if self.battle_callback:
            # ★ 실제 게임 엔진(스테이지30)으로 배틀 실행
            self._run_real_engine_battle()
            return

        # 폴백: 내부 물리 시스템 (battle_callback 없을 때)
        self._run_internal_battle()

    def _run_real_engine_battle(self):
        """실제 게임 엔진(스테이지30)으로 배틀 실행 (블로킹)"""
        import pingfighter

        # 상대(상단) 영웅 데이터 준비 - 스탯 스케일링
        top_hero = dict(self.current_opponent)
        top_hero["speed"] = top_hero["speed"] * self.current_stat_mult
        top_hero["reaction"] = top_hero["reaction"] * self.current_stat_mult
        top_hero["power"] = top_hero["power"] * min(self.current_stat_mult, 1.5)
        top_hero["accuracy"] = min(0.98, top_hero["accuracy"] * self.current_stat_mult)
        top_hero["_selected_skill_idx"] = self.opponent_skill_index

        # 플레이어(하단) 영웅 데이터 준비 - 퍽 적용
        bottom_hero = dict(self.player_hero)
        self._apply_perks_to_hero(bottom_hero)
        hero_id = self.player_hero["id"]
        if self.hero_has_both_skills.get(hero_id, False):
            bottom_hero["_selected_skill_idx"] = -1
        else:
            bottom_hero["_selected_skill_idx"] = self.player_hero_skill_index

        # pingfighter에 pending 데이터 설정 (start_arena_battle에서 읽음)
        pingfighter._arena_pending_perk_data = self  # self.hero_perks, self.win_score 참조
        pingfighter._arena_pending_skill_selections = self.hero_selected_skills
        pingfighter._arena_pending_both_skills = self.hero_has_both_skills
        # 도장깨기는 호위무사 없음
        pingfighter._arena_pending_top_guards = []
        pingfighter._arena_pending_bottom_guards = []

        # ★ battle_callback 호출 (블로킹 - main(30) 실행)
        result = self.battle_callback(top_hero, bottom_hero)

        # BGM 복원 (배틀 후 투기장 로비 BGM)
        try:
            import bgm_manager
            bgm_manager.play_colosseum_room_bgm()
        except Exception:
            pass

        # 결과 처리
        if result is None:
            # ESC 나가기
            self.exit_requested = True
            return

        if result:
            # 하단(플레이어) 승리
            self._on_score("player")
        else:
            # 상단(상대) 승리
            self._on_score("opponent")

    def _run_internal_battle(self):
        """내부 물리 시스템으로 배틀 실행 (폴백)"""
        self.state = DojoState.BATTLE
        self.battle_active = True
        self.score_top = 0
        self.score_bottom = 0

        # 상대(상단) 패들 생성 - 스탯 스케일링 적용
        opp_data = dict(self.current_opponent)
        opp_data["speed"] = opp_data["speed"] * self.current_stat_mult
        opp_data["reaction"] = opp_data["reaction"] * self.current_stat_mult
        opp_data["power"] = opp_data["power"] * min(self.current_stat_mult, 1.5)
        opp_data["accuracy"] = min(0.98, opp_data["accuracy"] * self.current_stat_mult)

        self.top_paddle = AIPaddleController(opp_data, is_top=True)

        # 플레이어(하단) 패들 생성 - 퍽 적용
        player_data = dict(self.player_hero)
        self._apply_perks_to_hero(player_data)
        self.bottom_paddle = AIPaddleController(player_data, is_top=False)

        # 공 생성
        self.ball = ArenaBall()
        self.ball_spawn_animation = BallSpawnAnimation()
        self.spawn_phase = True

        # 서브 방향 (실점한 쪽이 서브 → 첫 라운드는 랜덤)
        serve_dir = random.choice([-1, 1])
        self.ball_spawn_animation.start(serve_dir)

        # 스킬 매니저 초기화
        if HERO_SKILLS_AVAILABLE:
            self.skill_manager = get_skill_manager()
            if self.skill_manager:
                self.skill_manager.reset()
                # 플레이어 영웅 스킬
                self._register_hero_skills(self.player_hero, is_top=False)
                # 상대 영웅 스킬
                self._register_opponent_skills()

    def _register_hero_skills(self, hero, is_top):
        """영웅 스킬 등록 (init_hero_skills API 사용)"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE:
            return
        hero_id = hero["id"]
        skill_idx = self.player_hero_skill_index if not is_top else self.opponent_skill_index
        # 양쪽 스킬 보유 시 -1 (전체 활성화)
        if self.hero_has_both_skills.get(hero_id, False):
            skill_idx = -1
        self.skill_manager.init_hero_skills(hero_id, is_top=is_top, selected_skill_index=skill_idx)

    def _register_opponent_skills(self):
        """상대 영웅 스킬 등록"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE or not self.current_opponent:
            return
        opp_id = self.current_opponent["id"]
        self.skill_manager.init_hero_skills(opp_id, is_top=True, selected_skill_index=self.opponent_skill_index)

    def _apply_perks_to_hero(self, hero_data):
        """퍽 효과를 영웅 데이터에 적용"""
        if not self.player_hero:
            return
        hero_id = self.player_hero["id"]
        perks = self.hero_perks.get(hero_id, [])
        for perk in perks:
            etype = perk.get("effect_type")
            val = perk.get("value", 0)
            if etype == "move_speed":
                hero_data["speed"] = hero_data["speed"] * (1 + val)
            elif etype == "paddle_enlarge":
                hero_data["_paddle_scale"] = hero_data.get("_paddle_scale", 1.0) + val

    def _draw_perk_icon(self, surface, perk_id, cx, cy, size):
        """퍽 아이콘 그리기 (ColosseumsArena의 아이콘 메서드 재사용)"""
        if not hasattr(self, '_icon_proxy'):
            try:
                # ColosseumsArena의 아이콘 그리기 메서드만 사용하는 경량 프록시
                cls = _arena_mod.ColosseumsArena
                self._icon_proxy = cls.__new__(cls)  # __init__ 없이 메서드만 접근
            except Exception:
                self._icon_proxy = None
        if self._icon_proxy:
            try:
                self._icon_proxy._draw_perk_icon(surface, perk_id, cx, cy, size)
            except Exception:
                pass

    def get_hero_perk_multipliers(self, hero_id: str) -> Dict[str, float]:
        """영웅의 퍽에서 멀티플라이어 계산 (apply_arena_perks_for_battle 호환)"""
        perks = self.hero_perks.get(hero_id, [])
        mults = {
            "move_speed": 1.0,
            "dash_cooldown": 1.0,
            "skill_cooldown": 1.0,
            "guard_cooldown": 1.0,
            "dash_tokens": 0,
            "dash_distance": 1.0,
            "retry_chance": 0.0,
            "guard_extra_skill": False,
            "magic_immunity": 0.0,
            "laurel_shield": 0,
            "paddle_enlarge": 1.0,
            "recall_guard": False,
            "instant_cooldown": 0.0,
        }
        for perk in perks:
            etype = perk.get("effect_type", "")
            val = perk.get("value", 0)
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
                mults["guard_cooldown"] += 0.35  # 승급 패널티: 호위무사 스킬 쿨타임 35% 증가
            elif etype == "instant_cooldown":
                mults["instant_cooldown"] = val
        return mults

    def _handle_battle_event(self, event) -> bool:
        # 배속 버튼 클릭
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos
            for mult, rect in self.speed_btn_rects.items():
                if rect.collidepoint(mx, my):
                    self.speed_multiplier = mult
                    return False
        return False

    def _update_battle(self, dt):
        """배틀 업데이트"""
        if not self.battle_active:
            return

        # 배속 적용
        effective_dt = dt * self.speed_multiplier

        # 공 생성 애니메이션
        if self.spawn_phase and self.ball_spawn_animation:
            if self.ball_spawn_animation.update(effective_dt):
                self.spawn_phase = False
                serve_dir = self.ball_spawn_animation.serve_direction
                self.ball.reset(direction=serve_dir)
            return

        # 패들 AI 업데이트
        if self.ball and self.top_paddle:
            self.top_paddle.update(
                self.ball.x, self.ball.y,
                self.ball.vx, self.ball.vy, effective_dt
            )
        if self.ball and self.bottom_paddle:
            self.bottom_paddle.update(
                self.ball.x, self.ball.y,
                self.ball.vx, self.ball.vy, effective_dt
            )

        # 공 업데이트
        if self.ball:
            result = self.ball.update(effective_dt)

            # 패들 충돌
            if self.top_paddle and self.ball.check_paddle_collision(self.top_paddle):
                if self.skill_manager:
                    self.skill_manager.on_ball_hit("top", self.top_paddle,
                                                    self.bottom_paddle, self.ball)
            if self.bottom_paddle and self.ball.check_paddle_collision(self.bottom_paddle):
                if self.skill_manager:
                    self.skill_manager.on_ball_hit("bottom", self.bottom_paddle,
                                                    self.top_paddle, self.ball)

            # 득점
            if result == "bottom":
                self.score_bottom += 1
                self._on_score("player")
            elif result == "top":
                self.score_top += 1
                self._on_score("opponent")

        # 스킬 업데이트
        if self.skill_manager and self.top_paddle and self.bottom_paddle and self.ball:
            self.skill_manager.update(effective_dt, self.top_paddle,
                                       self.bottom_paddle, self.ball)

    def _on_score(self, scorer: str):
        """득점 처리 (1점이면 끝)"""
        self.battle_active = False
        self.result_winner = scorer
        self.result_timer = 0.0
        self.state = DojoState.RESULT

        if scorer == "player":
            self.win_streak += 1
            self.total_wins += 1
            self.best_streak = max(self.best_streak, self.win_streak)
            # 골드 보상
            gold = int(DOJO_GOLD_PER_WIN * self.difficulty_data["reward_multiplier"])
            # 연승 보너스 (10연승마다 +50%)
            streak_bonus = 1.0 + (self.win_streak // 10) * 0.5
            gold = int(gold * streak_bonus)
            self.total_gold_earned += gold
        else:
            self.lives -= 1
            self.life_lost_anim = 1.0
            self.win_streak = 0

    def _update_result(self, dt):
        self.result_timer += dt
        if self.life_lost_anim > 0:
            self.life_lost_anim = max(0, self.life_lost_anim - dt * 2)

        if self.result_timer >= self.result_duration:
            if self.result_winner == "player":
                # 5연승마다 퍽 선택
                if self.win_streak > 0 and self.win_streak % 5 == 0:
                    self._start_perk_select()
                else:
                    self._start_next_opponent()
            else:
                # 패배
                if self.lives <= 0:
                    self.state = DojoState.GAME_OVER
                    self.game_over_timer = 0.0
                else:
                    self._start_next_opponent()

    def _draw_battle(self):
        """배틀 화면 (기존 토너먼트와 동일한 렌더링)"""
        shake_x, shake_y = 0, 0
        if self.skill_manager:
            shake_x, shake_y = self.skill_manager.get_screen_shake()

        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X + shake_x, offset_y=shake_y)
        else:
            pygame.draw.rect(self.screen, (194, 158, 108),
                             (GAME_AREA_X + shake_x, shake_y, GAME_AREA_WIDTH, SCREEN_HEIGHT))

        # 중앙선
        center_y = SCREEN_HEIGHT // 2
        pygame.draw.line(self.screen, (164, 128, 88),
                         (GAME_AREA_X + 30 + shake_x, center_y + shake_y),
                         (GAME_AREA_X + GAME_AREA_WIDTH - 30 + shake_x, center_y + shake_y), 3)
        pygame.draw.circle(self.screen, (164, 128, 88),
                           (GAME_AREA_X + GAME_AREA_WIDTH // 2 + shake_x, center_y + shake_y), 120, 2)

        # 스킬 이펙트
        if self.skill_manager and self.top_paddle and self.bottom_paddle and self.ball:
            self.skill_manager.draw_skills(self.screen, self.top_paddle, self.bottom_paddle, self.ball)

        # 패들 대쉬 효과
        if self.top_paddle:
            self.top_paddle.draw_dash_effects(self.screen)
        if self.bottom_paddle:
            self.bottom_paddle.draw_dash_effects(self.screen)

        # 패들 그리기
        self._draw_paddle(self.top_paddle, self.current_opponent, "down", shake_x, shake_y)
        self._draw_paddle(self.bottom_paddle, self.player_hero, "up", shake_x, shake_y)

        # 공 생성 애니메이션
        if self.spawn_phase and self.ball_spawn_animation:
            self.ball_spawn_animation.draw(self.screen)

        # 공
        if self.ball and self.ball.visible:
            self._draw_ball(shake_x, shake_y)

        # 스킬 화면 효과
        if self.skill_manager:
            self.skill_manager.draw_screen_effects(self.screen)

        # 필러
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        # 도장깨기 HUD
        self._draw_dojo_hud()

        # 배속 버튼
        self._draw_speed_buttons()

        # 전경
        if self.arena_background:
            self.arena_background.draw_foreground(self.screen, offset_x=GAME_AREA_X)

    def _draw_paddle(self, paddle, hero, facing, shake_x, shake_y):
        """패들 그리기"""
        if not paddle or not hero:
            return
        paddle_rect = paddle.get_rect()
        scaled_width = int(PADDLE_WIDTH * paddle.paddle_scale)

        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero["id"],
                paddle_rect.centerx + shake_x,
                paddle_rect.centery + shake_y,
                scaled_width, PADDLE_HEIGHT,
                facing=facing, color=hero["color"]
            )
        else:
            scaled_rect = pygame.Rect(
                paddle_rect.centerx - scaled_width // 2 + shake_x,
                paddle_rect.y + shake_y,
                scaled_width, PADDLE_HEIGHT
            )
            shadow = scaled_rect.copy()
            shadow.y += 3
            pygame.draw.rect(self.screen, (60, 50, 40), shadow, border_radius=4)
            pygame.draw.rect(self.screen, hero["color"], scaled_rect, border_radius=4)

    def _draw_ball(self, shake_x, shake_y):
        """공 그리기"""
        ball_x = int(self.ball.x) + shake_x
        ball_y = int(self.ball.y) + shake_y

        # 잔상
        for tx, ty, alpha in self.ball.trail:
            trail_alpha = int(100 * alpha)
            if trail_alpha > 10:
                trail_size = int(BALL_SIZE * 0.7 * alpha)
                if trail_size > 1:
                    trail_surf = _get_arena_surface(trail_size * 2, trail_size * 2)
                    pygame.draw.circle(trail_surf, (255, 255, 200, trail_alpha),
                                       (trail_size, trail_size), trail_size)
                    self.screen.blit(trail_surf, (int(tx) + shake_x - trail_size,
                                                   int(ty) + shake_y - trail_size))

        # 그림자
        pygame.draw.circle(self.screen, (60, 50, 40), (ball_x + 2, ball_y + 3), BALL_SIZE)
        # 본체
        ball_color = (255, 255, 255)
        if self.skill_manager:
            if self.skill_manager.game_state.get('ball_on_fire', False):
                ball_color = (255, 200, 100)
            elif self.skill_manager.game_state.get('ball_holy', False):
                ball_color = (255, 240, 180)
        pygame.draw.circle(self.screen, ball_color, (ball_x, ball_y), BALL_SIZE)
        pygame.draw.circle(self.screen, (255, 255, 200), (ball_x - 3, ball_y - 3), 3)

    def _draw_dojo_hud(self):
        """도장깨기 전용 HUD (라이프, 연승, 골드)"""
        # ── 라이프 (왼쪽 필러 상단) ──
        self._draw_lives_ui(40, 30)

        # ── 연승 카운터 (오른쪽 필러 상단) ──
        if self.win_streak > 0:
            streak_color = (255, 100, 50) if self.win_streak >= 10 else ET["gold_bright"]
            self._render_text("small", f"{self.win_streak}연승",
                              streak_color, center_x=720, y=30)

        # ── 누적 골드 (오른쪽 필러) ──
        self._render_text("small", f"{self.total_gold_earned}G",
                          ET["gold_bright"], center_x=720, y=55)

        # ── 상대 이름 (상단 중앙) ──
        if self.current_opponent:
            self._render_text("small", self.current_opponent["name"],
                              self.current_opponent["color"],
                              center_x=SCREEN_WIDTH // 2, y=5)

    def _draw_lives_ui(self, center_x, y):
        """라이프 하트 그리기"""
        heart_size = 12
        total_w = self.max_lives * (heart_size * 2 + 4)
        sx = center_x - total_w // 2

        for i in range(self.max_lives):
            hx = sx + i * (heart_size * 2 + 4) + heart_size
            hy = y + heart_size

            if i < self.lives:
                # 살아있는 하트 - 빨간색
                color = (220, 40, 40)
                # 하트 모양 (간략화)
                pygame.draw.circle(self.screen, color, (hx - 5, hy - 3), 7)
                pygame.draw.circle(self.screen, color, (hx + 5, hy - 3), 7)
                pygame.draw.polygon(self.screen, color, [
                    (hx - 12, hy), (hx, hy + 12), (hx + 12, hy)
                ])
            else:
                # 잃은 하트 - 회색
                color = (80, 80, 80)
                pygame.draw.circle(self.screen, color, (hx - 5, hy - 3), 7)
                pygame.draw.circle(self.screen, color, (hx + 5, hy - 3), 7)
                pygame.draw.polygon(self.screen, color, [
                    (hx - 12, hy), (hx, hy + 12), (hx + 12, hy)
                ])

    def _draw_speed_buttons(self):
        """배속 버튼"""
        self.speed_btn_rects = {}
        speeds = [1, 2, 3]
        btn_w, btn_h = 30, 20
        sx = SCREEN_WIDTH - 35
        sy = SCREEN_HEIGHT - 90

        for i, spd in enumerate(speeds):
            bx = sx
            by = sy + i * (btn_h + 4)
            rect = pygame.Rect(bx, by, btn_w, btn_h)
            self.speed_btn_rects[spd] = rect

            is_active = (self.speed_multiplier == spd)
            bg = ET["gold_dark"] if is_active else ET["bg_panel"]
            pygame.draw.rect(self.screen, bg, rect, border_radius=3)
            border = ET["gold_bright"] if is_active else ET["card_border"]
            pygame.draw.rect(self.screen, border, rect, 1, border_radius=3)

            label = f"x{spd}"
            font = self.fonts.get("small")
            if font:
                surf, _ = font.render(label, (255, 255, 255) if is_active else ET["text_hint"])
                self.screen.blit(surf, (bx + btn_w // 2 - surf.get_width() // 2,
                                         by + btn_h // 2 - surf.get_height() // 2))

    # ========================================================================
    # 결과 화면
    # ========================================================================
    def _draw_result(self):
        """결과 표시 (짧은 전환)"""
        # 배틀 화면 위에 오버레이
        self._draw_battle()

        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 140))
        self.screen.blit(overlay, (0, 0))

        if self.result_winner == "player":
            self._render_text("medium", "승리!", (100, 255, 100),
                              center_x=SCREEN_WIDTH // 2, y=SCREEN_HEIGHT // 2 - 40)
            gold = int(DOJO_GOLD_PER_WIN * self.difficulty_data["reward_multiplier"])
            streak_bonus = 1.0 + (self.win_streak // 10) * 0.5
            gold = int(gold * streak_bonus)
            self._render_text("small", f"+{gold}G",
                              ET["gold_bright"],
                              center_x=SCREEN_WIDTH // 2, y=SCREEN_HEIGHT // 2 + 10)
        else:
            self._render_text("medium", "실점!", (255, 80, 80),
                              center_x=SCREEN_WIDTH // 2, y=SCREEN_HEIGHT // 2 - 40)
            if self.lives <= 0:
                self._render_text("small", "라이프 소진...",
                                  (200, 100, 100),
                                  center_x=SCREEN_WIDTH // 2, y=SCREEN_HEIGHT // 2 + 10)
            else:
                self._render_text("small", f"남은 라이프: {'❤' * self.lives}",
                                  (200, 150, 150),
                                  center_x=SCREEN_WIDTH // 2, y=SCREEN_HEIGHT // 2 + 10)

    # ========================================================================
    # 퍽 선택
    # ========================================================================
    def _start_perk_select(self):
        """퍽 선택 시작 (5연승마다)"""
        self.state = DojoState.PERK_SELECT
        self.perk_selected_index = 0
        self.perk_anim_timer = 0.0
        self.perk_anim_phase = "appearing"
        self.perk_selected_id = None
        self.perk_frame_count = 0
        self.perk_particles = []

        # 퍽 풀 구성
        pool = self._build_perk_pool()
        self.current_perk_options = random.sample(pool, min(3, len(pool)))
        self.perk_card_offsets = [-400.0, 500.0, 400.0]

    def _build_perk_pool(self):
        """현재 영웅에 맞는 퍽 풀"""
        owned_ids = set()
        if self.player_hero:
            for perk in self.hero_perks.get(self.player_hero["id"], []):
                owned_ids.add(perk["id"])

        pool = []
        for p in ARENA_PERK_POOL:
            if p["id"] in owned_ids:
                continue
            # 도장깨기에서 불필요한 퍽 제외
            if p.get("effect_type") in ("guard_cooldown", "guard_extra_skill"):
                continue  # 호위무사 관련 퍽 제외
            pool.append(p)

        # 미선택 스킬 퍽
        if self.player_hero and HERO_SKILLS_AVAILABLE:
            hero_id = self.player_hero["id"]
            if not self.hero_has_both_skills.get(hero_id, False):
                current_idx = self.hero_selected_skills.get(hero_id, 0)
                other_idx = 1 - current_idx
                skills = HERO_SKILLS.get(hero_id, [])
                if len(skills) > other_idx:
                    other_skill = skills[other_idx]
                    pool.append({
                        "id": f"skill_{other_skill.skill_id}",
                        "name": other_skill.korean_name,
                        "description": f"추가 스킬 획득\n(쿨타임 30% 증가)",
                        "icon_color": tuple(self.player_hero.get("color", (200, 200, 100))),
                        "effect_type": "add_skill",
                        "value": other_idx,
                    })

        return pool

    def _handle_perk_event(self, event) -> bool:
        if self.perk_anim_phase != "active":
            return False

        num_options = len(self.current_perk_options)

        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_LEFT, pygame.K_a):
                self.perk_selected_index = max(0, self.perk_selected_index - 1)
                self._play_sound("hover")
            elif event.key in (pygame.K_RIGHT, pygame.K_d):
                self.perk_selected_index = min(num_options - 1, self.perk_selected_index + 1)
                self._play_sound("hover")
            elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._confirm_perk()

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos
            card_w, card_h = 160, 240
            gap = 20
            total_w = num_options * card_w + (num_options - 1) * gap
            sx = SCREEN_WIDTH // 2 - total_w // 2
            cy = SCREEN_HEIGHT // 2 - card_h // 2

            for i in range(num_options):
                rect = pygame.Rect(sx + i * (card_w + gap), cy, card_w, card_h)
                if rect.collidepoint(mx, my):
                    self.perk_selected_index = i
                    self._confirm_perk()
                    return False

        if event.type == pygame.MOUSEMOTION:
            mx, my = event.pos
            card_w, card_h = 160, 240
            gap = 20
            total_w = num_options * card_w + (num_options - 1) * gap
            sx = SCREEN_WIDTH // 2 - total_w // 2
            cy = SCREEN_HEIGHT // 2 - card_h // 2
            old = self.hover_perk_index
            self.hover_perk_index = -1
            for i in range(num_options):
                rect = pygame.Rect(sx + i * (card_w + gap), cy, card_w, card_h)
                if rect.collidepoint(mx, my):
                    self.hover_perk_index = i
                    self.perk_selected_index = i
                    break
            if self.hover_perk_index != old and self.hover_perk_index >= 0:
                self._play_sound("hover")

        return False

    def _confirm_perk(self):
        """퍽 확정"""
        if self.perk_selected_index < 0 or self.perk_selected_index >= len(self.current_perk_options):
            return

        selected = self.current_perk_options[self.perk_selected_index]
        self.perk_selected_id = selected["id"]
        self._play_sound("click")

        # 퍽 적용
        hero_id = self.player_hero["id"]
        if hero_id not in self.hero_perks:
            self.hero_perks[hero_id] = []
        self.hero_perks[hero_id].append(selected)

        # 스킬 추가 퍽 처리
        if selected.get("effect_type") == "add_skill":
            self.hero_has_both_skills[hero_id] = True

        # 다음 상대로
        self._start_next_opponent()

    def _update_perk_select(self, dt):
        self.perk_anim_timer += dt
        self.perk_frame_count += 1

        if self.perk_anim_phase == "appearing":
            # 카드 슬라이드 인
            easing = min(1.0, self.perk_anim_timer / 0.5) ** 2
            num = len(self.current_perk_options)
            for k in range(num):
                self.perk_card_offsets[k] += (0 - self.perk_card_offsets[k]) * easing
            if self.perk_anim_timer >= 0.5:
                self.perk_card_offsets = [0] * num
                self.perk_anim_phase = "active"

    def _draw_perk_select(self):
        """퍽 선택 화면"""
        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 타이틀
        self._render_text("medium", f"{self.win_streak}연승! 퍽 선택",
                          ET["gold_bright"], center_x=SCREEN_WIDTH // 2, y=100)
        self._render_text("small", "영웅을 강화할 퍽을 선택하세요",
                          ET["text_subtitle"], center_x=SCREEN_WIDTH // 2, y=140)

        # 카드 렌더
        num = len(self.current_perk_options)
        card_w, card_h = 160, 240
        gap = 20
        total_w = num * card_w + (num - 1) * gap
        sx = SCREEN_WIDTH // 2 - total_w // 2
        cy = SCREEN_HEIGHT // 2 - card_h // 2

        for i, perk in enumerate(self.current_perk_options):
            offset_x = int(self.perk_card_offsets[i]) if i < len(self.perk_card_offsets) else 0
            offset_y = int(abs(self.perk_card_offsets[i]) * 0.3) if i < len(self.perk_card_offsets) else 0
            cx = sx + i * (card_w + gap) + offset_x
            card_y = cy + offset_y

            is_sel = (i == self.perk_selected_index and self.perk_anim_phase == "active")
            is_hover = (i == self.hover_perk_index)

            # 카드 배경
            card_surf = _get_arena_surface(card_w, card_h)
            bg = ET["card_bg_hover"] if is_hover else ET["card_bg"]
            pygame.draw.rect(card_surf, bg, (0, 0, card_w, card_h), border_radius=10)

            # 테두리
            border_color = ET["gold_bright"] if is_sel else (
                ET["card_border_hover"] if is_hover else ET["card_border"])
            border_width = 3 if is_sel else 2
            pygame.draw.rect(card_surf, border_color, (0, 0, card_w, card_h),
                             border_width, border_radius=10)

            self.screen.blit(card_surf, (cx, card_y))

            # 퍽 아이콘 (색상 원)
            icon_color = perk.get("icon_color", (200, 200, 200))
            pygame.draw.circle(self.screen, icon_color,
                               (cx + card_w // 2, card_y + 50), 25)

            # 퍽 이름
            self._render_text("small", perk["name"],
                              ET["text_white"],
                              center_x=cx + card_w // 2, y=card_y + 90)

            # 설명
            desc_lines = perk.get("description", "").split("\n")
            for li, line in enumerate(desc_lines):
                self._render_text("small", line, ET["text_body"],
                                  center_x=cx + card_w // 2, y=card_y + 120 + li * 20)

    # ========================================================================
    # 게임 오버
    # ========================================================================
    def _handle_game_over_event(self, event) -> bool:
        if event.type == pygame.KEYDOWN or event.type == pygame.MOUSEBUTTONDOWN:
            if self.game_over_timer >= 2.0:
                self.exit_requested = True
                return True
        return False

    def _update_game_over(self, dt):
        self.game_over_timer += dt

    def _draw_game_over(self):
        """게임 오버 결산 화면"""
        self.screen.fill(ET["bg_dark"])
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        overlay = _get_arena_fullscreen()
        overlay.fill((0, 0, 0, 200))
        self.screen.blit(overlay, (0, 0))

        cy = SCREEN_HEIGHT // 2

        self._render_text("medium", "도장깨기 종료", ET["text_title"],
                          center_x=SCREEN_WIDTH // 2, y=cy - 120)

        # 전적
        self._render_text("medium", f"최고 연승: {self.best_streak}",
                          ET["gold_bright"],
                          center_x=SCREEN_WIDTH // 2, y=cy - 50)

        self._render_text("small", f"총 승리: {self.total_wins}회",
                          ET["text_body"],
                          center_x=SCREEN_WIDTH // 2, y=cy + 0)

        self._render_text("small", f"획득 골드: {self.total_gold_earned}G",
                          ET["gold_pale"],
                          center_x=SCREEN_WIDTH // 2, y=cy + 35)

        # 난이도
        self._render_text("small", f"난이도: {self.difficulty_data['name']}",
                          ET["text_hint"],
                          center_x=SCREEN_WIDTH // 2, y=cy + 75)

        if self.game_over_timer >= 2.0:
            # 깜빡이는 안내
            if int(self.game_over_timer * 3) % 2 == 0:
                self._render_text("small", "클릭하여 나가기", ET["text_subtitle"],
                                  center_x=SCREEN_WIDTH // 2, y=cy + 130)

    # ========================================================================
    # 사운드
    # ========================================================================
    def _play_sound(self, sound_type: str):
        """사운드 재생 (모듈 레벨 글로벌 참조)"""
        try:
            if sound_type == "hover" and _arena_mod._hover_sound:
                _arena_mod._hover_sound.play()
            elif sound_type == "click" and _arena_mod._button_click_sound:
                _arena_mod._button_click_sound.play()
            elif sound_type == "start" and _arena_mod._start_button_sound:
                _arena_mod._start_button_sound.play()
            elif sound_type == "result" and _arena_mod._gacha_result_sound:
                _arena_mod._gacha_result_sound.play()
            elif sound_type == "swing" and _arena_mod._select_swing_sound:
                _arena_mod._select_swing_sound.play()
        except Exception:
            pass
