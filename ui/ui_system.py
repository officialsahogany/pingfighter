# -*- coding: utf-8 -*-
"""
🎮 UI System
UI 시스템 - 메뉴, HUD, 다이얼로그 관리
"""

import pygame
import pygame.freetype
from typing import List, Dict, Optional, Any, Tuple, Callable
from enum import Enum
from dataclasses import dataclass, field


class UIElementType(Enum):
    """UI 요소 타입"""
    BUTTON = "button"
    LABEL = "label"
    PANEL = "panel"
    PROGRESS_BAR = "progress_bar"
    DIALOG = "dialog"
    MENU = "menu"
    HUD = "hud"
    TOOLTIP = "tooltip"


class UIState(Enum):
    """UI 상태"""
    NORMAL = "normal"
    HOVER = "hover"
    PRESSED = "pressed"
    DISABLED = "disabled"
    SELECTED = "selected"


@dataclass
class UIStyle:
    """UI 스타일 설정"""
    # 색상
    background_color: Tuple[int, int, int] = (50, 50, 50)
    border_color: Tuple[int, int, int] = (200, 200, 200)
    text_color: Tuple[int, int, int] = (255, 255, 255)
    hover_color: Tuple[int, int, int] = (100, 100, 100)
    pressed_color: Tuple[int, int, int] = (30, 30, 30)
    disabled_color: Tuple[int, int, int] = (100, 100, 100)
    
    # 크기
    border_width: int = 2
    padding: int = 10
    margin: int = 5
    corner_radius: int = 5
    
    # 폰트
    font_size: int = 24
    font_name: Optional[str] = None
    
    # 효과
    shadow: bool = False
    shadow_offset: Tuple[int, int] = (2, 2)
    shadow_color: Tuple[int, int, int] = (0, 0, 0)
    
    # 애니메이션
    transition_speed: float = 0.2


@dataclass
class UIElement:
    """UI 요소 기본 클래스"""
    id: str
    type: UIElementType
    position: Tuple[int, int]
    size: Tuple[int, int]
    style: UIStyle = field(default_factory=UIStyle)
    visible: bool = True
    enabled: bool = True
    state: UIState = UIState.NORMAL
    parent: Optional['UIElement'] = None
    children: List['UIElement'] = field(default_factory=list)
    
    # 콜백
    on_click: Optional[Callable] = None
    on_hover: Optional[Callable] = None
    on_focus: Optional[Callable] = None
    
    # 렌더링
    rect: Optional[pygame.Rect] = None
    surface: Optional[pygame.Surface] = None
    dirty: bool = True
    
    def __post_init__(self):
        """초기화 후 처리"""
        self.rect = pygame.Rect(self.position[0], self.position[1], 
                               self.size[0], self.size[1])
    
    def update(self, dt: float):
        """UI 요소 업데이트"""
        # 자식 요소 업데이트
        for child in self.children:
            child.update(dt)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if not self.visible or not self.enabled:
            return False
        
        # 자식 요소 이벤트 처리 (역순으로 처리하여 위에 있는 것 우선)
        for child in reversed(self.children):
            if child.handle_event(event):
                return True
        
        # 마우스 이벤트 처리
        if event.type == pygame.MOUSEMOTION:
            if self.rect and self.rect.collidepoint(event.pos):
                if self.state != UIState.HOVER:
                    self.state = UIState.HOVER
                    if self.on_hover:
                        self.on_hover(self)
                return True
            else:
                if self.state == UIState.HOVER:
                    self.state = UIState.NORMAL
        
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if self.rect and self.rect.collidepoint(event.pos):
                self.state = UIState.PRESSED
                return True
        
        elif event.type == pygame.MOUSEBUTTONUP:
            if self.rect and self.rect.collidepoint(event.pos):
                if self.state == UIState.PRESSED:
                    self.state = UIState.HOVER
                    if self.on_click:
                        self.on_click(self)
                return True
        
        return False
    
    def draw(self, screen: pygame.Surface):
        """UI 요소 그리기"""
        if not self.visible:
            return
        
        # 기본 배경 그리기
        if self.rect:
            color = self._get_current_color()
            
            # 그림자
            if self.style.shadow:
                shadow_rect = self.rect.copy()
                shadow_rect.x += self.style.shadow_offset[0]
                shadow_rect.y += self.style.shadow_offset[1]
                pygame.draw.rect(screen, self.style.shadow_color, shadow_rect,
                               border_radius=self.style.corner_radius)
            
            # 배경
            pygame.draw.rect(screen, color, self.rect,
                           border_radius=self.style.corner_radius)
            
            # 테두리
            if self.style.border_width > 0:
                pygame.draw.rect(screen, self.style.border_color, self.rect,
                               self.style.border_width,
                               border_radius=self.style.corner_radius)
        
        # 자식 요소 그리기
        for child in self.children:
            child.draw(screen)
    
    def _get_current_color(self) -> Tuple[int, int, int]:
        """현재 상태에 따른 색상 반환"""
        if not self.enabled:
            return self.style.disabled_color
        elif self.state == UIState.PRESSED:
            return self.style.pressed_color
        elif self.state == UIState.HOVER:
            return self.style.hover_color
        else:
            return self.style.background_color
    
    def add_child(self, child: 'UIElement'):
        """자식 요소 추가"""
        child.parent = self
        self.children.append(child)
    
    def remove_child(self, child: 'UIElement'):
        """자식 요소 제거"""
        if child in self.children:
            child.parent = None
            self.children.remove(child)


