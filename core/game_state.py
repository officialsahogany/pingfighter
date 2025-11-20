"""
GameState - 전역 상태 관리 클래스
모든 전역 변수를 하나의 클래스로 관리
"""

import json
from typing import Dict, List, Any

from core.legacy_state_accessor import bind_legacy_accessor
from core.player_state import RollingState


class GameState:
    """게임의 전역 상태를 관리하는 싱글톤 클래스
    
    모든 전역 변수를 중앙에서 관리하여 상태 추적과
    디버깅을 용이하게 합니다.
    """
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(GameState, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    @classmethod
    def get_instance(cls):
        """싱글톤 인스턴스 반환"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        
        # ========== 게임 기본 상태 ==========
        self.game_running = True
        self.game_paused = False
        self.current_stage = 1
        self.ai_mode = "normal"  # normal, hard, mythic
        
        # ========== 점수 및 라운드 ==========
        self.player_score = 0
        self.ai_score = 0
        self.round_wins = 0
        self.round_losses = 0
        self.deuce_mode = False
        self.deuce_wins = 0
        self.deuce_losses = 0
        self.deuce_goal = 2
        
        # ========== 메달 시스템 ==========
        self.medal_score = 0
        self.session_medal_earned = 0
        
        # ========== 플레이어 상태 ==========
        self.player_character = "ufo"  # ufo, eagle
        self.player_x = 0
        self.player_y = 0
        self.player_width = 120
        self.player_height = 20
        self.player_speed = 8
        
        # ========== 보스 상태 ==========
        self.boss_x = 0
        self.boss_y = 0
        self.boss_width = 120
        self.boss_height = 20
        self.boss_speed = 6
        self.boss_health = 100
        self.boss_phase = 1
        
        # ========== 공 상태 ==========
        self.ball_x = 0
        self.ball_y = 0
        self.ball_speed_x = 0
        self.ball_speed_y = 0
        self.ball_radius = 22
        self.ball_vel = [0, 0]
        self.ball_angle = 0
        self.ball_impact_boost = 1.0
        self.ball_boost_decay_rate = 0.975
        self.ball_min_boost = 0.7
        self.last_hit_by = "player"
        self.slow_ball_timer = 0
        self.vertical_bounce_count = 0
        
        # ========== 특수 능력 ==========
        self.special_gauge = 0
        self.special_ready = False
        self.special_active = False
        self.special_duration = 0
        self.special_gauge_max = 100
        # 최근 패들 충전량 및 충전가방 보정용 상태
        self.last_player_gauge_gain = 80
        self.chargebag_wall_charge_percent = 0.2
        self.chargebag_wall_charge_cooldown = 0
        self.displayed_gauge = 0
        self.gauge_animation_speed = 0.15
        self.displayed_boss_gauge = 0
        self.boss_gauge_animation_speed = 0.15
        
        # 홍련폭염 시스템
        self.hongryun_hit_count = 0
        self.hongryun_ready = False
        # 홍련폭염 게이지 최대치 (화염탄 4회 피격 시 발동)
        self.HONGRYUN_MAX_HITS = 4
        
        # ========== 대시 시스템 ==========
        self.dash_charges = 3
        self.dash_max = 3
        self.dash_active = False
        self.dash_timer = 0
        self.dash_direction = 0
        self.dash_cooldown = 0
        
        # ========== 아이템 시스템 ==========
        self.items_obtained = {}
        self.passive_items = []
        self.active_items = []
        
        # 패시브 아이템 상태
        self.speedboots_obtained = False
        self.speedgear_obtained = False
        self.battery_obtained = False
        self.revival_obtained = False
        self.revival_used = False
        self.master_obtained = False
        self.cooltime_obtained = False
        self.chargebag_obtained = False
        self.spikeboots_obtained = False
        self.dashgear_obtained = False
        self.bulkup_obtained = False
        self.dashholder_obtained = False
        self.gravitybelt_obtained = False
        self.foul_whistle_obtained = False
        self.star_detector_obtained = False
        self.danger_sensor_obtained = False
        self.sensor_obtained = False
        
        # ========== 벽돌 시스템 ==========
        self.walls = []
        
        # ========== 풍선 시스템 ==========
        self.balloons = []
        self.balloon_active = False
        self.balloon_timer = 0
        self.balloon_used_this_round = False
        
        # ========== 효과 및 애니메이션 ==========
        self.screen_shake = 0
        self.screen_shake_intensity = 0
        self.border_flash_active = False
        self.border_flash_timer = 0
        
        # ========== 사운드 설정 ==========
        self.sound_enabled = True
        self.music_enabled = True
        self.sound_volume = 0.7
        self.music_volume = 0.5
        
        # ========== 퍼펙트 타이밍 시스템 ==========
        self.perfect_timing_window = 12
        self.perfect_timing_active = False
        self.perfect_timing_frame_count = 0
        self.perfect_direction = None
        self.perfect_timing_indicator_active = False
        
        # ========== 입력 상태 ==========
        self.space_just_pressed = False
        self.last_space_state = False
        self.left_just_pressed = False
        self.last_left_state = False
        self.right_just_pressed = False
        self.last_right_state = False
        
        # ========== 배경 및 UI ==========
        self.current_bg = None
        self.boss_names = {
            1: "기본 보스",
            2: "악어 보스",
            3: "멘헤라걸",
            4: "자석 마녀",
            5: "슬롯머신",
            6: "체력형 보스"
        }
        
        # ========== 상태 딕셔너리 (추가적인 동적 상태 저장용) ==========
        self.state = {}
        self.legacy_globals: Dict[str, Any] = {}
        self._bind_legacy_accessor()
        self.rolling = RollingState(self.legacy)

    def get(self, key: str, default: Any = None) -> Any:
        """상태 값 가져오기
        
        Args:
            key: 상태 키
            default: 기본값
            
        Returns:
            상태 값
        """
        # 먼저 state 딕셔너리에서 찾기
        if key in self.state:
            return self.state[key]
        # 없으면 인스턴스 속성에서 찾기
        if hasattr(self, key):
            return getattr(self, key)
        return default
        
    def set(self, key: str, value: Any):
        """상태 값 설정
        
        Args:
            key: 상태 키
            value: 설정할 값
        """
        # 인스턴스 속성이 있으면 거기에 설정
        if hasattr(self, key):
            setattr(self, key, value)
        else:
            # 없으면 state 딕셔너리에 설정
            self.state[key] = value

    def _bind_legacy_accessor(self) -> None:
        """레거시 상태 접근자를 현재 딕셔너리에 맞게 재바인딩."""
        self.legacy = bind_legacy_accessor(self.legacy_globals)
        self.rolling = RollingState(self.legacy)
        
    def reset_round(self):
        """라운드 초기화"""
        self.special_gauge = 0 if not self.battery_obtained else self.special_gauge
        self.special_ready = False
        self.special_active = False
        self.walls.clear()
        self.balloons.clear()
        self.balloon_used_this_round = False
        
    def reset_stage(self):
        """스테이지 초기화"""
        self.reset_round()
        self.round_wins = 0
        self.round_losses = 0
        self.deuce_mode = False
        self.deuce_wins = 0
        self.deuce_losses = 0
        
    def save_state(self, filename="game_state.json"):
        """게임 상태 저장"""
        state_dict = {
            'current_stage': self.current_stage,
            'medal_score': self.medal_score,
            'items_obtained': self.items_obtained,
            'passive_items': self.passive_items,
            # 필요한 다른 상태들 추가
        }
        
        with open(filename, 'w') as f:
            json.dump(state_dict, f, indent=2)
            
    def load_state(self, filename="game_state.json"):
        """게임 상태 로드"""
        try:
            with open(filename, 'r') as f:
                state_dict = json.load(f)
                
            self.current_stage = state_dict.get('current_stage', 1)
            self.medal_score = state_dict.get('medal_score', 0)
            self.items_obtained = state_dict.get('items_obtained', {})
            self.passive_items = state_dict.get('passive_items', [])
            # 필요한 다른 상태들 로드
            
            return True
        except FileNotFoundError:
            return False
            
    @classmethod
    def get_instance(cls):
        """싱글톤 인스턴스 반환"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
        
    def get_state_dict(self) -> Dict[str, Any]:
        """현재 상태를 딕셔너리로 반환"""
        return {
            key: value for key, value in self.__dict__.items()
            if not key.startswith('_')
        }
        
    def update_from_globals(self, globals_dict: Dict[str, Any]):
        """기존 전역 변수들로부터 상태 업데이트"""
        mapping = {
            'current_stage': 'current_stage',
            'player_score': 'player_score', 
            'ai_score': 'ai_score',
            'round_wins': 'round_wins',
            'round_losses': 'round_losses',
            'medal_score': 'medal_score',
            'special_gauge': 'special_gauge',
            'special_ready': 'special_ready',
            'special_active': 'special_active',
            # 필요한 매핑 추가
        }
        
        for global_name, attr_name in mapping.items():
            if global_name in globals_dict:
                setattr(self, attr_name, globals_dict[global_name])
                
    def sync_to_globals(self, globals_dict: Dict[str, Any]):
        """GameState의 값을 전역 변수로 동기화"""
        mapping = {
            'current_stage': 'current_stage',
            'player_score': 'player_score',
            'ai_score': 'ai_score', 
            'round_wins': 'round_wins',
            'round_losses': 'round_losses',
            'medal_score': 'medal_score',
            'special_gauge': 'special_gauge',
            'special_ready': 'special_ready',
            'special_active': 'special_active',
            # 필요한 매핑 추가
        }
        
        for attr_name, global_name in mapping.items():
            globals_dict[global_name] = getattr(self, attr_name)


# 사용 예시:
if __name__ == "__main__":
    # 싱글톤 인스턴스 가져오기
    game_state = GameState.get_instance()
    
    # 상태 변경
    game_state.player_score += 10
    game_state.special_gauge = min(100, game_state.special_gauge + 20)
    
    # 상태 저장
    game_state.save_state()
    
    # 상태 로드
    game_state.load_state()
