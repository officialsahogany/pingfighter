"""
반응형 UI 컴포넌트 시스템
사용자 친화적이고 접근성 높은 UI 컴포넌트를 제공합니다.
"""
import pygame
from typing import Optional, Callable, Tuple, List
from ui.font_manager import font_manager
from ui.theme_manager import theme_manager
from ui.animation_manager import Animation, AnimationManager

class UIComponent:
    """기본 UI 컴포넌트 클래스"""
    
    def __init__(self, x: int, y: int, width: int, height: int):
        self.rect = pygame.Rect(x, y, width, height)
        self.is_visible = True
        self.is_enabled = True
        self.is_focused = False
        self.is_hovered = False
        self.animations = []
    
    def update(self, dt: float):
        """컴포넌트 업데이트"""
        # 애니메이션 업데이트
        for anim in self.animations[:]:
            anim.update(dt)
            if anim.is_complete:
                self.animations.remove(anim)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if not self.is_enabled or not self.is_visible:
            return False
        
        if event.type == pygame.MOUSEMOTION:
            mouse_pos = pygame.mouse.get_pos()
            was_hovered = self.is_hovered
            self.is_hovered = self.rect.collidepoint(mouse_pos)
            
            if self.is_hovered and not was_hovered:
                self.on_hover_enter()
            elif not self.is_hovered and was_hovered:
                self.on_hover_exit()
        
        return False
    
    def on_hover_enter(self):
        """호버 시작"""
        pass
    
    def on_hover_exit(self):
        """호버 종료"""
        pass
    
    def draw(self, surface: pygame.Surface):
        """컴포넌트 그리기"""
        pass

class Button(UIComponent):
    """반응형 버튼 컴포넌트"""
    
    def __init__(self, x: int, y: int, width: int, height: int, 
                 text: str, on_click: Optional[Callable] = None):
        super().__init__(x, y, width, height)
        self.text = text
        self.on_click = on_click
        self.is_pressed = False
        
        # 상태별 스케일
        self.normal_scale = 1.0
        self.hover_scale = 1.05
        self.pressed_scale = 0.95
        self.current_scale = 1.0
        
        # 애니메이션 시간
        self.animation_duration = 0.2
        
        # 최소 크기 (접근성)
        self.min_size = 44  # 터치 친화적 최소 크기
        if self.rect.width < self.min_size:
            self.rect.width = self.min_size
        if self.rect.height < self.min_size:
            self.rect.height = self.min_size
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if not super().handle_event(event):
            if not self.is_enabled or not self.is_visible:
                return False
        
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.rect.collidepoint(event.pos):
                self.is_pressed = True
                self._animate_scale(self.pressed_scale)
                return True
        
        elif event.type == pygame.MOUSEBUTTONUP:
            if self.is_pressed:
                self.is_pressed = False
                if self.rect.collidepoint(event.pos):
                    self._animate_scale(self.hover_scale)
                    if self.on_click:
                        self.on_click()
                else:
                    self._animate_scale(self.normal_scale)
                return True
        
        return False
    
    def on_hover_enter(self):
        """호버 시작"""
        if not self.is_pressed:
            self._animate_scale(self.hover_scale)
    
    def on_hover_exit(self):
        """호버 종료"""
        if not self.is_pressed:
            self._animate_scale(self.normal_scale)
    
    def _animate_scale(self, target_scale: float):
        """스케일 애니메이션"""
        anim = Animation(
            self.current_scale,
            target_scale,
            self.animation_duration,
            AnimationManager.ease_out_cubic,
            on_update=lambda v: setattr(self, 'current_scale', v)
        )
        self.animations.append(anim)
    
    def draw(self, surface: pygame.Surface):
        """버튼 그리기"""
        if not self.is_visible:
            return
        
        # 스케일 적용된 rect 계산
        scaled_width = int(self.rect.width * self.current_scale)
        scaled_height = int(self.rect.height * self.current_scale)
        scaled_rect = pygame.Rect(
            self.rect.centerx - scaled_width // 2,
            self.rect.centery - scaled_height // 2,
            scaled_width,
            scaled_height
        )
        
        # 색상 결정
        if not self.is_enabled:
            bg_color = theme_manager.get_color('surface')
            text_color = theme_manager.get_color('text_disabled')
            border_color = theme_manager.get_color('text_disabled')
        elif self.is_pressed:
            bg_color = theme_manager.get_color('primary')
            text_color = theme_manager.get_color('text_primary')
            border_color = theme_manager.get_color('primary')
        elif self.is_hovered:
            bg_color = theme_manager.apply_brightness('primary', 0.8)
            text_color = theme_manager.get_color('text_primary')
            border_color = theme_manager.get_color('primary')
        else:
            bg_color = theme_manager.get_color('surface')
            text_color = theme_manager.get_color('text_primary')
            border_color = theme_manager.get_color('secondary')
        
        # 그림자 효과
        if self.is_enabled and not self.is_pressed:
            shadow_rect = scaled_rect.copy()
            shadow_rect.x += 2
            shadow_rect.y += 2
            pygame.draw.rect(surface, (0, 0, 0, 50), shadow_rect, border_radius=8)
        
        # 버튼 배경
        pygame.draw.rect(surface, bg_color, scaled_rect, border_radius=8)
        
        # 버튼 테두리
        pygame.draw.rect(surface, border_color, scaled_rect, 2, border_radius=8)
        
        # 텍스트 그리기
        text_surface = font_manager.render(self.text, 'button', text_color)
        text_rect = text_surface.get_rect(center=scaled_rect.center)
        surface.blit(text_surface, text_rect)