class Button(UIElement):
    """버튼 UI 요소"""
    
    def __init__(self, id: str, text: str, position: Tuple[int, int],
                size: Tuple[int, int], **kwargs):
        super().__init__(id, UIElementType.BUTTON, position, size, **kwargs)
        self.text = text
        self.font = None
        self._init_font()
    
    def _init_font(self):
        """폰트 초기화"""
        if self.style.font_name:
            self.font = pygame.freetype.Font(self.style.font_name, self.style.font_size)
        else:
            self.font = pygame.freetype.Font(None, self.style.font_size)
    
    def draw(self, screen: pygame.Surface):
        """버튼 그리기"""
        super().draw(screen)
        
        if self.visible and self.font and self.rect:
            # 텍스트 렌더링
            text_surface, text_rect = self.font.render(
                self.text, self.style.text_color
            )
            
            # 텍스트 중앙 정렬
            text_rect.center = self.rect.center
            screen.blit(text_surface, text_rect)


class Label(UIElement):
    """라벨 UI 요소"""
    
    def __init__(self, id: str, text: str, position: Tuple[int, int], **kwargs):
        # 라벨은 텍스트 크기에 맞춰 자동 크기 조정
        super().__init__(id, UIElementType.LABEL, position, (0, 0), **kwargs)
        self.text = text
        self.font = None
        self._init_font()
        self._calculate_size()
    
    def _init_font(self):
        """폰트 초기화"""
        if self.style.font_name:
            self.font = pygame.freetype.Font(self.style.font_name, self.style.font_size)
        else:
            self.font = pygame.freetype.Font(None, self.style.font_size)
    
    def _calculate_size(self):
        """텍스트 크기 계산"""
        if self.font:
            text_rect = self.font.get_rect(self.text)
            self.size = (text_rect.width, text_rect.height)
            self.rect = pygame.Rect(self.position[0], self.position[1],
                                   self.size[0], self.size[1])
    
    def draw(self, screen: pygame.Surface):
        """라벨 그리기"""
        if self.visible and self.font:
            text_surface, text_rect = self.font.render(
                self.text, self.style.text_color
            )
            text_rect.topleft = self.position
            screen.blit(text_surface, text_rect)


