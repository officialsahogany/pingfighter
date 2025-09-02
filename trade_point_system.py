"""
Trade Point Star System Module
트레이드 포인트 별 시스템 - 모든 스테이지에서 사용 가능한 통합 모듈
"""

import pygame
import math
import random
import os
import sys

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

class TradePointSystem:
    """트레이드 포인트 별 시스템 관리 클래스"""
    
    def __init__(self, screen):
        """
        초기화
        Args:
            screen: Pygame 화면 객체
        """
        self.screen = screen
        self.stars = []  # 별 리스트
        self.particles = []  # 파티클 리스트
        self.texts = []  # 텍스트 효과 리스트
        self.collected_count = 0  # 수집한 개수
        self.draw_debug_count = 0  # 디버그 카운터
        
        # 별 설정
        self.star_size = 12  # 작은 크기로 조정
        self.star_lifetime = 600  # 10초
        self.collection_range = 40
        
        # 파티클 설정
        self.particle_lifetime = 60  # 1초
        self.particles_per_star = 20
        
        # 폰트 설정
        try:
            self.font = pygame.font.Font("NeoDGM.ttf", 20)
        except:
            self.font = pygame.font.Font(None, 20)
    
    def spawn_star(self, x, y, source_type="default"):
        """
        별 생성
        Args:
            x, y: 생성 위치
            source_type: 생성 원인 ("wall", "crow", "balloon", etc.)
        """
        # 초기 포물선 효과를 위한 랜덤 방향과 속도
        initial_direction = random.choice([-1, 1])  # 왼쪽 또는 오른쪽
        initial_horizontal_speed = random.uniform(1.5, 3.0) * initial_direction  # 수평 속도
        initial_upward_speed = random.uniform(-4.0, -2.5)  # 위로 튀어오르는 속도
        
        star = {
            'x': x,
            'y': y,
            'vx': initial_horizontal_speed,  # 초기 수평 속도 (포물선용)
            'vy': initial_upward_speed,   # 초기 위쪽 속도 (포물선용)
            'acceleration': 0.25,  # 중력 가속도 (더 빠르게 떨어지도록 증가)
            'size': self.star_size,
            'rotation': random.uniform(0, 2 * math.pi),
            'rotation_speed': random.uniform(0.05, 0.1),
            'glow_intensity': 1.0,
            'glow_timer': 0,
            'life': self.star_lifetime,
            'collected': False,
            'source_type': source_type,
            'float_timer': random.uniform(0, 2 * math.pi),  # 좌우 흔들림용 타이머
            'bounce_damping': 0.7  # 벽에 튕길 때 속도 감쇠
        }
        self.stars.append(star)
        
        # 파티클 생성
        self._spawn_particles(x, y, source_type)
        
        # 디버그 로그
        print(f" [spawn_star]   !")
        print(f"    : ({x:.1f}, {y:.1f})")
        print(f"    : {source_type}")
        print(f"    : vx={star['vx']:.2f}, vy={star['vy']:.2f}")
        print(f"       : {len(self.stars)}")
        
        return star
    
    def _spawn_particles(self, x, y, source_type):
        """파티클 생성 (내부 함수)"""
        for _ in range(self.particles_per_star):
            # 까마귀 타입은 검은색 파티클, 나머지는 형광색
            if source_type == "crow":
                color_shift = 0.0  # 검은색 파티클 표시
            else:
                color_shift = random.uniform(0.1, 0.9)  # 형광색 변화
            
            particle = {
                'x': x + random.uniform(-10, 10),
                'y': y + random.uniform(-10, 10),
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-3, -1),  # 위로 올라가는 효과
                'size': random.uniform(1, 3),
                'alpha': 255,
                'fade_speed': random.uniform(3, 5),
                'color_shift': color_shift
            }
            self.particles.append(particle)
    
    def update(self, ball_rect=None, paddle_rect=None):
        """
        시스템 업데이트
        Args:
            ball_rect: 공의 충돌 영역 (현재 사용 안 함 - 패들로만 수집 가능)
            paddle_rect: 패들의 충돌 영역 (수집 체크용)
        Returns:
            collected: 이번 프레임에 수집된 별 개수
        """
        collected_this_frame = 0
        
        # 별 업데이트
        stars_to_remove = []
        for star in self.stars:
            if star['collected']:
                continue
            
            # 수명 감소
            star['life'] -= 1
            if star['life'] <= 0:
                stars_to_remove.append(star)
                continue
            
            # 위치 업데이트 (포물선 효과 + 가속도)
            star['float_timer'] += 0.05
            
            # 수평 이동 (초기 속도 + 약간의 흔들림)
            star['x'] += star['vx'] + math.sin(star['float_timer']) * 0.1  # 약간의 좌우 흔들림
            star['y'] += star['vy']  # 수직 이동
            
            # 중력 가속도 적용 (점점 빨라짐)
            star['vy'] += star['acceleration']
            if star['vy'] > 12.0:  # 최대 속도 제한 (더 빠르게)
                star['vy'] = 12.0
            
            # 벽 충돌 체크 및 튕김
            # 왼쪽 벽
            if star['x'] <= star['size']:
                star['x'] = star['size']
                star['vx'] = abs(star['vx']) * star['bounce_damping']  # 오른쪽으로 튕김
            
            # 오른쪽 벽
            if star['x'] >= 600 - star['size']:  # WIDTH = 600
                star['x'] = 600 - star['size']
                star['vx'] = -abs(star['vx']) * star['bounce_damping']  # 왼쪽으로 튕김
            
            # 수평 속도 감쇠 (공기 저항)
            star['vx'] *= 0.98
            
            # 화면 밖으로 나가면 제거
            if star['y'] > 750:  # 화면 하단 밖
                stars_to_remove.append(star)
                continue
            
            # 회전
            star['rotation'] += star['rotation_speed']
            
            # 반짝임 효과
            star['glow_timer'] += 0.1
            star['glow_intensity'] = 0.7 + 0.3 * abs(math.sin(star['glow_timer']))
            
            # 수집 체크 - 패들로만 수집 가능
            # (공으로는 별을 획득할 수 없음)
            
            # 패들과 충돌 체크
            if paddle_rect:
                # 별의 더 작은 충돌 영역 (패들은 정확한 충돌 필요)
                star_collision_rect = pygame.Rect(
                    star['x'] - star['size'],
                    star['y'] - star['size'],
                    star['size'] * 2,
                    star['size'] * 2
                )
                
                if paddle_rect.colliderect(star_collision_rect):
                    star['collected'] = True
                    self.collected_count += 1
                    collected_this_frame += 1
                    
                    # 수집 텍스트 추가
                    self._add_collection_text(star['x'], star['y'])
                    
                    # 수집 파티클 추가
                    self._spawn_collection_particles(star['x'], star['y'])
                    
                    # 수집 효과음 재생
                    try:
                        pygame.mixer.Sound(resource_path("sounds/star.wav")).play()
                    except:
                        # star.wav가 없으면 coin.wav 재생
                        try:
                            pygame.mixer.Sound(resource_path("sounds/coin.wav")).play()
                        except:
                            pass
                    
                    stars_to_remove.append(star)
        
        # 별 제거
        for star in stars_to_remove:
            if star in self.stars:
                self.stars.remove(star)
        
        # 파티클 업데이트
        self._update_particles()
        
        # 텍스트 업데이트
        self._update_texts()
        
        return collected_this_frame
    
    def _update_particles(self):
        """파티클 업데이트 (내부 함수)"""
        particles_to_remove = []
        
        for particle in self.particles:
            # 이동
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            
            # 중력 효과
            particle['vy'] += 0.1
            
            # 페이드 아웃
            particle['alpha'] -= particle['fade_speed']
            
            if particle['alpha'] <= 0:
                particles_to_remove.append(particle)
        
        # 제거
        for particle in particles_to_remove:
            self.particles.remove(particle)
    
    def _update_texts(self):
        """텍스트 효과 업데이트 (내부 함수)"""
        texts_to_remove = []
        
        for text in self.texts:
            text['y'] -= text['speed']
            text['alpha'] -= text['fade_speed']
            
            if text['alpha'] <= 0:
                texts_to_remove.append(text)
        
        # 제거
        for text in texts_to_remove:
            self.texts.remove(text)
    
    def _add_collection_text(self, x, y):
        """수집 텍스트 추가 (내부 함수)"""
        text = {
            'x': x,
            'y': y - 20,
            'text': "+1 Trade Point",
            'alpha': 255,
            'speed': 1.5,
            'fade_speed': 4
        }
        self.texts.append(text)
    
    def _spawn_collection_particles(self, x, y):
        """수집 시 특별 파티클 생성 (내부 함수)"""
        for _ in range(30):  # 수집 시 더 많은 파티클
            particle = {
                'x': x,
                'y': y,
                'vx': random.uniform(-3, 3),
                'vy': random.uniform(-4, -1),
                'size': random.uniform(2, 4),
                'alpha': 255,
                'fade_speed': random.uniform(2, 4),
                'color_shift': random.uniform(0.3, 1.0)
            }
            self.particles.append(particle)
    
    def draw(self):
        """시스템 렌더링"""
        # 디버그: draw 호출 확인 (처음 10번만)
        active_stars = len([s for s in self.stars if not s['collected']])
        if active_stars > 0 and self.draw_debug_count < 10:
            print(f" [draw #{self.draw_debug_count+1}]  {active_stars}")
            self.draw_debug_count += 1
        
        # 파티클 먼저 그리기
        self._draw_particles()
        
        # 별 그리기
        self._draw_stars()
        
        # 텍스트 그리기
        self._draw_texts()
    
    def _draw_particles(self):
        """파티클 그리기 (내부 함수)"""
        for particle in self.particles:
            if particle['alpha'] <= 0:
                continue
            
            # 색상 계산
            color = self._calculate_particle_color(particle)
            
            # 파티클 그리기
            particle_surface = pygame.Surface((int(particle['size'] * 4), int(particle['size'] * 4)), pygame.SRCALPHA)
            pygame.draw.circle(particle_surface, color,
                             (int(particle['size'] * 2), int(particle['size'] * 2)), int(particle['size']))
            self.screen.blit(particle_surface, (particle['x'] - particle['size'] * 2, particle['y'] - particle['size'] * 2))
    
    def _calculate_particle_color(self, particle):
        """파티클 색상 계산 (내부 함수)"""
        color_shift = particle['color_shift']
        alpha = min(255, particle['alpha'])
        
        if color_shift == 0.0:  # 까마귀 파티클 (검은색)
            gray_value = int(30 + alpha * 0.2)
            return (gray_value, gray_value, gray_value, alpha)
        elif color_shift < 0.33:
            # 노란색 → 흰색
            t = color_shift * 3
            return (255, 255, int(100 + 155 * t), alpha)
        elif color_shift < 0.66:
            # 흰색 → 연한 파란색
            t = (color_shift - 0.33) * 3
            return (int(255 - 55 * t), int(255 - 30 * t), 255, alpha)
        else:
            # 연한 파란색 → 청록색
            t = (color_shift - 0.66) * 3
            return (int(200 - 100 * t), int(225 + 30 * t), 255, alpha)
    
    def _draw_stars(self):
        """별 그리기 (내부 함수)"""
        for idx, star in enumerate(self.stars):
            if star['collected']:
                continue
            
            # 디버그: 별 그리기 상세 정보 (처음 10번만)
            if self.draw_debug_count <= 10:
                print(f"    #{idx+1} : =({star['x']:.1f}, {star['y']:.1f}), life={star['life']}, size={star['size']}")
            
            # 투명도 계산
            alpha = min(255, star['life'] * 2)
            
            # 별의 실제 중심 좌표
            center_x = star['x']
            center_y = star['y']
            
            # 핑크빛 후광 효과 (4단계 그라데이션)
            glow_alpha = int(alpha * 0.5 * star['glow_intensity'])
            glow_colors = [
                (255, 180, 220, glow_alpha // 4),  # 연한 핑크 (가장 바깥)
                (255, 150, 200, glow_alpha // 3),  # 중간 핑크
                (255, 120, 180, glow_alpha // 2),  # 진한 핑크
                (255, 100, 160, glow_alpha)        # 가장 진한 핑크 (가장 안쪽)
            ]
            
            for i, glow_color in enumerate(glow_colors):
                glow_size = star['size'] * (4 - i * 0.7)
                glow_surf_size = int(glow_size * 2 + 4)
                glow_surface = pygame.Surface((glow_surf_size, glow_surf_size), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, glow_color, 
                                 (glow_surf_size // 2, glow_surf_size // 2), int(glow_size))
                self.screen.blit(glow_surface, (center_x - glow_surf_size // 2, center_y - glow_surf_size // 2))
            
            # 별 그리기를 위한 최소 크기 서페이스
            star_size = star['size'] * 2 + 4
            star_surface = pygame.Surface((star_size, star_size), pygame.SRCALPHA)
            local_center = star_size // 2
            
            # 5각 별 그리기
            points = []
            for i in range(10):
                angle = star['rotation'] + (i * math.pi / 5)
                if i % 2 == 0:
                    # 외부 꼭지점
                    radius = star['size']
                else:
                    # 내부 꼭지점
                    radius = star['size'] * 0.5
                x = local_center + radius * math.cos(angle)
                y = local_center + radius * math.sin(angle)
                points.append((x, y))
            
            # 별 색상 (빨간색으로 변경해서 더 잘 보이게)
            star_color = (255, 0, 0, alpha)  # 빨간색
            if len(points) >= 3:
                pygame.draw.polygon(star_surface, star_color, points)
                
                # 테두리 (노란색)
                border_color = (255, 255, 0, alpha)  # 노란색 테두리
                pygame.draw.polygon(star_surface, border_color, points, 3)  # 테두리 두께 증가
            
            # 중앙 반짝임
            sparkle_alpha = int(alpha * star['glow_intensity'])
            pygame.draw.circle(star_surface, (255, 255, 255, sparkle_alpha), 
                             (local_center, local_center), 3)
            
            # 화면에 그리기
            self.screen.blit(star_surface, (center_x - local_center, center_y - local_center))
    
    def _draw_texts(self):
        """텍스트 효과 그리기 (내부 함수)"""
        for text in self.texts:
            if text['alpha'] <= 0:
                continue
            
            # 텍스트 렌더링
            text_surface = self.font.render(text['text'], True, (255, 255, 100))
            text_surface.set_alpha(text['alpha'])
            
            # 중앙 정렬로 그리기
            text_rect = text_surface.get_rect(center=(text['x'], text['y']))
            self.screen.blit(text_surface, text_rect)
    
    def reset(self):
        """시스템 리셋"""
        self.stars.clear()
        self.particles.clear()
        self.texts.clear()
        self.collected_count = 0
    
    def get_collected_count(self):
        """수집한 개수 반환"""
        return self.collected_count
    
    def set_collected_count(self, count):
        """수집한 개수 설정"""
        self.collected_count = count
    
    def get_active_star_count(self):
        """현재 활성화된 별 개수 반환"""
        return len([s for s in self.stars if not s['collected']])