"""
Global Manager - 전역 변수 관리 시스템
모든 전역 변수를 중앙에서 관리
"""

from typing import Dict, Any, Optional
import pygame


class GlobalManager:
    """전역 변수 관리자 - 싱글톤"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(GlobalManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        
        # 전역 변수들
        self.variables = {
            # 화면 설정
            'screen': None,
            'SCREEN': None,  # bosspong.py 호환
            'screen_width': 600,
            'screen_height': 750,
            'WIDTH': 600,  # bosspong.py 호환
            'HEIGHT': 750,  # bosspong.py 호환
            'fps': 60,
            'FPS': 60,  # bosspong.py 호환
            'clock': None,
            
            # 게임 상태
            'running': True,
            'paused': False,
            'game_over': False,
            'current_stage': 1,
            'current_mode': 'menu',
            
            # 폰트
            'fonts': {},
            'default_font': None,
            
            # 이미지
            'images': {},
            'backgrounds': {},
            
            # 사운드
            'sounds': {},
            'music_volume': 0.7,
            'sfx_volume': 0.7,
            
            # 색상 (bosspong.py와 호환)
            'colors': {
                'WHITE': (255, 255, 255),
                'BLACK': (0, 0, 0),
                'RED': (255, 0, 0),
                'GREEN': (0, 255, 0),
                'BLUE': (0, 0, 255),
                'YELLOW': (255, 255, 0),
                'CYAN': (0, 255, 255),
                'MAGENTA': (255, 0, 255),
                'GRAY': (128, 128, 128),
                'FIELD_GREEN': (30, 100, 30),
                'ORANGE': (255, 165, 0),
                'PURPLE': (128, 0, 128),
                'PINK': (255, 192, 203),
                'GOLD': (255, 215, 0),
                'SILVER': (192, 192, 192),
                'BRONZE': (205, 127, 50)
            },
            
            # 색상 변수 (레거시 호환)
            'WHITE': (255, 255, 255),
            'BLACK': (0, 0, 0),
            'FIELD_GREEN': (30, 100, 30),
            
            # 설정
            'settings': {
                'language': 'ko',
                'difficulty': 'normal',
                'fullscreen': False,
                'vsync': True,
                'show_fps': False,
                'auto_save': True
            },
            
            # 저장 데이터
            'save_data': {
                'high_scores': {},
                'unlocked_stages': [1],
                'achievements': [],
                'total_play_time': 0
            },
            
            # === bosspong.py 전역 변수들 ===
            
            # 패들 설정
            'PADDLE_WIDTH': 100,
            'PADDLE_HEIGHT': 20,
            'PADDLE_BASE_WIDTH': 100,
            'PADDLE_BASE_HEIGHT': 20,
            
            # 볼 설정
            'BALL_RADIUS': 22,
            'BALL_SPEED_X': 5,
            'BALL_SPEED_Y': 8,
            'BALL_BASE_SPEED': 9,
            
            # 플레이어 설정
            'PLAYER_SPEED': 1,
            'PLAYER_BASE_SPEED': 2,
            'MAX_SPEED': 5,
            'ACCELERATION': 0.4,
            'DECELERATION': 0.4,
            'INSTANT_STOP_DECELERATION': 1.0,
            'DIRECTION_CHANGE_BOOST': 2.5,
            'PERMANENT_SPEED_BOOST': 0.15,
            
            # 보스 설정
            'BOSS_Y': 25,
            'BOSS_SPEED': 1,
            'BOSS_COLOR': (255, 255, 255),
            'BOSS_ACCELERATION': 0.798,
            'BOSS_DECELERATION': 0.798,
            'BOSS_MAX_SPEED': 6.3175,
            'BOSS_INSTANT_STOP_DECELERATION': 0.665,
            'BOSS_ACCELERATION_DEFAULT': 0.798,
            'BOSS_DECELERATION_DEFAULT': 0.798,
            'BOSS_MAX_SPEED_DEFAULT': 6.3175,
            'BOSS_INSTANT_STOP_DECELERATION_DEFAULT': 0.665,
            
            # 보스 이미지 크기
            'BOSS_IMG_WIDTH': 160,
            'BOSS_IMG_HEIGHT': 80,
            
            # 아이템 설정
            'MAX_ITEM_SLOTS': 2,
            
            # 게임 상태 변수들
            'player_score': 0,
            'boss_score': 0,
            'target_score': 11,
            'league_mode': 'bronze',
            'game_running': True,
            'ball_dx': 0,
            'ball_dy': 5,
            'boss_dx': 0,
            'boss_ai_mode': 'normal',
            'boss_hit_animation': 0,
            'player_hit_animation': 0,
            'HIT_ANIMATION_DURATION': 6,
            'BOSS_HIT_ANIMATION_DURATION': 6,
            
            # 스테이지 관련
            'stage': 1,
            'selected_boss': 'training',
            'CURRENT_BG': None,
            
            # 특수 기능 관련
            'hongryun_flame_gauge': 0,
            'HONGRYUN_MAX_HITS': 10,
            'quake_duration': 0,
            'QUAKE_COOLDOWN': 4000,
            'meditation_time': 0,
            'magnetic_field_active': False,
            
            # 대쉬 관련
            'dash_count': 3,
            'dash_cooldown': 0,
            'dash_active': False,
            'dash_timer': 0,
            'DASH_SPIRIT_LASER_DURATION': 360,
            'DASH_SPIRIT_LASER_WIDTH': 8,
            'DASH_SPIRIT_LASER_COLOR': (135, 206, 235),
            'DASH_SPIRIT_ELECTRIC_COLOR': (255, 255, 255),
            'dash_spirit_lasers': [],
            
            # 스킬 관련
            'tears_active': False,
            'tears_timer': 0,
            'tears_list': [],
            'TEARS_COOLDOWN': 7000,
            
            # 화염탄 관련
            'fireballs': [],
            'flame_trails': [],
            
            # 롱부스트 관련
            'long_boost_active': False,
            'long_boost_timer': 0,
            'LONG_BOOST_DURATION': 360,
            'LONG_BOOST_TRANSITION_TIME': 60,
            'doping_potion_active': False,
            'doping_potion_timer_frames': 0,
            'doping_potion_duration_frames': 480,
            'doping_potion_refresh': False,
            'doping_potion_use_count': 0,
            'berserk_potion_active': False,
            'berserk_potion_timer_frames': 0,
            'berserk_potion_duration_frames': 900,
            'berserk_potion_refresh': False,

            # 메뉴/UI 관련
            'menu_selected': 0,
            'show_credits': False,
            'show_options': False,
            
            # Pygame 객체들 (나중에 초기화)
            'PLAYER': None,
            'BOSS': None,
            'BALL': None,
            'BOSS_IMG': None,
            'PLAYER_IMG': None,
            'BALL_IMG': None,
            'FONT': None,
            
            # 배경 이미지
            'STAGE1_BG': None,
            'animated_bg': None,
            'animated_bg_stage2': None,
            'animated_bg_stage3': None,
            'animated_bg_stage4': None,
            'animated_bg_stage5': None,
            
            # 사운드
            'SOUND_SERVE': None,
            'SOUND_WALL': None,
            'SOUND_PADDLE': None,
            'SOUND_QUAKE': None,
            'SOUND_DEFENSE_HIT': None,
            'SOUND_DEFENSE_START': None,
            'SOUND_FIREBALL': None,
            'SOUND_DASH': None,
            'SOUND_ACTIVE_ITEM': None,
            'SOUND_BALLOON_BOOM': None,
            'SOUND_POWER_SMASH': None,
            'SOUND_POWER_SMASH_LAUNCH': None,
            'SOUND_MISSILE': None
        }
        
    def get(self, key: str, default: Any = None) -> Any:
        """전역 변수 가져오기
        
        Args:
            key: 변수 키
            default: 기본값
            
        Returns:
            변수 값
        """
        return self.variables.get(key, default)
    
    def set(self, key: str, value: Any):
        """전역 변수 설정
        
        Args:
            key: 변수 키
            value: 변수 값
        """
        self.variables[key] = value
    
    def update(self, updates: Dict[str, Any]):
        """여러 전역 변수 한번에 업데이트
        
        Args:
            updates: 업데이트할 변수들
        """
        self.variables.update(updates)
    
    def get_color(self, color_name: str) -> tuple:
        """색상 가져오기
        
        Args:
            color_name: 색상 이름
            
        Returns:
            RGB 튜플
        """
        colors = self.variables.get('colors', {})
        return colors.get(color_name.upper(), (255, 255, 255))
    
    def get_setting(self, setting_name: str, default: Any = None) -> Any:
        """설정 가져오기
        
        Args:
            setting_name: 설정 이름
            default: 기본값
            
        Returns:
            설정 값
        """
        settings = self.variables.get('settings', {})
        return settings.get(setting_name, default)
    
    def set_setting(self, setting_name: str, value: Any):
        """설정 변경
        
        Args:
            setting_name: 설정 이름
            value: 설정 값
        """
        if 'settings' not in self.variables:
            self.variables['settings'] = {}
        self.variables['settings'][setting_name] = value
    
    def get_save_data(self, data_name: str, default: Any = None) -> Any:
        """저장 데이터 가져오기
        
        Args:
            data_name: 데이터 이름
            default: 기본값
            
        Returns:
            데이터 값
        """
        save_data = self.variables.get('save_data', {})
        return save_data.get(data_name, default)
    
    def set_save_data(self, data_name: str, value: Any):
        """저장 데이터 설정
        
        Args:
            data_name: 데이터 이름
            value: 데이터 값
        """
        if 'save_data' not in self.variables:
            self.variables['save_data'] = {}
        self.variables['save_data'][data_name] = value
    
    def init_pygame_objects(self):
        """Pygame 객체 초기화"""
        if not pygame.get_init():
            pygame.init()
            
        # 화면 생성
        if self.get('screen') is None:
            width = self.get('WIDTH', 600)
            height = self.get('HEIGHT', 750)
            screen = pygame.display.set_mode((width, height))
            pygame.display.set_caption("PINGFIGHTER")
            self.set('screen', screen)
            self.set('SCREEN', screen)  # bosspong.py 호환
            
        # 시계 생성
        if self.get('clock') is None:
            clock = pygame.time.Clock()
            self.set('clock', clock)
            
        # 기본 폰트 생성
        if self.get('default_font') is None:
            try:
                font = pygame.font.Font('NanumSquareB.ttf', 24)
            except:
                font = pygame.font.Font(None, 24)
            self.set('default_font', font)
            
        # bosspong.py 폰트
        if self.get('FONT') is None:
            try:
                font = pygame.font.Font('NanumSquareR.ttf', 40)
            except:
                font = pygame.font.Font(None, 40)
            self.set('FONT', font)
            
        # Rect 객체들 초기화
        self.init_game_objects()
        
        # 사운드 로드
        self.load_sounds()
        
        # 이미지 로드
        self.load_images()
    
    def init_game_objects(self):
        """게임 객체 초기화 (Rect 등)"""
        width = self.get('WIDTH', 600)
        height = self.get('HEIGHT', 750)
        paddle_width = self.get('PADDLE_WIDTH', 100)
        paddle_height = self.get('PADDLE_HEIGHT', 20)
        ball_radius = self.get('BALL_RADIUS', 22)
        boss_y = self.get('BOSS_Y', 25)
        
        # 플레이어 Rect
        if self.get('PLAYER') is None:
            player = pygame.Rect(
                width // 2 - paddle_width // 2,
                height - 40,
                paddle_width,
                paddle_height
            )
            self.set('PLAYER', player)
        
        # 보스 Rect
        if self.get('BOSS') is None:
            boss = pygame.Rect(
                width // 2 - 130 // 2,
                boss_y,
                130,
                40
            )
            self.set('BOSS', boss)
        
        # 볼 Rect
        if self.get('BALL') is None:
            ball = pygame.Rect(
                width // 2 - ball_radius // 2,
                height // 2 - ball_radius // 2,
                ball_radius,
                ball_radius
            )
            self.set('BALL', ball)
    
    def load_sounds(self):
        """사운드 파일 로드"""
        sound_files = {
            'SOUND_SERVE': 'sounds/serve.wav',
            'SOUND_WALL': 'sounds/wall_hit.wav',
            'SOUND_PADDLE': 'sounds/paddle_hit.wav',
            'SOUND_QUAKE': 'sounds/quake_sound.wav',
            'SOUND_DEFENSE_HIT': 'sounds/defense_hit.wav',
            'SOUND_DEFENSE_START': 'sounds/speed_defense_start.wav',
            'SOUND_FIREBALL': 'sounds/fireball.wav',
            'SOUND_DASH': 'sounds/dash.wav',
            'SOUND_ACTIVE_ITEM': 'sounds/activeitem.wav',
            'SOUND_BALLOON_BOOM': 'sounds/balloonboom.wav',
            'SOUND_POWER_SMASH': 'sounds/power_smash.wav',
            'SOUND_POWER_SMASH_LAUNCH': 'sounds/power_smash_launch.wav',
            'SOUND_MISSILE': 'sounds/missle.wav'
        }
        
        for name, path in sound_files.items():
            try:
                sound = pygame.mixer.Sound(path)
                self.set(name, sound)
            except:
                print(f"Warning: Could not load sound {path}")
                self.set(name, None)
    
    def load_images(self):
        """이미지 파일 로드"""
        # 플레이어 이미지
        try:
            player_img = pygame.image.load("ufo_player.png").convert_alpha()
            player_img = pygame.transform.scale(player_img, (250, 100))
            self.set('PLAYER_IMG', player_img)
        except:
            print("Warning: Could not load player image")
            
        # 볼 이미지
        try:
            ball_img = pygame.image.load("ball.png").convert_alpha()
            ball_img = pygame.transform.smoothscale(ball_img, (36, 36))
            self.set('BALL_IMG', ball_img)
        except:
            print("Warning: Could not load ball image")
            
        # 배경 이미지
        try:
            stage1_bg = pygame.image.load("stage1_field.png").convert()
            stage1_bg = pygame.transform.scale(stage1_bg, (self.get('WIDTH'), self.get('HEIGHT')))
            self.set('STAGE1_BG', stage1_bg)
            self.set('CURRENT_BG', stage1_bg)
        except:
            # 폴백 배경 생성
            stage1_bg = pygame.Surface((self.get('WIDTH'), self.get('HEIGHT')))
            for y in range(self.get('HEIGHT')):
                ratio = y / self.get('HEIGHT')
                r = int(10 + ratio * 20)
                g = int(50 + ratio * 50)
                b = int(20 + ratio * 30)
                pygame.draw.line(stage1_bg, (r, g, b), (0, y), (self.get('WIDTH'), y))
            self.set('STAGE1_BG', stage1_bg)
            self.set('CURRENT_BG', stage1_bg)
    
    def cleanup(self):
        """정리 작업"""
        # Pygame 객체 정리
        self.variables['screen'] = None
        self.variables['SCREEN'] = None
        self.variables['clock'] = None
        self.variables['fonts'].clear()
        self.variables['images'].clear()
        self.variables['sounds'].clear()
    
    def reset(self):
        """전역 변수 리셋"""
        # 게임 상태만 리셋 (설정과 저장 데이터는 유지)
        self.variables['running'] = True
        self.variables['paused'] = False
        self.variables['game_over'] = False
        self.variables['current_stage'] = 1
        self.variables['current_mode'] = 'menu'
    
    @classmethod
    def get_instance(cls):
        """싱글톤 인스턴스 반환"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance


# 헬퍼 함수들
def get_global(key: str, default: Any = None) -> Any:
    """전역 변수 가져오기"""
    return GlobalManager.get_instance().get(key, default)

def set_global(key: str, value: Any):
    """전역 변수 설정"""
    GlobalManager.get_instance().set(key, value)

def update_globals(updates: Dict[str, Any]):
    """여러 전역 변수 업데이트"""
    GlobalManager.get_instance().update(updates)

def get_color(color_name: str) -> tuple:
    """색상 가져오기"""
    return GlobalManager.get_instance().get_color(color_name)

def get_setting(setting_name: str, default: Any = None) -> Any:
    """설정 가져오기"""
    return GlobalManager.get_instance().get_setting(setting_name, default)

def set_setting(setting_name: str, value: Any):
    """설정 변경"""
    GlobalManager.get_instance().set_setting(setting_name, value)
