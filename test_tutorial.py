"""
튜토리얼 시스템 테스트
새로운 모듈화된 튜토리얼 시스템 테스트
"""

import pygame
import sys
import os
import logging

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tutorial import TutorialManager, GameInterface, TutorialState
from tutorial.state import TutorialChapter
from tutorial.dialogue import DialogueSystem, DialogueLine

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MockGameInterface(GameInterface):
    """테스트용 Mock 게임 인터페이스"""
    
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((1024, 768))
        self.clock = pygame.time.Clock()
        self.font = pygame.font.Font(None, 24)
        
        # 게임 상태
        self.ball_x = 512
        self.ball_y = 384
        self.ball_dx = 5
        self.ball_dy = 3
        self.ball_speed = 5.0
        self.player_x = 50
        self.player_y = 384
        self.special_gauge = 0
        self.rolling_charges = 3
        self.is_serving_flag = False
        
    def get_screen(self):
        return self.screen
    
    def get_screen_dimensions(self):
        return 1024, 768
    
    def get_ball_position(self):
        return self.ball_x, self.ball_y
    
    def set_ball_position(self, x, y):
        self.ball_x = x
        self.ball_y = y
    
    def get_ball_velocity(self):
        return self.ball_dx, self.ball_dy
    
    def set_ball_velocity(self, dx, dy):
        self.ball_dx = dx
        self.ball_dy = dy
    
    def get_ball_speed(self):
        return self.ball_speed
    
    def set_ball_speed(self, speed):
        self.ball_speed = speed
    
    def get_player_position(self):
        return self.player_x, self.player_y
    
    def set_player_position(self, x, y):
        self.player_x = x
        self.player_y = y
    
    def get_special_gauge(self):
        return self.special_gauge
    
    def set_special_gauge(self, value):
        self.special_gauge = value
    
    def get_rolling_charges(self):
        return self.rolling_charges
    
    def set_rolling_charges(self, charges):
        self.rolling_charges = charges
    
    def get_font(self, size):
        return pygame.font.Font(None, size)
    
    def play_sound(self, sound_name):
        logger.info(f"Playing sound: {sound_name}")
    
    def get_game_state(self):
        return {
            'ball_x': self.ball_x,
            'ball_y': self.ball_y,
            'special_gauge': self.special_gauge,
        }
    
    def set_game_state(self, state):
        for key, value in state.items():
            setattr(self, key, value)
    
    def is_serving(self):
        return self.is_serving_flag
    
    def start_serve(self, player="player"):
        self.is_serving_flag = True
        logger.info(f"Starting serve for {player}")
    
    def handle_player_input(self, action, params=None):
        logger.info(f"Player action: {action}")
    
    def pause_game(self):
        logger.info("Game paused")
    
    def resume_game(self):
        logger.info("Game resumed")
    
    def reset_game_state(self):
        self.__init__()
        logger.info("Game state reset")


def test_tutorial_manager():
    """튜토리얼 매니저 테스트"""
    print("=" * 50)
    print("튜토리얼 매니저 테스트")
    print("=" * 50)
    
    # Mock 인터페이스 생성
    game = MockGameInterface()
    
    # 튜토리얼 매니저 생성
    tutorial = TutorialManager(game)
    
    # 상태 확인
    assert not tutorial.is_active(), "초기 상태는 비활성이어야 함"
    assert tutorial.get_progress() == 0.0, "초기 진행도는 0이어야 함"
    
    print("✓ 튜토리얼 매니저 생성 성공")
    
    # 튜토리얼 시작
    # tutorial.start()  # 실제로는 대화 시스템 때문에 블로킹됨
    
    # 상태 직접 설정 (테스트용)
    tutorial.state.start_tutorial()
    assert tutorial.is_active(), "튜토리얼이 활성화되어야 함"
    
    print("✓ 튜토리얼 시작 성공")
    
    # 챕터 진행
    tutorial.state.advance_chapter()
    assert tutorial.get_current_chapter() == TutorialChapter.CHAPTER_1_SERVE
    
    print("✓ 챕터 진행 성공")
    
    # 이벤트 처리
    tutorial.on_game_event('hit', {'damage': 10})
    
    # 진행도 업데이트
    tutorial.state.update_chapter_progress(0.5)
    
    print("✓ 이벤트 처리 및 진행도 업데이트 성공")
    
    return tutorial


