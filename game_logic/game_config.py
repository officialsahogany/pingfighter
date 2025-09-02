"""
게임 설정 매니저 - 스테이지별 설정 및 게임 규칙 관리
"""
from typing import Dict, Any, Tuple
from dataclasses import dataclass

@dataclass
class StageConfig:
    """스테이지 설정 데이터 클래스"""
    stage_num: int
    name: str
    boss_name: str
    background_color: Tuple[int, int, int]
    boss_color: Tuple[int, int, int]
    boss_speed: float
    boss_ai_level: int
    win_condition: int  # 필요한 승리 점수
    special_mechanics: Dict[str, Any]
    
class GameConfig:
    """게임 설정 관리 클래스"""
    
    def __init__(self):
        """설정 초기화"""
        # 화면 설정
        self.SCREEN_WIDTH = 600
        self.SCREEN_HEIGHT = 750
        self.FPS = 60
        
        # 게임플레이 설정
        self.DEFAULT_WIN_GOAL = 3
        self.HEALTH_BOSS_WIN_GOAL = 5
        self.BOSS_MAX_HEALTH = 15
        
        # 물리 설정
        self.BALL_DEFAULT_SPEED = 5
        self.BALL_MAX_SPEED = 15
        self.BALL_RADIUS = 10
        
        self.PADDLE_WIDTH = 100
        self.PADDLE_HEIGHT = 20
        self.PADDLE_SPEED = 10
        
        # 아이템 설정
        self.ITEM_SPAWN_INTERVAL = 5  # 초
        self.MAX_ITEMS_ON_FIELD = 3
        self.ITEM_DURATION = 5  # 초
        
        # 스테이지 설정
        self.stages = self._init_stages()
        
    def _init_stages(self) -> Dict[int, StageConfig]:
        """스테이지 설정 초기화"""
        return {
            1: StageConfig(
                stage_num=1,
                name="초원",
                boss_name="그린 파이터",
                background_color=(135, 206, 235),  # Sky blue
                boss_color=(34, 139, 34),  # Forest green
                boss_speed=5,
                boss_ai_level=1,
                win_condition=3,
                special_mechanics={
                    'balloon_event': True,
                    'border_flash': True
                }
            ),
            2: StageConfig(
                stage_num=2,
                name="정글",
                boss_name="정글 킹",
                background_color=(34, 100, 34),  # Dark green
                boss_color=(139, 69, 19),  # Saddle brown
                boss_speed=6,
                boss_ai_level=2,
                win_condition=3,
                special_mechanics={
                    'vine_borders': True,
                    'leaf_particles': True
                }
            ),
            3: StageConfig(
                stage_num=3,
                name="사막",
                boss_name="샌드 스톰",
                background_color=(238, 203, 173),  # Peach puff
                boss_color=(244, 164, 96),  # Sandy brown
                boss_speed=7,
                boss_ai_level=3,
                win_condition=3,
                special_mechanics={
                    'sandstorm': True,
                    'mirage_effect': True
                }
            ),
            4: StageConfig(
                stage_num=4,
                name="얼음",
                boss_name="아이스 로드",
                background_color=(176, 224, 230),  # Powder blue
                boss_color=(70, 130, 180),  # Steel blue
                boss_speed=8,
                boss_ai_level=4,
                win_condition=3,
                special_mechanics={
                    'ice_physics': True,
                    'freeze_attack': True,
                    'crow_spawning': True
                }
            ),
            5: StageConfig(
                stage_num=5,
                name="화산",
                boss_name="파이어 드래곤",
                background_color=(178, 34, 34),  # Fire brick
                boss_color=(255, 69, 0),  # Orange red
                boss_speed=9,
                boss_ai_level=5,
                win_condition=3,
                special_mechanics={
                    'lava_pools': True,
                    'fire_balls': True,
                    'heat_wave': True
                }
            ),
            6: StageConfig(
                stage_num=6,
                name="우주",
                boss_name="코스믹 마스터",
                background_color=(25, 25, 112),  # Midnight blue
                boss_color=(138, 43, 226),  # Blue violet
                boss_speed=10,
                boss_ai_level=6,
                win_condition=3,
                special_mechanics={
                    'gravity_wells': True,
                    'meteor_shower': True,
                    'black_holes': True,
                    'teleportation': True
                }
            )
        }
    
    def get_stage_config(self, stage_num: int) -> StageConfig:
        """스테이지 설정 반환
        
        Args:
            stage_num: 스테이지 번호
            
        Returns:
            스테이지 설정
        """
        return self.stages.get(stage_num, self.stages[1])
    
    def get_boss_config(self, stage_num: int, ai_mode: str = 'normal') -> Dict[str, Any]:
        """보스 AI 설정 반환
        
        Args:
            stage_num: 스테이지 번호
            ai_mode: AI 모드 ('normal', 'hard', 'extreme')
            
        Returns:
            보스 설정 딕셔너리
        """
        stage = self.get_stage_config(stage_num)
        
        # AI 모드에 따른 보정
        ai_multipliers = {
            'normal': 1.0,
            'hard': 1.5,
            'extreme': 2.0
        }
        multiplier = ai_multipliers.get(ai_mode, 1.0)
        
        return {
            'name': stage.boss_name,
            'color': stage.boss_color,
            'speed': stage.boss_speed * multiplier,
            'ai_level': stage.boss_ai_level,
            'accel': 0.5 * multiplier,
            'decel': 0.3,
            'max_speed': 15 * multiplier,
            'instant_stop_decel': 0.8
        }
    
    def get_difficulty_settings(self, difficulty: str) -> Dict[str, Any]:
        """난이도 설정 반환
        
        Args:
            difficulty: 난이도 ('easy', 'normal', 'hard', 'extreme')
            
        Returns:
            난이도 설정 딕셔너리
        """
        settings = {
            'easy': {
                'ball_speed_multiplier': 0.8,
                'boss_speed_multiplier': 0.8,
                'item_spawn_rate_multiplier': 1.5,
                'player_paddle_width_multiplier': 1.2
            },
            'normal': {
                'ball_speed_multiplier': 1.0,
                'boss_speed_multiplier': 1.0,
                'item_spawn_rate_multiplier': 1.0,
                'player_paddle_width_multiplier': 1.0
            },
            'hard': {
                'ball_speed_multiplier': 1.2,
                'boss_speed_multiplier': 1.3,
                'item_spawn_rate_multiplier': 0.8,
                'player_paddle_width_multiplier': 0.9
            },
            'extreme': {
                'ball_speed_multiplier': 1.5,
                'boss_speed_multiplier': 1.6,
                'item_spawn_rate_multiplier': 0.5,
                'player_paddle_width_multiplier': 0.8
            }
        }
        
        return settings.get(difficulty, settings['normal'])
    
    def get_item_settings(self) -> Dict[str, Any]:
        """아이템 설정 반환"""
        return {
            'spawn_interval': self.ITEM_SPAWN_INTERVAL,
            'max_on_field': self.MAX_ITEMS_ON_FIELD,
            'duration': self.ITEM_DURATION,
            'types': [
                {
                    'name': 'speed_up',
                    'color': (255, 255, 0),
                    'effect': 'ball_speed_x1.5',
                    'duration': 5
                },
                {
                    'name': 'slow_down',
                    'color': (0, 255, 255),
                    'effect': 'ball_speed_x0.7',
                    'duration': 5
                },
                {
                    'name': 'wide_paddle',
                    'color': (255, 0, 255),
                    'effect': 'paddle_width_x1.5',
                    'duration': 10
                },
                {
                    'name': 'multi_ball',
                    'color': (255, 128, 0),
                    'effect': 'spawn_extra_balls',
                    'duration': 0  # 즉시 효과
                },
                {
                    'name': 'shield',
                    'color': (0, 255, 0),
                    'effect': 'block_next_goal',
                    'duration': 0  # 다음 골까지
                }
            ]
        }
    
    def get_physics_settings(self) -> Dict[str, Any]:
        """물리 설정 반환"""
        return {
            'gravity': 0,  # 기본 중력 없음
            'friction': 0.99,  # 마찰 계수
            'restitution': 1.0,  # 반발 계수
            'max_ball_speed': self.BALL_MAX_SPEED,
            'min_ball_speed': 3,
            'paddle_bounce_angle_modifier': 0.75,  # 패들 히트 위치에 따른 각도 변경량
            'wall_bounce_damping': 1.0  # 벽 충돌 시 속도 감소
        }
    
    def get_scoring_settings(self) -> Dict[str, Any]:
        """점수 설정 반환"""
        return {
            'point_per_goal': 1,
            'combo_multiplier_increment': 0.1,
            'combo_reset_on_goal': True,
            'bonus_points': {
                'perfect_hit': 10,  # 패들 중앙 히트
                'fast_return': 20,  # 빠른 리턴
                'trick_shot': 50,   # 특수 샷
                'no_miss_round': 100  # 실점 없이 라운드 승리
            }
        }
    
    def get_ui_settings(self) -> Dict[str, Any]:
        """UI 설정 반환"""
        return {
            'font_size': {
                'small': 16,
                'medium': 24,
                'large': 32,
                'huge': 48
            },
            'colors': {
                'text_primary': (255, 255, 255),
                'text_secondary': (200, 200, 200),
                'text_highlight': (255, 255, 0),
                'text_danger': (255, 0, 0),
                'text_success': (0, 255, 0)
            },
            'ui_positions': {
                'score': (self.SCREEN_WIDTH // 2, 30),
                'timer': (self.SCREEN_WIDTH - 100, 30),
                'combo': (50, self.SCREEN_HEIGHT - 50),
                'message': (self.SCREEN_WIDTH // 2, self.SCREEN_HEIGHT // 2)
            }
        }

# 전역 설정 인스턴스
game_config = GameConfig()

def get_config() -> GameConfig:
    """전역 게임 설정 반환"""
    return game_config