class ProgressBar(UIElement):
    """진행률 바 UI 요소"""
    
    def __init__(self, id: str, position: Tuple[int, int],
                size: Tuple[int, int], max_value: float = 100, **kwargs):
        super().__init__(id, UIElementType.PROGRESS_BAR, position, size, **kwargs)
        self.max_value = max_value
        self.current_value = 0
        self.fill_color = (0, 255, 0)
        self.show_text = True
        self.font = None
        self._init_font()
    
    def _init_font(self):
        """폰트 초기화"""
        if self.style.font_name:
            self.font = pygame.freetype.Font(self.style.font_name, 
                                            self.style.font_size - 4)
        else:
            self.font = pygame.freetype.Font(None, self.style.font_size - 4)
    
    def set_value(self, value: float):
        """값 설정"""
        self.current_value = max(0, min(value, self.max_value))
        self.dirty = True
    
    def draw(self, screen: pygame.Surface):
        """진행률 바 그리기"""
        super().draw(screen)
        
        if self.visible and self.rect:
            # 진행률 계산
            progress = self.current_value / self.max_value if self.max_value > 0 else 0
            fill_width = int(self.rect.width * progress)
            
            if fill_width > 0:
                # 채우기 영역
                fill_rect = pygame.Rect(self.rect.x, self.rect.y,
                                       fill_width, self.rect.height)
                pygame.draw.rect(screen, self.fill_color, fill_rect,
                               border_radius=self.style.corner_radius)
            
            # 텍스트 표시
            if self.show_text and self.font:
                text = f"{int(progress * 100)}%"
                text_surface, text_rect = self.font.render(text, self.style.text_color)
                text_rect.center = self.rect.center
                screen.blit(text_surface, text_rect)