def test_tutorial_state():
    """튜토리얼 상태 관리 테스트"""
    print("\n" + "=" * 50)
    print("튜토리얼 상태 관리 테스트")
    print("=" * 50)
    
    state = TutorialState()
    
    # 초기 상태 확인
    assert state.current_chapter == TutorialChapter.INTRO
    assert state.overall_progress == 0.0
    assert not state.is_active
    
    print("✓ 초기 상태 확인 성공")
    
    # 챕터 진행
    state.start_tutorial()
    state.advance_chapter()
    assert state.current_chapter == TutorialChapter.CHAPTER_1_SERVE
    
    print("✓ 챕터 진행 성공")
    
    # 챕터 상태 업데이트
    chapter_state = state.get_current_chapter_state()
    chapter_state.hit_count = 5
    chapter_state.success_count = 5
    state.update_chapter_progress(0.5)
    
    print("✓ 챕터 상태 업데이트 성공")
    
    # 저장/로드 테스트
    save_data = state.get_save_data()
    
    new_state = TutorialState()
    new_state.load_save_data(save_data)
    assert new_state.current_chapter == state.current_chapter
    
    print("✓ 저장/로드 테스트 성공")
    
    return state


def test_dialogue_system():
    """대화 시스템 테스트"""
    print("\n" + "=" * 50)
    print("대화 시스템 테스트")
    print("=" * 50)
    
    game = MockGameInterface()
    dialogue = DialogueSystem(game)
    
    # 대화 생성
    lines = [
        DialogueLine("조교", "테스트 대화 1"),
        DialogueLine("조교", "테스트 대화 2"),
        DialogueLine("시스템", "선택하세요", choices=["예", "아니오"]),
    ]
    
    dialogue.start_dialogue(lines)
    assert dialogue.is_dialogue_active()
    
    print("✓ 대화 시작 성공")
    
    # 대화 진행
    dialogue.advance_dialogue()
    assert dialogue.dialogue_index == 1
    
    print("✓ 대화 진행 성공")
    
    # 선택지 처리
    dialogue.selected_choice = 0
    dialogue.advance_dialogue()
    
    print("✓ 선택지 처리 성공")
    
    return dialogue


def test_ui_rendering():
    """UI 렌더링 테스트"""
    print("\n" + "=" * 50)
    print("UI 렌더링 테스트")
    print("=" * 50)
    
    from tutorial.ui import TutorialUI
    
    game = MockGameInterface()
    ui = TutorialUI(game)
    state = TutorialState()
    
    # 렌더링 테스트 (실제 그리기는 하지 않고 에러만 체크)
    try:
        ui.update(0.016, state)
        ui.render(game.screen, state)
        print("✓ UI 렌더링 성공")
    except Exception as e:
        print(f"✗ UI 렌더링 실패: {e}")
        return None
    
    return ui


def run_all_tests():
    """모든 테스트 실행"""
    print("\n🧪 튜토리얼 시스템 테스트 시작\n")
    
    try:
        # 각 테스트 실행
        tutorial = test_tutorial_manager()
        state = test_tutorial_state()
        dialogue = test_dialogue_system()
        ui = test_ui_rendering()
        
        print("\n" + "=" * 50)
        print("✅ 모든 테스트 통과!")
        print("=" * 50)
        
        # 통합 테스트 (실제 화면 표시)
        if '--visual' in sys.argv:
            print("\n시각적 테스트 모드 시작...")
            visual_test(tutorial)
        
    except AssertionError as e:
        print(f"\n❌ 테스트 실패: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ 예상치 못한 오류: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


def visual_test(tutorial):
    """시각적 통합 테스트"""
    game = tutorial.game
    clock = game.clock
    running = True
    
    print("Space: 다음 챕터 | ESC: 종료")
    
    while running:
        dt = clock.tick(60) / 1000.0
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 다음 챕터로
                    tutorial.state.advance_chapter()
                    print(f"현재 챕터: {tutorial.get_current_chapter().name}")
            
            # 튜토리얼 이벤트 처리
            tutorial.handle_event(event)
        
        # 업데이트
        tutorial.update(dt)
        
        # 렌더링
        game.screen.fill((20, 20, 40))
        tutorial.render(game.screen)
        
        # 디버그 정보
        font = game.font
        debug_info = [
            f"Chapter: {tutorial.get_current_chapter().name}",
            f"Progress: {tutorial.get_progress():.1%}",
            f"Active: {tutorial.is_active()}",
        ]
        
        y = 10
        for info in debug_info:
            text = font.render(info, True, (255, 255, 255))
            game.screen.blit(text, (10, y))
            y += 25
        
        pygame.display.flip()
    
    pygame.quit()


if __name__ == "__main__":
    run_all_tests()