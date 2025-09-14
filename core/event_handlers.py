"""
Event Handlers - 이벤트 핸들러 모음
게임 전반의 이벤트 처리 로직
"""

from core.events import EventType, subscribe
from core.game_state import GameState
import pygame


class EventHandlers:
    """이벤트 핸들러 관리 클래스"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.setup_handlers()
        
    def setup_handlers(self):
        """이벤트 핸들러 등록"""
        # 게임 상태 이벤트
        subscribe(EventType.GAME_START, self.handle_game_start)
        subscribe(EventType.GAME_PAUSE, self.handle_game_pause)
        subscribe(EventType.GAME_RESUME, self.handle_game_resume)
        subscribe(EventType.GAME_OVER, self.handle_game_over)
        
        # 라운드 이벤트
        subscribe(EventType.ROUND_START, self.handle_round_start)
        subscribe(EventType.ROUND_END, self.handle_round_end)
        subscribe(EventType.ROUND_WIN, self.handle_round_win)
        subscribe(EventType.ROUND_LOSE, self.handle_round_lose)
        
        # 점수 이벤트
        subscribe(EventType.SCORE_UPDATE, self.handle_score_update)
        subscribe(EventType.DEUCE_MODE, self.handle_deuce_mode)
        
        # 아이템 이벤트
        subscribe(EventType.ITEM_COLLECTED, self.handle_item_collected)
        subscribe(EventType.ITEM_ACTIVATED, self.handle_item_activated)
        
        # UI 이벤트
        subscribe(EventType.MENU_OPENED, self.handle_menu_opened)
        subscribe(EventType.MENU_CLOSED, self.handle_menu_closed)
        subscribe(EventType.DIALOG_SHOWN, self.handle_dialog_shown)
        subscribe(EventType.DIALOG_HIDDEN, self.handle_dialog_hidden)
        subscribe(EventType.BUTTON_CLICKED, self.handle_button_clicked)
        
        # 설정 이벤트
        subscribe(EventType.SETTINGS_CHANGED, self.handle_settings_changed)
        
        # 특수 효과 이벤트
        subscribe(EventType.SCREEN_SHAKE, self.handle_screen_shake)
        subscribe(EventType.SPECIAL_ACTIVATED, self.handle_special_activated)
        
    # ========== 게임 상태 핸들러 ==========
    
    def handle_game_start(self, event):
        """게임 시작 이벤트 처리"""
        self.game_state.game_running = True
        self.game_state.game_paused = False
        
        # 스테이지 설정
        if 'stage' in event.data:
            self.game_state.current_stage = event.data['stage']
            
        # 게임 상태 초기화
        self.game_state.reset_stage()
        
        print(f"게임 시작: 스테이지 {self.game_state.current_stage}")
        
    def handle_game_pause(self, event):
        """게임 일시정지 이벤트 처리"""
        self.game_state.game_paused = True
        print("게임 일시정지")
        
    def handle_game_resume(self, event):
        """게임 재개 이벤트 처리"""
        self.game_state.game_paused = False
        print("게임 재개")
        
    def handle_game_over(self, event):
        """게임 종료 이벤트 처리"""
        self.game_state.game_running = False
        
        # 메인 메뉴로 돌아가기
        if event.data.get('from_menu'):
            pygame.quit()
            import sys
            sys.exit()
            
        print("게임 종료")
        
    # ========== 라운드 핸들러 ==========
    
    def handle_round_start(self, event):
        """라운드 시작 이벤트 처리"""
        # 라운드 초기화
        self.game_state.reset_round()
        
        # 다음 스테이지로 이동
        if event.data.get('next_stage'):
            self.game_state.current_stage += 1
            self.game_state.reset_stage()
            
        print(f"라운드 시작: 스테이지 {self.game_state.current_stage}")
        
    def handle_round_end(self, event):
        """라운드 종료 이벤트 처리"""
        winner = event.data.get('winner')
        
        if winner == 'player':
            self.handle_round_win(event)
        else:
            self.handle_round_lose(event)
            
    def handle_round_win(self, event):
        """라운드 승리 이벤트 처리"""
        if self.game_state.deuce_mode:
            self.game_state.deuce_wins += 1
        else:
            self.game_state.round_wins += 1
            
        print(f"라운드 승리! 현재 스코어: {self.game_state.round_wins} - {self.game_state.round_losses}")
        
    def handle_round_lose(self, event):
        """라운드 패배 이벤트 처리"""
        if self.game_state.deuce_mode:
            self.game_state.deuce_losses += 1
        else:
            self.game_state.round_losses += 1
            
        print(f"라운드 패배! 현재 스코어: {self.game_state.round_wins} - {self.game_state.round_losses}")
        
    # ========== 점수 핸들러 ==========
    
    def handle_score_update(self, event):
        """점수 업데이트 이벤트 처리"""
        if 'player_score' in event.data:
            self.game_state.player_score = event.data['player_score']
        if 'ai_score' in event.data:
            self.game_state.ai_score = event.data['ai_score']
            
    def handle_deuce_mode(self, event):
        """듀스 모드 이벤트 처리"""
        self.game_state.deuce_mode = event.data.get('active', False)
        
        if self.game_state.deuce_mode:
            self.game_state.deuce_wins = 0
            self.game_state.deuce_losses = 0
            print("듀스 모드 돌입!")
            
    # ========== 아이템 핸들러 ==========
    
    def handle_item_collected(self, event):
        """아이템 획득 이벤트 처리"""
        item_name = event.data.get('item_name')
        print(f"아이템 획득: {item_name}")
        
        # 메달 보상
        if event.data.get('medal_reward'):
            self.game_state.medal_score += event.data['medal_reward']
            
    def handle_item_activated(self, event):
        """아이템 활성화 이벤트 처리"""
        item_name = event.data.get('item_name')
        effect = event.data.get('effect')
        print(f"아이템 활성화: {item_name}, 효과: {effect}")
        
    # ========== UI 핸들러 ==========
    
    def handle_menu_opened(self, event):
        """메뉴 열림 이벤트 처리"""
        menu_type = event.data.get('menu_type', 'main')
        print(f"메뉴 열림: {menu_type}")
        
        # 게임 일시정지
        if menu_type in ['pause', 'settings']:
            self.game_state.game_paused = True
            
    def handle_menu_closed(self, event):
        """메뉴 닫힘 이벤트 처리"""
        # 게임 재개
        if not event.data.get('keep_paused'):
            self.game_state.game_paused = False
            
    def handle_dialog_shown(self, event):
        """다이얼로그 표시 이벤트 처리"""
        dialog_type = event.data.get('type')
        title = event.data.get('title')
        print(f"다이얼로그 표시: {title} ({dialog_type})")
        
    def handle_dialog_hidden(self, event):
        """다이얼로그 숨김 이벤트 처리"""
        pass
        
    def handle_button_clicked(self, event):
        """버튼 클릭 이벤트 처리"""
        button_name = event.data.get('button_name')
        menu_item = event.data.get('menu_item')
        
        if menu_item:
            print(f"메뉴 선택: {menu_item}")
            
    # ========== 설정 핸들러 ==========
    
    def handle_settings_changed(self, event):
        """설정 변경 이벤트 처리"""
        # 사운드 설정 적용
        if 'sound' in event.data:
            sound_settings = event.data['sound']
            self.game_state.sound_enabled = sound_settings.get('sound_enabled', True)
            self.game_state.music_enabled = sound_settings.get('music_enabled', True)
            self.game_state.sound_volume = sound_settings.get('sfx_volume', 1.0)
            self.game_state.music_volume = sound_settings.get('music_volume', 0.8)
            
        # 게임플레이 설정 적용
        if 'gameplay' in event.data:
            gameplay_settings = event.data['gameplay']
            self.game_state.ai_mode = gameplay_settings.get('difficulty', 'normal')
            
        print("설정이 변경되었습니다.")
        
    # ========== 특수 효과 핸들러 ==========
    
    def handle_screen_shake(self, event):
        """스크린 쉐이크 이벤트 처리"""
        intensity = event.data.get('intensity', 10)
        duration = event.data.get('duration', 0.3)
        
        self.game_state.screen_shake = duration
        self.game_state.screen_shake_intensity = intensity
        
    def handle_special_activated(self, event):
        """특수 능력 활성화 이벤트 처리"""
        special_type = event.data.get('type')
        duration = event.data.get('duration', 0)
        
        self.game_state.special_active = True
        self.game_state.special_duration = duration
        
        print(f"특수 능력 활성화: {special_type}")


# 싱글톤 인스턴스
_event_handlers = None

def init_event_handlers():
    """이벤트 핸들러 초기화"""
    global _event_handlers
    if _event_handlers is None:
        _event_handlers = EventHandlers()
    return _event_handlers

def get_event_handlers():
    """이벤트 핸들러 인스턴스 반환"""
    global _event_handlers
    if _event_handlers is None:
        _event_handlers = EventHandlers()
    return _event_handlers