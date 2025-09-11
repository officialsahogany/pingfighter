"""
대화 시스템 모듈
튜토리얼의 대화 표시와 상호작용을 담당
"""

import pygame
import logging
from typing import List, Optional, Dict, Any, Tuple
from dataclasses import dataclass
from enum import Enum
from .game_interface import GameInterface

logger = logging.getLogger(__name__)


class DialogueType(Enum):
    """대화 타입"""
    NORMAL = "normal"
    WARNING = "warning"
    SUCCESS = "success"
    INFO = "info"
    QUESTION = "question"


@dataclass
class DialogueLine:
    """대화 라인 데이터"""
    speaker: str
    text: str
    type: DialogueType = DialogueType.NORMAL
    duration: Optional[float] = None  # None이면 사용자 입력 대기
    choices: Optional[List[str]] = None  # 선택지
    
    
class DialogueBox:
    """대화 박스 UI 컴포넌트"""
    
    def __init__(self, game_interface: GameInterface):
        self.game = game_interface
        self.width, self.height = game_interface.get_screen_dimensions()
        
        # 박스 설정
        self.box_width = 800
        self.box_height = 200
        self.box_x = (self.width - self.box_width) // 2
        self.box_y = self.height - self.box_height - 50
        
        # 색상
        self.bg_color = (20, 30, 40, 240)
        self.border_color = (0, 200, 255, 200)
        self.text_color = (255, 255, 255)
        
        # 애니메이션
        self.animation_timer = 0.0
        self.text_reveal_progress = 0.0
        self.text_speed = 30  # 초당 글자 수
        
    def draw(self, screen: pygame.Surface, speaker: str, text: str, 
             progress: float = 1.0, choices: Optional[List[str]] = None,
             selected_choice: int = 0):
        """
        대화 박스 그리기
        
        Args:
            screen: 화면
            speaker: 화자
            text: 대화 내용
            progress: 텍스트 표시 진행도 (0.0 ~ 1.0)
            choices: 선택지 리스트
            selected_choice: 선택된 선택지 인덱스
        """
        # 반투명 배경
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 100))
        screen.blit(overlay, (0, 0))
        
        # 대화 박스 배경
        box_surface = pygame.Surface((self.box_width, self.box_height), pygame.SRCALPHA)
        pygame.draw.rect(box_surface, self.bg_color,
                        (0, 0, self.box_width, self.box_height),
                        border_radius=15)
        pygame.draw.rect(box_surface, self.border_color,
                        (0, 0, self.box_width, self.box_height),
                        width=3, border_radius=15)
        
        # 화자 이름
        if speaker:
            speaker_font = self.game.get_font(24)
            speaker_text = speaker_font.render(speaker, True, (0, 255, 255))
            box_surface.blit(speaker_text, (20, 15))
            
            # 구분선
            pygame.draw.line(box_surface, self.border_color,
                           (20, 45), (self.box_width - 20, 45), 1)
        
        # 대화 텍스트
        text_font = self.game.get_font(20)
        
        # 텍스트 표시 (타이핑 효과)
        visible_chars = int(len(text) * progress)
        visible_text = text[:visible_chars]
        
        # 줄바꿈 처리
        lines = self._wrap_text(visible_text, text_font, self.box_width - 40)
        y_offset = 60 if speaker else 30
        
        for line in lines:
            text_surface = text_font.render(line, True, self.text_color)
            box_surface.blit(text_surface, (20, y_offset))
            y_offset += 30
        
        # 선택지 표시
        if choices and progress >= 1.0:
            self._draw_choices(box_surface, choices, selected_choice)
        
        # 계속 표시 (선택지가 없을 때)
        elif progress >= 1.0 and not choices:
            continue_font = self.game.get_font(16)
            continue_text = "Space 키를 눌러 계속..."
            continue_surface = continue_font.render(continue_text, True, (180, 180, 180))
            continue_rect = continue_surface.get_rect(
                right=self.box_width - 20,
                bottom=self.box_height - 10
            )
            box_surface.blit(continue_surface, continue_rect)
        
        # 화면에 그리기
        screen.blit(box_surface, (self.box_x, self.box_y))
    
    def _wrap_text(self, text: str, font: pygame.font.Font, max_width: int) -> List[str]:
        """텍스트 줄바꿈 처리"""
        words = text.split(' ')
        lines = []
        current_line = []
        
        for word in words:
            test_line = ' '.join(current_line + [word])
            text_width = font.size(test_line)[0]
            
            if text_width <= max_width:
                current_line.append(word)
            else:
                if current_line:
                    lines.append(' '.join(current_line))
                    current_line = [word]
                else:
                    lines.append(word)
        
        if current_line:
            lines.append(' '.join(current_line))
        
        return lines
    
    def _draw_choices(self, surface: pygame.Surface, choices: List[str], selected: int):
        """선택지 그리기"""
        choice_font = self.game.get_font(20)
        x = self.box_width // 2
        y = self.box_height - 60
        
        for i, choice in enumerate(choices):
            # 선택된 항목 강조
            if i == selected:
                color = (0, 255, 255)
                # 선택 표시
                marker = "▶ "
            else:
                color = (180, 180, 180)
                marker = "  "
            
            text = marker + choice
            text_surface = choice_font.render(text, True, color)
            text_rect = text_surface.get_rect(
                centerx=x + (i - len(choices) / 2 + 0.5) * 200,
                centery=y
            )
            surface.blit(text_surface, text_rect)


