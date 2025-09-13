"""
아이템 획득 애니메이션 시스템
- 아이템 아이콘이 아래에서 위로 올라오는 효과
- 크게 시작해서 서서히 보이는 페이드 인
- 전설 아이템과 일반 아이템 구분
"""

import pygame
import math
import random
from typing import Optional, List, Tuple, Any

class ItemAcquisitionEffect:
    """아이템 획득 시 표시되는 플로팅 애니메이션"""
    
    def __init__(self, width: int = 600, height: int = 750):
        self.width = width
        self.height = height
        self.active_items = []  # 현재 애니메이션 중인 아이템들
        
        # 애니메이션 설정
        self.animation_duration = 3000  # 3초로 늘림 (더 천천히)
        self.rise_speed = 80  # 픽셀/초 (느리게 상승)
        self.fade_in_duration = 700  # 0.7초
        self.float_amplitude = 15  # 좌우 흔들림 진폭 (더 부드럽게)
        self.float_frequency = 1.5  # 흔들림 주파수 (더 천천히)
        
        # 크기 설정
        self.initial_scale = 4.0  # 시작 크기 (4배로 더 크게)
        self.final_scale = 2.0  # 최종 크기 (2배 크기 유지)
        self.icon_size = 120  # 기본 아이콘 크기 (더 크게)
        
    def add_item(self, item_name: str, korean_name: str, item_icon: Any = None, 
                 is_legendary: bool = False, position: Optional[Tuple[int, int]] = None):
        """새 아이템 획득 애니메이션 추가
        
        Args:
            item_name: 아이템 영문 이름
            korean_name: 아이템 한글 이름
            item_icon: 아이템 아이콘 Surface
            is_legendary: 전설 아이템 여부
            position: 시작 위치 (None이면 화면 중앙)
        """
        # position이 제공되지 않으면 화면 중앙에서 시작
        if position is None:
            position = (self.width // 2, self.height // 2 + 100)  # 화면 중앙 약간 아래에서 시작
            
        item_data = {
            'name': item_name,
            'korean_name': korean_name,
            'icon': item_icon,
            'is_legendary': is_legendary,
            'x': position[0],
            'y': position[1],
            'start_x': position[0],  # 시작 x 위치 저장
            'start_y': position[1],
            'time': 0,
            'alpha': 0,
            'scale': self.initial_scale,
            'particles': [],
            'glow_intensity': 0
        }
        
        # 전설 아이템은 특별한 파티클 생성
        if is_legendary:
            self._create_legendary_particles(item_data)
            
        self.active_items.append(item_data)
        
    def _create_legendary_particles(self, item_data):
        """전설 아이템용 특별 파티클 생성"""
        for _ in range(20):
            particle = {
                'x': 0,  # 아이템 상대 위치
                'y': 0,
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-3, -1),
                'life': 1.0,
                'size': random.randint(2, 5),
                'color': (255, 215, 0) if random.random() > 0.5 else (255, 100, 100),
                'trail': []
            }
            item_data['particles'].append(particle)
            
    def update(self, dt: float):
        """애니메이션 업데이트
        
        Args:
            dt: 델타 타임 (밀리초)
        """
        new_items = []
        
        for item in self.active_items:
            item['time'] += dt
            
            # 애니메이션 종료 체크
            if item['time'] >= self.animation_duration:
                continue
                
            # 수직 이동 (아래에서 위로)
            progress = item['time'] / self.animation_duration
            item['y'] = item['start_y'] - (self.rise_speed * item['time'] / 1000)
            
            # 좌우 흔들림 (사인파) - 시작 위치 기준으로 흔들림
            float_offset = math.sin(item['time'] * 0.001 * self.float_frequency) * self.float_amplitude
            item['x'] = item['start_x'] + float_offset  # 시작 위치 기준으로 좌우 흔들림
            
            # 페이드 인
            if item['time'] < self.fade_in_duration:
                item['alpha'] = int(255 * (item['time'] / self.fade_in_duration))
            else:
                # 페이드 아웃 (마지막 0.7초)
                fade_out_start = self.animation_duration - 700
                if item['time'] > fade_out_start:
                    fade_progress = (item['time'] - fade_out_start) / 700
                    item['alpha'] = int(255 * (1 - fade_progress))
                else:
                    item['alpha'] = 255
                    
            # 크기 변화 (크게 시작해서 천천히 작아짐)
            scale_progress = min(1.0, item['time'] / 1500)  # 1.5초에 걸쳐 크기 정상화
            item['scale'] = self.initial_scale - (self.initial_scale - self.final_scale) * scale_progress
            
            # 전설 아이템 효과
            if item['is_legendary']:
                # 글로우 펄스
                item['glow_intensity'] = abs(math.sin(item['time'] * 0.003)) * 0.5 + 0.5
                
                # 파티클 업데이트
                new_particles = []
                for particle in item['particles']:
                    # 파티클 이동
                    particle['x'] += particle['vx']
                    particle['y'] += particle['vy']
                    particle['vy'] += 0.1  # 중력
                    
                    # 수명 감소
                    particle['life'] -= dt * 0.001
                    
                    # 트레일 추가
                    if len(particle['trail']) > 5:
                        particle['trail'].pop(0)
                    particle['trail'].append((particle['x'], particle['y']))
                    
                    if particle['life'] > 0:
                        new_particles.append(particle)
                        
                item['particles'] = new_particles
                
                # 새 파티클 생성 (일정 간격으로)
                if random.random() < 0.1:
                    particle = {
                        'x': random.uniform(-20, 20),
                        'y': 0,
                        'vx': random.uniform(-1, 1),
                        'vy': random.uniform(-2, 0),
                        'life': 0.5,
                        'size': random.randint(2, 4),
                        'color': (255, 215, 0),
                        'trail': []
                    }
                    item['particles'].append(particle)
                    
            new_items.append(item)
            
        self.active_items = new_items
        
    def draw(self, screen: pygame.Surface, font: pygame.font.Font):
        """애니메이션 그리기
        
        Args:
            screen: 게임 화면
            font: 텍스트 폰트
        """
        for item in self.active_items:
            x, y = int(item['x']), int(item['y'])
            alpha = item['alpha']
            scale = item['scale']
            
            # 전설 아이템 글로우
            if item['is_legendary'] and item['glow_intensity'] > 0:
                glow_size = int(self.icon_size * scale * 1.5)
                glow_alpha = int(alpha * item['glow_intensity'] * 0.3)
                
                # 여러 겹의 글로우
                for i in range(3):
                    size = glow_size + i * 20
                    surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    color = (255, 215, 0, glow_alpha // (i + 1))
                    pygame.draw.circle(surf, color, (size, size), size)
                    screen.blit(surf, (x - size, y - size))
                    
                # 파티클 그리기
                for particle in item['particles']:
                    px = x + particle['x']
                    py = y + particle['y']
                    
                    # 트레일
                    for i, pos in enumerate(particle['trail']):
                        trail_alpha = int(alpha * particle['life'] * (i / len(particle['trail'])) * 0.5)
                        trail_color = (*particle['color'], trail_alpha)
                        pygame.draw.circle(screen, trail_color[:3], 
                                         (int(x + pos[0]), int(y + pos[1])), 
                                         max(1, particle['size'] // 2))
                    
                    # 파티클 본체
                    particle_alpha = int(alpha * particle['life'])
                    particle_color = (*particle['color'], particle_alpha)
                    pygame.draw.circle(screen, particle_color[:3],
                                     (int(px), int(py)), particle['size'])
            
            # 아이템 아이콘 그리기
            if item['icon'] and isinstance(item['icon'], pygame.Surface):
                # 크기 조정
                icon_size = int(self.icon_size * scale)
                scaled_icon = pygame.transform.scale(item['icon'], (icon_size, icon_size))
                
                # 알파 적용
                scaled_icon.set_alpha(alpha)
                
                # 중앙 정렬로 그리기
                icon_rect = scaled_icon.get_rect(center=(x, y))
                screen.blit(scaled_icon, icon_rect)
            else:
                # 아이콘이 없는 경우 기본 원형 표시
                size = int(self.icon_size * scale / 2)
                color = (255, 255, 255) if not item['is_legendary'] else (255, 215, 0)
                
                # 외곽선
                pygame.draw.circle(screen, color, (x, y), size, 3)
                
                # 내부 채우기 (반투명)
                fill_alpha = alpha // 2
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                fill_color = (*color, fill_alpha)
                pygame.draw.circle(surf, fill_color, (size, size), size - 3)
                screen.blit(surf, (x - size, y - size))
            
            # 아이템 이름 표시
            if font and item['korean_name']:
                # 텍스트 렌더링
                text_surface = font.render(item['korean_name'] + " 획득!", True, (255, 255, 255))
                text_surface.set_alpha(alpha)
                
                # 텍스트 위치 (아이콘 아래)
                text_rect = text_surface.get_rect(center=(x, y + int(self.icon_size * scale / 2) + 30))
                
                # 배경 그리기 (가독성을 위해)
                bg_padding = 10
                bg_rect = text_rect.inflate(bg_padding * 2, bg_padding)
                bg_surf = pygame.Surface((bg_rect.width, bg_rect.height), pygame.SRCALPHA)
                bg_color = (0, 0, 0, int(alpha * 0.5))
                bg_surf.fill(bg_color)
                screen.blit(bg_surf, bg_rect)
                
                # 텍스트 그리기
                screen.blit(text_surface, text_rect)
                    
    def clear(self):
        """모든 활성 애니메이션 제거"""
        self.active_items = []
        
    def is_active(self) -> bool:
        """활성 애니메이션이 있는지 확인"""
        return len(self.active_items) > 0


# 싱글톤 인스턴스
_item_effect = None

def get_item_effect() -> ItemAcquisitionEffect:
    """아이템 획득 효과 싱글톤 반환"""
    global _item_effect
    if _item_effect is None:
        _item_effect = ItemAcquisitionEffect()
    return _item_effect

def show_item_acquisition(item_name: str, korean_name: str, item_icon: Any = None, 
                          is_legendary: bool = False, position: Optional[Tuple[int, int]] = None):
    """아이템 획득 애니메이션 표시
    
    Args:
        item_name: 아이템 영문 이름
        korean_name: 아이템 한글 이름
        item_icon: 아이템 아이콘 Surface
        is_legendary: 전설 아이템 여부
        position: 시작 위치
    """
    effect = get_item_effect()
    effect.add_item(item_name, korean_name, item_icon, is_legendary, position)
    
def update_item_effects(dt: float):
    """아이템 획득 효과 업데이트"""
    effect = get_item_effect()
    effect.update(dt)
    
def draw_item_effects(screen: pygame.Surface, font: pygame.font.Font):
    """아이템 획득 효과 그리기"""
    effect = get_item_effect()
    effect.draw(screen, font)
    
def initialize_item_effects(width: int = 600, height: int = 750):
    """아이템 획득 효과 시스템 초기화"""
    global _item_effect
    _item_effect = ItemAcquisitionEffect(width, height)