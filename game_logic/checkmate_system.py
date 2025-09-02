"""
Checkmate System - 매치 포인트 상황 관리
플레이어나 보스가 승리 직전(2점)에 도달했을 때의 특별 효과
"""

import pygame
import math
import random

class CheckmateSystem:
    """체크메이트 시스템 - 매치포인트 상황 관리"""
    
    def __init__(self):
        self.is_player_checkmate = False  # 플레이어가 매치포인트
        self.is_boss_checkmate = False    # 보스가 매치포인트
        self.checkmate_timer = 0
        self.pulse_effect = 0
        self.particle_timer = 0
        
        # 시각 효과 설정
        self.checkmate_particles = []
        self.warning_flash = 0
        self.tension_level = 0
        
        # 색상 설정
        self.player_checkmate_color = (255, 215, 0)  # 황금색
        self.boss_checkmate_color = (255, 50, 50)    # 위험 빨강
        self.flash_color = (255, 255, 255)
        
        # 텍스트 효과
        self.text_scale = 1.0
        self.text_bounce = 0
        
    def check_checkmate(self, round_wins, round_losses, win_goal=3):
        """체크메이트 상황 체크"""
        # 이전 상태 저장
        prev_player_checkmate = self.is_player_checkmate
        prev_boss_checkmate = self.is_boss_checkmate
        
        # 플레이어 체크메이트: 2점이고 보스가 2점 미만
        self.is_player_checkmate = (round_wins == win_goal - 1) and (round_losses < win_goal - 1)
        
        # 보스 체크메이트: 보스가 2점이고 플레이어가 2점 미만
        self.is_boss_checkmate = (round_losses == win_goal - 1) and (round_wins < win_goal - 1)
        
        # 새로운 체크메이트 상황 발생
        if self.is_player_checkmate and not prev_player_checkmate:
            self.on_player_checkmate()
        elif self.is_boss_checkmate and not prev_boss_checkmate:
            self.on_boss_checkmate()
        elif not self.is_player_checkmate and not self.is_boss_checkmate:
            self.on_checkmate_end()
            
    def on_player_checkmate(self):
        """플레이어 체크메이트 시작"""
        self.checkmate_timer = 0
        self.warning_flash = 0
        self.tension_level = 1.0
        self.generate_checkmate_particles(True)
        print("CHECKMATE!  !")
        
    def on_boss_checkmate(self):
        """보스 체크메이트 시작"""
        self.checkmate_timer = 0
        self.warning_flash = 0
        self.tension_level = 1.0
        self.generate_checkmate_particles(False)
        print("DANGER!  !")
        
    def on_checkmate_end(self):
        """체크메이트 상황 종료"""
        self.checkmate_particles.clear()
        self.tension_level = 0
        
    def generate_checkmate_particles(self, is_player):
        """체크메이트 파티클 생성"""
        self.checkmate_particles.clear()
        color = self.player_checkmate_color if is_player else self.boss_checkmate_color
        
        for _ in range(20):
            self.checkmate_particles.append({
                'x': random.randint(100, 500),
                'y': random.randint(100, 200),
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-1, 1),
                'life': random.uniform(1.0, 2.0),
                'size': random.randint(2, 5),
                'color': color,
                'alpha': 255
            })
    
    def update(self, dt=1/60):
        """체크메이트 효과 업데이트"""
        if not self.is_player_checkmate and not self.is_boss_checkmate:
            return
            
        # 타이머 증가
        self.checkmate_timer += dt * 60
        
        # 펄스 효과
        self.pulse_effect = abs(math.sin(self.checkmate_timer * 0.1)) * 0.5 + 0.5
        
        # 텍스트 애니메이션
        self.text_scale = 1.0 + math.sin(self.checkmate_timer * 0.15) * 0.1
        self.text_bounce = math.sin(self.checkmate_timer * 0.2) * 5
        
        # 경고 플래시
        if self.is_boss_checkmate:
            self.warning_flash = abs(math.sin(self.checkmate_timer * 0.3)) * 100
        
        # 파티클 업데이트
        for particle in self.checkmate_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] += 0.1  # 중력
            particle['life'] -= dt
            particle['alpha'] = max(0, particle['alpha'] - dt * 100)
            
            if particle['life'] <= 0 or particle['alpha'] <= 0:
                self.checkmate_particles.remove(particle)
        
        # 새 파티클 생성
        if self.checkmate_timer % 10 == 0:
            self.generate_checkmate_particles(self.is_player_checkmate)
    
    def draw(self, screen, font_large=None, font_small=None):
        """체크메이트 효과 그리기"""
        if not self.is_player_checkmate and not self.is_boss_checkmate:
            return
            
        # 화면 테두리 효과
        if self.is_player_checkmate:
            # 황금빛 테두리
            border_color = (*self.player_checkmate_color, int(50 * self.pulse_effect))
            pygame.draw.rect(screen, border_color, (0, 0, 600, 750), 5)
            
        elif self.is_boss_checkmate:
            # 위험 빨간 테두리 + 플래시
            alpha = int(100 + self.warning_flash)
            border_color = (*self.boss_checkmate_color, min(255, alpha))
            for i in range(3):
                pygame.draw.rect(screen, border_color, (i*2, i*2, 600-i*4, 750-i*4), 2)
        
        # 파티클 그리기
        for particle in self.checkmate_particles:
            color = (*particle['color'], int(particle['alpha']))
            pos = (int(particle['x']), int(particle['y']))
            pygame.draw.circle(screen, color[:3], pos, particle['size'])
        
        # 텍스트 표시
        if font_large:
            if self.is_player_checkmate:
                text = "MATCH POINT!"
                color = self.player_checkmate_color
            else:
                text = "DANGER!"
                color = self.boss_checkmate_color
                
            # 텍스트 렌더링 (스케일 효과 적용)
            text_surface = font_large.render(text, True, color)
            
            # 스케일 적용
            scaled_width = int(text_surface.get_width() * self.text_scale)
            scaled_height = int(text_surface.get_height() * self.text_scale)
            if scaled_width > 0 and scaled_height > 0:
                scaled_surface = pygame.transform.scale(text_surface, (scaled_width, scaled_height))
                
                # 중앙 상단에 표시
                x = 300 - scaled_width // 2
                y = 50 + int(self.text_bounce)
                screen.blit(scaled_surface, (x, y))
                
        # 추가 정보 텍스트
        if font_small:
            if self.is_player_checkmate:
                info_text = "승리까지 1점!"
                color = (255, 255, 200)
            else:
                info_text = "위험! 보스 승리 직전!"
                color = (255, 200, 200)
                
            text_surface = font_small.render(info_text, True, color)
            x = 300 - text_surface.get_width() // 2
            y = 100 + int(self.text_bounce)
            screen.blit(text_surface, (x, y))
    
    def draw_score_emphasis(self, screen, x, y, font, is_player_score, score):
        """점수 표시에 체크메이트 강조 효과"""
        if self.is_player_checkmate and is_player_score:
            # 플레이어 점수 강조
            glow_size = int(5 + self.pulse_effect * 3)
            for i in range(glow_size):
                alpha = int(50 - i * 10)
                if alpha > 0:
                    glow_color = (*self.player_checkmate_color, alpha)
                    pygame.draw.circle(screen, glow_color[:3], (x, y), 30 + i * 5, 2)
                    
        elif self.is_boss_checkmate and not is_player_score:
            # 보스 점수 강조
            glow_size = int(5 + self.pulse_effect * 3)
            for i in range(glow_size):
                alpha = int(50 - i * 10)
                if alpha > 0:
                    glow_color = (*self.boss_checkmate_color, alpha)
                    pygame.draw.circle(screen, glow_color[:3], (x, y), 30 + i * 5, 2)

# 싱글톤 인스턴스
_checkmate_instance = None

def get_checkmate_system():
    """체크메이트 시스템 싱글톤 인스턴스 반환"""
    global _checkmate_instance
    if _checkmate_instance is None:
        _checkmate_instance = CheckmateSystem()
    return _checkmate_instance