class DialogueSystem:
    """대화 시스템 관리 클래스"""
    
    def __init__(self, game_interface: GameInterface):
        """
        초기화
        
        Args:
            game_interface: 게임 인터페이스
        """
        self.game = game_interface
        self.dialogue_box = DialogueBox(game_interface)
        
        # 대화 큐
        self.dialogue_queue: List[DialogueLine] = []
        self.current_dialogue: Optional[DialogueLine] = None
        self.dialogue_index = 0
        
        # 상태
        self.is_active = False
        self.is_blocking = True  # 게임 차단 여부
        self.text_progress = 0.0
        self.selected_choice = 0
        self.dialogue_result = None
        
        # 타이머
        self.timer = 0.0
        self.auto_advance_timer = 0.0
        
        logger.info("DialogueSystem initialized")
    
    def start_dialogue(self, dialogues: List[DialogueLine], blocking: bool = True):
        """
        대화 시작
        
        Args:
            dialogues: 대화 라인 리스트
            blocking: 게임 차단 여부
        """
        self.dialogue_queue = dialogues.copy()
        self.dialogue_index = 0
        self.is_active = True
        self.is_blocking = blocking
        self.text_progress = 0.0
        self.selected_choice = 0
        self.dialogue_result = None
        
        if self.dialogue_queue:
            self.current_dialogue = self.dialogue_queue[0]
            logger.info(f"Started dialogue with {len(dialogues)} lines")
    
    def update(self, dt: float):
        """
        대화 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.is_active or not self.current_dialogue:
            return
        
        self.timer += dt
        
        # 텍스트 타이핑 효과
        if self.text_progress < 1.0:
            self.text_progress += dt * 2  # 2초에 전체 텍스트 표시
            self.text_progress = min(1.0, self.text_progress)
        
        # 자동 진행 (duration이 설정된 경우)
        if (self.current_dialogue.duration and 
            self.text_progress >= 1.0 and 
            not self.current_dialogue.choices):
            
            self.auto_advance_timer += dt
            if self.auto_advance_timer >= self.current_dialogue.duration:
                self.advance_dialogue()
    
    def render(self, screen: pygame.Surface):
        """
        대화 렌더링
        
        Args:
            screen: 화면
        """
        if not self.is_active or not self.current_dialogue:
            return
        
        self.dialogue_box.draw(
            screen,
            self.current_dialogue.speaker,
            self.current_dialogue.text,
            self.text_progress,
            self.current_dialogue.choices,
            self.selected_choice
        )
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """
        이벤트 처리
        
        Args:
            event: pygame 이벤트
            
        Returns:
            bool: 이벤트 처리 여부
        """
        if not self.is_active or not self.current_dialogue:
            return False
        
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 텍스트가 아직 표시 중이면 즉시 표시
                if self.text_progress < 1.0:
                    self.text_progress = 1.0
                    return True
                
                # 선택지가 없으면 다음으로
                if not self.current_dialogue.choices:
                    self.advance_dialogue()
                    return True
            
            elif event.key == pygame.K_RETURN:
                # 선택지 선택
                if self.current_dialogue.choices and self.text_progress >= 1.0:
                    self.dialogue_result = self.selected_choice
                    self.advance_dialogue()
                    return True
            
            elif event.key == pygame.K_LEFT:
                # 선택지 이동
                if self.current_dialogue.choices:
                    self.selected_choice = max(0, self.selected_choice - 1)
                    return True
            
            elif event.key == pygame.K_RIGHT:
                # 선택지 이동
                if self.current_dialogue.choices:
                    max_choice = len(self.current_dialogue.choices) - 1
                    self.selected_choice = min(max_choice, self.selected_choice + 1)
                    return True
            
            elif event.key == pygame.K_ESCAPE:
                # 대화 스킵
                if self.can_skip():
                    self.skip_dialogue()
                    return True
        
        return self.is_blocking
    
    def advance_dialogue(self):
        """다음 대화로 진행"""
        self.dialogue_index += 1
        
        if self.dialogue_index < len(self.dialogue_queue):
            self.current_dialogue = self.dialogue_queue[self.dialogue_index]
            self.text_progress = 0.0
            self.auto_advance_timer = 0.0
            self.selected_choice = 0
        else:
            self.end_dialogue()
    
    def skip_dialogue(self):
        """대화 스킵"""
        self.end_dialogue()
    
    def end_dialogue(self):
        """대화 종료"""
        self.is_active = False
        self.current_dialogue = None
        self.dialogue_queue.clear()
        logger.info("Dialogue ended")
    
    def can_skip(self) -> bool:
        """스킵 가능 여부"""
        # 중요한 대화는 스킵 불가
        if self.current_dialogue and self.current_dialogue.type == DialogueType.WARNING:
            return False
        return True
    
    def is_dialogue_active(self) -> bool:
        """대화 활성 상태"""
        return self.is_active
    
    def get_result(self) -> Optional[int]:
        """선택 결과 반환"""
        return self.dialogue_result
    
    # 튜토리얼 전용 대화 메서드들
    
    def show_tutorial_dialog(self) -> bool:
        """튜토리얼 시작 대화"""
        dialogues = [
            DialogueLine("시스템", "튜토리얼을 진행하시겠습니까?", 
                        DialogueType.QUESTION,
                        choices=["예", "아니오"])
        ]
        
        self.start_dialogue(dialogues)
        
        # 대화 완료까지 대기 (실제 구현에서는 비동기 처리)
        # 여기서는 간단히 True 반환
        return True
    
    def show_intro_dialogue(self):
        """인트로 대화"""
        dialogues = [
            DialogueLine("조교", "안녕하세요! PingFighter 튜토리얼에 오신 것을 환영합니다!"),
            DialogueLine("조교", "저와 함께 게임의 기본 조작법을 배워보겠습니다."),
            DialogueLine("조교", "먼저 기본 타격부터 시작해볼까요?"),
        ]
        self.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화"""
        dialogues = [
            DialogueLine("조교", "축하합니다! 모든 튜토리얼을 완료하셨습니다!", 
                        DialogueType.SUCCESS),
            DialogueLine("조교", "이제 실전에서 배운 기술들을 활용해보세요!"),
            DialogueLine("조교", "행운을 빕니다!"),
        ]
        self.start_dialogue(dialogues)
    
    def confirm_skip(self) -> bool:
        """스킵 확인 대화"""
        dialogues = [
            DialogueLine("시스템", "튜토리얼을 건너뛰시겠습니까?",
                        DialogueType.QUESTION,
                        choices=["예", "아니오"])
        ]
        self.start_dialogue(dialogues)
        
        # 실제 구현에서는 결과 대기
        return self.dialogue_result == 0