class ProgressBar(UIComponent):
    """프로그레스 바 컴포넌트"""
    
    def __init__(self, x: int, y: int, width: int, height: int,
                 max_value: float = 100, initial_value: float = 0):
        super().__init__(x, y, width, height)
        self.max_value = max_value
        self.current_value = initial_value
        self.target_value = initial_value
        self.animation_speed = 2.0  # 초당 애니메이션 속도
        
        # 스타일 옵션
        self.show_text = True
        self.show_percentage = True
        self.rounded_corners = True
        self.gradient_fill = True
    
    def set_value(self, value: float, animate: bool = True):
        """값 설정"""
        value = max(0, min(value, self.max_value))
        
        if animate:
            self.target_value = value
        else:
            self.current_value = value
            self.target_value = value
    
    def update(self, dt: float):
        """프로그레스 바 업데이트"""
        super().update(dt)
        
        # 부드러운 값 전환
        if self.current_value != self.target_value:
            diff = self.target_value - self.current_value
            change = diff * self.animation_speed * dt
            
            if abs(change) < 0.1:
                self.current_value = self.target_value
            else:
                self.current_value += change
    
    def draw(self, surface: pygame.Surface):
        """프로그레스 바 그리기"""
        if not self.is_visible:
            return
        
        # 배경
        bg_color = theme_manager.get_color('surface')
        pygame.draw.rect(surface, bg_color, self.rect, 
                        border_radius=self.rect.height // 2 if self.rounded_corners else 0)
        
        # 진행 바
        if self.current_value > 0:
            progress_width = int((self.current_value / self.max_value) * self.rect.width)
            progress_rect = pygame.Rect(self.rect.x, self.rect.y, progress_width, self.rect.height)
            
            # 체력 비율에 따른 색상
            percentage = self.current_value / self.max_value
            fill_color = theme_manager.get_health_color(percentage)
            
            if self.gradient_fill:
                # 그라디언트 효과
                for i in range(progress_rect.width):
                    alpha = 0.7 + 0.3 * (i / max(1, progress_rect.width))
                    color = tuple(int(c * alpha) for c in fill_color)
                    pygame.draw.line(surface, color, 
                                   (progress_rect.x + i, progress_rect.y),
                                   (progress_rect.x + i, progress_rect.bottom))
            else:
                pygame.draw.rect(surface, fill_color, progress_rect,
                               border_radius=self.rect.height // 2 if self.rounded_corners else 0)
        
        # 테두리
        border_color = theme_manager.get_color('secondary')
        pygame.draw.rect(surface, border_color, self.rect, 2,
                        border_radius=self.rect.height // 2 if self.rounded_corners else 0)
        
        # 텍스트
        if self.show_text:
            if self.show_percentage:
                text = f"{int((self.current_value / self.max_value) * 100)}%"
            else:
                text = f"{int(self.current_value)}/{int(self.max_value)}"
            
            text_surface = font_manager.render(text, 'caption_small', 
                                              theme_manager.get_color('text_primary'))
            text_rect = text_surface.get_rect(center=self.rect.center)
            surface.blit(text_surface, text_rect)

class Card(UIComponent):
    """카드 컴포넌트"""
    
    def __init__(self, x: int, y: int, width: int, height: int,
                 title: str = "", content: str = ""):
        super().__init__(x, y, width, height)
        self.title = title
        self.content = content
        self.elevation = 4
        self.padding = 16
    
    def draw(self, surface: pygame.Surface):
        """카드 그리기"""
        if not self.is_visible:
            return
        
        # 그림자 효과 (elevation)
        for i in range(self.elevation):
            shadow_rect = self.rect.inflate(i * 2, i * 2)
            shadow_rect.y += i
            shadow_color = (*theme_manager.get_color('shadow'), 20)
            shadow_surf = pygame.Surface(shadow_rect.size, pygame.SRCALPHA)
            pygame.draw.rect(shadow_surf, shadow_color, shadow_surf.get_rect(), 
                           border_radius=12)
            surface.blit(shadow_surf, shadow_rect)
        
        # 카드 배경
        bg_color = theme_manager.get_color('surface')
        pygame.draw.rect(surface, bg_color, self.rect, border_radius=12)
        
        # 호버 효과
        if self.is_hovered:
            hover_color = (*theme_manager.get_color('primary'), 30)
            hover_surf = pygame.Surface(self.rect.size, pygame.SRCALPHA)
            pygame.draw.rect(hover_surf, hover_color, hover_surf.get_rect(), 
                           border_radius=12)
            surface.blit(hover_surf, self.rect)
        
        # 테두리
        border_color = theme_manager.get_color('secondary')
        pygame.draw.rect(surface, border_color, self.rect, 1, border_radius=12)
        
        # 타이틀
        if self.title:
            title_surface = font_manager.render(self.title, 'heading_small',
                                               theme_manager.get_color('text_primary'))
            title_rect = title_surface.get_rect(
                x=self.rect.x + self.padding,
                y=self.rect.y + self.padding
            )
            surface.blit(title_surface, title_rect)
        
        # 내용
        if self.content:
            content_y = self.rect.y + self.padding + 40 if self.title else self.rect.y + self.padding
            content_lines = font_manager.render_multiline(
                self.content, 'body_small',
                theme_manager.get_color('text_secondary'),
                max_width=self.rect.width - self.padding * 2
            )
            
            for i, line in enumerate(content_lines):
                line_rect = line.get_rect(
                    x=self.rect.x + self.padding,
                    y=content_y + i * 25
                )
                surface.blit(line, line_rect)

class Toggle(UIComponent):
    """토글 스위치 컴포넌트"""
    
    def __init__(self, x: int, y: int, width: int = 60, height: int = 30,
                 initial_state: bool = False, on_change: Optional[Callable] = None):
        super().__init__(x, y, width, height)
        self.is_on = initial_state
        self.on_change = on_change
        self.animation_progress = 1.0 if initial_state else 0.0
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if not super().handle_event(event):
            if not self.is_enabled or not self.is_visible:
                return False
        
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.rect.collidepoint(event.pos):
                self.toggle()
                return True
        
        return False
    
    def toggle(self):
        """토글 상태 변경"""
        self.is_on = not self.is_on
        
        # 애니메이션 시작
        anim = Animation(
            self.animation_progress,
            1.0 if self.is_on else 0.0,
            0.3,
            AnimationManager.ease_out_cubic,
            on_update=lambda v: setattr(self, 'animation_progress', v)
        )
        self.animations.append(anim)
        
        if self.on_change:
            self.on_change(self.is_on)
    
    def draw(self, surface: pygame.Surface):
        """토글 스위치 그리기"""
        if not self.is_visible:
            return
        
        # 배경 트랙
        track_color = theme_manager.get_color('primary' if self.is_on else 'secondary')
        track_rect = pygame.Rect(self.rect.x, self.rect.y + self.rect.height // 4,
                                self.rect.width, self.rect.height // 2)
        pygame.draw.rect(surface, track_color, track_rect, 
                        border_radius=track_rect.height // 2)
        
        # 썸 (움직이는 원)
        thumb_radius = self.rect.height // 2 - 4
        thumb_x = int(self.rect.x + thumb_radius + 4 + 
                     (self.rect.width - thumb_radius * 2 - 8) * self.animation_progress)
        thumb_y = self.rect.centery
        
        # 썸 그림자
        pygame.draw.circle(surface, (0, 0, 0, 50), 
                         (thumb_x + 2, thumb_y + 2), thumb_radius)
        
        # 썸 본체
        thumb_color = theme_manager.get_color('text_primary')
        pygame.draw.circle(surface, thumb_color, (thumb_x, thumb_y), thumb_radius)

# UI 컴포넌트 매니저
class UIManager:
    """UI 컴포넌트 관리자"""
    
    def __init__(self):
        self.components: List[UIComponent] = []
    
    def add(self, component: UIComponent):
        """컴포넌트 추가"""
        self.components.append(component)
    
    def remove(self, component: UIComponent):
        """컴포넌트 제거"""
        if component in self.components:
            self.components.remove(component)
    
    def update(self, dt: float):
        """모든 컴포넌트 업데이트"""
        for component in self.components:
            component.update(dt)
    
    def handle_event(self, event: pygame.event.Event):
        """모든 컴포넌트에 이벤트 전달"""
        for component in reversed(self.components):  # 위에서부터 처리
            if component.handle_event(event):
                break
    
    def draw(self, surface: pygame.Surface):
        """모든 컴포넌트 그리기"""
        for component in self.components:
            component.draw(surface)