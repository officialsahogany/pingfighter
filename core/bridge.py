"""
Bridge - 기존 코드와 새 아키텍처를 연결하는 브리지
점진적 마이그레이션을 위한 호환성 레이어
"""

from typing import Dict, Any
from core.game_state import GameState
from core.events import EventManager, EventType, emit_event


class LegacyBridge:
    """기존 전역 변수 시스템과 새 GameState를 연결"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.event_manager = EventManager.get_instance()
        
        # 전역 변수 매핑 테이블
        self.variable_mapping = {
            # 게임 상태
            'current_stage': 'current_stage',
            'game_paused': 'game_paused',
            'ai_mode': 'ai_mode',
            
            # 점수
            'player_score': 'player_score',
            'ai_score': 'ai_score',
            'round_wins': 'round_wins',
            'round_losses': 'round_losses',
            'medal_score': 'medal_score',
            'session_medal_earned': 'session_medal_earned',
            
            # 듀스 모드
            'deuce_mode': 'deuce_mode',
            'deuce_wins': 'deuce_wins',
            'deuce_losses': 'deuce_losses',
            'deuce_goal': 'deuce_goal',
            
            # 특수 능력
            'special_gauge': 'special_gauge',
            'special_ready': 'special_ready',
            'special_active': 'special_active',
            
            # 대시
            'dash_charges': 'dash_charges',
            'dash_max': 'dash_max',
            
            # 아이템
            'speedboots_obtained': 'speedboots_obtained',
            'speedgear_obtained': 'speedgear_obtained',
            'battery_obtained': 'battery_obtained',
            'revival_obtained': 'revival_obtained',
            'revival_used': 'revival_used',
            'master_obtained': 'master_obtained',
            'cooltime_obtained': 'cooltime_obtained',
            'chargebag_obtained': 'chargebag_obtained',
            'spikeboots_obtained': 'spikeboots_obtained',
            'dashgear_obtained': 'dashgear_obtained',
            'bulkup_obtained': 'bulkup_obtained',
            'dashholder_obtained': 'dashholder_obtained',
            'gravitybelt_obtained': 'gravitybelt_obtained',
            'danger_sensor_obtained': 'danger_sensor_obtained',
            'sensor_obtained': 'sensor_obtained',
            
            # 벽돌과 풍선
            'walls': 'walls',
            'balloons': 'balloons',
            'balloon_active': 'balloon_active',
            'balloon_timer': 'balloon_timer',
            'balloon_used_this_round': 'balloon_used_this_round',
            
            # 화면 효과
            'screen_shake': 'screen_shake',
            'screen_shake_intensity': 'screen_shake_intensity',
            'border_flash_active': 'border_flash_active',
            'border_flash_timer': 'border_flash_timer',
        }
        
    def sync_from_globals(self, globals_dict: Dict[str, Any]):
        """전역 변수를 GameState로 동기화"""
        for global_name, state_attr in self.variable_mapping.items():
            if global_name in globals_dict:
                setattr(self.game_state, state_attr, globals_dict[global_name])
                
    def sync_to_globals(self, globals_dict: Dict[str, Any]):
        """GameState를 전역 변수로 동기화"""
        for global_name, state_attr in self.variable_mapping.items():
            if hasattr(self.game_state, state_attr):
                globals_dict[global_name] = getattr(self.game_state, state_attr)
                
    def emit_legacy_event(self, event_name: str, data: Dict[str, Any] = None):
        """기존 코드에서 이벤트 발생"""
        # 문자열을 EventType으로 변환
        try:
            event_type = EventType(event_name)
            self.event_manager.emit(event_type, data)
        except ValueError:
            print(f"Unknown event type: {event_name}")
            
    def wrap_function(self, func):
        """함수 실행 전후에 동기화를 수행하는 래퍼"""
        def wrapper(*args, **kwargs):
            # 실행 전: 전역 변수 -> GameState
            self.sync_from_globals(globals())
            
            # 함수 실행
            result = func(*args, **kwargs)
            
            # 실행 후: GameState -> 전역 변수
            self.sync_to_globals(globals())
            
            return result
        return wrapper


# 싱글톤 인스턴스
_bridge = None

def get_bridge():
    """브리지 싱글톤 인스턴스 반환"""
    global _bridge
    if _bridge is None:
        _bridge = LegacyBridge()
    return _bridge


# 기존 코드에서 사용할 헬퍼 함수들

def init_game_state():
    """게임 시작 시 GameState 초기화"""
    bridge = get_bridge()
    game_state = bridge.game_state
    
    # 초기값 설정
    game_state.current_stage = 1
    game_state.player_score = 0
    game_state.ai_score = 0
    game_state.round_wins = 0
    game_state.round_losses = 0
    
    # 전역 변수로 동기화
    bridge.sync_to_globals(globals())
    
    # 게임 시작 이벤트 발생
    emit_event(EventType.GAME_START)
    
def update_score(player_delta: int = 0, ai_delta: int = 0):
    """점수 업데이트 (새 시스템 사용)"""
    bridge = get_bridge()
    game_state = bridge.game_state
    
    if player_delta > 0:
        game_state.player_score += player_delta
        emit_event(EventType.PLAYER_SCORE, {'points': player_delta})
    
    if ai_delta > 0:
        game_state.ai_score += ai_delta
        emit_event(EventType.AI_SCORE, {'points': ai_delta})
        
def handle_item_collection(item_type: str):
    """아이템 획득 처리 (새 시스템 사용)"""
    bridge = get_bridge()
    game_state = bridge.game_state
    
    # 아이템 상태 업데이트
    item_updated = False
    
    if item_type == "speedboots" and not game_state.speedboots_obtained:
        game_state.speedboots_obtained = True
        item_updated = True
    elif item_type == "speedgear" and not game_state.speedgear_obtained:
        game_state.speedgear_obtained = True
        item_updated = True
    elif item_type == "battery" and not game_state.battery_obtained:
        game_state.battery_obtained = True
        item_updated = True
    elif item_type == "revival" and not game_state.revival_obtained:
        game_state.revival_obtained = True
        item_updated = True
    elif item_type == "master" and not game_state.master_obtained:
        game_state.master_obtained = True
        item_updated = True
    elif item_type == "cooltime" and not game_state.cooltime_obtained:
        game_state.cooltime_obtained = True
        item_updated = True
    elif item_type == "chargebag" and not game_state.chargebag_obtained:
        game_state.chargebag_obtained = True
        item_updated = True
    elif item_type == "spikeboots" and not game_state.spikeboots_obtained:
        game_state.spikeboots_obtained = True
        item_updated = True
    elif item_type == "dashgear" and not game_state.dashgear_obtained:
        game_state.dashgear_obtained = True
        item_updated = True
    elif item_type == "bulkup" and not game_state.bulkup_obtained:
        game_state.bulkup_obtained = True
        item_updated = True
    elif item_type == "dashholder" and not game_state.dashholder_obtained:
        game_state.dashholder_obtained = True
        item_updated = True
    elif item_type == "gravitybelt" and not game_state.gravitybelt_obtained:
        game_state.gravitybelt_obtained = True
        item_updated = True
    elif item_type == "sensor" and not game_state.danger_sensor_obtained:
        game_state.danger_sensor_obtained = True
        game_state.sensor_obtained = True  # 호환성
        item_updated = True
    
    # 이벤트 발생
    if item_updated:
        emit_event(EventType.ITEM_COLLECTED, {'item_type': item_type})
        
    return item_updated
    
def handle_round_end(player_won: bool):
    """라운드 종료 처리 (새 시스템 사용)"""
    bridge = get_bridge()
    game_state = bridge.game_state
    
    if player_won:
        game_state.round_wins += 1
        emit_event(EventType.ROUND_WIN, {
            'stage': game_state.current_stage,
            'score': game_state.player_score
        })
    else:
        game_state.round_losses += 1
        emit_event(EventType.ROUND_LOSE, {
            'stage': game_state.current_stage,
            'score': game_state.ai_score
        })
        
    # 라운드 리셋
    game_state.reset_round()


# 사용 예시 - bosspong.py에서:
"""
# 파일 상단에 추가
from core.bridge import get_bridge, init_game_state, update_score

# 게임 시작 시
init_game_state()

# 점수 획득 시 (기존 코드 대체)
# 기존: player_score += 1
# 새: update_score(player_delta=1)

# 매 프레임 동기화 (선택적)
bridge = get_bridge()
bridge.sync_from_globals(globals())
# ... 게임 로직 ...
bridge.sync_to_globals(globals())
"""