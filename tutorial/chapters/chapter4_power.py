"""
챕터 4: 파워스매싱
최강 기술 파워스매싱 학습
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType
from ..state import PowerChapterState


class Chapter4Power(BaseChapter):
    """파워스매싱 챕터 클래스"""
    
    def __init__(self, game, state, dialogue):
        super().__init__(game, state, dialogue)
        # 시범 관련 변수
        self.demo_active = False
        self.demo_phase = 0  # 0: left, 1: center, 2: right
        self.demo_timer = 0.0
        self.demo_ball_active = False
        self.demo_ball_x = 0
        self.demo_ball_y = 0
        self.demo_ball_dx = 0
        self.demo_ball_dy = 0
        self.demo_charge_timer = 0.0
        self.demo_shooting = False
        self.demo_completed = False
        self.demo_directions = ['left', 'center', 'right']
        self.demo_phase_timer = 0.0
        self.demo_wait_timer = 0.0
    
    def start(self):
        """챕터 시작"""
        super().start()
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = True
        self.state.ui_states['counter_visible'] = True
        
        # 게임 설정
        self.game.set_ball_speed(5.0)
        self.game.set_special_gauge(300)  # 시작 게이지
    
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, PowerChapterState):
            return
        
        # 시범 모드 업데이트
        if self.demo_active:
            self.update_demonstration(dt)
            return  # 시범 중에는 다른 업데이트 스킵
        
        # 게이지 체크
        gauge = self.game.get_special_gauge()
        if gauge >= 500 and not chapter_state.gauge_reached_500:
            chapter_state.gauge_reached_500 = True
            self.show_gauge_reached_dialogue()
        
        # 시범 보이기 (3초 후 시작)
        if not chapter_state.demonstration_shown and self.timer > 3.0:
            chapter_state.demonstration_shown = True
            self.start_demonstration()
        
        self.update_progress()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        # 시범 모드 렌더링
        if self.demo_active:
            self.render_demonstration(screen)
            return
        
        # 파워스매싱 가이드
        gauge = self.game.get_special_gauge()
        if gauge >= 500:
            self._draw_power_guide(screen)
    
    def _draw_power_guide(self, screen: pygame.Surface):
        """파워스매싱 가이드 표시"""
        width, height = self.game.get_screen_dimensions()
        font = self.game.get_font(32)
        
        text = font.render("X키로 파워스매싱!", True, (255, 0, 100))
        text_rect = text.get_rect(centerx=width // 2, y=height - 150)
        
        # 펄스 효과
        import math
        scale = 1.0 + math.sin(self.timer * 3) * 0.1
        scaled_text = pygame.transform.scale(text,
                                            (int(text_rect.width * scale),
                                             int(text_rect.height * scale)))
        scaled_rect = scaled_text.get_rect(center=text_rect.center)
        screen.blit(scaled_text, scaled_rect)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_x:
                gauge = self.game.get_special_gauge()
                if gauge >= 500:
                    self.game.handle_player_input("power_smash")
                    return True
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, PowerChapterState):
            return
        
        if event_type == 'power_smash':
            chapter_state.power_count += 1
            self.show_feedback("파워스매싱!!!", "perfect")
            
            # 게이지 소비
            current_gauge = self.game.get_special_gauge()
            self.game.set_special_gauge(max(0, current_gauge - 500))
            
            # 축하 효과
            if chapter_state.power_count >= chapter_state.target_power:
                self.state.animation_states['celebration_active'] = True
                self.state.animation_states['celebration_timer'] = 3.0
        
        elif event_type == 'hit':
            # 게이지 증가
            current_gauge = self.game.get_special_gauge()
            self.game.set_special_gauge(min(600, current_gauge + 30))
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        chapter_state = self.state.get_current_chapter_state()
        if isinstance(chapter_state, PowerChapterState):
            return chapter_state.is_complete()
        return False
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "Chapter 4: 파워스매싱", DialogueType.INFO),
            DialogueLine("조교", "이제 가장 강력한 기술을 배울 차례입니다!"),
            DialogueLine("조교", "게이지가 500 이상일 때 X키로 파워스매싱을 사용할 수 있습니다."),
            DialogueLine("조교", "파워스매싱은 막을 수 없는 필살기입니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def start_demonstration(self):
        """시범 시작"""
        dialogues = [
            DialogueLine("조교", "제가 먼저 시범을 보여드리겠습니다.", DialogueType.INFO),
            DialogueLine("조교", "파워스매싱은 왼쪽, 중앙, 오른쪽 3가지 방향으로 발사할 수 있습니다."),
            DialogueLine("조교", "각 방향별로 시범을 보여드리겠습니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
        
        # 시범 모드 활성화
        self.demo_active = True
        self.demo_phase = 0
        self.demo_timer = 0.0
        self.demo_completed = False
        self.demo_phase_timer = 0.0
        self.demo_wait_timer = 0.0
    
    def update_demonstration(self, dt: float):
        """시범 업데이트"""
        self.demo_timer += dt
        self.demo_phase_timer += dt
        
        if self.demo_phase >= len(self.demo_directions):
            # 모든 시범 완료
            if not self.demo_completed:
                self.demo_completed = True
                self.demo_active = False
                dialogues = [
                    DialogueLine("조교", "이렇게 3가지 방향으로 파워스매싱을 날릴 수 있습니다!", DialogueType.SUCCESS),
                    DialogueLine("조교", "이제 직접 연습해보세요!"),
                ]
                self.dialogue.start_dialogue(dialogues)
            return
        
        direction = self.demo_directions[self.demo_phase]
        
        # 각 단계별 처리
        if self.demo_phase_timer < 1.0:
            # 준비 단계
            if not self.demo_ball_active:
                self.demo_ball_active = True
                self.demo_ball_x = self.game.get_screen_dimensions()[0] // 2
                self.demo_ball_y = self.game.get_screen_dimensions()[1] // 2
                self.demo_ball_dx = 0
                self.demo_ball_dy = 5
        elif self.demo_phase_timer < 2.5:
            # 차징 단계
            self.demo_charge_timer = self.demo_phase_timer - 1.0
            # 공이 조교 패들 근처로 이동
            if self.demo_ball_y < self.game.get_screen_dimensions()[1] - 150:
                self.demo_ball_y += self.demo_ball_dy * dt * 60
        elif self.demo_phase_timer < 3.0:
            # 발사 단계
            if not self.demo_shooting:
                self.demo_shooting = True
                # 방향에 따른 발사
                if direction == 'left':
                    self.demo_ball_dx = -15
                    self.demo_ball_dy = -20
                elif direction == 'center':
                    self.demo_ball_dx = 0
                    self.demo_ball_dy = -25
                else:  # right
                    self.demo_ball_dx = 15
                    self.demo_ball_dy = -20
        else:
            # 공 날아가는 애니메이션
            if self.demo_shooting:
                self.demo_ball_x += self.demo_ball_dx * dt * 60
                self.demo_ball_y += self.demo_ball_dy * dt * 60
                
                # 화면 밖으로 나가면 다음 시범으로
                if self.demo_ball_y < -50:
                    self.demo_phase += 1
                    self.demo_phase_timer = 0.0
                    self.demo_shooting = False
                    self.demo_ball_active = False
                    self.demo_charge_timer = 0.0
    
    def render_demonstration(self, screen: pygame.Surface):
        """시범 렌더링"""
        width, height = self.game.get_screen_dimensions()
        
        # 조교 패들 그리기
        instructor_paddle = pygame.Rect(width // 2 - 50, height - 100, 100, 15)
        pygame.draw.rect(screen, (0, 200, 255), instructor_paddle)
        
        # 시범용 공 그리기
        if self.demo_ball_active:
            # 파워스매싱 차징 효과
            if self.demo_charge_timer > 0:
                # 차징 이펙트
                charge_radius = int(15 + self.demo_charge_timer * 20)
                charge_alpha = int(100 + self.demo_charge_timer * 100)
                charge_surface = pygame.Surface((charge_radius * 2, charge_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(charge_surface, (255, 0, 100, min(charge_alpha, 255)), 
                                 (charge_radius, charge_radius), charge_radius)
                screen.blit(charge_surface, 
                          (self.demo_ball_x - charge_radius, self.demo_ball_y - charge_radius))
            
            # 공 그리기
            ball_color = (255, 100, 100) if self.demo_shooting else (255, 255, 255)
            pygame.draw.circle(screen, ball_color, (int(self.demo_ball_x), int(self.demo_ball_y)), 10)
            
            # 파워스매싱 트레일 효과
            if self.demo_shooting:
                for i in range(5):
                    trail_x = self.demo_ball_x - self.demo_ball_dx * i * 0.3
                    trail_y = self.demo_ball_y - self.demo_ball_dy * i * 0.3
                    trail_alpha = 150 - i * 30
                    trail_surface = pygame.Surface((20, 20), pygame.SRCALPHA)
                    pygame.draw.circle(trail_surface, (255, 50, 50, trail_alpha), (10, 10), 8 - i)
                    screen.blit(trail_surface, (trail_x - 10, trail_y - 10))
        
        # 현재 시범 방향 표시
        if self.demo_phase < len(self.demo_directions):
            direction = self.demo_directions[self.demo_phase]
            font_large = self.game.get_font(36)
            
            # 방향 텍스트
            direction_text = {
                'left': '왼쪽',
                'center': '중앙', 
                'right': '오른쪽'
            }[direction]
            
            # 시범 안내 텍스트
            if self.demo_phase_timer < 1.0:
                text = f"준비: {direction_text} 파워스매싱"
                color = (255, 255, 255)
            elif self.demo_phase_timer < 2.5:
                text = f"차징 중... {direction_text} 방향"
                color = (255, 200, 0)
            else:
                text = f"{direction_text} 파워스매싱!!!"
                color = (255, 0, 100)
            
            text_surface = font_large.render(text, True, color)
            text_rect = text_surface.get_rect(centerx=width // 2, y=50)
            screen.blit(text_surface, text_rect)
            
            # 키 커맨드 표시 (차징 중일 때)
            if 1.0 < self.demo_phase_timer < 2.5:
                key_text = {
                    'left': '← + X',
                    'center': 'X',
                    'right': '→ + X'
                }[direction]
                
                # 키 배경
                key_bg = pygame.Surface((150, 60), pygame.SRCALPHA)
                pygame.draw.rect(key_bg, (0, 0, 0, 180), key_bg.get_rect(), border_radius=10)
                bg_rect = key_bg.get_rect(centerx=width // 2, y=height - 200)
                screen.blit(key_bg, bg_rect)
                
                # 키 텍스트
                key_surface = font_large.render(key_text, True, (0, 255, 255))
                key_rect = key_surface.get_rect(center=(width // 2, height - 170))
                screen.blit(key_surface, key_rect)
        
        # 진행 상황 표시
        progress_text = f"시범 {self.demo_phase + 1}/3"
        font = self.game.get_font(20)
        progress_surface = font.render(progress_text, True, (200, 200, 200))
        progress_rect = progress_surface.get_rect(x=20, y=20)
        screen.blit(progress_surface, progress_rect)
    
    def show_gauge_reached_dialogue(self):
        """게이지 도달 대화"""
        dialogues = [
            DialogueLine("조교", "게이지가 500을 넘었습니다!", DialogueType.SUCCESS),
            DialogueLine("조교", "지금이 파워스매싱을 사용할 절호의 기회입니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        dialogues = [
            DialogueLine("조교", "놀랍습니다! 파워스매싱까지 완벽하게 마스터하셨네요!", DialogueType.SUCCESS),
            DialogueLine("조교", "이제 모든 기본 기술을 익히셨습니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)