class UISystem:
    """
    🎮 UI 시스템 관리자
    
    모든 UI 요소를 관리하고 이벤트를 처리합니다.
    """
    
    def __init__(self, screen_width: int = 600, screen_height: int = 750):
        """
        UI 시스템 초기화
        
        Args:
            screen_width: 화면 너비
            screen_height: 화면 높이
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        
        # UI 요소 관리
        self.elements: Dict[str, UIElement] = {}
        self.root_elements: List[UIElement] = []
        
        # 포커스 관리
        self.focused_element: Optional[UIElement] = None
        
        # 모달 다이얼로그
        self.modal_stack: List[UIElement] = []
        
        # 툴팁
        self.tooltip: Optional[UIElement] = None
        self.tooltip_delay = 0.5
        self.tooltip_timer = 0
        
        # 애니메이션
        self.animations: List[Dict[str, Any]] = []
        
        print("🎮 UI 시스템 초기화 완료")
    
    def add_element(self, element: UIElement, parent: Optional[UIElement] = None):
        """
        UI 요소 추가
        
        Args:
            element: 추가할 UI 요소
            parent: 부모 요소 (None이면 루트)
        """
        self.elements[element.id] = element
        
        if parent:
            parent.add_child(element)
        else:
            self.root_elements.append(element)
    
    def remove_element(self, element_id: str):
        """UI 요소 제거"""
        if element_id in self.elements:
            element = self.elements[element_id]
            
            # 부모에서 제거
            if element.parent:
                element.parent.remove_child(element)
            elif element in self.root_elements:
                self.root_elements.remove(element)
            
            # 딕셔너리에서 제거
            del self.elements[element_id]
    
    def get_element(self, element_id: str) -> Optional[UIElement]:
        """UI 요소 가져오기"""
        return self.elements.get(element_id)
    
    def show_modal(self, dialog: UIElement):
        """모달 다이얼로그 표시"""
        self.modal_stack.append(dialog)
        self.add_element(dialog)
    
    def close_modal(self):
        """최상위 모달 다이얼로그 닫기"""
        if self.modal_stack:
            dialog = self.modal_stack.pop()
            self.remove_element(dialog.id)
    
    def update(self, dt: float):
        """
        UI 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 루트 요소 업데이트
        for element in self.root_elements:
            element.update(dt)
        
        # 애니메이션 업데이트
        for anim in self.animations[:]:
            anim['progress'] += dt / anim['duration']
            if anim['progress'] >= 1.0:
                anim['progress'] = 1.0
                if anim['on_complete']:
                    anim['on_complete']()
                self.animations.remove(anim)
            else:
                # 애니메이션 적용
                self._apply_animation(anim)
        
        # 툴팁 타이머 업데이트
        if self.tooltip_timer > 0:
            self.tooltip_timer -= dt
            if self.tooltip_timer <= 0 and self.tooltip:
                self.tooltip.visible = True
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """
        이벤트 처리
        
        Args:
            event: Pygame 이벤트
            
        Returns:
            이벤트 처리 여부
        """
        # 모달이 있으면 모달만 처리
        if self.modal_stack:
            return self.modal_stack[-1].handle_event(event)
        
        # 루트 요소 이벤트 처리 (역순)
        for element in reversed(self.root_elements):
            if element.handle_event(event):
                return True
        
        return False
    
    def draw(self, screen: pygame.Surface):
        """
        UI 그리기
        
        Args:
            screen: Pygame 화면
        """
        # 루트 요소 그리기
        for element in self.root_elements:
            element.draw(screen)
        
        # 모달 오버레이
        if self.modal_stack:
            # 반투명 배경
            overlay = pygame.Surface((self.screen_width, self.screen_height))
            overlay.set_alpha(128)
            overlay.fill((0, 0, 0))
            screen.blit(overlay, (0, 0))
            
            # 모달 다이얼로그 그리기
            self.modal_stack[-1].draw(screen)
        
        # 툴팁 그리기
        if self.tooltip and self.tooltip.visible:
            self.tooltip.draw(screen)
    
    def animate(self, element: UIElement, property: str, 
               target_value: Any, duration: float,
               easing: str = "linear",
               on_complete: Optional[Callable] = None):
        """
        UI 애니메이션 시작
        
        Args:
            element: 애니메이션할 요소
            property: 애니메이션할 속성
            target_value: 목표 값
            duration: 지속 시간
            easing: 이징 함수
            on_complete: 완료 콜백
        """
        animation = {
            'element': element,
            'property': property,
            'start_value': getattr(element, property),
            'target_value': target_value,
            'duration': duration,
            'progress': 0,
            'easing': easing,
            'on_complete': on_complete
        }
        self.animations.append(animation)
    
    def _apply_animation(self, anim: Dict[str, Any]):
        """애니메이션 적용"""
        element = anim['element']
        progress = self._ease(anim['progress'], anim['easing'])
        
        # 선형 보간
        start = anim['start_value']
        target = anim['target_value']
        
        if isinstance(start, (int, float)):
            value = start + (target - start) * progress
        elif isinstance(start, tuple):
            value = tuple(
                s + (t - s) * progress
                for s, t in zip(start, target)
            )
        else:
            value = target if progress >= 1.0 else start
        
        setattr(element, anim['property'], value)
        element.dirty = True
    
    def _ease(self, t: float, easing: str) -> float:
        """이징 함수"""
        if easing == "linear":
            return t
        elif easing == "ease_in":
            return t * t
        elif easing == "ease_out":
            return 1 - (1 - t) * (1 - t)
        elif easing == "ease_in_out":
            if t < 0.5:
                return 2 * t * t
            else:
                return 1 - pow(-2 * t + 2, 2) / 2
        else:
            return t
    
    def create_hud(self) -> UIElement:
        """HUD 생성"""
        hud = UIElement(
            id="hud",
            type=UIElementType.HUD,
            position=(0, 0),
            size=(self.screen_width, 100)
        )
        
        # 점수 표시
        score_label = Label(
            id="score_label",
            text="Score: 0",
            position=(10, 10)
        )
        hud.add_child(score_label)
        
        # HP 바
        hp_bar = ProgressBar(
            id="hp_bar",
            position=(10, 40),
            size=(200, 20),
            max_value=100
        )
        hp_bar.set_value(100)
        hud.add_child(hp_bar)
        
        return hud
    
    def reset(self):
        """UI 시스템 초기화"""
        self.elements.clear()
        self.root_elements.clear()
        self.modal_stack.clear()
        self.animations.clear()
        self.focused_element = None
        self.tooltip = None
        
        print("🎮 UI 시스템 리셋 완료")